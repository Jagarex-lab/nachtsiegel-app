import { writeFileSync } from 'node:fs';
import { z } from 'zod';
import { messageSchema } from '../src/transport/protocol.js';
writeFileSync(new URL('../../shared/schemas/client-message-v1.schema.json', import.meta.url), `${JSON.stringify(z.toJSONSchema(messageSchema), null, 2)}\n`);
