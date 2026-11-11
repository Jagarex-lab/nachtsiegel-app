import { createHash } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';

export type EloScore = 0 | 0.5 | 1;
export type EloChange = { first: number; second: number; delta: number };

/** Isolated Elo candidate. No transport route or productive match processing calls this. */
export function calculateElo(first: number, second: number, score: EloScore, k = 32): EloChange {
  if (![first, second].every(value => Number.isInteger(value) && value >= 0 && value <= 10000) || ![0, 0.5, 1].includes(score) || !Number.isInteger(k) || k < 1 || k > 128) {
    throw new Error('INVALID_RATING_INPUT');
  }
  const expected = 1 / (1 + 10 ** ((second - first) / 400));
  const proposed = Math.round(k * (score - expected));
  const delta = Math.max(-first, second - 10000, Math.min(second, 10000 - first, proposed));
  return { first: first + delta, second: second - delta, delta };
}

export type SandboxResult = { matchId: string; firstId: string; secondId: string; score: EloScore; season?: string };

/** Explicit sandbox tables keep this experiment separate from eventual production ranks. */
export class EloSandbox {
  constructor(private readonly db: DatabaseSync) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS online_test_ratings (
        season TEXT NOT NULL, user_id TEXT NOT NULL, rating INTEGER NOT NULL CHECK (rating >= 0),
        PRIMARY KEY (season, user_id)
      );
      CREATE TABLE IF NOT EXISTS online_test_rating_results (
        match_id TEXT PRIMARY KEY, payload_digest TEXT NOT NULL, result_json TEXT NOT NULL
      );
    `);
  }

  applyResultOnce(result: SandboxResult): EloChange {
    const season = result.season ?? 'sandbox';
    if (![result.matchId, result.firstId, result.secondId].every(value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value)) || result.firstId === result.secondId || !/^[A-Za-z0-9_-]{1,32}$/.test(season) || ![0, 0.5, 1].includes(result.score)) {
      throw new Error('INVALID_RATING_INPUT');
    }
    const digest = createHash('sha256').update(JSON.stringify({ matchId: result.matchId, firstId: result.firstId, secondId: result.secondId, score: result.score, season })).digest('hex');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const stored = this.db.prepare('SELECT * FROM online_test_rating_results WHERE match_id = ?').get(result.matchId) as { payload_digest: string; result_json: string } | undefined;
      if (stored) {
        if (stored.payload_digest !== digest) throw new Error('RESULT_CONFLICT');
        this.db.exec('COMMIT');
        return JSON.parse(stored.result_json) as EloChange;
      }
      const read = (userId: string) => (this.db.prepare('SELECT rating FROM online_test_ratings WHERE season = ? AND user_id = ?').get(season, userId) as { rating: number } | undefined)?.rating ?? 1500;
      const changed = calculateElo(read(result.firstId), read(result.secondId), result.score);
      const upsert = this.db.prepare('INSERT INTO online_test_ratings VALUES (?, ?, ?) ON CONFLICT (season, user_id) DO UPDATE SET rating = excluded.rating');
      upsert.run(season, result.firstId, changed.first);
      upsert.run(season, result.secondId, changed.second);
      this.db.prepare('INSERT INTO online_test_rating_results VALUES (?, ?, ?)').run(result.matchId, digest, JSON.stringify(changed));
      this.db.exec('COMMIT');
      return changed;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }
}
