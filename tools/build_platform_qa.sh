#!/usr/bin/env bash
# Local debug exports only. This script cannot publish or sign a store release.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production/platforms work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
out="$PWD/work/production/platforms"
mkdir -p "$out/isolated-resource-root"
python3 - <<'PY'
import hashlib,json
from pathlib import Path
paths=[Path('project.godot'),Path('export_presets.cfg')]
for folder in ['scripts','scenes','data','assets']:
    paths.extend(p for p in Path(folder).rglob('*') if p.is_file())
Path('work/production/platforms/source-before.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)},indent=2)+'\n')
PY
"${GODOT_BIN:-godot}" --headless --path . --export-debug 'Linux QA' "$out/orafold-preview.x86_64" > "$out/linux-export.log" 2>&1
# Neither --path nor --script is supported by the official exported template.
# Check the regular game's actual startup, then export an explicit QA-only entry
# scene that runs a real duel using the same packed game resources and kernel.
(
  cd "$out/isolated-resource-root"
  timeout 60 "$out/orafold-preview.x86_64" --headless --audio-driver Dummy --quit-after 120
) > "$out/linux-startup.log" 2>&1
"${GODOT_BIN:-godot}" --headless --path . --export-debug 'Linux Runtime QA' "$out/orafold-runtime-qa.x86_64" > "$out/linux-runtime-export.log" 2>&1
(
  cd "$out/isolated-resource-root"
  timeout 300 "$out/orafold-runtime-qa.x86_64" --headless --audio-driver Dummy
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
startup=(root/'linux-startup.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',startup,re.M),startup
log=(root/'linux-runtime.log').read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',log,re.M),log
summary=next(json.loads(line) for line in log.splitlines() if line.startswith('{'))
assert summary['suite']=='production_native_exported' and summary['assertions']>0 and summary['failures']==0
badging=(root/'android-badging.log').read_text()
assert 'com.jagarex.nachtsiegel' in badging and "application-label:'ORAFOLD'" in badging
sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
sources=json.loads((root/'source-before.json').read_text())
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==digest for p,digest in sources.items()),'Source changed during platform exports'
status=subprocess.check_output(['git','status','--porcelain'],text=True).splitlines()
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in root.iterdir() if p.suffix in ['.apk','.x86_64']}
report={'commit':sha,'working_tree_status':status,'source_sha256':sources,'builds':files,'linux_regular_startup':True,'linux_exported_duel':summary,'android_debug_signature_verified':True,'android_device_tested':False,'physical_iphone_tested':False,'ios_native_build':'not-built: Apple Xcode/signing environment unavailable on Linux'}
(root/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='source_sha256'},indent=2))
PY
