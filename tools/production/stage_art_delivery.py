#!/usr/bin/env python3
"""Validate and hardlink actual immutable full illustrations into a Web export."""
from __future__ import annotations
import argparse
import errno
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]

def checked_delivery_files(export: Path, manifest: dict) -> list[Path]:
    if manifest.get("schema_version") != 1 or manifest.get("profile") != "orafold-web-art-v1" or not isinstance(manifest.get("entries"), dict):
        raise ValueError("Invalid external illustration manifest")
    files = []
    for card_id, entry in manifest["entries"].items():
        sha = entry.get("web_sha256", "")
        if not re.fullmatch(r"[0-9a-f]{64}", sha) or entry.get("relative_url") != f"art/full/{sha}.webp":
            raise ValueError(f"Invalid hash/path binding: {card_id}")
        path = export / entry["relative_url"]
        if any(p.is_symlink() for p in [path, *path.parents] if p != export.parent):
            raise ValueError(f"Symlink illustration rejected: {card_id}")
        if not path.resolve().is_relative_to(export.resolve()) or not path.is_file():
            raise ValueError(f"Missing/external illustration: {card_id}")
        body = path.read_bytes()
        if len(body) != entry.get("bytes") or hashlib.sha256(body).hexdigest() != sha:
            raise ValueError(f"Illustration body/hash mismatch: {card_id}")
        files.append(path)
    actual = {path for path in (export / "art").rglob("*") if path.is_file() or path.is_symlink()}
    if actual != set(files): raise ValueError("Unexpected full-art export entries")
    return sorted(set(files))

def stage(destination: Path, root: Path = ROOT) -> dict:
    if not destination.is_dir() or destination.is_symlink(): raise ValueError("Existing real export directory required")
    source = root / "data/production/art_delivery.json"
    manifest = json.loads(source.read_text(encoding="utf-8"))
    output = destination / "art/full"
    if any(path.is_symlink() for path in [destination / "art", output, destination / "art-delivery.json"]): raise ValueError("Symlink illustration destination rejected")
    if (destination / "art-delivery.json").exists(): raise ValueError("Export already contains delivery metadata")
    output.mkdir(parents=True, exist_ok=True)
    for card_id, entry in manifest["entries"].items():
        sha = entry.get("web_sha256", "")
        if not re.fullmatch(r"[0-9a-f]{64}", sha) or entry.get("relative_url") != f"art/full/{sha}.webp": raise ValueError(f"Unsafe full-art URL: {card_id}")
        original = root / "work/art-delivery-cache" / (sha + ".webp")
        if original.is_symlink() or not original.is_file(): raise ValueError(f"Missing safe encoded illustration: {card_id}")
        body = original.read_bytes()
        if len(body) != entry["bytes"] or hashlib.sha256(body).hexdigest() != sha: raise ValueError(f"Stale encoded illustration: {card_id}")
        target = output / original.name
        if target.exists() or target.is_symlink(): raise ValueError(f"Export already contains illustration: {card_id}")
        try: target.hardlink_to(original)
        except OSError as error:
            if error.errno != errno.EXDEV: raise
            shutil.copyfile(original, target)
    (destination / "art-delivery.json").write_bytes(source.read_bytes())
    checked = checked_delivery_files(destination, manifest)
    return {"full_assets": len(checked), "full_bytes": sum(p.stat().st_size for p in checked), "delivery": "relative same-origin URLs; originals excluded from Web PCK"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("destination", type=Path)
    print(json.dumps(stage(parser.parse_args().destination), ensure_ascii=False))
