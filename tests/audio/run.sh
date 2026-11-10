#!/usr/bin/env bash
# Isolated opt-in runtime + real-asset tests; no gameplay suite or export changes.
set -euo pipefail
cd "$(dirname "$0")/../.."
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/orafold-audio-test-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/orafold-audio-test-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/orafold-audio-test-cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" work/audio
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --path . --import > work/audio/import.log 2>&1
"$GODOT_BIN" --headless --audio-driver Dummy --path . --script tests/audio/runtime_suite.gd 2>&1 | tee work/audio/runtime.log
"$GODOT_BIN" --headless --audio-driver Dummy --path . --script tests/audio/preview.gd 2>&1 | tee work/audio/preview.log
# A logged engine error or leaked audio resource is a failure even if assertions pass.
if rg -n '(^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked|resources still in use)' work/audio/runtime.log work/audio/preview.log; then
    exit 1
fi
python3 tests/audio/validate_assets.py --report work/audio/asset-results.json
