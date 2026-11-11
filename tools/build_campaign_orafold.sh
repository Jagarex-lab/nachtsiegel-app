#!/usr/bin/env bash
# Isolated QA export. This script never changes the source project or publishes.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/campaign_orafold work/xdg/{data,config,cache}
touch work/.gdignore
campaign_stage="$(mktemp -d "$PWD/work/campaign_orafold/.project.XXXXXX")"
campaign_candidate="$(mktemp -d "$PWD/work/campaign_orafold/.web.XXXXXX")"
campaign_target="$PWD/work/campaign_orafold/web"
trap 'rm -rf -- "$campaign_stage" "$campaign_candidate"' EXIT
campaign_web_template="${CAMPAIGN_WEB_TEMPLATE:-}"
# CI setup-godot installs templates in the ordinary user data directory.
# Resolve that installed Web template before isolating generated QA user data.
if [[ -z "$campaign_web_template" && -f "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.6.3.stable/web_nothreads_debug.zip" ]]; then
  campaign_web_template="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.6.3.stable/web_nothreads_debug.zip"
fi
export XDG_DATA_HOME="${XDG_DATA_HOME:-$PWD/work/xdg/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$PWD/work/xdg/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$PWD/work/xdg/cache}"
python3 - "$campaign_stage" "$campaign_web_template" <<'PY'
from pathlib import Path
import json,shutil,sys
stage=Path(sys.argv[1]); source=Path.cwd()
for name in ('assets','data','scripts','scenes','web'):
    shutil.copytree(source/name,stage/name)
project=(source/'project.godot').read_text()
old='run/main_scene="res://scenes/alpha_shell.tscn"'
assert project.count(old)==1, 'Main scene changed; review staging setup before exporting.'
project=project.replace(old,'run/main_scene="res://scenes/campaign_orafold/campaign_overview.tscn"',1)
(stage/'project.godot').write_text(project)
template=Path(sys.argv[2]).resolve() if sys.argv[2] else None
if template:
    assert template.is_file(),f'Missing custom Web template: {template}'
    assert template.name != 'web_debug.zip', 'Threaded web_debug.zip is incompatible; use official web_nothreads_debug.zip.'
custom='custom_template/debug='+json.dumps(str(template) if template else '')+'\n'
(stage/'export_presets.cfg').write_text('''[preset.0]
name="Campaign Web QA"
platform="Web"
runnable=false
custom_features="campaign_orafold_qa"
export_filter="all_resources"
include_filter="data/campaign_orafold/*.json,data/campaign_orafold/locales/*.json,data/brand/*.json,data/narrative/*.json,data/narrative/locales/*.json,data/campaign/*.json,data/legacy/*.json,data/alpha/*.json,data/card_system/*.json"
exclude_filter="work/*,tests/*,docs/*,tools/*,node_modules/*,.git/*"
script_export_mode=2

[preset.0.options]
'''+custom+'''variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/resize_canvas_on_start=true
html/custom_html_shell="res://web/shell.html"
html/canvas_resize_policy=2
html/experimental_virtual_keyboard=true
progressive_web_app/enabled=false
''')
assert json.loads((stage/'data/campaign_orafold/prototype.json').read_text())['default_campaign']=='prototype'
PY
if ! "${GODOT_BIN:-godot}" --headless --editor --import --path "$campaign_stage" --quit > work/campaign_orafold/web-import.log 2>&1; then
  cat work/campaign_orafold/web-import.log
  exit 1
fi
if ! "${GODOT_BIN:-godot}" --headless --path "$campaign_stage" --export-debug 'Campaign Web QA' "$campaign_candidate/index.html" > work/campaign_orafold/web-export.log 2>&1; then
  cat work/campaign_orafold/web-export.log
  exit 1
fi
for campaign_ext in html js wasm pck; do test -s "$campaign_candidate/index.$campaign_ext"; done
python3 - "$campaign_candidate" <<'PY'
import json,subprocess,sys
from pathlib import Path
Path(sys.argv[1],'build-info.json').write_text(json.dumps({
 'commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
 'channel':'isolated-campaign-qa','source_scene':'res://scenes/campaign_orafold/campaign_overview.tscn',
 'production_release':False,'main_story_approved':False},indent=2)+'\n')
PY
# Only replace a generated local QA directory after a complete export exists.
if [[ -e "$campaign_target" ]]; then
  test -d "$campaign_target" && test ! -L "$campaign_target"
  rm -rf -- "$campaign_target"
fi
mv "$campaign_candidate" "$campaign_target"
campaign_candidate=""
printf 'Isolated campaign Web QA export: %s\n' "$campaign_target"
