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
        ▼                          LogService, SyncClient, CallManager.
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

## Video calling (LiveKit)

> **Why LiveKit and not 100ms?** The assignment's default/required RTC
> vendor is 100ms, and this build's 100ms integration was fully implemented
> first (HMSSDK join/preview/mute/reconnect, matching UI). Every attempt to
> actually get a usable 100ms App Access Key, though, hit a signup flow that
> required card details before a project could be created - not a paid
> feature gate, the *account creation itself*. That was raised with, and
> explicitly approved by, the interviewer and HR before swapping to
> LiveKit. See DECISIONS.md ADR #3 and AI_LEDGER.md for the full trail. The
> architecture below is a like-for-like port of the original 100ms design -
> same token-server shape, same single-dev-room shortcut, same
> `ChangeNotifier`-wrapped call manager - just retargeted at a different
> WebRTC SFU.

**Token generation.** `token_server/server.js` exposes
`GET /token?userId=&userName=&roomId=`, which self-signs a JWT with the
grant shape LiveKit's SDKs expect (`iss` = API Key, `sub` = participant
identity, `video: { room, roomJoin, canPublish, canSubscribe }`,
`nbf`/`exp`/`jti`), signed with your LiveKit API Secret. This avoids any
network round-trip to LiveKit just to mint a token - the only call to
LiveKit's infrastructure is the actual room join, against the `LIVEKIT_URL`
the same endpoint returns alongside the token. This is the "minimal token
server" the assignment explicitly allows in place of a full
Management-API-backed server (LiveKit's server SDKs exist for this too;
self-signing is used here for the same reason as the original 100ms plan -
fewer moving parts for a local dev build).

**Rooms.** Rather than provisioning a new LiveKit room per approved call,
every approved `CallRequest` reuses a single persistent dev room
(`CallConfig.devRoomId = 'wtf-dev-room'`, see
`shared/lib/services/call_config.dart`) - LiveKit creates a room on first
join automatically, so there's no room-provisioning API call needed at all
for this shortcut, even less ceremony than the 100ms version had. `RoomMeta`
just maps a `CallRequest` to that room id so swapping in per-call room
provisioning later is a one-function change in `CallService.approve`.

**Permissions.** LiveKit doesn't have 100ms-style named dashboard roles;
permissions (`canPublish`/`canSubscribe`/`roomJoin`) are grants baked
directly into each token by the token server, identical for member and
trainer in this build. The spec's "member cannot end for both" is
satisfied the same way it would have been under 100ms: both roles get the
same in-call button set (`Room.disconnect()` only ever leaves the *local*
participant), and a real per-role restriction on ending the room for
everyone would need a server-side moderation call this local build doesn't
implement - documented as-scoped, acceptable per spec ("fine if SDK
limits").

**Client flow.** `CallManager` (`shared/lib/services/call_manager.dart`)
wraps LiveKit's `Room`, which is itself a `ChangeNotifier` - `CallManager`
mostly just re-exposes it with the same shape the UI expected from the
100ms version. `startPreview()` creates a standalone camera track
(`LocalVideoTrack.createCameraTrack`) for the pre-join device-check screen
without connecting to any room; `connect()` disposes that preview track and
calls `room.connect(url, token, fastConnectOptions: ...)` to publish
fresh mic/camera tracks and join. `room.connectionState` (LiveKit's own
`disconnected/connecting/reconnecting/connected` enum) drives the
reconnecting banner directly; mute/video toggle call
`localParticipant.setMicrophoneEnabled`/`setCameraEnabled`; camera flip
calls `LocalVideoTrack.setCameraPosition`.

## What's intentionally out of scope

See DECISIONS.md and the assignment's "No excuses" clause - image
attachments, push notifications, and an offline send queue are stubbed out
in the UI copy/quick-replies rather than implemented; the app is fully usable
without them and they're flagged as stretch goals only.
