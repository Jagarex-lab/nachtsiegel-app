# Illustration pipeline and actual delivery

Status: production work in progress, 10 November 2026. The 550-record candidate
catalog has **five newly generated, visually approved individual illustrations**,
not 550 finished illustrations. **545 individual illustrations are missing.**
The implementing and root agents inspected the actual original images and card
renders under the user's delegated production order. Commercial rights review
remains incomplete for every image.

`data/production/art_briefs.json` contains one brief for each actual catalog ID.
These instructions are proposals, not generated assets or new world canon.
`data/production/art_sources.json` records the five actual images, complete
generation prompts, date, original dimensions, byte hashes, absence of reference
images, absence of edits and current review status. The native PNG originals
remain in `assets/cards/originals/` and are not AI-upscaled versions of the atlas.

| Card | Stable ID | Source pixels | Actual state |
| --- | --- | --- | --- |
| Torwache | `oa-neutral-c02` | 1448 × 1086 | Visual production approved; legal review pending |
| Namenhüter | `oa-houses-c01` | 1448 × 1086 | Visual production approved; legal review pending |
| Glaskonservator | `oa-stillwatch-c01` | 1448 × 1086 | Visual production approved; legal review pending |
| Sprunglarve | `oa-morph-c01` | 1448 × 1086 | Visual production approved; legal review pending |
| Kausaljäger | `oa-ninth-c01` | 1448 × 1086 | Visual production approved; legal review pending |

These preserve the current card IDs. Their visual details are small setting
proposals, not new confirmed leaders, origins, historical events or Eira
revelations. Original downloaded generation files are retained outside the
repository under the environment's `generated_images` directory. Repository PNGs
are byte-identical copies, with the source filename recorded in provenance.

## Deterministic inventory

```sh
python3 tools/production/art_manifest.py
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p production_art_manifest_test.py -v
godot --headless --path . --audio-driver Dummy --script tests/production_art_pipeline.gd
godot --headless --path . --audio-driver Dummy --script tests/production_card_text_layout.gd
```

The generator binds its inventory to the exact SHA-256 of
`data/production/cards.json`; rerun it after catalog edits. It requires a matching
art brief for every card. It checks each actual PNG's signature, chunk boundaries,
CRC, pixel-stream decompression, dimensions, expected card filename and original
hash. Duplicate actual originals, orphan source IDs, renamed images, corrupted
images and final states without an explicit production approval record fail. Orphan disk files are reported for
review; the tool never deletes them. Source paths outside the originals directory,
traversal, encoded aliases and symlinks are rejected.

`art_manifest.json` explicitly separates `missing`, `concept` and `final`. Its
counts describe files and review states, never playability or legal suitability.
An expected filename is not evidence that an image exists. No missing asset is
declared generated. The older seven atlas motifs remain labelled fallback
concepts, not individual illustrations for hundreds of cards.

## Runtime

`scripts/production/art_resolver.gd` loads the small manifest once and loads
textures only when requested by a visible card. Full and compact card renderers
share it. The resolver returns the texture, actual display state, label, path,
individual-original flag and commercial-clearance flag. An explicit card field
cannot promote an unapproved original or the shared atlas to a final illustration.

The least-recently-used cache retains at most eight textures and an estimated
32 MiB of RGBA pixels including a mip pyramid. `stats()` exposes the estimate and
load/hit counters; `clear_cache()` releases retained references. These are cache
estimates, **not measured total GPU/browser memory**; visible nodes and Godot can
hold additional references. A future 550-image release must also measure export
size, decode stalls, actual device memory and individual asset streaming.

The five originals use lossless import at their native dimensions and generated
mipmaps. No size-limit downsampling is applied. Linear mip filtering applies to
illustrations, while text remains deterministic font rendering. PNG source image,
frame, statistics, titles, symbols and rules are separate. All cards retain the
same renderer-controlled 756 × 1056 outer silhouette and common card back.

## Rights and release limits

OpenAI Image Generation produced these five assets without supplied reference
images. Their prompts request original local scenes and exclude known characters,
logos and game interfaces. This records provenance and a visual screening; it is
**not a legal opinion, trademark search, guarantee of exclusivity or completed
commercial clearance**. `commercially_cleared` remains false for all five.

The five images moved to `final` / `approved` only after the root agent reviewed
the actual rendered masters for palette, species, motif, crop and obvious visual
errors. This is delegated visual production approval, not a human legal review.
The two dimensions remain separate: `status=final` says the image is visually
ready for the current production direction; `commercially_cleared=false` records
that legal review is still open. The project owner must retain applicable
generation terms and complete that review before claiming commercial clearance.
Do not set either flag merely to remove a label.

The 545 missing originals remain production blockers for the user's full final
acceptance. The usable candidate catalog and missing-art pipeline do not satisfy
the complete commercial illustration requirement.
