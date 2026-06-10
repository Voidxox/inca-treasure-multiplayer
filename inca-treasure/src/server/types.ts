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

export type PublicPlayer = Omit<Player, 'socketId'> & {
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
