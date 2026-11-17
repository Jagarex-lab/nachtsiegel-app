"""Focused fail-closed contract for transport and actual online duel QA."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_online_demo", ROOT / "tools/alpha03/check_online_demo.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class OnlineRunnerContract(unittest.TestCase):
    def setUp(self):
        # These are parser unit data, not claims of executed gameplay.
        self.transport = {
            "demo": "two local test accounts; authentication, matchmaking, simulated action, reconnect, completion and history",
            "prototype": "simulation-only; no ORAFOLD combat or capacity guarantee",
            "clients": 2, "matches_finished": 1, "reconnects": 1,
            "successful_ws_requests": 12, "attempted_measured_ws_requests": 12,
            "expected_security_rejections": 1, "unexpected_errors": [],
        }
        self.production = {
            "rules": "orafold550-godot-4.6.3-alpha03", "simulation": False,
            "card_count": 550, "actions": 9,
            "command_counts": {"mulligan": 2, "origin": 2, "openingDone": 1, "play": 2, "endTurn": 2},
            "result": {"winner_id": "unit-player", "reason": "duel"},
            "final_state_hash": "a" * 64,
        }

    def test_completed_transport_is_explicitly_not_production(self):
        CHECK.validate_transport(self.transport)
        with self.assertRaises(ValueError):
            CHECK.validate_production(self.transport)

    def test_completed_production_is_not_transport(self):
        CHECK.validate_production(self.production)
        with self.assertRaises(ValueError):
            CHECK.validate_transport(self.production)

    def test_transport_rejects_incomplete_failed_or_boolean_counts(self):
        changes = ({"matches_finished": 0}, {"reconnects": 0}, {"unexpected_errors": ["failed"]},
                   {"successful_ws_requests": 11}, {"attempted_measured_ws_requests": 13},
                   {"matches_finished": True}, {"prototype": "production"})
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                CHECK.validate_transport(self.transport | change)

    def test_production_rejects_simulation_incomplete_replay_and_early_exit(self):
        changes = ({"simulation": True}, {"card_count": 55}, {"result": None},
                   {"result": {"winner_id": "unit-player", "reason": "concede"}},
                   {"actions": 8}, {"final_state_hash": "not-a-hash"},
                   {"command_counts": {"mulligan": 2, "origin": 2, "openingDone": 1}})
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                CHECK.validate_production(self.production | change)

    def test_actual_terminal_draw_is_valid(self):
        value = copy.deepcopy(self.production)
        value["result"]["winner_id"] = None
        CHECK.validate_production(value)

    def test_npm_banner_and_update_notice_do_not_change_completion(self):
        text = "> demo\n> node tools/demo.ts\n\n" + json.dumps(self.transport, indent=2) + "\nnpm notice\nnpm notice Update available\n"
        self.assertEqual(CHECK.summary(text), self.transport)

    def test_truncated_multiple_missing_and_trailing_error_results_fail(self):
        body = json.dumps(self.production, indent=2)
        for text in ("npm banner only", body[:-2], body + "\n" + body, body + "\nERROR: failed after result"):
            with self.subTest(text=text[:40]), self.assertRaises((ValueError, json.JSONDecodeError)):
                CHECK.summary(text)

    def test_required_runner_keeps_scope_deadlines_and_all_security_checks(self):
        runner = (ROOT / "tools/test_alpha03.sh").read_text()
        self.assertRegex(runner, r"run_checked online-demo-fixture '' timeout 180s npm --prefix server run demo:transport\s")
        self.assertRegex(runner, r"run_checked online-production-duel '\\?\"simulation\\?\": false' timeout 900s npm --prefix server run demo:duel\s")
        for required in ("timeout 1500s npm --prefix server test", "online-demo-fixture-parser", "online-production-duel-parser",
                         "check_online_demo.py transport", "check_online_demo.py production", "online-security-audit", "online-client", "offline-draw-seam"):
            self.assertIn(required, runner)
        self.assertEqual(len(re.findall(r"^run_checked online-demo-fixture ", runner, re.MULTILINE)), 1)
        self.assertEqual(len(re.findall(r"^run_checked online-production-duel ", runner, re.MULTILINE)), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
