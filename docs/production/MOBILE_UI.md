# Alpha 0.3: mobile UI and the production library

Status: implemented in the production feature branch; release and browser evidence
must be checked against the final integration commit. This is a catalog preview,
not a claim of finished commercial production or physical iPhone testing.

## Library and deckbuilder

The normal shell uses one cached `scripts/production/catalog.gd` instance.
The archived Alpha and Legacy catalogs keep their separate constructors.

For more than 60 matching cards, the collection creates only the current page:
12 cards on mobile, 24 on desktop. Previous/next controls remain visible outside
the scrolling grid and have a minimum 44 × 44 CSS-pixel hit area. Search, filters,
sort order, power changes and desktop/mobile page-size changes reset the page.
Mobile rotation preserves the page when the page size stays the same. Adding a
card preserves the current page and scroll position. Every identity is reachable;
pagination is not an unlock or ownership rule.

The active production collection contains 550 records. A selected-power builder
queries its 110 cards and the 110 neutral cards. Name, ability, species, kind,
rarity, exact energy and power filters continue to use the same pure filter
module. Fourteen actual production test decks are editable templates. Loading
one never replaces a saved deck until the user presses Save.

## Battlefield

The paired five paths and battlefield mulligan remain the opening surface.
The narrow unit view separates permanent combat values from a status column.
It shows attack after the player's current weakening, current life, unit shield,
unit block, attack readiness/summoning delay/stasis, origin and convergence.
The larger view retains portrait, nameplate and value strips. Full inspection
shows complete rules and equal-rank species. Unit block is provided by the
production model; archived units default to zero and their rules are untouched.

Relic inspection offers the real activation command with the model's exact energy
and resonance costs. Passive-only or currently illegal activation remains disabled.
Prepared reactive impulses expose a count and an inspection list with their actual
expiry semantics. These controls do not invent new battle commands.

Read-only browser diagnostics expose actual `play_support` results, target side,
controlled lanes and visible unit metadata. Browser tests use these results to
select legal input actions rather than duplicating card-specific effect rules.

## Feedback, interruptions and recovery

Short, bounded overlay jobs distinguish hero block absorption, shield absorption,
life damage, healing, resonance gains and unit changes. At most 24 jobs exist.
Reduced motion removes decorative trails/rings while retaining short static
informational text. Feedback never owns, delays or resolves a model command.

Existing DOM cancellation protection is retained for both drag and ordinary taps.
An accepted command that encounters an engine error stops battle input and opens
an explicit recovery dialog with replay export, restart and menu actions. It is
not described as an ordinary invalid target. Profile migration/recovery notices
are available in Settings. A functional first-game rules guide is available there.

## Illustrations

Compact cards and full inspection share the production illustration resolver.
Individual concept artwork is labelled separately from shared-atlas placeholders.
Frames, text and values remain deterministic UI. No number of individual final
illustrations is implied by the existence of 550 card records.

## Verification

Native suites:

```sh
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/production_ui.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/master550_library_filter.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/alpha_ui.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/master550_opening_ui.gd
```

`production_ui.gd` deliberately distinguishes its 550-entry layout fixture from
actual production records. It traverses all pages at 390×844, 320×568, 844×390
and 1280×720, verifies bounded node/card counts and then measures compact names
and values for the actual production catalog. The other suites exercise real
collection controls, touch-driven opening, card play, drag cancellation, rotation,
replay, saving and restart. The original pure 55-card query and deck/model tests
remain historical regression coverage.

`tools/master550_browser_qa.cjs` additionally traverses all 550 real collection IDs
through visible browser pagination controls, searches a last-page identity,
applies species filtering and opens inspection. Browser screenshots and assertions
are not real-device tests. Real iPhone/Android thermal, memory and Safari toolbar
behaviour still require device testing.
