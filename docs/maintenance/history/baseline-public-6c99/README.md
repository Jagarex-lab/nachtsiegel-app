# Actual public baseline verification — 6c99dfc

These copied records and three actual screenshots belong only to published baseline `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`, verified on 2026-11-18. The JSON asserts and this copy checks that the browser build-info uses that exact commit and records zero errors. The extra real-public Chromium Android-viewport session completed a full AI duel, replay and restart. It was browser emulation, not a physical device. The screenshots are actual browser captures, not mockups.

The ordinary publisher's public Chromium/WebKit menu and executable-byte integrity receipt is [artifact 14403288321](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44250211904/artifacts/14403288321). The additional full-duel/replay/restart proof here is a local recorded session also described in [PR #30](https://github.com/Jagarex-lab/nachtsiegel-app/pull/30); no external Actions artifact for that extra session is claimed.

The first two local attempts failed **before gameplay**: direct requests lacked the required existing proxy (`ENETUNREACH` / `ECONNREFUSED`); the next attempt met `ERR_CERT_AUTHORITY_INVALID` because Chromium's legacy NSS lacked the already-system-trusted managed proxy CA. `environment-attempts.json` retains these outcomes. TLS verification was not disabled. A temporary trust adjustment used that existing managed CA and the original environment was restored and independently checked; no private NSS database/keys are archived. These environment failures are not erased by the final pass.

`driver-provenance.json` was captured during preparation and still says “Prepared only”; the later `final-public-proof.json` and browser-result file record execution. Its pinned source/blob mapping remains provenance, not a separate test result.

**This baseline pass does not validate the new maintenance PR/head or its eventual merge.** That commit is unknown inside its own content. Fresh exact-head CI, fresh post-merge seven-suite/29-job QA, publication and public receipt must be linked in the maintenance PR's final comment and authoritative live `release-evidence.json` / `build-info.json` after they actually exist.
