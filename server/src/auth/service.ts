import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';
import argon2 from 'argon2';
import { readPublicProfile, type PublicProfile } from '../profiles/profile.ts';

export class AuthError extends Error {
  constructor(public readonly code: string, public readonly status = 400) { super(code); }
}

type Session = { token: string; csrfToken: string; profile: PublicProfile; expiresAt: number };
type Authenticated = { userId: string; csrfToken: string; expiresAt: number };
const digest = (token: string): string => createHash('sha256').update(token).digest('hex');
const freshToken = (): string => randomBytes(32).toString('base64url');
const hashOptions = { type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1 };
const normalize = (username: string): string => username.trim().toLowerCase();
let dummyHash: Promise<string> | undefined;

export class AuthService {
  private readonly now: () => number;
  private readonly ttl: number;
  constructor(private readonly db: DatabaseSync, options: { sessionTtlMs?: number; now?: () => number } = {}) {
    this.now = options.now ?? Date.now;
    this.ttl = options.sessionTtlMs ?? 30 * 60_000;
    if (this.ttl <= 0 || !Number.isSafeInteger(this.ttl)) throw new Error('invalid_session_ttl');
  }

  private validatePassword(password: string): void {
    if (typeof password !== 'string' || password.length < 12 || Buffer.byteLength(password) > 1024) {
      throw new AuthError('INVALID_ACCOUNT_INPUT');
    }
  }

  private audit(userId: string | null, kind: string): void {
    this.db.prepare('INSERT INTO account_audit_events(id, user_id, kind, created_at) VALUES (?, ?, ?, ?)')
      .run(randomUUID(), userId, kind, this.now());
  }

