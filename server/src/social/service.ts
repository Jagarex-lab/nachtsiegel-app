import type { DatabaseSync } from 'node:sqlite';

export class SocialError extends Error {
  readonly status = 400;
  constructor(readonly code: string) { super(code); }
}

type SocialMessage = { type: string; request_id?: string; target_user_id?: string };
type Edge = { low_id: string; high_id: string; requester_id: string; status: 'pending' | 'accepted' };

/** Small private social graph. Public account data, chat and presence are intentionally absent. */
export class SocialService {
  constructor(private readonly db: DatabaseSync) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS social_edges (
        low_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        high_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        requester_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
        created_at INTEGER NOT NULL,
        PRIMARY KEY (low_id, high_id),
        CHECK (low_id < high_id),
        CHECK (requester_id = low_id OR requester_id = high_id)
      );
      CREATE INDEX IF NOT EXISTS social_edges_high ON social_edges(high_id);
      CREATE TABLE IF NOT EXISTS social_blocks (
        owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        target_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (owner_id, target_id),
        CHECK (owner_id <> target_id)
      );
      CREATE INDEX IF NOT EXISTS social_blocks_target ON social_blocks(target_id);
    `);
  }

  handle(userId: string, message: SocialMessage): Record<string, unknown> {
    if (!this.userExists(userId)) throw new SocialError('SOCIAL_UNAVAILABLE');
    if (message.type === 'social.list') return this.response(message, this.list(userId));
    const target = message.target_user_id;
    if (typeof target !== 'string' || target.length < 1 || target.length > 128 || target === userId || !this.userExists(target)) {
      throw new SocialError('SOCIAL_UNAVAILABLE');
    }
    const [low, high] = [userId, target].sort();
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const edge = this.db.prepare('SELECT * FROM social_edges WHERE low_id = ? AND high_id = ?').get(low!, high!) as Edge | undefined;
      switch (message.type) {
        case 'social.request': {
          this.requireUnblocked(userId, target);
          if (edge) break; // Duplicate requests never auto-accept a reverse request.
          if (this.edgeCount(userId) >= 100 || this.edgeCount(target) >= 100) throw new SocialError('SOCIAL_LIMIT');
          this.db.prepare("INSERT INTO social_edges VALUES (?, ?, ?, 'pending', ?)").run(low!, high!, userId, Date.now());
          break;
        }
        case 'social.accept': {
          this.requireUnblocked(userId, target);
          if (!edge || (edge.status === 'pending' && edge.requester_id === userId)) throw new SocialError('SOCIAL_UNAVAILABLE');
          this.db.prepare("UPDATE social_edges SET status = 'accepted' WHERE low_id = ? AND high_id = ?").run(low!, high!);
          break;
        }
        case 'social.remove': {
          this.db.prepare('DELETE FROM social_edges WHERE low_id = ? AND high_id = ?').run(low!, high!);
          break;
        }
        case 'social.block': {
          const count = this.db.prepare('SELECT COUNT(*) AS n FROM social_blocks WHERE owner_id = ?').get(userId) as { n: number };
          const existing = this.db.prepare('SELECT 1 FROM social_blocks WHERE owner_id = ? AND target_id = ?').get(userId, target);
          if (!existing && count.n >= 1000) throw new SocialError('SOCIAL_LIMIT');
          this.db.prepare('INSERT OR IGNORE INTO social_blocks VALUES (?, ?, ?)').run(userId, target, Date.now());
          this.db.prepare('DELETE FROM social_edges WHERE low_id = ? AND high_id = ?').run(low!, high!);
          break;
        }
        default: throw new SocialError('UNKNOWN_TYPE');
      }
      this.db.exec('COMMIT');
      return this.response(message, this.list(userId));
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  /** For private invitations: blocking must be enforced in both directions. */
  isBlocked(first: string, second: string): boolean {
    return !!this.db.prepare('SELECT 1 FROM social_blocks WHERE (owner_id = ? AND target_id = ?) OR (owner_id = ? AND target_id = ?)').get(first, second, second, first);
  }

  private list(userId: string): Record<string, unknown> {
    const edges = this.db.prepare('SELECT * FROM social_edges WHERE low_id = ? OR high_id = ? ORDER BY created_at, low_id, high_id').all(userId, userId) as Edge[];
    return {
      friends: edges.filter(edge => edge.status === 'accepted').map(edge => edge.low_id === userId ? edge.high_id : edge.low_id),
      incoming_requests: edges.filter(edge => edge.status === 'pending' && edge.requester_id !== userId).map(edge => edge.requester_id),
      outgoing_requests: edges.filter(edge => edge.status === 'pending' && edge.requester_id === userId).map(edge => edge.low_id === userId ? edge.high_id : edge.low_id),
      blocked: this.db.prepare('SELECT target_id FROM social_blocks WHERE owner_id = ? ORDER BY created_at, target_id').all(userId).map(row => row.target_id),
    };
  }

  private userExists(userId: string): boolean { return !!this.db.prepare('SELECT 1 FROM users WHERE id = ?').get(userId); }
  private edgeCount(userId: string): number { return (this.db.prepare('SELECT COUNT(*) AS n FROM social_edges WHERE low_id = ? OR high_id = ?').get(userId, userId) as { n: number }).n; }
  private requireUnblocked(first: string, second: string): void { if (this.isBlocked(first, second)) throw new SocialError('SOCIAL_UNAVAILABLE'); }
  private response(message: SocialMessage, graph: Record<string, unknown>): Record<string, unknown> {
    return { protocol_version: 1, type: 'social.state', request_id: message.request_id, ...graph };
  }
}
