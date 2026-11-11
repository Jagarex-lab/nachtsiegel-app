#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/campaign_orafold/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/campaign_orafold/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/campaign_orafold/xdg/config"
export XDG_CACHE_HOME="$PWD/work/campaign_orafold/xdg/cache"
export GODOT_SILENCE_ROOT_WARNING=1
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
# Import only; no project settings, release workflow or productive scene mutations.
if [[ "${CAMPAIGN_SKIP_IMPORT:-0}" != 1 ]]; then
  timeout 180s "${GODOT_BIN:-godot}" --headless --path . --editor --import > work/campaign_orafold/import.log 2>&1
fi
for suite in validator runtime battle layout presentation; do
  timeout 420s "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script "tests/campaign_orafold/$suite.gd" > "work/campaign_orafold/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
import re,sys
from pathlib import Path
suite=sys.argv[1]
text=Path('work/campaign_orafold',suite+'.log').read_text()
print(text,end='')
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:',text,re.M), text
marker='CAMPAIGN BATTLE' if suite=='battle' else 'ORAFOLD '+suite.upper()
assert re.search(marker+r': \d+ assertions, 0 failures;',text), text
PY
done
node --check tools/campaign_orafold_browser_qa.cjs
python3 tools/campaign_orafold/verify_integration.py
