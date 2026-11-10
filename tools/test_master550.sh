#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/master550 work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
node --test tests/alpha_card_texts.test.cjs tests/card_system/*.test.cjs
node tools/alpha_card_texts.cjs --check
node tools/card_system/schema.cjs --check
node tools/card_system/assets.cjs --check
node tools/card_system/validate.cjs
for suite in card_system_runtime master550_card_visual master550_opening_ui; do
  "${GODOT_BIN:-godot}" --path . --audio-driver Dummy --script "tests/$suite.gd" > "work/master550/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
import json,re,sys
from pathlib import Path
s=Path('work/master550',sys.argv[1]+'.log').read_text();print(s)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',s,re.M)
rows=[]
for line in s.splitlines():
    if line.startswith('{'):
        try: rows.append(json.loads(line))
        except json.JSONDecodeError: pass
assert re.search(r'\d+ assertions, 0 failures',s) or any(r.get('assertions',0)>0 and r.get('failures')==0 for r in rows), 'Missing successful real test summary'
PY
done
