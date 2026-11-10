# On-demand full illustration delivery

The Web candidate packages the 15 prepared 512 × 384 previews in its initial PCK.
Its 15 full illustrations are separate, content-addressed WebP files requested
when an inspector needs them. Native exports retain their full imported textures.
This change adds no new illustrations: 15 individual originals exist and 535
remain missing in this branch. Every commercial-clearance flag remains false.

## Build and asset identity

`tools/production/prepare_art_delivery.gd` decodes each actual immutable original
PNG and encodes a lossless WebP at its original 1448 × 1086 dimensions. It never
upscales or edits source pixels. The committed `data/production/art_delivery.json`
records the original SHA-256, encoded SHA-256, exact byte length and dimensions.
The source cache is ignored build output, not another source/provenance record.
`--check` regenerates all 15 derivatives and verifies the committed metadata;
`--ensure-cache` reconstructs missing encoded files and rejects stale metadata.

`tools/build_alpha.sh` exports into its existing temporary staging directory,
ensures the encoded cache and stages `art/full/<sha256>.webp` plus a copy of the
delivery manifest beside `index.html`. Staging uses hardlinks on the same
filesystem, with a copy fallback across filesystems. The original PNGs remain
unchanged. A failed export/preparation/pack check preserves the previous complete
candidate. Web export presets exclude full original textures; Linux/Android
presets retain them. The canonical Alpha candidate stages external art; separate
archive/legacy QA exports must stage those files explicitly to provide full art.

`tools/package_alpha.py` includes the complete validated external-art set in the
ZIP using relative paths, records each body's hash in `artifact-manifest.json`
and checks the ZIP entries and bytes after creation. Unknown art, traversal,
symlinks and changed body hashes cause packaging to fail. The existing manual
Pages workflow uploads the tested export tree recursively; publication still
uses its protected environment and explicit release approval.

## Runtime behavior

`ArtDelivery` derives the asset directory from `window.location.href`, preserving
the deployed site subdirectory and the document origin. A base tag cannot move
the requests to a different server. HTTPS and loopback HTTP are accepted. Normal
native startup does not create an HTTP request node.

Compact library/hand/board cards use prepared previews without starting full-art
requests. An inspector immediately shows the same preview with a loading label.
One HTTP request runs at a time, with at most four pending requests, an 8 MiB
body limit, ten-second timeout, no redirects and a thirty-second failure retry
cooldown. Godot 4.6.3's Web fetch omits a redirect policy, so a Web-only guard
enforces `redirect: error` and `mode: same-origin` for this art prefix. Unrelated
engine, PCK and wasm fetch calls keep their original options. The guard contains
no GDScript callbacks and restores the original function after its last owner
exits. Before creating a full texture, the response must be HTTP 200 with the
exact manifest byte length and SHA-256, decode as WebP, and match both delivery
and original dimensions. Mipmaps are generated after validation.

A verified texture enters the existing 48-entry / 32 MiB estimated LRU and
invalidates the visible inspector binding. Missing, corrupt, disconnected or
oversized responses leave the real 512-pixel preview visible and explicitly
labelled. A failed download does not become a full/original-quality claim. There
is no application-managed persistent HTTP cache or background prefetch of all cards. Browser image
decoding, request buffers and visible Control references are outside the LRU's
retained-byte estimate; it is not a total-memory guarantee.

## Actual verification

The first local candidate was exported from base
`d880c450baa5a9644c6065ed0a2f3677a9514d49` plus the uncommitted delivery changes.
It is provisional working-tree evidence, not an exact-source Git build or a
release. Its artifact and changed-source hashes are recorded in
`art-evidence/delivery-results.json`. The implementation must be rebuilt at its
committed SHA and again after integration with the active Core branch.

