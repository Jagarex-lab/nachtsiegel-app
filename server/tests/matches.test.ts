import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { MatchService, type Message } from '../src/matches/service.js';
import { SimulationAdapter } from '../src/matches/simulation-adapter.js';
import { SocialService } from '../src/social/service.js';

function fixture(path = ':memory:', extra: object = {}) {
  const db = new DatabaseSync(path);
  db.exec('PRAGMA foreign_keys=ON; CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY); INSERT OR IGNORE INTO users VALUES (\'alice\'),(\'bob\'),(\'eve\');');
  let now = 1_000_000;
  const options = { now: () => now, adapter: new SimulationAdapter(), ...extra };
  const service = new MatchService(db, options);
  const send = (user: string, type: string, body: object = {}) => service.handle(user, { protocol_version: 1, type, request_id: randomUUID(), ...body }) as Record<string, any>;
  const paired = () => {
    assert.equal(send('alice', 'matchmaking.join', { mode: 'casual', region: 'local' }).type, 'matchmaking.queued');
    const found = send('bob', 'matchmaking.join', { mode: 'casual', region: 'local' });
    assert.equal(found.type, 'match.found');
    return found.match_id as string;
  };
  const started = () => { const id = paired(); send('alice', 'match.ready', { match_id: id }); send('bob', 'match.ready', { match_id: id }); return id; };
  return { db, service, send, paired, started, time: (delta: number) => { now += delta; }, options };
}

test('server pairs two users once and requires both ready', () => {
  const f = fixture();
  try {
    const id = f.paired();
    assert.equal(f.service.activeMatchFor('alice'), id);
    assert.deepEqual(f.service.participants(id), ['alice', 'bob']);
    assert.equal(f.send('alice', 'matchmaking.join', { mode: 'casual', region: 'local' }).match_id, id);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 1, action: { type: 'advance' } }), /INVALID_MATCH_PHASE/);
    assert.equal(f.send('alice', 'match.ready', { match_id: id }).status, 'waiting_ready');
    assert.equal(f.send('bob', 'match.ready', { match_id: id }).status, 'active');
    assert.equal((f.db.prepare('SELECT COUNT(*) AS n FROM online_matches').get() as { n: number }).n, 1);
    assert.throws(() => f.send('eve', 'matchmaking.join', { mode: 'ranked', region: 'local' }), /MODE_DISABLED/);
  } finally { f.db.close(); }
});

test('views and events never disclose another hand, server seed or draw order', () => {
  const f = fixture();
  try {
    const id = f.started();
    const a = f.service.view('alice', id) as any, b = f.service.view('bob', id) as any;
    assert.equal(a.state.own_hand.length, 2);
    assert.equal(a.state.players[1].hand_count, 2);
    for (const secret of b.state.own_hand) assert.equal(JSON.stringify(a).includes(secret), false);
    const row = f.db.prepare('SELECT server_seed,state FROM online_matches WHERE id=?').get(id) as { server_seed: string; state: string };
    assert.equal(JSON.stringify(a).includes(row.server_seed), false);
    for (const hidden of Object.values(JSON.parse(row.state).hidden) as any[]) for (const secret of hidden.deck) assert.equal(JSON.stringify(a).includes(secret), false);
    assert.throws(() => f.service.view('eve', id), /MATCH_NOT_FOUND/);
    assert.throws(() => f.service.replay('alice', id), /REPLAY_NOT_AVAILABLE/);
    const spectator = f.service.adapter.get_player_view(f.service.adapter.deserialize(row.state), null) as any;
    assert.equal(spectator.own_hand, undefined);
  } finally { f.db.close(); }
});

test('accepted actions are atomic idempotent and strictly ordered per player', () => {
  const f = fixture();
  try {
    const id = f.started();
    const message: Message = { protocol_version: 1, type: 'match.action', request_id: randomUUID(), match_id: id, sequence: 1, action: { type: 'advance' } };
    assert.throws(() => f.send('bob', 'match.action', { match_id: id, sequence: 1, action: { type: 'advance' } }), /NOT_YOUR_TURN/);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 2, action: { type: 'advance' } }), /INVALID_SEQUENCE/);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 1, action: { type: 'play_card', card_id: 'fake' } }), /INVALID_ACTION/);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 1, action: { type: 'advance', energy: 9999 } }), /INVALID_ACTION/);
    const accepted = f.service.handle('alice', message);
    assert.deepEqual(f.service.handle('alice', { action: { type: 'advance' }, ...message }), accepted);
    assert.throws(() => f.service.handle('alice', { ...message, sequence: 2 }), /REQUEST_ID_CONFLICT/);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 1, action: { type: 'advance' } }), /INVALID_SEQUENCE/);
    assert.equal((f.service.view('alice', id) as any).state.accepted_actions, 1);
    assert.equal((f.db.prepare('SELECT COUNT(*) AS n FROM online_match_actions').get() as { n: number }).n, 1);
    assert.equal((f.service.view('alice', id) as any).next_action_sequence, 2);
    assert.equal((f.service.view('bob', id) as any).next_action_sequence, 1);
  } finally { f.db.close(); }
});

