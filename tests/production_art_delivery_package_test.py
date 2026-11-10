"""Filesystem unit fixtures; actual WebP/HTTP/PCK proof runs in separate gates."""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from package_alpha import package
from production.stage_art_delivery import checked_delivery_files, stage


class ProductionArtDeliveryPackage(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="orafold-art-package-unit-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.web = self.root / "export"
        self.web.mkdir()
        self.source = self.root / "source"
        (self.source / "data/production").mkdir(parents=True)
        (self.source / "work/art-delivery-cache").mkdir(parents=True)
        self.body = b"explicit filesystem unit fixture, not an actual encoded illustration"
        self.sha = hashlib.sha256(self.body).hexdigest()
        self.entry = {"web_sha256": self.sha, "relative_url": f"art/full/{self.sha}.webp", "bytes": len(self.body)}
        self.manifest = {"schema_version": 1, "profile": "orafold-web-art-v1", "entries": {"unit-fixture": self.entry}}
        self.manifest_path = self.source / "data/production/art_delivery.json"
        self.manifest_path.write_text(json.dumps(self.manifest))
        self.original = self.source / "work/art-delivery-cache" / f"{self.sha}.webp"
        self.original.write_bytes(self.body)
        self.commit = "1234567890abcdef1234567890abcdef12345678"
        self.prefix = "orafold-" + self.commit[:12]
        (self.web / "index.html").write_text("explicit simulated Web core " + self.prefix)
        (self.web / "build-info.json").write_text(json.dumps({"commit": self.commit, "version": "unit fixture"}))
        for extension in ("pck", "wasm", "js"):
            (self.web / f"{self.prefix}.{extension}").write_bytes(b"explicit simulated Web core")

    def test_stages_exact_hash_bound_body_by_hardlink_without_source_change(self):
        result = stage(self.web, self.source)
        target = self.web / self.entry["relative_url"]
        self.assertEqual(result["full_assets"], 1)
        self.assertEqual(target.read_bytes(), self.body)
        self.assertEqual(self.original.read_bytes(), self.body)
        self.assertEqual(target.stat().st_ino, self.original.stat().st_ino)
        self.assertEqual(checked_delivery_files(self.web, self.manifest), [target])
        with self.assertRaises(ValueError): stage(self.web, self.source)

    def test_zip_includes_nested_art_and_exact_hashes_reproducibly(self):
        stage(self.web, self.source)
        first = package(self.web, self.root / "packages")
        with zipfile.ZipFile(first["archive"]) as zipped:
            self.assertEqual(zipped.read(self.entry["relative_url"]), self.body)
            manifest = json.loads(zipped.read("artifact-manifest.json"))
            self.assertEqual(manifest["full_art_assets"], 1)
            self.assertEqual(manifest["files"][self.entry["relative_url"]], self.sha)
            self.assertEqual(json.loads(zipped.read("art-delivery.json")), self.manifest)
            self.assertTrue(all(not name.startswith("/") and ".." not in Path(name).parts for name in zipped.namelist()))
        self.assertEqual(package(self.web, self.root / "packages")["sha256"], first["sha256"])

    def test_rejects_corrupted_cache_before_staging(self):
        self.original.write_bytes(b"x" * len(self.body))
        with self.assertRaisesRegex(ValueError, "Stale encoded"): stage(self.web, self.source)

    def test_rejects_tampered_staged_body_before_packaging(self):
        stage(self.web, self.source)
        (self.web / self.entry["relative_url"]).write_bytes(b"x" * len(self.body))
        with self.assertRaisesRegex(ValueError, "body/hash mismatch"): package(self.web, self.root / "packages")

    def test_rejects_traversal_and_absolute_delivery_urls(self):
        for url in ("../outside.webp", "/outside.webp", "https://example.com/art.webp", "art/full/../outside.webp"):
            manifest = copy.deepcopy(self.manifest)
            manifest["entries"]["unit-fixture"]["relative_url"] = url
            with self.assertRaisesRegex(ValueError, "hash/path binding"): checked_delivery_files(self.web, manifest)

    def test_rejects_output_directory_symlink_before_any_external_write(self):
        external = self.root / "outside"; external.mkdir()
        (self.web / "art").symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink"): stage(self.web, self.source)
        self.assertEqual(list(external.iterdir()), [])

    def test_rejects_delivery_metadata_symlink_before_any_external_write(self):
        external = self.root / "outside.json"; external.write_bytes(b"untouched")
        (self.web / "art-delivery.json").symlink_to(external)
        with self.assertRaisesRegex(ValueError, "Symlink"): stage(self.web, self.source)
        self.assertEqual(external.read_bytes(), b"untouched")

    def test_rejects_external_cache_symlink(self):
        self.original.unlink()
        external = self.root / "outside.webp"; external.write_bytes(self.body)
        self.original.symlink_to(external)
        with self.assertRaisesRegex(ValueError, "Missing safe"): stage(self.web, self.source)

    def test_rejects_staged_art_symlink(self):
        stage(self.web, self.source)
        target = self.web / self.entry["relative_url"]
        target.unlink(); target.symlink_to(self.original)
        with self.assertRaisesRegex(ValueError, "Symlink"): package(self.web, self.root / "packages")

    def test_rejects_unmanifested_art_at_any_depth(self):
        stage(self.web, self.source)
        extra = self.web / "art/other/extra.webp"
        extra.parent.mkdir(); extra.write_bytes(b"unmanifested")
        with self.assertRaisesRegex(ValueError, "Unexpected"): package(self.web, self.root / "packages")

    def test_rejects_art_directory_without_delivery_manifest(self):
        (self.web / "art").mkdir()
        with self.assertRaisesRegex(ValueError, "Unmanifested"): package(self.web, self.root / "packages")


if __name__ == "__main__": unittest.main()
