#!/usr/bin/env bash
# Actual loopback HTTP delivery: the exporter/source tree cannot fake success.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production-art work/xdg/{data,config,cache}
touch work/.gdignore
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
art_ready_file="$(mktemp "$PWD/work/production-art/.http-ready.XXXXXX")"
rm "$art_ready_file"
art_server_pid=""
cleanup_art_http() {
  if [[ -n "$art_server_pid" ]]; then kill "$art_server_pid" 2>/dev/null || true; wait "$art_server_pid" 2>/dev/null || true; fi
  rm -f "$art_ready_file"
}
trap cleanup_art_http EXIT
python3 tools/production/art_delivery_test_server.py --root "$PWD" --ready-file "$art_ready_file" --log-file "$PWD/work/production-art/preview-http-server.jsonl" > work/production-art/preview-http-server.log 2>&1 &
art_server_pid="$!"
art_base_url="$(python3 - "$art_ready_file" "$art_server_pid" <<'PY'
import json,os,sys,time
from pathlib import Path
ready=Path(sys.argv[1])
for _ in range(100):
    if ready.is_file():
        print(json.loads(ready.read_text())['url']);break
    os.kill(int(sys.argv[2]),0)
    time.sleep(.05)
else: raise RuntimeError('Actual local HTTP fixture failed to become ready')
PY
)"
timeout "${GODOT_TEST_TIMEOUT:-120s}" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tests/production_art_preview_delivery.gd -- "$art_base_url" > work/production-art/preview-http.log 2>&1
python3 - <<'PY'
import json,re
from pathlib import Path
text=Path('work/production-art/preview-http.log').read_text(); print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use', text, re.M)
assert re.search(r'PRODUCTION PREVIEW HTTP: \d+ assertions, 0 failures', text)
rows=[json.loads(line) for line in Path('work/production-art/preview-http-server.jsonl').read_text().splitlines()]
assert any(row.get('relative_url','').startswith('art/preview/') and row.get('actual_manifest_body') for row in rows)
assert sum(row.get('relative_url','').startswith('art/full/') for row in rows)==1, rows
assert any(row['route']=='redirect' and row['code']==302 for row in rows)
assert not any(row['route']=='ok' and row.get('relative_url','').startswith('art/full/') for row in rows), 'Redirect target was fetched'
print('ACTUAL PREVIEW SERVER: original compact WebPs, exact rejected response bodies, no followed redirects; priority/cancel assertions in native runtime')
PY
