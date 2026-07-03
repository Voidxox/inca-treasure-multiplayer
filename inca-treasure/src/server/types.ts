export type Decision = 'continue' | 'leave';

export type RoomStatus = 'waiting' | 'playing' | 'finished';

export type GamePhase = 'revealing' | 'waitingDecision' | 'roundEnd' | 'gameEnd';

export type PlayerStatus = 'waiting' | 'active' | 'left' | 'busted';

export type Card =
  | { type: 'treasure'; value: number }
  | { type: 'hazard'; hazardType: HazardType }
  | { type: 'relic'; value: number };

export type HazardType = 'snake' | 'fire' | 'rock' | 'spider' | 'curse';

export type Player = {
  id: string;
  socketId: string;
  nickname: string;
  connected: boolean;
  isHost: boolean;
  bankScore: number;
  temporaryGems: number;
  status: PlayerStatus;
  submittedDecision: Decision | null;
  /** 断线时间戳（毫秒）。null 表示在线。用于重连宽限期与房间回收判定。 */
  disconnectedAt: number | null;
  /** 服务端签发的身份凭证：仅回给本人，重连与敏感操作需匹配，防止冒充他人 playerId。 */
  secret: string;
};

export type GameLog = {
  id: string;
  text: string;
};

export type GameState = {
  round: number;
  phase: GamePhase;
  deck: Card[];
  revealedCards: Card[];
  caveGems: number;
  relics: number[];
  seenHazards: Partial<Record<HazardType, number>>;
  lastCard: Card | null;
  logs: GameLog[];
  /** 决策阶段自动结算的截止时间戳（毫秒）。null 表示当前不在计时。 */
  decisionDeadline: number | null;
};

export type Room = {
  roomCode: string;
  status: RoomStatus;
  hostPlayerId: string;
  players: Player[];
  game: GameState | null;
  createdAt: number;
  updatedAt: number;
};

export type PublicPlayer = Omit<Player, 'socketId' | 'secret'> & {
  hasSubmitted: boolean;
  submittedDecision: null;
};

export type PublicGameState = Omit<GameState, 'deck'> & {
  deckCount: number;
};

export type PublicRoomState = Omit<Room, 'players' | 'game'> & {
  players: PublicPlayer[];
  game: PublicGameState | null;
  me: string | null;
};
