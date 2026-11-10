#!/usr/bin/env bash
# Isolated economy checks. No active scenes, profiles or exports are changed.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p work/economy work/economy/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/economy/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/economy/xdg/config"
export XDG_CACHE_HOME="$PWD/work/economy/xdg/cache"
GODOT_BIN="${GODOT_BIN:-godot}"
"$GODOT_BIN" --headless --editor --import --path . --quit > work/economy/import.log 2>&1
python3 -m unittest discover -s tests -p 'economy*_test.py' -v
for suite in economy_config economy_core economy_ui; do
  timeout 180s "$GODOT_BIN" --headless --path . --script "tests/$suite.gd" > "work/economy/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
import re, sys
from pathlib import Path
s = Path('work/economy', sys.argv[1]+'.log').read_text()
print(s)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:', s, re.M), 'Godot errors in '+sys.argv[1]
assert re.search(r'ECONOMY .*: \d+ assertions, 0 failures', s), 'Missing test completion marker'
PY
done
git diff --check
