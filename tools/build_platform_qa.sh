#!/usr/bin/env bash
# Debug builds and evidence only. No publication or store-signing credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
export LP_NUM_THREADS="${LP_NUM_THREADS:-2}"
python3 tools/platform_qa.py "$@"
