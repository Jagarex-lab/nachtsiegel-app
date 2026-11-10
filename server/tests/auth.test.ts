import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { openDatabase } from '../src/persistence/database.ts';
import { AuthService, AuthError } from '../src/auth/service.ts';
import { RateLimiter } from '../src/security/rate-limit.ts';

const password = 'Prototype-Local-Test-Password-42!';

test('Argon2id storage, public profile allowlist, generic login errors and SQL input safety', async () => {
  const db = openDatabase(':memory:');
  try {
    const auth = new AuthService(db);
    const profile = await auth.register('Test_User', password, 'Test Player');
    assert.equal(profile.displayName, 'Test Player');
    assert.deepEqual(Object.keys(profile).sort(), ['avatar', 'createdAt', 'displayName', 'language', 'level', 'playerId']);
    const row = db.prepare('SELECT password_hash,username FROM users').get()!;
    assert.match(row.password_hash as string, /^\$argon2id\$v=19\$m=65536,t=3,p=1\$/);
    assert.equal(row.username, 'test_user');
    assert.ok(!(row.password_hash as string).includes(password));
    const good = await auth.login('TEST_USER', password);
    assert.equal(good.profile.playerId, profile.playerId);
    for (const [username, secret] of [['test_user', 'wrong'], ['missing_user', 'wrong'], ["' OR 1=1 --", password]]) {
      await assert.rejects(auth.login(username!, secret!), (error: unknown) => error instanceof AuthError && error.code === 'INVALID_CREDENTIALS' && error.status === 401);
    }
    await assert.rejects(auth.register('test_user', password, 'Other'), { code: 'REGISTRATION_UNAVAILABLE' });
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM users').get()!.n, 1);
    await assert.rejects(auth.register('bad', 'short', 'Test'), { code: 'INVALID_ACCOUNT_INPUT' });
    await assert.rejects(auth.register('bad_name', password, 'A\u0000B'), { code: 'INVALID_ACCOUNT_INPUT' });
  } finally { db.close(); }
});

test('session expiry, rotation, revocation, random tokens and maximum active sessions', async () => {
  const db = openDatabase(':memory:');
  let now = 1_000;
  try {
    const auth = new AuthService(db, { now: () => now, sessionTtlMs: 60_000 });
    await auth.register('session_user', password, 'Session Player');
    const first = await auth.login('session_user', password);
    const tokenHash = createHash('sha256').update(first.token).digest('hex');
    assert.notEqual(first.token, first.csrfToken);
    assert.equal(first.token.length, 43);
    assert.equal(db.prepare('SELECT token_hash FROM sessions').get()!.token_hash, tokenHash);
    assert.throws(() => auth.authenticate('invalid'), { code: 'UNAUTHENTICATED' });
    const rotated = auth.rotate(first.token);
    assert.notEqual(rotated.token, first.token);
    assert.throws(() => auth.authenticate(first.token), { code: 'UNAUTHENTICATED' });
    assert.ok(auth.authenticate(rotated.token));
    now = rotated.expiresAt;
    assert.throws(() => auth.authenticate(rotated.token), { code: 'UNAUTHENTICATED' });
    const active = await auth.login('session_user', password);
    auth.logout(active.token);
    auth.logout(active.token);
    assert.throws(() => auth.authenticate(active.token), { code: 'UNAUTHENTICATED' });
    const tokens: string[] = [];
    for (let i = 0; i < 9; i++) { now++; tokens.push((await auth.login('session_user', password)).token); }
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE revoked_at IS NULL').get()!.n, 8);
    assert.throws(() => auth.authenticate(tokens[0]!), { code: 'UNAUTHENTICATED' });
    assert.ok(auth.authenticate(tokens.at(-1)!));
  } finally { db.close(); }
});

test('recovery is generic, tokens one-use and expiring, reset revokes sessions', async () => {
  const db = openDatabase(':memory:');
  let now = 1_000;
  try {
    const auth = new AuthService(db, { now: () => now });
    const profile = await auth.register('recovery_user', password, 'Recovery Player');
    const session = await auth.login('recovery_user', password);
    assert.deepEqual(auth.requestRecovery('recovery_user'), auth.requestRecovery('not_registered'));
    const token = auth.issueRecoveryToken('recovery_user')!;
    assert.ok(token);
    assert.ok(!JSON.stringify(db.prepare('SELECT * FROM recovery_tokens').all()).includes(token));
    await auth.resetPassword(token, `${password}new`);
    assert.throws(() => auth.authenticate(session.token), { code: 'UNAUTHENTICATED' });
    await assert.rejects(auth.resetPassword(token, password), { code: 'INVALID_RECOVERY' });
    await assert.rejects(auth.login('recovery_user', password), { code: 'INVALID_CREDENTIALS' });
    assert.equal((await auth.login('recovery_user', `${password}new`)).profile.playerId, profile.playerId);
    const expired = auth.issueRecoveryToken('recovery_user')!;
    now += 15 * 60_000;
    await assert.rejects(auth.resetPassword(expired, password), { code: 'INVALID_RECOVERY' });
  } finally { db.close(); }
});

