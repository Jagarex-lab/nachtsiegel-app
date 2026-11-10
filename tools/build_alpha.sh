#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/alpha work/xdg/{data,config,cache}
# Generated browsers, logs and previous builds must never become game assets.
touch work/.gdignore
if [[ -d node_modules ]]; then touch node_modules/.gdignore; fi
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
alpha_build_commit="$(git rev-parse HEAD)"
alpha_build_name="orafold-${alpha_build_commit:0:12}"
alpha_target_dir="$PWD/work/alpha/web"
alpha_stage_dir="$(mktemp -d "$PWD/work/alpha/.web-staging.XXXXXX")"
alpha_backup_dir=""
cleanup_alpha_export() {
  # Restore the last verified directory if the final local rename was interrupted.
  if [[ -n "$alpha_backup_dir" && -d "$alpha_backup_dir/web" ]]; then
    if [[ ! -e "$alpha_target_dir" ]]; then
      if ! mv "$alpha_backup_dir/web" "$alpha_target_dir"; then
        printf 'Previous verified build retained at %s\n' "$alpha_backup_dir/web" >&2
        return 1
      fi
    fi
    rm -rf -- "$alpha_backup_dir"
  fi
  if [[ -n "$alpha_stage_dir" && -d "$alpha_stage_dir" ]]; then rm -rf -- "$alpha_stage_dir"; fi
}
trap cleanup_alpha_export EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! "${GODOT_BIN:-godot}" --headless --path . --export-debug 'Alpha Web QA' "$alpha_stage_dir/$alpha_build_name.html" > work/alpha/export.log 2>&1; then
  cat work/alpha/export.log
  exit 1
fi
mv "$alpha_stage_dir/$alpha_build_name.html" "$alpha_stage_dir/index.html"
for alpha_extension in pck wasm js; do test -s "$alpha_stage_dir/$alpha_build_name.$alpha_extension"; done
"${GODOT_BIN:-godot}" --headless --main-pack "$alpha_stage_dir/$alpha_build_name.pck" --script "$PWD/tools/alpha02_pack_inventory.gd" -- --reject-test-assets > work/alpha/package-inspection.log 2>&1
python3 - "$alpha_build_commit" "$alpha_stage_dir" <<'PY'
import json,sys,os
from pathlib import Path
Path(sys.argv[2], 'build-info.json').write_text(json.dumps({'commit':sys.argv[1],'version':'ORAFOLD Alpha 0.3 – Katalogvorschau','channel':os.environ.get('GITHUB_REF_NAME','isolated-test'),'rulesets':['legacy-34b3062','orafold-alpha-0.1','production-550-v1']},indent=2))
PY
# Publish only the verified local candidate. Repeated exports cannot accumulate
# old commit-addressed .pck/.wasm files or accidentally serve a partial rebuild.
if [[ -e "$alpha_target_dir" ]]; then
  test -d "$alpha_target_dir" && test ! -L "$alpha_target_dir"
  alpha_backup_dir="$(mktemp -d "$PWD/work/alpha/.web-previous.XXXXXX")"
  mv "$alpha_target_dir" "$alpha_backup_dir/web"
fi
mv "$alpha_stage_dir" "$alpha_target_dir"
alpha_stage_dir=""
