#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
mkdir -p work/combat
# Run separately from performance tests: MovieMaker is an offline recording workload.
godot --path . --audio-driver Dummy --resolution 1280x720 --write-movie work/combat/gameplay.avi --fixed-fps 30 --script tests/combat_capture.gd --quit-after 1800 > work/combat/movie.log 2>&1
if ! rg -q '^MOVIE: SIEG' work/combat/movie.log; then cat work/combat/movie.log; exit 1; fi
ffmpeg -y -loglevel error -i work/combat/gameplay.avi -c:v libx264 -preset fast -crf 21 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart work/combat/gameplay.mp4
