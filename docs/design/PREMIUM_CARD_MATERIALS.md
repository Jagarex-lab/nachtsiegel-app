# Premium card materials and mobile representations

Base: `10782185cf41f2013607ba47da0bbfcb737e89e2`. This change concerns presentation only. Catalog values, rules, original illustrations, delivery manifests and asset rights are unchanged.

## Three implemented and rendered concepts

`frame_concept` is a real renderer selector on `CardFace` and `CardView`, not a mockup or replacement image. `tools/premium/render_card_concepts.gd` renders the same twenty actual production cards (five powers × four rarities, including Wesen, Impuls and Relikt) in all three variants. Each sheet contains four 236×330 canonical faces and twenty 90×126 hand cards. The generated comparison records card IDs and source SHA-256 values in `work/premium-mobile/cards/comparison.json`. `rarity-closeup.png` is a separately labelled presentation-only study: one identical actual card motif is shown with four visual rarity overrides at 84×117 and a 2.5× Godot draw scale. The source catalog is never changed by that study.

| Concept | Implemented architecture | Native visual review | Decision |
| --- | --- | --- | --- |
| Reliquary | Broad machined metal rails, rectangular shoulders, rivets, repeated engraved ribs | Strong material silhouette; shoulders make the asymmetric image/text hinge less prominent | Retained for reproducible comparison |
| Prismatic | Alternating filled glass facets, sharp interlocking segments, split specular edges | Clearly different silhouette inside the contour; repeated facets compete with small illustration edges | Retained for reproducible comparison |
| Folded | Asymmetric folded metal rails, lit faces, dark undersides, diagonal hinges, nested folds | Best continuation of the existing diagonal identity; calmer image aperture and readable information plates | Default |

The choice is a development visual judgment from actual Godot framebuffers, not a consumer study or a claim that commercial production quality is complete. All variants use the same font, cards, artwork, text, contour and interaction rules. The canonical full face also places the matching epic/legendary collector architecture below its title bar at the illustration shoulders. It is suppressed when a concept/pending provenance caption needs that area. No new shaders or image files are needed; physical mobile GPU, memory and battery measurements remain open.

## Implemented material system

- One shared `scripts/premium/card_frames.gd` material renderer supplies canonical and compact cards.
- Power pigments are exactly copper `#B9824A`, ice `#58A9CF`, jade `#5B9E68`, amethyst `#9867BE` and steel `#8B98A5`. Vector sigils and different engraved rail motifs supplement colour.
- Common/rare/epic/legendary rails reserve approximately 3/4/5/6 screen pixels at a 90px hand width. Higher ranks add inner bevels, corner armour, crystals and nested fold layers. At compact size epic cards additionally carry a three-crystal crest and aperture-corner clusters; legendary cards have a broad nested fold crown and two side hinges, rather than relying on footer gems. The outer silhouette remains identical.
- All ornaments stay inside the card. Names, costs and combat values are painted **after** the material overlay; legendary ornaments cannot overwrite these fields.
- Optional legendary reveal glints last at most 0.65 seconds. They run only on visible cards and stop for reduced motion. There is no permanent animated idle redraw.
- The canonical card remains 756×1056 (63:88). The neutral, face-independent card back is unchanged and never reads faction, rarity or face data.

## Representation and interaction contracts

`CardView.display_role` accepts `auto`, `hand`, `board` and `library`; legacy properties and measurement helpers remain available. `frame_concept` selects one of the three materials. Shells must set `reduced_motion` from the player preference.

Library cards fit 63:88 inside existing wide touch controls; the touch surface remains unchanged and reported artwork bounds are the actual fitted portrait. Hand and library cards show illustration, top-left energy, top-right vector power seal, a measured complete name and a compact footer. Only Wesen display attack and life; Impulse and Relikte show their type. Complete rules remain in the full, undistorted inspector. Names use 10px minimum normally, 9px only below an 84px card width, with a measured grapheme fallback for two unusually long words. This fallback preserves the whole name but can wrap inside a German compound; full inspection remains the comfortable reading view.

