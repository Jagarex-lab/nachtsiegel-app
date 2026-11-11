#!/usr/bin/env bash
# Full real-kernel interaction/coverage sample; no GUI, alternate engine or rules.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production work/xdg/{data,config,cache}
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
export ORAFOLD_COVERAGE_SOURCE_COMMIT="$(git rev-parse HEAD)"
python3 tools/production/build_full_pool_decks.py --check
coverage_prefix="work/production/full-pool-coverage"
if [[ -e "$coverage_prefix.json" || -e "$coverage_prefix-journal.jsonl" ]]; then
  coverage_archive="work/production/full-pool-history/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$coverage_archive"
  for coverage_file in "$coverage_prefix.json" "$coverage_prefix-plan.json" "$coverage_prefix-journal.jsonl" "$coverage_prefix.log"; do
    [[ ! -f "$coverage_file" ]] || cp "$coverage_file" "$coverage_archive/"
  done
fi
coverage_engine_status=0
timeout "${FULL_POOL_TIMEOUT:-1800}s" nice -n 10 "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tests/production_full_pool_coverage.gd > "$coverage_prefix.log" 2>&1 || coverage_engine_status=$?
# Always preserve/report actual attempts after failure or an infrastructure stop.
# A flushed journal can recover completed attempts; missing cases remain unrun.
coverage_report_status=0
if [[ -f "$coverage_prefix.json" && -f "$coverage_prefix-plan.json" ]]; then
  nice -n 10 python3 tools/production/report_full_pool_coverage.py --source "$coverage_prefix.json" --plan "$coverage_prefix-plan.json" --journal "$coverage_prefix-journal.jsonl" --engine-log "$coverage_prefix.log" --engine-exit-code "$coverage_engine_status" --output-dir work/production/full-pool-report --verify-rejections || coverage_report_status=$?
else
  coverage_report_status=1
fi
python3 - "$coverage_prefix.log" <<'PY'
import re,sys
from pathlib import Path
text=Path(sys.argv[1]).read_text()
print(text[-5000:])
if re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M):
    raise SystemExit(1)
PY
if [[ "$coverage_engine_status" != 0 || "$coverage_report_status" != 0 ]]; then
  printf 'Full-pool sampler failed: engine=%s report=%s; preserve all planned/attempted/unrun evidence.\n' "$coverage_engine_status" "$coverage_report_status" >&2
  exit 1
fi
