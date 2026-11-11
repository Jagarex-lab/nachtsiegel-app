#!/usr/bin/env bash
# Actual loopback HTTP delivery: the exporter/source tree cannot fake success.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production-art work/xdg/{data,config,cache}
touch work/.gdignore
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
# Each standalone suite needs both groups: the strict fixture eagerly validates
# full and preview bodies. --ensure-cache preserves committed metadata; the
# surrounding source --check gates remain separate and unchanged.
python3 - <<'PYCACHE'
import os
from pathlib import Path
from tools.production.art_delivery_test_server import ensure_caches
ensure_caches(Path.cwd(), Path('work/production-art/delivery-http'), os.environ.get('GODOT_BIN','godot'), os.environ.get('GODOT_CACHE_TIMEOUT','600s'))
PYCACHE
art_ready_file="$(mktemp "$PWD/work/production-art/.http-ready.XXXXXX")"
rm "$art_ready_file"
art_server_pid=""
cleanup_art_http() {
  if [[ -n "$art_server_pid" ]]; then kill "$art_server_pid" 2>/dev/null || true; wait "$art_server_pid" 2>/dev/null || true; fi
  rm -f "$art_ready_file"
}
trap cleanup_art_http EXIT
python3 tools/production/art_delivery_test_server.py --root "$PWD" --ready-file "$art_ready_file" --log-file "$PWD/work/production-art/delivery-http-server.jsonl" > work/production-art/delivery-http-server.log 2>&1 &
art_server_pid="$!"
art_wait_status=0
art_base_url="$(python3 tools/production/art_delivery_test_server.py --root "$PWD" --ready-file "$art_ready_file" --log-file "$PWD/work/production-art/delivery-http-server.jsonl" --wait-pid "$art_server_pid" --ready-timeout "${ART_HTTP_READY_TIMEOUT:-60}")" || art_wait_status=$?
if (( art_wait_status != 0 )); then
  # Reap the actual child and expose its original failure, rather than ending
  # at a secondary os.kill/JSON error with the server traceback hidden.
  art_terminate_status=0
  if kill -0 "$art_server_pid" 2>/dev/null; then kill "$art_server_pid" 2>/dev/null || art_terminate_status=$?; fi
  art_server_status=0
  wait "$art_server_pid" || art_server_status=$?
  art_server_pid=""
  printf 'HTTP fixture readiness failed: waiter exit=%s; actual server exit=%s; terminate exit=%s\n' "$art_wait_status" "$art_server_status" "$art_terminate_status" >&2
  cat work/production-art/delivery-http-server.log >&2
  exit "$art_wait_status"
fi
art_test_status=0
timeout "${GODOT_TEST_TIMEOUT:-120s}" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tests/production_art_delivery.gd -- "$art_base_url" > work/production-art/delivery-http.log 2>&1 || art_test_status=$?
if (( art_test_status != 0 )); then
  printf 'Actual Godot HTTP suite failed: exit=%s\n' "$art_test_status" >&2
  cat work/production-art/delivery-http.log work/production-art/delivery-http-server.log >&2
  exit "$art_test_status"
fi
python3 - <<'PY'
from collections import Counter
import json,re
from pathlib import Path
text=Path('work/production-art/delivery-http.log').read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'PRODUCTION ART HTTP DELIVERY: \d+ assertions, 0 failures',text)
rows=[json.loads(line) for line in Path('work/production-art/delivery-http-server.jsonl').read_text().splitlines()]
assert Counter(row['route'] for row in rows)=={'ok':1,'missing':1,'hash':1,'dimensions':1,'redirect':1,'disconnect':1,'oversized':1,'slow':5},rows
assert all(row['actual_manifest_body'] for row in rows if row['route'] in {'ok','dimensions','slow'})
assert all(not row['actual_manifest_body'] for row in rows if row['route']=='hash')
assert next(row for row in rows if row['route']=='missing')['code']==404
assert next(row for row in rows if row['route']=='redirect')['code']==302
assert next(row for row in rows if row['route']=='disconnect')['code']==0
assert next(row for row in rows if row['route']=='oversized')['bytes']>8*1024*1024
result=json.loads(Path('work/production-art/delivery-http-result.json').read_text())
assert result['failures']==0 and result['http_success']==6
print('ACTUAL HTTP SERVER: 6 verified-source body successes; 404, same-length corruption, geometry, redirect, connection-close and 8 MiB limit rejection; no compact requests')
PY
