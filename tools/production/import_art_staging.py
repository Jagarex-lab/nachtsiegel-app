#!/usr/bin/env python3
"""Import a complete reviewed illustration staging area without rewriting pixels.

Run only after the external collector reports ready_for_bulk_import=true. This
imports actual PNG hardlinks and provenance, never card definitions or lore.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from art_manifest import png_info

ROOT = Path(__file__).resolve().parents[2]


def atomic_write(path: Path, body: bytes) -> None:
    descriptor, name = tempfile.mkstemp(dir=path.parent, prefix=".art-import-")
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(body); stream.flush(); os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if Path(name).exists(): Path(name).unlink()


def original_import_profile(card_id: str) -> bytes:
    path = f"res://assets/cards/originals/{card_id}.png"
    imported = f"res://.godot/imported/{card_id}.png-{hashlib.md5(path.encode()).hexdigest()}.ctex"
    # Godot fills its own resource UID/defaults during the real editor import.
    # This applies the existing profile before that first import can create a
    # large lossless default. Original native PNG bytes remain unmodified.
    return f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{"vram_texture": false}}
[deps]
source_file="{path}"
dest_files=["{imported}"]
[params]
compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
process/size_limit=0
'''.encode()


def import_staging(staging: Path, root: Path = ROOT, check_only: bool = False) -> dict:
    if staging.is_symlink() or not staging.is_dir(): raise ValueError("Real staging directory required")
    status = json.loads((staging / "staging_status.json").read_text())
    if status.get("ready_for_bulk_import") is not True or status.get("accepted_originals") != 550 or status.get("final_visual_originals") != 550:
        raise ValueError("Staging is incomplete or not finally visually reviewed")
    source = staging / "art_sources.json"
    imported = json.loads(source.read_text())
    entries = imported.get("entries")
    cards = json.loads((root / "data/production/cards.json").read_text())["cards"]
    cards_by_id = {card["id"]: card for card in cards}
    if len(cards_by_id) != 550 or not isinstance(entries, dict) or set(entries) != set(cards_by_id):
        raise ValueError("Staging must match all 550 current card identities exactly")
    source_dir = staging / "assets/cards/originals"
    target_dir = root / "assets/cards/originals"
    if source_dir.is_symlink() or target_dir.is_symlink() or not target_dir.is_dir():
        raise ValueError("Original directories cannot be symlinks")
    files = []
    digests = set()
    powers = collections.Counter()
    existing = 0
    for card_id, entry in sorted(entries.items()):
        card = cards_by_id[card_id]
        if not re.fullmatch(r"[a-z0-9-]+", card_id) or entry.get("asset_path") != f"res://assets/cards/originals/{card_id}.png":
            raise ValueError("Invalid immutable original path: " + card_id)
        if entry.get("card_id", card_id) != card_id or entry.get("name") != card["name"] or entry.get("power") != card["faction"]:
            raise ValueError("Illustration identity/name/power mismatch: " + card_id)
        if entry.get("status") != "final" or entry.get("production_review") != "approved" or entry.get("individual_original") is not True:
            raise ValueError("Unapproved original: " + card_id)
        for field in ["source_prompt", "creator_or_generator", "creation_date", "alternative_text", "commercial_review", "reference_sources"]:
            if field not in entry: raise ValueError("Missing provenance: " + card_id + "/" + field)
        original = source_dir / (card_id + ".png")
        target = target_dir / original.name
        if original.is_symlink() or not original.is_file() or target.is_symlink() or target.with_name(target.name + ".import").is_symlink():
            raise ValueError("Unsafe original/profile file: " + card_id)
        if type(entry.get("commercially_cleared")) is not bool or not isinstance(entry.get("reference_sources"), list):
            raise ValueError("Explicit legal/provenance field types required: " + card_id)
        width, height, digest = png_info(original)
        if (width, height) != (entry.get("original_width"), entry.get("original_height")) or digest != entry.get("sha256") or width < 1024 or height < 768:
            raise ValueError("Original PNG/dimensions/hash do not match: " + card_id)
        if digest in digests: raise ValueError("Duplicate individual image bytes: " + card_id)
        digests.add(digest); powers[card["faction"]] += 1
        if target.exists():
            if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
                raise ValueError("Refusing to overwrite a different existing original: " + card_id)
            existing += 1
        if original.stat().st_dev != target_dir.stat().st_dev:
            raise ValueError("Bulk import requires same-filesystem hardlinks, not silent PNG copies")
        files.append((original, target, card_id))
    if powers != {power:110 for power in ("houses", "stillwatch", "morph", "ninth", "neutral")}:
        raise ValueError("Each identity requires exactly110 real originals")
    disk_ids = {path.stem for path in source_dir.glob("*.png")}
    if disk_ids != set(entries): raise ValueError("Staging original directory has missing/orphan files")
    if not check_only:
        for original, target, card_id in files:
            if not target.exists(): target.hardlink_to(original)
            profile = target.with_name(target.name + ".import")
            if not profile.exists(): atomic_write(profile, original_import_profile(card_id))
        # Preserve the full actual author records including rejected/edit traces;
        # neither visual nor commercial status is promoted by this importer.
        atomic_write(root / "data/production/art_sources.json", source.read_bytes())
        for old, new in [("source_map.json", "art_source_map.json"), ("rejection_trace.json", "art_rejection_trace.json")]:
            path = staging / old
            if path.exists(): atomic_write(root / "data/production" / new, path.read_bytes())
    return {"checked":550,"already_present":existing,"new_hardlinks":0 if check_only else 550-existing,"per_power":dict(powers),"source_metadata_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"check_only":check_only,"pixels_rewritten":0,"commercially_cleared":sum(entry.get("commercially_cleared") is True for entry in entries.values())}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    parser.add_argument("--check", action="store_true", help="Verify every actual PNG and target without changing files")
    args = parser.parse_args()
    print(json.dumps(import_staging(args.staging, check_only=args.check), indent=2))
