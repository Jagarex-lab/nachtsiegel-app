#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/legacy work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
node tools/legacy/generate.cjs --check
node --test tests/legacy_foundations.test.cjs
"${GODOT_BIN:-godot}" --headless --path . --script tests/legacy_foundations.gd --quit-after 600 > work/legacy/godot.log 2>&1
python3 - <<'PY'
from pathlib import Path
import re
log=Path('work/legacy/godot.log').read_text()
print(log.strip())
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',log,re.M), 'Godot error in legacy test'
assert re.search(r'^LEGACY FOUNDATIONS: \d+ assertions, 0 failures;',log,re.M), 'Missing successful legacy test summary'
PY
