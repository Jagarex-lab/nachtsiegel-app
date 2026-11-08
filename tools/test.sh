#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --import --path . --quit > work/import-final.log 2>&1
"$GODOT_BIN" --headless --path . --script tests/rules.gd > work/rules-final.log 2>&1
if [[ -n "${DISPLAY:-}" ]]; then
  "$GODOT_BIN" --path . --audio-driver Dummy --resolution 1600x900 --script tests/input_layout.gd > work/input-layout-final.log 2>&1
  "$GODOT_BIN" --path . --audio-driver Dummy --resolution 1600x900 --script tests/visual.gd > work/visual-final.log 2>&1
else
  echo 'Render tests require DISPLAY (for example Xvfb :99 -screen 0 1600x1000x24 -ac).'
  exit 2
fi
if rg 'SCRIPT ERROR|^ERROR:|^FAIL:' work/{import,rules,input-layout,visual}-final.log; then
  exit 1
fi
rg 'assertions' work/{rules,input-layout}-final.log
