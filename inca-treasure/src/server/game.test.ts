import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  DECISION_TIMEOUT_MS,
  createGame,
  resolveDecisionTimeout,
  revealNextCard,
  startGame,
  submitDecision,
} from './game.js';
import type { Card, Player, Room } from './types.js';

/** 构造一个已开始对局的房间，玩家数量可配置。牌堆随后可被测试直接改写。 */
function makeRoom(nicknames: string[]): Room {
  const players: Player[] = nicknames.map((nickname, index) => ({
    id: `p_${index}`,
    socketId: `s_${index}`,
    nickname,
    connected: true,
    isHost: index === 0,
    bankScore: 0,
    temporaryGems: 0,
    status: 'waiting',
    submittedDecision: null,
    disconnectedAt: null,
  }));
  const room: Room = {
    roomCode: 'TEST',
    status: 'waiting',
    hostPlayerId: players[0].id,
    players,
    game: null,
    createdAt: Date.now(),
    updatedAt: Date.now(),
  };
  startGame(room);
  return room;
}

/** 替换牌堆为指定序列，并翻出下一张（deck.pop 取末尾，故末位为下一张）。 */
function revealCard(room: Room, card: Card): void {
  room.game!.deck = [card];
  revealNextCard(room);
}

function player(room: Room, nickname: string): Player {
  const found = room.players.find((item) => item.nickname === nickname);
  assert.ok(found, `player ${nickname} not found`);
  return found;
}

test('宝石在探险者间平分，余数留在通道', () => {
  const room = makeRoom(['A', 'B', 'C']);
  // startGame 已翻了一张随机牌，清空临时收益重置到可控状态。
  room.players.forEach((p) => {
    p.temporaryGems = 0;
  });
  room.game!.caveGems = 0;

  revealCard(room, { type: 'treasure', value: 7 });

  // 7 / 3 = 每人 2，余 1 留通道。
  assert.equal(player(room, 'A').temporaryGems, 2);
  assert.equal(player(room, 'B').temporaryGems, 2);
  assert.equal(player(room, 'C').temporaryGems, 2);
  assert.equal(room.game!.caveGems, 1);
});

test('同类危险第二次出现，仍在场玩家爆掉并清空本轮宝石', () => {
  const room = makeRoom(['A', 'B']);
  room.players.forEach((p) => {
    p.temporaryGems = 5;
  });
  room.game!.seenHazards = {};

  revealCard(room, { type: 'hazard', hazardType: 'snake' });
  // 第一次出现：不爆，进入决策。
  assert.equal(room.game!.phase, 'waitingDecision');
  assert.equal(player(room, 'A').status, 'active');

  revealCard(room, { type: 'hazard', hazardType: 'snake' });
  // 第二次出现：爆掉。
  assert.equal(player(room, 'A').status, 'busted');
  assert.equal(player(room, 'B').status, 'busted');
  assert.equal(player(room, 'A').temporaryGems, 0);
  assert.ok(room.game!.phase === 'roundEnd' || room.game!.phase === 'gameEnd');
});

test('不同类危险各出现一次不会爆', () => {
  const room = makeRoom(['A', 'B']);
  room.game!.seenHazards = {};

  revealCard(room, { type: 'hazard', hazardType: 'snake' });
  revealCard(room, { type: 'hazard', hazardType: 'fire' });

  assert.equal(player(room, 'A').status, 'active');
  assert.equal(player(room, 'B').status, 'active');
});

test('单人撤退可带走遗物分数', () => {
  const room = makeRoom(['A', 'B']);
  room.players.forEach((p) => {
    p.temporaryGems = 0;
  });
  room.game!.relics = [5];
  room.game!.caveGems = 0;
  // 制造决策阶段。
  revealCard(room, { type: 'treasure', value: 4 }); // 每人 +2
  room.game!.phase = 'waitingDecision';

  // A 撤退、B 继续 → A 单独撤退，独享遗物。
  submitDecision(room, player(room, 'A').id, 'leave');
  submitDecision(room, player(room, 'B').id, 'continue');

  // A 入账：本轮宝石 2 + 遗物 5 = 7。
  assert.equal(player(room, 'A').bankScore, 7);
  assert.equal(player(room, 'A').status, 'left');
  // 遗物被带走后清空。
  assert.deepEqual(room.game!.relics, []);
});

test('多人同时撤退时遗物不归任何人', () => {
  const room = makeRoom(['A', 'B']);
  room.players.forEach((p) => {
    p.temporaryGems = 3;
  });
  room.game!.relics = [10];
  room.game!.caveGems = 0;
  room.game!.phase = 'waitingDecision';

  submitDecision(room, player(room, 'A').id, 'leave');
  submitDecision(room, player(room, 'B').id, 'leave');

  // 两人各拿回本轮 3 宝石，无人拿遗物。
  assert.equal(player(room, 'A').bankScore, 3);
  assert.equal(player(room, 'B').bankScore, 3);
  // 遗物未被带走，保留。
  assert.deepEqual(room.game!.relics, [10]);
});

test('撤退者平分通道遗留宝石', () => {
  const room = makeRoom(['A', 'B']);
  room.players.forEach((p) => {
    p.temporaryGems = 0;
  });
  room.game!.relics = [];
  room.game!.caveGems = 5;
  room.game!.phase = 'waitingDecision';

  submitDecision(room, player(room, 'A').id, 'leave');
  submitDecision(room, player(room, 'B').id, 'leave');

  // 5 / 2 = 每人分 2，余 1 留通道。
  assert.equal(player(room, 'A').bankScore, 2);
  assert.equal(player(room, 'B').bankScore, 2);
  assert.equal(room.game!.caveGems, 1);
});

test('决策超时把未提交的活跃玩家默认判为撤退', () => {
  const room = makeRoom(['A', 'B']);
  room.players.forEach((p) => {
    p.temporaryGems = 4;
  });
  room.game!.relics = [];
  room.game!.caveGems = 0;
  room.game!.phase = 'waitingDecision';
  // 把截止时间设到过去，模拟超时。
  room.game!.decisionDeadline = Date.now() - 1;

  const resolved = resolveDecisionTimeout(room);
  assert.equal(resolved, true);
  // 两人都未提交 → 都被默认撤退，保住本轮宝石。
  assert.equal(player(room, 'A').bankScore, 4);
  assert.equal(player(room, 'B').bankScore, 4);
});

test('未到截止时间不触发超时结算', () => {
  const room = makeRoom(['A', 'B']);
  room.game!.phase = 'waitingDecision';
  room.game!.decisionDeadline = Date.now() + DECISION_TIMEOUT_MS;

  const resolved = resolveDecisionTimeout(room);
  assert.equal(resolved, false);
});

test('公开状态不应泄露牌堆（createGame 含 deck，属内部状态）', () => {
  const game = createGame();
  // deck 是内部字段，publicGame 会剥离它——此处仅确认 createGame 初始化正确。
  assert.ok(Array.isArray(game.deck));
  assert.equal(game.decisionDeadline, null);
  assert.equal(game.phase, 'revealing');
});
