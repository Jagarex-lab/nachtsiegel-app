# NACHTSIEGEL delivery policy

The user has explicitly authorized this standing preference (2026-11-08): after
implementing and testing a playable web change, publish the tested build to the
existing GitHub Pages game at https://jagarex-lab.github.io/nachtsiegel-app/ and
provide that direct play URL. Do not stop at a source branch or downloadable QA
artifact, and do not ask again for routine publication to this same game URL.

Work on a development branch. Publish through `develop`, which is already allowed
by the existing Pages environment policy. After feature-branch QA passes, a
fast-forward integration into `develop` is authorized as part of delivering the
web game; keep `main` untouched. Run the required Godot, rule, GUI and browser
checks before deployment. Keep Pages deployment behind passing checks and verify
the live game afterwards. Use commit-specific asset filenames to avoid old
Safari caches. Preserve the existing game rules and five paths. Report native
platform limitations honestly; a browser deployment is not an App Store release.
