#!/usr/bin/env bash
# Required Alpha 0.3 integration gate. Tests remain local; nothing is published.
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 0 )); then
  printf '%s\n' 'Usage: tools/test_alpha03.sh (runs every integration suite)' >&2
  exit 2
fi

mkdir -p work/alpha03/xdg/{data,config,cache}
touch work/.gdignore
export XDG_DATA_HOME="$PWD/work/alpha03/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/alpha03/xdg/config"
export XDG_CACHE_HOME="$PWD/work/alpha03/xdg/cache"
export GODOT_SILENCE_ROOT_WARNING=1
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
export ORAFOLD_GODOT_DIAGNOSTICS="$PWD/work/alpha03/online-worker.log"
rm -f -- "$ORAFOLD_GODOT_DIAGNOSTICS"
GODOT_BIN="${GODOT_BIN:-godot}"
export GODOT_BIN
export ORAFOLD_GODOT_BIN="$GODOT_BIN"
online_started=0

check_log() {
  python3 - "$1" "${2:-}" <<'PYALPHA03LOG'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
errors = re.compile(
    r"SCRIPT ERROR|^ERROR:|^FAIL:|ObjectDB instances leaked|"
    r"resources still in use at exit|RID allocations|Leaked instance",
    re.MULTILINE | re.IGNORECASE,
)
assert not errors.search(text), f"Runtime error or leak in {path}:\n{text}"
if sys.argv[2]:
    assert re.search(sys.argv[2], text, re.MULTILINE), f"Missing completion marker in {path}:\n{text}"
if "TAP version 13" in text:
    for summary in (r"^# tests [1-9][0-9]*$", r"^# fail 0$", r"^# cancelled 0$", r"^# skipped 0$"):
        assert re.search(summary, text, re.MULTILINE), f"Incomplete, skipped or failing Node tests in {path}:\n{text}"
PYALPHA03LOG
}

run_checked() {
  local label="$1" marker="$2" result=0
  shift 2
  local log="work/alpha03/$label.log"
  if "$@" > "$log" 2>&1; then result=0; else result=$?; fi
  cat "$log"
  check_log "$log" "$marker"
  if (( result != 0 )); then
    printf '%s failed with exit code %s\n' "$label" "$result" >&2
    return "$result"
  fi
}

cleanup() {
  local result=$? cleanup_result=0
  trap - EXIT
  if (( online_started )); then
    if timeout 45s python3 scripts/online/godot_bridge.py --project "$PWD" --godot "$GODOT_BIN" --stop > work/alpha03/online-shutdown.log 2>&1; then
      cleanup_result=0
    else
      cleanup_result=$?
    fi
    cat work/alpha03/online-shutdown.log
    if ! check_log work/alpha03/online-shutdown.log; then cleanup_result=1; fi
    if [[ -f "$ORAFOLD_GODOT_DIAGNOSTICS" ]]; then
      cat "$ORAFOLD_GODOT_DIAGNOSTICS"
      if ! check_log "$ORAFOLD_GODOT_DIAGNOSTICS"; then cleanup_result=1; fi
    elif (( result == 0 )); then
      printf '%s\n' 'Missing production online worker diagnostics' >&2
      cleanup_result=1
    fi
  fi
  if (( result == 0 && cleanup_result != 0 )); then result=$cleanup_result; fi
  exit "$result"
}
trap cleanup EXIT

node -e "const [major,minor]=process.versions.node.split('.').map(Number); if(major!==24||minor<13)throw Error('Online integration requires Node >=24.13 <25')"
"$GODOT_BIN" --version | python3 -c 'import sys; version=sys.stdin.read().strip(); assert version.startswith("4.6.3."), version; print(version)'
run_checked online-runner-contract 'Ran [1-9][0-9]* tests? in [^\n]+\n\nOK$' \
  timeout 30s python3 tests/alpha03_runner_contract_test.py

# Only import can be reused from an already prepared immutable CI/local cache.
# No test suite can be skipped by this runner.
if [[ "${ALPHA03_SKIP_IMPORT:-0}" != 1 ]]; then
  run_checked import '' timeout 300s "$GODOT_BIN" --headless --editor --import --path . --audio-driver Dummy --quit
