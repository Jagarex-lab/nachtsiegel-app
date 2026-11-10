"""Checks real illustration inventory/provenance, plus corrupt input rejection."""
import copy
import importlib.util
import json
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
        self.assertEqual(manifest["individual_original_count"], 5)
        self.assertEqual(manifest["missing_individual_count"], 545)
        self.assertEqual(manifest["final_individual_count"], 5)
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
            self.assertEqual((width, height), (1448, 1086))
            self.assertEqual(digest, entry["sha256"])
            self.assertNotIn(digest, digests)
            self.assertEqual(entry["edits"], [])
            self.assertEqual(entry["reference_sources"], [])
            self.assertIn("illustration", entry["source_prompt"].lower())
            digests.add(digest)

    def test_corruption_not_accepted_as_image(self):
        original = (ROOT / "assets/cards/originals/oa-neutral-c02.png").read_bytes()
        with tempfile.TemporaryDirectory() as temp:
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
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / "assets/cards/originals").mkdir(parents=True)
            outside = root / "outside.png"; outside.write_bytes(b"unused")
            (root / "assets/cards/originals/link.png").symlink_to(outside)
            with self.assertRaises(ValueError): ART.checked_asset(root, "res://assets/cards/originals/link.png")

    def test_stale_and_misrepresented_original_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "data/production", root / "data/production")
            shutil.copytree(ROOT / "assets/cards/originals", root / "assets/cards/originals")
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


if __name__ == "__main__": unittest.main()
