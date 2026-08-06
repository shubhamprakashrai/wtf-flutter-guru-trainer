// Minimal local server for the WTF Flutter assignment.
//
// Two jobs, one process:
//  1) GET /token - issues a 100ms "app token" (self-signed JWT) for a given
//     userId/role/roomId, following 100ms's documented auth-token schema
//     (https://www.100ms.live/docs/get-started/v2/get-started/foundation/security-and-tokens).
//     This is the "minimal token server" approach the assignment allows in
//     lieu of calling 100ms's Management API - no network round-trip to
//     100ms is needed to mint a token, only the Room join itself talks to
//     100ms's edge.
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
const APP_ACCESS_KEY = process.env.HMS_APP_ACCESS_KEY || '';
const APP_SECRET = process.env.HMS_APP_SECRET || '';

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
    hmsConfigured: Boolean(APP_ACCESS_KEY && APP_SECRET),
    appAccessKey: maskKey(APP_ACCESS_KEY),
  });
});

app.get('/token', (req, res) => {
  const { userId, role, roomId } = req.query;

  if (!userId || !role || !roomId) {
    return res.status(400).json({ error: 'userId, role and roomId query params are required' });
  }
  if (!APP_ACCESS_KEY || !APP_SECRET) {
    return res.status(500).json({
      error:
        'Token server is missing HMS_APP_ACCESS_KEY/HMS_APP_SECRET. Copy .env.example to .env and fill in your 100ms dashboard credentials.',
    });
  }

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    access_key: APP_ACCESS_KEY,
    room_id: roomId,
    user_id: userId,
    role,
    type: 'app',
    version: 2,
    iat: now,
    nbf: now,
    exp: now + 60 * 60 * 24, // 24h, generous for a dev/take-home token
    jti: uuidv4(),
  };

  const token = jwt.sign(payload, APP_SECRET, { algorithm: 'HS256' });
  console.log(`[token] issued for userId=${userId} role=${role} roomId=${roomId}`);
  res.json({ token });
});

const server = app.listen(PORT, () => {
  console.log(`token_server listening on http://localhost:${PORT}`);
  console.log(`  - GET /token?userId=&role=&roomId=`);
  console.log(`  - WS  ws://localhost:${PORT} (chat/schedule relay)`);
  if (!APP_ACCESS_KEY || !APP_SECRET) {
    console.warn('  ! HMS_APP_ACCESS_KEY / HMS_APP_SECRET not set - /token will 500 until .env is filled in.');
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
