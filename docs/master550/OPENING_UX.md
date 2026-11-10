# M6: Mulligan on the battlefield

This is a bounded implementation milestone of the 550-card plan. It does not add cards or claim that the complete master order is finished.

## Implemented

The opening now uses the same five paired lane controls and model data as combat in `scripts/alpha/shell.gd::_battle_board`. The board is visible from the first mulligan frame. The opening no longer displays a separate list of card-name buttons.

1. The real five starting cards appear below the battlefield. Tapping a card toggles its exchange mark; an outlined `TAUSCHEN` ribbon remains inside that card. The primary action states how many cards will be exchanged, or offers to keep the hand.
2. `KARTENDETAILS` opens the existing complete card inspector for the last tapped card. It includes its full name, cost, power, type, rarity, values when applicable, ability text and keyword explanations. Closing it retains the exchange marks.
3. Confirming sends the original `mulligan` command. Original draw-before-return/shuffle rules and deterministic RNG remain in `scripts/alpha/model.gd`.
4. The five own lane controls become origin targets. The opponent's lanes cannot select an origin. Origins are displayed only when the model has revealed them.
5. If the human is second, the same battlefield supports the optional second origin choice and the optional one-card exchange. Selecting a hand card does not immediately exchange it: `KARTE TAUSCHEN` explicitly confirms this irreversible operation. `KAMPF BEGINNEN` may be used without either optional change.
6. Combat then continues in the same board composition. No phase, energy, resonance, shield, combat, AI or victory rule changes were made.

The hand briefly fades in when the actual card IDs change, including replacement cards. The presentation never delays a command. Reduced motion displays the cards immediately. Physical card travel and richer replacement animations remain separate work.

The inspector uses the canonical 756×1056 split/diagonal full-card renderer in portrait or when the viewport is at least 560 logical pixels tall. Its card wrapper responds to the available scroll width, including rotation while the inspector remains open. Smaller landscape screens retain the existing compact illustration plus readable scrolling full text. Both retain the same close and target-selection actions. Shared atlas art remains explicitly labelled.

## Optional drag and drop

Normal Alpha combat now accepts either the original tap-to-select/tap-target interaction or a one-pointer hand-card drag. A gesture must move at least 12 CSS-equivalent pixels before becoming a drag. The lifted card follows the pointer; legal board targets are highlighted. Relics have a separate `RELIKT` drop area in the upper resource bar and never occupy a path. This preserves the previous hand-card widths. The pre-existing tap-on-lane installation route remains compatible with the existing input tests.

Drag start records the source index and stable card ID, the full model-state digest and a snapshot of currently legal targets. Release requires all of these to remain valid before sending one original `play` command. There is no new effect implementation or second rules engine. Invalid drops, canceled touches, rotation/layout reconstruction, focus loss and an eight-second inactive pointer cancel the presentation without changing the model. Other touch pointers cannot take over the gesture. Synthesized mouse/touch duplicates are excluded from gesture ownership.

Mulligan and optional-opening exchanges continue to use explicit tap and confirmation rather than drag. A drag does not bypass targeting restrictions, pending choices, resource costs, summoning limits or the current phase. Reduced motion does not change input behavior.

## Input and rotation

Existing action IDs remain available: `mulligan_<index>`, `mulligan_done`, `origin_<lane>`, `second_origin_<lane>`, `second_card_<index>` and `opening_done`. Lane IDs now refer to the real battlefield controls. During the second opportunity, `second_card_<index>` selects that card; the added `second_exchange` action confirms the exchange.

Landscape remains the combat orientation. Portrait, or insufficient usable browser height, shows the existing rotation guard and a safe menu return. There is no forced Safari orientation lock and no rotated canvas. Rotation rebuilds presentation from the unchanged model and retains mulligan marks, the inspected/selected index, origins, optional-choice flags and command history. No new local match-resume promise is made.

The opening is tested at 844×390, 915×412, 844×320 and 1280×720. All ten lane controls, all five hand controls and primary actions remain inside the viewport with at least 44×44 logical touch areas.

The six-card hand is additionally checked at **756×299 and 756×320 usable pixels**, representing an 844-wide phone after side safe areas. `CardView.stat_layout` measures the actual caption and font used by drawing. It preserves `ANG` and `LP`, removes redundant spaces and chooses 13, 12, 11 or 10 logical pixels only when the larger font would intersect the energy badge. All 55 existing Alpha cards are checked at the smallest real tile width for complete names, correct combat values and stat ink bounds. Board-unit rendering remains unchanged.

## Verification

`tests/master550_opening_ui.gd` uses real `InputEventScreenTouch`, `InputEventScreenDrag` and mouse events against the production shell and real seeded model starts. It covers marking/unmarking, the inspector, original mulligan command arguments, origin selection on actual lanes, rejection of opponent-lane taps, first- and second-player openings, optional-choice limits, portrait transitions, reduced motion and deterministic replay of the recorded opening commands. Drag cases are prepared through valid original commands and independently replayed; they never edit model state. Tests cover creatures, impulses and relics, small-movement taps, valid/invalid/canceled drops, rotation cancellation and exactly one play command. A separate explicitly manufactured layout fixture fills ten lanes and six hand slots using existing card data; it tests geometry and is not presented as a recorded gameplay position.

Reproduction from the repository root:

```sh
export DISPLAY=:99 LP_NUM_THREADS=2
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
godot --path . --audio-driver Dummy --script tests/master550_opening_ui.gd
godot --path . --audio-driver Dummy --script tests/alpha_ui.gd
godot --path . --audio-driver Dummy --script tests/alpha02_ui.gd
```

The opening test writes real native screenshots to `work/master550/opening/`:

- `mulligan-marked-844x390.png`
- `mulligan-inspection-844x390.png`
- `origin-844x390.png`
- `second-844x390.png`
- `full-card-portrait-390x844.png`
- `compact-fixture-756x299.png` and `compact-fixture-756x320.png` (explicit layout fixtures)

These are desktop Godot renders using simulated viewport sizes. They are not iPhone-device evidence. The images use the existing explicitly labelled atlas illustrations; no new art is claimed.

## Results and limits

The combined opening/input/inspection suite passed **852 assertions with 0 failures**, including the permanent narrow safe-area fixture and all 55 hand-card names and stat captions. The existing Alpha02 suite passed **769 assertions with 0 failures again after the caption fix**. The preceding `alpha_ui.gd` regression passed 347 assertions with no failures. A focused drag probe also passed 38 assertions, including release immediately after a viewport-size change, and the open-inspector rotation probe passed 9 assertions. Test logs are `work/master550-opening-ui.log`, `work/master550-drag-probe.log`, `work/master550-inspector-probe.log`, `work/master550-alpha-ui.log` and `work/master550-alpha02-ui.log`.

The narrow fixture originally reproduced six clipped `LP` captions caused by redundant spaces in `%d ANG   %d LP`; the shared measured stat layout fixes those overflows. Reproduction is now part of the committed main suite, rather than relying on the temporary `work/master550/compact_probe.gd` used for diagnosis.

This milestone does not validate mobile Safari hardware, browser orientation APIs, audio, the 550-card catalog or cross-card balance. Browser/production verification remains a separate integration gate. The original seven Godot prototype cards, frozen legacy reference, campaign scenes, data and workflows are unchanged.