test('deletion reauthenticates, removes credentials and exports no password or tokens', async () => {
  const db = openDatabase(':memory:');
  try {
    const auth = new AuthService(db);
    const profile = await auth.register('delete_user', password, 'Private Name');
    const session = await auth.login('delete_user', password);
    const exported = JSON.stringify(auth.exportAccount(profile.playerId));
    assert.ok(exported.includes('delete_user'));
    assert.ok(!exported.includes('password'));
    assert.ok(!exported.includes(session.token));
    assert.ok(!exported.includes(session.csrfToken));
    await assert.rejects(auth.deleteAccount(profile.playerId, 'wrong'), { code: 'INVALID_CREDENTIALS' });
    await auth.deleteAccount(profile.playerId, password);
    assert.throws(() => auth.authenticate(session.token), { code: 'UNAUTHENTICATED' });
    await assert.rejects(auth.login('delete_user', password), { code: 'INVALID_CREDENTIALS' });
    assert.equal(auth.getProfile(profile.playerId).displayName, 'Deleted player');
    assert.equal(db.prepare('SELECT password_hash FROM users WHERE id=?').get(profile.playerId)!.password_hash, '');
  } finally { db.close(); }
});

test('foreign keys enforce data integrity and limiter is bounded/fails closed', () => {
  const db = openDatabase(':memory:');
  try {
    assert.throws(() => db.prepare('INSERT INTO profiles(user_id,display_name,created_at) VALUES (?,?,?)').run('not-user', 'name', 1));
    let now = 0;
    const limiter = new RateLimiter(() => now, 2);
    assert.equal(limiter.consume('a', 2, 100), true);
    assert.equal(limiter.consume('a', 2, 100), true);
    assert.equal(limiter.consume('a', 2, 100), false);
    assert.equal(limiter.consume('b', 1, 100), true);
    assert.equal(limiter.consume('c', 1, 100), false);
    now = 100;
    assert.equal(limiter.consume('c', 1, 100), true);
    assert.equal(limiter.consume('a', 1, 100), true);
  } finally { db.close(); }
});

test('accounts/sessions survive reopen and disabled accounts cannot resume', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'orafold-auth-'));
  const path = join(directory, 'test.sqlite');
  let db = openDatabase(path);
  try {
    const auth = new AuthService(db);
    const profile = await auth.register('persistent_user', password, 'Persistent');
    const session = await auth.login('persistent_user', password);
    db.close();
    db = openDatabase(path);
    const resumed = new AuthService(db);
    assert.equal(resumed.authenticate(session.token).userId, profile.playerId);
    assert.equal(resumed.getProfile(profile.playerId).displayName, 'Persistent');
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM schema_migrations').get()!.n, 1);
    db.prepare("UPDATE users SET status = 'disabled' WHERE id = ?").run(profile.playerId);
    assert.throws(() => resumed.authenticate(session.token), { code: 'UNAUTHENTICATED' });
    await assert.rejects(resumed.login('persistent_user', password), { code: 'INVALID_CREDENTIALS' });
  } finally { db.close(); rmSync(directory, { recursive: true, force: true }); }
});

test('password changes during asynchronous verification cannot create sessions or delete accounts', async () => {
  const db = openDatabase(':memory:');
  try {
    const auth = new AuthService(db);
    const profile = await auth.register('racing_user', password, 'Race Player');
    const originalHash = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(profile.playerId)!.password_hash as string;
    const login = auth.login('racing_user', password);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(`${originalHash}changed`, profile.playerId);
    await assert.rejects(login, { code: 'INVALID_CREDENTIALS' });
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM sessions').get()!.n, 0);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(originalHash, profile.playerId);
    const deletion = auth.deleteAccount(profile.playerId, password);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(`${originalHash}changed`, profile.playerId);
    await assert.rejects(deletion, { code: 'INVALID_CREDENTIALS' });
    assert.equal(db.prepare('SELECT status FROM users WHERE id = ?').get(profile.playerId)!.status, 'active');
  } finally { db.close(); }
});
