# Mobile card inspection: Node and Python unit evidence

Date: 2026-11-19. UI source base: `e8c43ab570b63f2ca6acf56d523eeea6ea4064f5`; the five harness sources below were tested as working-tree changes before their own commit. No game rules or card data changed.

## Actual results

| Group | Passed | Failed / skipped | Scope |
| --- | ---: | --- | --- |
| Premium browser contracts, hosted pages, campaign header, public integrity, PWA and worker units | 74 | 0 / 0 | Node observations, geometry, cache and release contracts |
| Alpha data/texts, storage mirror, audio PCM/geometry, migration input units | 54 | 0 / 0 | Node data and isolated contracts |
| Legacy foundations, P01–P07 and match fixtures | 30 | 0 / 0 | Pinned JavaScript reference and golden-fixture regression |
| Card-system contract and species units | 29 | 0 / 0 | Data schema and actual asset-path safety |
| PWA staging | 3 | 0 / 0 | Python deterministic icons, manifest and worker staging |
| Release safety and candidate selection | 50 | 0 / 0 | Python protected release/artifact selection |
| **Total** | **240** | **0 / 0** | **187 Node + 53 Python units** |

These 240 units are **not browser gameplay tests, 550 played-card tests, Godot tests, or physical iPhone/Android acceptance**. Actual exported-game browser checks and screenshots run separately. No browser, GPU renderer or deployment was started by this unit-test batch.

## Reproducible commands

Run from the full exact checkout, with `TMPDIR=/tmp`. This host used `NODE_PATH=/workspace/nachtsiegel-app/work/qa-browser-current/node_modules`; the unit groups do not launch a browser.

```sh
node --test tests/premium/browser_contract.test.cjs tests/premium/campaign_header_contract.test.cjs tests/premium/hosted_contract.test.cjs tests/release/public_integrity.test.cjs tools/premium/test_pwa.cjs tools/premium/test_worker.cjs
node --test tests/alpha_data.test.cjs tests/alpha_card_texts.test.cjs tests/production_storage_mirror.test.cjs tests/audio/pcm_readiness.test.cjs tests/audio/product_geometry.test.cjs tests/production/migration_input_contract.test.cjs
node --test tests/legacy_foundations.test.cjs tests/legacy_engine.test.cjs tests/legacy_matches.test.cjs tests/legacy_p05_p06.test.cjs tests/legacy_p07.test.cjs
node --test tests/card_system/alpha_species.test.cjs tests/card_system/contract.test.cjs
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/premium -p test_stage_pwa.py -v
PYTHONDONTWRITEBYTECODE=1 python3 -Werror::ResourceWarning -m unittest discover -s tests/release -v
```

All five changed CJS sources also passed `node --check`; `git diff --check` passed. The existing mandatory syntax gate in `tools/test_premium.sh` now includes the new helper. Both browser workflows check out the repository and execute the harnesses from that checkout, so their relative helper imports are available without adding code to the exported PCK.

## Host constraints and failed setup attempts

The shared source worktree is sparse and the filesystem is almost full. A small exact-source test mirror under `/tmp/orafold-inspector-unit-snapshot` occupied 832 KiB, without copying illustrations or legacy goldens. Unchanged linked trees were checked against their Git tree IDs; Node used `--preserve-symlinks --preserve-symlinks-main` so modules resolved against the mirror.

The first expanded unit attempt failed on missing mirror files and correctly rejected a symlinked asset root. Missing exact sources were supplied. The card-system tests were rerun in the existing full source directory with an actual asset root, after verifying the SHA-1 Git blob identity of all 17 relevant source/test/catalog/atlas files against the current head. All final groups above passed. No asset-path protection, assertion or test was disabled or weakened. Initial setup failures do not count as passes.

Small final host logs: `/tmp/orafold-inspector-node.log`, `/tmp/orafold-inspector-data-final.log`, `/tmp/orafold-inspector-legacy-final.log`, `/tmp/orafold-inspector-card-system.log`, `/tmp/orafold-inspector-pwa.log`, `/tmp/orafold-inspector-release.log`. They are local execution evidence, not uploaded release evidence.

## Harness source fingerprints

| Source | SHA-256 |
| --- | --- |
| `tools/alpha_browser_qa.cjs` | `f8821b79580771c19f0a21e07cbc6b4c988fece387f15211ae2a482f43fa1ebb` |
| `tools/alpha02_browser_qa.cjs` | `d84690cb9cbf47161e6b86011a94bd926768f7ad4220a43ba3c31d40324ecf4c` |
| `tools/master550_browser_qa.cjs` | `e18cf489700118ab1233754dda6fb61421a8ce2dbd60cff0c184ac76cdf59d5b` |
| `tools/premium/browser_qa.cjs` | `6cd0f688f463c88ddb310621a34f903795b6ac5b055159c9d99ffc5ec7c4b01a` |
| `tools/premium/card_inspection_contract.cjs` | `6f009197ebb14f22376eeb570702c281cb6491a9c5519e253a2e34071a5c5483` |

## Behavior asserted by the updated browser harnesses

A first actual hand tap opens the same card without changing selection, marks, commands, deck or complete battle state. An explicit inspector action arms it; the existing target or exchange/burn confirmation still performs the original game action. The legacy-only archive retains its original input contract.

The inspector checks use actual painted-card/control reports: original ID/name/rules, 63:88 contour inside the viewport, internal rules viewport, at least 13 CSS-pixel rules, and visible 44 CSS-pixel close action. Additional exported-game tests cover open-inspector rotation, optional separate keyword help, consumed outside close, longest printed rules scrolling, Mulligan/second-chance selection, overflow burn selection and existing canceled drag/target inputs. These tests are implemented here; their browser results must be recorded only after running the actual export.

## Actual first Chromium export attempt and harness correction

The first real Chromium premium-browser attempt stopped after 82 checks, eight screenshots and one landscape viewport. This is a failed attempt, not a completed browser acceptance. Root inspected its actual failure report: `inspect_keywords.disabled` was `false`, and `inspection.help_visible` was already `true`. The help opened correctly; the harness incorrectly waited only for a full UI-render or top-level modal-version change. A nested help panel deliberately changes neither.

The action waiter now additionally observes the actual `help_visible` transition **only** for `inspect_keywords` and `inspect_help_close`. All existing version waits, deadlines, input, clipping and negative assertions remain. No product patch or disabled-button assumption was introduced to make the harness pass.

The optional-help regression now searches the real `oa-neutral-c04` Feldärztin through collection input and opens its real card. It requires the existing Heile keyword, an enabled help control, visible `Heilung:` definition, absence of a false `Eile:` definition, unchanged original card and game/deck data, and actual help-close behavior. The random first hand card is no longer assumed to need glossary help. Rotation and consumed outside-close assertions on that hand card remain. This correction requires a new actual export-browser run; no successful browser result is claimed here.
