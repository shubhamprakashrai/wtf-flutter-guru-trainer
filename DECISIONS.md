# Architecture Decision Records

## ADR #1 — State management: Bloc (Cubit)

**Decision:** `flutter_bloc` (Cubit flavor), not Provider or raw Riverpod.

**Context:** The build actually started on `flutter_riverpod` (Provider for
DI, a `StateProvider` tick to force rebuilds after mock-auth mutations,
`ConsumerStatefulWidget` screens). Mid-build this was switched to
`flutter_bloc` per explicit direction. Because most screens were already
holding their own reactive state via `StreamSubscription` + `setState`
rather than leaning on Riverpod's provider graph, the swap was mostly
mechanical: `Provider`/`StateProvider` → `RepositoryProvider` for `AppServices`
DI, and four small `Cubit`s (`AuthCubit`, `ChatCubit`, `CallCubit`,
`SessionLogCubit` in `shared/lib/blocs/`) that each wrap one service's
stream and re-emit a plain UI-state object. Screens use
`BlocBuilder`/`BlocConsumer`/`context.read`.

**Why this shape specifically:** the real complexity in this app is in the
*services* (Hive persistence + WebSocket relay fan-out), not in UI state
machines. Cubits here are intentionally thin - "reload from service, emit" -
rather than modeling every screen as a `Bloc` with events, which would have
added ceremony without a matching payoff for an app this size.

