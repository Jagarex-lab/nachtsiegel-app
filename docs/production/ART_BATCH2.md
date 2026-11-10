# Individual illustration batch 2

Working branch `production/individual-art-batch2`, based on the tested production
foundation. Ten actual new originals increase visual production delivery from
five to **15 individual illustrations**. **535 individual illustrations are still
missing.** Derivative previews do not count as additional cards or originals.
All 15 have completed delegated visual review; commercial rights review remains
pending and `commercially_cleared=false` for every file.

| Stable card ID | Card | Type / species | Distinct motif |
| --- | --- | --- | --- |
| `of-houses-020` | Kupferspinne | Wesen · Mechanoide / Bestien | Copper-braced spider repairs a torn cloth binding on a workbench |
| `of-houses-094` | Restaurationslampe | Relikt | Porcelain/copper lamp illuminates three suspended pieces of a clay bird |
| `of-stillwatch-043` | Gepanzerter Keim | Wesen · Pflanzen / Konstrukte | Crystal seedling, protective leaves and mechanical hinges in a cold greenhouse |
| `of-stillwatch-055` | Wand aus Erinnerung | Wesen · Konstrukte / Geister | Glass slabs with spirit profiles protect a twig in a water cistern |
| `of-morph-003` | Zweithautechse | Wesen · Bestien / Morphiden | Four-legged lizard actively forms a gliding membrane while shedding its old skin |
| `of-morph-082` | Reißende Blüte | Impuls | An opening flower sends sharp petals across a hanging garden toward an empty practice frame |
| `of-ninth-019` | Taktfalter | Wesen · Bestien | Four-winged moth rests on a suspended droplet in an observatory |
| `of-ninth-095` | Verzögerungsspule | Relikt | Amethyst spool draws a silver filament through a displaced spatial fold |
| `of-neutral-049` | Wanderfeuer | Wesen · Elementare | Independent pale flame travels between firepans on a deserted marsh causeway |
| `of-neutral-083` | Gemeinsame Deckung | Impuls | Two travelers share steel cover while one tends the other's forearm |

These are actual cards already referenced by the production starter decks. No
new card IDs, values, abilities, rules, campaign events or canonical leaders are
introduced by the art batch. The original images contain no frames or card text.

## Provenance and quality

Every native source is 1448 × 1086 pixels. Full prompts, source filenames, actual
hashes, dimensions, alternative text and review notes are in
`data/production/art_sources.json`. Nine originals were generated without supplied
references. Zweithautechse received one documented Image Generation edit using
only its own first project-generated draft: ordinary shedding alone did not
communicate its equal Morphiden identity, so the revised shoulder/flank actively
forms an amber gliding membrane. The first draft's hash, filename and edit prompt
are retained in the provenance; the original input PNG is archived under
`art-evidence/source-references/` with `.gdignore`, so it is not another active
illustration or runtime resource. No third-party reference was supplied.

The production visual agent inspected each full generated image and each actual
756 × 1056 Godot card master for subject, anatomy, palette, safe crop, species and
visible artifacts. This is visual production approval under the user's delegated
order, not a legal opinion or claim of exclusive rights. A native render test
checks all ten real cards, distinct pixels, proper type slots, complete text,
invariant contour, approved final display state and information-free card backs:
90 assertions, zero failures. The final render explicitly rejects a leftover
concept badge on any of the ten approved illustrations.

The card-frame comparison is an actual Godot UI rendering, not an image-generation
mockup: [ten rendered masters](screenshots/art-batch2-masters.png).

## Runtime resources

All native original PNGs remain unchanged. The ten new full-card runtime imports
use Godot's lossy quality 0.90 at the original dimensions with generated mipmaps.
The first five originals keep their existing lossless import profile. A controlled
one-image import measurement used Zweithautechse's unedited initial draft:

| Measurement | Actual result |
| --- | --- |
| Native dimensions | 1448 × 1086, unchanged |
| Lossless mipmapped CTEX | 3,153,018 bytes |
| Quality 0.90 mipmapped CTEX | 758,262 bytes |
| Encoded size reduction | 75.95% |
| RGB PSNR against the source | 37.91 dB |

This is one measured image, not a claim that every image has the same size or
quality. Lossy imports are not pixel-identical to the originals. Native master
renders were inspected after import. The unmodified originals remain available
for later native export profiles and art review.

