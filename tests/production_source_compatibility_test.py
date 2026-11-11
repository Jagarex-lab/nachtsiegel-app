"""Source/evidence integrity tests only; these generate no played-game results."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.production import source_compatibility as guard
from tools.production import report_full_pool_coverage as coverage
from tools.production import report_resources as resources


def committed(revision, path):
    return subprocess.check_output(["git", "show", revision + ":" + path], cwd=ROOT)


class SourceCompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = committed("1151530^", guard.MODEL)
        cls.after = committed("1151530", guard.MODEL)

    def test_exact_reviewed_hashes_and_reversible_diff(self):
        self.assertEqual(guard.sha(self.before), guard.BEFORE_SHA256)
        self.assertEqual(guard.sha(self.after), guard.AFTER_SHA256)
        self.assertEqual(guard.normalize_draw_controller(self.after), self.before)
        proof = guard.compare_frozen_source(guard.MODEL, self.after, self.before)
        self.assertEqual(proof["anchor_sha256"], guard.BEFORE_SHA256)
        self.assertEqual(proof["executed_sha256"], guard.AFTER_SHA256)
        self.assertEqual(proof["normalized_sha256"], guard.BEFORE_SHA256)
        self.assertEqual(proof["default_predicate"], 'side=="enemy"')
        self.assertEqual(proof["compatibility_guard_sha256"], hashlib.sha256(Path(guard.__file__).read_bytes()).hexdigest())

    def test_unchanged_source_needs_no_exception(self):
        self.assertIsNone(guard.compare_frozen_source(guard.MODEL, self.before, self.before))
        self.assertEqual(guard.inspect_draw_controller(self.before)["compatibility"], "unchanged-default-source")

    def test_mutated_seams_and_unrelated_edits_rejected(self):
        mutations = {
            "wrong default": self.after.replace(b'func _automatic_draw_side(side: String) -> bool:return side=="enemy"', b'func _automatic_draw_side(side: String) -> bool:return false'),
            "wrong side": self.after.replace(b'func _automatic_draw_side(side: String) -> bool:return side=="enemy"', b'func _automatic_draw_side(side: String) -> bool:return side=="hero"'),
            "different branch": self.after.replace(b'if _automatic_draw_side(side):', b'if not _automatic_draw_side(side):'),
            "duplicate hook": self.after + guard.HOOK,
            "unrelated edit": self.after.replace(b'func energy_limit() -> int:return 8', b'func energy_limit() -> int:return 10'),
            "extra whitespace": self.after + b'\n',
            "arbitrary source": b'func _automatic_draw_side(side):return side=="enemy"\n',
        }
        for label, data in mutations.items():
            with self.subTest(label=label), self.assertRaises(ValueError):
                guard.compare_frozen_source(guard.MODEL, data, self.before)

    def test_other_paths_and_changed_original_anchor_rejected(self):
        with self.assertRaises(ValueError):
            guard.compare_frozen_source("scripts/card_system/production_model.gd", self.after, self.before)
        with self.assertRaises(ValueError):
            guard.compare_frozen_source(guard.MODEL, self.after, self.before + b'\n')

    def test_normalization_cannot_relabel_old_evidence_as_new(self):
        with self.assertRaisesRegex(ValueError, "fresh evidence"):
            guard.verify_executed_draw_controller({guard.MODEL: guard.BEFORE_SHA256}, self.after)
        actual = {guard.MODEL: guard.AFTER_SHA256}
        proof = guard.verify_executed_draw_controller(actual, self.after)
        self.assertEqual(actual[guard.MODEL], guard.AFTER_SHA256)
        self.assertEqual(proof["executed_sha256"], guard.AFTER_SHA256)

    def test_full_pool_context_preserves_core_and_actual_hashes(self):
        # Reconstruct only source files needed by context; no engine or game runs.
        anchors = {path: committed(coverage.CORE, path) for path in coverage.BOUND_PATHS - coverage.NEW_PATHS}
        new = {path: committed("HEAD", path) for path in coverage.NEW_PATHS}
        with tempfile.TemporaryDirectory(prefix="orafold-source-guard-") as directory:
            checkout = Path(directory)
            for path, data in (anchors | new).items():
                target = checkout / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            (checkout / guard.MODEL).write_bytes(self.after)
            def old_source(command, **_kwargs):
                return anchors[command[2].split(":", 1)[1]]
            with mock.patch.object(coverage, "ROOT", checkout), mock.patch.object(coverage.subprocess, "check_output", old_source):
                ctx = coverage.context()
                self.assertEqual(ctx["core_hashes"][guard.MODEL], guard.BEFORE_SHA256)
                self.assertEqual(ctx["hashes"][guard.MODEL], guard.AFTER_SHA256)
                self.assertEqual(set(ctx["source_compatibility"]), {guard.MODEL})
                (checkout / guard.MODEL).write_bytes(self.after + b'\n')
                with self.assertRaises(ValueError):
                    coverage.context()
                (checkout / guard.MODEL).write_bytes(self.after)
                (checkout / "scripts/production/ai_policy.gd").write_bytes(anchors["scripts/production/ai_policy.gd"] + b'\n')
                with self.assertRaises(ValueError):
                    coverage.context()

    def test_resource_default_state_and_event_guards_remain_exact(self):
        # Historical records are used only as rejection-test inputs, never
        # relabelled, saved or presented as results from the changed checkout.
        report = json.loads(committed("HEAD", "docs/production/RESOURCE_MODEL_GAMES.json"))
        baseline = json.loads(committed("HEAD", resources.BASELINE))
        catalog = {c["id"]: c for c in json.loads((ROOT / "data/production/cards.json").read_text())["cards"]}
        resources.validate(report, baseline, catalog, report["source_sha256"])
        for field in ("event_sha256", "final_state_sha256"):
            damaged = copy.deepcopy(report)
            default = next(g for g in damaged["games"] if g["condition"] == "energy8_res15")
            default[field] = "0" * 64
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "Default differs"):
                resources.validate(damaged, baseline, catalog, damaged["source_sha256"])


if __name__ == "__main__":
    unittest.main()
