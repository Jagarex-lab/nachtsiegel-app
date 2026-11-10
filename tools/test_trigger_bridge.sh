#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/trigger-bridge work/alpha work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
# Headless only: this package has no scene/UI integration or browser claims.
for suite in card_system_trigger_bridge card_system_runtime alpha_rules alpha_replay; do
  timeout "${TRIGGER_TEST_TIMEOUT:-300s}" "${GODOT_BIN:-godot}" --headless --path . --script "tests/$suite.gd" > "work/trigger-bridge/$suite.log" 2>&1
  python3 - "$suite" <<'PYCHECK'
import json,re,sys
from pathlib import Path
name=sys.argv[1]
text=Path('work/trigger-bridge', name+'.log').read_text()
print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M),text
rows=[]
for line in text.splitlines():
    if line.startswith('{'):
        try:rows.append(json.loads(line))
        except json.JSONDecodeError:pass
assert re.search(r'\d+ assertions, 0 failures',text) or any(row.get('assertions',0)>0 and row.get('failures')==0 for row in rows), 'Missing actual successful test summary'
PYCHECK
done
