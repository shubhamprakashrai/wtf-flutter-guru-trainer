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
exist and `HmsCallManager` (the actual call state machine) is a
`ChangeNotifier`, not a Cubit, because it has to implement 100ms's
`HMSUpdateListener`/`HMSPreviewListener` interfaces, which are
callback-shaped rather than event-shaped - forcing it into a Cubit would
mean hand-translating every SDK callback into a "fire an event, wait for the
new state" round-trip for no behavioral benefit.

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

## ADR #3 — RTC strategy: 100ms self-signed dev token + single persistent room + WebSocket relay for app-to-app sync

**Decision:** see ARCHITECTURE.md "100ms integration" for the full
rationale. Summary of the three sub-decisions:

1. **Token minting** happens locally in `token_server/` by self-signing a
   JWT with the 100ms App Access Key/Secret, rather than calling 100ms's
   Management API - fewer moving parts, and the assignment explicitly
   allows a "minimal token server."
2. **One dev room reused for every call** rather than provisioning a room
   per `CallRequest` via the Management API - this is 100ms's own
   recommended shortcut for take-home/dev builds.
3. **A WebSocket relay** (same Node process as the token server) is the
   *only* way `guru_app` and `trainer_app` learn about each other's chat
   messages, approvals, and session-log updates, since the assignment rules
   out a shared cloud backend for app data. This is separate from 100ms
   itself, which only carries the actual audio/video.

**Fallback documented, not implemented:** if a reviewer's 100ms project only
accepts Room-Code-based tokens (newer dashboard default) rather than
directly-signed app tokens, `/token`'s implementation needs to switch to
calling 100ms's Management API - flagged in ARCHITECTURE.md rather than
guessed at, since it depends on dashboard configuration this build can't
see.

## Explicitly skipped (per assignment's "No excuses" clause)

- **Image/file attachments in chat** - UI has quick-reply chips and a text
  composer only. Fallback: not implemented; would need `image_picker` +
  either base64-in-Hive or a shared file relay, both meaningful scope adds.
- **Local scheduled push notifications** - not implemented; the in-app
  "Join Call" badge (camera icon w/ dot) covers the 10-minutes-before
  affordance the spec asks for without needing OS notification permissions.
- **Offline send queue for chat** - messages are written to Hive
  synchronously before the relay send, so they survive an app restart, but
  there's no retry/backoff if the relay is down when a message is sent -
  it simply won't reach the other app until both are online again.
- **Light/Dark theme toggle** - single light theme per app (spec's fixed
  brand colors), no toggle.
