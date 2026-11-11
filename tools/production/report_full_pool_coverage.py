#!/usr/bin/env python3
"""Validate and report actual full-pool self-play, including honest failed runs.

No games are generated here. Raw input, plan and optional flushed journal are
preserved before validation. Only successful observed play commands count toward
played-card coverage; deck membership and replay controls never inflate it.
"""
from __future__ import annotations

import argparse
import collections
import copy
import hashlib
import importlib.util
import json
import math
import re
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = "d3c7c7bf1e2d714aef896d39538bfd343d2365c2"
SUITE = "production_full_pool_coverage"
POWERS = ("houses", "stillwatch", "morph", "ninth")
REPEATS = (0, 57, 64, 121, 128, 185, 192, 249)
FRESH = (2, 67, 130, 195)
FIXTURE = "tests/fixtures/production/full_pool_decks.json"
NEW_PATHS = {"tests/production_full_pool_coverage.gd", FIXTURE,
             "tools/production/build_full_pool_decks.py"}
BOUND_PATHS = NEW_PATHS | {
    "tests/production_simulations.gd", "data/production/cards.json", "data/production/starters.json",
    "scripts/production/catalog.gd", "scripts/alpha/catalog.gd", "scripts/production/ai_policy.gd",
    "scripts/card_system/production_model.gd", "scripts/card_system/production_effects.gd",
    "scripts/card_system/trigger_model.gd", "scripts/card_system/runtime.gd",
    "scripts/card_system/registry.gd", "data/card_system/registry.json",
    "data/card_system/alpha_species.json", "data/alpha/cards.json", "scripts/alpha/model.gd",
    "scripts/legacy/battle_engine.gd", "scripts/legacy/rng.gd",
}
HEADER_KEYS = {
    "schema_version", "suite", "profile", "base_core_commit", "executed_commit", "godot", "run_state",
    "diagnostic_case_index", "expected_matrix_games", "matrix_games", "expected_repeat_games",
    "expected_fresh_constructor_games", "additional_verification_games", "max_hero_calls_per_game",
    "planning_openings_not_full_games", "planned_cases", "control_plan", "plan_sha256", "decks",
    "assertions", "failures", "source_sha256", "source_changes_during_run", "source_guard_completed",
    "games", "controls", "total_elapsed_usec", "measurement_notes",
}
RESOURCE_FIELDS = ("turns_observed", "energy_at_action_phase", "known_card_energy_paid",
                   "known_card_resonance_paid", "unspent_energy_at_end",
                   "action_net_resonance_gained", "action_net_resonance_spent", "failed_action_attempts")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def integer(value, label, minimum=0):
    require(type(value) in (int, float) and math.isfinite(value) and value == int(value)
            and value >= minimum, "Invalid nonnegative integer: " + label)
    return int(value)


def digest(value, label):
    require(isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value),
            "Invalid full SHA-256: " + label)


def counts(value, label):
    require(isinstance(value, dict), "Expected count mapping: " + label)
    for key, amount in value.items():
        require(isinstance(key, str) and bool(key), "Invalid count identity: " + label)
        integer(amount, label + "/" + key)


