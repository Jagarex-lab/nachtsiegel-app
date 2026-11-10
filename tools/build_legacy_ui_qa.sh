#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha/legacy-web work/xdg/{data,config,cache}
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
archive_commit="$(git rev-parse HEAD)"
archive_name="legacy-${archive_commit:0:12}"
if ! "${GODOT_BIN:-godot}" --headless --path . --export-debug 'Legacy UI QA' "work/alpha/legacy-web/$archive_name.html" > work/alpha/legacy-export.log 2>&1; then
  cat work/alpha/legacy-export.log
  exit 1
fi
mv "work/alpha/legacy-web/$archive_name.html" work/alpha/legacy-web/index.html
python3 - "$archive_commit" <<'PY'
import json,sys
from pathlib import Path
Path('work/alpha/legacy-web/build-info.json').write_text(json.dumps({'commit':sys.argv[1],'channel':'legacy-ui-regression'}))
PY
