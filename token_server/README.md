# token_server

Tiny local Node server used by both Flutter apps. Two jobs:

1. `GET /token?userId=&userName=&roomId=` — mints a [LiveKit](https://livekit.io)
   access token (self-signed JWT) so `guru_app`/`trainer_app` can join a
   LiveKit room, and returns it alongside the LiveKit `url` to connect to.
   No call to LiveKit's API is needed to issue the token; only the actual
   room join talks to LiveKit's edge.
2. WebSocket relay on the same port — pushes chat messages, call-request and
   session-log updates between the two apps in real time, since this is a
   local-first assignment with no shared cloud backend.

> **Why LiveKit and not 100ms?** The assignment's default RTC vendor is
> 100ms; this build swapped to LiveKit mid-assessment (interviewer-approved)
> because 100ms's signup flow required card details. See
> `../DECISIONS.md` ADR #3 and `../AI_LEDGER.md` for the full rationale -
> the token-server shape (self-signed JWT, no Management API call) carried
> over almost unchanged.

## Setup

```bash
cd token_server
npm install
cp .env.example .env
# then edit .env with your LiveKit Cloud project details
# https://cloud.livekit.io  (free tier, no card required at signup)
npm start
```

Server listens on `http://localhost:8090` (HTTP + WebSocket on the same
port). Every platform (Android emulator or physical device) reaches it via
plain `localhost` - a physical device needs `adb reverse tcp:8090 tcp:8090`
first (see root README). The Flutter services already assume `localhost`
(`shared/lib/services/call_config.dart` and `sync_client.dart`).

## Without real LiveKit credentials

If `.env` is left unfilled, `/token` returns a clear 500 explaining what's
missing (see `ARCHITECTURE.md`) - chat and scheduling still work fully
since they don't depend on LiveKit, only the actual video call screen needs
a valid API Key/Secret/URL.

## Quick check

```bash
curl "http://localhost:8090/health"
curl "http://localhost:8090/token?userId=member_dk&userName=DK&roomId=wtf-dev-room"
```
