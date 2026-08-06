# AI Ledger

This entire repo was built in a single AI-native pairing session using
**Claude Code** (Claude Sonnet 5) as the primary development agent. The
candidate directed scope/priorities and made the calls Claude Code
flagged (state-management choice, GitHub timing); Claude Code did the
research, scaffolding, implementation, self-review (`flutter analyze`),
and test-writing. Entries below are in chronological order; "Output" is a
summary since actual output was thousands of lines of code, not a
paste-able snippet.

---

### 1. Prompt: full assignment spec + "how should I approach this, then let's build it one piece at a time, keep it on Desktop"

**Tool:** Claude Code (Sonnet 5) **Intent:** turn a 6-hour, 100+ requirement
assessment brief into an executable build plan under real constraints
(no cloud backend, 100ms mandatory, two Flutter apps).
**Output:** Verified local tooling (`flutter --version`, `node --version`),
proposed a priority order (hard-fail items first: 100ms + AI ledger), then
proceeded on "kro" (go ahead) into scaffolding `wtf_flutter_test/` with
`token_server/`, `shared/`, `guru_app/`, `trainer_app/` per the required
repo layout.

### 2. Prompt (implicit, from spec): shared data models

**Intent:** "Data Model (minimum)" section → generate `User`, `Message`,
`CallRequest`, `SessionLog`, `RoomMeta` as plain Dart classes with
`toJson`/`fromJson`, storable in Hive without codegen.
**Output:** `shared/lib/models/*.dart` — 5 model files with enum helpers
(`userRoleFromString`, `messageStatusFromString`, etc.) and validation
statics (`CallRequest.validateScheduledFor`, `SessionLog.computeDurationSec`)
that the unit tests later exercise directly.

### 3. Prompt (implicit, from spec section 5): "minimal token server ... include minimal token server or 100ms recommended dev approach"

**Intent:** build `token_server/` without guessing at 100ms's token schema.
**Output:** Claude Code wrote a self-signed-JWT `/token` endpoint matching
100ms's documented app-token claim shape (`access_key`, `room_id`,
`user_id`, `role`, `type: app`, `version: 2`), then **smoke-tested it live**
(`node server.js &`, `curl /health`, `curl /token?...`) in the same turn to
confirm the JWT actually generates before moving on, rather than assuming
it was correct.

### 4. Correction: "state bloc use kro" (use Bloc, not Riverpod)

**Tool:** Claude Code **Intent:** refactor with AI. At this point
`guru_app` already had `flutter_riverpod`-based screens (`ConsumerStatefulWidget`,
`Provider`, a `StateProvider` tick to force auth-state rebuilds).
**Before:** DI via `Provider<Services>`, manual `authTickProvider` bump after
mock login/onboarding to force a rebuild since `AuthService` wasn't itself
reactive.
**After:** `RepositoryProvider<AppServices>` for DI + four `Cubit`s
(`AuthCubit`, `ChatCubit`, `CallCubit`, `SessionLogCubit` in
`shared/lib/blocs/`) wrapping each service's stream and emitting typed UI
state, consumed via `BlocBuilder`/`BlocConsumer`. Recorded as ADR #1 in
DECISIONS.md, including *why* Cubits stayed thin (the real complexity is in
the services, not UI state) and why `HmsCallManager` deliberately stayed a
`ChangeNotifier` instead (100ms's listener interfaces are callback-shaped,
not event-shaped).

### 5. Prompt (implicit): integrate 100ms without web access to current docs

**Intent:** debugging/research with AI, doc-free. `WebFetch`/`WebSearch`
weren't used; instead Claude Code located the installed
`hmssdk_flutter-1.11.1` package under `~/.pub-cache` and **read the actual
SDK source** (`hmssdk.dart`, `hms_config.dart`, `hms_update_listener.dart`,
`hms_video_view.dart`, the bundled example's `AndroidManifest.xml`/
`Info.plist`) to get exact method signatures (`build()`, `preview()`,
`join()`, the full `HMSUpdateListener`/`HMSPreviewListener` interfaces,
`minSdk 24` requirement) rather than guessing at an API surface.
**Output:** `shared/lib/services/hms_call_manager.dart` (join/preview/
leave/mute/camera-flip/reconnect handling implementing both listener
interfaces) + `shared/lib/widgets/call_widgets.dart` (participant tiles,
control buttons, reconnecting banner) + `guru_app/lib/screens/call/
pre_join_screen.dart` and `in_call_screen.dart`.

### 6. Prompt (implicit, spec section D): SessionLog id collision across two independent apps

**Intent:** debugging with AI, caught before it shipped, not after.
While wiring `InCallScreen`, Claude Code noticed that both apps calling
`LogService.startSession(...)` independently would create **two different
Hive records with two different UUIDs** for the same call, since there was
no start-of-call sync event - only end/feedback/notes synced.
**Fix:** changed `startSession`'s signature to take a caller-supplied
deterministic `id` (the `RoomMeta`/`CallRequest` id) instead of generating a
UUID internally, so both apps' `InCallScreen` converge on the same Hive key
from the moment either side joins. Documented as a deliberate simplification
in ARCHITECTURE.md rather than silently left as a landmine.