test('reconnect restores snapshot and cursor without adding actions or resources', () => {
  const f = fixture();
  try {
    const id = f.started();
    const before = f.service.view('alice', id) as any;
    f.send('alice', 'match.action', { match_id: id, sequence: 1, action: { type: 'advance' } });
    f.service.disconnected('alice');
    f.time(10_000);
    const reconnect = f.send('alice', 'match.reconnect', { match_id: id, after_sequence: before.sequence });
    assert.equal(reconnect.state.accepted_actions, 1);
    assert.deepEqual(reconnect.state.own_hand, before.state.own_hand);
    assert.equal(reconnect.events.length, 1);
    assert.equal(reconnect.next_action_sequence, 2);
    const repeat = f.send('alice', 'match.reconnect', { match_id: id, after_sequence: reconnect.sequence });
    assert.equal(repeat.events.length, 0);
    assert.deepEqual(repeat.state, reconnect.state);
    assert.throws(() => f.service.view('alice', id, 100_000), /INVALID_EVENT_CURSOR/);
  } finally { f.db.close(); }
});

test('six simulated actions finish, history persists and replay reproduces outcome', () => {
  const f = fixture();
  try {
    const id = f.started();
    for (let i = 0; i < 6; i++) f.send(i % 2 ? 'bob' : 'alice', 'match.action', { match_id: id, sequence: Math.floor(i / 2) + 1, action: { type: 'advance' } });
    const view = f.service.view('alice', id) as any;
    assert.equal(view.status, 'finished');
    assert.equal(view.state.result.reason, 'simulation_complete');
    assert.equal(f.service.activeMatchFor('alice'), null);
    const history = f.service.history('alice') as any[];
    assert.equal(history.length, 1); assert.equal(history[0].result.reason, 'simulation_complete');
    assert.equal(f.service.history('eve').length, 0);
    assert.throws(() => f.service.replay('eve', id), /MATCH_NOT_FOUND/);
    const replay = f.service.replay('bob', id) as any;
    assert.equal(replay.actions.length, 6);
    const adapter = new SimulationAdapter();
    let state = adapter.create_state(replay.players, replay.server_seed);
    for (const event of replay.actions) state = adapter.apply_action(state, event.player_id, event.action, replay.server_seed);
    assert.deepEqual(adapter.get_result(state), replay.result);
    assert.deepEqual(adapter.get_player_view(state, 'alice'), view.state);
    assert.throws(() => f.send('alice', 'match.action', { match_id: id, sequence: 4, action: { type: 'advance' } }), /INVALID_MATCH_PHASE/);
  } finally { f.db.close(); }
});

test('SQLite restart preserves actions and rejects duplicate request side effects', () => {
  const directory = mkdtempSync(join(tmpdir(), 'orafold-match-test-'));
  const path = join(directory, 'online.sqlite');
  let db: DatabaseSync | undefined;
  try {
    const f = fixture(path); db = f.db;
    const id = f.started();
    const message: Message = { protocol_version: 1, type: 'match.action', request_id: randomUUID(), match_id: id, sequence: 1, action: { type: 'advance' } };
    const before = f.service.handle('alice', message);
    db.close(); db = new DatabaseSync(path); db.exec('PRAGMA foreign_keys=ON');
    const resumed = new MatchService(db, f.options);
    assert.deepEqual(resumed.handle('alice', message), before);
    const snapshot = resumed.view('alice', id) as any;
    assert.equal(snapshot.state.accepted_actions, 1);
    assert.equal(snapshot.next_action_sequence, 2);
    assert.equal(resumed.activeMatchFor('bob'), id);
  } finally { db?.close(); rmSync(directory, { recursive: true, force: true }); }
});