fi

run_checked economy-python 'Ran [1-9][0-9]* tests? in [^\n]+\n\nOK$' timeout 180s python3 -m unittest discover -s tests -p 'economy*_test.py' -v
for suite in economy_config economy_core economy_alpha550 economy_ui; do
  run_checked "$suite" 'ECONOMY [A-Z0-9 ]+: [1-9][0-9]* assertions, 0 failures' \
    timeout 240s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script "tests/$suite.gd"
done
export CHROMIUM_BIN="${CHROMIUM_BIN:-$(node -e "process.stdout.write(require('playwright').chromium.executablePath())")}"
run_checked economy-browser '^# pass [1-9][0-9]*$' timeout 180s node --test --test-reporter=tap tests/economy_web_storage.test.cjs

run_checked campaign 'ORAFOLD PRESENTATION: [1-9][0-9]* assertions, 0 failures' \
  env CAMPAIGN_SKIP_IMPORT=1 bash tools/test_campaign_orafold.sh
for suite in validator runtime battle layout presentation; do
  check_log "work/campaign_orafold/$suite.log"
done

run_checked online-install '' timeout 300s npm --prefix server ci
run_checked online-typecheck '' timeout 180s npm --prefix server run typecheck
run_checked online-schema '' timeout 180s npm --prefix server run schema
run_checked online-schema-pinned '' git diff --exit-code -- shared/schemas/client-message-v1.schema.json
online_started=1
run_checked online-server '^# pass [1-9][0-9]*$' \
  env NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--test-reporter=tap" timeout 1500s npm --prefix server test
# The short fixture checks transport only. `demo` aliases the full production
# duel and can legitimately exceed180s as its cryptorandom match seed varies.
run_checked online-demo-fixture '' timeout 180s npm --prefix server run demo:transport
run_checked online-demo-fixture-parser 'ONLINE TRANSPORT FIXTURE: completed; simulation-only' \
  timeout 30s python3 tools/alpha03/check_online_demo.py transport work/alpha03/online-demo-fixture.log
run_checked online-production-duel '"simulation": false' timeout 900s npm --prefix server run demo:duel
run_checked online-production-duel-parser 'ONLINE PRODUCTION DUEL: completed; actual Godot rules' \
  timeout 30s python3 tools/alpha03/check_online_demo.py production work/alpha03/online-production-duel.log
run_checked online-security-audit '' timeout 180s npm --prefix server audit --omit=dev --audit-level=high
run_checked online-client 'ONLINE CLIENT: [1-9][0-9]* assertions, 0 failures' \
  timeout 180s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script tests/online_client.gd
git show 345edb6e683d4359b8141ef228683c0855773ac2:scripts/alpha/model.gd > work/alpha03/alpha-before-online.gd
run_checked offline-draw-seam 'OFFLINE_DRAW_SEAM_PASS [1-9][0-9]* identical accepted boundaries across 8 seeds' \
  timeout 240s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script scripts/online/check_offline_draw_seam.gd -- "$PWD/work/alpha03/alpha-before-online.gd"

run_checked orientation 'ALPHA03 ORIENTATION: [1-9][0-9]* assertions, 0 failures' \
  timeout 180s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script tests/alpha03_orientation.gd
run_checked online-layout 'ONLINE_LOBBY_LAYOUT_PASS' \
  timeout 180s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script tests/online_lobby_layout.gd
run_checked application 'ALPHA03 APPLICATION: [1-9][0-9]* assertions, 0 failures' \
  timeout 240s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script tests/alpha03_application.gd
run_checked match-rewards 'ALPHA03 MATCH REWARDS: [1-9][0-9]* assertions, 0 failures' \
  timeout 300s "$GODOT_BIN" --headless --path . --audio-driver Dummy --script tests/alpha03_match_rewards.gd

git diff --check
printf '%s\n' 'ALPHA03 INTEGRATION: all required suites passed; worker shutdown diagnostics follow'