### 7. Prompt (implicit): copy guru_app's role-agnostic screens into trainer_app

**Intent:** avoid re-deriving already-correct logic. `conversation_screen.dart`,
`pre_join_screen.dart`, `in_call_screen.dart`, `session_logs_screen.dart` are
identical in *logic* between the two apps (both branch on
`AuthCubit.state.user.role` at runtime); Claude Code copied the files rather
than reimplementing, then targetedly edited the two spots that differ per
role: `in_call_screen.dart`'s post-call sheet (rating vs. trainer notes) and
`session_logs_screen.dart`'s Cubit scope (`memberId:` vs `trainerId:`).

### 8. Prompt (implicit): trainer-side screens (login, home, members, chat list, requests)

**Intent:** generate the remaining trainer-only UI per spec section 3.A/B/C -
mock login as seeded "Aarav", 4-tile home, member roster, chat list with
unread badges, and the approve/decline Requests inbox including the decline-
reason bottom sheet and the "Call approved for {date} {time}" system message
sent into chat on approval.
**Output:** `trainer_app/lib/screens/{login,home,members,chat_list,
requests}_screen.dart`.

### 9. Debugging with AI: stale `flutter_riverpod` dependency survived the Bloc refactor

**Error:** after finishing `trainer_app`'s screens and running
`flutter pub get`, the dependency diff showed `flutter_riverpod`/`riverpod`/
`state_notifier` still resolving - `trainer_app/pubspec.yaml` had been
scaffolded *before* the Bloc switch (entry #4) and was never touched by that
refactor, unlike `guru_app`'s.
**Fix:** swapped the leftover `flutter_riverpod: ^2.6.1` line for
`flutter_bloc: ^9.1.1` + `permission_handler`, re-ran `pub get`, confirmed
the "no longer being depended on" list showed exactly the three riverpod
packages disappearing.

### 10. Debugging with AI: `flutter analyze` lint cleanup across all three packages

**Intent:** spec requires "zero warnings in final build."
**Errors fixed:** unused `time_ext.dart` import in `chat_bubble.dart`;
unnecessary string-interpolation braces; unnecessary multi-underscore lambda
params (`_, __` → named); `unintended_html_in_doc_comment` from a bare
`Map<String,dynamic>` in a doc comment; `HMSVideoView`'s deprecated
`matchParent` parameter; two `use_build_context_synchronously` warnings in
`pre_join_screen.dart`/`in_call_screen.dart` fixed by adding `if (!mounted)
return;` immediately after the awaited call rather than only at the end of
the function; a stale `test/widget_test.dart` referencing a deleted `MyApp`
class, removed since its default counter-app content no longer applied.
**Result:** `flutter analyze` → "No issues found!" on `shared`, `guru_app`,
and `trainer_app` independently.

### 11. Prompt (implicit, spec section 6): unit tests

**Intent:** "Message serialization/deserialization. Scheduler validation (no
past time). Log duration calculation."
**Output:** `shared/test/{chat_message,call_request,session_log}_test.dart`
- 13 tests, run via `flutter test`, all passing on first run. Written to
exercise the exact static helpers added in entry #2
(`ChatMessage.chatIdFor`'s order-independence, `CallRequest
.validateScheduledFor`'s past/now/future boundary, `SessionLog
.computeDurationSec`'s negative-duration clock-skew fallback).

### 12. Prompt (implicit): README / ARCHITECTURE / DECISIONS

**Intent:** docs-with-AI. Rather than generic boilerplate, Claude Code wrote
these to reflect what actually happened in this session - including the
mid-build Riverpod→Bloc switch as ADR #1 with its real trade-off, the
SessionLog id-collision fix as part of the sync-architecture writeup, and
an explicit "what's assumed about your 100ms dashboard template" fallback
note for the self-signed-token approach, since that can't be verified
without live 100ms credentials.

### 13. Debugging with AI: real-device run exposed an emulator-only assumption

**Error:** after pushing to GitHub, testing moved from an Android emulator to
a physical Android phone connected over USB (the emulator's AVD had run out
of `/data` storage - `INSTALL_FAILED_INSUFFICIENT_STORAGE` - mid-session and
a wipe/cold-boot didn't come back up in time, so the candidate said "run it
on the physical device instead"). `guru_app` built and installed fine, but
`SyncClient`/`HmsConfig` hard-coded the `10.0.2.2` alias for all Android
targets - which only resolves inside the emulator's virtual router, not on
real hardware, so the WebSocket relay would have silently never connected
on-device.
**Fix:** both classes now always dial plain `localhost`; the physical
device reaches it via `adb reverse tcp:8090 tcp:8090` (documented in
README's setup steps), which also works for emulators, so one code path
covers both. Verified live: `guru_app` and `trainer_app` installed and run
*simultaneously* on the same physical phone (Android 15, package names
`com.wtf.guru_app` / `com.wtf.trainer_app` don't collide), both logging
`[CHAT] sync connected to localhost:8090` with no crashes in `adb logcat`
output streamed through `flutter run`.

---

## Repo proof

Commit bodies reference these ledger entries (Conventional Commits, e.g.
`feat: implement guru_app member flows` with a body noting which ledger
entry it corresponds to) - see `git log`.
