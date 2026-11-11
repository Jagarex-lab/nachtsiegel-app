import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { request } from 'node:http';
import { createApp } from '../src/transport/app.js';
import { SimulatedClient } from '../tools/load.js';

type Json = Record<string, any>;
const password = 'Security-Regression-Password-42!';
async function post(url: string, path: string, value: object, headers: Record<string, string> = {}) {
  return fetch(`${url}${path}`, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(value) });
}
async function account(url: string, wsUrl: string, index: number): Promise<SimulatedClient> {
  const username = `security_${index}_${randomUUID().slice(0, 8)}`;
  assert.equal((await post(url, '/auth/register', { username, password, display_name: `Security ${index}` })).status, 202);
  const response = await post(url, '/auth/login', { username, password, client: 'native' });
  assert.equal(response.status, 200);
  const session = await response.json() as Json;
  const client = new SimulatedClient(url, wsUrl, session.token, session.profile.playerId);
  await client.connect();
  return client;
}
async function startMatch(first: SimulatedClient, second: SimulatedClient): Promise<string> {
  await first.send('matchmaking.join', { mode: 'casual', region: 'local' });
  const found = await second.send('matchmaking.join', { mode: 'casual', region: 'local' });
  const id = found.match_id as string;
  assert.equal(typeof id, 'string');
  await first.send('match.ready', { match_id: id });
  assert.equal((await second.send('match.ready', { match_id: id })).status, 'active');
  return id;
}

test('loopback API rejects a DNS rebinding Host header', { timeout: 15_000 }, async () => {
  const app = await createApp({ port: 0 });
  const { url } = await app.start();
  try {
    const response = await new Promise<{ status: number; value: Json }>((resolve, reject) => {
      const req = request(`${url}/health`, { headers: { host: 'attacker.example' } }, res => {
        let raw = '';
        res.setEncoding('utf8');
        res.on('data', chunk => { raw += chunk; });
        res.on('end', () => resolve({ status: res.statusCode!, value: JSON.parse(raw) as Json }));
      });
      req.on('error', reject);
      req.end();
    });
    assert.equal(response.status, 403);
    assert.equal(response.value.code, 'HOST_REJECTED');
    assert.equal((await fetch(`${url}/health`)).status, 200);
  } finally { await app.close(); }
});

test('HTTP limiter uses peer address and ignores spoofed forwarding headers', { timeout: 15_000 }, async () => {
  const app = await createApp({ port: 0 });
  const { url } = await app.start();
  try {
    // Exhaust only the cheap health route; every request invents a distinct proxy IP.
    let rejected = false;
    for (let i = 0; i < 605; i++) {
      const response = await fetch(`${url}/health`, { headers: { 'x-forwarded-for': `198.51.${Math.floor(i / 250)}.${i % 250 + 1}`, forwarded: `for=203.0.113.${i % 250 + 1}` } });
      if (response.status === 429) {
        assert.equal((await response.json() as Json).code, 'RATE_LIMITED');
        rejected = true;
        break;
      }
      assert.equal(response.status, 200);
      await response.arrayBuffer();
    }
    assert.equal(rejected, true, 'Changing untrusted forwarding headers must not evade the peer limit');
    assert.equal((await fetch(`${url}/health`, { headers: { 'x-forwarded-for': '192.0.2.240' } })).status, 429);
  } finally { await app.close(); }
});

