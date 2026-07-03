import http from 'node:http';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from 'socket.io';
import {
  resolveDecisionTimeout,
  resolveSubmittedDecisions,
  startGame,
  startNextRound,
  submitDecision,
} from './game.js';
import type { Decision, Player, PublicRoomState, Room } from './types.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const clientDist = path.resolve(__dirname, '../client');
const port = Number(process.env.PORT ?? 4174);
const rooms = new Map<string, Room>();

/** 断线宽限期（毫秒）：断线玩家在此期间可重连回到牌桌，超时后按撤退结算。 */
const DISCONNECT_GRACE_MS = 25_000;
/** 空房回收：所有玩家离线超过此时长的房间将被销毁，防止内存泄漏。 */
const EMPTY_ROOM_TTL_MS = 60_000;
/** 结束房回收：finished 状态房间保留一段时间供查看排名后销毁。 */
const FINISHED_ROOM_TTL_MS = 5 * 60_000;
/** 全局巡检间隔（毫秒）：处理决策超时、断线宽限到期、房间回收。 */
const SWEEP_INTERVAL_MS = 5_000;

/** 单 socket 事件限流：令牌桶容量（允许的突发事件数）。 */
const RATE_BURST = 20;
/** 单 socket 事件限流：每秒回填令牌数（稳态允许的事件速率）。 */
const RATE_REFILL_PER_SEC = 10;

/**
 * CORS 来源白名单。生产环境通过 CORS_ORIGINS 环境变量传入逗号分隔的域名；
 * 未配置时回退到本地开发地址，避免像原先 `*` 那样对任意站点敞开。
 */
const corsOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:8088,http://127.0.0.1:8088')
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean);

export function createIncaServer() {
const server = http.createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', `http://${request.headers.host ?? 'localhost'}`);

  // 健康检查端点：供负载均衡 / 容器编排探活，返回进程存活与房间数。
  if (url.pathname === '/health' || url.pathname === '/healthz') {
    response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    response.end(JSON.stringify({ status: 'ok', rooms: rooms.size, uptime: process.uptime() }));
    return;
  }

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
  // 生产环境通过 CORS_ORIGINS 锁定来源；未配置时回退为放开（仅供本地开发）。
  cors: { origin: corsOrigins.length > 0 ? corsOrigins : '*' },
});

