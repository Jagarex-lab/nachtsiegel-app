#!/usr/bin/env bash
# Inspect an existing exported artifact with no project source fallback.
set -euo pipefail
art_source_root="$(cd "$(dirname "$0")/.." && pwd)"
art_package_path="$(realpath "${1:?Pass the existing exported Web PCK path}")"
art_package_mode="${2:-web}"
[[ "$art_package_mode" == web || "$art_package_mode" == native ]]
test -s "$art_package_path"
art_godot_command="$(command -v "${GODOT_BIN:-godot}")"
mkdir -p "$art_source_root/work/production-art" "$art_source_root/work/xdg/"{data,config,cache}
touch "$art_source_root/work/.gdignore"
export XDG_DATA_HOME="$art_source_root/work/xdg/data" XDG_CONFIG_HOME="$art_source_root/work/xdg/config" XDG_CACHE_HOME="$art_source_root/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
art_isolated_dir="$(mktemp -d "$art_source_root/work/production-art/.pack-inspection.XXXXXX")"
trap 'rm -rf -- "$art_isolated_dir"' EXIT
(
  cd "$art_isolated_dir"
  art_mode_args=()
  if [[ "$art_package_mode" == native ]]; then art_mode_args+=(--native); fi
  timeout "${GODOT_TEST_TIMEOUT:-120s}" "$art_godot_command" --headless --path . --audio-driver Dummy --main-pack "$art_package_path" --script "$art_source_root/tools/production/art_export_inventory.gd" -- "${art_mode_args[@]}"
) > "$art_source_root/work/production-art/exported-art-package-$art_package_mode.log" 2>&1
python3 - "$art_source_root/work/production-art/exported-art-package-$art_package_mode.log" "$art_package_mode" <<'PY'
from pathlib import Path
import json,re,sys
text=Path(sys.argv[1]).read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'PRODUCTION ART EXPORTED: \d+ assertions, 0 failures',text)
rows=[json.loads(line) for line in text.splitlines() if line.startswith('{')]
assert len(rows)==1 and rows[0]['failures']==0 and rows[0]['actual_originals']==(rows[0]['declared_originals'] if sys.argv[2]=='native' else 0) and rows[0]['actual_previews']==(rows[0]['declared_originals'] if sys.argv[2]=='native' else 5) and not rows[0]['source_files_visible'] and rows[0]['mode']==sys.argv[2]
assert '.pack-inspection.' in rows[0]['process_working_directory']
PY
