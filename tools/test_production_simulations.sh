#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
python3 tools/production/build_test_decks.py --check
printf '%s\n' 'Running complete real-kernel production simulation matrix...'
timeout "${PRODUCTION_SIM_TIMEOUT:-1800}s" "${GODOT_BIN:-godot}" --headless --path . --script tests/production_simulations.gd -- "$@" > work/production/simulations.log 2>&1
python3 - <<'PY'
import json,re
from pathlib import Path
text=Path('work/production/simulations.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',text,re.M),text[-12000:]
assert re.search(r'PRODUCTION SIMULATIONS: \d+ assertions; 0 failures;',text),text[-12000:]
report=json.loads(Path('work/production/simulations.json').read_text())
assert report['failures']==0 and report['matrix_games']==report['expected_matrix_games']>0
assert len(report['games'])==report['matrix_games']
assert report['summary']['errors']==0 and report['summary']['censored']==0
print(text[-12000:])
PY