io.on('connection', (socket) => {
  let playerId: string | null = null;
  let roomCode: string | null = null;

  // 每 socket 令牌桶限流：防止恶意客户端 emit 洪水。
  // 容量 RATE_BURST，按 RATE_REFILL_PER_SEC 匀速回填；耗尽时丢弃事件并回错误。
  let tokens = RATE_BURST;
  let lastRefill = Date.now();
  function tooFast(): boolean {
    const now = Date.now();
    tokens = Math.min(RATE_BURST, tokens + ((now - lastRefill) / 1000) * RATE_REFILL_PER_SEC);
    lastRefill = now;
    if (tokens < 1) {
      emitError(socket, new Error('操作过于频繁，请稍候'));
      return true;
    }
    tokens -= 1;
    return false;
  }

  socket.on('createRoom', (payload: { nickname?: string }) => {
    if (tooFast()) return;
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

  socket.on('joinRoom', (payload: { roomCode?: string; nickname?: string; playerId?: string }) => {
    if (tooFast()) return;
    try {
      const code = normalizeRoomCode(payload.roomCode);
      const room = getRoom(code);

      // 优先按持久化的 playerId 重连：允许在游戏进行中回到原座位。
      const rejoining = payload.playerId
        ? room.players.find((item) => item.id === payload.playerId)
        : undefined;

      if (rejoining) {
        rejoining.socketId = socket.id;
        rejoining.connected = true;
        rejoining.disconnectedAt = null;
        playerId = rejoining.id;
        roomCode = code;
        touch(room);
        socket.join(code);
        socket.emit('roomJoined', { roomCode: code, playerId: rejoining.id });
        pushSystemLog(room, `${rejoining.nickname} 重新连接。`);
        broadcastRoom(room);
        return;
      }

      // 新玩家加入：仅在等待阶段允许。
      const nickname = normalizeNickname(payload.nickname);
      if (room.status !== 'waiting') throw new Error('房间已开始，暂不允许加入');
      if (room.players.length >= 8) throw new Error('房间已满');
      if (room.players.some((item) => item.nickname === nickname && item.connected)) {
        throw new Error('昵称已被占用');
      }

      const player = createPlayer(socket.id, nickname, false);
      room.players.push(player);
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
    if (tooFast()) return;
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
    if (tooFast()) return;
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
    if (tooFast()) return;
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

    // 不立即判撤退：仅标记离线并起宽限计时，给玩家 RECONNECT_GRACE_MS 的重连窗口。
    // 宽限期到点仍未回来，由全局 sweep 定时器兜底处理（active 玩家自动撤退、房主迁移）。
    player.connected = false;
    player.disconnectedAt = Date.now();

    if (room.status === 'waiting') {
      // 等待阶段直接移除未开始的离线玩家，避免占位。
      room.players = room.players.filter((item) => item.id !== player.id);
      if (room.players.length > 0 && player.isHost) {
        promoteNewHost(room);
      }
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

// 全局巡检：决策超时结算、断线宽限到期处理、房间回收。
const sweep = setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    let changed = false;

    // 1) 断线宽限到期：仍未回来的活跃玩家自动撤退，掉线房主迁移。
    if (room.status === 'playing') {
      const expired = room.players.filter(
        (player) =>
          !player.connected &&
          player.disconnectedAt != null &&
          now - player.disconnectedAt >= DISCONNECT_GRACE_MS,
      );
      for (const player of expired) {
        if (player.status === 'active') {
          player.submittedDecision = 'leave';
          changed = true;
        }
        if (player.isHost) {
          promoteNewHost(room);
          changed = true;
        }
        // 标记已处理，避免重复结算。
        player.disconnectedAt = null;
      }
      if (changed) {
        resolveSubmittedDecisions(room);
      }
    }

    // 2) 决策超时：等待过久则把未提交者默认撤退并结算。
    if (resolveDecisionTimeout(room)) {
      changed = true;
    }

    // 3) 房间回收：结束房超时、或全员离线超时的房间销毁，防止内存泄漏。
    const everyoneOffline = room.players.every((player) => !player.connected);
    const emptyExpired = everyoneOffline && now - room.updatedAt >= EMPTY_ROOM_TTL_MS;
    const finishedExpired =
      room.status === 'finished' && now - room.updatedAt >= FINISHED_ROOM_TTL_MS;
    if (room.players.length === 0 || emptyExpired || finishedExpired) {
      rooms.delete(code);
      continue;
    }

    if (changed) {
      touch(room);
      broadcastRoom(room);
    }
  }
}, SWEEP_INTERVAL_MS);
sweep.unref?.();

return { server, io, sweep };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { server, io, sweep } = createIncaServer();
  server.listen(port, () => {
    console.log(`Inca Treasure server listening on http://127.0.0.1:${port}`);
  });

  // 优雅关闭：容器 / 编排器发来 SIGTERM/SIGINT 时，停掉巡检定时器、
  // 关闭 socket 连接与 HTTP server，给正在进行的请求留出收尾时间。
  let shuttingDown = false;
  const shutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Received ${signal}, shutting down gracefully...`);
    clearInterval(sweep);
    io.close();
    server.close(() => process.exit(0));
    // 兜底：10s 内未能正常关闭则强制退出，避免进程挂死。
    setTimeout(() => process.exit(1), 10_000).unref?.();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
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
    disconnectedAt: null,
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

/** 把房主身份转交给第一个仍在线的玩家；无人在线则转给第一个玩家占位。 */
function promoteNewHost(room: Room): void {
  const current = room.players.find((item) => item.id === room.hostPlayerId);
  if (current && current.connected) return; // 现任房主仍在线，无需迁移。

  const next = room.players.find((item) => item.connected) ?? room.players[0];
  if (!next) return;

  room.players.forEach((item) => {
    item.isHost = item.id === next.id;
  });
  room.hostPlayerId = next.id;
  pushSystemLog(room, `${next.nickname} 成为新的房主。`);
}

/** 向房间的游戏日志写入一条系统消息（游戏未开始时静默跳过）。 */
function pushSystemLog(room: Room, text: string): void {
  const game = room.game;
  if (!game) return;
  game.logs.unshift({ id: `${Date.now()}-${Math.random().toString(16).slice(2)}`, text });
  game.logs = game.logs.slice(0, 8);
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
