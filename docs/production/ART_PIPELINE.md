# Illustration pipeline and actual delivery

Status: 11 November 2026. The production candidate has **550 actual individual
illustrations**, exactly 110 for each power and 110 neutral. All 550 PNGs have a
recorded delegated visual production approval. No individual illustration is
missing; all 550 commercial-clearance flags remain false. This is neither a legal
clearance nor a claim of physical iPhone testing or publication.

`data/production/art_sources.json` contains complete generation prompts, dates,
native dimensions, original hashes, alternative text, recorded edits/references
and first-review facts. `art_source_map.json` preserves the collector's source
and tool-output mapping; `art_rejection_trace.json` preserves rejected attempts
without counting them as delivered originals. The canonical source metadata has
SHA-256 `6eafb4bdf0852dd0ecc0e3f7211e915e718955607e31babab54e3d52c891f6ef`.

The final native sources are 527 images at 1448×1086, 17 at 1447×1087, 3 at 1450×1085,
2 at 1449×1086 and 1 at 1491×1055. They are immutable PNGs under
`assets/cards/originals/`; no atlas was enlarged and no odd aspect ratio was
stretched to fit a prescribed size. Frame, text and values remain separate.
Every local visual detail remains a proposal under `docs/LORE-BIBLE.md`.

## Inventory, import and derived files

The complete collector must report 550 real, final/approved, unique originals,
110 per identity, before `tools/production/import_art_staging.py` accepts it.
The importer verifies every native PNG's signature, CRC, decoded dimensions,
SHA-256, ID/name/power, explicit review status and existing target before linking
files. It uses same-filesystem hardlinks, never silently copies 1.5 GB or rewrites
pixels. Existing mismatched originals and symlink profiles are rejected.

New native import profiles use the existing quality 0.90+mipmap standard before
the first editor import. The first five earlier lossless import profiles remain
unchanged; the next 545 use quality 0.90. These imported GPU resources are technical
derivatives; the original native PNGs remain byte-identical.

`prepare_art_previews.gd` creates 550 deterministic 512-edge PNGs by downsampling
only. Actual proportional heights are retained, including the real 1491×1055 →
512×362 regression. `art_previews.json` binds each derivative to its source.
These are not 550 additional illustrations. `art_manifest.py` validates the
complete source/preview relationship and reports missing/concept/final states
and orphan files explicitly. Unknown paths, altered hashes, incorrect geometry,
unapproved final states, duplicate actual originals and traversal fail.

## Runtime and Web delivery

The resolver loads the manifest once and textures only as needed. Compact and
full Controls retain their own bindings. The shared LRU keeps at most 48 textures
and an estimated 32 MiB of RGBA pixels with mipmaps; visible Control references,
GPU driver storage and browser request/decode buffers are outside that estimate.
It is not a total-memory guarantee.

Web packages five pinned starter previews and no full original textures. Other
previews are content-addressed quality 0.90 WebPs requested by genuinely visible
Controls; scrolling out or leaving a page cancels unowned work. Inspectors have
priority and request original-resolution quality 0.90 WebPs. Native packages keep
all imported full/compact textures. A decoded response must match the exact
manifest bytes/hash and geometry before entering the cache. Offline/unfetched
art stays explicitly unavailable or a labelled preview. See
[compact streaming](ART_PREVIEW_STREAMING.md) and the historical
[full-delivery stage](ART_DELIVERY.md).

The Q90 decision is measured: the same ten actual512px previews require 656,692
bytes at quality 0.90 versus 2,750,150 bytes losslessly, 4.19× the mobile transfer.
The read-only 40-assertion comparison checks both real encodings and exact decoded
lossless pixels. Metadata correctly declares `external_lossless:false` and
`quality:0.9`; earlier misleading prose is preserved as a corrected historical
claim, not a lossless success.

## Actual visual and technical reviews

Artists inspected the actual native originals. A separate contact pass viewed
all 550 labelled thumbnails and opened 22 targeted native files. That reviewer
also performed 106 first reviews; this overlap is explicit and is not relabelled
an independent second opinion. Root separately inspected 275 thumbnails on five
contact pages. No new definite visual blocker was confirmed in those scopes;
related book, lens, plant-animal and amber-root motifs remain documented.
See [contact review](CONTACT_REVIEW.md) and the
[portable source-linked gallery](art-evidence/contact-gallery.html).

After complete local import, the actual native renderer pipeline passed 4984
assertions with all 550 imported originals loaded/decoded, their real dimensions,
different decoded pixels, bounded cache and path/state checks. A 24-card visible
page plus full inspector passed 81 cache/redraw assertions, and ten earlier
master renders passed 90 assertions. Source/derivative generation passed 4953,
3302 and 3828 assertions respectively. These are working-tree source-bound tests
before the final integration; browser/PCK/CI proof must still be attached to the
actual final commit. They do not establish all 550 runtime crops by human review,
physical phone memory or legal suitability.

## Rights and reproduction

OpenAI Image Generation produced the illustrations from project prompts. The
real own-project image edit/reference for Zweithautechse is retained rather than
replaced with a false blanket no-reference claim. The prompts exclude known
protected characters and UI. Provenance and visual screening do not guarantee
exclusivity, copyright status or commercial clearance. All 550 flags remain false;
see [rights review](ASSET_RIGHTS_REVIEW.md) for retained sources and open work.

```sh
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p 'production_art_*_test.py' -v
bash tools/test_production_art.sh
bash tools/build_alpha.sh
node tools/production/browser_art_delivery_qa.cjs
python3 tools/production/build_contact_review.py
```

The five grouped power commits carry matching source, preview and delivery
manifests. Every PNG remains bound to a real card ID. Historical Alpha/Legacy
art remains outside this active550-original inventory for regression purposes.
