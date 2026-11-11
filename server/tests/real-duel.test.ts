import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createApp } from '../src/transport/app.js';
import { GodotRuleAdapter, type GodotState } from '../src/matches/godot-adapter.js';
import { MatchService } from '../src/matches/service.js';
import { registerClient, SimulatedClient } from '../tools/load.js';
import { driveRealDuel } from '../tools/real-duel.js';

const canonical = (value: any): string => Array.isArray(value) ? `[${value.map(canonical).join(',')}]` : value !== null && typeof value === 'object' ? `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}` : JSON.stringify(value);
const digest = (value: any) => createHash('sha256').update(canonical(value)).digest('hex');

test('actual two-account production duel: private opening, immutable rejection, restart, full combat and exact replay', { timeout: 600_000 }, async () => {
  const directory = mkdtempSync(join(tmpdir(), 'orafold-real-duel-'));
  const dbPath = join(directory, 'duel.sqlite');
  let app = await createApp({ dbPath, port: 0 });
  let address = await app.start();
  let clients: SimulatedClient[] = [];
  try {
    clients.push(await registerClient(address.url, address.wsUrl, 0), await registerClient(address.url, address.wsUrl, 1), await registerClient(address.url, address.wsUrl, 2));
    let [alice, bob, outsider] = clients as [SimulatedClient, SimulatedClient, SimulatedClient];
    assert.ok(app.matches.adapter instanceof GodotRuleAdapter);
    const catalog = (await alice.send('catalog.get')).catalog;
    assert.equal(catalog.card_count, 550); assert.equal(catalog.hero_hp, 30); assert.equal(catalog.deck_size, 30); assert.equal(catalog.starters.length, 4);
    for (const starter of catalog.starters) assert.equal(starter.cards.length, 30);
    assert.equal((await alice.send('deck.select', { selection: { cards: Array(30).fill('invented-card') } })).code, 'INVALID_DECK');
    await alice.send('deck.select', { selection: { starter_id: catalog.starters[0].id } });
    await bob.send('deck.select', { selection: { starter_id: catalog.starters[1].id } });
    const invite = await alice.send('private.create');
    const id = (await bob.send('private.join', { invite_code: invite.invite_code })).match_id;
    await alice.send('match.ready', { match_id: id }); await bob.send('match.ready', { match_id: id });
    const initial = app.matches.view(alice.userId, id) as any;
    assert.equal(initial.state.rules_profile, 'production-550-v1'); assert.equal(initial.state.stage, 'mulligan');
    assert.equal(initial.state.self.hp, 30); assert.equal(initial.state.opponent.hp, 30);
    assert.equal(initial.state.opponent.hand, undefined); assert.equal(initial.state.opponent.deck, undefined);
    assert.equal(initial.state.self.deck, undefined); assert.equal(initial.state.rng, undefined); assert.equal(initial.state.seed, undefined);
    assert.equal((await outsider.send('match.reconnect', { match_id: id, after_sequence: 0 })).code, 'MATCH_NOT_FOUND');
    const replayUrl = `/matches/${id}/replay`;
    await assert.rejects(alice.request(replayUrl, undefined, 'GET'), /HTTP 409/);
    const row = () => app.db.prepare('SELECT state,server_seed FROM online_matches WHERE id=?').get(id) as { state: string; server_seed: string };
    const before = row();
    assert.equal(JSON.stringify(initial).includes(before.server_seed), false);
    const illegal = await alice.send('match.action', { match_id: id, sequence: initial.next_action_sequence, action: { type: 'command', name: 'play', args: [999, 99] } });
    assert.equal(illegal.code, 'ILLEGAL_COMMAND'); assert.equal(row().state, before.state);
    const messageId = randomUUID();
    const action = { match_id: id, sequence: initial.next_action_sequence, action: { type: 'command', name: 'mulligan', args: [[0]] } };
    const first = await alice.send('match.action', action, messageId);
    assert.equal(first.type, 'match.state');
    assert.deepEqual(await alice.send('match.action', action, messageId), first);
    assert.equal((await alice.send('match.action', { ...action, action: { type: 'command', name: 'mulligan', args: [[]] } }, messageId)).code, 'REQUEST_ID_CONFLICT');
    assert.equal((await alice.send('match.action', action)).code, 'INVALID_SEQUENCE');
    const bView = app.matches.view(bob.userId, id) as any;
    assert.equal(bView.state.opponent.hand, undefined);
    assert.equal(bView.events.at(-1).action.args, undefined);
    assert.equal(bView.state.opening.mulligan_done, false); assert.equal(bView.state.opening.opponent_mulligan_done, true);
    const identities = clients.map(client => ({ token: client.token, userId: client.userId }));
    await Promise.all(clients.map(client => client.disconnect())); await app.close();
    app = await createApp({ dbPath, port: 0 }); address = await app.start();
    clients = identities.map(identity => new SimulatedClient(address.url, address.wsUrl, identity.token, identity.userId));
    await Promise.all(clients.map(client => client.connect()));
    [alice, bob, outsider] = clients as [SimulatedClient, SimulatedClient, SimulatedClient];
    assert.deepEqual(await alice.send('match.action', action, messageId), first);
    const restored = await alice.send('match.reconnect', { match_id: id, after_sequence: first.sequence });
    assert.deepEqual(restored.state, first.state); assert.equal(restored.next_action_sequence, 2);
    const result = await driveRealDuel(app, [alice, bob], id);
    assert.equal(result.view.status, 'finished'); assert.equal(result.view.state.result.reason, 'duel');
    assert.ok([alice.userId, bob.userId].includes(result.view.state.result.winner_id));
    assert.ok((result.counts.play ?? 0) > 0); assert.ok((result.counts.endTurn ?? 0) > 0);
    assert.equal(result.counts.origin, 2); assert.equal(result.counts.secondOrigin, 1); assert.equal(result.counts.secondCard, 1);
    const replay = await bob.request(replayUrl, undefined, 'GET');
    assert.equal(replay.simulation, false); assert.equal(replay.actions.length, result.actions + 1);
    assert.equal(replay.actions.some((entry: any) => entry.action.type === 'advance' || entry.action.type === 'concede'), false);
    await assert.rejects(outsider.request(replayUrl, undefined, 'GET'), /HTTP 404/);
    const journal = replay.engine_replay.commands;
    assert.equal(journal.length, replay.actions.length);
    for (let i = 0; i < journal.length; i++) {
      const accepted = replay.actions[i]; const command = journal[i];
      assert.equal(command.name, accepted.action.name);
      assert.equal(command.args[0], accepted.player_id === replay.players[0] ? 'hero' : 'enemy');
      assert.deepEqual(command.args.slice(1), accepted.action.args);
    }
    const verified = (app.matches.adapter as GodotRuleAdapter).verify_state(replay.engine_replay as GodotState);
    assert.equal(digest(verified), replay.final_state_hash);
    assert.deepEqual(verified.result, replay.result);
    assert.deepEqual((app.matches.adapter as GodotRuleAdapter).get_player_view(verified, alice.userId), app.matches.view(alice.userId, id).state);
  } finally {
    await Promise.all(clients.map(client => client.disconnect().catch(() => {})));
    await app.close(); rmSync(directory, { recursive: true, force: true });
  }
});

test('actual kernel replay also preserves a server lifecycle timeout result', { timeout: 60_000 }, () => {
  const db = new DatabaseSync(':memory:');
  db.exec("PRAGMA foreign_keys=ON; CREATE TABLE users(id TEXT PRIMARY KEY); INSERT INTO users VALUES('alice'),('bob');");
  let now = 1000;
  const service = new MatchService(db, { now: () => now, readyTimeoutMs: 1 });
  const send = (user: string) => service.handle(user, { protocol_version: 1, type: 'matchmaking.join', request_id: randomUUID(), mode: 'casual', region: 'local' }) as any;
  try {
    send('alice'); const id = send('bob').match_id;
    now += 1; assert.deepEqual(service.tick(), [id]);
    const replay = service.replay('alice', id) as any;
    assert.equal(replay.result.reason, 'ready_timeout');
    const adapter = service.adapter as GodotRuleAdapter;
    const verified = adapter.verify_state(replay.engine_replay);
    assert.equal(digest(verified), replay.final_state_hash);
    assert.deepEqual(adapter.get_player_view(verified, 'alice'), service.view('alice', id).state);
    assert.equal((service.view('alice', id).state as any).finished, true);
  } finally { db.close(); }
});
