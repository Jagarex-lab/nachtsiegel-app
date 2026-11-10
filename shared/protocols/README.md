# Online protocol source

Canonical validation: `server/src/transport/protocol.ts` (strict Zod schema).
Generated JSON Schema: `shared/schemas/client-message-v1.schema.json`.
Regenerate with `cd server && npm run schema`; drift is covered by protocol tests.
Godot optional client: `scripts/online/online_protocol.gd`.
Wire semantics, action/event cursors and HTTP contracts: `docs/online/PROTOCOL.md`.
This protocol implements simulation-only intentions, no ORAFOLD combat rules.
