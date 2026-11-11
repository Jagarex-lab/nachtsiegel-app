#!/usr/bin/env bash
# New illustration/preview/cache tests supplement the regular production gate.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/production-art work/xdg/{data,config,cache}
touch work/.gdignore
export XDG_DATA_HOME="$PWD/work/xdg/data" XDG_CONFIG_HOME="$PWD/work/xdg/config" XDG_CACHE_HOME="$PWD/work/xdg/cache"
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
python3 tools/production/art_manifest.py --check
python3 -m unittest discover -s tests -p production_art_manifest_test.py -v
python3 -m unittest discover -s tests -p production_art_delivery_package_test.py -v
node --test tests/production_art_transport.test.cjs
timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tools/production/prepare_art_delivery.gd -- --check > work/production-art/prepare_art_delivery.log 2>&1
python3 - <<'PY'
from pathlib import Path
import re
text=Path('work/production-art/prepare_art_delivery.log').read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'PRODUCTION ART DELIVERY DATA: \d+ assertions, 0 failures',text)
PY
python3 -m unittest discover -s tests -p production_art_http_fixture_test.py -v
bash tools/test_production_art_delivery.sh
bash tools/test_production_art_preview_delivery.sh
timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tools/production/prepare_preview_delivery.gd -- --check > work/production-art/prepare_preview_delivery.log 2>&1
python3 - <<'PY'
from pathlib import Path
import re
text=Path('work/production-art/prepare_preview_delivery.log').read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'PRODUCTION PREVIEW DELIVERY DATA: \d+ assertions, 0 failures',text)
PY
timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" --headless --path . --audio-driver Dummy --script tools/production/prepare_art_previews.gd -- --check > work/production-art/prepare_art_previews.log 2>&1
python3 - <<'PY'
from pathlib import Path
import re
text=Path('work/production-art/prepare_art_previews.log').read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'PRODUCTION ART PREVIEWS: \d+ assertions, 0 failures',text)
PY
for suite in production_art_batch2 production_art_cache production_art_visibility; do
  timeout "${GODOT_TEST_TIMEOUT:-600s}" "${GODOT_BIN:-godot}" --path . --audio-driver Dummy --script "tests/$suite.gd" > "work/production-art/$suite.log" 2>&1
  python3 - "$suite" <<'PY'
from pathlib import Path
import re,sys
text=Path('work/production-art',sys.argv[1]+'.log').read_text();print(text)
assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use',text,re.M)
assert re.search(r'\d+ assertions, 0 failures',text)
PY
done
