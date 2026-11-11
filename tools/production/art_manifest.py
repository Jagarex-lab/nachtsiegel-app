#!/usr/bin/env python3
"""Build/check illustration-only production inventory; never generate fake images.

Uses only the standard library so the same strict check can run in normal CI.
Each present PNG is CRC checked, decompressed with a size ceiling and bound to
its original dimensions/hash. Missing illustrations stay explicit missing rows.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[2]
PALETTES = {
    "houses": "Kupfer, Elfenbein, stumpfes Wachs; Erinnerungen als materielle Spuren",
    "stillwatch": "Eisblau, Silber, tiefes Glas; ruhige stabile Formen",
    "morph": "Jadegrün, Bernstein, organische Übergänge; Anpassung statt formloser Masse",
    "ninth": "Amethyst, Silber, kosmische Geometrie; klare zeitliche Verschiebungen",
    "neutral": "Graphit, Stahl, mineralische Akzente; keine dominante Machtfarbe",
}
SPECIES = {
    "human": "Menschen", "beast": "Bestien", "spirit": "Geister",
    "construct": "Konstrukte", "plant": "Pflanzen", "amalgam": "Amalgame",
    "morphid": "Morphiden", "paradox": "Paradoxe", "revenant": "Wiedergänger",
    "elemental": "Elementare", "devourer": "Zehrer", "mechanoid": "Mechanoide",
}
STYLE = "Eigenständige malerische Dark Fantasy mit präzisem Fokus, zurückhaltender Raumfalten-Geometrie, glaubhaften Materialien und Licht von oben links. Keine Referenz auf bestehende Spielefiguren."
EXCLUSIONS = "Nur Illustration: keine Schrift, Zahlen, Kartenrahmen, Logos, Wasserzeichen oder UI. Keine Enthüllung zu Eira, neuen Fraktionsführer oder verbindlichen Weltursprung erfinden."


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def png_info(path: Path) -> tuple[int, int, str]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {path}")
    offset, dimensions, pixels, ended = 8, None, bytearray(), False
    while offset < len(data):
        if offset + 12 > len(data): raise ValueError(f"Truncated PNG: {path}")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        tag = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data): raise ValueError(f"Truncated PNG chunk: {path}")
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack(">I", data[offset + 8 + length:end])[0]
        if zlib.crc32(tag + payload) & 0xffffffff != crc:
            raise ValueError(f"PNG CRC mismatch: {path}")
        if tag == b"IHDR":
            if dimensions is not None or length != 13 or offset != 8: raise ValueError("Invalid PNG header")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if not 1 <= width <= 4096 or not 1 <= height <= 4096 or width * height > 4096 * 4096:
                raise ValueError("Illustration exceeds source pixel limit")
            if depth != 8 or color not in [2, 6] or compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError("Original pipeline requires non-interlaced RGB/RGBA8 PNG")
            dimensions = (width, height, 3 if color == 2 else 4)
        elif tag == b"IDAT": pixels.extend(payload)
        elif tag == b"IEND":
            if length or end != len(data): raise ValueError("Trailing PNG data")
            ended = True; break
        offset = end
    if dimensions is None or not ended or not pixels: raise ValueError("Incomplete PNG")
    width, height, channels = dimensions
    expected = (width * channels + 1) * height
    decoder = zlib.decompressobj()
    raw = decoder.decompress(pixels, expected + 1)
    if len(raw) != expected or not decoder.eof or decoder.unused_data:
        raise ValueError("Invalid/truncated PNG pixel stream")
    if any(raw[row * (width * channels + 1)] > 4 for row in range(height)):
        raise ValueError("Invalid PNG row filter")
    return width, height, hashlib.sha256(data).hexdigest()


def checked_asset(root: Path, asset: str, directory: str = "originals") -> Path:
    if directory not in ["originals", "previews"]:
        raise ValueError("Unknown illustration directory")
    if not asset.startswith(f"res://assets/cards/{directory}/") or not asset.endswith(".png"):
        raise ValueError(f"Original path outside illustration directory: {asset}")
    relative = asset.removeprefix("res://")
    if any(token in relative for token in ["..", "\\", "%", ":", "//"]):
        raise ValueError(f"Unsafe asset path: {asset}")
    path = root / relative
    if any(part.is_symlink() for part in [path, *path.parents] if part != root.parent):
        raise ValueError(f"Symlink artwork rejected: {asset}")
    if not path.resolve().is_relative_to((root / f"assets/cards/{directory}").resolve()):
        raise ValueError(f"Asset escapes original directory: {asset}")
    return path


def validate_edit_provenance(source: dict, root: Path = ROOT) -> None:
    """Accept the two recorded generation formats without rewriting history.

    Edit inputs are project-generated drafts, never unidentified third-party
    references. Their portable archive is build evidence, not a runtime asset.
    """
    def require(ok: bool, message: str) -> None:
        if not ok: raise ValueError("Invalid edit provenance: " + message)

    def substantial(value, minimum: int = 1) -> bool:
        return isinstance(value, str) and len(value.strip()) >= minimum

    edits = source.get("edits", [])
    require(isinstance(edits, list), "edits must be a list")
    references = source.get("reference_sources")
    require(isinstance(references, list), "reference_sources must be a list")
    inputs = source.get("generation_inputs", [])
    require(isinstance(inputs, list), "generation_inputs must be a list")
    if not edits:
        require(not references and not inputs, "an input requires its edit record")
        return

    stream_format = False
    for edit in edits:
        require(isinstance(edit, dict), "edit must be an object")
        if set(edit) == {"method", "date", "instruction"}:
            require(edit["method"] == "OpenAI Image Generation", "unknown method")
            require(isinstance(edit["date"], str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", edit["date"]) is not None, "missing edit date")
            require(substantial(edit["instruction"], 100), "missing edit instruction")
            require(bool(references), "method format requires its archived reference")
        elif set(edit) == {"tool", "prompt", "reason", "review"}:
            stream_format = True
            require(edit["tool"] == "OpenAI image generation tool", "unknown tool")
            require(substantial(edit["prompt"], 100), "missing edit prompt")
            require(substantial(edit["reason"]) and substantial(edit["review"]), "missing edit reason/review")
            require(bool(inputs), "tool format requires its original generation input")
        else:
            raise ValueError("Invalid edit provenance: unknown or mixed edit format")

    def verify_archive(relative: str, digest: str, dimensions=None) -> None:
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None, "invalid input SHA-256")
        require(isinstance(relative, str) and relative.startswith("docs/production/art-evidence/source-references/") and relative.endswith(".png"), "unsafe input archive")
        require(not any(token in relative for token in ("..", "\\", "%", ":", "//")), "unsafe input archive")
        archive = root / relative
        require(not any(p.is_symlink() for p in (archive, *archive.parents)), "symlink input archive")
        width, height, actual = png_info(archive)
        require(actual == digest, "archived input hash differs")
        if dimensions is not None:
            require((width, height) == dimensions, "archived input dimensions differ")

    for reference in references:
        require(isinstance(reference, dict) and reference.get("kind") == "project_generated_illustration", "unidentified reference")
        verify_archive(reference.get("repository_path"), reference.get("sha256"))
    if stream_format:
        mapping = load(root / "docs/production/art-evidence/edit-inputs.json")
        require(isinstance(mapping, dict) and mapping.get("schema_version") == 1 and isinstance(mapping.get("entries"), dict), "invalid portable input inventory")
        for item in inputs:
            require(isinstance(item, dict) and item.get("type") == "original_generated_image", "unidentified generation input")
            require(substantial(item.get("source_prompt"), 100) and substantial(item.get("reason")), "missing original generation context")
            digest = item.get("sha256")
            require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None, "invalid input SHA-256")
            portable = mapping["entries"].get(digest)
            require(isinstance(portable, dict) and portable.get("card_id") == source.get("card_id"), "generation input has no matching portable archive")
            verify_archive(portable.get("repository_path"), digest, (item.get("original_width"), item.get("original_height")))


def build(root: Path = ROOT) -> tuple[dict, dict]:
    catalog_path = root / "data/production/cards.json"
    catalog = load(catalog_path)
    cards = catalog["cards"] if isinstance(catalog, dict) else catalog
    sources = load(root / "data/production/art_sources.json")["entries"]
    preview_manifest_path = root / "data/production/art_previews.json"
    previews = load(preview_manifest_path)["entries"] if preview_manifest_path.exists() else {}
    if previews and set(previews) != set(sources):
        raise ValueError("Every actual original must have its own current compact preview")
    cards_by_id = {c["id"]: c for c in cards}
    if len(cards_by_id) != len(cards): raise ValueError("Duplicate catalog card IDs")
    if set(sources) - set(cards_by_id): raise ValueError("Orphan art source IDs")
    authored_briefs = load(root / "data/production/art_briefs.json")["cards"]
    brief_by_id = {b["id"]: b for b in authored_briefs}
    if len(brief_by_id) != len(authored_briefs) or set(brief_by_id) != set(cards_by_id):
        raise ValueError("Art brief IDs must exactly match the catalog")
    entries, briefs, hashes = {}, [], {}
    for card in cards:
        card_id, name = card["id"], card["name"]
        power = card.get("faction", card.get("power", "neutral"))
        if power not in PALETTES: raise ValueError(f"Unknown illustration identity {power}: {card_id}")
        species = [SPECIES[t] for t in card.get("species", [])]
        expected_path = f"res://assets/cards/originals/{card_id}.png"
        source = sources.get(card_id)
        entry = {"card_id": card_id, "name": name, "power": power, "status": "missing", "expected_path": expected_path, "asset_path": "", "individual_original": False, "commercially_cleared": False, "production_review": "pending"}
        if source:
            if source.get("asset_path") != expected_path: raise ValueError(f"Art source path/card mismatch: {card_id}")
            path = checked_asset(root, expected_path)
            width, height, digest = png_info(path)
            if source.get("sha256") != digest or (width, height) != (source.get("original_width"), source.get("original_height")):
                raise ValueError(f"Original hash/dimensions changed: {card_id}")
            if width < 1024 or height < 768: raise ValueError(f"Insufficient native source dimensions for full-card inspection: {card_id}")
            if digest in hashes: raise ValueError(f"One image assigned as two originals: {card_id}/{hashes[digest]}")
            hashes[digest] = card_id
            if source.get("status") not in ["concept", "final"]: raise ValueError(f"Unsupported source status: {card_id}")
            if source.get("status") == "final" and source.get("production_review") != "approved": raise ValueError(f"Final artwork lacks production approval: {card_id}")
            for key in ["source_prompt", "creator_or_generator", "creation_date", "alternative_text", "reference_sources", "commercial_review"]:
                if key not in source: raise ValueError(f"Missing provenance {key}: {card_id}")
            validate_edit_provenance(source, root)
            entry.update({key: source[key] for key in ["asset_path", "status", "individual_original", "production_review", "commercially_cleared", "commercial_review", "alternative_text", "original_width", "original_height", "sha256"]})
            if card_id in previews:
                preview = previews[card_id]
                expected_preview = f"res://assets/cards/previews/{card_id}.png"
                if preview.get("asset_path") != expected_preview or preview.get("source_asset_path") != expected_path or preview.get("source_sha256") != digest:
                    raise ValueError(f"Preview/source binding mismatch: {card_id}")
                pw, ph, pdigest = png_info(checked_asset(root, expected_preview, "previews"))
                ratio = min(1.0, 512 / max(width, height))
                expected_dimensions = (int(width * ratio + 0.5), int(height * ratio + 0.5))
                if (pw, ph) != expected_dimensions or (pw, ph) != (preview.get("width"), preview.get("height")) or pdigest != preview.get("sha256") or preview.get("profile") != "compact-512-v1":
                    raise ValueError(f"Preview dimensions/hash/profile mismatch: {card_id}")
                entry.update({"preview_asset_path": expected_preview, "preview_width": pw, "preview_height": ph, "preview_sha256": pdigest})
        entries[card_id] = entry
        briefs.append({
            "card_id": card_id, "name": name, "power": power, "kind": card["kind"],
            "species": species, "lore_status": "VORSCHLAG", "asset_path": expected_path,
            "native_target": {"minimum_width": 1024, "minimum_height": 768, "preferred_width": 1448, "preferred_height": 1086, "art_crop": "672:500"},
            "palette": PALETTES[power], "style": STYLE, "exclusions": EXCLUSIONS,
            "composition": "Ein klarer Hauptfokus im mittleren 80-Prozent-Bereich. Wichtige Gesichter und Anatomie oberhalb der diagonalen unteren Kartenmaske; eigenständiger Schauplatz und glaubhafte räumliche Tiefe.",
            "subject": brief_by_id[card_id]["brief_de"],
            "mechanical_reference_de": card.get("text_de", card.get("description", "")),
            "current_status": entry["status"], "generated": source is not None,
        })
    disk_art = {"res://" + str(p.relative_to(root)) for p in (root / "assets/cards/originals").glob("*.png")}
    represented = {e["asset_path"] for e in entries.values() if e["asset_path"]}
    preview_disk = {"res://" + str(p.relative_to(root)) for p in (root / "assets/cards/previews").glob("*.png")}
    represented_previews = {e["preview_asset_path"] for e in entries.values() if e.get("preview_asset_path")}
    manifest = {"schema_version": 1, "source_catalog": "data/production/cards.json", "source_catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(), "provenance": "data/production/art_sources.json", "inventory_card_count": len(cards), "individual_original_count": len(sources), "final_individual_count": sum(e["status"] == "final" for e in entries.values()), "missing_individual_count": len(cards) - len(sources), "commercially_cleared_count": sum(e["commercially_cleared"] for e in entries.values()), "orphan_files": sorted(disk_art - represented), "compact_preview_count": len(previews), "orphan_preview_files": sorted(preview_disk - represented_previews), "entries": entries}
    return manifest, {"schema_version": 1, "lore_source": "docs/LORE-BIBLE.md", "scope_de": "Art-Briefs sind vorläufige Produktionsanweisungen, keine erzeugten Illustrationen und kein zusätzlicher Kanon.", "count": len(briefs), "entries": briefs}


def serialized(value) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        manifest, briefs = build()
        for name, content in [("art_manifest.json", manifest)]:
            path = ROOT / "data/production" / name
            text = serialized(content)
            if args.check:
                if not path.exists() or path.read_text(encoding="utf-8") != text: raise ValueError(f"Stale/missing {path.relative_to(ROOT)}; run python3 tools/production/art_manifest.py")
            else: path.write_text(text, encoding="utf-8")
        print(f"PRODUCTION ART: {manifest['inventory_card_count']} briefs, {manifest['individual_original_count']} individual illustrations, {manifest['final_individual_count']} visually approved final, {manifest['missing_individual_count']} missing, {len(manifest['orphan_files'])} orphan files")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"PRODUCTION ART ERROR: {exc}", file=sys.stderr); return 1


if __name__ == "__main__": raise SystemExit(main())
