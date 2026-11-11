/** Fixed-window limiter; bounded storage fails closed while all buckets are active. */
export class RateLimiter {
  private readonly buckets = new Map<string, { count: number; resetAt: number }>();
  constructor(private readonly now: () => number = Date.now, private readonly maxKeys = 10_000) {}

  consume(key: string, limit: number, windowMs: number): boolean {
    if (!Number.isSafeInteger(limit) || limit <= 0 || windowMs <= 0) return false;
    const now = this.now();
    let bucket = this.buckets.get(key);
    if (!bucket || now >= bucket.resetAt) {
      if (!bucket && this.buckets.size >= this.maxKeys) {
        for (const [existingKey, existing] of this.buckets) {
          if (now >= existing.resetAt) this.buckets.delete(existingKey);
        }
        if (this.buckets.size >= this.maxKeys) return false;
      }
      bucket = { count: 0, resetAt: now + windowMs };
      this.buckets.set(key, bucket);
    }
    bucket.count += 1;
    return bucket.count <= limit;
  }
}
