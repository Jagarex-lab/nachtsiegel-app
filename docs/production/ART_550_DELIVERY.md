# 550 individual illustrations: delivery and test evidence

This is the source-bound historical e6 delivery report. Later battle-lifecycle,
scoped cancellation and packaging corrections are recorded in
[ART_BATTLE_VISIBILITY.md](ART_BATTLE_VISIBILITY.md),
[WEB_RUNTIME_PACKAGE.md](WEB_RUNTIME_PACKAGE.md) and the
[production readiness report](PRODUCTION_READINESS.md). Counts below are not
silently relabelled a final integrated CI or public deployment.

Implemented and pushed in [PR #23](https://github.com/Jagarex-lab/nachtsiegel-app/pull/23),
stacked on PR #19. Actual tested Web artifact:
`e6ba7592594f119f54736ebb81fb0e31e8abb587`, branch
`production/individual-art-batch2`, based on Core `53ad3d2`.
This report does not claim integration into develop or publication.

## Actual inventory and review

550 native original PNGs, 550 proportional 512-edge previews, exactly 110 originals
per power and neutral, zero missing/orphan images. The original PNGs total
1,540,667,127 bytes and remain unchanged. Their complete source metadata is
SHA-256 `6eafb4bdf0852dd0ecc0e3f7211e915e718955607e31babab54e3d52c891f6ef`.
The 100 Legacy cards and original Alpha rules profile remain separate.

The importer verified every actual PNG, ID, name, power, native dimensions,
CRC/decoded stream, original hash and review flags before creating 535 additional
hardlinks. Existing 15 originals were retained. No atlas enlargement, invented
image file or unrecorded status promotion supplies the count.

Artists inspected their actual native outputs. A separate contact pass viewed all
550 thumbnails and opened 22 targeted originals; that reviewer overlapped 106
first reviews. Root separately inspected 275 thumbnails. Related book/lens/plant
motifs and review limits remain in [CONTACT_REVIEW.md](CONTACT_REVIEW.md).
None of this constitutes a second full-native review of every pixel or legal
clearance. All 550 commercial flags remain false. Every local scene remains a
lore proposal, not a new canonical historical event or Eira revelation.

Five independently inventoried image commits keep the Git payload manageable:

| Power | Commit | Actual originals/previews present after commit |
| --- | --- | ---: |
| Zwölf Häuser | `a399820` | 122 / 122 |
| Stillwacht | `f62f1e8` | 229 / 229 |
| Vielgestalt | `6b41daa` | 336 / 336 |
| Neunte Stunde | `efea1f7` | 443 / 443 |
| Neutral | `e6ba759` | 550 / 550 |

Each adds 107 originals plus derivatives to the already present 15. The actual
committed PNG identity sets, source entries and all five manifests were checked
for exact agreement; these counts do not depend on untracked local files.

## Exact Web artifact and actual transport checks

The committed build has a **19,706,340-byte PCK** and **35,754,592-byte wasm**.
The isolated PCK test passed **3,878 assertions, zero failures**, with no project
checkout fallback: zero full textures, exactly five pinned previews, declared 550
sources, no editor plugin/build/test files. The actual separate native export also passed **5,513 assertions, zero failures**
from an isolated working directory/project path: all550 full textures and550
prepared previews loaded and decoded, with no source/editor/test fallback. The
`Linux Runtime QA` PCK is **400381108 bytes**, SHA-256 `53bda9326048c4038294636a9fd30c4b4f6d3308e5fb8f558af526d38883924d`.
This pack-only export required no template configuration change. The generated
large PCK was removed after its byte/hash receipt to preserve integration space;
its source/assets and full proof log remain. Final integrated CI is separate.

The export tree contains **550 full WebPs, 216,916,238 bytes**, and **545 compact
WebPs, 38,255,648 bytes**. These content-addressed files are not all fetched at
startup. Their summed disk size is not a measured initial network transfer or
phone memory consumption. Full images retain original dimensions at quality 0.90;
compact images retain proportional 512-edge dimensions at quality 0.90.

Ten actual Chromium/WebKit contexts passed **284 assertions, zero failures** on
this exact exported commit. Both engines performed visible touch/search input and
actual same-origin requests under the deployed-style URL subdirectory:

- successful compact and full response with exact body hash/byte length/geometry;
- genuine 404 and same-length corrupted full body, retaining the honest preview;
- genuine 302 redirect refused before its target is requested;
- actual response over 8 MiB rejected without being reported as full art;
- real pending compact request cancelled by leaving the collection, then resumed
  and visibly completed after returning to that card;
- repeated redraws do not fetch another full image; deck state remains unchanged;
- no unhandled promises or unexpected script errors. WebKit's exact browser-native
  forced-redirect notification is retained and narrowly classified by URL/empty
  stack; it is not hidden with a broad exception filter.

[Verified full view](screenshots/art-delivery-full.png) and
[offline preview](screenshots/art-delivery-offline.png) are actual native 1280×900
browser screenshots. Their complete results, browser versions, source hashes,
PCK/wasm hashes and exact limits are in
[final550-delivery-results.json](art-evidence/final550-delivery-results.json).
These are simulated browsers, not physical iPhone or Android tests.

## Other actually executed checks and bounds

The complete local source/derivative stage passed 4,953 preview-generator,
3,302 full-WebP and 3,828 compact-WebP assertions. The actual native renderer
pipeline loaded/decoded all 550 originals and passed 4,984 assertions. A 24-card
page plus a full inspector passed 81 checks; ten original master-card renders
passed 90. The LRU may evict a thumbnail cache entry while its visible Control
retains that texture; the 32 MiB estimate is a shared-cache bound, not total GPU,
browser, visible-reference or peak response memory.

A real same-ten-image codec comparison passed 40 assertions: Q90 uses 656,692 bytes,
lossless 2,750,150 bytes, 4.19×. Decoded lossless RGBA was checked byte-for-byte.
The production lead retained Q90 rather than increasing mobile bandwidth merely
to match previously incorrect prose. Actual metadata now explicitly says
`external_lossless:false` and `quality:0.9`. Source PNGs never changed.

The generation/renderer counts above are local working-tree component proofs
before the final Core rebase and are not silently relabelled final integrated CI.
The browser/PCK counts are bound specifically to e6ba759. Complete Legacy/Alpha/
Production/Native/Browser/ZIP gates on the actual final integration SHA remain
required. The CI workflow includes separate native-art PCK and both-engine
transport jobs; it cannot deploy this branch.

## Reproduction and safe integration

```sh
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p 'production_art_*_test.py' -v
bash tools/test_production_art.sh
bash tools/build_alpha.sh
node tools/production/browser_art_delivery_qa.cjs
```

For GUI scripts use an actual display/Xvfb; use writable XDG directories in a
restricted environment. The built directory is `work/alpha/web`. Localhost is a
secure-context browser test origin; physical iPhones need trusted HTTPS, not
`file://` or a plain LAN-IP HTTP page. Existing HTTPS serving instructions apply.

Retarget PR23 after PR19 is integrated; do not merge its Core ancestors twice.
Keep final integration in the existing artwork worktree to avoid duplicating
1.54GB of source PNGs. No direct develop push, protection change or Pages release
is performed by this art PR. A manual release still requires the final tested
commit and the existing release guard, followed by actual public browser proof.