## Compact preview pipeline

`tools/production/prepare_art_previews.gd` generates **15 actual 512 × 384 preview
derivatives** from the 15 originals using Godot's Lanczos downsampling. It never
enlarges a source and never draws a frame or changes the creative composition.
`data/production/art_previews.json` binds every derivative to its original path,
source SHA-256, original dimensions, derivative hash, profile and exact dimensions.
The main art manifest validates both file sets. `--check` regenerates the pixel
result in memory and checks the committed bytes and native-size quality-90/mip
import settings. These 15 previews add zero originals to the illustration count.

```sh
godot --headless --path . --audio-driver Dummy --script tools/production/prepare_art_previews.gd
godot --headless --path . --audio-driver Dummy --script tools/production/prepare_art_previews.gd -- --check
python3 tools/production/art_manifest.py
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p production_art_manifest_test.py -v
godot --path . --audio-driver Dummy --script tests/production_art_batch2.gd
godot --path . --audio-driver Dummy --script tests/production_art_cache.gd
```

Visible compact cards retain their own resolved preview binding. Full cards retain
their native illustration binding. Unchanged redraws do not consult the resolver
or decode/resample source files. The shared LRU now allows 48 entries while still
enforcing its 32 MiB estimate; an explicit cache generation invalidates bindings
after a requested clear.

Actual test scene: 15 illustrated compact cards plus one full inspector, then 20
rendered redraws. All 38 assertions passed. Retained profiles: 15 compact / one
full. Loads remained 16, and no runtime thumbnail was generated after preparing
previews. Estimated retained texture storage was 24,115,456 bytes; the compatibility
renderer reported 43,085,385 texture bytes including fonts, atlas and other
resources. The estimate is not total browser memory.

The same software-rendered fixture's initial three-frame timing was 20.67 seconds
with on-demand full-source resampling and 2.95 seconds with prepared previews.
This motivated moving conditioning to build time. These are Linux llvmpipe fixture
measurements, include startup/render work, and are not physical iPhone timings,
touch-latency guarantees or a statistically controlled device benchmark.

## Remaining large-library work

The initial batch package below contains 15 full individual assets plus 15
compact previews. Its successor uses [on-demand full-art delivery](ART_DELIVERY.md):
the Web PCK contains prepared previews and the inspector fetches a verified
same-origin full WebP as needed. Native packs retain full textures. That separate
delivery stage adds no originals. A complete 550-image rollout and physical
Safari memory/network testing remain outstanding.

The first fresh worktree import timed out before a complete scan. Adding an
ignored `work/.gdignore` prevented development caches from becoming project
resources; a bounded verbose retry imported all 15 originals successfully. The
initial timeout is not counted as a passed test. A temporary one-image profile
attempt also lacked writable XDG directories; it was stopped and rerun with
explicit writable state before recording the successful measurement above.

## Exported package verification

The actual Web export of art head
`c8b2d1da07e825f59d9cc8dde6f3134161dad7b9` produced a 33,488,316-byte PCK.
`tools/test_production_art_package.sh PATH_TO_PCK` verifies it from an empty
temporary working directory with `--path` pointing to that same empty directory.
The probe script is supplied by absolute path, so it can only load game resources
from the mounted PCK. The checks also require `res://AGENTS.md`, tests, the
historical reference PNG and build-time conditioning code to be invisible.

All 97 assertions passed: fifteen 1448 × 1086 full textures and fifteen real
512 × 384 previews loaded, their actual pixel streams decoded, final display
states matched the inventory, no commercial clearance was implied, and no project
source was visible. `art-evidence/exported-package.json` records the exact package
hash, size, tested commit and probe context. This is a native load of the Web
artifact, not a browser/device test or a production deployment.

A first local export failed because a template symlink was nested one directory
too deep; correcting the version-directory link resolved it. A source-directory
PCK probe then correctly failed the exclusion check: Godot can fall back to
project files while running a pack from the project directory. That attempt is
not counted as package proof. The passing probe uses both an empty working
directory and an empty `--path`; this isolation is required when reusing the test.

The source-quality validator now requires at least native 1024 × 768 for a full
illustration. An eighth Python test replaces an original with its actual 512px
derivative and matching low-resolution hash/metadata, then requires rejection.
A compact derivative cannot acquire original status merely through declaration.
