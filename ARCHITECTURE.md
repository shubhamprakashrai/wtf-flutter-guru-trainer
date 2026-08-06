# Architecture

## Layers

```
guru_app/lib, trainer_app/lib     -- screens (StatefulWidget) + Cubit wiring
        │  reads/creates
        ▼
shared/lib/blocs/*                -- Cubits: AuthCubit, ChatCubit, CallCubit,
        │  wraps                      SessionLogCubit. One Cubit instance per
        ▼                             screen/scope, thin - just adapts a
shared/lib/services/*             -- service stream to Bloc state.
        │  reads/writes            AuthService, ChatService, CallService,
        ▼                          LogService, SyncClient, HmsCallManager.
shared/lib/models/*                Pure Dart, no Flutter/Bloc dependency.
        │
        ▼
Hive (local disk)  +  token_server WebSocket relay (cross-app realtime)
```

Both apps depend on `shared` via a `path:` pubspec dependency (a real local
Flutter package, not copy-pasted code), which is also why `shared/widgets/`
holds every visual component used by both apps (chat bubbles, cards, call
grid, schedule chips, DevPanel) - `guru_app`/`trainer_app` only contain
screens and app-specific wiring (theme color, entry screen, navigation).

## Local-first data + "real-time" sync

There is no backend database. Each app persists its own copy of everything
in Hive (`shared/lib/services/storage_service.dart`), storing models as plain
`Map<String,dynamic>` via `toJson`/`fromJson` - no generated Hive
`TypeAdapter`s, so there's no `build_runner` step slowing down iteration.

Because `guru_app` and `trainer_app` are two separate OS processes (two
emulators, or an emulator + a device) with no shared storage, "real-time chat"
and "call request approved instantly" are implemented with a tiny WebSocket
relay in `token_server/server.js`: both apps connect to
`ws://<host>:8090` and broadcast events (`chat_message`, `chat_read`,
`call_request`, `room_meta`, `session_log`) to each other. Each app applies
incoming events to its own Hive boxes (`shared/lib/services/sync_client.dart`
+ each service's `listen()`). This is why the token server has to be running
for cross-app features to feel live - without it, each app still works fully
standalone (send-to-self, local session logs, etc.), it just won't see the
other side's updates until the relay reconnects.

`SessionLog` is the one place this needed a deliberate choice: both the
member's and trainer's app independently "start a session" the moment they
join the call. Instead of syncing a `session_started` event and racing to
see who wins, `LogService.startSession` takes an explicit deterministic `id`
- the call's `RoomMeta`/`CallRequest` id - so both apps write to the *same*
Hive key from the start. `endSession`/`addMemberFeedback`/`addTrainerNotes`
then broadcast their updates over the relay so both sides converge on one
record instead of ending up with two.

## 100ms integration

**Token generation.** `token_server/server.js` exposes
`GET /token?userId=&role=&roomId=`, which self-signs a JWT with the shape
100ms's SDK expects for an "app token" (`access_key`, `room_id`, `user_id`,
`role`, `type: "app"`, `version: 2`, `iat`/`exp`/`jti`), signed with your
100ms App Secret. This avoids a network round-trip to 100ms's Management API
just to mint a token - the only call to 100ms's infrastructure is the actual
room join. This is the "minimal token server" the assignment explicitly
allows in place of a full Management-API-backed server.

**Assumption / fallback:** self-signed app tokens require your 100ms
dashboard template to accept directly-signed tokens rather than requiring
Room-Code-based auth. If your project only supports Room Codes, swap
`/token` in `token_server/server.js` for a call to 100ms's
`POST /v2/room-codes/room/:room_id` (Management API) instead - the Flutter
side (`CallService.fetchHmsToken`) doesn't need to change, only the server
route's implementation.

**Rooms.** Rather than provisioning a new 100ms room per approved call via
the Management API, every approved `CallRequest` reuses a single persistent
dev room (`HmsConfig.devRoomId = 'wtf-dev-room'`, see
`shared/lib/services/hms_config.dart`). This is the 100ms-recommended
shortcut for dev/take-home projects. `RoomMeta` still models a per-request
room (`hmsRoomId`, `hmsRoleMember`, `hmsRoleTrainer`) so swapping in real
per-call room provisioning later is a one-function change in
`CallService.approve`.

**Roles.** The token's `role` field is `"member"` or `"trainer"`
(`shared/lib/screens/call/pre_join_screen.dart` maps `UserRole` → that
string). These must exist as Role names in your 100ms dashboard template -
the default 100ms template ships with `host`/`guest` instead, so either
rename roles in the dashboard or adjust the two string literals in
`pre_join_screen.dart` to match your template.

**Client flow.** `HmsCallManager` (`shared/lib/services/hms_call_manager.dart`)
wraps `HMSSDK`: `startPreview()` warms up camera/mic for the pre-join device
check screen without publishing to the room, then `join()` on the same SDK
instance transitions straight into the call reusing those tracks.
`onReconnecting`/`onReconnected` drive a banner in `InCallScreen`; mute/video
toggle and camera flip call straight through to the SDK; `onPeerListUpdate`/
`onTrackUpdate` keep the 2-tile grid current as people/tracks change.

**Permission scoping (spec: "member cannot end for both").** Both roles get
the same in-call button set in this build - the SDK-level distinction 100ms
would use for that (role-scoped end-room permission, `endRoom` vs `leave`)
needs a matching Role permission set in the dashboard, which isn't something
this local build can configure. Documenting as-scoped: acceptable per spec
("fine if SDK limits").

## What's intentionally out of scope

See DECISIONS.md and the assignment's "No excuses" clause - image
attachments, push notifications, and an offline send queue are stubbed out
in the UI copy/quick-replies rather than implemented; the app is fully usable
without them and they're flagged as stretch goals only.