  async register(username: string, password: string, displayName: string): Promise<PublicProfile> {
    this.validatePassword(password);
    if (typeof username !== 'string' || typeof displayName !== 'string') throw new AuthError('INVALID_ACCOUNT_INPUT');
    username = normalize(username);
    displayName = displayName.trim();
    if (!/^[a-z0-9_]{3,32}$/.test(username) || displayName.length < 2 || displayName.length > 40 || /[\p{Cc}\p{Cf}]/u.test(displayName)) {
      throw new AuthError('INVALID_ACCOUNT_INPUT');
    }
    const passwordHash = await argon2.hash(password, hashOptions);
    const id = randomUUID();
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.prepare('INSERT INTO users(id, username, password_hash, created_at) VALUES (?, ?, ?, ?)')
        .run(id, username, passwordHash, this.now());
      this.db.prepare('INSERT INTO profiles(user_id, display_name, created_at) VALUES (?, ?, ?)')
        .run(id, displayName, this.now());
      this.audit(id, 'account.registered');
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      if ((error as { code?: string }).code?.startsWith('ERR_SQLITE') || String(error).includes('UNIQUE constraint')) {
        throw new AuthError('REGISTRATION_UNAVAILABLE');
      }
      throw error;
    }
    return this.getProfile(id);
  }

  async login(username: string, password: string): Promise<Session> {
    if (typeof username !== 'string' || typeof password !== 'string' || username.length > 64 || Buffer.byteLength(password) > 1024) {
      throw new AuthError('INVALID_CREDENTIALS', 401);
    }
    const row = this.db.prepare('SELECT id, password_hash, status FROM users WHERE username = ?').get(normalize(username));
    dummyHash ??= argon2.hash(freshToken(), hashOptions);
    // Await identical warmup for known/unknown handles, including the first request.
    const fallbackHash = await dummyHash;
    const hash = row ? row.password_hash as string : fallbackHash;
    const matches = await argon2.verify(hash, password);
    if (!row || !matches || row.status !== 'active') throw new AuthError('INVALID_CREDENTIALS', 401);
    // Password verification yields: a concurrent recovery/deletion must win.
    const current = this.db.prepare('SELECT password_hash,status FROM users WHERE id = ?').get(row.id as string);
    if (!current || current.status !== 'active' || current.password_hash !== hash) throw new AuthError('INVALID_CREDENTIALS', 401);
    this.audit(row.id as string, 'session.created');
    return this.createSession(row.id as string);
  }

  private createSession(userId: string): Session {
    // Expired tokens contain no usable authority; bounded cleanup avoids indefinite growth.
    this.db.prepare('DELETE FROM sessions WHERE expires_at <= ? OR revoked_at IS NOT NULL').run(this.now());
    const count = this.db.prepare('SELECT COUNT(*) AS count FROM sessions WHERE user_id = ?').get(userId)!.count as number;
    if (count >= 8) {
      this.db.prepare('DELETE FROM sessions WHERE token_hash = (SELECT token_hash FROM sessions WHERE user_id = ? ORDER BY created_at ASC, token_hash ASC LIMIT 1)').run(userId);
    }
    const token = freshToken();
    const csrfToken = freshToken();
    const expiresAt = this.now() + this.ttl;
    this.db.prepare('INSERT INTO sessions(token_hash,user_id,csrf_token,created_at,expires_at) VALUES (?,?,?,?,?)')
      .run(digest(token), userId, csrfToken, this.now(), expiresAt);
    return { token, csrfToken, profile: this.getProfile(userId), expiresAt };
  }

  authenticate(token: string): Authenticated {
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) throw new AuthError('UNAUTHENTICATED', 401);
    const row = this.db.prepare(`SELECT s.user_id, s.csrf_token, s.expires_at FROM sessions s
      JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.revoked_at IS NULL
      AND s.expires_at > ? AND u.status = 'active'`).get(digest(token), this.now());
    if (!row) throw new AuthError('UNAUTHENTICATED', 401);
    return { userId: row.user_id as string, csrfToken: row.csrf_token as string, expiresAt: row.expires_at as number };
  }

  rotate(token: string): Session {
    const auth = this.authenticate(token);
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.logout(token);
      const result = this.createSession(auth.userId);
      this.db.exec('COMMIT');
      return result;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }

  logout(token: string): void {
    if (typeof token !== 'string' || token.length > 256) return;
    this.db.prepare('UPDATE sessions SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL').run(this.now(), digest(token));
  }

  getProfile(userId: string): PublicProfile {
    const profile = readPublicProfile(this.db, userId);
    if (!profile) throw new AuthError('PROFILE_NOT_FOUND', 404);
    return profile;
  }

  requestRecovery(_username: string): { accepted: true } {
    // No mail provider or verified recovery identity exists yet. Do not reveal existence.
    return { accepted: true };
  }

  /** Trusted operator CLI ONLY, after independently verifying the account holder. */
  issueRecoveryToken(username: string): string | null {
    const row = this.db.prepare("SELECT id FROM users WHERE username = ? AND status = 'active'").get(normalize(username));
    if (!row) return null;
    const userId = row.id as string;
    const token = freshToken();
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.prepare('DELETE FROM recovery_tokens WHERE user_id = ? OR expires_at <= ?').run(userId, this.now());
      this.db.prepare('INSERT INTO recovery_tokens(token_hash,user_id,expires_at) VALUES (?,?,?)').run(digest(token), userId, this.now() + 15 * 60_000);
      this.audit(userId, 'recovery.issued');
      this.db.exec('COMMIT');
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
    return token;
  }

  async resetPassword(token: string, password: string): Promise<void> {
    this.validatePassword(password);
    if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) throw new AuthError('INVALID_RECOVERY');
    const passwordHash = await argon2.hash(password, hashOptions);
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const row = this.db.prepare('SELECT user_id FROM recovery_tokens WHERE token_hash = ? AND used_at IS NULL AND expires_at > ?').get(digest(token), this.now());
      if (!row) throw new AuthError('INVALID_RECOVERY');
      const userId = row.user_id as string;
      this.db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, userId);
      this.db.prepare('UPDATE recovery_tokens SET used_at = ? WHERE user_id = ?').run(this.now(), userId);
      this.db.prepare('UPDATE sessions SET revoked_at = ? WHERE user_id = ?').run(this.now(), userId);
      this.audit(userId, 'recovery.completed');
      this.db.exec('COMMIT');
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }

  exportAccount(userId: string): object {
    const user = this.db.prepare('SELECT id,username,status,created_at FROM users WHERE id = ?').get(userId);
    if (!user) throw new AuthError('UNAUTHENTICATED', 401);
    return {
      account: user,
      profile: this.getProfile(userId),
      auditEvents: this.db.prepare('SELECT kind,created_at FROM account_audit_events WHERE user_id = ? ORDER BY created_at,id').all(userId),
      decks: this.db.prepare('SELECT id,catalog_version,definition_json,version FROM decks WHERE user_id = ?').all(userId),
      collection: this.db.prepare('SELECT card_id,catalog_version,quantity FROM collections WHERE user_id = ?').all(userId),
      social: {
        relationships: this.hasTable('social_edges') ? this.db.prepare('SELECT * FROM social_edges WHERE low_id = ? OR high_id = ?').all(userId, userId) : [],
        blocks: this.hasTable('social_blocks') ? this.db.prepare('SELECT target_id,created_at FROM social_blocks WHERE owner_id = ?').all(userId) : [],
      },
    };
  }

  private hasTable(name: string): boolean {
    return !!this.db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(name);
  }

  async deleteAccount(userId: string, password: string): Promise<void> {
    const row = this.db.prepare('SELECT password_hash FROM users WHERE id = ?').get(userId);
    if (!row || typeof password !== 'string' || Buffer.byteLength(password) > 1024 || !await argon2.verify(row.password_hash as string, password)) throw new AuthError('INVALID_CREDENTIALS', 401);
    const current = this.db.prepare('SELECT password_hash,status FROM users WHERE id = ?').get(userId);
    if (!current || current.status !== 'active' || current.password_hash !== row.password_hash) throw new AuthError('INVALID_CREDENTIALS', 401);
    // Preserve a pseudonymous identity for match integrity; remove login and profile data.
    this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.prepare("UPDATE users SET status='deleted', username=?, password_hash='' WHERE id=?").run(`deleted_${randomUUID()}`, userId);
      this.db.prepare("UPDATE profiles SET display_name='Deleted player',avatar='default',language='und' WHERE user_id=?").run(userId);
      this.db.prepare('DELETE FROM sessions WHERE user_id=?').run(userId);
      this.db.prepare('DELETE FROM recovery_tokens WHERE user_id=?').run(userId);
      this.db.prepare('DELETE FROM decks WHERE user_id=?').run(userId);
      this.db.prepare('DELETE FROM collections WHERE user_id=?').run(userId);
      if (this.hasTable('social_edges')) this.db.prepare('DELETE FROM social_edges WHERE low_id=? OR high_id=?').run(userId, userId);
      if (this.hasTable('social_blocks')) this.db.prepare('DELETE FROM social_blocks WHERE owner_id=? OR target_id=?').run(userId, userId);
      this.audit(userId, 'account.deleted');
      this.db.exec('COMMIT');
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
}
