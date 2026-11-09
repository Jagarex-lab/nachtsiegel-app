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
  mkdir -p work/ux
  "$GODOT_BIN" --path . --audio-driver Dummy --resolution 1280x720 --script tests/ux_audit.gd > work/ux-final.log 2>&1
  python3 tools/contrast_report.py > work/contrast-final.log 2>&1
else
  echo 'Render tests require DISPLAY (for example Xvfb :99 -screen 0 1600x1000x24 -ac).'
  exit 2
fi
python3 - <<'VERIFY'
from pathlib import Path
import re
for name in ["import", "rules", "input-layout", "visual", "ux", "contrast"]:
    path = Path("work", name + "-final.log")
    content = path.read_text()
    if re.search(r"SCRIPT ERROR|^ERROR:|^FAIL:", content, re.MULTILINE):
        raise SystemExit("Godot errors in " + str(path))
    if name in ["rules", "input-layout", "ux"]:
        result = re.search(r"^.*assertions, 0 failures.*$", content, re.MULTILINE)
        if not result:
            raise SystemExit("Missing successful test summary in " + str(path))
        print(result.group())
    if name == "contrast":
        print(content.strip())
VERIFY
