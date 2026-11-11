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

Tall desktop/tablet slots (at least 170×160 CSS pixels) now use their full portrait
surface, with an opaque complete-name header and diagonal value/status footer.
The former 66px image strip left most of a 310×340 slot empty. Current attack/life,
separate shield/block, readiness and origin/convergence/buff markers stay visible.
All 357 actual creature names/value glyphs are measured at three tall sizes;
five real native framebuffers separately prove the new drawing.

On usable heights of 620 pixels or more, battle hand cards are 144 pixels tall
(160 on the taller desktop), and opening cards 160. Small-phone hand heights,
44 pixel minimum targets and the paired five paths retain their existing budgets.
The native layout suite checks five actual viewport sizes, the real opening,
and an explicitly arranged six-card/ten-creature boundary. These arrangements
are layout evidence, not additional complete games or balance measurements.

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
The actual source inventory now contains550 visually approved individual originals;
that count is established by files/provenance, not inferred from550 card records.
The Web packs five pinned starter thumbnails, streams other compact images only
for live visible Controls and gives full inspectors priority. Missing/offline
responses remain explicit. Frames, text and values remain deterministic UI;
commercial-clearance flags are separate. See ART_PIPELINE.md and
ART_PREVIEW_STREAMING.md for actual codec, cache and review limits.

## Verification

Native suites:

```sh
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/production_ui.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/production_board_portrait.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/production_desktop_hand.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/master550_library_filter.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/alpha_ui.gd
DISPLAY=:99 LP_NUM_THREADS=2 godot --path . --audio-driver Dummy --script tests/master550_opening_ui.gd
```

The new local tall-board suite passed 8,583 assertions / 0 failures; the desktop-hand
suite 180 / 0; the complete paginated production UI 5,012 / 0, with clean script/font/
texture teardown. A former duplicate direct Alpha/Production catalog preload
retained eight script/font resources in CI. The fixture now uses the actual
production catalog and the existing audio owner's orderly shutdown, retaining
all assertions and keeping synthetic layout records explicitly separate.

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

## Actual touch scrolling and clip-aware browser checks

The four deck-selection panels used the default stopping input filter. A primary
touch drag on their content never reached the ScrollContainer, even though wheel
scrolling could work. Decorative panels now pass input and portraits ignore it.
The native regression uses actual ScreenTouch/ScreenDrag events, recreates the old
STOP fixture (0px), verifies the corrected scrolling (33px), and selects the fully
revealed second-row power by touch. It passed 23 assertions with clean shutdown.

Read-only QA retains its existing action rectangles and adds each action's visible
rectangle after intersection with the viewport and all clipping ancestors. The
browser gate requires the complete 44 CSS-pixel control to be visible, uses actual
pointer pans, and verifies the full 30-card saved list in the newly created match.
Chromium uses primary CDP touch; WebKit's public automation API supplies taps but
no general touch-pan API, so its pan is explicitly identified as a browser mouse
gesture through Godot's configured touch emulation. Neither is a physical iPhone
test. Earlier viewport-only coordinates could land behind the fixed footer and
start a starter deck; that failed attempt remains separate from later checks.
