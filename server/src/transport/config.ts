export interface AppOptions {
  dbPath?: string;
  host?: string;
  port?: number;
  origin?: string;
  sessionTtlMs?: number;
}

export function localOnlyGuard() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Prototype only: production is disabled until engine integration and security review.');
  }
}
