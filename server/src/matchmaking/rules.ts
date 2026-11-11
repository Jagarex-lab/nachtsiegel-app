export interface QueueEntry { user_id: string; region: string; rating: number; joined_at: number }
/** Rating must be server-owned. The local fixture currently supplies fixed 1000. */
export function compatible(a: QueueEntry, b: QueueEntry, now: number): boolean {
  if (a.user_id === b.user_id || a.region !== b.region) return false;
  const waited = Math.max(0, now - Math.min(a.joined_at, b.joined_at));
  const window = Math.min(600, 100 + Math.floor(waited / 10_000) * 50);
  return Math.abs(a.rating - b.rating) <= window;
}
