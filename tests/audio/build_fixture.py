#!/usr/bin/env python3
"""Stage a disposable audio-only Godot project; never edit the product project.

Run: python3 tests/audio/build_fixture.py
Then import/export work/audio/fixture with Godot and matching export templates.
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "work/audio/fixture"
DEST.mkdir(parents=True, exist_ok=True)
for rel in ("scripts/audio", "data/audio"):
    target = DEST / rel
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(ROOT / rel, target, ignore=shutil.ignore_patterns("*.py", "__pycache__"))
for name in ("music", "ambience", "ui", "cards", "combat", "resonance", "relics", "factions"):
    target = DEST / "assets/audio" / name
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(ROOT / "assets/audio" / name, target)
for path in (ROOT / "tests/audio/web_fixture").iterdir():
    if path.is_file():
        shutil.copy2(path, DEST / path.name)
(DEST / "build/web").mkdir(parents=True, exist_ok=True)
print(DEST)
