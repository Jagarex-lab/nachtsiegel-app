import type { DatabaseSync } from 'node:sqlite';

export interface PublicProfile {
  playerId: string;
  displayName: string;
  avatar: string;
  language: string;
  level: number;
  createdAt: number;
}

/** Deliberate allowlist: never serialize a joined users/session row. */
export function readPublicProfile(db: DatabaseSync, userId: string): PublicProfile | null {
  const row = db.prepare('SELECT user_id, display_name, avatar, language, level, created_at FROM profiles WHERE user_id = ?').get(userId);
  if (!row) return null;
  return {
    playerId: row.user_id as string,
    displayName: row.display_name as string,
    avatar: row.avatar as string,
    language: row.language as string,
    level: row.level as number,
    createdAt: row.created_at as number,
  };
}
