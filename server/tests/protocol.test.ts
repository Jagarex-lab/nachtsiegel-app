import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { z } from 'zod';
import { messageSchema, parseMessage } from '../src/transport/protocol.js';

test('published protocol schema and fixtures stay in sync with strict transport validator', () => {
  const schema = JSON.parse(readFileSync(new URL('../../shared/schemas/client-message-v1.schema.json', import.meta.url), 'utf8'));
  assert.deepEqual(schema, z.toJSONSchema(messageSchema));
  const raw = readFileSync(new URL('../../shared/fixtures/simulated-action-v1.json', import.meta.url), 'utf8');
  const valid = parseMessage(raw);
  for (const field of ['damage','healing','energy','resonance','seed','winner_id','card_instance_id','target_lane']) {
    const altered = structuredClone(valid) as Record<string, unknown>;
    altered.action = { ...(altered.action as object), [field]: 999 };
    assert.throws(() => parseMessage(JSON.stringify(altered)));
  }
  assert.throws(() => parseMessage(JSON.stringify({ ...valid, action: { type:'play_card' } })));
  assert.throws(() => parseMessage(JSON.stringify({ ...valid, sequence:0 })));
  assert.throws(() => parseMessage(JSON.stringify({ ...valid, protocol_version:2 })));
  assert.throws(() => parseMessage(' '.repeat(8193)));
  assert.throws(() => parseMessage('{'));
});
