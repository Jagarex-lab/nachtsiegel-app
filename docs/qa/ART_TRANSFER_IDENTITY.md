# Full-art transfer identity and actual-draw observation

## Observed browser defect and limits of attribution

The strict premium browser run on `4fdcd4cbb5ad12d1068f5f4431f1e2134c5af29d` intermittently left the Glaskonservator inspector (`oa-stillwatch-c01`) at a 512×384 preview with `state=failed`, two rejected requests and no queued request. Another run reached 1448×1086. The first implementation's single `last_failure` field was reset by later successful previews, so the original failed browser run does **not** establish which response body caused each rejection.

Direct HTTP and three subsequent passive browser diagnostic attempts supplied the correct full WebP: 450,794 bytes, SHA-256 `2a1e9e7d0ac7a41e611f0fdc7d88f5bfa19e63c053875610e1bfba60603db67a`. Those diagnostic attempts all succeeded. They do not invalidate the earlier intermittent failure or prove its exact scheduling. No image, manifest, resolution, timeout or integrity criterion was changed to make it pass.

## Deterministically proven transfer race

Godot 4.6.3's [`HTTPRequest::_defer_done` / `_request_done`](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/http_request.cpp) queues native completion. `_request_done` first calls `cancel_request()` on its HTTPRequest and then emits `request_completed`. Cancelling a request does not remove an already queued native completion.

The old service reused one HTTPRequest for all transfers and assigned every completion to the current global `_active` key. Thus an old compact completion could cancel a subsequent full request on the same native node and pass its old body to the new full key. A script-only identity guard would stop misclassification but would not prevent the native old completion from cancelling its successor.

`tests/production_art_transfer_identity.gd` controls that boundary explicitly:

1. Fetch the unchanged actual compact WebP over loopback HTTP and verify its length and SHA.
2. Start an actual slow compact transfer and capture its already connected callback.
3. Preempt it with the actual full-art transfer.
4. Deliver the captured old callback after the handoff.
5. Require the current full request to remain active and free of failure/cooldown; then verify actual full and resumed compact HTTP delivery.

Before the fix, the old transfer topology plus bounded diagnostic instrumentation failed **2 of 6 assertions**, exit 1. A genuine compact response of 77,656 bytes, SHA `f7736064aba8219c2e883938a47ddcf9fd8eba574ee80d2744351d5795326aea`, was wrongly classified as `byte_length` for the new 450,794-byte full key while its visible owner was alive. This is a controlled callback-order regression, not a claim that this exact body was captured in the earlier browser failure.

## Fix

- Create a separate HTTPRequest node for every transfer. Retire the old node by disconnecting its callback, cancelling and scheduling it for deletion.
- Bind monotonically increasing transfer identity **and** expected profile/card key to its callback. Ignore an already queued obsolete callback without rejecting, clearing or changing the current request.
- Keep one active transfer, existing bounded pending queues, 10-second timeout, 30-second retry cooldown, redirect refusal, same-origin guard, body limits, exact byte count/SHA, dimensions, mipmap checks and 32MiB/48-entry cache bounds.
- Retry a failed transfer after the existing cooldown only while a real visible owner survives. A stable card binding or offscreen text label is no longer required to initiate recovery. No hidden/unowned speculative retry is added.
- Retain at most 32 transfer events and 16 failures, with request identity, card/profile key, result/status, expected/actual byte counts and SHA. Never retain response bodies. A later successful preview cannot erase the failure evidence.

The controlled regression also tests actual HTTP503→HTTP200 recovery without reopening the inspector or calling request again. Only the fixture's private deadline is advanced so the suite need not wait 30 seconds; it first asserts the production cooldown remains 30,000ms. Removing the owner suppresses that retry.

## Inspector evidence must describe the drawn face

The old browser observation queried the shared art cache. Cache availability is not proof that the inspector drew those pixels. Canonical `CardFace.art_report()` now observes a snapshot captured only by `_draw`, with actual card identity, texture geometry, delivery state and `draw_count`. It never calls `ART.resolve`, `normalized()` or a network request. Changed/hidden identities remain unbound until their own draw. The shell must publish this actual face report and wait for its native-size ready pixels.

`tests/premium_face_art_observation.gd` passed **7 assertions**: even loading/measuring the real original leaves an undrawn face unbound; repeated observation has no cache/request side effects; changed and hidden identities cannot inherit old pixel claims. Graphical/browser tests separately establish the actual draw.

## Verification and remaining release gate

The post-fix transfer identity/recovery regression passes **18 assertions, 0 failures**. The unchanged full-art suite passed **609 assertions, 0 failures** and the preview-art suite passed **51 assertions, 0 failures**, including their original rejection cases and strict rejection of script/resource errors; the wrapper now also runs the new identity regression after its original exact server-log checks. The eight embedded Web-fetch guard tests remain unchanged and passed **8/8**.

Reproduction:

```sh
node --test tests/production_art_transport.test.cjs
bash tools/test_production_art_delivery.sh
bash tools/test_production_art_preview_delivery.sh
LP_NUM_THREADS=1 godot --headless --path . --script tests/premium_face_art_observation.gd
```

The HTTP wrapper explicitly ensures both immutable derivative caches with `--ensure-cache` before starting its loopback fixture. Existing valid files are reused without re-encoding and committed delivery metadata must remain byte-identical. The new identity script requires that actual fixture URL; it is not a URL-free standalone SceneTree test.

The native suites serve the actual committed-art derivatives over loopback and do not establish browser scheduling or physical iPhone behavior. A fresh Web export and strict Chromium/WebKit inspector, cancellation, corruption/redirect/limit, rotation and full-duel checks on the final integration commit remain required. Earlier native all-550 illustration evidence must not be presented as evidence for this Web cancellation boundary. No release or physical-device acceptance is asserted by this document.