test('ready, turn and reconnect timeouts are authoritative and bounded', () => {
  const f = fixture();
  try {
    const first = f.paired(); f.time(30_000); assert.deepEqual(f.service.tick(), [first]);
    assert.equal((f.service.view('alice', first) as any).state.result.reason, 'ready_timeout');
    const second = f.started(); f.time(30_000); assert.deepEqual(f.service.tick(), [second]);
    assert.equal((f.service.view('alice', second) as any).state.result.reason, 'simulation_turn_timeout');
    const third = f.started(); f.service.disconnected('alice'); f.time(89_999);
    assert.deepEqual(f.service.tick(), []);
    f.time(1); assert.deepEqual(f.service.tick(), [third]);
    assert.deepEqual((f.service.view('bob', third) as any).state.result, { winner_id: 'bob', reason: 'reconnect_timeout' });
    const fourth = f.started(); f.service.disconnected('alice'); f.service.disconnected('bob'); f.time(90_000); f.service.tick();
    assert.equal((f.service.view('alice', fourth) as any).state.result.winner_id, null);
  } finally { f.db.close(); }
});

test('private invitations expire, are single use and respect blocking', () => {
  const f = fixture();
  try {
    const social = new SocialService(f.db);
    const invite = f.send('alice', 'private.create');
    social.handle('bob', { type: 'social.block', target_user_id: 'alice' });
    assert.throws(() => f.send('bob', 'private.join', { invite_code: invite.invite_code }), /INVALID_INVITE/);
    const id = f.send('eve', 'private.join', { invite_code: invite.invite_code }).match_id;
    assert.equal(f.service.activeMatchFor('alice'), id);
    assert.throws(() => f.send('bob', 'private.join', { invite_code: invite.invite_code }), /INVALID_INVITE/);
    f.time(30_000); f.service.tick();
    const next = f.send('alice', 'private.create'); f.time(120_000);
    assert.throws(() => f.send('bob', 'private.join', { invite_code: next.invite_code }), /INVALID_INVITE/);
    f.send('alice', 'matchmaking.join', { mode: 'casual', region: 'local' });
    assert.equal(f.send('bob', 'matchmaking.join', { mode: 'casual', region: 'local' }).type, 'matchmaking.queued');
  } finally { f.db.close(); }
});

test('queue region isolation, cancellation, expiry and disconnect leave no matches', () => {
  const f = fixture();
  try {
    f.send('alice', 'matchmaking.join', { mode: 'casual', region: 'eu' });
    f.send('bob', 'matchmaking.join', { mode: 'casual', region: 'us' });
    assert.equal(f.service.activeMatchFor('alice'), null);
    f.send('bob', 'matchmaking.leave'); f.service.disconnected('alice');
    assert.equal((f.db.prepare('SELECT COUNT(*) AS n FROM online_matchmaking_entries').get() as { n: number }).n, 0);
    f.send('alice', 'matchmaking.join', { mode: 'casual', region: 'local' }); f.time(120_000); f.service.tick();
    assert.equal((f.db.prepare('SELECT COUNT(*) AS n FROM online_matchmaking_entries').get() as { n: number }).n, 0);
  } finally { f.db.close(); }
});

test('account lifecycle cancels active matches and removes transient private records', () => {
  const f = fixture();
  try {
    const id = f.started();
    f.service.abortAccount('alice');
    const view = f.service.view('bob', id) as any;
    assert.equal(view.status, 'cancelled');
    assert.equal(view.state.result.reason, 'account_deleted');
    assert.equal(f.service.activeMatchFor('alice'), null);
    assert.equal((f.db.prepare('SELECT COUNT(*) AS n FROM online_requests WHERE user_id=?').get('alice') as { n: number }).n, 0);
    f.service.abortAccount('alice');
    assert.equal((f.service.view('bob', id) as any).sequence, view.sequence);
  } finally { f.db.close(); }
});

test('reconnect snapshots bound their public event tail and identify truncated history', () => {
  const f = fixture();
  try {
    const id = f.started();
    const insert = f.db.prepare('INSERT INTO online_match_events VALUES(?,?,?,?)');
    const initial = f.service.view('alice', id).sequence as number;
    for (let i = 1; i <= 120; i++) insert.run(id, initial + i, JSON.stringify({ type: 'fixture.event' }), i);
    const full = f.service.view('alice', id) as any;
    assert.equal(full.events.length, 100); assert.equal(full.events_truncated, true);
    assert.equal(full.events.at(-1).sequence, full.sequence);
    const recent = f.service.view('alice', id, full.sequence - 5) as any;
    assert.equal(recent.events.length, 5); assert.equal(recent.events_truncated, false);
    assert.deepEqual(recent.state, full.state);
  } finally { f.db.close(); }
});
