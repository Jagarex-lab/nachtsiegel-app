# Premium Mobile delivery plan

Base: `develop` / `10782185cf41f2013607ba47da0bbfcb737e89e2`.
Working branch: `feature/premium-mobile-experience`.

## Verified starting point

The working tree was clean. The remote Develop tree still matches the supplied
base. PR27 is integrated. Open PRs 4, 5, 7, 11, 14, 15 and 26 are historical or
superseded work; they are not merged again. The active catalog contains 550 cards;
the older Alpha55, Legacy100 and prototype cards remain regression references.

The current card renderer already resolves individual production artwork and
owns a bounded texture cache. Its compact battlefield branch below 72 pixels,
however, reserves most width for text and only a narrow illustration. The hand
uses expanding horizontal cells without preserving the collectible-card aspect.
The existing rarity treatment is too small to communicate material differences
at phone size. The battle presenter stacks several permanent button/text rows.
These are implementation findings, not claims of a new visual acceptance.

The prior Safari viewport correction uses usable CSS dimensions, delayed resize
settling and safe-area handling. It must remain covered during the redesign.
The production kernel, card values, local economy and provisional campaign are
already integrated; presentation work must not introduce a second engine.

## Independently reviewable packages

1. **Baseline and contracts.** Capture actual Godot battle, inspection, menu and
   deckbuilder images. Record source hashes, viewports and art readiness. Freeze
   combat/catalog inputs and map current regression tests.
2. **Shared card materials.** Render three real frame concepts using the same
   card, powers and rarities. Compare legibility, contour, image area and cost;
   select a vector-based shared implementation for hand, board and inspection.
3. **Arena and spatial comparison.** Build flat 2D, perspective 2.5D and actual
   Camera3D/SubViewport variants with the same state. Compare actual phone
   renderings and measurable hit areas. Select the best composition and integrate
   explicit layout geometry, portrait hand, compact HUD and contextual actions.
4. **PWA and continuity.** Add standalone metadata/icons, installation help,
   supported fullscreen controls and bounded versioned caching. Preserve Safari
   rotation and validate local duel resume through the existing replay contract.
5. **Gameplay and system verification.** Re-run unchanged rules, all550 catalog
   checks, paired AI simulations, replay, audio, economy, campaign and online
   security. Correct reproducible defects; do not invent balance nerfs from a
   small or policy-dependent sample.
6. **Combined visual QA.** At least three documented iterations; Chromium and
   WebKit on 844×390, 852×393, 932×430, 1024×768 and desktop, plus portrait menus.
   Inspect opening, full board/six-card hand, inspection, targeting, results,
   restart, deckbuilder and integrated features. Retain failed attempts as well
   as successful evidence. Do not describe Linux emulation as physical iPhone QA.
7. **Dormant release preparation.** Prepare a tested one-click exact-commit
   release proposal without activating an alternate publisher or modifying the
   existing manual barrier. Explicit subsequent approval is required to activate
   it. Open a reviewed PR against Develop with fresh CI and visual evidence.

## Invariants and release boundary

- Five paths and all combat/resource/victory rules remain unchanged. An attack
  into an empty opposing path hits the opposing hero; existing block/shield
  ordering remains covered by kernel tests.
- One common card silhouette, 63:88 proportions and one shared card back.
- Original illustration files are not upscaled or rewritten. Rendering uses
  existing licensed/provenance-tracked source assets; commercial legal clearance
  is not inferred from file validity.
- No real-money features, paid services, public multiplayer hosting, security
  setting changes, automatic merge or production publication in this package.
- The current manual Pages workflow remains authoritative until the separately
  requested activation is expressly approved. Old QA IDs cannot release new SHAs.

## Evidence status

Implementation and new acceptance are in progress. Existing Alpha0.3 CI results
are baseline evidence only. Final test counts, chosen variants, screenshots and
remaining physical-device limitations will be recorded in the accompanying
comparison and QA reports after execution.
