# Online duels: local alpha test

There is **no public ORAFOLD server**. The menu and lobby say “Online: lokaler Testserver / kein öffentlicher Server”. Offline AI play does not depend on this service.

## What runs

The default Node adapter calls the same Godot 4.6.3 `production_model.gd` used by the production AlphaSession. The 550-card catalog supplies four 30-card starters, custom-deck validation, and 30 starting life. TypeScript transports authenticated intentions; it contains no card or combat implementation. `SimulationAdapter` is available only when a test explicitly injects it.

`authority_model.gd` changes controller boundaries: both humans submit their own mulligan and origin; the second player can change one origin and exchange one card before confirming. Enemy draws, burns, card choices and turn endings receive no AI. The one core seam, `_automatic_draw_side`, defaults to the exact existing offline enemy behavior. Its separate comparison test compiles the original source and compares accepted boundaries, full snapshots, events and RNG with the new default.

Every accepted intention passes through AlphaSession's command audit. SQLite saves server seed, selected decks, accepted commands, event hashes, final state hash and RNG checkpoint. The headless worker reconstructs that journal for each command. A private Unix socket and Python's standard library keep a single Godot process warm; only immutable catalog/binding caches are retained between reconstructions. A server restart requires no in-memory match state.

Each participant receives their own hand and public board/counts. Neither player receives an enemy hand, either deck order, seed, RNG checkpoint, trigger caches or event snapshots. Opening choices remain hidden until their reveal boundary. Action broadcasts omit arguments. Full replay access requires a finished match and an authenticated participant.

## Start locally

Prerequisites: the complete repository, Node 24, Python 3, and the official Godot **4.6.3** binary on PATH. Godot rejects a different version or catalog size. Use the existing package lock; do not install a second copy of the dependencies in another worktree.

```sh
cd server
npm ci
HOST=127.0.0.1 PORT=8787 DB_PATH=var/orafold.sqlite npm start
```

`HOST`, `PORT`, `DB_PATH` and optional external `ORIGIN` are read in `server/src/main.ts`; defaults listen only on loopback. The database belongs in a writable local directory. `NODE_ENV=production` is deliberately rejected for this local alpha. No new cloud account, credential, paid host or deployment is needed for this test.

Open two native Godot clients, enter Online, apply `http://127.0.0.1:8787`, and register two distinct accounts. Select a starter in each client. Create a private invitation in one and paste its code into the other, or join the local matchmaking queue from both. Both click Ready, choose their opening, and play through actual five-path combat. The UI offers the authoritative kernel's legal card, draw, target, shift, resonance, relic, convergence and turn commands. Reconnect automatically resumes the participant's latest sequence; credentials are memory-only.

Stop the private worker after local tests:

```sh
python3 scripts/online/godot_bridge.py --project . --stop
```

## Browser origin and HTTPS/WSS

Browser authentication uses HttpOnly cookies, CSRF tokens and one-use WebSocket tickets. Browser API requests must share the game's origin. A hosted HTTPS game cannot connect to loopback HTTP/WS because of mixed-content and origin rules. Merely entering a public URL does not create a server.

For a local browser test, serve the exported game and reverse-proxy `/auth/`, `/profile`, `/catalog`, `/transport/`, `/matches/` and `/ws` from one origin to the loopback Node process; preserve WebSocket upgrade headers. Set the server's configured external origin and allowed host to that same origin. For access from another device, use a trusted HTTPS certificate and WSS on the same origin. Native clients accept HTTPS servers; insecure HTTP is restricted to the default loopback test addresses. Keep the backend bound to loopback behind the proxy.

Any public host would need the complete Godot project/catalog, pinned Godot binary, Python, Node, writable persistent SQLite storage, a TLS reverse proxy, backups, resource limits and operational monitoring. The historical transport-only Docker image does not supply that complete production worker. This integration does not publish or provision hosting.

## Verification and limits

Run `npm run typecheck`, `npm run schema`, and the server tests from `server/`. `tests/real-duel.test.ts` uses two authenticated WebSockets and real Production commands through a rules-determined win, then reconstructs the participant replay and compares its exact final hash. The fixture suites cover authentication, origin/CSRF/session limits, rate limits, social authorization, queueing and persistence separately.

Verified locally: **34 distinct server tests** across the focused runs, including the actual two-account full duel (141.94 s), security/protocol checks, and exact timeout replay reconstruction. No accepted action in the full-duel proof was `advance` or `concede`. The client protocol and responsive lobby tests also pass, including five visible paths at 390 px, 44 px controls, rotation preserving input/session state, and QA output excluding credentials. Geometry is exposed through `qa_controls()`; `qa_snapshot()` reports only connection and match status/counts.

Set `ORAFOLD_GODOT_DIAGNOSTICS` to a writable log path to retain worker stderr and non-protocol startup output for CI. The private bridge omits response payloads from that log. Stopping the bridge closes stdin and lets Godot exit cleanly before the log is checked. Presentation edits do not invalidate the running authority process; its cache identity covers only rule scripts and catalog inputs.

The offline seam proof passed **148 identical accepted boundaries across eight seeds**. `scripts/online/check_offline_draw_seam.gd` compiled the exact pre-hook Alpha source from commit `1151530^` alongside the changed default and compared snapshots, ordered events and RNG after every boundary. Original Alpha source SHA256: `fd1c2937f74bf587a4bcdf7a82e0da5990ad8dfadb7bf812b4ad0728b9fa6bd2`; changed source: `9e41cab7589c3a05ab1ede8375075018672142c9afdd90873a72efaaf0c5d089`.

The bridge serializes work and the synchronous Node adapter blocks its one event loop during reconstruction. This is a local alpha service, not a load-tested public deployment. First engine startup is slower than warm requests. SQLite and this adapter require a single application writer; multi-instance hosting needs explicit coordination. Password recovery has no public delivery integration. Accounts created here are local test accounts, separate from offline progression.
