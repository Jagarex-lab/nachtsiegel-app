import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';
import { createApp } from '../src/transport/app.js';
import { registerClient, SimulatedClient } from '../tools/load.js';

type Message = Record<string, any>;
const code = (message: Message) => message.code ?? message.error?.code;
async function rawPost(url: string, path: string, value: object, headers: Record<string, string> = {}) {
  return fetch(`${url}${path}`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(value) });
}
async function expectUpgradeFailure(url: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    socket.on('unexpected-response', (_request, response) => { response.resume(); resolve(response.statusCode!); });
    socket.on('open', () => { socket.close(); reject(new Error('Unauthenticated WebSocket accepted')); });
    socket.on('error', () => {});
  });
}

test('HTTP credentials, secure web cookies, CSRF, origin, rotation and revocation', async () => {
  const app = await createApp({ dbPath: ':memory:', port: 0 });
  const { url, wsUrl } = await app.start();
  try {
    const username = `web_${randomUUID().slice(0, 8)}`;
    const password = 'Local-Integration-Password-42!';
    assert.equal((await rawPost(url, '/auth/register', { username, password, display_name: 'Web Test' })).status, 202);
    const unknown = await rawPost(url, '/auth/login', { username: 'missing_account', password });
    const wrong = await rawPost(url, '/auth/login', { username, password: 'incorrect-password-42' });
    assert.equal(unknown.status, wrong.status);
    assert.deepEqual(await unknown.json(), await wrong.json());
    const login = await rawPost(url, '/auth/login', { username, password }, { origin: url });
    assert.equal(login.status, 200);
    const body = await login.json() as Message;
    assert.equal(body.token, undefined, 'Browser body must not expose session secret');
    const setCookie = login.headers.get('set-cookie')!;
    assert.match(setCookie, /HttpOnly/i);
    assert.match(setCookie, /SameSite=Strict/i);
    const cookie = setCookie.split(';')[0]!;
    const restored = await fetch(`${url}/auth/session`, { headers: { cookie } });
    assert.equal(restored.status, 200);
    assert.equal((await restored.json() as Message).csrf_token, body.csrf_token);
    const profile = await fetch(`${url}/profile`, { headers: { cookie } });
    assert.equal(profile.status, 200);
    const publicProfile = JSON.stringify(await profile.json());
    assert.doesNotMatch(publicProfile, /password|password_hash|csrf|token|username/);
    assert.equal((await rawPost(url, '/transport/ticket', {}, { cookie, origin: url })).status, 403);
    assert.equal((await rawPost(url, '/transport/ticket', {}, { cookie, origin: 'https://hostile.example', 'x-csrf-token': body.csrf_token })).status, 403);
    const ticketResponse = await rawPost(url, '/transport/ticket', {}, { cookie, origin: url, 'x-csrf-token': body.csrf_token });
    assert.equal(ticketResponse.status, 200);
    const ticket = await ticketResponse.json() as Message;
    const socket = new WebSocket(`${wsUrl}/ws?ticket=${encodeURIComponent(ticket.ticket)}`, { origin: url });
    await new Promise<void>((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
    assert.equal(await expectUpgradeFailure(`${wsUrl}/ws?ticket=${encodeURIComponent(ticket.ticket)}`), 401);
    await new Promise<void>(resolve => { socket.once('close', resolve); socket.close(); });
    const rotated = await rawPost(url, '/auth/rotate', {}, { cookie, origin: url, 'x-csrf-token': body.csrf_token });
    assert.equal(rotated.status, 200);
    assert.equal((await fetch(`${url}/profile`, { headers: { cookie } })).status, 401);
    const newCookie = rotated.headers.get('set-cookie')!.split(';')[0]!;
    const rotatedBody = await rotated.json() as Message;
    assert.equal((await rawPost(url, '/auth/logout', {}, { cookie: newCookie, origin: url, 'x-csrf-token': rotatedBody.csrf_token })).status, 200);
    assert.equal((await fetch(`${url}/profile`, { headers: { cookie: newCookie } })).status, 401);
    assert.equal(await expectUpgradeFailure(`${wsUrl}/ws?ticket=invalid`), 401);
    assert.equal((await fetch(`${url}/profile`, { headers: { authorization: 'Bearer invalid' } })).status, 401);
    assert.equal((await rawPost(url, '/auth/register', { username: 'bad', password: 'short', display_name: 'Bad' })).status, 400);
    const oversized = await fetch(`${url}/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username, password: 'x'.repeat(70_000) }) });
    assert.equal(oversized.status, 413);
  } finally { await app.close(); }
});

test('two real WebSocket clients: assigned match, views, duplicate protection, reconnect and history', async () => {
  const app = await createApp({ dbPath: ':memory:', port: 0 });
  const { url, wsUrl } = await app.start();
  const clients: SimulatedClient[] = [];
  try {
    clients.push(await registerClient(url, wsUrl, 0), await registerClient(url, wsUrl, 1), await registerClient(url, wsUrl, 2));
    const [alice, bob, outsider] = clients as [SimulatedClient, SimulatedClient, SimulatedClient];
    await alice.send('matchmaking.join', { mode: 'casual', region: 'local' });
    const found = await bob.send('matchmaking.join', { mode: 'casual', region: 'local' });
    const resume = await alice.send('session.resume');
    const matchId = found.match_id ?? resume.match_id;
    assert.equal(typeof matchId, 'string');
    await alice.send('match.ready', { match_id: matchId });
    await bob.send('match.ready', { match_id: matchId });
    const aliceView = await alice.send('match.reconnect', { match_id: matchId, after_sequence: 0 });
    const bobView = await bob.send('match.reconnect', { match_id: matchId, after_sequence: 0 });
    assert.equal(aliceView.state.simulation, true);
    assert.equal(aliceView.status, 'active');
    assert.notDeepEqual(aliceView.state.own_hand, bobView.state.own_hand);
    for (const hidden of bobView.state.own_hand) assert.equal(JSON.stringify(aliceView).includes(hidden), false);
    for (const hidden of aliceView.state.own_hand) assert.equal(JSON.stringify(bobView).includes(hidden), false);
    assert.doesNotMatch(JSON.stringify(aliceView), /"seed"|"deck"|"hidden"|password|token/);
    assert.equal(code(await outsider.send('match.reconnect', { match_id: matchId, after_sequence: 0 })), 'MATCH_NOT_FOUND');
    const invalid = await alice.send('match.action', { match_id: matchId, sequence: 1, action: { type: 'advance', damage: 999 } });
    assert.ok(code(invalid), 'Server must reject invented authoritative values');
    const actor = aliceView.state.turn_player_id === alice.userId ? alice : bob;
    const actorView = actor === alice ? aliceView : bobView;
    const requestId = randomUUID();
    const action = { match_id: matchId, sequence: actorView.next_action_sequence, action: { type: 'advance' } };
    const first = await actor.send('match.action', action, requestId);
    assert.equal(code(first), undefined);
    const repeated = await actor.send('match.action', action, requestId);
    assert.deepEqual(repeated, first);
    assert.ok(code(await actor.send('match.action', { ...action, action: { type: 'concede' } }, requestId)), 'Conflicting idempotency payload rejected');
    assert.ok(code(await actor.send('match.action', action)), 'Reused sequence rejected');
    await bob.disconnect();
    await bob.connect();
    const reconnected = await bob.send('match.reconnect', { match_id: matchId, after_sequence: bobView.sequence });
    assert.equal(reconnected.state.accepted_actions, 1);
    assert.equal(reconnected.state.own_hand.length, bobView.state.own_hand.length);
    const finished = await bob.send('match.action', { match_id: matchId, sequence: reconnected.next_action_sequence, action: { type: 'concede' } });
    assert.equal(finished.status, 'finished');
    const history = await alice.request('/matches/history', undefined, 'GET');
    const rows = Array.isArray(history) ? history : history.matches ?? history.history;
    assert.ok(rows.some((row: Message) => row.match_id === matchId));
    assert.doesNotMatch(JSON.stringify(rows), /password|token|"seed"|"hidden"|"deck"/);
    assert.ok(code(await alice.raw({ protocol_version: 99, request_id: randomUUID(), type: 'session.resume' })));
    assert.ok(code(await alice.raw({ protocol_version: 1, request_id: randomUUID(), type: 'not.a.message' })));
  } finally { await Promise.all(clients.map(client => client.disconnect().catch(() => {}))); await app.close(); }
});

test('WebSocket invalid JSON, oversized message and revoked session are rejected', async () => {
  const app = await createApp({ dbPath: ':memory:', port: 0 });
  const { url, wsUrl } = await app.start();
  let client: SimulatedClient | undefined;
  try {
    client = await registerClient(url, wsUrl, 0);
    const errorReceived = new Promise<Message>(resolve => client!.socket.once('message', raw => resolve(JSON.parse(raw.toString()))));
    client.socket.send('{');
    assert.ok(code(await errorReceived));
    const closed = new Promise<number>(resolve => client!.socket.once('close', closeCode => resolve(closeCode)));
    client.socket.send('x'.repeat(100_000));
    assert.equal(await closed, 1009);
    await client.connect();
    assert.equal((await rawPost(url, '/auth/logout', {}, { authorization: `Bearer ${client.token}` })).status, 200);
    const revokedClosed = new Promise<number>(resolve => client!.socket.once('close', closeCode => resolve(closeCode)));
    client.socket.send(JSON.stringify({ protocol_version: 1, request_id: randomUUID(), type: 'session.resume' }));
    assert.ok([1008, 4001, 4401].includes(await revokedClosed));
  } finally { if (client) await client.disconnect().catch(() => {}); await app.close(); }
});
