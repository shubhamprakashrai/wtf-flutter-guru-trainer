# token_server

Tiny local Node server used by both Flutter apps. Two jobs:

1. `GET /token?userId=&role=&roomId=` — mints a 100ms auth token (self-signed
   JWT) so `guru_app`/`trainer_app` can join a 100ms room. No call to 100ms's
   Management API is needed to issue the token; only the actual room join
   talks to 100ms's edge network.
2. WebSocket relay on the same port — pushes chat messages, call-request and
   session-log updates between the two apps in real time, since this is a
   local-first assignment with no shared cloud backend.

## Setup

```bash
cd token_server
npm install
cp .env.example .env
# then edit .env with your 100ms dashboard App Access Key + Secret
# https://dashboard.100ms.live/developer
npm start
```

Server listens on `http://localhost:8090` (HTTP + WebSocket on the same
port). Android emulators reach it via `http://10.0.2.2:8090` — the Flutter
services already handle that (`shared/lib/services/hms_config.dart` and
`sync_client.dart`).

## Without real 100ms credentials

If `.env` is left unfilled, `/token` returns a clear 500 explaining what's
missing (see `ARCHITECTURE.md` for the documented fallback) — chat and
scheduling still work fully since they don't depend on 100ms, only the
actual video call screen needs a valid App Access Key/Secret.

## Quick check

```bash
curl "http://localhost:8090/health"
curl "http://localhost:8090/token?userId=member_dk&role=member&roomId=wtf-dev-room"
```
