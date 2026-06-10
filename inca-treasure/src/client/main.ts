declare const io: () => Socket;

type Socket = {
  connected: boolean;
  emit: (event: string, payload?: unknown) => void;
  on: (event: string, handler: (...args: any[]) => void) => void;
};

type Decision = 'continue' | 'leave';
type RoomStatus = 'waiting' | 'playing' | 'finished';
type GamePhase = 'revealing' | 'waitingDecision' | 'roundEnd' | 'gameEnd';
type PlayerStatus = 'waiting' | 'active' | 'left' | 'busted';
type HazardType = 'snake' | 'fire' | 'rock' | 'spider' | 'curse';

type Card =
  | { type: 'treasure'; value: number }
  | { type: 'hazard'; hazardType: HazardType }
  | { type: 'relic'; value: number };

type PublicPlayer = {
  id: string;
  nickname: string;
  connected: boolean;
  isHost: boolean;
  bankScore: number;
  temporaryGems: number;
  status: PlayerStatus;
  hasSubmitted: boolean;
  submittedDecision: null;
};

type GameLog = { id: string; text: string };

type PublicGameState = {
  round: number;
  phase: GamePhase;
  deckCount: number;
  revealedCards: Card[];
  caveGems: number;
  relics: number[];
  seenHazards: Partial<Record<HazardType, number>>;
  lastCard: Card | null;
  logs: GameLog[];
};

type PublicRoomState = {
  roomCode: string;
  status: RoomStatus;
  hostPlayerId: string;
  players: PublicPlayer[];
  game: PublicGameState | null;
  me: string | null;
};

const hazardNames: Record<HazardType, string> = {
  snake: '毒蛇',
  fire: '火焰',
  rock: '落石',
  spider: '毒蛛',
  curse: '诅咒',
};

const app = document.querySelector<HTMLDivElement>('#app')!;

const socket: Socket = io();
let room: PublicRoomState | null = null;
let errorMessage = '';
let nickname = localStorage.getItem('inca.nickname') ?? '';
let roomCode = new URLSearchParams(window.location.search).get('room')?.trim().toUpperCase() ?? '';

socket.on('roomJoined', (payload: { roomCode: string; playerId: string }) => {
  roomCode = payload.roomCode;
  window.history.replaceState(null, '', invitePath(roomCode));
});

socket.on('stateUpdated', (state: PublicRoomState) => {
  room = state;
  errorMessage = '';
  render();
});

socket.on('errorMessage', (payload: { message: string }) => {
  errorMessage = payload.message;
  render();
});

socket.on('connect', render);
socket.on('disconnect', render);

function render(): void {
  if (!room) {
    renderHome();
    return;
  }
  if (room.status === 'waiting') {
    renderWaitingRoom(room);
    return;
  }
  renderGame(room);
}

function renderHome(): void {
  app.innerHTML = shell(`
    <section class="panel home">
      <div class="field">
        <label for="nickname">昵称</label>
        <input id="nickname" maxlength="12" value="${escapeHtml(nickname)}" placeholder="输入你的探险名" />
      </div>
      <div class="field">
        <label for="roomCode">房间码</label>
        <input id="roomCode" maxlength="6" value="${escapeHtml(roomCode)}" placeholder="加入时填写" />
      </div>
      <div class="home-actions">
        <button id="createRoom" class="action primary">创建房间</button>
        <button id="joinRoom" class="action secondary">加入房间</button>
      </div>
      <p class="muted">每名玩家用自己的手机进入同一房间，同时选择继续或撤退。服务端统一翻牌和结算。</p>
      <p class="error">${escapeHtml(errorMessage)}</p>
    </section>
  `, '房间码对局', '未连接');

  bindInput('#nickname', (value) => {
    nickname = value.trim();
    localStorage.setItem('inca.nickname', nickname);
  });
  bindInput('#roomCode', (value) => {
    roomCode = value.trim().toUpperCase();
  });
  bindClick('#createRoom', () => socket.emit('createRoom', { nickname }));
  bindClick('#joinRoom', () => socket.emit('joinRoom', { nickname, roomCode }));
}

