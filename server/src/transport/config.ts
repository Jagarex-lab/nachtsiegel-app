import type { RuleAdapter } from '../matches/rule-adapter.js';
export interface AppOptions {
  dbPath?: string;
  host?: string;
  port?: number;
  origin?: string;
  sessionTtlMs?: number;
  /** Explicit fixtures only. The default always runs production Godot rules. */
  ruleAdapter?: RuleAdapter<any>;
}

export function localOnlyGuard() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Prototype only: production is disabled until engine integration and security review.');
  }
}
