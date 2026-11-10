#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha/web work/xdg/{data,config,cache}
# Generated browsers, logs and previous builds must never become game assets.
touch work/.gdignore
if [[ -d node_modules ]]; then touch node_modules/.gdignore; fi
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
alpha_build_commit="$(git rev-parse HEAD)"
alpha_build_name="orafold-${alpha_build_commit:0:12}"
if ! "${GODOT_BIN:-godot}" --headless --path . --export-debug 'Alpha Web QA' "work/alpha/web/$alpha_build_name.html" > work/alpha/export.log 2>&1; then
  cat work/alpha/export.log
  exit 1
fi
mv "work/alpha/web/$alpha_build_name.html" work/alpha/web/index.html
"${GODOT_BIN:-godot}" --headless --main-pack "work/alpha/web/$alpha_build_name.pck" --script "$PWD/tools/alpha02_pack_inventory.gd" -- --reject-test-assets > work/alpha/package-inspection.log 2>&1
python3 - "$alpha_build_commit" <<'PY'
import json,sys,os
from pathlib import Path
Path('work/alpha/web/build-info.json').write_text(json.dumps({'commit':sys.argv[1],'version':'ORAFOLD Alpha 0.2','channel':os.environ.get('GITHUB_REF_NAME','isolated-test'),'rulesets':['legacy-34b3062','orafold-alpha-0.1']},indent=2))
PY