function renderWaitingRoom(state: PublicRoomState): void {
  const me = currentPlayer(state);
  const canStart = me?.isHost && state.players.length >= 2;
  app.innerHTML = shell(`
    <section class="panel room-header">
      <div class="room-code">
        <div>
          <p class="muted">房间码</p>
          <div class="code">${state.roomCode}</div>
        </div>
        <button id="copyCode" class="action secondary">复制邀请</button>
      </div>
      <p class="muted">${state.players.length < 2 ? '至少 2 名玩家才能开始。' : '玩家到齐后由房主开始游戏。'}</p>
      <button id="startGame" class="action primary" ${canStart ? '' : 'disabled'}>${me?.isHost ? '开始游戏' : '等待房主'}</button>
    </section>
    ${playersView(state.players)}
    <p class="error">${escapeHtml(errorMessage)}</p>
  `, '等待房间', `${state.players.length}/8`);

  bindClick('#copyCode', async () => {
    const inviteUrl = `${window.location.origin}${invitePath(state.roomCode)}`;
    await navigator.clipboard?.writeText(inviteUrl);
    errorMessage = '邀请链接已复制';
    render();
  });
  bindClick('#startGame', () => socket.emit('startGame'));
}

function renderGame(state: PublicRoomState): void {
  const game = state.game;
  if (!game) {
    renderWaitingRoom(state);
    return;
  }

  const me = currentPlayer(state);
  const isHost = Boolean(me?.isHost);
  const canDecide = game.phase === 'waitingDecision' && me?.status === 'active' && !me.hasSubmitted;
  const waitingText = waitingDecisionText(state, game, me);
  const ranking = [...state.players].sort((a, b) => b.bankScore - a.bankScore);

  app.innerHTML = shell(`
    ${playersView(state.players)}
    <section class="panel game-board">
      <div class="status-row">
        <div>
          <h2>${phaseTitle(game, me)}</h2>
          <p class="muted">${waitingText}</p>
        </div>
        <div class="stash"><span>通道遗留</span><strong>${game.caveGems}</strong></div>
      </div>
      <div class="card-stage">${cardView(game.lastCard)}</div>
      <div class="path">${game.revealedCards.map(miniCardView).join('')}</div>
      ${game.phase === 'gameEnd' ? rankingView(ranking) : ''}
      <div class="actions">
        ${game.phase === 'waitingDecision' ? `
          <button id="leave" class="action secondary" ${canDecide ? '' : 'disabled'}>${me?.status === 'active' ? '撤退' : '已撤退'}</button>
          <button id="continue" class="action primary" ${canDecide ? '' : 'disabled'}>${me?.status === 'active' ? '继续深入' : '观察中'}</button>
        ` : `
          <button class="action secondary" disabled>${state.status === 'finished' ? '游戏结束' : '等待结算'}</button>
          <button id="nextRound" class="action primary" ${isHost && game.phase === 'roundEnd' ? '' : 'disabled'}>${game.round >= 5 ? '查看排名' : '下一轮'}</button>
        `}
      </div>
      <div class="log">${game.logs.map((item) => `<div class="log-item">${escapeHtml(item.text)}</div>`).join('')}</div>
    </section>
    <p class="error">${escapeHtml(errorMessage)}</p>
  `, `第 ${game.round}/5 轮`, `${game.deckCount} 张`);

  bindClick('#leave', () => socket.emit('submitDecision', { decision: 'leave' satisfies Decision }));
  bindClick('#continue', () => socket.emit('submitDecision', { decision: 'continue' satisfies Decision }));
  bindClick('#nextRound', () => socket.emit('nextRound'));
}

function shell(content: string, title: string, pill: string): string {
  return `
    <main class="app-shell">
      <header class="topbar">
        <div>
          <span class="eyebrow">inca treasure</span>
          <h1>${title}</h1>
        </div>
        <div class="pill"><strong>${escapeHtml(pill)}</strong><span>${socket.connected ? '在线' : '离线'}</span></div>
      </header>
      ${content}
    </main>
  `;
}

