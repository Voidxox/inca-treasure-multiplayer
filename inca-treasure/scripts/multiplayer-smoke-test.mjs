import { createIncaServer } from '../dist/server/index.js';
import { io as createClient } from 'socket.io-client';

const { server, io } = createIncaServer();
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

const address = server.address();
if (!address || typeof address === 'string') throw new Error('Could not allocate test port');

const url = `http://127.0.0.1:${address.port}`;
const host = createClient(url, { transports: ['websocket'] });
const guest = createClient(url, { transports: ['websocket'] });

let hostState;
let guestState;

host.on('stateUpdated', (state) => {
  hostState = state;
});
guest.on('stateUpdated', (state) => {
  guestState = state;
});

try {
  const joined = await createRoom(host, 'Host');
  await joinRoom(guest, 'Guest', joined.roomCode);
  await waitFor(() => hostState?.players.length === 2 && guestState?.players.length === 2);

  host.emit('startGame');
  await waitFor(() => hostState?.game?.phase === 'waitingDecision');
  if ('deck' in hostState.game) throw new Error('Public state leaked the hidden deck');
  if (typeof hostState.game.deckCount !== 'number') throw new Error('Public state is missing deckCount');

  const firstDecisionCardCount = hostState.game.revealedCards.length;
  host.emit('submitDecision', { decision: 'continue' });
  guest.emit('submitDecision', { decision: 'leave' });
  await waitFor(() => hostState.players.some((player) => player.nickname === 'Guest' && player.status === 'left'));

  const guestPlayer = hostState.players.find((player) => player.nickname === 'Guest');
  if (!guestPlayer) throw new Error('Guest player missing after decision');
  const hostPlayer = hostState.players.find((player) => player.nickname === 'Host');
  if (!hostPlayer || hostPlayer.status !== 'active') throw new Error('Host should remain active after choosing continue');
  if (hostState.game.phase !== 'waitingDecision') throw new Error('Round should continue after only one player leaves');
  if (hostState.game.revealedCards.length <= firstDecisionCardCount) throw new Error('Server should reveal the next card when someone continues');

  while (hostState.game.phase !== 'gameEnd') {
    if (hostState.game.phase === 'waitingDecision') {
      submitForActivePlayers();
      await waitFor(() => hostState.game.phase !== 'waitingDecision');
    }
    if (hostState.game.phase === 'roundEnd') {
      host.emit('nextRound');
      await waitFor(() => hostState.game.phase === 'waitingDecision' || hostState.game.phase === 'gameEnd');
    }
    if ('deck' in hostState.game) throw new Error('Public state leaked the hidden deck after round progression');
  }

  if (hostState.status !== 'finished') throw new Error('Room did not finish after 5 rounds');
  if (hostState.game.round !== 5) throw new Error(`Expected final round to be 5, got ${hostState.game.round}`);
  if (hostState.players.length !== 2) throw new Error('Final state lost players');

  console.log(JSON.stringify({
    roomCode: joined.roomCode,
    phase: hostState.game.phase,
    round: hostState.game.round,
    players: hostState.players.map((player) => ({ nickname: player.nickname, score: player.bankScore })),
  }));
} finally {
  host.close();
  guest.close();
  io.close();
  await new Promise((resolve) => server.close(resolve));
}

function submitForActivePlayers() {
  const hostPlayer = hostState.players.find((player) => player.nickname === 'Host');
  const guestPlayer = hostState.players.find((player) => player.nickname === 'Guest');
  if (hostPlayer?.status === 'active' && !hostPlayer.hasSubmitted) {
    host.emit('submitDecision', { decision: 'leave' });
  }
  if (guestPlayer?.status === 'active' && !guestPlayer.hasSubmitted) {
    guest.emit('submitDecision', { decision: 'leave' });
  }
}

function createRoom(socket, nickname) {
  socket.emit('createRoom', { nickname });
  return once(socket, 'roomJoined');
}

function joinRoom(socket, nickname, roomCode) {
  socket.emit('joinRoom', { nickname, roomCode });
  return once(socket, 'roomJoined');
}

function once(socket, event) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${event}`)), 3000);
    socket.once(event, (value) => {
      clearTimeout(timer);
      resolve(value);
    });
  });
}

async function waitFor(predicate) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < 3000) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('Timed out waiting for state condition');
}
