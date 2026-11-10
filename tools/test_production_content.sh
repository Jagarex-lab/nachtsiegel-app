#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Authoring-only checks. This gate neither exports nor activates new cards.
node --test --test-concurrency=1 tests/production/*.test.cjs
python3 -m unittest discover -s tests/production -p 'test_*.py' -v
node tools/production/catalog_review.cjs --check
python3 tools/production/art_pipeline.py validate
python3 tools/production/art_pipeline.py report
