# Online protocol source

Canonical validation: `server/src/transport/protocol.ts` (strict Zod schema).
Generated JSON Schema: `shared/schemas/client-message-v1.schema.json`.
Regenerate with `cd server && npm run schema`; drift is covered by protocol tests.
Godot optional client: `scripts/online/online_protocol.gd`.
Wire semantics, action/event cursors and HTTP contracts: `docs/online/PROTOCOL.md`.
The default server runs `GodotRuleAdapter`: each accepted intention executes the
same ORAFOLD550 production Godot kernel in a headless worker. `advance` belongs
only to explicitly injected transport test fixtures and is rejected by the
default server.

`catalog.get` (or HTTP `GET /catalog`) returns the real catalog and four starter
choices. Select a starter with `deck.select {selection:{starter_id}}`, or a
30-card catalog-validated test deck with `deck.select {selection:{cards:[...]}}`.
The server stores this choice and locks each match's initial loadouts.

After both participants send `match.ready`, send `match.action` with the next
per-player sequence and `{type:"command",name,args}`. The worker binds the actor
to the authenticated user. `legal_actions` in each personal snapshot supplies
valid command names and arguments for that user, including independent human
mulligan/origin and the second player's Second Possibility choices. Never send
an actor, damage, resource total, RNG seed or outcome as an intention.

Snapshots contain one's own hand and public opponent counts/board only. Public
events omit command arguments. Completed replays include the seed, locked
loadouts, accepted command journal and final state hash; their HTTP route checks
participant membership and terminal match status. Keep those replay files
private because they intentionally reveal the completed match's hidden choices.