**Trade-off accepted:** a "real" Bloc (event → state, testable via
`bloc_test`) would give better auditability for something like the in-call
connection state machine. Given the timebox, only the four Cubits above
exist and `CallManager` (the actual call state machine, wrapping the RTC
SDK's room object - see ADR #3) is a `ChangeNotifier`, not a Cubit. This
turned out to be a good fit independent of which RTC vendor ended up behind
it: LiveKit's own `Room`/`Participant` classes are themselves
`ChangeNotifier`s, so `CallManager` mostly just re-exposes `Room` rather
than hand-translating SDK callbacks into Bloc events for no behavioral
benefit.

## ADR #2 — Storage: Hive, models as plain JSON maps (no codegen)

**Decision:** Hive boxes, one per model type, storing each model as
`Map<String,dynamic>` via hand-written `toJson`/`fromJson` - no
`hive_generator`/`build_runner`, no `TypeAdapter`s.

**Why:** Hive natively supports arbitrary JSON-safe maps without adapters.
Skipping codegen removes a `build_runner watch` step from the dev loop
entirely, which mattered more here than the (small, at this data volume)
performance edge adapters have over map decoding. `DateTime` is stored as
`millisecondsSinceEpoch`, enums as `.name` strings - both are already how
`toJson()` needs to serialize for the WebSocket relay payloads anyway, so
there's no second encoding to maintain.

**Alternative considered:** SQLite (`sqflite`) - rejected because nothing in
this data model needs relational queries; every list screen is
"all records of type X, filtered/sorted in Dart," which Hive's `.values`
handles fine at this scale.

## ADR #3 — RTC strategy: LiveKit (swapped from 100ms) + self-signed dev token + single persistent room + WebSocket relay for app-to-app sync

**Decision:** [LiveKit](https://livekit.io) instead of 100ms as the RTC
vendor, everything else about the strategy unchanged from the original
100ms-based plan. Summary of the four sub-decisions:

0. **Vendor: LiveKit, not 100ms.** The assignment's default/required vendor
   is 100ms. Every 100ms signup attempt during this build asked for card
   details before a project/App Access Key could be created, which blocks a
   local, free take-home build. This was raised with, and explicitly
   approved by, both the interviewer and HR before switching - not a
   unilateral substitution. LiveKit's Cloud free tier requires only an
   email to sign up and issue an API Key/Secret, no card. See
   `AI_LEDGER.md` for the build sequence (100ms integration was fully built
   and working first, per spec, then swapped once the card requirement was
   confirmed to be a hard blocker rather than a one-off signup quirk).
   Everything downstream of "get a token, join a room, render tiles, toggle
   mute/video/camera, handle reconnects" carried over essentially unchanged
   in shape - see ARCHITECTURE.md "Video calling (LiveKit)".
1. **Token minting** happens locally in `token_server/` by self-signing a
   JWT with the LiveKit API Key/Secret, rather than calling any LiveKit
   management endpoint - fewer moving parts, and the assignment explicitly
   allows a "minimal token server" (this shape is identical to what the
   100ms version did).
2. **One dev room reused for every call** rather than provisioning a room
   per `CallRequest` - same shortcut the original 100ms plan used, still
   appropriate for a dev/take-home build with LiveKit.
3. **A WebSocket relay** (same Node process as the token server) is the
   *only* way `guru_app` and `trainer_app` learn about each other's chat
   messages, approvals, and session-log updates, since the assignment rules
   out a shared cloud backend for app data. This is separate from LiveKit
   itself, which only carries the actual audio/video.

**What would need to change to go back to 100ms:** `token_server/server.js`'s
`/token` route (claim shape only), `shared/lib/services/call_manager.dart`
and `call_widgets.dart` (SDK calls), and the `livekit_client` dependency in
`shared`/`guru_app`/`trainer_app` pubspecs - the rest of the app (chat,
scheduling, session logs, UI) has no RTC-vendor awareness at all.

## Implemented from the optional/bonus lists

All four spec section 15 stretch items ended up implemented (see
AI_LEDGER.md entry #19) - initially scoped out given the timebox, then
picked back up on explicit request after the core assessment was already
submitted, once there was time to spend on them without risking the
verified-working core flows.

- **Export session summary** (spec section 3.E bonus) - a share icon on
  the session-log detail sheet in both apps, using `share_plus` to hand a
  plain-text summary (`shared/lib/utils/session_summary.dart`) to the
  OS share sheet.
- **Light/Dark theme toggle** - `ThemeCubit` (Hive-persisted `ThemeMode`)
  + a toggle icon in both apps' AppBar. `AppTheme.buildDark` mirrors the
  light theme using `ColorScheme.fromSeed(brightness: Brightness.dark)`,
  and the most-reused shared widgets (`HomeActionCard`, `ChatBubble`,
  `MessageInputBar`, the scheduler chips, `DevPanel`) plus each screen's
  own card/list-tile containers were swept from hardcoded literal colors
  to `Theme.of(context).colorScheme` lookups. The in-call screens
  (`pre_join_screen.dart`, `in_call_screen.dart`) were deliberately left on
  their fixed dark background regardless of app theme - video-call UIs are
  conventionally always-dark (Zoom/Meet-style), not something a light/dark
  toggle should affect.
- **Offline send queue for chat** - `SyncClient.connectionChanges` (a new
  broadcast stream firing on relay connect/disconnect) drives
  `ChatService`: a message sent while offline is persisted with
  `MessageStatus.sending` (shown as a clock icon) instead of `sent`, and
  `_flushQueue()` re-dispatches every such message - including any image
  attachment bytes, re-read from the locally-saved copy - the moment the
  relay reconnects, in original send order.
- **Image/file attachments in chat** - scoped to images only (not
  arbitrary files). `image_picker` (downsized to maxWidth 1024 /
  quality 70 before sending, since the relay is a plain-text WebSocket) →
  `ChatService.sendImageMessage` saves a local copy via `path_provider`
  and relays the bytes as a base64 sibling field alongside the normal
  `chat_message` JSON payload (not part of `ChatMessage.toJson()` itself,
  since a sender's local file path is meaningless on the receiver's
  filesystem) → the receiving `ChatService.listen()` handler decodes and
  saves its *own* local copy, then persists a `ChatMessage` pointing at
  that. `ChatBubble` renders a thumbnail above the caption when
  `attachmentPath` is set.
- **Local scheduled push notifications** - `NotificationService`
  (`flutter_local_notifications` + `timezone`) schedules a local
  notification 10 minutes before `CallRequest.scheduledFor` the moment a
  trainer approves a request (`CallService.approve`), and cancels it on
  decline. Uses `AndroidScheduleMode.inexactAllowWhileIdle` deliberately -
  exact alarms need `SCHEDULE_EXACT_ALARM`, a separately-user-granted
  permission on Android 12+, which is disproportionate ceremony for a
  "reminder," not a time-critical alarm. Each app schedules its own local
  copy independently (best-effort, not synced) - a scheduling failure
  never blocks the approval flow itself (wrapped in try/catch, logged not
  thrown).

## Known deviation from spec: Join Call no longer gated to a 10-minute window

Spec section D says "10 minutes before scheduled time, both see Join Call
button." The original implementation enforced exactly that
(`now.isAfter(scheduledFor - 10min)`) and was verified working - the first
successful end-to-end LiveKit call in this build happened through that
gate. At explicit candidate request, `_isJoinable` in both apps'
`scheduler_screen.dart`/`requests_screen.dart`/`conversation_screen.dart`
was simplified to just `status == approved`, so Join Call is available
immediately on approval regardless of how far out `scheduledFor` is - to
make live demo recording practical without waiting out real 10-minute
windows between takes. The time-gated version is a one-line revert per
call site if strict spec compliance on this point matters more than demo
convenience.