def stable(row):
    result = copy.deepcopy(row)
    result.pop("wall_usec", None)
    return json.dumps(result, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def context():
    fixture = json.loads((ROOT / FIXTURE).read_text())
    catalog = {c["id"]: c for c in json.loads((ROOT / "data/production/cards.json").read_text())["cards"]}
    starters = json.loads((ROOT / "data/production/starters.json").read_text())
    spec = importlib.util.spec_from_file_location("full_pool_deck_validation", ROOT / "tools/production/build_full_pool_decks.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    builder.validate_decks(fixture["decks"], catalog, starters)
    require(len(catalog) == 550, "Expected actual550 catalog")
    hashes = {path: sha((ROOT / path).read_bytes()) for path in BOUND_PATHS}
    core_hashes = {}
    for path in sorted(BOUND_PATHS - NEW_PATHS):
        data = subprocess.check_output(["git", "show", CORE + ":" + path], cwd=ROOT)
        core_hashes[path] = sha(data)
        require(hashes[path] == core_hashes[path], "Sampler modified existing core/model/data/AI/inherited harness: " + path)
    return {"fixture": fixture, "catalog": catalog, "hashes": hashes, "core_hashes": core_hashes,
            "decks": {d["id"]: d for d in fixture["decks"]}}


def expected_pairs(decks):
    groups = {p: sorted((d["id"] for d in decks.values() if d["power"] == p)) for p in POWERS}
    require(all(len(ids) == 8 for ids in groups.values()), "Eight decks per power required")
    return [(groups[p][i], enemy)
            for pi, p in enumerate(POWERS) for i in range(8)
            for enemy in (groups[POWERS[(pi + 1) % 4]][i], groups[POWERS[(pi + 2) % 4]][(i + 3) % 8])]


def validate_plan(plan, ctx):
    require(plan["schema_version"] == 1 and plan["suite"] == SUITE and plan["base_core_commit"] == CORE, "Wrong plan identity/core")
    require(isinstance(plan["executed_commit"], str) and len(plan["executed_commit"]) == 40
            and all(c in "0123456789abcdef" for c in plan["executed_commit"]), "Missing exact executed commit")
    require(plan["deck_fixture_sha256"] == ctx["hashes"][FIXTURE], "Plan uses different deck fixture")
    require((plan["expected_matrix_games"], plan["expected_repeats"], plan["expected_fresh_constructor_games"]) == (256, 8, 4), "Changed planned sample size")
    integer(plan["opening_probes_not_full_games"], "planning probes", 256)
    cases = plan["cases"]
    require(len(cases) == 256, "Missing/extra planned case")
    pairs = expected_pairs(ctx["decks"])
    for index, item in enumerate(cases):
        require(integer(item["case_index"], "case index") == index and item["case_id"] == f"coverage-{index:03}", "Changed planned case identity/order")
        require(integer(item["pair_index"], "pair index") == index // 4, "Wrong pair index")
        require((item["hero"], item["enemy"]) == pairs[index // 4], "Unplanned directed pairing")
        require(item["hero_power"] == ctx["decks"][item["hero"]]["power"] and item["enemy_power"] == ctx["decks"][item["enemy"]]["power"], "Wrong planned power")
        integer(item["seed"], "seed")
        require(item["first"] in ("hero", "enemy"), "Invalid planned first side")
    for start in range(0, 256, 4):
        rows = cases[start:start + 4]
        require(len({r["seed"] for r in rows}) == 4, "Duplicate planned seed")
        require(collections.Counter(r["first"] for r in rows) == {"hero": 2, "enemy": 2}, "Unbalanced planned first sides")
    controls = ([{"kind": "repeat", "matrix_case_index": i} for i in REPEATS]
                + [{"kind": "fresh_constructor", "matrix_case_index": i} for i in FRESH])
    require(plan["controls"] == controls, "Changed predeclared controls")


def read_journal(data):
    rows, warnings = [], []
    lines = data.splitlines()
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except (ValueError, UnicodeDecodeError):
            if index == len(lines) - 1:
                warnings.append("Last journal line is incomplete; it is preserved but is not a finished attempt.")
            else:
                raise ValueError("Invalid journal line before end: " + str(index + 1))
    return rows, warnings


def runtime_log_errors(data):
    errors = []
    last_case = None
    pattern = re.compile(r"SCRIPT ERROR|^ERROR:|^FAIL:|instances leaked|resources still in use")
    for number, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
        if line.startswith("FULL POOL CASE START:"):
            last_case = line.removeprefix("FULL POOL CASE START:").strip()
        if pattern.search(line):
            errors.append({"line": number, "message": line, "last_case_start_seen": last_case})
    return errors


def recover_journal(report, journal_rows):
    matrices, controls = [], []
    for entry in journal_rows:
        require(entry["record_type"] in ("matrix", "control"), "Unknown journal record type")
        require(integer(entry["case_index"], "journal index") == integer(entry["game"]["case_index"], "journal game index"), "Journal index disagrees with game")
        if entry["record_type"] == "matrix":
            matrices.append(entry["game"])
        else:
            controls.append({"kind": entry["control_kind"], "matrix_case_index": entry["case_index"], "game": entry["game"]})
    if report["run_state"] == "completed":
        require(matrices == report["games"], "Journal matrix differs from raw completed evidence")
        require(len(controls) == len(report["controls"]), "Journal controls differ from raw evidence")
        for actual, stored in zip(controls, report["controls"]):
            require(all(actual[k] == stored[k] for k in ("kind", "matrix_case_index", "game")), "Journal replay differs from raw evidence")
        return copy.deepcopy(report), False
    effective = copy.deepcopy(report)
    # Only flushed finished attempts are recovered. No missing case is invented.
    if report["games"]:
        require(report["games"] == matrices[:len(report["games"])], "Running snapshot is not a journal prefix")
    by_index = {integer(g["case_index"], "journal matrix index"): g for g in matrices}
    for item in controls:
        reference = by_index.get(integer(item["matrix_case_index"], "control index"))
        require(reference is not None, "Journal control has no completed matrix attempt")
        item["identical_excluding_wall_time"] = stable(item["game"]) == stable(reference)
    effective["games"] = matrices
    effective["matrix_games"] = len(matrices)
    effective["controls"] = controls
    effective["additional_verification_games"] = len(controls)
    return effective, True


def validate_game(game, planned, ctx, maximum):
    for name in ("case_index", "case_id", "hero", "enemy", "seed", "first"):
        require(game[name] == planned[name], "Game differs from frozen planned case: " + name)
    require(type(game["censored"]) is bool and type(game["initialization_failed"]) is bool and isinstance(game["error"], str), "Invalid actual failure fields")
    integer(game["wall_usec"], "wall time")
    if game["initialization_failed"]:
        require(game["censored"] and game["winner"] is None and bool(game["error"]), "False initialization-failure outcome")
        return
    require(game["group"] == "full_pool_coverage" and game["difficulty"] == 2, "Wrong actual policy group/difficulty")
    require(game["hero_power"] == planned["hero_power"] and game["enemy_power"] == planned["enemy_power"], "Wrong actual power")
    require(game["winner"] in ("hero", "enemy", "draw", None), "Fabricated winner")
    require(game["censored"] == (game["winner"] is None), "Censored game falsely counted as completed or draw")
    require(type(game["convergence"]) is bool, "Invalid victory observation")
    require(not game["convergence"] or game["winner"] in ("hero", "enemy"), "False convergence outcome")
    require(integer(game["hero_calls"], "hero calls") <= maximum, "Hero calls exceed technical horizon")
    for name in ("round", "longest_native_chain", "longest_generic_chain", "action_limit_reached", "policy_decisions", "illegal_card_play_attempts"):
        integer(game[name], name)
    digest(game["event_sha256"], "events")
    digest(game["final_state_sha256"], "state")
    counts(game["event_counts"], "native event kinds")
    require(integer(game["event_count"], "event count") == sum(game["event_counts"].values()), "Event count mismatch")
    counts(game["generic_effect_statuses"], "generic statuses")
    counts(game["generic_effect_operations"], "generic operations/statuses")
    statuses = collections.Counter()
    for operation, amount in game["generic_effect_operations"].items():
        effect, separator, status = operation.rpartition("/")
        require(bool(effect) and bool(separator) and bool(status), "Invalid observed effect/status key")
        statuses[status] += amount
    require(dict(statuses) == game["generic_effect_statuses"], "Effect/status totals differ from actual runtime counts")
    for source, effects in game["generic_applied_by_card"].items():
        require(source in ctx["catalog"], "Unknown effect source card")
        counts(effects, "applied effects by source")
    require(sum(sum(v.values()) for v in game["generic_applied_by_card"].values()) <= statuses.get("applied", 0), "Per-card applied effects exceed actual applied entries")
    require(set(game["metrics"]) == {"hero", "enemy"}, "Missing actual side metrics")
    for side, metrics in game["metrics"].items():
        for name in RESOURCE_FIELDS:
            integer(metrics[name], side + "/" + name)
        integer(metrics["resonance_peak_observed"], "observed resonance peak")
        require(len(metrics["resonance_at_turn_begin"]) == metrics["turns_observed"], "Turn observations differ")
        for amount in metrics["resonance_at_turn_begin"]:
            integer(amount, "observed turn resonance")
        counts(metrics["cards_played"], "successful observed card plays")
        require(set(metrics["cards_played"]) <= set(ctx["catalog"]), "Unknown successfully played identity")
        require(all(n > 0 for n in metrics["cards_played"].values()), "Zero/fake successful-play count")
        counts(metrics["actions"], "successful actions")
        require(sum(metrics["cards_played"].values()) == metrics["actions"].get("play", 0), "Card play counts differ from successful play commands")
        require(sum(ctx["catalog"][id]["cost"] * n for id, n in metrics["cards_played"].items()) == metrics["known_card_energy_paid"], "Printed successful-play energy payments differ")
        require(sum(ctx["catalog"][id].get("resonance_cost", 0) * n for id, n in metrics["cards_played"].items()) == metrics["known_card_resonance_paid"], "Printed successful-play resonance payments differ")


def validate(report, plan, plan_hash, ctx, reconstructed=False, warnings=()):
    require(set(report) == HEADER_KEYS, "Missing/extra raw schema fields; coverage claims must be derived from actual observations")
    require(report["schema_version"] == 1 and report["suite"] == SUITE and report["profile"] == "production-550-v1", "Wrong sampler/profile")
    require(report["base_core_commit"] == CORE, "Changed core anchor")
    require(report["source_sha256"] == ctx["hashes"] and set(report["source_sha256"]) == BOUND_PATHS, "Mixed, missing or changed executed sources")
    require(report["decks"] == ctx["fixture"]["decks"], "Actual deck lists differ from frozen fixture")
    validate_plan(plan, ctx)
    require(report["executed_commit"] == plan["executed_commit"], "Plan and run executed different commits")
    commit_cache = ctx.setdefault("executed_commit_source_hashes", {})
    if report["executed_commit"] not in commit_cache:
        commit_cache[report["executed_commit"]] = {
            path: sha(subprocess.check_output(["git", "show", report["executed_commit"] + ":" + path], cwd=ROOT))
            for path in sorted(BOUND_PATHS)
        }
    require(commit_cache[report["executed_commit"]] == report["source_sha256"], "Executed source hashes differ from exact committed source")
    require(report["plan_sha256"] == plan_hash, "Separate frozen plan SHA mismatch")
    require(report["planned_cases"] == plan["cases"] and report["control_plan"] == plan["controls"], "Raw report differs from separate pre-match plan")
    require(report["planning_openings_not_full_games"] == plan["opening_probes_not_full_games"], "Changed opening-probe count")
    require((report["expected_matrix_games"], report["expected_repeat_games"], report["expected_fresh_constructor_games"]) == (256, 8, 4), "Changed sample/control sizes")
    require(report["matrix_games"] == len(report["games"]) and report["additional_verification_games"] == len(report["controls"]), "Attempt counts disagree with records")
    require(report["run_state"] in ("running", "completed", "planning_only"), "Unknown actual run state")
    require(type(report["source_guard_completed"]) is bool and report["source_guard_completed"] == (report["run_state"] == "completed"), "False source guard completion")
    integer(report["assertions"], "engine assertions")
    integer(report["failures"], "engine failed checks")
    integer(report["total_elapsed_usec"], "whole-run elapsed time")
    require(report["max_hero_calls_per_game"] == 500, "Changed technical horizon")
    selected = integer(report["diagnostic_case_index"] + 1, "diagnostic case offset") - 1
    require(selected < 256, "Invalid diagnostic case")
    require(isinstance(report["source_changes_during_run"], list) and set(report["source_changes_during_run"]) <= BOUND_PATHS, "Invalid source-change evidence")
    full = report["run_state"] == "completed" and selected == -1
    indices = [integer(g["case_index"], "actual case index") for g in report["games"]]
    require(len(indices) == len(set(indices)) and set(indices) <= set(range(256)), "Duplicate/extra actual case")
    require(indices == sorted(indices), "Actual case order differs from frozen plan")
    if full:
        require(indices == list(range(256)), "Missing completed-run matrix cases")
    games = {integer(g["case_index"], "actual case index"): g for g in report["games"]}
    for index, game in games.items():
        validate_game(game, plan["cases"][index], ctx, 500)
    expected_controls = {(item["kind"], item["matrix_case_index"]) for item in plan["controls"]}
    found_controls = set()
    for item in report["controls"]:
        key = item["kind"], integer(item["matrix_case_index"], "control matrix index")
        require(key in expected_controls and key not in found_controls, "Duplicate/unplanned control")
        found_controls.add(key)
        require(key[1] in games, "Control lacks actual matrix case")
        validate_game(item["game"], plan["cases"][key[1]], ctx, 500)
        equivalent = stable(item["game"]) == stable(games[key[1]])
        require(type(item["identical_excluding_wall_time"]) is bool and item["identical_excluding_wall_time"] == equivalent, "Altered control or false determinism verdict")
    if full:
        require(found_controls == expected_controls and len(report["controls"]) == 12, "Missing full-run replay/fresh-constructor controls")
    issues = []
    if not full:
        issues.append("Run is interrupted, planning-only or diagnostic; cases without finished evidence may be unrun or interrupted mid-game.")
    if not report["source_guard_completed"]:
        issues.append("Final executed-source guard did not complete.")
    if report["source_changes_during_run"]:
        issues.append("Executed source contents changed during the run.")
    if report["failures"]:
        issues.append(f"Engine recorded {report['failures']} failed checks.")
    issues.extend(warnings)
    failed_cases = []
    for kind, rows in (("matrix", report["games"]), ("control", [c["game"] for c in report["controls"]])):
        for game in rows:
            reasons = []
            if game["initialization_failed"]: reasons.append("initialization_failed")
            if game["censored"]: reasons.append("censored")
            if game["error"]: reasons.append("engine_error: " + game["error"])
            if game.get("action_limit_reached", 0): reasons.append("policy_action_ceiling")
            if game.get("illegal_card_play_attempts", 0): reasons.append("illegal_advertised_card_play")
            if reasons:
                failed_cases.append({"record_type": kind, "case_index": game["case_index"], "case_id": game["case_id"], "reasons": reasons})
    nonidentical = [{"kind": c["kind"], "matrix_case_index": c["matrix_case_index"]}
                    for c in report["controls"] if not c["identical_excluding_wall_time"]]
    if failed_cases: issues.append(f"{len(failed_cases)} matrix/control attempts contain actual censors/errors/technical failures.")
    if nonidentical: issues.append(f"{len(nonidentical)} controls do not reproduce full observations excluding wall time.")
    return {"passed": not issues, "issues": issues, "failed_attempts": failed_cases, "nonidentical_controls": nonidentical,
            "reconstructed_from_flushed_journal": reconstructed,
            "not_completed_or_unrun_cases": [c for c in plan["cases"] if c["case_index"] not in games],
            "not_completed_or_unrun_controls": [c for c in plan["controls"] if (c["kind"], c["matrix_case_index"]) not in found_controls]}


def rejection_checks(report, plan, plan_hash, ctx):
    if len(report["games"]) != 256 or len(report["controls"]) != 12 or report["run_state"] != "completed":
        return {"tested": [], "skipped_reason": "Incomplete actual dataset; do not manufacture missing games for negative tests."}
    tests = {}
    tests["missing actual case"] = lambda r: (r["games"].pop(), r.__setitem__("matrix_games", 255))
    tests["extra actual case"] = lambda r: (r["games"].append(copy.deepcopy(r["games"][0])), r.__setitem__("matrix_games", 257))
    tests["duplicate actual case"] = lambda r: r["games"].__setitem__(1, copy.deepcopy(r["games"][0]))
    tests["false first side"] = lambda r: r["games"][0].__setitem__("first", "hero" if r["games"][0]["first"] == "enemy" else "enemy")
    tests["fabricated winner"] = lambda r: r["games"][0].__setitem__("winner", "fabricated")
    tests["mixed source"] = lambda r: r["source_sha256"].__setitem__("scripts/alpha/model.gd", "0" * 64)
    tests["missing bound source"] = lambda r: r["source_sha256"].pop(FIXTURE)
    tests["unplanned source"] = lambda r: r["source_sha256"].__setitem__("invented.gd", "0" * 64)
    tests["wrong seed"] = lambda r: r["games"][0].__setitem__("seed", 999999)
    tests["missing control"] = lambda r: (r["controls"].pop(), r.__setitem__("additional_verification_games", 11))
    tests["duplicate control"] = lambda r: r["controls"].__setitem__(1, copy.deepcopy(r["controls"][0]))
    tests["false control verdict"] = lambda r: r["controls"][0].__setitem__("identical_excluding_wall_time", not r["controls"][0]["identical_excluding_wall_time"])
    def altered_replay(r):
        r["controls"][0]["game"]["event_sha256"] = "0" * 64
        r["controls"][0]["identical_excluding_wall_time"] = True
    tests["altered replay claimed identical"] = altered_replay
    tests["false coverage claim"] = lambda r: r.__setitem__("played_card_ids", sorted(ctx["catalog"]))
    tests["altered frozen plan"] = lambda r: r["planned_cases"][0].__setitem__("seed", 999999)
    tests["false plan SHA"] = lambda r: r.__setitem__("plan_sha256", "0" * 64)
    tests["false opening count"] = lambda r: r.__setitem__("planning_openings_not_full_games", r["planning_openings_not_full_games"] + 1)
    usable = next((i for i, g in enumerate(report["games"]) if not g["initialization_failed"]), None)
    if usable is not None:
        tests["unknown observed played identity"] = lambda r: r["games"][usable]["metrics"]["hero"]["cards_played"].__setitem__("invented-card", 1)
        tests["false printed payments"] = lambda r: r["games"][usable]["metrics"]["hero"].__setitem__("known_card_energy_paid", r["games"][usable]["metrics"]["hero"]["known_card_energy_paid"] + 1)
    passed = []
    for name, mutate in tests.items():
        damaged = copy.deepcopy(report)
        mutate(damaged)
        try:
            validate(damaged, plan, plan_hash, ctx)
        except (ValueError, KeyError, TypeError, IndexError):
            passed.append(name)
        else:
            raise ValueError("Corrupt actual evidence accepted: " + name)
    return {"tested": sorted(passed), "skipped_reason": None}


def summarize(report, plan, ctx, validation):
    used = collections.Counter()
    completed_used = collections.Counter()
    operations = collections.Counter()
    events = collections.Counter()
    applied = {}
    resources = collections.Counter()
    resources["resonance_peak_observed"] = 0
    pairs, deck_stats = {}, {}
    for deck in report["decks"]:
        deck_stats[deck["id"]] = {"power": deck["power"], "participations": 0, "completed": 0, "censored": 0,
                                  "errors": 0, "wins": 0, "played_card_counts": {}, "member_ids": sorted(set(deck["cards"]))}
    for game in report["games"]:
        pair = game["hero"] + "/" + game["enemy"]
        stats = pairs.setdefault(pair, {"attempts": 0, "completed": 0, "censored": 0, "errors": 0,
                                       "hero_wins": 0, "enemy_wins": 0, "draws": 0, "rounds": [], "wall_usec": 0})
        completed = not game["censored"] and not game["initialization_failed"]
        stats["attempts"] += 1
        stats["completed"] += completed
        stats["censored"] += game["censored"]
        stats["errors"] += bool(game["error"])
        stats["hero_wins"] += game["winner"] == "hero"
        stats["enemy_wins"] += game["winner"] == "enemy"
        stats["draws"] += game["winner"] == "draw"
        stats["wall_usec"] += game["wall_usec"]
        if "round" in game: stats["rounds"].append(game["round"])
        for side in ("hero", "enemy"):
            ds = deck_stats[game[side]]
            ds["participations"] += 1
            ds["completed"] += completed
            ds["censored"] += game["censored"]
            ds["errors"] += bool(game["error"])
            ds["wins"] += game["winner"] == side
        if game["initialization_failed"]:
            continue
        operations.update(game["generic_effect_operations"])
        events.update(game["event_counts"])
        for source, effects in game["generic_applied_by_card"].items():
            target = applied.setdefault(source, collections.Counter())
            target.update(effects)
        for side, metrics in game["metrics"].items():
            used.update(metrics["cards_played"])
            if completed and not game["error"]: completed_used.update(metrics["cards_played"])
            target = collections.Counter(deck_stats[game[side]]["played_card_counts"])
            target.update(metrics["cards_played"])
            deck_stats[game[side]]["played_card_counts"] = dict(sorted(target.items()))
            for field in RESOURCE_FIELDS: resources[field] += metrics[field]
            resources["resonance_peak_observed"] = max(resources["resonance_peak_observed"], metrics["resonance_peak_observed"])
    for stats in pairs.values():
        rounds = stats.pop("rounds")
        stats["mean_round_observed"] = statistics.mean(rounds) if rounds else None
    for stats in deck_stats.values():
        stats["played_unique_ids"] = len(stats["played_card_counts"])
        stats["unplayed_member_ids"] = sorted(set(stats["member_ids"]) - set(stats["played_card_counts"]))
    times = sorted(g["wall_usec"] for g in report["games"])
    perf = {"matrix_wall_usec_sum": sum(times), "control_wall_usec_sum": sum(c["game"]["wall_usec"] for c in report["controls"]),
            "whole_run_elapsed_usec": report["total_elapsed_usec"], "minimum_usec": min(times) if times else None,
            "median_usec": statistics.median(times) if times else None,
            "p95_nearest_rank_usec": times[max(0, math.ceil(len(times) * .95) - 1)] if times else None,
            "maximum_usec": max(times) if times else None,
            "mean_usec": statistics.mean(times) if times else None}
    unplayed = [{"id": id, "name": card["name"], "power": card["faction"], "kind": card["kind"]}
                for id, card in sorted(ctx["catalog"].items()) if id not in used]
    return {"status": "passed" if validation["passed"] else "failed", "validation": validation,
            "matrix_attempts": len(report["games"]), "matrix_completed": sum(not g["censored"] and not g["initialization_failed"] for g in report["games"]),
            "matrix_censored": sum(g["censored"] for g in report["games"]), "matrix_engine_errors": sum(bool(g["error"]) for g in report["games"]),
            "matrix_draws": sum(g["winner"] == "draw" for g in report["games"]),
            "control_attempts": len(report["controls"]), "repeat_attempts": sum(c["kind"] == "repeat" for c in report["controls"]),
            "fresh_constructor_attempts": sum(c["kind"] == "fresh_constructor" for c in report["controls"]),
            "opening_probes_excluded_from_games": report["planning_openings_not_full_games"],
            "deck_membership_unique_ids": len({id for d in report["decks"] for id in d["cards"]}),
            "observed_played_unique_ids": len(used), "completed_error_free_played_unique_ids": len(completed_used),
            "observed_card_play_counts": dict(sorted(used.items())), "unplayed_cards": unplayed,
            "generic_effect_operations": dict(sorted(operations.items())), "native_event_kind_counts": dict(sorted(events.items())),
            "generic_applied_by_source_card": {id: dict(sorted(effects.items())) for id, effects in sorted(applied.items())},
            "resources_observed": dict(resources), "performance_wall_time": perf, "directed_pairs": pairs, "decks": deck_stats,
            "actual_case_digests": [{key: g.get(key) for key in ("case_index", "case_id", "hero", "enemy", "seed", "first", "winner", "censored", "error", "event_sha256", "final_state_sha256")}
                                    for g in report["games"]]}


def markdown(summary, report, guards):
    v = summary["validation"]
    lines = ["# Full-Pool-Selbstspiel: Coverage-Stichprobe", "",
             f"**{'BESTANDEN' if v['passed'] else 'NICHT BESTANDEN'}**: {summary['matrix_attempts']}/256 vollständig protokollierte Matrixversuche, {summary['matrix_completed']} beendet, {summary['matrix_censored']} zensiert, {summary['matrix_engine_errors']} mit Enginefehler. Für {len(v['not_completed_or_unrun_cases'])} geplante Fälle liegt kein abgeschlossener Versuch vor: Sie wurden entweder noch nicht begonnen oder mitten in der Ausführung unterbrochen. Sie erhalten keine erfundenen Sieger oder Unentschieden.", "",
             f"Die 32 legalen Decklisten enthalten zusammen {summary['deck_membership_unique_ids']}/550 Identitäten. Tatsächlich erfolgreich ausgespielt wurden **{summary['observed_played_unique_ids']}/550** verschiedene IDs aus beobachteten KI-Kommandos; {summary['completed_error_free_played_unique_ids']} davon erscheinen auch in vollständig beendeten fehlerfreien Partien. {len(summary['unplayed_cards'])} IDs wurden nicht ausgespielt. Mitgliedschaft, Beschwörung und gedruckte Fähigkeiten zählen nicht als Ausspielnachweis.", "",
             f"Zusätzlich {summary['repeat_attempts']}/8 Wiederholungen und {summary['fresh_constructor_attempts']}/4 frische Konstruktoren. Diese Kontrollen werden nicht zur Matrix-Coverage addiert. {summary['opening_probes_excluded_from_games']} Öffnungsproben sind keine vollständigen Partien. {len(guards['tested'])} beschädigte Nachweiskopien wurden abgewiesen; diese Prüfungen spielen keine weiteren Partien.", "",
             "## Methode und Grenzen", "",
             "Die vorhandene Produktionsengine und KI bleiben unverändert. Der Sampler erbt Aufbau, tatsächliche Zugausführung und Messung aus production_simulations.gd; er ist keine zweite Engine. Acht Decks je Macht besitzen einen Starterkern und echte wiederkehrende Angriffswachstums-Relikte. Je Deck werden zwei vorab festgelegte Gegner und je zwei Seeds pro erster Sitzposition gespielt: 64 gerichtete Paarungen × vier Fälle = 256 geplante Partien.", "",
             "Der separate Plan wird vor der ersten vollständigen Partie geschrieben und per SHA-256 gebunden. Alle bestehenden Modell-, Daten-, KI- und geerbten Testdateien werden gegen den angegebenen Core-Commit geprüft; der Lauf bindet zusätzlich Deckfixture, Generator und Orchestrierung. Nur die gemessene Wandzeit ist aus vollständigen Wiederholungsvergleichen ausgeschlossen.", "",
             "Diese heuristische Stichprobe untersucht breitere tatsächliche Interaktionen und Laufzeiten. Sie beweist weder vollständige Interaktionsabdeckung noch menschliche oder vollständige 550-Karten-Balance. Nicht ausgespielte Karten sind keine automatisch schwachen oder defekten Karten. Ein 500-Aufrufe-Horizont ist ein technischer Abbruch und keine Unentschiedenregel.", "",
             "## Fehler, Zensierung und nicht ausgeführte Fälle", ""]
    lines += ["- " + issue for issue in v["issues"]] or ["Keine Fehler/Zensierung und alle geplanten Fälle/Kontrollen vollständig."]
    lines += ["", "Die unveränderten Rohdaten, der Plan und gegebenenfalls das geflushte Journal bleiben erhalten. Die JSON-Zusammenfassung enthält jeden tatsächlichen Fall samt Digest und die vollständigen Listen fehlgeschlagener und nicht ausgeführter Fälle. Bei Unterbrechung werden nur vollständig geflushte Journalzeilen rekonstruiert; unvollständige letzte Zeilen bleiben im Originaljournal erhalten.", "", "## Ressourcen und tatsächliche Effekte", "",
              "Energie wird als beobachtete Aktionsphasen-Verfügbarkeit, bekannte gedruckte Kosten erfolgreicher Ausspielvorgänge und Restenergie beim Zugabschluss ausgewiesen. Diese Werte sind keine geschlossene Bruttobilanz. Resonanzwerte sind Nettodifferenzen je Aktion; gleichzeitige Erzeugung und Verbrauch können sich aufheben. Peaks erfassen beobachtete Grenzen, nicht jeden internen Zwischenwert.", "",
              "| Messwert über Matrixversuche | Wert |", "|---|---:|"]
    log_note = (f"Engine-Log geprüft: {len(summary['runtime_log_errors'])} Fehlerzeilen. `last_case_start_seen` nennt nur die zuletzt protokollierte Fallöffnung, keine bewiesene Fehlerursache."
                if summary["runtime_log_checked"] else "Engine-Log fehlt; stderr-Laufzeitfehler wurden nicht als abwesend behauptet.")
    log_note += (f" Beobachteter Engine-Exitcode: {summary['engine_exit_code']}."
                 if summary["engine_exit_code"] is not None else " Engine-Exitcode fehlt; ein erfolgreicher Prozessabschluss ist nicht verifiziert.")
    at = lines.index("## Ressourcen und tatsächliche Effekte")
    lines[at:at] = [log_note, ""]
    lines += [f"| {key} | {value} |" for key, value in summary["resources_observed"].items()]
    lines += ["", "Generische Operationen zählen tatsächliche Runtime-Einträge nach Effekt und Status; native Ereignisarten sind Trace-Zähler, keine vollständige Einzelhandler-Abdeckung. Ausspiel- und Effektzahlen stammen nicht aus den gedruckten Fähigkeitslisten.", "", "| Tatsächlicher Effekt/Status | Runtime-Einträge |", "|---|---:|"]
    lines += [f"| {key} | {value} |" for key, value in summary["generic_effect_operations"].items()]
    lines += ["", "## Gerichtete Paarungen", "", "| Hero / Enemy | Versuche | Beendet | Zensiert | Fehler | Siege Hero/Enemy/Draw | Ø beobachtete Halbzüge |", "|---|---:|---:|---:|---:|---|---:|"]
    for pair, stats in summary["directed_pairs"].items():
        mean = "–" if stats["mean_round_observed"] is None else f"{stats['mean_round_observed']:.2f}"
        lines.append(f"| {pair} | {stats['attempts']} | {stats['completed']} | {stats['censored']} | {stats['errors']} | {stats['hero_wins']}/{stats['enemy_wins']}/{stats['draws']} | {mean} |")
    perf = summary["performance_wall_time"]
    lines += ["", "## Laufzeitbeobachtung", "",
              "Gemessen wird reale Wandzeit von Aufbau/Öffnung bis zur Rückkehr der vollständigen Zugschleife. Last, geteilte Hardware und Ausgabe beeinflussen diese Werte; sie sind keine garantierte Gerätegeschwindigkeit. Planungsproben und Berichtsausgabe gehören nicht zu den einzelnen Matrix-Wandzeiten.", "",
              "| Wandzeit-Messwert | Mikrosekunden |", "|---|---:|"]
    lines += [f"| {key} | {value if value is not None else '–'} |" for key, value in perf.items()]
    lines += ["", "## Explizit nicht ausgespielte Karten", "", "| ID | Name | Macht | Typ |", "|---|---|---|---|"]
    lines += [f"| {c['id']} | {c['name'].replace('|', '/')} | {c['power']} | {c['kind']} |" for c in summary["unplayed_cards"]]
    if not summary["unplayed_cards"]: lines.append("| – | Alle550 IDs beobachtet ausgespielt; vollständige Balance dennoch nicht belegt. | – | – |")
    exit_code = str(summary["engine_exit_code"]) if summary["engine_exit_code"] is not None else "BEOBACHTETER_EXITCODE"
    lines += ["", "## Quellen und Reproduktion", "", f"Core: `{CORE}`. Godot: `{report['godot']}`. Der JSON-Bericht bindet Rohdaten-, Plan-, Journal-, Engine-Log- und Reporterhash sowie alle20 ausgeführten Quellen. Vollständige Decklisten und alle Fall-/Seed-/Startseitenangaben bleiben in den Rohdaten und im Plan.", "", "Der Wrapper übergibt den tatsächlichen Engine-Exitcode. Der Wert 0 darf bei manueller Reproduktion nur für einen wirklich erfolgreichen Prozessabschluss verwendet werden; ein Fehlercode darf nicht durch 0 ersetzt werden. Ein fehlender Exitcode bleibt unverifiziert und kann keinen bestandenen Bericht erzeugen.", "", "```sh", "bash tools/test_production_full_pool_coverage.sh", f"python3 tools/production/report_full_pool_coverage.py --source work/production/full-pool-coverage.json --plan work/production/full-pool-coverage-plan.json --journal work/production/full-pool-coverage-journal.jsonl --engine-log work/production/full-pool-coverage.log --engine-exit-code {exit_code} --verify-rejections", "```", ""]
    return "\n".join(lines)


def atomic(path, data, check=False):
    if check:
        require(path.read_bytes() == data, "Report differs from reproducible output: " + path.name)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_bytes(data)
    temp.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "work/production/full-pool-coverage.json")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--journal", type=Path)
    parser.add_argument("--engine-log", type=Path)
    parser.add_argument("--engine-exit-code", type=int)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "docs/production/full-pool")
    parser.add_argument("--verify-rejections", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    plan_path = args.plan or args.source.with_name(args.source.stem + "-plan.json")
    journal_path = args.journal
    if journal_path is None:
        candidate = args.source.with_name(args.source.stem + "-journal.jsonl")
        if candidate.exists(): journal_path = candidate
    # Stable logical artifact names allow identical-byte rechecks after moving
    # inputs from the working run directory into the committed evidence folder.
    provenance = {"source_path": "FULL_POOL_GAMES.json", "plan_path": "FULL_POOL_PLAN.json",
                  "journal_path": "FULL_POOL_JOURNAL.jsonl" if journal_path else None,
                  "engine_log_path": "FULL_POOL_ENGINE.log" if args.engine_log else None,
                  "observed_engine_exit_code": args.engine_exit_code,
                  "reporter_sha256": sha(Path(__file__).read_bytes())}
    raw = plan_raw = journal_raw = engine_log_raw = None
    try:
        # Preserve actual material before parsing or making any acceptance claim.
        read_errors = []
        def preserve(path, name):
            if path is None:
                return None
            try:
                data = path.read_bytes()
                atomic(args.output_dir / name, data, args.check)
                return data
            except OSError as error:
                read_errors.append(str(error))
                return None
        engine_log_raw = preserve(args.engine_log, "FULL_POOL_ENGINE.log")
        raw = preserve(args.source, "FULL_POOL_GAMES.json")
        plan_raw = preserve(plan_path, "FULL_POOL_PLAN.json")
        journal_raw = preserve(journal_path, "FULL_POOL_JOURNAL.jsonl")
        for name, data in (("engine_log_sha256", engine_log_raw), ("raw_evidence_sha256", raw),
                           ("plan_sha256", plan_raw), ("journal_sha256", journal_raw)):
            provenance[name] = sha(data) if data is not None else None
        require(not read_errors, "Missing/unreadable evidence: " + "; ".join(read_errors))
        provenance.update(raw_evidence_sha256=sha(raw), plan_sha256=sha(plan_raw), journal_sha256=sha(journal_raw) if journal_raw is not None else None)
        report, plan = json.loads(raw), json.loads(plan_raw)
        warnings, reconstructed = [], False
        if journal_raw is not None:
            journal_rows, warnings = read_journal(journal_raw)
            report, reconstructed = recover_journal(report, journal_rows)
        ctx = context()
        validation = validate(report, plan, sha(plan_raw), ctx, reconstructed, warnings)
        log_errors = runtime_log_errors(engine_log_raw) if engine_log_raw is not None else []
        if log_errors:
            validation["issues"].append(f"Engine stderr/log contains {len(log_errors)} actual runtime error/leak/failure lines.")
            validation["passed"] = False
        if engine_log_raw is None:
            validation["issues"].append("Engine log not supplied; runtime stderr health is unverified.")
            validation["passed"] = False
        if args.engine_exit_code is None:
            validation["issues"].append("Actual engine exit code not supplied; successful process completion is unverified.")
            validation["passed"] = False
        elif args.engine_exit_code != 0:
            validation["issues"].append(f"Actual engine process failed with exit code {args.engine_exit_code}.")
            validation["passed"] = False
        guards = rejection_checks(report, plan, sha(plan_raw), ctx) if args.verify_rejections else {"tested": [], "skipped_reason": "Not requested"}
        summary = summarize(report, plan, ctx, validation)
        summary.update(schema_version=1, suite=SUITE, base_core_commit=CORE, provenance=provenance,
                       runtime_log_checked=engine_log_raw is not None, runtime_log_errors=log_errors,
                       engine_exit_code=args.engine_exit_code,
                       source_sha256=report["source_sha256"], core_source_sha256=ctx["core_hashes"], executed_commit=report["executed_commit"],
                       engine_assertions_snapshot=report["assertions"], engine_failures_snapshot=report["failures"],
                       negative_evidence_guards=guards, measurement_notes=report["measurement_notes"])
        atomic(args.output_dir / "FULL_POOL_COVERAGE.json", (json.dumps(summary, ensure_ascii=False, indent=2) + "\n").encode(), args.check)
        atomic(args.output_dir / "FULL_POOL_COVERAGE.md", markdown(summary, report, guards).encode(), args.check)
        print(f"FULL-POOL REPORT: {summary['status'].upper()}; {summary['matrix_attempts']}/256 recorded attempts; {summary['observed_played_unique_ids']}/550 actually played; {len(validation['not_completed_or_unrun_cases'])} unfinished-or-unrun; {len(guards['tested'])} corrupt copies rejected")
        return 0 if validation["passed"] else 1
    except (OSError, ValueError, KeyError, TypeError, IndexError, subprocess.CalledProcessError) as error:
        failure = {"schema_version": 1, "suite": SUITE, "status": "failed_invalid_evidence",
                   "validation_errors": [str(error)], "provenance": provenance,
                   "raw_preserved": raw is not None, "plan_preserved": plan_raw is not None,
                   "journal_preserved": journal_raw is not None,
                   "engine_log_preserved": engine_log_raw is not None,
                   "runtime_log_errors": runtime_log_errors(engine_log_raw) if engine_log_raw is not None else [],
                   "engine_exit_code": args.engine_exit_code,
                   "coverage_claim": None, "note": "Invalid evidence is preserved; no successful coverage or replacement outcome is invented."}
        if not args.check:
            atomic(args.output_dir / "FULL_POOL_COVERAGE.json", (json.dumps(failure, ensure_ascii=False, indent=2) + "\n").encode())
            atomic(args.output_dir / "FULL_POOL_COVERAGE.md", ("# Full-Pool-Selbstspiel: NICHT BESTANDEN\n\nUngültiger oder unvollständiger Nachweis: " + str(error) + "\n\nVorhandene Rohdaten, Plan und Journal bleiben erhalten. Es wird keine Coverage behauptet.\n").encode())
        print("FULL-POOL REPORT: FAILED_INVALID_EVIDENCE; " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
