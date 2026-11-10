import { z } from 'zod';

export const MAX_MESSAGE_BYTES = 8192;
const id = z.string().min(1).max(80).regex(/^[A-Za-z0-9_-]+$/);
const base = { protocol_version: z.literal(1), request_id: id };
const match = { match_id: id };
const message = <T extends z.ZodRawShape>(type: string, shape: T) =>
  z.object({ ...base, type: z.literal(type), ...shape }).strict();
export const messageSchema = z.union([
  message('session.resume', {}),
  message('matchmaking.join', { mode: z.literal('casual'), region: z.enum(['local', 'eu', 'na', 'asia']) }),
  message('matchmaking.leave', {}),
  message('private.create', {}),
  message('private.join', { invite_code: z.string().min(6).max(80).regex(/^[A-Za-z0-9_-]+$/) }),
  message('match.ready', match),
  message('match.action', { ...match, sequence: z.number().int().min(1).max(Number.MAX_SAFE_INTEGER), action: z.object({ type: z.enum(['advance', 'concede']) }).strict() }),
  message('match.reconnect', { ...match, after_sequence: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER) }),
  message('social.list', {}),
  ...['social.request', 'social.accept', 'social.remove', 'social.block'].map(type => message(type, { target_user_id: id })),
]);

export function parseMessage(raw: string) {
  if (Buffer.byteLength(raw) > MAX_MESSAGE_BYTES) throw new Error('MESSAGE_TOO_LARGE');
  return messageSchema.parse(JSON.parse(raw));
}
