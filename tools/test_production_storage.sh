#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production-storage/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/production-storage/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/production-storage/xdg/config"
export XDG_CACHE_HOME="$PWD/work/production-storage/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
node --test tests/production_storage_mirror.test.cjs
args=()
if [[ "${PRODUCTION_STORAGE_FOCUSED:-0}" == "1" ]]; then args+=(-- --focused); fi
timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" --headless --path . --script tests/production_storage.gd "${args[@]}" > work/production-storage/native.log 2>&1
python3 - <<'PY'
import json, os, re
from pathlib import Path
text = Path('work/production-storage/native.log').read_text()
print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use', text, re.M)
rows = [json.loads(line) for line in text.splitlines() if line.startswith('{')]
result = next(row for row in rows if row.get('suite') == 'production_storage')
assert result['assertions'] > 0 and result['failures'] == 0
if os.environ.get('PRODUCTION_STORAGE_FOCUSED') == '1':
    assert result['production_deferred'] is True and result['production_games'] == 0
else:
    assert result['production_deferred'] is False and result['production_games'] == 4
PY