function playersView(players: PublicPlayer[]): string {
  return `<section class="players">${players.map((player) => `
    <article class="player ${player.status}">
      <div class="player-name"><span>${escapeHtml(player.nickname)}${player.isHost ? ' · 房主' : ''}</span><span>${player.connected ? statusText(player) : '离线'}</span></div>
      <span class="score">${player.bankScore}</span>
      <span class="temp">携带 ${player.temporaryGems}${player.hasSubmitted ? ' · 已提交' : ''}</span>
    </article>
  `).join('')}</section>`;
}

function cardView(card: Card | null): string {
  if (!card) {
    return '<article class="card"><div class="card-kind">入口</div><div class="card-icon">◆</div><div class="card-title">等待翻牌</div><div class="card-text">所有选择提交后会继续深入。</div></article>';
  }
  if (card.type === 'treasure') {
    return `<article class="card"><div class="card-kind">宝石</div><div class="card-icon">◆</div><div class="card-title">${card.value} 颗</div><div class="card-text">仍在神庙内的玩家平分，余数留在通道。</div></article>`;
  }
  if (card.type === 'relic') {
    return `<article class="card relic"><div class="card-kind">遗物</div><div class="card-icon">⬟</div><div class="card-title">${card.value} 分</div><div class="card-text">只有一人撤退时可以带走遗物。</div></article>`;
  }
  return `<article class="card hazard"><div class="card-kind">危险</div><div class="card-icon">!</div><div class="card-title">${hazardNames[card.hazardType]}</div><div class="card-text">同类危险第二次出现时，仍在神庙内的玩家爆掉。</div></article>`;
}

function miniCardView(card: Card): string {
  if (card.type === 'treasure') return `<span class="mini-card">${card.value}</span>`;
  if (card.type === 'relic') return '<span class="mini-card">⬟</span>';
  return `<span class="mini-card">${hazardNames[card.hazardType].slice(0, 1)}</span>`;
}

function rankingView(players: PublicPlayer[]): string {
  return `<section class="ranking">${players.map((player, index) => `
    <div class="rank-row"><span>${index + 1}. ${escapeHtml(player.nickname)}</span><strong>${player.bankScore} 分</strong></div>
  `).join('')}</section>`;
}

function phaseTitle(game: PublicGameState, me: PublicPlayer | null): string {
  if (game.phase === 'gameEnd') return '最终排名';
  if (game.phase === 'roundEnd') return '本轮结束';
  if (game.phase === 'waitingDecision' && me?.status !== 'active') return '你已撤退，继续观察';
  if (game.phase === 'waitingDecision' && me?.status === 'active' && !me.hasSubmitted) return '继续，还是撤退？';
  if (game.phase === 'waitingDecision') return '等待其他玩家';
  return '翻牌中';
}

function waitingDecisionText(state: PublicRoomState, game: PublicGameState, me: PublicPlayer | null): string {
  if (game.phase === 'gameEnd') return '5 轮探险结束。';
  if (game.phase === 'roundEnd') return me?.isHost ? '点击下一轮继续。' : '等待房主进入下一轮。';
  const active = state.players.filter((player) => player.status === 'active');
  const waiting = active.filter((player) => !player.hasSubmitted).length;
  if (me?.hasSubmitted) return `你的选择已提交，等待 ${waiting} 名玩家。`;
  if (me?.status !== 'active') return `你已离开神庙，等待 ${waiting} 名玩家选择。`;
  return `你携带 ${me.temporaryGems} 颗宝石，仍有 ${active.length} 名玩家在神庙内。`;
}

function statusText(player: PublicPlayer): string {
  if (player.status === 'active') return '探险中';
  if (player.status === 'left') return '营地';
  if (player.status === 'busted') return '爆掉';
  return '等待';
}

function currentPlayer(state: PublicRoomState): PublicPlayer | null {
  return state.players.find((player) => player.id === state.me) ?? null;
}

function bindClick(selector: string, handler: () => void): void {
  document.querySelector<HTMLButtonElement>(selector)?.addEventListener('click', handler);
}

function bindInput(selector: string, handler: (value: string) => void): void {
  document.querySelector<HTMLInputElement>(selector)?.addEventListener('input', (event) => {
    handler((event.target as HTMLInputElement).value);
  });
}

function escapeHtml(value: unknown): string {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function invitePath(code: string): string {
  return `/?room=${encodeURIComponent(code)}`;
}

render();
