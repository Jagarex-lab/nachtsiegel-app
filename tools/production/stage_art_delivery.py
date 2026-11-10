#!/usr/bin/env python3
"""Validate and hardlink immutable full/preview derivatives into a Web export."""
from __future__ import annotations
import argparse
import errno
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]


def external_entries(manifest: dict, preview: bool = False) -> dict:
    profile = "orafold-web-preview-v1" if preview else "orafold-web-art-v1"
    if manifest.get("schema_version") != 1 or manifest.get("profile") != profile or not isinstance(manifest.get("entries"), dict) or len(manifest["entries"]) > 550:
        raise ValueError("Invalid external illustration manifest")
    entries = manifest["entries"]
    if preview:
        pinned = manifest.get("pinned_card_ids")
        if not isinstance(pinned, list) or len(pinned) != 5 or len(set(pinned)) != 5 or manifest.get("resource_kind") != "compact_preview":
            raise ValueError("Invalid data-only pinned preview metadata")
        packed = {card_id for card_id, entry in entries.items() if entry.get("delivery") == "packed"}
        if packed != set(pinned): raise ValueError("Pinned preview entries disagree")
        common = {"delivery", "asset_path", "source_sha256", "preview_sha256", "width", "height"}
        for card_id, entry in entries.items():
            allowed = common | ({"web_sha256", "relative_url", "bytes"} if entry.get("delivery") == "external" else set())
            if set(entry) != allowed or entry.get("delivery") not in {"packed", "external"}:
                raise ValueError("Preview entries contain non-data/unknown fields")
            if not re.fullmatch(r"[a-z0-9-]+", card_id) or entry.get("asset_path") != f"res://assets/cards/previews/{card_id}.png":
                raise ValueError("Unsafe logical preview path")
            if any(not re.fullmatch(r"[0-9a-f]{64}", str(entry.get(field, ""))) for field in ("source_sha256", "preview_sha256")):
                raise ValueError("Invalid preview provenance binding")
            if any(type(entry.get(field)) is not int or not 1 <= entry[field] <= 512 for field in ("width", "height")) or max(entry["width"], entry["height"]) != 512:
                raise ValueError("Invalid actual preview dimensions")
        entries = {card_id: entry for card_id, entry in entries.items() if entry["delivery"] == "external"}
        if manifest.get("preview_count") != len(manifest["entries"]) or manifest.get("external_preview_count") != len(entries):
            raise ValueError("Preview counts disagree")
    folder, maximum = ("preview", 1024 * 1024) if preview else ("full", 8 * 1024 * 1024)
    for card_id, entry in entries.items():
        sha = entry.get("web_sha256", "")
        if not re.fullmatch(r"[0-9a-f]{64}", sha) or entry.get("relative_url") != f"art/{folder}/{sha}.webp":
            raise ValueError(f"Invalid hash/path binding: {card_id}")
        if type(entry.get("bytes")) is not int or not 1 <= entry["bytes"] <= maximum:
            raise ValueError(f"Invalid encoded image length: {card_id}")
    return entries


def checked_delivery_files(export: Path, manifest: dict, previews: dict | None = None) -> list[Path]:
    groups = [external_entries(manifest)]
    if previews is not None: groups.append(external_entries(previews, True))
    files = []
    for entries in groups:
        for card_id, entry in entries.items():
            path = export / entry["relative_url"]
            if any(parent.is_symlink() for parent in [path, *path.parents] if parent != export.parent):
                raise ValueError(f"Symlink illustration rejected: {card_id}")
            if not path.resolve().is_relative_to(export.resolve()) or not path.is_file():
                raise ValueError(f"Missing/external illustration: {card_id}")
            body = path.read_bytes()
            if len(body) != entry["bytes"] or hashlib.sha256(body).hexdigest() != entry["web_sha256"]:
                raise ValueError(f"Illustration body/hash mismatch: {card_id}")
            files.append(path)
    actual = {path for path in (export / "art").rglob("*") if path.is_file() or path.is_symlink()}
    if actual != set(files): raise ValueError("Unexpected external-art export entries")
    return sorted(set(files))


def stage(destination: Path, root: Path = ROOT) -> dict:
    if not destination.is_dir() or destination.is_symlink(): raise ValueError("Existing real export directory required")
    source = root / "data/production/art_delivery.json"
    manifest = json.loads(source.read_text(encoding="utf-8"))
    preview_source = root / "data/production/art_preview_delivery.json"
    previews = json.loads(preview_source.read_text(encoding="utf-8")) if preview_source.exists() else None
    groups = [(external_entries(manifest), root / "work/art-delivery-cache")]
    if previews is not None: groups.append((external_entries(previews, True), root / "work/art-preview-delivery-cache"))
    destinations = [destination / "art", destination / "art/full", destination / "art/preview", destination / "art-delivery.json", destination / "art-preview-delivery.json"]
    if any(path.is_symlink() for path in destinations): raise ValueError("Symlink illustration destination rejected")
    if any((destination / name).exists() for name in ("art-delivery.json", "art-preview-delivery.json")): raise ValueError("Export already contains delivery metadata")
    created = set()
    for entries, cache in groups:
        for card_id, entry in entries.items():
            original = cache / (entry["web_sha256"] + ".webp")
            if any(path.is_symlink() for path in [original, cache]) or not original.is_file(): raise ValueError(f"Missing safe encoded illustration: {card_id}")
            body = original.read_bytes()
            if len(body) != entry["bytes"] or hashlib.sha256(body).hexdigest() != entry["web_sha256"]: raise ValueError(f"Stale encoded illustration: {card_id}")
            target = destination / entry["relative_url"]
            if target in created: continue
            if target.exists() or target.is_symlink(): raise ValueError(f"Export already contains illustration: {card_id}")
            target.parent.mkdir(parents=True, exist_ok=True)
            try: target.hardlink_to(original)
            except OSError as error:
                if error.errno != errno.EXDEV: raise
                shutil.copyfile(original, target)
            created.add(target)
    (destination / "art-delivery.json").write_bytes(source.read_bytes())
    if previews is not None: (destination / "art-preview-delivery.json").write_bytes(preview_source.read_bytes())
    checked = checked_delivery_files(destination, manifest, previews)
    full = [path for path in checked if path.parent.name == "full"]
    compact = [path for path in checked if path.parent.name == "preview"]
    return {"full_assets": len(full), "full_bytes": sum(path.stat().st_size for path in full), "preview_assets": len(compact), "preview_bytes": sum(path.stat().st_size for path in compact), "delivery": "relative same-origin full/visible-preview URLs; native sources unchanged"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("destination", type=Path)
    print(json.dumps(stage(parser.parse_args().destination), ensure_ascii=False))
