#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/master550 work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
timeout "${RESOURCE_TEST_TIMEOUT:-600}s" "${GODOT_BIN:-godot}" --headless --path . --script tests/master550_resources.gd > work/master550/resources.log 2>&1
python3 - <<'PYCHECK'
import json,re
from pathlib import Path
log=Path('work/master550/resources.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',log,re.M),log
assert re.search(r'\d+ assertions; 0 failures',log),log
report=json.loads(Path('work/master550/resource_experiments.json').read_text())
assert report.get('assertions',0)>0 and report.get('failures')==0, report
assert report.get('matrix_games')==192 and report.get('additional_verification_games')==7, report
assert len(report.get('games',[]))==192, 'Incomplete matrix evidence'
print(log)
PYCHECK
