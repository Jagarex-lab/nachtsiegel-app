#!/usr/bin/env python3
"""Build legal full-pool exposure decks from unchanged production definitions.

Membership coverage is a fixture property, never evidence that a card was played.
Every deck keeps a fixed starter-derived creature core and an actual recurring
attack-growth relic. No card, mechanic, policy or match outcome is changed here.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "tests/fixtures/production/full_pool_decks.json"
POWERS = ("houses", "stillwatch", "morph", "ninth")
DECKS_PER_POWER = 8
DECK_SIZE = 30
MIN_CREATURES = 18
MIN_LOW_COST = 8
SOURCES = ("data/production/cards.json", "data/production/starters.json")

# Actual starter identities, with two recurring attack-growth relics rather than
# a mostly defensive relic mix. Two copies leave a legal spare copy limit.
CORES = {
    "houses": ["oa-houses-c01"] * 2 + ["of-houses-001"] * 2
    + ["of-neutral-049"] * 2 + ["of-houses-062"] * 2
    + ["of-houses-057", "of-houses-058"] + ["of-houses-094"] * 2,
    "stillwatch": ["oa-stillwatch-c01"] * 2 + ["of-stillwatch-001"] * 2
    + ["of-neutral-049"] * 2
    + ["of-stillwatch-050", "of-stillwatch-056", "of-stillwatch-057", "of-neutral-057"]
    + ["of-stillwatch-097"] * 2,
    "morph": ["oa-morph-c01"] * 2 + ["of-morph-001"] * 2
    + ["of-morph-031"] * 2 + ["of-morph-032"] * 2 + ["of-morph-038"] * 2
    + ["of-morph-096"] * 2,
    "ninth": ["oa-ninth-c01"] * 2 + ["of-ninth-001"] * 2
    + ["of-ninth-043"] * 2
    + ["of-ninth-044", "of-ninth-050", "of-ninth-046", "of-neutral-049"]
    + ["of-neutral-092"] * 2,
}
FINISHERS = {
    "houses": "of-houses-094",
    "stillwatch": "of-stillwatch-097",
    "morph": "of-morph-096",
    "ninth": "of-neutral-092",
}
KIND_ORDER = {"creature": 0, "event": 1, "relic": 2}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def copy_limit(card: dict) -> int:
    return 1 if card["rarity"] == "legendary" else 3


def card_key(card: dict) -> tuple:
    return int(card["cost"]), KIND_ORDER[card["kind"]], card["id"]


def card_metrics(ids: list[str], by_id: dict[str, dict]) -> dict:
    return {
        "creatures": sum(by_id[id]["kind"] == "creature" for id in ids),
        "kind_counts": dict(sorted(collections.Counter(by_id[id]["kind"] for id in ids).items())),
        "cost_curve": {str(k): v for k, v in sorted(collections.Counter(int(by_id[id]["cost"]) for id in ids).items())},
        "low_cost_copies": sum(int(by_id[id]["cost"]) <= 3 for id in ids),
        "unique_card_ids": len(set(ids)),
        "total_printed_cost": sum(int(by_id[id]["cost"]) for id in ids),
    }


def growth_ability(card: dict) -> dict:
    matches = [a for a in card.get("abilities", [])
               if a.get("mode") == "triggered" and a.get("trigger") == "on_turn_start"
               and a.get("effect") == "modify_attack" and a.get("target") == "own_lowest_health"
               and int(a.get("params", {}).get("amount", 0)) > 0]
    require(card["kind"] == "relic" and len(matches) == 1,
            "Finisher lost its actual recurring attack-growth operation: " + card["id"])
    return matches[0]


def allocate_exposure(cards: list[dict]) -> list[list[str]]:
    """Balance actual distinct cards, without removing difficult/expensive ones."""
    bins: list[list[str]] = [[] for _ in range(DECKS_PER_POWER)]
    kinds = [collections.Counter() for _ in bins]
    costs = [0 for _ in bins]
    # Deal expensive cards first within each kind, then keep kind counts and
    # total list lengths balanced; stable identity is the final tie-breaker.
    ordered = sorted(cards, key=lambda c: (KIND_ORDER[c["kind"]], -int(c["cost"]), c["id"]))
    for card in ordered:
        legal = [i for i in range(DECKS_PER_POWER) if len(bins[i]) < DECK_SIZE - 12]
        require(bool(legal), "Exposure pool exceeds fixed available deck slots")
        index = min(legal, key=lambda i: (kinds[i][card["kind"]], len(bins[i]), costs[i], i))
        bins[index].append(card["id"])
        kinds[index][card["kind"]] += 1
        costs[index] += int(card["cost"])
    return bins


def validate_decks(decks: list[dict], by_id: dict[str, dict], starters: dict) -> None:
    expected = {f"full-pool-{power}-{i:02}" for power in POWERS for i in range(1, DECKS_PER_POWER + 1)}
    require(len(decks) == len(expected) and {d["id"] for d in decks} == expected,
            "Expected exactly32 distinct predeclared deck identities")
    membership: set[str] = set()
    exposures: list[str] = []
    for deck in decks:
        power = deck["power"]
        require(power in POWERS and deck["id"].startswith("full-pool-" + power + "-"), "Wrong deck power")
        ids = deck["cards"]
        require(len(ids) == DECK_SIZE and set(ids) <= set(by_id), "Wrong deck size or unknown card")
        counts = collections.Counter(ids)
        require(all(by_id[id]["faction"] in (power, "neutral") for id in ids), "Cross-power deck")
        require(any(by_id[id]["faction"] == power for id in ids), "Neutral-only deck")
        require(all(n <= copy_limit(by_id[id]) for id, n in counts.items()), "Card copy limit exceeded")
        require(deck["core_card_ids"] == CORES[power], "Changed predeclared starter core")
        require(len(set(deck["exposure_card_ids"])) == len(deck["exposure_card_ids"]), "Duplicate exposure identity")
        require(counts == collections.Counter(deck["core_card_ids"] + deck["exposure_card_ids"] + deck["filler_card_ids"]), "Core/exposure/filler metadata differs from playable list")
        metrics = card_metrics(ids, by_id)
        require(metrics["creatures"] >= MIN_CREATURES, "Insufficient real creatures")
        require(metrics["low_cost_copies"] >= MIN_LOW_COST, "Insufficient low-cost cards")
        require(deck["metrics"] == metrics, "Incorrect composition metrics")
        require(counts[FINISHERS[power]] == 2, "Missing actual recurring growth finisher")
        require(sum((collections.Counter(deck["core_card_ids"]) & collections.Counter(starters[power])).values()) >= 8,
                "Core no longer retains a substantial actual starter skeleton")
        require(all(by_id[id]["kind"] == "creature" and id in starters[power] for id in deck["filler_card_ids"]), "Filler is not an actual starter creature")
        growth_ability(by_id[FINISHERS[power]])
        membership.update(ids)
        exposures.extend(deck["exposure_card_ids"])
    require(membership == set(by_id), "Full550 membership coverage missing identities")
    core_membership = {id for core in CORES.values() for id in core}
    require(len(exposures) == len(set(exposures)), "Exposure card assigned to multiple decks")
    require(set(exposures) == set(by_id) - core_membership, "Exposure allocation is not the exact non-core catalog")


def build_fixture() -> dict:
    source = json.loads((ROOT / SOURCES[0]).read_text())
    cards: list[dict] = source["cards"]
    by_id = {card["id"]: card for card in cards}
    starters = json.loads((ROOT / SOURCES[1]).read_text())
    require(len(cards) == len(by_id) == 550, "Expected the actual550-card catalog")
    require(set(starters) == set(POWERS), "Expected four actual starter lists")
    core_membership = {id for core in CORES.values() for id in core}
    require(core_membership <= set(by_id), "Core card missing from actual catalog")
    for power, core in CORES.items():
        require(len(core) == 12, "Expected fixed12-card core")
        require(sum(by_id[id]["kind"] == "creature" for id in core) == 10, "Expected10-creature starter core")
        growth_ability(by_id[FINISHERS[power]])

    # Every remaining neutral identity has one exposure owner. Kind-stratified
    # round-robin assignment spreads neutral creatures/impulses/relics widely.
    neutral_by_power: dict[str, list[dict]] = {power: [] for power in POWERS}
    neutral = sorted((c for c in cards if c["faction"] == "neutral" and c["id"] not in core_membership),
                     key=lambda c: (KIND_ORDER[c["kind"]], int(c["cost"]), c["id"]))
    for index, card in enumerate(neutral):
        neutral_by_power[POWERS[index % len(POWERS)]].append(card)

    decks = []
    for power in POWERS:
        exposure_pool = [c for c in cards if c["faction"] == power and c["id"] not in core_membership] + neutral_by_power[power]
        bins = allocate_exposure(exposure_pool)
        for index, exposure in enumerate(bins, 1):
            chosen = CORES[power] + exposure
            fillers: list[str] = []
            while len(chosen) < DECK_SIZE:
                counts = collections.Counter(chosen)
                legal = {id for id in starters[power]
                         if by_id[id]["kind"] == "creature" and counts[id] < copy_limit(by_id[id])}
                require(bool(legal), "No legal actual starter creature filler")
                # Prefer diversity, then inexpensive real starter creatures.
                id = min(legal, key=lambda id: (counts[id], int(by_id[id]["cost"]), -int(by_id[id].get("atk", 0)), id))
                chosen.append(id)
                fillers.append(id)
            chosen.sort(key=lambda id: card_key(by_id[id]))
            decks.append({
                "id": f"full-pool-{power}-{index:02}", "power": power,
                "source_starter": power,
                "core_card_ids": CORES[power].copy(),
                "exposure_card_ids": sorted(exposure), "filler_card_ids": fillers,
                "finisher_card_ids": [FINISHERS[power]],
                "cards": chosen, "metrics": card_metrics(chosen, by_id),
            })
    validate_decks(decks, by_id, starters)
    membership_counts = collections.Counter(id for deck in decks for id in set(deck["cards"]))
    slot_counts = collections.Counter(id for deck in decks for id in deck["cards"])
    return {
        "schema_version": 1, "format": "ORAFOLD-FULL-POOL-COVERAGE-DECKS",
        "ruleset_id": "production-550-v1", "generator": "tools/production/build_full_pool_decks.py",
        "source_sha256": {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCES},
        "scope": "Deterministic legal deck membership fixture; membership never means actual play or full balance coverage.",
        "method": {
            "decks_per_power": DECKS_PER_POWER, "core_copies": 12,
            "core_creatures": 10, "minimum_creatures": MIN_CREATURES,
            "minimum_cost_at_most3": MIN_LOW_COST,
            "exposure": "Each non-core actual card identity appears once in a kind/size/cost-balanced exposure allocation; remaining neutral identities are assigned round-robin across powers.",
            "fillers": "Only unchanged actual starter creatures; diversity and low cost break deterministic ties.",
            "limitation": "Growth finishers provide an ordinary legal win plan, not a guarantee against censoring. Difficult/prerequisite cards are retained, including oa-ninth-e01.",
        },
        "finisher_definitions": {power: {
            "card_id": id, "name": by_id[id]["name"], "printed_text": by_id[id]["description"],
            "actual_growth_ability": growth_ability(by_id[id]),
        } for power, id in FINISHERS.items()},
        "summary": {
            "decks": len(decks), "slots": sum(len(d["cards"]) for d in decks),
            "unique_member_ids": len(membership_counts), "missing_member_ids": sorted(set(by_id) - set(membership_counts)),
            "exposure_unique_ids": len(set(id for d in decks for id in d["exposure_card_ids"])),
            "core_unique_ids": len(core_membership),
            "minimum_creatures": min(d["metrics"]["creatures"] for d in decks),
            "minimum_cost_at_most3": min(d["metrics"]["low_cost_copies"] for d in decks),
        },
        "membership_deck_counts": dict(sorted(membership_counts.items())),
        "membership_slot_counts": dict(sorted(slot_counts.items())),
        "decks": decks,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    fixture = build_fixture()
    text = json.dumps(fixture, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        require(OUTPUT.read_text() == text, "Full-pool deck fixture differs from reproducible generator")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        temp = OUTPUT.with_suffix(".json.tmp")
        temp.write_text(text)
        temp.replace(OUTPUT)
    summary = fixture["summary"]
    print(f"FULL-POOL DECKS: {summary['decks']} legal30-card lists; {summary['unique_member_ids']}/550 member IDs; minimum {summary['minimum_creatures']} creatures and {summary['minimum_cost_at_most3']} cost<=3 copies; actual play coverage not claimed")


if __name__ == "__main__":
    main()
