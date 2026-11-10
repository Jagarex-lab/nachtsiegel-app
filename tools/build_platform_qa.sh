#!/usr/bin/env bash
# Local debug exports only. This script cannot publish or sign a store release.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production/platforms work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
repo_dir="$PWD"
out="$PWD/work/production/platforms"
mkdir -p "$out/isolated-resource-root"
"${GODOT_BIN:-godot}" --headless --path . --export-debug 'Linux QA' "$out/orafold-preview.x86_64" > "$out/linux-export.log" 2>&1
(
  cd "$out/isolated-resource-root"
  timeout 300 "$out/orafold-preview.x86_64" --headless --path . --audio-driver Dummy --script "$repo_dir/tests/production_exported.gd"
) > "$out/linux-runtime.log" 2>&1
"${GODOT_BIN:-godot}" --headless --path . --export-debug 'Android QA' "$out/orafold-preview.apk" > "$out/android-export.log" 2>&1
# Paths can be supplied by any installed, appropriate Android SDK.
android_build_tools="${ANDROID_BUILD_TOOLS:-$PWD/work/tools/android-sdk/build-tools/35.0.0}"
"$android_build_tools/apksigner" verify --verbose "$out/orafold-preview.apk" > "$out/android-signature.log" 2>&1
"$android_build_tools/aapt" dump badging "$out/orafold-preview.apk" > "$out/android-badging.log"
python3 - <<'PY'
import hashlib,json,re,subprocess
from pathlib import Path
root=Path('work/production/platforms')
log=(root/'linux-runtime.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',log,re.M),log
summary=next(json.loads(line) for line in log.splitlines() if line.startswith('{'))
assert summary['suite']=='production_exported' and summary['assertions']>0 and summary['failures']==0
badging=(root/'android-badging.log').read_text()
assert 'com.jagarex.nachtsiegel' in badging and "application-label:'ORAFOLD'" in badging
sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in root.iterdir() if p.suffix in ['.apk','.x86_64']}
report={'commit':sha,'builds':files,'linux_exported_duel':summary,'android_debug_signature_verified':True,'android_device_tested':False,'physical_iphone_tested':False,'ios_native_build':'not-built: Apple Xcode/signing environment unavailable on Linux'}
(root/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
PY
