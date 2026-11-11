# Safari viewport and orientation repair

The reported Alpha 0.2 symptom was a rotate prompt remaining visible after an
iPhone had turned to landscape. No physical iPhone reproduction was available.
Source inspection identified a reproducible dimensional disagreement: the old
shell decided portrait from Godot's backing buffer (`size.y > size.x`), while
fitting the UI with independently sampled canvas/visual viewport values. Safari
can update the CSS layout before the buffer or visual viewport. Its
`orientationchange` handler also retried only once, on the next animation frame.
This establishes source defects and a testable failure mechanism, not proof of
the exact event sequence on the reporter's phone.

## Change

- One browser snapshot records CSS layout dimensions, canvas CSS dimensions,
  validated visual viewport, zoom/offsets and safe area together.
- Orientation follows the layout viewport, independently of `screen.orientation`
  support, its angle/type, or a stale Godot backing buffer. A same-width editable
  keyboard view retains its prior orientation. Pinch zoom does not set orientation.
- Visual viewport width times scale must agree with layout width before its
  height and offsets can constrain the UI. An old portrait visual viewport is
  ignored during landscape settling.
- Immediate, animation-frame and 50/150/300/600/1000/1600 ms refreshes follow resize,
  orientation, resume and visual viewport events. Changes found by delayed
  refreshes also notify Godot's resize policy. Timers are bounded and replaced
  by newer event sequences; unchanged snapshots do not rebuild the UI.
- Safe area and the visible rectangle are intersected, avoiding duplicate top
  padding during keyboard/zoom panning. Each CSS axis maps to the current backing
  buffer independently, retaining 44 CSS pixel primary controls even while the
  buffer has its old aspect ratio. The canvas is never rotated or orientation
  locked.
- Landscape below 248 usable CSS pixels gets the existing space guidance with
  keyboard/zoom/browser-bar remedies. Portrait gets the rotate explanation.
  Battle modals are retained but hidden while either guidance screen is active.
  The return-to-menu action remains at least 44 pixels and visible.

The model, RNG, command processing, deck data and rules are unchanged. Ordinary
layout rebuilds retain selected card, source lane, action mode, convergence marks
and mulligan choices. A fresh browser document in landscape recognizes landscape
without requiring another turn. Browser navigation/reload does **not** gain
in-progress match persistence; the existing session stores the profile only.

## Verification

`tools/alpha03_viewport_browser.cjs` runs the actual inline shell bridge in real
Linux Chromium 158.0.8127.18 and WebKit 27.2. It injects layout/visual viewport
timing faults; it is not a full exported-game or physical Safari test. Both
browsers pass 18 checks, including absent/stale `screen.orientation`, old portrait
buffer, stale visual viewport, delayed dimensions without a final resize,
width-first/height-first sequences, browser chrome/safe insets, keyboard,
zoom/pan, invalid/missing visual viewport, repeated turns, bounded retries and a
fresh landscape document.

The same harness's `--baseline` mode loads `9c235781:web/shell.html` and evaluates
the previous GDScript layout equations. Before the change it fails the named
stale-portrait-buffer landscape check in both browsers, and fails delayed-height
settling without a final resize. This is a deterministic source-level regression,
not a claimed reproduction on an iPhone. JSON evidence is saved next to this doc.

Native Godot 4.6.3 checks:

- `tests/production_mobile_metrics.gd`: 30 assertions, 0 failures. Covers native
  density plus CSS/buffer mapping, 44 CSS pixel dimensions, safe intersections,
  short landscape, keyboard orientation, and invalid metrics.
- `tests/alpha03_orientation.gd`: 95 assertions, 0 failures using the real production
  Shell/model. Compares the entire model snapshot (including RNG) and command
  array plus all UI selections through repeated portrait/landscape rebuilds,
  including 220/247/248 pixel landscape heights and marked mulligan cards.

Commands from the repository root in this managed environment:

```sh
NODE_PATH=/workspace/nachtsiegel-app/work/qa-browser-current/node_modules \
PLAYWRIGHT_BROWSERS_PATH=/workspace/nachtsiegel-app/work/qa-browser-current/browsers \
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 \
node tools/alpha03_viewport_browser.cjs
# Add --baseline for the expected failing previous implementation.

XDG_DATA_HOME=/tmp/orafold-safari-data \
XDG_CACHE_HOME=/tmp/orafold-safari-cache \
XDG_CONFIG_HOME=/tmp/orafold-safari-config LP_NUM_THREADS=2 \
godot --headless --path . --script tests/production_mobile_metrics.gd
# Same environment: --script tests/alpha03_orientation.gd
```

The installed headless WebKit WPE runs successfully; Playwright's generic host
validator checks unavailable GTK libraries too, so this test uses the skip flag.
No browser packages were downloaded or installed. Native tests use already
imported immutable project resources.

Current patched-export browser verification is performed after integration;
the old frozen export was not overwritten. Physical iPhone Safari verification
remains necessary for the original device-specific report: rotate repeatedly in
both directions with browser bars expanded/collapsed, keyboard and zoom, retain
opening marks and an active card selection, and check notch/home-indicator bounds.
