import type { Card, Decision, GameState, HazardType, Player, Room } from './types.js';

const treasureValues = [1, 2, 3, 4, 5, 5, 7, 7, 9, 11, 11, 13, 14, 15, 17];
const hazardTypes: HazardType[] = ['snake', 'fire', 'rock', 'spider', 'curse'];

export const hazardNames: Record<HazardType, string> = {
  snake: '毒蛇',
  fire: '火焰陷阱',
  rock: '落石',
  spider: '毒蛛',
  curse: '古墓诅咒',
};

export function createGame(): GameState {
  return {
    round: 1,
    phase: 'revealing',
    deck: createDeck(1),
    revealedCards: [],
    caveGems: 0,
    relics: [],
    seenHazards: {},
    lastCard: null,
    logs: [],
  };
}

export function startGame(room: Room): void {
  room.status = 'playing';
  room.players.forEach((player) => {
    player.bankScore = 0;
    player.temporaryGems = 0;
    player.status = 'active';
    player.submittedDecision = null;
  });
  room.game = createGame();
  pushLog(room.game, '第 1 轮开始，所有探险者进入神庙。');
  revealNextCard(room);
}

export function startNextRound(room: Room): void {
  const game = requireGame(room);
  if (game.round >= 5) {
    game.phase = 'gameEnd';
    room.status = 'finished';
    pushLog(game, '5 轮探险结束，最终排名已生成。');
    return;
  }

  const nextRound = game.round + 1;
  room.players.forEach((player) => {
    player.temporaryGems = 0;
    player.status = 'active';
    player.submittedDecision = null;
  });
  room.game = {
    round: nextRound,
    phase: 'revealing',
    deck: createDeck(nextRound),
    revealedCards: [],
    caveGems: 0,
    relics: [],
    seenHazards: {},
    lastCard: null,
    logs: [...game.logs],
  };
  pushLog(room.game, `第 ${nextRound} 轮开始。`);
  revealNextCard(room);
}

export function submitDecision(room: Room, playerId: string, decision: Decision): void {
  const game = requireGame(room);
  if (room.status !== 'playing' || game.phase !== 'waitingDecision') {
    throw new Error('现在不是选择阶段');
  }

  const player = room.players.find((item) => item.id === playerId);
  if (!player || player.status !== 'active') {
    throw new Error('当前玩家不在神庙内');
  }
  if (player.submittedDecision) {
    throw new Error('你已经提交过选择');
  }

  player.submittedDecision = decision;
  resolveSubmittedDecisions(room);
}

export function resolveSubmittedDecisions(room: Room): void {
  const game = requireGame(room);
  if (room.status !== 'playing' || game.phase !== 'waitingDecision') return;
  if (activePlayers(room).every((item) => item.submittedDecision)) {
    resolveDecisions(room);
  }
}

export function revealNextCard(room: Room): void {
  const game = requireGame(room);
  if (activePlayers(room).length === 0 || game.deck.length === 0) {
    finishRound(room, '本轮没有探险者继续深入。');
    return;
  }

  const card = game.deck.pop();
  if (!card) {
    finishRound(room, '牌堆耗尽，本轮结束。');
    return;
  }

  room.players.forEach((player) => {
    if (player.status === 'active') player.submittedDecision = null;
  });
  game.lastCard = card;
  game.revealedCards.push(card);

  if (card.type === 'treasure') {
    resolveTreasure(room, card.value);
    game.phase = 'waitingDecision';
    return;
  }

  if (card.type === 'relic') {
    game.relics.push(card.value);
    game.phase = 'waitingDecision';
    pushLog(game, `发现价值 ${card.value} 的遗物，单独撤退者可以带走它。`);
    return;
  }

  const seen = (game.seenHazards[card.hazardType] ?? 0) + 1;
  game.seenHazards[card.hazardType] = seen;
  if (seen >= 2) {
    const busted = activePlayers(room);
    busted.forEach((player) => {
      player.temporaryGems = 0;
      player.status = 'busted';
      player.submittedDecision = null;
    });
    finishRound(room, `${hazardNames[card.hazardType]}第二次出现，${names(busted)} 爆掉并失去本轮宝石。`);
    return;
  }

  game.phase = 'waitingDecision';
  pushLog(game, `${hazardNames[card.hazardType]}出现一次，继续深入会更危险。`);
}

function resolveTreasure(room: Room, value: number): void {
  const game = requireGame(room);
  const explorers = activePlayers(room);
  const share = Math.floor(value / explorers.length);
  const remainder = value % explorers.length;
  explorers.forEach((player) => {
    player.temporaryGems += share;
  });
  game.caveGems += remainder;
  pushLog(game, `发现 ${value} 颗宝石，${names(explorers)} 各获得 ${share} 颗，遗留 ${remainder} 颗。`);
}

function resolveDecisions(room: Room): void {
  const game = requireGame(room);
  const leavers = activePlayers(room).filter((player) => player.submittedDecision === 'leave');

  if (leavers.length > 0) {
    const caveShare = Math.floor(game.caveGems / leavers.length);
    game.caveGems %= leavers.length;

    let relicScore = 0;
    if (leavers.length === 1 && game.relics.length > 0) {
      relicScore = game.relics.reduce((sum, value) => sum + value, 0);
      game.relics = [];
    }

    leavers.forEach((player) => {
      const earned = player.temporaryGems + caveShare + (leavers.length === 1 ? relicScore : 0);
      player.bankScore += earned;
      player.temporaryGems = 0;
      player.status = 'left';
      player.submittedDecision = null;
    });
    pushLog(game, `${names(leavers)} 撤退并安全入账${caveShare ? `，各分得通道 ${caveShare} 颗` : ''}${relicScore ? `，带走遗物 ${relicScore} 分` : ''}。`);
  }

  activePlayers(room).forEach((player) => {
    player.submittedDecision = null;
  });

  if (activePlayers(room).length === 0) {
    finishRound(room, '所有探险者都离开了神庙。');
    return;
  }

  game.phase = 'revealing';
  revealNextCard(room);
}

function finishRound(room: Room, reason: string): void {
  const game = requireGame(room);
  game.phase = game.round >= 5 ? 'gameEnd' : 'roundEnd';
  if (game.round >= 5) room.status = 'finished';
  room.players.forEach((player) => {
    if (player.status === 'active') player.status = 'left';
    player.temporaryGems = 0;
    player.submittedDecision = null;
  });
  pushLog(game, reason);
}

function activePlayers(room: Room): Player[] {
  return room.players.filter((player) => player.status === 'active');
}

function createDeck(round: number): Card[] {
  const cards: Card[] = treasureValues.map((value) => ({ type: 'treasure', value }));
  hazardTypes.forEach((hazardType) => {
    for (let index = 0; index < 3; index += 1) {
      cards.push({ type: 'hazard', hazardType });
    }
  });
  cards.push({ type: 'relic', value: round < 4 ? 5 : 10 });
  return shuffle(cards);
}

function shuffle<T>(items: T[]): T[] {
  const copy = [...items];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [copy[index], copy[swapIndex]] = [copy[swapIndex], copy[index]];
  }
  return copy;
}

function names(players: Player[]): string {
  return players.map((player) => player.nickname).join('、') || '无人';
}

function pushLog(game: GameState, text: string): void {
  game.logs.unshift({ id: `${Date.now()}-${Math.random().toString(16).slice(2)}`, text });
  game.logs = game.logs.slice(0, 8);
}

function requireGame(room: Room): GameState {
  if (!room.game) throw new Error('游戏尚未开始');
  return room.game;
}
