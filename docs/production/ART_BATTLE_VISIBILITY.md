# Battle illustration lifecycle regression

A normal browser duel on source `4026f943992a2eaa30269acd8e6cf354f11fd022`
showed offline art while the same artifact successfully fetched collection and
inspector images. Delivery was enabled but all request counters were zero.
The packaged runtime manifests and external WebP bodies matched their sources.
This was independent of the preceding build-only JSON packaging change.

`CardView.illustration()` retained a binding and card/profile identity even when
its request was refused because container geometry was not visible during the
first draw. If the view was visible at the next process callback, the unchanged
binding suppressed another resolution. No owner had been registered, so no HTTP
request or delivery-version invalidation could repair it.

CardView now records visibility at the actual resolve/draw point and invalidates
its binding once on the transition to a visible owner. Existing owner release,
queue priority, cancellation, cache limits and card/profile invalidation remain.
Steady-state redraws do not repeatedly resolve images. No rule, catalog, image,
resource model or HTTP validation policy changes.

## Reproduction and regression

`tests/production_art_visibility.gd` uses the real CardView draw callback with
initial container geometry outside its viewport, then restores visible geometry
before the next process callback. The unmodified lifecycle failed the subsequent
owner-registration check. The fixed lifecycle passes **12/12**, including
visibility return, replacement after rotation, decoded pixels and zero repeated
resolver/cache work over fifteen stable frames. This native test uses actual
local images; it does not claim to test browser HTTP delivery.

Targeted native checks on the fix:

- Lifecycle: 12 assertions, 0 failures.
- Shared cache: 81 assertions, 0 failures, 24 compact views and one inspector.
- All 550 card text layouts: 2,201 assertions, 0 failures.
- Production UI: 5,507 assertions, 0 failures.
- Actual compact HTTP: 51 assertions, 0 failures, including bad hash/geometry,
  redirect/size rejection, cancellation, full priority and bounded cache.

Logs are under `work/production-art/lifecycle-*`; the original negative case is
`work/production-art/visibility-before.log`. Reproduce the new render regression
with `godot --path . --audio-driver Dummy --script tests/production_art_visibility.gd`
using a writable XDG directory and a display. It is also included in
`tools/test_production_art.sh`.

## Actual browser evidence contract

`CardView.art_report()` reads only the currently bound texture and status. It
never calls the resolver, loads a resource, updates the cache or starts delivery.
QA exposes the real hand/board views as `battle_art`, with card ID, zone, actual
visibility, status, pending flag, profile, pixel dimensions and delivery state.
Delivery metrics additionally expose validated entry and registered-owner-key
counts without changing state.

The normal browser harness now requires visible, decoded, non-pinned external
compact art in both the real mulligan and battle. It verifies dimensions against
the delivery manifest and checks that waiting for art issues no game command.
Exact committed-artifact browser results are recorded separately by the final
browser gate; the native results above alone are not a browser pass or release.

## Intentional Web cancellation follow-up

The first exact f8 browser run completed a real 45-command duel, replay viewer
and restart with all eight gameplay frames, and the before/after midgame battle
snapshots were identical (seed 8802028, command 13). All four board creatures and
five hand cards now had real illustrations. A WebKit iPhone-bars profile also
passed real mulligan, battle and newly drawn external-art checks. Nevertheless,
the desktop run correctly **failed** on a normal owner-cancellation `AbortError`.
It is not recorded as an overall passing browser run.

Godot 4.6.3's Fetch.onerror logs a rejected fetch/body read even after its engine
request object has been freed. The scoped art guard now handles only its own
explicit AbortController cancellation: before headers it returns an empty
non-success response (499); during body streaming it closes the pending reader.
Other network/body failures still reject. Images remain streamed with ordinary
backpressure, not downloaded in full before the engine sees their response.
No global error filter or engine/generated-JS patch is introduced.

Eight exact embedded-guard Node tests pass. The new pre-header and mid-body
cancellation tests both fail with AbortError against the actual f8 source guard;
negative evidence is `work/production-art/transport-abort-before.log`. The art
browser harness now explicitly fails any AbortError console record as well as
its existing pageerror/unhandled-rejection/script checks. Exact-artifact browser
confirmation of this follow-up remains a release prerequisite.
