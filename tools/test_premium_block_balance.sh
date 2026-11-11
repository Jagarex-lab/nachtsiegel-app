#!/usr/bin/env bash
# Real paired production matches; no GPU, deployment, or gameplay mutation.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/premium-balance work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
python3 tools/production/build_test_decks.py --check
python3 tools/production/build_starters.py --check
python3 -m unittest discover -s tools/premium -p test_block_composition.py -v
timeout "${BLOCK_EXPERIMENT_TIMEOUT:-1800}s" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tests/premium_block_balance.gd > work/premium-balance/run.log 2>&1
python3 - <<'PY'
import re
from pathlib import Path
text=Path('work/premium-balance/run.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M),text[-12000:]
assert re.search(r'PREMIUM BLOCK BALANCE: \d+ assertions, 0 failures; 224 actual matrix games \+ 8 fresh verification games',text),text[-12000:]
print(text[-4000:])
PY
python3 tools/premium/report_block_balance.py --check-sources --verify-rejections
