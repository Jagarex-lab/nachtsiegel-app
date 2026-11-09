#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha/web/media work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
alpha_build_commit="$(git rev-parse HEAD)"
alpha_build_name="orafold-${alpha_build_commit:0:12}"
"${GODOT_BIN:-godot}" --headless --path . --export-debug 'Alpha Web QA' "work/alpha/web/$alpha_build_name.html" > work/alpha/export.log 2>&1
mv "work/alpha/web/$alpha_build_name.html" work/alpha/web/index.html
cp docs/combat/gameplay.mp4 work/alpha/web/media/gameplay.mp4
python3 - "$alpha_build_commit" <<'PY'
import json,sys,os
from pathlib import Path
Path('work/alpha/web/build-info.json').write_text(json.dumps({'commit':sys.argv[1],'version':'ORAFOLD Alpha 0.1','channel':os.environ.get('GITHUB_REF_NAME','isolated-test'),'rulesets':['legacy-34b3062','orafold-alpha-0.1']},indent=2))
PY
