#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
timeout "${PRODUCTION_FINISHER_TIMEOUT:-600}s" "${GODOT_BIN:-godot}" --headless --path . --script tests/production_ai_finishers.gd > work/production/ai-finishers.log 2>&1
python3 - <<'PY'
import re
from pathlib import Path
text=Path('work/production/ai-finishers.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',text,re.M),text
assert re.search(r'PRODUCTION FINISHERS: \d+ assertions; 0 failures; 9 actual production matches',text),text
print(text)
PY
