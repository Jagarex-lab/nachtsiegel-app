# Alpha 0.3 integration audit and execution plan

Starting point: develop `345edb6e683d4359b8141ef228683c0855773ac2`.
These are new changes and require fresh QA; the historical QA run for 345edb6 cannot release this integration.

## Verified repository evidence

- PRs 19–25 are already in develop: 550 active production cards and 550 individual source illustrations. Alpha55 and Legacy100 are historical regression catalogs, not additional active collection cards.
- PR11's opt-in trigger bridge has already been superseded by production trigger work; merging the old branch again is unnecessary. PR14 audio was selectively integrated in PR24. PR15 proposals were superseded by the production catalog/art pipeline. None is blindly merged over newer code.
- PR16 provides local economy primitives, but originally had no connection to the active550 menu, match outcomes, or real collection. PR18 supplies a provisional two-chapter campaign, originally disconnected and using the old Alpha55 battle adapter. PR17 supplies authentication, matchmaking and transport, but its advance/concede simulation was not a real ORAFOLD duel.
- PR26 is an open draft containing two historical release-evidence documents. Its head is 56a11cfc047d6a44c4cea66a38fc991350d5bcd2. Its old345 release instructions are not adopted as approval for newly changed code.
- Original PR16/18/17 branches were merged only on the new integration feature branch, in that order. Develop and Pages were unchanged at audit time.

## Execution packages

1. Fix the Safari CSS-viewport/canvas orientation mismatch, including delayed resize, keyboard/zoom, short landscape, safe-area and repeated rotation regressions.
2. Connect local collection/economy to actual550 cards and idempotent duel/campaign receipts; preserve four free starter decks and existing saved decks. Alpha test deckbuilding remains unrestricted; collectible ownership is separate and never a combat input.
3. Connect the provisional campaign to the production550 kernel, shared session, checkpoint save/retry, audio and durable reward outbox.
4. Replace simulation-only online combat with an authoritative process running the same Godot production kernel; test two real clients, secrecy, illegal actions, reconnect and replay. No paid or public hosting is implied.
5. Compose the main menu and persistent hosted panels; preserve their state across layout changes. Add all new suites to the release-gating CI.
6. Reproduce balance evidence with paired starts and fresh seeds before deciding changes; do not treat old24/24 Ninth Hour pilot results as current evidence.
7. Run combined Godot/Node/Python/browser/security/export tests on the actual integration commit, open a PR, and integrate only green reviewed results. Re-run all required checks on the exact resulting develop SHA before manual release.

## Explicit limits at audit time

No physical iPhone or Android device is attached. WebKit/Chromium automation is browser simulation, not device acceptance. GitHub Pages cannot host the authoritative multiplayer process. Local balances are untrusted test saves, not accounts suitable for purchases. Commercial clearance of generated illustrations remains a separate legal/provenance task.
