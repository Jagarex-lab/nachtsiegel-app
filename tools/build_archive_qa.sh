#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha/archive-web/media work/xdg/{data,config,cache}
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
archive_commit="$(git rev-parse HEAD)"
archive_name="archive-${archive_commit:0:12}"
if ! "${GODOT_BIN:-godot}" --headless --path . --export-debug 'Web QA' "work/alpha/archive-web/$archive_name.html" > work/alpha/archive-export.log 2>&1; then
  cat work/alpha/archive-export.log
  exit 1
fi
mv "work/alpha/archive-web/$archive_name.html" work/alpha/archive-web/index.html
cp docs/combat/gameplay.mp4 work/alpha/archive-web/media/gameplay.mp4
python3 - "$archive_commit" <<'PY'
import json,sys
from pathlib import Path
Path('work/alpha/archive-web/build-info.json').write_text(json.dumps({'commit':sys.argv[1],'channel':'archive-regression'}))
PY
