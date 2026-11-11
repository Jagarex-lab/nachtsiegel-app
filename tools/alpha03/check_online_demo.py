#!/usr/bin/env python3
"""Validate completed online QA output without conflating transport and combat."""
import argparse
import json
import re
from pathlib import Path


def summary(text: str) -> dict:
    # npm/Node banners precede one pretty-printed JSON result. A partial JSON,
    # multiple results or trailing diagnostics must never count as completion.
    # npm may append its own update notice after a successfully completed CLI.
    starts = list(re.finditer(r"(?m)^\{", text))
    if len(starts) != 1:
        raise ValueError("Expected exactly one completed online demo JSON object")
    body = text[starts[0].start():]
    value, end = json.JSONDecoder().raw_decode(body)
    if any(line.strip() and not line.startswith("npm notice") for line in body[end:].splitlines()):
        raise ValueError("Unexpected output after online demo completion")
    if not isinstance(value, dict):
        raise ValueError("Online demo summary must be an object")
    return value


def validate_transport(value: dict) -> None:
    expected = {
        "demo": "two local test accounts; authentication, matchmaking, simulated action, reconnect, completion and history",
        "prototype": "simulation-only; no ORAFOLD combat or capacity guarantee",
        "clients": 2,
        "matches_finished": 1,
        "reconnects": 1,
        "expected_security_rejections": 1,
        "unexpected_errors": [],
    }
    for key, required in expected.items():
        if type(value.get(key)) is not type(required) or value[key] != required:
            raise ValueError(f"Incomplete transport fixture: {key}")
    requests = value.get("successful_ws_requests")
    if type(requests) is not int or requests < 12 or value.get("attempted_measured_ws_requests") != requests:
        raise ValueError("Transport fixture did not complete every measured request")


def validate_production(value: dict) -> None:
    if value.get("simulation") is not False or value.get("rules") != "orafold550-godot-4.6.3-alpha03" or value.get("card_count") != 550:
        raise ValueError("Expected the actual 550-card production Godot rules")
    result = value.get("result")
    if not isinstance(result, dict) or result.get("reason") != "duel" or "winner_id" not in result:
        raise ValueError("Production duel must reach its actual terminal result")
    if result["winner_id"] is not None and (not isinstance(result["winner_id"], str) or not result["winner_id"]):
        raise ValueError("Invalid production duel winner")
    counts = value.get("command_counts")
    if not isinstance(counts, dict) or any(type(count) is not int or count <= 0 for count in counts.values()):
        raise ValueError("Missing accepted production commands")
    if counts.get("mulligan") != 2 or counts.get("origin") != 2 or counts.get("openingDone") != 1 or counts.get("endTurn", 0) < 1:
        raise ValueError("Production duel did not complete both openings and combat")
    if type(value.get("actions")) is not int or value["actions"] != sum(counts.values()):
        raise ValueError("Production replay action count does not match accepted commands")
    if not re.fullmatch(r"[0-9a-f]{64}", value.get("final_state_hash", "")):
        raise ValueError("Missing final production replay state hash")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", choices=("transport", "production"))
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    value = summary(args.log.read_text(encoding="utf-8"))
    (validate_transport if args.scope == "transport" else validate_production)(value)
    print("ONLINE TRANSPORT FIXTURE: completed; simulation-only" if args.scope == "transport" else "ONLINE PRODUCTION DUEL: completed; actual Godot rules")


if __name__ == "__main__":
    main()
