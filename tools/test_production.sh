#!/usr/bin/env bash
# Freeze source files before running this gate; every missing suite is a failure.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
python3 tools/production/build_catalog.py --check
python3 tools/production/build_starters.py --check
python3 tools/production/build_test_decks.py --check
python3 tools/production/validate_catalog.py
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p 'production_*_test.py' -v
python3 -m unittest discover -s tools/production -p 'test_catalog.py' -v
for suite in production_engine production_mobile_metrics production_ai_policy production_art_pipeline production_card_text_layout production_ui production_short_landscape production_burst_ui; do
  args=(--headless)
  if [[ "$suite" == production_ui || "$suite" == production_art_pipeline || "$suite" == production_card_text_layout || "$suite" == production_short_landscape || "$suite" == production_burst_ui ]]; then args=(); fi
  timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" "${args[@]}" --path . --audio-driver Dummy --script "tests/$suite.gd" > "work/production/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
import json,re,sys
from pathlib import Path
log=Path('work/production',sys.argv[1]+'.log').read_text();print(log)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',log,re.M)
rows=[]
for line in log.splitlines():
    if line.startswith('{'):
        try:rows.append(json.loads(line))
        except json.JSONDecodeError:pass
assert re.search(r'\d+ assertions[,;]\s*0 failures',log) or any(r.get('assertions',0)>0 and r.get('failures')==0 for r in rows),'Missing successful actual test summary'
PY
done
tools/test_production_finishers.sh
tools/test_production_storage.sh
