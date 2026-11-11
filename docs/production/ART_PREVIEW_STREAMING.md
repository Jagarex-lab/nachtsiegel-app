# Visible compact illustration delivery

Implemented as a separate fifth stage after the fifteen-image full-art delivery
in [ART_DELIVERY.md](ART_DELIVERY.md). This stage adds **zero illustrations**.
The current branch has 15 visually approved originals and 535 missing originals;
commercial clearance remains explicitly open. Counts change only when real
originals and provenance are separately imported and validated.

The Web PCK contains five pinned 512-edge previews: the four powers' first
starter creatures and Torwache. Other compact previews are quality-0.90 WebPs beside
`index.html`, addressed by SHA-256. Full original-resolution WebPs remain
separate. Native packages retain every imported preview and full texture.
Original PNGs, their dimensions, source hashes and quality-90 native imports are
unchanged. Frames, values and text are never baked into the illustrations.

## Data and packaging

`art_delivery_config.json` selects the five pilots. The versioned, data-only
`art_preview_delivery.json` binds each compact file to its original and prepared
PNG hashes, exact dimensions and encoded length. It contains no executable card
or effect definitions. The export plugin skips other preview imports only for
Web; its own editor scripts are excluded from every runtime package.

The build verifies both derivative caches before export. Before its atomic swap
it validates the actual PCK from an empty working directory and project path:
five compact textures, zero original textures, no editor plugin/build tools or
checkout fallback. A failed preparation, export, PCK check or rename preserves
the complete previous candidate. Staging and ZIP packaging validate both complete
`art/full/` and `art/preview/` trees, content hashes and relative paths. Unknown
files, symlinks, traversal and metadata/body mismatches fail.

## Visible owners, priorities and cancellation

Compact requests require a live Control intersecting its viewport and every
clipping ancestor. `is_visible_in_tree()` alone is insufficient for a scrolled
card. Leaving a page, scrolling out, hiding/deleting a Control or changing its
card releases ownership. With no remaining owner the in-flight fetch is aborted
and pending work is removed. Returning to the card requests it again.

One HTTP request runs at a time. At most 24 compact and four full requests wait.
An inspector preempts a compact request and goes first; still-visible interrupted
previews resume afterward. Compact responses are capped at 1 MiB and full
responses at 8 MiB, with a ten-second timeout and thirty-second failure cooldown.
Before decoding/retaining a texture, status, exact length, SHA-256 and geometry
must match the manifest. Missing art is visibly unavailable; an unsuccessful
fetch is never described as a loaded original.

The scoped Web fetch guard enforces same-origin URLs and refuses redirects,
tracks AbortControllers and restores the original fetch after its last owner
exits. Unrelated engine/network fetch options remain unchanged. The shared LRU
retains at most 48 textures and an estimated 32 MiB including mipmaps. Full art
can evict a compact cache entry even when its Control still holds that texture.
Visible Control references, browser response/decode buffers and GPU resources are
outside this cache estimate: **it is not a total-memory or peak-response guarantee**.
No persistent image cache or 550-card background prefetch is added.

## Actual local evidence before committed rebuild

These working-tree proofs used Godot 4.6.3 and actual source/derivative bytes.
They are not a publication, final integrated build or physical phone test.

| Gate | Result |
| --- | --- |
| Compact HTTP | 51 assertions, zero failures: real WebP, 404, wrong SHA/geometry, refused redirect, oversized body, actual cancellation, priority/resumption, scroll clipping and 24-visible-preview cache boundary |
| Existing full HTTP | 74 assertions, zero failures; retained complete full-art/cooldown/queue regressions |
| JS guard + atomic build | 12 Node tests passed; explicitly simulated exporter fixtures are filesystem/rollback tests, not game executions |
| Staging/ZIP + original/preview provenance | 23 Python tests passed, including both delivery groups and metadata/body/symlink failures |
| Isolated Web PCK | 133 assertions, zero failures; zero full and five compact textures, no editor/source fallback |
| Isolated native PCK | 163 assertions, zero failures; fifteen full and fifteen compact textures |
| Native rendered pipeline/cache/master | 169 / 38 / 90 assertions respectively, zero failures |
| Actual odd-aspect original | Unverrückbarer Gast at 1491×1055 produced 512×362 through the unchanged production preview generator; generate/check each passed 12 assertions; original SHA unchanged |

The real odd-aspect proof uses an isolated image-conditioning project. Only its
quit lifecycle is a fixture; the native generated PNG and production generator
are actual. No illustration is resized to a prescribed 4:3 aspect.

Browser success/failure/cancellation and the exact committed package must still
be checked after committing this stage. The previous full-only browser proof
remains historical and does not count as a compact-streaming success. Reproduce:

```sh
node --test tests/production_art_transport.test.cjs tests/build_alpha_staging.test.cjs
python3 -m unittest discover -s tests -p 'production_art_*_test.py' -v
bash tools/test_production_art_preview_delivery.sh
bash tools/test_production_art_delivery.sh
bash tools/build_alpha.sh
bash tools/test_production_art_package.sh work/alpha/web/orafold-COMMIT.pck web
python3 tools/package_alpha.py
node tools/production/browser_art_delivery_qa.cjs
```

## Corrected codec review and measured decision

The initial working-tree generator called `save_webp_to_buffer(true, 0.9)`
while incorrectly labelling its compact output lossless. Godot's first argument
is **lossy**; the actual RIFF chunk was `VP8 `. Those earlier 656,692 bytes were
quality-0.90 compact WebPs. The metadata/schema now explicitly declare
`external_lossless:false` and `quality:0.9`.

A real same-image comparison encoded the ten current external previews losslessly
using `false`, verified the `VP8L` envelope and compared every decoded RGBA byte
against its prepared PNG. The actual generation run completed with 93 assertions, zero
failures. Lossless bodies totalled **2,750,150 bytes**, versus **656,692 bytes**
for the same ten quality-0.90 bodies: **4.19×** mobile transfer size. This sample
is not a measured 550-card transfer. On the production lead's explicit decision,
compact delivery retains quality0.90, matching the existing native preview
import standard. Correcting prose does not justify quadrupling mobile bandwidth.
The experiment and original hashes remain in the test evidence; no source PNG
pixels changed. Full delivery also retains its recorded quality0.90 encoding
and actual original dimensions.

The original HTTP and package checks proved bytes, geometry and transport
behavior. They did not prove lossless pixels and are not reported as such.
