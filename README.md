# WTF Flutter Engineer Assessment — Guru App + Trainer App

Two Flutter apps (Member-facing `guru_app`, Trainer-facing `trainer_app`) sharing
a local Dart/Flutter package (`shared/`) for models, services, Bloc state
management and UI, plus a tiny local Node server (`token_server/`) that issues
100ms auth tokens and relays chat/scheduling events between the two apps.

See also: [`ARCHITECTURE.md`](ARCHITECTURE.md), [`DECISIONS.md`](DECISIONS.md),
[`AI_LEDGER.md`](AI_LEDGER.md).

## Prerequisites

- Flutter 3.38+ / Dart 3.10+ (`flutter --version`)
- Node.js 18+ (`node --version`)
- Android Studio emulator (or two: one for each app) or physical devices
- A [100ms](https://dashboard.100ms.live) account — free dev project is fine.
  Video calling is the only feature that needs this; everything else (auth,
  chat, scheduling, session logs) runs fully local without it.

## 1. Start the token server

```bash
cd token_server
npm install
cp .env.example .env
# edit .env: paste your 100ms App Access Key + Secret from
# https://dashboard.100ms.live/developer
npm start
```

Leave this running. It serves on `http://localhost:8090` — every app build
talks to it as plain `localhost`. For an **Android emulator** that just
works. For a **physical Android device** over USB, forward the port first:

```bash
adb reverse tcp:8090 tcp:8090
# repeat with -s <device-id> if you have more than one device attached
```

(see `shared/lib/services/hms_config.dart` / `sync_client.dart`.)

> **No 100ms account yet?** Chat, scheduling, onboarding and session logs all
> work without it. `/token` will return a clear error until `.env` is filled
> in, and only the "Join Call" screen is blocked. See ARCHITECTURE.md
> "100ms integration" for what's assumed about your dashboard template.

## 2. Run both apps

Two emulators (or one emulator + one physical device) are recommended so you
can drive both sides of chat/scheduling/calling at once.

```bash
# terminal 2 - Member app
cd guru_app
flutter pub get
flutter run

# terminal 3 - Trainer app
cd trainer_app
flutter pub get
flutter run
```

First run of `guru_app`: 2-slide onboarding → create profile (name defaults
to "DK") → auto-assigned to seeded trainer "Aarav".

First run of `trainer_app`: mock login screen → "Log in as Aarav".

Both apps persist locally via Hive, so relaunching skips onboarding/login;
uninstalling (or clearing app storage) shows it again.

## 3. Manual test script

Follow the 9-step script in the assignment brief section 6, or in short:

1. Log in as Aarav on `trainer_app`.
2. Onboard as DK on `guru_app`.
3. DK sends "Hi Coach 👋" from Chat → Aarav sees an unread badge, replies.
4. DK schedules a call for a slot ~5-10 minutes from now with a note.
5. Aarav approves it in Requests → DK sees a system message + can see it
   under "My Requests" as approved.
6. Within 10 minutes of the scheduled time, both tap the camera icon in the
   chat toolbar (or the Requests/My Requests entry) → pre-join device check
   → Join Call.
7. Both see a 2-tile grid; toggle mute/video/flip camera.
8. End Call (either side) → DK rates the session, Aarav adds notes.
9. Open "My Sessions" / "Sessions" → the completed session is on top with
   duration and rating.

## Run tests

```bash
cd shared && flutter test
```

Model/business-logic tests (message serialization, scheduler past-time
validation, session duration calculation) live in `shared/test/` since that's
where the actual logic sits — both apps are thin UI layers over it. See
DECISIONS.md.

## Repo layout

```
wtf_flutter_test/
├─ token_server/     # 100ms token endpoint + WebSocket relay (Node)
├─ shared/            # Flutter package: models, services, blocs, widgets
├─ guru_app/          # Member app
└─ trainer_app/       # Trainer app
```
