// Minimal local server for the WTF Flutter assignment.
//
// Two jobs, one process:
//  1) GET /token - issues a LiveKit access token (self-signed JWT) for a
//     given userId/roomId, following LiveKit's documented access-token
//     grant schema (https://docs.livekit.io/home/get-started/authentication/).
//     No network round-trip to LiveKit is needed to mint a token - only the
//     Room join itself talks to LiveKit's edge (LIVEKIT_URL).
//
//     Originally built against 100ms (assignment's default RTC vendor);
//     swapped to LiveKit mid-assessment with interviewer sign-off after
//     100ms's signup flow asked for card details - see AI_LEDGER.md and
//     DECISIONS.md ADR #3 for the full rationale. The self-signed-JWT
//     "minimal token server" shape carried over almost unchanged.
//  2) A WebSocket relay so the Guru app and Trainer app - two separate
//     Flutter processes/emulators with no shared backend - can push chat
//     messages, call-request updates and session-log updates to each other
//     in real time while running on the same dev machine (local-first,
//     no cloud project required for app logic).
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT || 8090);
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || '';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || '';
const LIVEKIT_URL = process.env.LIVEKIT_URL || '';

const app = express();
app.use(cors());
app.use(express.json());

function maskKey(key) {
  if (!key) return '(not set)';
  if (key.length <= 8) return '****';
  return `${key.slice(0, 4)}...${key.slice(-4)}`;
}

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    liveKitConfigured: Boolean(LIVEKIT_API_KEY && LIVEKIT_API_SECRET && LIVEKIT_URL),
    apiKey: maskKey(LIVEKIT_API_KEY),
    url: LIVEKIT_URL || '(not set)',
  });
});

app.get('/token', (req, res) => {
  const { userId, userName, roomId } = req.query;

  if (!userId || !roomId) {
    return res.status(400).json({ error: 'userId and roomId query params are required' });
  }
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return res.status(500).json({
      error:
        'Token server is missing LIVEKIT_API_KEY/LIVEKIT_API_SECRET/LIVEKIT_URL. Copy .env.example to .env and fill in your LiveKit Cloud project details.',
    });
  }

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: LIVEKIT_API_KEY,
    sub: userId,
    name: userName || userId,
    nbf: now,
    exp: now + 60 * 60 * 6, // 6h, generous for a dev/take-home token
    jti: uuidv4(),
    video: {
      room: roomId,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    },
  };

  const token = jwt.sign(payload, LIVEKIT_API_SECRET, { algorithm: 'HS256' });
  console.log(`[token] issued for userId=${userId} roomId=${roomId}`);
  res.json({ token, url: LIVEKIT_URL });
});

const server = app.listen(PORT, () => {
  console.log(`token_server listening on http://localhost:${PORT}`);
  console.log(`  - GET /token?userId=&userName=&roomId=`);
  console.log(`  - WS  ws://localhost:${PORT} (chat/schedule relay)`);
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    console.warn('  ! LIVEKIT_API_KEY / LIVEKIT_API_SECRET / LIVEKIT_URL not set - /token will 500 until .env is filled in.');
  }
});

// --- WebSocket relay -------------------------------------------------------
// Dumb fan-out: broadcast every message to every other connected client.
// Both Flutter apps connect here and apply events to their own local Hive
// storage (see shared/lib/services/sync_client.dart).
const wss = new WebSocketServer({ server });

wss.on('connection', (socket) => {
  console.log(`[relay] client connected (${wss.clients.size} total)`);

  socket.on('message', (data) => {
    for (const client of wss.clients) {
      if (client !== socket && client.readyState === client.OPEN) {
        client.send(data.toString());
      }
    }
  });

  socket.on('close', () => {
    console.log(`[relay] client disconnected (${wss.clients.size} total)`);
  });
});
