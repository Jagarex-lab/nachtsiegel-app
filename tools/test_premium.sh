#!/usr/bin/env bash
# Complete presentation gate. No release build, deployment or rule mutations.
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 0 )); then
  printf '%s\n' 'Usage: tools/test_premium.sh' >&2
  exit 2
fi
mkdir -p work/premium-mobile/logs work/premium-mobile/native-xdg/{data,config,cache}
touch work/.gdignore
export XDG_DATA_HOME="$PWD/work/premium-mobile/native-xdg/data"
export XDG_CONFIG_HOME="$PWD/work/premium-mobile/native-xdg/config"
export XDG_CACHE_HOME="$PWD/work/premium-mobile/native-xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
premium_godot="${GODOT_BIN:-godot}"
for source in tools/premium/browser_contract.cjs tools/premium/campaign_header_contract.cjs tools/premium/campaign_header_browser_qa.cjs tools/premium/browser_qa.cjs tools/alpha_browser_qa.cjs tools/release/public_integrity.cjs tools/release/public_probe.cjs; do node --check "$source"; done
node --test tests/premium/browser_contract.test.cjs tests/premium/campaign_header_contract.test.cjs tests/release/public_integrity.test.cjs tools/premium/test_pwa.cjs tools/premium/test_worker.cjs
python3 -m unittest discover -s tools/premium -p test_stage_pwa.py -v
python3 -Werror::ResourceWarning -m unittest discover -s tests/release -v
premium_run() {
  local label="$1" marker="$2"
  shift 2
  local log="work/premium-mobile/logs/$label.log"
  if timeout "${GODOT_TEST_TIMEOUT:-600s}" "$@" > "$log" 2>&1; then
    cat "$log"
  else
    local result=$?
    cat "$log"
    return "$result"
  fi
  python3 - "$log" "$marker" <<'PYLOG'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use|RID allocations|Leaked instance', text, re.M | re.I), text
assert re.search(sys.argv[2], text), 'Missing actual successful completion: ' + sys.argv[1]
PYLOG
}
for suite in premium_card_frames premium_face_art_observation premium_battle_layout premium_battle_geometry premium_battle_text premium_drag_cancel premium_primary_input premium_scroll_input premium_arena_geometry; do
  premium_run "$suite" '[1-9][0-9]* (assertions|checks), 0 failures' "$premium_godot" --headless --path . --audio-driver Dummy --script "tests/$suite.gd"
done
for suite in test_duel_checkpoint test_library_geometry; do
  premium_run "$suite" '[1-9][0-9]* assertions, 0 failures' "$premium_godot" --headless --path . --audio-driver Dummy --script "tools/premium/$suite.gd"
done
premium_run card-concepts 'PREMIUM CARD CONCEPTS: 3 actual Godot concepts' "$premium_godot" --path . --audio-driver Dummy --script tools/premium/render_card_concepts.gd
premium_run illustration-chain 'PREMIUM ART CHAIN: [1-9][0-9]* assertions, 0 failures' "$premium_godot" --path . --audio-driver Dummy --script tests/premium_illustration_chain.gd
premium_run presentation 'PREMIUM PRESENTATION: 9 actual Shell captures' "$premium_godot" --path . --audio-driver Dummy --script tools/premium/render_arena_qa.gd -- --output=res://work/premium-mobile/after
python3 tools/premium/run_arena_comparison.py --godot "$premium_godot" --out "$PWD/work/premium-mobile/spatial"
git diff --check
printf '%s\n' 'PREMIUM PRESENTATION GATE: all required contracts and actual native renders passed; browser tests run separately'
