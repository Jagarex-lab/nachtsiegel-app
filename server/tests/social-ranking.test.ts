import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { SocialService } from '../src/social/service.js';
import { calculateElo, EloSandbox } from '../src/rankings/elo.js';
import { UnavailableEconomy } from '../src/economy/port.js';

function fixture() {
  const db = new DatabaseSync(':memory:');
  db.exec('PRAGMA foreign_keys = ON; CREATE TABLE users (id TEXT PRIMARY KEY);');
  for (const id of ['alice', 'bob', 'carol']) db.prepare('INSERT INTO users VALUES (?)').run(id);
  return { db, social: new SocialService(db) };
}

test('friend requests need receiver consent, are idempotent, and do not disclose other graphs', () => {
  const { db, social } = fixture();
  try {
    const first = social.handle('alice', { type: 'social.request', request_id: 'r1', target_user_id: 'bob' });
    assert.deepEqual(first.outgoing_requests, ['bob']);
    assert.throws(() => social.handle('alice', { type: 'social.accept', target_user_id: 'bob' }), { message: 'SOCIAL_UNAVAILABLE' });
    social.handle('alice', { type: 'social.request', target_user_id: 'bob' });
    social.handle('bob', { type: 'social.request', target_user_id: 'alice' });
    assert.deepEqual(social.handle('alice', { type: 'social.list' }).friends, []);
    const accepted = social.handle('bob', { type: 'social.accept', target_user_id: 'alice' });
    assert.deepEqual(accepted.friends, ['alice']);
    social.handle('bob', { type: 'social.accept', target_user_id: 'alice' });
    assert.deepEqual(social.handle('alice', { type: 'social.list' }).friends, ['bob']);
    assert.deepEqual(social.handle('carol', { type: 'social.list' }).friends, []);
    social.handle('alice', { type: 'social.remove', target_user_id: 'bob' });
    social.handle('alice', { type: 'social.remove', target_user_id: 'bob' });
    assert.deepEqual(social.handle('bob', { type: 'social.list' }).friends, []);
  } finally { db.close(); }
});

test('blocking removes relationships and blocks requests and invitations in both directions', () => {
  const { db, social } = fixture();
  try {
    social.handle('alice', { type: 'social.request', target_user_id: 'bob' });
    social.handle('bob', { type: 'social.accept', target_user_id: 'alice' });
    social.handle('alice', { type: 'social.block', target_user_id: 'bob' });
    social.handle('alice', { type: 'social.block', target_user_id: 'bob' });
    assert.equal(social.isBlocked('alice', 'bob'), true);
    assert.equal(social.isBlocked('bob', 'alice'), true);
    assert.deepEqual(social.handle('bob', { type: 'social.list' }).friends, []);
    assert.deepEqual(social.handle('bob', { type: 'social.list' }).blocked, []);
    assert.deepEqual(social.handle('alice', { type: 'social.list' }).blocked, ['bob']);
    for (const [sender, receiver] of [['alice', 'bob'], ['bob', 'alice']]) {
      assert.throws(() => social.handle(sender!, { type: 'social.request', target_user_id: receiver }), { message: 'SOCIAL_UNAVAILABLE' });
      assert.throws(() => social.handle(sender!, { type: 'social.accept', target_user_id: receiver }), { message: 'SOCIAL_UNAVAILABLE' });
    }
  } finally { db.close(); }
});

test('social operations validate identities, resist SQL input and enforce graph bounds', () => {
  const { db, social } = fixture();
  try {
    for (const target of ['alice', 'missing', "'; DROP TABLE users;--"]) assert.throws(() => social.handle('alice', { type: 'social.request', target_user_id: target }), { message: 'SOCIAL_UNAVAILABLE' });
    assert.throws(() => social.handle('missing', { type: 'social.list' }), { message: 'SOCIAL_UNAVAILABLE' });
    for (let i = 0; i < 101; i++) db.prepare('INSERT INTO users VALUES (?)').run(`peer_${i}`);
    for (let i = 0; i < 100; i++) social.handle('alice', { type: 'social.request', target_user_id: `peer_${i}` });
    assert.throws(() => social.handle('alice', { type: 'social.request', target_user_id: 'peer_100' }), { message: 'SOCIAL_LIMIT' });
    social.handle('alice', { type: 'social.remove', target_user_id: 'peer_0' });
    social.handle('alice', { type: 'social.request', target_user_id: 'peer_100' });
    db.prepare('DELETE FROM users WHERE id = ?').run('alice');
    assert.equal((db.prepare('SELECT COUNT(*) AS n FROM social_edges').get() as { n: number }).n, 0);
  } finally { db.close(); }
});

test('Elo candidate is deterministic, bounded, zero-sum and rejects invalid inputs', () => {
  assert.deepEqual(calculateElo(1500, 1500, 1), { first: 1516, second: 1484, delta: 16 });
  assert.deepEqual(calculateElo(1500, 1500, 0.5), { first: 1500, second: 1500, delta: 0 });
  assert.deepEqual(calculateElo(10000, 10000, 1), { first: 10000, second: 10000, delta: 0 });
  assert.equal(calculateElo(1500, 2000, 1).first + calculateElo(1500, 2000, 1).second, 3500);
  assert.throws(() => calculateElo(Number.NaN, 1500, 1), /INVALID_RATING_INPUT/);
  assert.throws(() => calculateElo(1500, 1500, 2 as 1), /INVALID_RATING_INPUT/);
});

test('sandbox persists results exactly once, rejects conflicting replay, and supports seasons', () => {
  const db = new DatabaseSync(':memory:');
  try {
    const ranking = new EloSandbox(db);
    const result = { matchId: 'test_match', firstId: 'alice', secondId: 'bob', score: 1 as const };
    const initial = ranking.applyResultOnce(result);
    assert.deepEqual(ranking.applyResultOnce({ score: 1, secondId: 'bob', firstId: 'alice', matchId: 'test_match' }), initial);
    assert.deepEqual(new EloSandbox(db).applyResultOnce(result), initial);
    assert.throws(() => ranking.applyResultOnce({ ...result, score: 0 }), /RESULT_CONFLICT/);
    assert.equal((db.prepare('SELECT rating FROM online_test_ratings WHERE user_id = ?').get('alice') as { rating: number }).rating, 1516);
    assert.deepEqual(ranking.applyResultOnce({ ...result, matchId: 'new_season_match', season: 'test_next' }), initial);
  } finally { db.close(); }
});

test('unintegrated economy fails closed for ownership, decks and transactions', async () => {
  const economy = new UnavailableEconomy();
  await assert.rejects(economy.ownedCards('alice'), { code: 'ECONOMY_NOT_INTEGRATED' });
  await assert.rejects(economy.validateDeck('alice', 'local_save', 'catalog'), { code: 'ECONOMY_NOT_INTEGRATED' });
  await assert.rejects(economy.transact({ userId: 'alice', idempotencyKey: 'r', kind: 'match_reward', authorizationRef: 'local-save' }), { code: 'ECONOMY_NOT_INTEGRATED' });
});
