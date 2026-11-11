#!/usr/bin/env python3
"""Strict production-data checks, separate from runtime playability evidence.

This deliberately does not equate schema acceptance with a tested card effect.
Runtime probes, native games, replay and browser QA remain separate CI gates.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POWERS = {"houses", "stillwatch", "morph", "ninth", "neutral"}
SPECIES = {"human", "beast", "spirit", "construct", "plant", "amalgam", "morphid", "paradox", "revenant", "elemental", "devourer", "mechanoid"}
RARITIES = {"common", "rare", "epic", "legendary"}
TRIGGERS = {"on_play", "on_summon", "on_attack", "on_defend", "on_deal_damage", "on_take_damage", "on_kill", "on_death", "on_turn_start", "on_turn_end", "on_lane_change", "on_draw", "on_discard", "on_spend_resonance", "on_relic_activate", "on_condition"}
CATEGORIES = {"deal_damage": "damage", "grant_shield": "protection", "grant_block": "protection", "heal_target": "healing", "modify_attack": "enhancement", "weaken_unit": "weakening", "move_unit": "movement", "summon_card": "summoning", "return_card": "recurrence", "gain_resonance": "resources", "gain_energy": "resources", "draw_cards": "card_manipulation", "discard_card": "card_manipulation", "delay_damage": "time_manipulation", "stun_unit": "control", "haste": "time_manipulation"}
ARCHETYPES = {"aggro", "midrange", "control", "shield", "block", "recurrence", "resonance", "movement", "species", "relic", "impulse", "convergence", "time", "resource_control"}
CARD_FIELDS = {"schema_version", "id", "name", "faction", "order", "kind", "rarity", "cost", "effect", "power", "description", "trigger", "target", "duration", "limit", "atk", "hp", "species", "abilities", "art", "archetypes", "lore_status", "reaction_window"}
NATIVE = {
    "creature": {"strike", "guard", "ward", "mend", "weave", "drain", "rally", "silence", "pierce", "shift", "harvest", "retaliate", "draw", "haste", "weaken", "pulse"},
    "event": {"bolt", "heal", "stasis", "surge", "recall", "delay", "redirect", "displace", "cascade"},
    "relic": {"relic_res", "relic_ward", "relic_heal", "relic_draw"},
}
TARGETS = {
    "deal_damage": {"enemy_hero", "enemy_lane", "opposite_enemy_unit", "enemy_lowest_health", "enemy_all"},
    "grant_shield": {"self", "own_hero", "own_lowest_health", "own_neighbors", "own_all", "own_species"},
    "grant_block": {"own_hero"},
    "heal_target": {"self", "own_hero", "own_lowest_health", "own_all", "own_species"},
    "modify_attack": {"self", "own_lowest_health", "own_neighbors", "own_all", "own_species"},
    "weaken_unit": {"opposite_enemy_unit", "enemy_lowest_health", "enemy_all"},
    "move_unit": {"self", "own_lowest_health", "enemy_lowest_health"},
    "summon_card": {"self"}, "return_card": {"self"}, "gain_resonance": {"self"}, "gain_energy": {"self"}, "draw_cards": {"self"}, "discard_card": {"self"},
    "delay_damage": {"enemy_lane"}, "stun_unit": {"opposite_enemy_unit", "enemy_lowest_health"}, "haste": {"self"},
}


def integer(value, low, high):
    return type(value) is int and low <= value <= high


def normalized_name(value):
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def mechanical_signature(card, include_power=True):
    # Name/art/ID are deliberately absent. Species affect real selectors; power
    # affects legal deck membership. Rarity changes the legendary copies limit.
    fields = ["kind", "cost", "atk", "hp", "effect", "power", "abilities", "species", "rarity", "reaction_window"]
    if include_power:
        fields.append("faction")
    return json.dumps({key: card.get(key) for key in fields}, sort_keys=True, ensure_ascii=False)


def validate(document, root=ROOT):
    errors = []
    warnings = []
    if not isinstance(document, dict) or not isinstance(document.get("cards"), list):
        return {"ok": False, "errors": ["cards must be an array"], "warnings": []}
    cards = document["cards"]
    if len(cards) != 550:
        errors.append(f"Expected 550 active cards, got {len(cards)}")
    ids, names, by_id, signatures = set(), set(), {}, {}
    powers, kinds, rarities, species_counts, triggers, categories, modes = (collections.Counter() for _ in range(7))
    generic = 0
    for index, card in enumerate(cards):
        where = f"cards[{index}]"
        if not isinstance(card, dict):
            errors.append(where + ": must be an object")
            continue
        identity = card.get("id")
        where = str(identity or where)
        if not isinstance(identity, str) or not re.fullmatch(r"(?:oa|of)-(?:houses|stillwatch|morph|ninth|neutral)-[a-z0-9]+", identity):
            errors.append(where + ": invalid stable identity")
        elif identity in ids:
            errors.append(where + ": duplicate identity")
        else:
            ids.add(identity)
            by_id[identity] = card
        if set(card) - CARD_FIELDS:
            errors.append(where + ": unknown card fields " + str(sorted(set(card) - CARD_FIELDS)))
        name = card.get("name")
        if not isinstance(name, str) or not 1 <= len(name) <= 64 or name != name.strip():
            errors.append(where + ": invalid display name")
        elif normalized_name(name) in names:
            errors.append(where + ": duplicate display name")
        else:
            names.add(normalized_name(name))
        faction, kind, rarity = card.get("faction"), card.get("kind"), card.get("rarity")
        if faction not in POWERS or card.get("order") != faction:
            errors.append(where + ": invalid power/order")
        else:
            powers[faction] += 1
        if kind not in NATIVE:
            errors.append(where + ": unknown main card kind")
            continue
        kinds[kind] += 1
        if rarity not in RARITIES:
            errors.append(where + ": unknown rarity")
        else:
            rarities[rarity] += 1
        if not integer(card.get("cost"), 1, 8):
            errors.append(where + ": energy outside tested production curve 1..8")
        if kind == "creature":
            if not integer(card.get("atk"), 0, 30) or not integer(card.get("hp"), 1, 40):
                errors.append(where + ": invalid creature stats")
            types = card.get("species")
            if not isinstance(types, list) or not 1 <= len(types) <= 2 or len(set(types)) != len(types) or any(value not in SPECIES for value in types):
                errors.append(where + ": requires one/two distinct supported species")
            else:
                species_counts.update(types)
        elif any(key in card for key in ["atk", "hp", "species"]):
            errors.append(where + ": impulse/relic must not contain creature stats or species")
        if not isinstance(card.get("archetypes"), list) or any(tag not in ARCHETYPES for tag in card.get("archetypes", [])):
            errors.append(where + ": unknown archetype")
        if card.get("lore_status") not in ["ARBEITSSTAND", "VORSCHLAG"]:
            errors.append(where + ": unsupported implicit lore canonization")
        description = card.get("description")
        if not isinstance(description, str) or not description or len(description) > 1000 or any(word in description.casefold() for word in ["todo", "placeholder", "platzhalter", "tbd"]):
            errors.append(where + ": missing/promissory card text")
        elif any(bad in description for bad in ["Heile deinem", "Betäube dem ", "Versetze dem ", "Angriff von dem"]):
            errors.append(where + ": invalid German object case")
        art = card.get("art")
        if not isinstance(art, dict) or set(art) != {"status", "asset_id", "provenance"} or art.get("status") not in ["missing", "shared_concept", "concept", "final"]:
            errors.append(where + ": invalid art declaration")
        elif art["status"] == "missing" and art["asset_id"] != "missing:" + str(identity):
            errors.append(where + ": missing art must bind its exact identity")
        if card.get("effect") != "v2":
            if card.get("effect") not in NATIVE[kind] or not integer(card.get("power"), 1, 30) or "abilities" in card:
                errors.append(where + ": unknown native handler or duplicate generic execution")
        else:
            generic += 1
            if card.get("schema_version") != 3 or card.get("power") != 0:
                errors.append(where + ": generic schema/power binding invalid")
            abilities = card.get("abilities")
            if not isinstance(abilities, list) or not 1 <= len(abilities) <= 3:
                errors.append(where + ": requires one to three actual abilities")
                continue
            for ability_index, a in enumerate(abilities):
                label = f"{where}.abilities[{ability_index}]"
                check_ability(a, kind, label, errors)
                if isinstance(a, dict):
                    if a.get("mode") in ["triggered", "reactive"]:
                        triggers[a.get("trigger")] += 1
                    categories[CATEGORIES.get(a.get("effect"), "UNKNOWN")] += 1
                    modes[a.get("mode")] += 1
            reactive = any(a.get("mode") == "reactive" for a in abilities if isinstance(a, dict))
            if kind == "event" and reactive and card.get("reaction_window") != "until_next_own_turn":
                errors.append(where + ": reactive impulse missing explicit expiry window")
            if "reaction_window" in card and (kind != "event" or not reactive):
                errors.append(where + ": orphan reaction window")
        signature = mechanical_signature(card)
        if signature in signatures:
            errors.append(where + ": duplicate same-power mechanical identity with " + signatures[signature])
        else:
            signatures[signature] = where
    for power in POWERS:
        if powers[power] != 110:
            errors.append(f"{power}: requires 110 cards, got {powers[power]}")
    if not all(species_counts[key] for key in SPECIES):
        errors.append("Not all twelve creature species are represented")
    if set(triggers) != TRIGGERS:
        errors.append("Missing/unknown generic trigger families: " + str(sorted(set(triggers) ^ TRIGGERS)))
    if set(categories) != set(CATEGORIES.values()):
        errors.append("Missing/unknown effect categories")
    if set(modes) != {"triggered", "activated", "passive", "reactive"}:
        errors.append("Missing/unknown ability modes")
    for card in cards:
        if not isinstance(card, dict):
            continue
        for a in card.get("abilities", []):
            if isinstance(a, dict) and a.get("effect") == "summon_card":
                summoned = by_id.get(a.get("params", {}).get("card_id"), {})
                if summoned.get("kind") != "creature" or summoned.get("faction") not in [card.get("faction"), "neutral"]:
                    errors.append(str(card.get("id")) + ": summon source must be an existing own/neutral creature")
    starters = document.get("starters")
    if not isinstance(starters, dict) or set(starters) != POWERS - {"neutral"}:
        errors.append("Exactly four power starter decks required")
    else:
        for power, deck in starters.items():
            errors += validate_deck(deck, by_id, "starter " + power, power)
    # Artwork/profile equivalence is reported separately from complete identity:
    # different factions constrain deck legality but can intentionally share basics.
    cross_power = collections.defaultdict(list)
    for card in cards:
        if isinstance(card, dict):
            cross_power[mechanical_signature(card, False)].append(card.get("id"))
    overlaps = [group for group in cross_power.values() if len(group) > 1]
    if overlaps:
        warnings.append(f"{len(overlaps)} cross-power equivalent mechanical groups; different faction/deck legality, not 550 unique effects")
    return {"ok": not errors, "scope": "static_data_not_runtime_playability_or_final_balance", "cards": len(cards), "native_cards": len(cards) - generic, "generic_cards": generic, "powers": dict(powers), "kinds": dict(kinds), "rarities": dict(rarities), "species": dict(species_counts), "triggers": dict(triggers), "categories": dict(categories), "modes": dict(modes), "distinct_same_power_mechanical_identities": len(signatures), "distinct_cross_power_mechanical_identities": len(cross_power), "cross_power_equivalent_groups": overlaps, "errors": errors, "warnings": warnings}


def check_ability(a, kind, label, errors):
    if not isinstance(a, dict):
        errors.append(label + ": must be an object")
        return
    common = {"mode", "effect", "target", "params", "limit"}
    mode, op, target = a.get("mode"), a.get("effect"), a.get("target")
    allowed = common | ({"trigger"} if mode in ["triggered", "reactive"] else set()) | ({"activation"} if mode in ["activated", "reactive"] else set()) | ({"condition"} if a.get("trigger") == "on_condition" else set())
    if set(a) != allowed:
        errors.append(label + ": missing/unknown fields " + str(sorted(set(a) ^ allowed)))
    if mode not in ["triggered", "reactive", "activated", "passive"]:
        errors.append(label + ": unknown ability mode")
    if op not in CATEGORIES:
        errors.append(label + ": unknown executable operation")
        return
    if target not in TARGETS[op]:
        errors.append(label + ": invalid target for operation")
    if a.get("limit") not in ["once_per_event", "once_per_turn", "while_on_board"]:
        errors.append(label + ": unknown limit")
    if mode == "passive" and (op != "haste" or kind != "creature" or a.get("limit") != "while_on_board"):
        errors.append(label + ": only creature haste has a passive execution contract")
    if mode != "passive" and op == "haste":
        errors.append(label + ": haste requires passive mode")
    if mode in ["triggered", "reactive"] and a.get("trigger") not in TRIGGERS:
        errors.append(label + ": unknown trigger")
    if mode in ["activated", "reactive"]:
        costs = a.get("activation")
        if not isinstance(costs, dict) or set(costs) != {"energy", "resonance"} or not integer(costs.get("energy"), 0, 8) or not integer(costs.get("resonance"), 0, 15):
            errors.append(label + ": invalid explicit activation cost")
    if mode == "activated" and (kind != "relic" or a.get("limit") != "once_per_turn"):
        errors.append(label + ": current activations require a once-per-turn relic")
    params = a.get("params")
    if not isinstance(params, dict):
        errors.append(label + ": params must be an object")
        return
    required = set()
    if op in ["deal_damage", "grant_shield", "grant_block", "heal_target", "modify_attack", "weaken_unit", "gain_resonance", "gain_energy", "delay_damage"]:
        required.add("amount")
        high = {"grant_shield": 8, "grant_block": 8, "heal_target": 8, "modify_attack": 4, "weaken_unit": 4, "gain_resonance": 4, "gain_energy": 3, "delay_damage": 8}.get(op, 10)
        if not integer(params.get("amount"), 1, high):
            errors.append(label + ": amount outside executable range")
    if op in ["draw_cards", "discard_card", "return_card", "stun_unit"]:
        required.add("count")
        if not integer(params.get("count"), 1, 2 if op in ["draw_cards", "stun_unit"] else 1):
            errors.append(label + ": count outside executable range")
    if op == "move_unit":
        required.add("steps")
        if type(params.get("steps")) is not int or params["steps"] not in [-1, 1]:
            errors.append(label + ": movement requires exactly one adjacent step")
    if op == "summon_card":
        required.add("card_id")
        if not isinstance(params.get("card_id"), str):
            errors.append(label + ": missing summon identity")
    if op == "delay_damage":
        required.add("turn_changes")
        if not integer(params.get("turn_changes"), 1, 3):
            errors.append(label + ": delay outside executable range")
    if target == "own_species":
        required.add("species")
        if params.get("species") not in SPECIES:
            errors.append(label + ": unknown equal-rank species selector")
    if set(params) != required:
        errors.append(label + ": missing/unknown operation parameters " + str(sorted(set(params) ^ required)))
    if a.get("trigger") == "on_condition":
        condition = a.get("condition")
        if not isinstance(condition, dict) or set(condition) != {"resource", "at_least"} or condition.get("resource") not in ["energy", "resonance", "hand", "controlled_paths"] or not integer(condition.get("at_least"), 1, 15):
            errors.append(label + ": invalid explicit condition")
        elif condition["at_least"] > {"energy": 8, "resonance": 15, "hand": 6, "controlled_paths": 5}[condition["resource"]]:
            errors.append(label + ": unreachable condition threshold")


def validate_deck(deck, by_id, label, power=None):
    errors = []
    if not isinstance(deck, list) or len(deck) != 30:
        return [label + ": requires exactly 30 cards"]
    if any(not isinstance(identity, str) or identity not in by_id for identity in deck):
        return [label + ": unknown card identity"]
    factions = {by_id[identity]["faction"] for identity in deck} - {"neutral"}
    if len(factions) != 1 or (power is not None and factions != {power}):
        errors.append(label + ": exactly the selected power plus neutral cards")
    for identity, count in collections.Counter(deck).items():
        if count > (1 if by_id[identity]["rarity"] == "legendary" else 3):
            errors.append(label + ": copy limit " + identity)
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs="?", type=Path, default=ROOT / "data/production/cards.json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.file.read_text()))
    result["sha256"] = hashlib.sha256(args.file.read_bytes()).hexdigest()
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded, end="")
    raise SystemExit(0 if result["ok"] else 1)


if __name__ == "__main__":
    main()
