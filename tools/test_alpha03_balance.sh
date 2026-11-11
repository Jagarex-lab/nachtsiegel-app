#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha03 work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
timeout "${GODOT_TEST_TIMEOUT:-1200s}" "${GODOT_BIN:-godot}" --headless --path . --script tests/alpha03_balance.gd > work/alpha03/balance-fresh.log 2>&1
python3 - <<'PY'
from pathlib import Path
import re
s=Path('work/alpha03/balance-fresh.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',s,re.M),s
assert re.search(r'ALPHA03 BALANCE: \d+ assertions, 0 failures; 56 fresh matrix \+ 4 replay games',s),s
print(s)
PY
python3 -m unittest discover -s tests -p 'alpha03_balance_report_test.py' -v
python3 tools/alpha03/report_balance.py
