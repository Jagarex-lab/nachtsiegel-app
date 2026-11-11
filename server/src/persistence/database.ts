import { DatabaseSync } from 'node:sqlite';
import { chmodSync, readFileSync } from 'node:fs';

/** One local process owns this SQLite database; PostgreSQL is a later migration. */
export function openDatabase(path: string): DatabaseSync {
  const db = new DatabaseSync(path);
  // Protect password hashes and session digests, including SQLite sidecar files.
  if (path !== ':memory:') chmodSync(path, 0o600);
  db.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  const migration = readFileSync(new URL('../../migrations/001_initial.sql', import.meta.url), 'utf8');
  db.exec('BEGIN IMMEDIATE');
  try {
    db.exec(migration);
    db.prepare('INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (1, ?)').run(Date.now());
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    db.close();
    throw error;
  }
  return db;
}
