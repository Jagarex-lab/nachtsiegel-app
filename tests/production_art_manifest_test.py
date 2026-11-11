"""Checks real illustration inventory/provenance, plus corrupt input rejection."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("art_manifest", ROOT / "tools/production/art_manifest.py")
ART = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ART)


class ProductionArtManifest(unittest.TestCase):
    def test_actual_inventory(self):
        manifest, briefs = ART.build()
        self.assertEqual(manifest["inventory_card_count"], 550)
        self.assertEqual(len(briefs["entries"]), 550)
        source_count = len(ART.load(ROOT / "data/production/art_sources.json")["entries"])
        self.assertGreaterEqual(source_count, 15)
        self.assertEqual(manifest["individual_original_count"], source_count)
        self.assertEqual(manifest["missing_individual_count"], 550 - source_count)
        self.assertEqual(manifest["final_individual_count"], source_count)
        self.assertEqual(manifest["compact_preview_count"], source_count)
        self.assertEqual(manifest["orphan_preview_files"], [])
        self.assertEqual(manifest["commercially_cleared_count"], 0)
        self.assertEqual(manifest["orphan_files"], [])
        for entry in manifest["entries"].values():
            self.assertFalse(entry["commercially_cleared"])
            if entry["individual_original"]:
                self.assertEqual(entry["status"], "final")
                self.assertEqual(entry["production_review"], "approved")
        self.assertEqual(len({b["card_id"] for b in briefs["entries"]}), 550)

    def test_real_originals_native_and_unique(self):
        source = ART.load(ROOT / "data/production/art_sources.json")
        digests = set()
        for entry in source["entries"].values():
            path = ART.checked_asset(ROOT, entry["asset_path"])
            width, height, digest = ART.png_info(path)
            self.assertEqual((width, height), (entry["original_width"], entry["original_height"]))
            self.assertGreaterEqual(width, 1024); self.assertGreaterEqual(height, 768)
            self.assertEqual(digest, entry["sha256"])
            self.assertNotIn(digest, digests)
            ART.validate_edit_provenance(entry)
            for reference in entry["reference_sources"]:
                self.assertEqual(reference["kind"], "project_generated_illustration")
                self.assertEqual(len(reference["sha256"]), 64)
                self.assertTrue(entry.get("edits"))
                archive = ROOT / reference["repository_path"]
                self.assertTrue(archive.resolve().is_relative_to((ROOT / "docs/production/art-evidence/source-references").resolve()))
                self.assertFalse(archive.is_symlink())
                self.assertEqual(ART.png_info(archive)[2], reference["sha256"])
            # The full collection uses both documented English art terms; the
            # original fifteen-image fixture happened to use only one of them.
            self.assertGreater(len(entry["source_prompt"].strip()), 100)
            self.assertRegex(entry["source_prompt"].lower(), r"\b(?:illustration|artwork)\b")
            digests.add(digest)

    def test_both_actual_edit_formats_retain_their_inputs(self):
        entries = ART.load(ROOT / "data/production/art_sources.json")["entries"]
        for card_id in ("of-morph-003", "of-neutral-010"):
            with self.subTest(card_id=card_id):
                entry = entries[card_id]
                self.assertTrue(entry["edits"])
                ART.validate_edit_provenance(entry)
        neutral = entries["of-neutral-010"]
        portable = ART.load(ROOT / "docs/production/art-evidence/edit-inputs.json")["entries"]
        original = neutral["generation_inputs"][0]
        self.assertEqual(ART.png_info(ROOT / portable[original["sha256"]]["repository_path"])[2], original["sha256"])
        self.assertNotEqual(original["sha256"], neutral["sha256"])

    def test_invalid_edit_records_are_rejected(self):
        entries = ART.load(ROOT / "data/production/art_sources.json")["entries"]
        for card_id in ("of-morph-003", "of-neutral-010"):
            original = entries[card_id]
            malformed = [None, {}, [None], [{}], [{"tool":"unknown", "prompt":"x"*120,"reason":"x","review":"x"}]]
            for edit in malformed:
                with self.subTest(card_id=card_id, edit=edit):
                    changed = copy.deepcopy(original); changed["edits"] = edit
                    with self.assertRaisesRegex(ValueError, "edit provenance"):
                        ART.validate_edit_provenance(changed)
            for key in original["edits"][0]:
                with self.subTest(card_id=card_id, missing=key):
                    changed = copy.deepcopy(original); del changed["edits"][0][key]
                    with self.assertRaisesRegex(ValueError, "edit provenance"):
                        ART.validate_edit_provenance(changed)
            for key in ("reference_sources", "generation_inputs"):
                if original.get(key):
                    changed = copy.deepcopy(original); changed[key] = []
                    with self.assertRaisesRegex(ValueError, "edit provenance"):
                        ART.validate_edit_provenance(changed)

    def test_changed_or_unidentified_generation_input_is_rejected(self):
        original = ART.load(ROOT / "data/production/art_sources.json")["entries"]["of-neutral-010"]
        for key, value in (("type", "external_unknown"), ("sha256", "0"*64), ("source_prompt", ""), ("original_width", 99)):
            with self.subTest(key=key):
                changed = copy.deepcopy(original); changed["generation_inputs"][0][key] = value
                with self.assertRaisesRegex(ValueError, "edit provenance"):
                    ART.validate_edit_provenance(changed)

    def test_corruption_not_accepted_as_image(self):
        original = (ROOT / "assets/cards/originals/oa-neutral-c02.png").read_bytes()
        with tempfile.TemporaryDirectory(dir=ROOT / "work") as temp:
            path = Path(temp) / "bad.png"
            for payload in [b"not a PNG", original[:40], original[:-5], original + b"trailing"]:
                path.write_bytes(payload)
                with self.assertRaises(ValueError): ART.png_info(path)
            damaged = bytearray(original); damaged[-20] ^= 255
            path.write_bytes(damaged)
            with self.assertRaises(ValueError): ART.png_info(path)

    def test_path_traversal_and_aliases_rejected(self):
        for path in ["res://scripts/model.gd", "res://assets/cards/originals/../../outside.png", "res://assets/cards/originals/%2e.png", "res://assets/cards/originals/x\\y.png", "https://elsewhere/a.png"]:
            with self.assertRaises(ValueError): ART.checked_asset(ROOT, path)
        with tempfile.TemporaryDirectory(dir=ROOT / "work") as temp:
            root = Path(temp); (root / "assets/cards/originals").mkdir(parents=True)
            outside = root / "outside.png"; outside.write_bytes(b"unused")
            (root / "assets/cards/originals/link.png").symlink_to(outside)
            with self.assertRaises(ValueError): ART.checked_asset(root, "res://assets/cards/originals/link.png")

    def test_stale_and_misrepresented_original_metadata(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "work") as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "data/production", root / "data/production")
            shutil.copytree(ROOT / "assets/cards/originals", root / "assets/cards/originals", copy_function=os.link)
            shutil.copytree(ROOT / "assets/cards/previews", root / "assets/cards/previews", copy_function=os.link)
            path = root / "data/production/art_sources.json"
            original = ART.load(path)
            first = next(iter(original["entries"]))
            for key, value in [("sha256", "0" * 64), ("original_width", 4096), ("asset_path", "res://assets/cards/originals/wrong-card.png"), ("production_review", "pending")]:
                changed = copy.deepcopy(original); changed["entries"][first][key] = value
                path.write_text(json.dumps(changed), encoding="utf-8")
                with self.assertRaises(ValueError): ART.build(root)
            changed = copy.deepcopy(original); changed["entries"]["unknown-card"] = changed["entries"].pop(first)
            path.write_text(json.dumps(changed), encoding="utf-8")
            with self.assertRaises(ValueError): ART.build(root)

    def test_compact_preview_source_binding(self):
        previews = ART.load(ROOT / "data/production/art_previews.json")["entries"]
        sources = ART.load(ROOT / "data/production/art_sources.json")["entries"]
        self.assertEqual(set(previews), set(sources))
        hashes = set()
        for card_id, preview in previews.items():
            path = ART.checked_asset(ROOT, preview["asset_path"], "previews")
            width, height, digest = ART.png_info(path)
            ratio = 512 / max(sources[card_id]["original_width"], sources[card_id]["original_height"])
            self.assertEqual((width, height), (int(sources[card_id]["original_width"] * ratio + 0.5), int(sources[card_id]["original_height"] * ratio + 0.5)))
            self.assertEqual(preview["source_sha256"], sources[card_id]["sha256"])
            self.assertEqual(preview["sha256"], digest)
            self.assertNotIn(digest, hashes)
            self.assertEqual(preview["source_asset_path"], sources[card_id]["asset_path"])
            self.assertEqual(preview["profile"], "compact-512-v1")
            hashes.add(digest)

    def test_stale_preview_metadata_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "work") as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "data/production", root / "data/production")
            shutil.copytree(ROOT / "assets/cards/originals", root / "assets/cards/originals", copy_function=os.link)
            shutil.copytree(ROOT / "assets/cards/previews", root / "assets/cards/previews", copy_function=os.link)
            path = root / "data/production/art_previews.json"
            original = ART.load(path)
            first = next(iter(original["entries"]))
            for key, value in [("source_sha256", "0" * 64), ("width", 513), ("sha256", "0" * 64), ("asset_path", "res://assets/cards/previews/wrong-card.png")]:
                changed = copy.deepcopy(original); changed["entries"][first][key] = value
                path.write_text(json.dumps(changed), encoding="utf-8")
                with self.assertRaises(ValueError): ART.build(root)

    def test_compact_derivative_cannot_masquerade_as_original(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "work") as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "data/production", root / "data/production")
            shutil.copytree(ROOT / "assets/cards/originals", root / "assets/cards/originals", copy_function=os.link)
            shutil.copytree(ROOT / "assets/cards/previews", root / "assets/cards/previews", copy_function=os.link)
            sources = ART.load(root / "data/production/art_sources.json")
            card_id = next(iter(sources["entries"]))
            preview = root / "assets/cards/previews" / (card_id + ".png")
            original = root / "assets/cards/originals" / (card_id + ".png")
            original.unlink()  # Break immutable hardlink before corruption fixture.
            shutil.copyfile(preview, original)
            width, height, digest = ART.png_info(original)
            self.assertEqual(max(width, height), 512)
            sources["entries"][card_id].update({"sha256": digest, "original_width": width, "original_height": height})
            (root / "data/production/art_sources.json").write_text(json.dumps(sources), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Insufficient native source dimensions"):
                ART.build(root)


if __name__ == "__main__": unittest.main()