Board cards show the actual current attack/life, separate `S` (Schild) and `B` (Block), readiness or remaining stasis, origin/convergence and attack modifiers. Below 120px height the permanent name plate is omitted to preserve useful artwork; tapping opens the full name and rules in the inspector. At larger slot heights the name remains visible. No creature rule or readiness calculation changes.

The controller can set `availability_shown`, `playable` and `unavailable_reason` after checking its real legal actions. A legal hand card has a bright energy medallion with a second inner ring; an unavailable card has a muted medallion and a lock symbol. Artwork remains fully inspectable. No affordability logic or model calls were added to the renderer. Browser observations also publish the exact measured `title_fits` and `title_font_size`.

`layout_report()` reports the exact local outer/art/title/stats/status rectangles, measured title size and fit, role, rarity architecture, and a conservative visible illustration fraction after opaque plates, cost seals and frame rails. `art_report()` preserves the existing bound-pixels-only contract: it never loads an image, invents a final status or changes delivery ownership. New geometry fields are marked `coordinate_space: local`; the shell must transform them to global CSS coordinates before publishing browser QA observations.

The illustration resolver still owns visibility registration, cancellation and its 32MiB/48-entry retained cache. Original art, compact delivery profiles, mipmaps and the MSDF font remain unchanged. No upscaling is presented as new artwork.

## Iterations and verification

1. Replaced shallow text-strip drawing with portrait/full-aperture representations; added actual three-concept rendering and all-catalog geometry checks.
2. Native screenshot review found legendary corners over names/costs and insufficiently different thin frames. Moved information above ornaments, enlarged filled material rails and separated metal/glass/fold architectures.
3. Reserved rarity-dependent apertures so illustrations cannot repaint the wider rails; adapted name plates to actual text height, preserved the short-slot illustration, and repeated the native comparison.
4. Real phone-arena inspection showed that a name plate still consumed too much of a 90px board unit. Raised the compact-board cutoff to 120px, preserved immediate full inspection, and fitted library cards into existing wide hit controls. New 60px-board coverage initially found 175 image-area failures: width-only material scaling made rare rails too thick in short slots. Frame thickness now uses the smaller canonical-axis scale; all 14,414 checks pass without weakening the image-area condition.

5. Independent visual review still found the 84px rarity hierarchy weak. Added compact-only architectural crests/hinges and a controlled same-motif rarity sheet (`rarity-closeup.png`). Six 84px image-area failures in the first crown pass were corrected by reducing its height, not by weakening the criterion. All normal hand cards now exceed 25% conservatively visible illustration after ornament and opaque UI; the exceptional 72px browser-toolbar layout keeps a separate documented lower budget.

Executed development checks:

- Godot 4.6.3 parser check on CardView and canonical CardFace: passed.
- `tests/premium_card_frames.gd`: **14,416 assertions, 0 failures**; all 550 actual hand names at 90×126, 84×117 and 72×100, all 357 creature status contracts, all twenty power/rarity combinations, 1,100 actual library fits into two wide touch tile sizes, mobile board illustration LOD, and semantic contrast.
- `tests/production_card_text_layout.gd`: **2,201 assertions, 0 failures**; all 550 canonical names, complete rules, type fields and panel bounds. The integration run must repeat this on its final commit.
- Three actual Godot concept sheets were rendered and inspected after the corrections. They are native Linux OpenGL compatibility framebuffers, not physical iPhone or Android acceptance.

Reproduction (use writable XDG directories in the cloud environment):

```sh
LP_NUM_THREADS=1 godot --headless --path . --script tests/premium_card_frames.gd
LP_NUM_THREADS=1 godot --headless --path . --script tests/production_card_text_layout.gd
LP_NUM_THREADS=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/premium/render_card_concepts.gd
```

Screenshots are generated QA artifacts rather than illustration assets. The final integration report must bind its evidence to the executed commit, repeat browser/touch/contour checks and include the actual arena context. No deployment or physical device result is asserted here.