test('cookie bootstrap exposes no bearer and expired sessions lose HTTP and existing WebSocket authority', { timeout: 15_000 }, async () => {
  const app = await createApp({ port: 0 });
  const { url, wsUrl } = await app.start();
  const username = `expiry_${randomUUID().slice(0, 8)}`;
  let socket: import('ws').default | undefined;
  try {
    assert.equal((await post(url, '/auth/register', { username, password, display_name: 'Expiry' })).status, 202);
    const login = await post(url, '/auth/login', { username, password }, { origin: url });
    const session = await login.json() as Json;
    assert.equal(session.token, undefined);
    const cookie = login.headers.get('set-cookie')!.split(';')[0]!;
    const bootstrap = await fetch(`${url}/auth/session`, { headers: { cookie } });
    assert.equal(bootstrap.status, 200);
    const restored = await bootstrap.json() as Json;
    assert.equal(restored.csrf_token, session.csrf_token);
    assert.equal(restored.token, undefined);
    const ticketResponse = await post(url, '/transport/ticket', {}, { cookie, origin: url, 'x-csrf-token': restored.csrf_token });
    assert.equal(ticketResponse.status, 200);
    const { default: WebSocket } = await import('ws');
    socket = new WebSocket(`${wsUrl}/ws?ticket=${(await ticketResponse.json() as Json).ticket}`, { origin: url });
    await new Promise<void>((resolve, reject) => { socket!.once('open', resolve); socket!.once('error', reject); });
    const closed = new Promise<number>(resolve => socket!.once('close', resolve));
    // Advance persisted expiry rather than waiting for wall-clock timing.
    app.db.prepare('UPDATE sessions SET expires_at = ?').run(Date.now() - 1);
    assert.equal((await fetch(`${url}/auth/session`, { headers: { cookie } })).status, 401);
    if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ protocol_version: 1, type: 'session.resume', request_id: randomUUID() }));
    assert.equal(await closed, 1008);
  } finally { socket?.terminate(); await app.close(); }
});

test('replays enforce participant/terminal checks and only successful account deletion cancels a match', { timeout: 30_000 }, async () => {
  const app = await createApp({ port: 0 });
  const { url, wsUrl } = await app.start();
  const clients: SimulatedClient[] = [];
  try {
    clients.push(await account(url, wsUrl, 0), await account(url, wsUrl, 1), await account(url, wsUrl, 2));
    const [alice, bob, outsider] = clients as [SimulatedClient, SimulatedClient, SimulatedClient];
    const getReplay = (player: SimulatedClient, id: string) => fetch(`${url}/matches/${id}/replay`, { headers: { authorization: `Bearer ${player.token}` } });
    const completed = await startMatch(alice, bob);
    const unavailable = await getReplay(alice, completed);
    assert.equal(unavailable.status, 409);
    assert.equal((await unavailable.json() as Json).code, 'REPLAY_NOT_AVAILABLE');
    assert.equal((await getReplay(outsider, completed)).status, 404);
    const view = await bob.send('match.reconnect', { match_id: completed, after_sequence: 0 });
    assert.equal((await bob.send('match.action', { match_id: completed, sequence: view.next_action_sequence, action: { type: 'concede' } })).status, 'finished');
    for (const player of [alice, bob]) {
      const response = await getReplay(player, completed);
      assert.equal(response.status, 200);
      const replay = await response.json() as Json;
      assert.equal(replay.match_id, completed);
      assert.equal(replay.actions.length, 1);
      assert.equal(typeof replay.server_seed, 'string');
      assert.doesNotMatch(JSON.stringify(replay), /password|password_hash|csrf|token/);
    }
    assert.equal((await getReplay(outsider, completed)).status, 404);
    const active = await startMatch(alice, bob);
    const headers = { authorization: `Bearer ${alice.token}` };
    assert.equal((await post(url, '/account/delete', { password: 'incorrect-password' }, headers)).status, 401);
    assert.equal((await bob.send('match.reconnect', { match_id: active, after_sequence: 0 })).status, 'active');
    assert.equal((await fetch(`${url}/profile`, { headers })).status, 200);
    assert.equal((await post(url, '/account/delete', { password }, headers)).status, 200);
    assert.equal((await fetch(`${url}/profile`, { headers })).status, 401);
    const cancelled = await bob.send('match.reconnect', { match_id: active, after_sequence: 0 });
    assert.equal(cancelled.status, 'cancelled');
    assert.equal(cancelled.state.result.reason, 'account_deleted');
    assert.equal((await getReplay(alice, completed)).status, 401);
    assert.equal((await getReplay(bob, completed)).status, 200);
  } finally { await Promise.all(clients.map(client => client.disconnect().catch(() => {}))); await app.close(); }
});
