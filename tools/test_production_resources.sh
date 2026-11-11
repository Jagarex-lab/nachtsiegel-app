#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
timeout "${RESOURCE_TEST_TIMEOUT:-900}s" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tests/production_resource_models.gd > work/production/resource-models.log 2>&1
python3 - <<'PY'
import json,re
from pathlib import Path
log=Path('work/production/resource-models.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',log,re.M),log
r=json.loads(Path('work/production/resource-models.json').read_text())
assert r['failures']==0 and r['matrix_games']==192 and len(r['games'])==192 and r['additional_verification_games']==10 and r['pre_seam_default_comparisons']==64
assert all(not g['error'] and not g['censored'] and g['winner'] in ('hero','enemy','draw') for g in r['games'])
assert re.search(r'\d+ assertions; 0 failures',log),log
print(log)
PY
