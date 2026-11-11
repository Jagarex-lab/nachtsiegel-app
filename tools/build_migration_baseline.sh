#!/usr/bin/env bash
# Re-export the pinned, unchanged pre-production runtime for real browser upgrades.
set -euo pipefail
cd "$(dirname "$0")/.."
baseline_commit=2b8ea627853b29ac80a5fca2f1c7a00253f92666
mkdir -p work/production work/xdg/{data,config,cache}
touch work/.gdignore
# Keep the caller's template directory. CI installs official templates in the
# default data home; replacing it with the isolated test-save directory hides
# those templates and makes the pinned export fail before package inspection.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
if ! git cat-file -e "$baseline_commit^{commit}" 2>/dev/null; then
  git fetch --no-tags origin "$baseline_commit"
fi
baseline_root="$PWD"
baseline_source="$(mktemp -d "$PWD/work/production/.baseline-source.XXXXXX")"
baseline_stage="$(mktemp -d "$PWD/work/production/.baseline-web.XXXXXX")"
baseline_registered=0
cleanup_baseline() {
  if [[ "$baseline_registered" == 1 ]]; then git -C "$baseline_root" worktree remove --force "$baseline_source"; fi
  if [[ -d "$baseline_source" ]]; then rmdir "$baseline_source"; fi
  if [[ -d "$baseline_stage" ]]; then rm -rf -- "$baseline_stage"; fi
}
trap cleanup_baseline EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git worktree add --detach "$baseline_source" "$baseline_commit"
baseline_registered=1
if ! (
  cd "$baseline_source"
  test "$(git rev-parse HEAD)" = "$baseline_commit"
  tools/build_alpha.sh
) > work/production/baseline-export.log 2>&1; then
  cat work/production/baseline-export.log
  exit 1
fi
cp -a "$baseline_source/work/alpha/web/." "$baseline_stage/"
python3 - "$baseline_commit" "$baseline_stage" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[2]); info=json.loads((root/'build-info.json').read_text())
assert info['commit']==sys.argv[1]
assert (root/'index.html').is_file()
assert len(list(root.glob('*.pck')))==1 and len(list(root.glob('*.wasm')))==1
assert all(not p.is_symlink() for p in root.rglob('*'))
print('Pinned migration baseline exported:',info['commit'])
PY
# This directory is a generated test artifact, not a Pages publish location.
if [[ -d work/production/before-web ]]; then rm -rf work/production/before-web; fi
mv "$baseline_stage" work/production/before-web
