#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
node --test tests/alpha_data.test.cjs
for suite in alpha_rules alpha_replay; do
  timeout 180s "${GODOT_BIN:-godot}" --headless --path . --script "tests/$suite.gd" > "work/alpha/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
import re,sys
from pathlib import Path
s=Path('work/alpha',sys.argv[1]+'.log').read_text();print(s)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',s,re.M)
assert re.search(r'ALPHA (RULES|REPLAY): \d+ assertions, 0 failures;',s)
PY
done
"${GODOT_BIN:-godot}" --path . --audio-driver Dummy --script tests/alpha_ui.gd > work/alpha/alpha_ui.log 2>&1
python3 - <<'PY'
import re
from pathlib import Path
s=Path('work/alpha/alpha_ui.log').read_text();print(s)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',s,re.M)
assert re.search(r'ALPHA UI: \d+ assertions, 0 failures;',s)
PY
