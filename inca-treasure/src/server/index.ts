import http from 'node:http';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from 'socket.io';
import { resolveSubmittedDecisions, startGame, startNextRound, submitDecision } from './game.js';
import type { Decision, Player, PublicRoomState, Room } from './types.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const clientDist = path.resolve(__dirname, '../client');
const port = Number(process.env.PORT ?? 4174);
const rooms = new Map<string, Room>();

export function createIncaServer() {
const server = http.createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', `http://${request.headers.host ?? 'localhost'}`);
  const pathname = url.pathname === '/' ? '/index.html' : url.pathname;
  const target = path.join(clientDist, pathname);

  if (!target.startsWith(clientDist) || !existsSync(target)) {
    response.writeHead(404);
    response.end('Not found');
    return;
  }

  const body = await readFile(target);
  response.writeHead(200, { 'content-type': contentType(target) });
  response.end(body);
});

const io = new Server(server, {
  cors: { origin: '*' },
});

io.on('connection', (socket) => {
  let playerId: string | null = null;
  let roomCode: string | null = null;

  socket.on('createRoom', (payload: { nickname?: string }) => {
    try {
      const nickname = normalizeNickname(payload.nickname);
      const code = createRoomCode();
      const player = createPlayer(socket.id, nickname, true);
      const room: Room = {
        roomCode: code,
        status: 'waiting',
        hostPlayerId: player.id,
        players: [player],
        game: null,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      rooms.set(code, room);
      playerId = player.id;
      roomCode = code;
      socket.join(code);
      socket.emit('roomJoined', { roomCode: code, playerId: player.id });
      broadcastRoom(room);
    } catch (error) {
      emitError(socket, error);
    }
  });

  socket.on('joinRoom', (payload: { roomCode?: string; nickname?: string }) => {
    try {
      const code = normalizeRoomCode(payload.roomCode);
      const nickname = normalizeNickname(payload.nickname);
      const room = getRoom(code);
      if (room.status !== 'waiting') throw new Error('房间已开始，暂不允许加入');
      if (room.players.length >= 8) throw new Error('房间已满');

      const existing = room.players.find((item) => item.nickname === nickname && !item.connected);
      const player = existing ?? createPlayer(socket.id, nickname, false);
      player.socketId = socket.id;
      player.connected = true;
      if (!existing) room.players.push(player);
      playerId = player.id;
      roomCode = code;
      touch(room);
      socket.join(code);
      socket.emit('roomJoined', { roomCode: code, playerId: player.id });
      broadcastRoom(room);
    } catch (error) {
      emitError(socket, error);
    }
  });

  socket.on('startGame', () => {
    try {
      const room = getCurrentRoom(roomCode);
      assertHost(room, playerId);
      if (room.players.length < 2) throw new Error('至少需要 2 名玩家开始');
      startGame(room);
      touch(room);
      broadcastRoom(room);
    } catch (error) {
      emitError(socket, error);
    }
  });

  socket.on('submitDecision', (payload: { decision?: Decision }) => {
    try {
      const room = getCurrentRoom(roomCode);
      if (payload.decision !== 'continue' && payload.decision !== 'leave') throw new Error('选择无效');
      if (!playerId) throw new Error('玩家身份无效');
      submitDecision(room, playerId, payload.decision);
      touch(room);
      broadcastRoom(room);
    } catch (error) {
      emitError(socket, error);
    }
  });

  socket.on('nextRound', () => {
    try {
      const room = getCurrentRoom(roomCode);
      assertHost(room, playerId);
      startNextRound(room);
      touch(room);
      broadcastRoom(room);
    } catch (error) {
      emitError(socket, error);
    }
  });

  socket.on('disconnect', () => {
    if (!roomCode || !playerId) return;
    const room = rooms.get(roomCode);
    if (!room) return;
    const player = room.players.find((item) => item.id === playerId);
    if (!player) return;
    player.connected = false;
    if (room.status === 'playing' && player.status === 'active') {
      player.submittedDecision = 'leave';
      resolveSubmittedDecisions(room);
    }
    touch(room);
    broadcastRoom(room);
  });
});

function broadcastRoom(room: Room): void {
  room.players.forEach((player) => {
    io.to(player.socketId).emit('stateUpdated', publicRoom(room, player.id));
  });
}

return { server, io };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { server } = createIncaServer();
  server.listen(port, () => {
    console.log(`Inca Treasure server listening on http://127.0.0.1:${port}`);
  });
}

function publicRoom(room: Room, me: string): PublicRoomState {
  return {
    roomCode: room.roomCode,
    status: room.status,
    hostPlayerId: room.hostPlayerId,
    createdAt: room.createdAt,
    updatedAt: room.updatedAt,
    me,
    players: room.players.map(({ socketId, submittedDecision, ...player }) => ({
      ...player,
      hasSubmitted: Boolean(submittedDecision),
      submittedDecision: null,
    })),
    game: room.game ? publicGame(room.game) : null,
  };
}

function publicGame(game: NonNullable<Room['game']>): PublicRoomState['game'] {
  const { deck, ...visibleGame } = game;
  return {
    ...visibleGame,
    deckCount: deck.length,
  };
}

function createPlayer(socketId: string, nickname: string, isHost: boolean): Player {
  return {
    id: `p_${Math.random().toString(36).slice(2, 10)}`,
    socketId,
    nickname,
    connected: true,
    isHost,
    bankScore: 0,
    temporaryGems: 0,
    status: 'waiting',
    submittedDecision: null,
  };
}

function createRoomCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  for (let attempt = 0; attempt < 100; attempt += 1) {
    let code = '';
    for (let index = 0; index < 4; index += 1) {
      code += alphabet[Math.floor(Math.random() * alphabet.length)];
    }
    if (!rooms.has(code)) return code;
  }
  throw new Error('房间码生成失败');
}

function normalizeNickname(value: unknown): string {
  const nickname = String(value ?? '').trim().slice(0, 12);
  if (!nickname) throw new Error('昵称不能为空');
  return nickname;
}

function normalizeRoomCode(value: unknown): string {
  const code = String(value ?? '').trim().toUpperCase();
  if (!/^[A-Z0-9]{4,6}$/.test(code)) throw new Error('房间码格式错误');
  return code;
}

function getRoom(code: string): Room {
  const room = rooms.get(code);
  if (!room) throw new Error('房间不存在');
  return room;
}

function getCurrentRoom(code: string | null): Room {
  if (!code) throw new Error('尚未加入房间');
  return getRoom(code);
}

function assertHost(room: Room, id: string | null): void {
  if (!id || room.hostPlayerId !== id) throw new Error('只有房主可以操作');
}

function touch(room: Room): void {
  room.updatedAt = Date.now();
}

function emitError(socket: { emit: (event: string, payload: { message: string }) => void }, error: unknown): void {
  socket.emit('errorMessage', { message: error instanceof Error ? error.message : '未知错误' });
}

function contentType(filePath: string): string {
  if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
  if (filePath.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (filePath.endsWith('.css')) return 'text/css; charset=utf-8';
  if (filePath.endsWith('.svg')) return 'image/svg+xml';
  return 'application/octet-stream';
}