| Gate | Actual result |
| --- | --- |
| Derivative regeneration | 77 assertions, zero failures; 15 native-size derivatives |
| Real loopback HTTP | 74 assertions, zero failures; success, 404, wrong SHA, wrong expected geometry, redirect, disconnect, over-8-MiB body, queue/cooldown and compact no-network checks |
| Isolated Web PCK | 144 assertions, zero failures; zero full textures, 15 decoded previews, honest offline inspection and no project-source fallback |
| Isolated native PCK | 144 assertions, zero failures; 15 decoded full textures and 15 previews, no raw original/source fallback |
| Staging rollback and success | Six filesystem unit tests pass, including art preparation failure |
| ZIP/staging boundaries | Eleven filesystem unit tests pass, including recursive art entries, hashes, symlinks, traversal and unmanifested files |
| Original/preview provenance | Eight Python tests pass |
| Web transport scoping/release | Four tests evaluate the exact embedded JavaScript guard |
| Actual browser delivery | Ten Chromium/WebKit contexts, 236 assertions, zero unexpected failures: success, offline, corrupt, redirect and oversized-response cases |
| Native visible cache/redraws | 38 assertions, zero failures; 15 compact cards plus one full inspector, 20 rendered redraws |

The actual provisional Web PCK is 15,294,284 bytes; the native PCK is 33,505,260
bytes. The 15 external WebPs total 5,388,974 bytes. The actual prepared ZIP is
27,867,527 bytes and contains all 15 external WebPs with verified hashes. These
figures describe this measured fifteen-image candidate, not a predicted 550-card
download size. The previous full-art Web PCK measurement is retained as historical
evidence in `ART_BATCH2.md`.

The browser gate uses real visible touch/search input and real HTTP bodies from
the exported files. Eight contexts passed with the original strict page-error
check; the last two use a narrow classification of WebKit's exact browser-native
forced-redirect notification, including its empty stack and the exact requested
URL. The corrected cases independently require no unhandled promise rejections.
Both harness hashes and all individual context results are retained. This is
complete scenario coverage across two runs, not one successful uninterrupted run.
The oversized case proves rejection with a retained preview; it does not identify
whether byte-length or transport-limit rejection fired first, or measure browser
memory. Physical iPhone/Safari memory and touch-latency tests remain outstanding.

Actual screenshots: [verified full illustration](screenshots/art-delivery-full.png)
and [offline preview](screenshots/art-delivery-offline.png).

## Preview scaling measurement

All 15 prepared preview imports already use lossy quality 0.90 and generated
mipmaps. An isolated PCK probe measured their actual imported CTEX streams at
**1,398,800 bytes total**, with no project-source fallback. The prepared PNGs are
5,447,721 bytes; these PNG source bytes are not the packed texture size. Individual
CTEXs range from 59,508 to 127,592 bytes. Decoding the actual imports gives RGB
PSNR 32.63–39.49 dB against the 512-pixel prepared PNGs. The lowest-PSNR pair was
visually inspected at native preview size; no quality setting was reduced.

At this fifteen-image sample's mean, 550 previews would contribute about 51.29 MB
of CTEX data. Holding other content constant projects a 65.18 MB PCK, plus the
actual 35.75 MB wasm engine and other startup files. This is a scaling projection:
550 corresponding individual originals do not yet exist in this branch, and it
is not a measured 550-image download, cold-start time or phone result. The next
separate delivery stage will package a small pinned preview set and request other
previews only for visible cards. This milestone still packages all 15 previews.
Full details are in `art-evidence/preview-byte-measurement.json`.

```sh
# Use writable XDG directories and the installed Godot 4.6.3 templates locally.
godot --headless --path . --audio-driver Dummy --script tools/production/prepare_art_delivery.gd -- --check
bash tools/test_production_art_delivery.sh
python3 -m unittest discover -s tests -p production_art_delivery_package_test.py -v
node --test tests/build_alpha_staging.test.cjs
bash tools/build_alpha.sh
bash tools/test_production_art_package.sh work/alpha/web/orafold-COMMIT.pck web
godot --headless --path . --export-pack 'Linux QA' work/production-art/native-art.pck
bash tools/test_production_art_package.sh work/production-art/native-art.pck native
python3 tools/package_alpha.py
node tools/production/browser_art_delivery_qa.cjs
```

An initial local build omitted writable XDG overrides and failed to locate the
installed templates; it is not counted as a passed export. The first ensure-cache
attempt then exposed Godot's parsed JSON float versus integer dictionary equality
behavior. Normalizing numeric values before comparison fixed that build failure
without changing original images or committed delivery metadata. The first HTTP
attempt exposed an inferred-type compile error; the passing run uses an explicit
boolean type. Failed attempts are retained in local development history and are
not included in the passing counts above.
