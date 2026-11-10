# ORAFOLD audio tests

Run from the repository root:

```sh
bash tests/audio/run.sh
```

Requires Godot 4, Python 3 with numpy, ffmpeg/ffprobe, and ripgrep. The runner uses writable temporary XDG directories, imports the Godot project, and writes results under ignored `work/audio/`. Set `GODOT_BIN` to select the installed Godot executable. The runtime's own save files use unique test names and are removed after each successful run.

- `runtime_suite.gd` uses shipped WAV/Ogg streams with Godot's Dummy audio driver, exercises all 52 event names, failure handling, variants, layer identities, pool pressure, volume buses, persistence, strict browser mirror decoding, explicit streaming backends, streamed music fades and background suspension. Tests use wall time for event cooldowns because Godot timer delta and wall time can differ in a fast headless session.
- `preview.gd` tests the opt-in settings panel and preview scene.
- `validate_assets.py` decodes every catalogued file through ffmpeg and checks references, provenance hashes, clipping, durations, signal bounds, storage and PCM budgets. Periodic loops are checked for continuity between their last and first decoded samples. Their arbitrary phase is permitted; the runtime fades loop startup and shutdown. One-shots must start and end near silence.
- `browser_smoke.mjs` and `web_fixture/` provide the separately documented isolated browser test; see `docs/audio/AUDIO-QA.md` for export and invocation details.

A nonzero assertion result or a logged Godot script/engine error fails the runner. Results in `docs/audio/evidence/` are an archived run, not a substitute for rerunning tests after changes. Dummy-driver timing and buffer limits are host measurements; they do not prove target-device latency, audible quality or physical mobile compatibility.
