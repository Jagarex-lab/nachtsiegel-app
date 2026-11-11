# Alpha 0.3 integrated verification

This report distinguishes executed evidence from remaining acceptance work. The starting develop commit is `345edb6e683d4359b8141ef228683c0855773ac2`. PR27 contains new source: none of the old345 QA run IDs can authorize its release.

## Implementation and independently executed checks

| Area | Implemented and observed evidence | Limits |
|---|---|---|
| Cards/art | Active550,110peraffiliation; original card-data SHA256161384024ba4ba4ad78994adfb203eaa49c6fd222916285e6d9338f5f19f53b7 unchanged. Real550illustration manifest check passes, no missing/orphan originals. | Commercial clearance remains0/550; provenance and visual review do not provide legal clearance. |
| Orientation | Validated CSSviewport snapshot rather than delayed backing-buffer or screen.orientation alone; bounded settling, visualViewport, keyboard, zoom, safe-area fallback. Chromium/WebKit each18 bridge fault checks; actualGodot95 full-model/RNG/selection retention assertions. | Browser emulation; no physical iPhone/Android attached. In-progress AI duels are not restored by browser reload; rotation preserves them. |
| Application | Seven real menu entries, persistent hosted panels across resize;35 application assertions after lifecycle and menu-music fix. | Online requires a separate test server; Pages alone supplies no backend. |
| Economy | Actual550collection; four free protected starters, saved-deck migration, rewards, gold packs, duplicates, crafting, quests, XP/levels.1,296 original integration assertions,40 Python tests, actual browser storage expressions.102additional assertions across four complete starter AI duels and four exact replays verify durable/idempotent match rewards. | Local untrusted test saves. Alpha deckbuilding keeps all550 freely playable; collectible ownership is advisory and never a combat input. No purchases. |
| Campaign | Existing provisional two chapters use production550 Session, decisions, safe battle return, checkpoints/retry, repeat isolation, durable reward outbox and shared GameAudio.3,964 assertions, including301 battle checks. | Story remains a proposal. Interrupted battles restart from their encounter checkpoint. |
| Online | Authentication, matchmaking, private invites, server-valid decks/turns, two-human opening, secrecy, reconnect/restart and ended participant replay through the same Godot production kernel.34 server tests, actual full two-account WebSocket duel through a combat winner, exact replay;26 client assertions and responsive UI fixture. | No public server deployed. Native/local server and reverse-proxy hosting steps are documented. |
| Offline compatibility | Approved opt-out controller seam verified148 identical accepted boundaries across8seeds: full state, ordered events and RNG. Frozen source guards retain original anchors and accept only the exact reversible seam;7 negative/positive tests. | Final full differential/matrix checks must also pass on the exact integrated commit. |
| Balance | Fresh paired56matches plus4exact repeats:314 assertions,0errors/censoring;7 evidence-integrity tests. Ninth starter13/24, time deck18/32; first player37/56, convergence5/56. No card/rule nerf inferred from old24/24 pilot. | Small AI sample and policy dependence. Start-player advantage remains a concern;550-card competitive balance is not established. |

## Actual Web bugs found and corrected

1. **Web write result type:** JavaScriptBridge returns numeric boolean values. Comparing an integer directly to a Godot bool raised a runtime error during starter grant. A strict decoder accepts onlytrue/1 and rejects all other values.
2. **Second-write CAS failure:** parsed JSON integers reserialize as1.0 in Godot while JavaScript emits1. Both CAS operands are parsed and serialized by the same JavaScript normalization; stale writers are still rejected.
3. **Synchronous feature exit:** detaching a campaign/online Control inside Button.pressed caused two actual can_process warnings. Hide and queue_free retain the sender until event dispatch completes.
4. **Menu music:** campaign owns music outside the main shell's cached context. Exiting a hosted feature now invalidates that cache and restores the actual menu music; the new regression failed before and passes afterward.
5. **CI browser installation path:** changing XDG_CACHE_HOME after Playwright installation caused the integration job to look in an uninstalled directory. The reusable job now pins one explicit browser path for installation and execution.

The exact local export314d3471450aff56273e04041c1e533c44ae2b82 passes both actual economy browser tests (Chromium46.9s/WebKit71.7s): real onboarding, quota-denied UI write preserving wallet/receipts, successful100gold purchase, five-card opening and exact reload equality. Its full navigation test then exposed issue3; those logs are retained as failed evidence, not a passing full test. The follow-up local exportde4595041f240a1a2638420043d2047fd867afaa includes issues3/4 fixes. A repeat economy Chromium run reached its180s outer deadline; WebKit passed99.8s. A targeted Chromium retry with the same180s deadline and all assertions unchanged passed70.2s. The earlier failed run remains retained. The original integrated navigation harness then passed56/56 checks in each browser with zero errors on exact local exportde4595041f240a1a2638420043d2047fd867afaa, including three rotations preserving complete model/command state and a landscape reload/new opening.

## Visual evidence

`tools/alpha03/render_card_qa.gd` renders20 actual canonical Godot card faces (five affiliations × four rarities), including creatures, impulses and relics; all titles/rules fit and every illustration must resolve to actual art. The local run produced five1280×720 sheets, visually reviewed for consistent diagonal contour, faction colors, rarity structure and readable values. Main CI repeats this exact rendering and binds its manifest to the executed commit, catalog, card-face script and art-manifest hashes. Screenshots are retained in `work/alpha03/visual-qa/` within the tested artifact. The separate two-engine integrated browser suite supplies14 portrait/landscape menu and opening screenshots; transient image-loading frames are not treated as final-illustration approval.

## CI and release rules

Required Main CI now includes economy/campaign/actual-online/application checks as well as the existing Legacy, Alpha, production, simulation, native-platform, audio and two-engine browser gates. Runtime errors, resource leaks, missing summaries, skipped Node tests and source mismatches remain failures. No checks are disabled to obtain green CI.

A campaign CI run reported one resource still in use after301 successful assertions. Local repeated verbose runs did not reproduce or identify its type. Campaign fixtures now use the existing product GameAudio.request_quit teardown, which stops streams and allows the mixer to drain, instead of abruptly bypassing that shutdown. All301 checks and the strict leak gate remain. The patched301 suite passes locally with zero errors/leaks; fresh CI subsequently identified the same abrupt-shutdown pattern in the layout fixture, so the remaining campaign fixtures use the same product shutdown.

A local Python orchestration test timed out at its existing10s subprocess limit during concurrent work. The unchanged affected10-test suite subsequently passed in5.631s; the first failed run is retained. Fresh required CI is the final aggregate verdict.

Only a completely green exact-commit PR can be integrated. The resulting exact develop SHA requires fresh full Main CI and a new unexpired artifact before the existing manual Pages workflow. No stale qa_run_id is reusable. The connected GitHub tool currently has no workflow-dispatch action; if still unavailable, publication needs the owner's manual workflow invocation with exact `commit`, `qa_run_id` and `confirmation=PUBLISH <commit>` fields.

## Remaining acceptance

- Final exact-commit Main and standalone checks, plus the resulting develop-commit repeat.
- Strict final integrated Chromium/WebKit navigation, rotation, reload and full-AI-game checks, with screenshots retained in the CI artifacts.
- Public Pages deployment and subsequent actual public browser verification.
- Physical iPhone/Android acceptance, broader practical balance playtesting, and commercial asset clearance.
