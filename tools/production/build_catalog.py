#!/usr/bin/env python3
"""Build the reviewed production inventory from explicit editorial rows.

This writes a candidate catalogue, not a claim that native or browser QA passed.
Card names/species are individually authored in authored_names.py; rules are
composed from a small generic effect vocabulary instead of per-card engine code.
The source concepts remain archived proposals and are mapped explicitly.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path

from authored_names import CREATURES, EVENTS, RELICS, rows

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data/production"
POWERS = ["houses", "stillwatch", "morph", "ninth", "neutral"]
POWER_NAMES = {"houses": "Zwölf Häuser", "stillwatch": "Stillwacht", "morph": "Vielgestalt", "ninth": "Neunte Stunde", "neutral": "Neutral"}
SPECIES = {"human": "Menschen", "beast": "Bestien", "spirit": "Geister", "construct": "Konstrukte", "plant": "Pflanzen", "amalgam": "Amalgame", "morphid": "Morphiden", "paradox": "Paradoxe", "revenant": "Wiedergänger", "elemental": "Elementare", "devourer": "Zehrer", "mechanoid": "Mechanoide"}
TRIGGER_DE = {
    "on_play": "Beim Ausspielen", "on_summon": "Beim Beschwören", "on_attack": "Beim Angreifen",
    "on_defend": "Beim Verteidigen", "on_deal_damage": "Beim Verursachen von Schaden",
    "on_take_damage": "Beim Erleiden von Schaden", "on_kill": "Beim Besiegen eines Wesens",
    "on_death": "Wenn dieses Wesen besiegt wird", "on_turn_start": "Zu deinem Zugbeginn",
    "on_turn_end": "Zu deinem Zugende", "on_lane_change": "Beim Pfadwechsel",
    "on_draw": "Wenn du eine Karte ziehst", "on_discard": "Wenn du eine Karte abwirfst",
    "on_spend_resonance": "Wenn du Resonanz ausgibst", "on_relic_activate": "Wenn du ein Relikt aktivierst",
    "on_condition": "Wenn die Bedingung erstmals in diesem Zug erfüllt ist",
}
ARCHETYPES = ["aggro", "midrange", "control", "shield", "block", "recurrence", "resonance", "movement", "species", "relic", "impulse", "convergence", "time", "resource_control"]


def ability(effect, target, amount=None, *, trigger="on_summon", mode="triggered", limit="once_per_event", **params):
    if amount is not None:
        params = {"amount": amount, **params}
    value = {"mode": mode, "effect": effect, "target": target, "params": params, "limit": limit}
    if mode in ["triggered", "reactive"]:
        value["trigger"] = trigger
    if mode in ["activated", "reactive"]:
        value["activation"] = {"energy": 1 if mode == "activated" else 0, "resonance": 1}
    return value


def conditional(effect, target, amount, resource="resonance", threshold=5):
    value = ability(effect, target, trigger="on_condition", limit="once_per_turn", count=amount) if effect == "return_card" else ability(effect, target, amount, trigger="on_condition", limit="once_per_turn")
    value["condition"] = {"resource": resource, "at_least": threshold}
    return value


def creature_profile(power, index, species):
    """Fourteen strategic families per power; later cohorts add a new timing axis.

    Cohorts are deliberately not stronger copies: repeated arrival families gain
    death, movement, resource, defensive or conditional hooks with stat costs.
    """
    family, cohort = index % 14, index // 14
    scale = 1 + cohort // 2
    group = species[0]
    if power == "houses":
        plans = [
            [ability("return_card", "self", trigger="on_death", count=1)],
            [ability("heal_target", "own_hero", 2 + scale)],
            [ability("draw_cards", "self", trigger="on_death", count=1)],
            [ability("grant_shield", "self", 1 + scale)],
            [ability("gain_resonance", "self", scale, trigger="on_death")],
            [ability("modify_attack", "own_species", scale, species=group)],
            [ability("grant_block", "own_hero", 1 + scale, trigger="on_take_damage", limit="once_per_turn")],
            [ability("heal_target", "own_lowest_health", 1 + scale, trigger="on_turn_start", limit="once_per_turn")],
            [ability("deal_damage", "opposite_enemy_unit", 1 + scale, trigger="on_attack", limit="once_per_turn")],
            [ability("summon_card", "self", trigger="on_death", card_id="oa-houses-c01")],
            [ability("gain_resonance", "self", scale, trigger="on_kill", limit="once_per_turn")],
            [ability("grant_shield", "own_species", scale, species=group, trigger="on_turn_start", limit="once_per_turn")],
            [ability("heal_target", "own_hero", 1 + scale, trigger="on_discard", limit="once_per_turn")],
            [conditional("return_card", "self", 1, threshold=4 + cohort % 2)],
        ]
        additions = [
            ability("gain_resonance", "self", 1, trigger="on_attack", limit="once_per_turn"),
            ability("grant_shield", "own_lowest_health", 1, trigger="on_turn_start", limit="once_per_turn"),
            ability("heal_target", "own_hero", 2, trigger="on_death"),
            ability("modify_attack", "own_species", 1, trigger="on_relic_activate", limit="once_per_turn", species=group),
        ]
    elif power == "stillwatch":
        plans = [
            [ability("grant_shield", "self", 1 + scale)],
            [ability("grant_block", "own_hero", 1 + scale, trigger="on_defend", limit="once_per_turn")],
            [ability("stun_unit", "opposite_enemy_unit", trigger="on_attack", limit="once_per_turn", count=1)],
            [ability("heal_target", "self", 1 + scale, trigger="on_turn_start", limit="once_per_turn")],
            [ability("weaken_unit", "enemy_lowest_health", scale, trigger="on_take_damage", limit="once_per_turn")],
            [ability("grant_shield", "own_species", scale, species=group)],
            [ability("grant_block", "own_hero", 2 + scale)],
            [ability("grant_shield", "own_hero", scale, trigger="on_draw", limit="once_per_turn")],
            [ability("stun_unit", "enemy_lowest_health", count=1)],
            [ability("draw_cards", "self", trigger="on_defend", limit="once_per_turn", count=1)],
            [ability("heal_target", "own_lowest_health", 2 + scale)],
            [ability("weaken_unit", "opposite_enemy_unit", scale, trigger="on_defend", limit="once_per_turn")],
            [ability("grant_shield", "own_neighbors", scale, trigger="on_turn_end", limit="once_per_turn")],
            [conditional("grant_shield", "own_all", 1, resource="controlled_paths", threshold=3)],
        ]
        additions = [
            ability("grant_block", "own_hero", 1, trigger="on_attack", limit="once_per_turn"),
            ability("gain_resonance", "self", 1, trigger="on_defend", limit="once_per_turn"),
            ability("grant_shield", "own_lowest_health", 2, trigger="on_death"),
            ability("heal_target", "own_hero", 1, trigger="on_relic_activate", limit="once_per_turn"),
        ]
    elif power == "morph":
        plans = [
            [ability("haste", "self", mode="passive", limit="while_on_board")],
            [ability("move_unit", "self", trigger="on_play", steps=1)],
            [ability("modify_attack", "self", scale, trigger="on_lane_change", limit="once_per_turn")],
            [ability("modify_attack", "own_species", scale, species=group)],
            [ability("heal_target", "self", scale, trigger="on_deal_damage", limit="once_per_turn")],
            [ability("grant_shield", "own_neighbors", scale)],
            [ability("summon_card", "self", trigger="on_death", card_id="oa-morph-c01")],
            [ability("move_unit", "self", trigger="on_turn_start", limit="once_per_turn", steps=-1)],
            [ability("gain_resonance", "self", scale, trigger="on_lane_change", limit="once_per_turn")],
            [ability("deal_damage", "opposite_enemy_unit", scale, trigger="on_attack", limit="once_per_turn")],
            [ability("heal_target", "own_species", scale, trigger="on_turn_end", limit="once_per_turn", species=group)],
            [ability("draw_cards", "self", trigger="on_kill", limit="once_per_turn", count=1)],
            [ability("modify_attack", "self", scale, trigger="on_take_damage", limit="once_per_turn")],
            [conditional("grant_shield", "self", 2 + scale, resource="controlled_paths", threshold=2)],
        ]
        additions = [
            ability("grant_shield", "self", 1, trigger="on_lane_change", limit="once_per_turn"),
            ability("modify_attack", "own_neighbors", 1, trigger="on_turn_start", limit="once_per_turn"),
            ability("heal_target", "own_lowest_health", 2, trigger="on_death"),
            ability("gain_resonance", "self", 1, trigger="on_relic_activate", limit="once_per_turn"),
            ability("draw_cards", "self", trigger="on_lane_change", limit="once_per_turn", count=1),
        ]
    elif power == "ninth":
        plans = [
            [ability("delay_damage", "enemy_lane", 1 + scale, turn_changes=2)],
            [ability("gain_resonance", "self", scale, trigger="on_attack", limit="once_per_turn")],
            [ability("grant_shield", "self", scale, trigger="on_spend_resonance", limit="once_per_turn")],
            [ability("draw_cards", "self", trigger="on_relic_activate", limit="once_per_turn", count=1)],
            [ability("stun_unit", "opposite_enemy_unit", trigger="on_turn_end", limit="once_per_turn", count=1)],
            [ability("delay_damage", "enemy_lane", 2 + scale, trigger="on_death", turn_changes=1)],
            [ability("weaken_unit", "enemy_lowest_health", scale)],
            [ability("gain_energy", "self", 1, trigger="on_turn_start", limit="once_per_turn")],
            [ability("deal_damage", "opposite_enemy_unit", 1 + scale, trigger="on_defend", limit="once_per_turn")],
            [ability("move_unit", "self", trigger="on_spend_resonance", limit="once_per_turn", steps=1)],
            [ability("grant_shield", "own_hero", scale, trigger="on_draw", limit="once_per_turn")],
            [ability("modify_attack", "own_species", scale, species=group)],
            [conditional("deal_damage", "enemy_hero", 1 + scale, threshold=5 + cohort % 2)],
            [ability("discard_card", "self", trigger="on_play", count=1), ability("draw_cards", "self", trigger="on_play", count=2)],
        ]
        additions = [
            ability("gain_resonance", "self", 1, trigger="on_deal_damage", limit="once_per_turn"),
            ability("grant_block", "own_hero", 1, trigger="on_spend_resonance", limit="once_per_turn"),
            ability("delay_damage", "enemy_lane", 1, trigger="on_death", turn_changes=2),
        ]
    else:
        plans = [
            [ability("grant_shield", "self", scale)],
            [ability("grant_block", "own_hero", 1 + scale)],
            [ability("heal_target", "own_lowest_health", scale)],
            [ability("deal_damage", "opposite_enemy_unit", scale)],
            [ability("gain_resonance", "self", 1, trigger="on_defend", limit="once_per_turn")],
            [ability("draw_cards", "self", trigger="on_death", count=1)],
            [ability("modify_attack", "own_neighbors", scale)],
            [ability("grant_shield", "own_species", scale, species=group)],
            [ability("haste", "self", mode="passive", limit="while_on_board")],
            [ability("heal_target", "own_hero", 1 + scale)],
            [ability("weaken_unit", "opposite_enemy_unit", scale, trigger="on_attack", limit="once_per_turn")],
            [ability("gain_energy", "self", 1, trigger="on_death")],
            [ability("move_unit", "self", trigger="on_play", steps=-1)],
            [conditional("modify_attack", "self", scale, resource="controlled_paths", threshold=2)],
        ]
        additions = [
            ability("grant_block", "own_hero", 1, trigger="on_defend", limit="once_per_turn"),
            ability("gain_resonance", "self", 1, trigger="on_draw", limit="once_per_turn"),
            ability("heal_target", "own_hero", 1, trigger="on_death"),
            ability("grant_shield", "self", 1, trigger="on_relic_activate", limit="once_per_turn"),
        ]
    result = plans[family]
    if cohort:
        result += [additions[min(cohort - 1, len(additions) - 1)]]
    # The last cohort's conditions are a costed strategic requirement, not free
    # ever-growing stats. The runtime's condition latch and turn limit are tested.
    if cohort >= 4 and family % 3 == 0:
        result += [conditional("gain_resonance", "self", 1, resource="controlled_paths", threshold=3)]
    return result


def event_profile(power, index):
    # Every impulse has an explicit composition. No repeated ordinal template
    # creates a second same-power copy with only a different name/illustration.
    def a(op, target="self", amount=None, **p):
        return ability(op, target, amount, trigger="on_play", **p)
    def reaction(op, target, amount, trigger):
        return ability(op, target, amount, mode="reactive", trigger=trigger, limit="once_per_turn")
    profiles = {
        "houses": [
            [a("return_card", count=1)],
            [a("summon_card", card_id="oa-houses-c01")],
            [a("heal_target", "own_hero", 4)],
            [a("discard_card", count=1), a("draw_cards", count=2)],
            [a("grant_shield", "own_all", 1)],
            [a("modify_attack", "own_species", 1, species="revenant")],
            [a("gain_resonance", amount=1), a("heal_target", "own_lowest_health", 2)],
            [a("return_card", count=1), a("grant_block", "own_hero", 1)],
            [reaction("heal_target", "own_hero", 3, "on_take_damage")],
            [a("draw_cards", count=1), a("grant_shield", "own_hero", 2)],
            [a("discard_card", count=1), a("gain_resonance", amount=3)],
            [a("grant_shield", "own_species", 2, species="construct"), a("return_card", count=1)],
            [a("return_card", count=1), a("heal_target", "own_hero", 2)],
            [a("deal_damage", "enemy_lowest_health", 2), a("heal_target", "own_hero", 1)],
            [a("return_card", count=1), a("gain_resonance", amount=1)],
            [a("summon_card", card_id="oa-neutral-c02"), a("grant_block", "own_hero", 1)],
            [a("draw_cards", count=2), a("discard_card", count=1)],
            [a("grant_shield", "own_hero", 4)],
            [a("stun_unit", "enemy_lowest_health", count=1), a("return_card", count=1)],
            [a("modify_attack", "own_species", 2, species="human"), a("heal_target", "own_all", 1)],
            [a("return_card", count=1), a("draw_cards", count=1)],
            [a("weaken_unit", "enemy_all", 1), a("discard_card", count=1)],
            [a("summon_card", card_id="oa-houses-c01"), a("summon_card", card_id="oa-neutral-c02")],
        ],
        "stillwatch": [
            [a("grant_block", "own_hero", 3)],
            [a("grant_shield", "own_all", 1), a("grant_block", "own_hero", 1)],
            [a("stun_unit", "enemy_lowest_health", count=1)],
            [a("heal_target", "own_all", 1)],
            [a("weaken_unit", "enemy_all", 1)],
            [a("grant_shield", "own_hero", 3)],
            [a("grant_shield", "own_species", 2, species="construct")],
            [a("stun_unit", "enemy_lowest_health", count=2)],
            [reaction("grant_shield", "own_hero", 3, "on_defend")],
            [a("move_unit", "enemy_lowest_health", steps=-1), a("stun_unit", "enemy_lowest_health", count=1)],
            [a("deal_damage", "enemy_lane", 2), a("grant_shield", "own_hero", 1)],
            [a("grant_shield", "own_lowest_health", 4)],
            [a("delay_damage", "enemy_lane", 3, turn_changes=1)],
            [a("grant_block", "own_hero", 4), a("gain_resonance", amount=1)],
            [a("grant_shield", "own_all", 2)],
            [a("move_unit", "own_lowest_health", steps=-1), a("grant_shield", "own_lowest_health", 1)],
            [a("grant_block", "own_hero", 2), a("draw_cards", count=1)],
            [a("return_card", count=1), a("grant_shield", "own_hero", 1)],
            [a("weaken_unit", "enemy_lowest_health", 3), a("grant_block", "own_hero", 1)],
            [a("stun_unit", "enemy_lowest_health", count=1), a("grant_shield", "own_all", 1)],
            [a("grant_block", "own_hero", 5), a("discard_card", count=1)],
            [a("grant_shield", "own_all", 2), a("heal_target", "own_hero", 2)],
            [a("stun_unit", "enemy_lowest_health", count=2), a("draw_cards", count=1)],
            [a("heal_target", "own_hero", 5), a("grant_shield", "own_lowest_health", 1)],
            [a("weaken_unit", "enemy_all", 2), a("grant_block", "own_hero", 2)],
            [a("stun_unit", "enemy_lowest_health", count=2), a("delay_damage", "enemy_lane", 4, turn_changes=2)],
        ],
        "morph": [
            [a("move_unit", "own_lowest_health", steps=1)],
            [a("modify_attack", "own_all", 1)],
            [a("grant_shield", "own_species", 2, species="morphid")],
            [a("move_unit", "enemy_lowest_health", steps=-1)],
            [a("deal_damage", "enemy_all", 1)],
            [a("summon_card", card_id="oa-morph-c01")],
            [a("heal_target", "own_species", 2, species="plant")],
            [a("modify_attack", "own_species", 2, species="beast")],
            [reaction("modify_attack", "own_all", 1, "on_attack")],
            [a("grant_shield", "own_species", 3, species="plant")],
            [a("deal_damage", "enemy_lowest_health", 3), a("heal_target", "own_lowest_health", 1)],
            [a("heal_target", "own_species", 3, species="amalgam")],
            [a("modify_attack", "own_species", 1, species="plant"), a("summon_card", card_id="oa-morph-c01")],
            [a("move_unit", "own_lowest_health", steps=-1), a("grant_shield", "own_all", 1)],
            [a("modify_attack", "own_species", 2, species="morphid"), a("gain_resonance", amount=1)],
            [a("summon_card", card_id="oa-morph-c01"), a("draw_cards", count=1)],
            [a("heal_target", "own_all", 2), a("modify_attack", "own_species", 1, species="plant")],
            [a("discard_card", count=1), a("return_card", count=1), a("gain_resonance", amount=1)],
            [a("modify_attack", "own_all", 2), a("deal_damage", "enemy_all", 1)],
            [a("summon_card", card_id="oa-morph-c01"), a("summon_card", card_id="oa-morph-c01")],
        ],
        "ninth": [
            [a("delay_damage", "enemy_lane", 3, turn_changes=2)],
            [a("deal_damage", "enemy_lane", 2)],
            [a("grant_shield", "own_hero", 2), a("gain_resonance", amount=1)],
            [a("stun_unit", "enemy_lowest_health", count=1), a("gain_resonance", amount=1)],
            [a("draw_cards", count=1), a("grant_block", "own_hero", 1)],
            [a("delay_damage", "enemy_lane", 2, turn_changes=1)],
            [a("discard_card", count=1), a("draw_cards", count=2), a("grant_block", "own_hero", 1)],
            [a("gain_resonance", amount=1), a("weaken_unit", "enemy_lowest_health", 1)],
            [reaction("deal_damage", "enemy_hero", 2, "on_spend_resonance")],
            [a("delay_damage", "enemy_lane", 2, turn_changes=3), a("draw_cards", count=1)],
            [a("deal_damage", "enemy_lane", 1), a("stun_unit", "enemy_lowest_health", count=1)],
            [a("grant_block", "own_hero", 2), a("gain_resonance", amount=2)],
            [a("draw_cards", count=1), a("gain_resonance", amount=1)],
            [a("deal_damage", "enemy_lowest_health", 3)],
            [a("delay_damage", "enemy_lane", 1, turn_changes=1), a("delay_damage", "enemy_lane", 1, turn_changes=2)],
            [a("delay_damage", "enemy_lane", 4, turn_changes=3)],
            [a("move_unit", "own_lowest_health", steps=1), a("gain_resonance", amount=1)],
            [a("stun_unit", "enemy_lowest_health", count=2), a("grant_block", "own_hero", 1)],
            [a("weaken_unit", "enemy_lowest_health", 2), a("draw_cards", count=1)],
            [a("grant_shield", "own_hero", 2), a("delay_damage", "enemy_lane", 2, turn_changes=2)],
            [a("move_unit", "enemy_lowest_health", steps=1), a("grant_shield", "own_hero", 1)],
            [a("heal_target", "own_hero", 3), a("delay_damage", "enemy_lane", 2, turn_changes=1)],
            [a("gain_energy", amount=2), a("discard_card", count=1)],
            [a("move_unit", "enemy_lowest_health", steps=-1), a("delay_damage", "enemy_lane", 2, turn_changes=1)],
            [a("deal_damage", "enemy_lane", 5), a("discard_card", count=1)],
            [a("delay_damage", "enemy_lane", 2, turn_changes=3), a("gain_resonance", amount=2)],
            [a("draw_cards", count=2), a("delay_damage", "enemy_lane", 1, turn_changes=2)],
            [a("summon_card", card_id="oa-ninth-c01"), a("grant_block", "own_hero", 1)],
            [a("weaken_unit", "enemy_all", 1), a("gain_resonance", amount=1)],
            [a("delay_damage", "enemy_lane", 4, turn_changes=1), a("grant_shield", "own_hero", 1)],
            [a("gain_energy", amount=1), a("draw_cards", count=1)],
            [a("delay_damage", "enemy_lane", 3, turn_changes=1), a("delay_damage", "enemy_lane", 3, turn_changes=2)],
        ],
        "neutral": [
            [a("heal_target", "own_hero", 3)],
            [a("move_unit", "own_lowest_health", steps=1), a("grant_block", "own_hero", 1)],
            [a("heal_target", "own_lowest_health", 3)],
            [a("draw_cards", count=1)],
            [a("deal_damage", "enemy_lane", 1), a("gain_resonance", amount=1)],
            [a("grant_block", "own_hero", 2)],
            [a("gain_resonance", amount=1)],
            [a("grant_shield", "own_hero", 2)],
            [reaction("grant_block", "own_hero", 2, "on_take_damage")],
            [a("weaken_unit", "enemy_lowest_health", 1)],
            [a("heal_target", "own_all", 1), a("gain_resonance", amount=1)],
            [a("grant_shield", "own_lowest_health", 1), a("draw_cards", count=1)],
            [a("heal_target", "own_hero", 4), a("discard_card", count=1)],
            [a("return_card", count=1), a("heal_target", "own_lowest_health", 1)],
            [a("gain_resonance", amount=2), a("grant_block", "own_hero", 1)],
            [a("grant_shield", "own_all", 1), a("heal_target", "own_hero", 1)],
            [a("grant_block", "own_hero", 3), a("heal_target", "own_lowest_health", 1)],
            [a("move_unit", "own_lowest_health", steps=-1), a("gain_resonance", amount=1)],
            [a("modify_attack", "own_all", 1), a("grant_shield", "own_hero", 1)],
            [a("draw_cards", count=2), a("grant_block", "own_hero", 1)],
        ],
    }
    return profiles[power][index]


def relic_profile(power, index):
    n = 1 + index // 5
    species = {"houses": "revenant", "stillwatch": "construct", "morph": "plant", "ninth": "paradox", "neutral": "human"}[power]
    primary = {
        "houses": [ability("return_card", "self", mode="activated", limit="once_per_turn", count=1), ability("heal_target", "own_hero", n, trigger="on_discard", limit="once_per_turn")],
        "stillwatch": [ability("grant_shield", "own_lowest_health", 1 + n, mode="activated", limit="once_per_turn"), ability("grant_block", "own_hero", n, trigger="on_defend", limit="once_per_turn")],
        "morph": [ability("modify_attack", "own_species", n, mode="activated", limit="once_per_turn", species=species), ability("gain_resonance", "self", 1, trigger="on_lane_change", limit="once_per_turn")],
        "ninth": [ability("deal_damage", "enemy_lowest_health", n, mode="activated", limit="once_per_turn"), ability("grant_shield", "own_hero", 1, trigger="on_spend_resonance", limit="once_per_turn")],
        "neutral": [ability("heal_target", "own_hero", 1 + n, mode="activated", limit="once_per_turn"), ability("gain_resonance", "self", 1, trigger="on_kill", limit="once_per_turn")],
    }[power]
    variants = [
        ability("grant_block", "own_hero", n, trigger="on_turn_start", limit="once_per_turn"),
        ability("grant_shield", "own_species", n, trigger="on_turn_end", limit="once_per_turn", species=species),
        ability("draw_cards", "self", trigger="on_relic_activate", limit="once_per_turn", count=1),
        ability("gain_resonance", "self", n, trigger="on_draw", limit="once_per_turn"),
        ability("modify_attack", "own_lowest_health", n, trigger="on_turn_start", limit="once_per_turn"),
    ]
    # A persistent hook plus a costed activation are categorically distinct from
    # a one-shot impulse. One relic slot, replacement and the once-per-turn flag
    # belong to the model and cannot be bypassed by extra ability entries.
    return [primary[0], variants[index % 5]] + ([primary[1]] if index >= 5 else [])


def target_phrase(target, params, case="dative"):
    species = SPECIES.get(params.get("species"), "")
    forms = {
      "dative": {
        "self": "diesem Wesen", "own_hero": "deinem Helden", "enemy_hero": "dem gegnerischen Helden",
        "enemy_lane": "dem gegnerischen Wesen auf dem gewählten Pfad; ist der Pfad leer, dem gegnerischen Helden",
        "opposite_enemy_unit": "dem direkt gegenüberliegenden gegnerischen Wesen",
        "own_lowest_health": "dem eigenen Wesen mit dem wenigsten Leben",
        "enemy_lowest_health": "dem gegnerischen Wesen mit dem wenigsten Leben",
        "own_neighbors": "den eigenen Wesen auf den Nachbarpfaden",
        "own_all": "allen eigenen Wesen", "enemy_all": "allen gegnerischen Wesen",
        "own_species": "allen eigenen Wesen der Art " + species,
      },
      "accusative": {
        "self": "dieses Wesen", "own_hero": "deinen Helden", "enemy_hero": "den gegnerischen Helden",
        "enemy_lane": "das gegnerische Wesen auf dem gewählten Pfad",
        "opposite_enemy_unit": "das direkt gegenüberliegende gegnerische Wesen",
        "own_lowest_health": "das eigene Wesen mit dem wenigsten Leben",
        "enemy_lowest_health": "das gegnerische Wesen mit dem wenigsten Leben",
        "own_neighbors": "die eigenen Wesen auf den Nachbarpfaden", "own_all": "alle eigenen Wesen",
        "enemy_all": "alle gegnerischen Wesen", "own_species": "alle eigenen Wesen der Art " + species,
      },
      "genitive": {
        "self": "dieses Wesens", "own_hero": "deines Helden", "enemy_hero": "des gegnerischen Helden",
        "enemy_lane": "des gegnerischen Wesens auf dem gewählten Pfad",
        "opposite_enemy_unit": "des direkt gegenüberliegenden gegnerischen Wesens",
        "own_lowest_health": "des eigenen Wesens mit dem wenigsten Leben",
        "enemy_lowest_health": "des gegnerischen Wesens mit dem wenigsten Leben",
        "own_neighbors": "der eigenen Wesen auf den Nachbarpfaden", "own_all": "aller eigenen Wesen",
        "enemy_all": "aller gegnerischen Wesen", "own_species": "aller eigenen Wesen der Art " + species,
      },
    }
    return forms[case][target]


def effect_text(a, kind):
    p, effect, target = a["params"], a["effect"], a["target"]
    n = p.get("amount", p.get("count", 1))
    who = target_phrase(target, p)
    if target == "self" and kind != "creature":
        who = "dir"
    if effect == "deal_damage":
        text = f"Füge {who} {n} Schaden zu."
    elif effect == "grant_shield":
        text = f"Gewähre {who} {n} Schild."
    elif effect == "grant_block":
        text = f"Gewähre deinem Helden {n} Block bis zu deinem Zugbeginn."
    elif effect == "heal_target":
        text = f"Heile {target_phrase(target, p, 'accusative')} um {n} Leben."
    elif effect == "modify_attack":
        text = f"Gewähre {who} +{n} Angriff."
    elif effect == "weaken_unit":
        text = f"Verringere den Angriff {target_phrase(target, p, 'genitive')} um {n}."
    elif effect == "move_unit":
        text = f"Versetze {target_phrase(target, p, 'accusative')} um einen Pfad nach {'links' if p['steps'] < 0 else 'rechts'}, falls dort Platz ist."
    elif effect == "summon_card":
        text = f"Beschwöre {ORIGINAL_NAMES[p['card_id']]} auf dem ersten freien eigenen Pfad."
    elif effect == "return_card":
        text = "Nimm das zuletzt abgelegte eigene Wesen auf die Hand, falls Platz ist."
    elif effect == "gain_resonance":
        text = f"Erzeuge {n} Resonanz."
    elif effect == "gain_energy":
        text = f"Erhalte {n} Energie für diesen Zug."
    elif effect == "draw_cards":
        text = f"Ziehe {n} {'Karte' if n == 1 else 'Karten'}."
    elif effect == "discard_card":
        text = "Wirf die erste Handkarte ab, falls vorhanden."
    elif effect == "delay_damage":
        text = f"Füge nach {p['turn_changes']} Zugwechseln dem gegnerischen Wesen auf diesem Pfad {n} Schaden zu; ein leerer Pfad trifft den Helden."
        if kind == "relic":
            text = f"Merke den Pfad des gegnerischen Wesens mit dem wenigsten Leben (ohne Wesen: Pfad 1). {text}"
    elif effect == "stun_unit":
        text = f"Betäube {target_phrase(target, p, 'accusative')} für {n} {'Angriffsphase' if n == 1 else 'Angriffsphasen'}."
    elif effect == "haste":
        text = "Dieses Wesen kann im Zug seiner Beschwörung angreifen."
    else:
        raise ValueError(effect)
    return text


def ability_text(a, kind, include_limit=True):
    if a["mode"] == "passive":
        prefix = "Dauerhaft"
    elif a["mode"] == "activated":
        costs = a["activation"]
        prefix = f"Aktivieren ({costs['energy']} Energie, {costs['resonance']} Resonanz)"
    else:
        prefix = TRIGGER_DE[a["trigger"]]
        if a["trigger"] == "on_condition":
            condition = a["condition"]
            resource = {"resonance": "Resonanz", "energy": "Energie", "hand": "Handkarten", "controlled_paths": "kontrollierte Pfade"}[condition["resource"]]
            prefix = f"Sobald du mindestens {condition['at_least']} {resource} hast"
            if condition["resource"] == "controlled_paths":
                prefix = f"Sobald du mindestens {condition['at_least']} Pfade kontrollierst"
        if kind in ["relic", "event"] and a["trigger"] in ["on_attack", "on_defend", "on_kill", "on_deal_damage", "on_take_damage", "on_lane_change"]:
            prefix = {"on_attack": "Wenn ein eigenes Wesen angreift", "on_defend": "Wenn ein eigenes Wesen verteidigt", "on_kill": "Wenn ein eigenes Wesen ein Wesen besiegt", "on_deal_damage": "Wenn ein eigenes Wesen Schaden verursacht", "on_take_damage": "Wenn ein eigenes Wesen Schaden erleidet", "on_lane_change": "Wenn ein eigenes Wesen den Pfad wechselt"}[a["trigger"]]
    if a["mode"] == "reactive":
        costs = a["activation"]
        prefix += f" (Reaktion, {costs['resonance']} Resonanz)"
    text = prefix + ": " + effect_text(a, kind)
    if a["mode"] == "reactive":
        text += " Beim Ausspielen bis zu deinem nächsten Zugbeginn vorbereiten."
    if include_limit and a["limit"] == "once_per_turn":
        text += " 1× pro Zug."
    return text


def card_description(abilities, kind):
    shared_limit = len(abilities) > 1 and all(a["limit"] == "once_per_turn" for a in abilities)
    text = "\n".join(ability_text(a, kind, not shared_limit) for a in abilities)
    return text + ("\nJede Fähigkeit 1× pro Zug." if shared_limit else "")


def tags_for(abilities, kind):
    tags = set()
    if kind == "relic":
        tags.add("relic")
    if kind == "event":
        tags.add("impulse")
    for a in abilities:
        effect = a["effect"]
        tags.update({
            "deal_damage": ["aggro"], "grant_shield": ["shield", "convergence"], "grant_block": ["block", "control"],
            "heal_target": ["control"], "modify_attack": ["midrange", "aggro"], "weaken_unit": ["control", "resource_control"],
            "move_unit": ["movement", "convergence"], "summon_card": ["midrange"], "return_card": ["recurrence"],
            "gain_resonance": ["resonance"], "gain_energy": ["resource_control"], "draw_cards": ["midrange"],
            "discard_card": ["recurrence"], "delay_damage": ["time"], "stun_unit": ["time", "control"], "haste": ["aggro"],
        }[effect])
        if a["target"] == "own_species":
            tags.add("species")
    return sorted(tags)


def rarity_for(index, count, kind):
    if index >= count - (3 if kind == "creature" else 2):
        return "legendary"
    if index >= count - max(5, count // 4):
        return "epic"
    return "rare" if index % 3 == 1 or kind == "relic" else "common"


def design_cost(abilities, kind, index, rarity):
    if kind == "creature":
        # A cost spread with low/medium bodies represented in every family.
        return min(8, 1 + index % 6 + (1 if len(abilities) > 1 else 0) + (1 if len(abilities) > 2 else 0))
    costs = 0
    for a in abilities:
        p, op = a["params"], a["effect"]
        value = p.get("amount", p.get("count", 1))
        costs += {
            "deal_damage": 1 + value / 2, "grant_shield": value / 2, "grant_block": value / 2,
            "heal_target": value / 3, "modify_attack": value / 2, "weaken_unit": value / 2,
            "move_unit": 1, "summon_card": 2, "return_card": 2, "gain_resonance": value,
            "gain_energy": 2 * value, "draw_cards": 1 + value, "discard_card": -1,
            "delay_damage": value / 2, "stun_unit": 1 + value, "haste": 1,
        }[op]
        if a["target"] in ["own_all", "enemy_all", "own_species"]:
            costs += 1
    if kind == "relic":
        costs = 1 + len(abilities) + index // 5
    return min(8, max(1, round(costs)))


def art_brief(card):
    power = card["faction"]
    material = {"houses": "Kupfer und warme, verwitterte Oberflächen", "stillwatch": "Eisblau, Silber und klare Kristalle", "morph": "Jadegrün, Bernstein und organische Strukturen", "ninth": "Amethyst, Silber und gebrochene Geometrie", "neutral": "Graphit, Stahl und gedämpfte Naturfarben"}[power]
    kind = {"creature": "handelndes Wesen", "event": "klar lesbarer magischer Vorgang", "relic": "ein einzelnes strategisches Artefakt"}[card["kind"]]
    species = ", ".join(SPECIES[s] for s in card.get("species", []))
    return {
        "id": card["id"], "name": card["name"], "status": "missing", "asset_id": "missing:" + card["id"],
        "suggested_path": f"res://assets/cards/production/{power}/{card['id']}.webp",
        "minimum_pixels": [1344, 1000], "crop_ratio": "168:125", "lore_status": "VORSCHLAG",
        "subject": card["name"], "species": card.get("species", []),
        "brief_de": f"Motiv: {card['name']}; {kind}{' der Arten ' + species if species else ''}. {material}. Eigenständige dunkle Fantasy mit räumlichen Falten; klares Hauptmotiv, Gesicht oder Funktion im mittleren Bildbereich. Mechanischer Bezug: {', '.join(card.get('archetypes', []))}. Die Illustration zeigt keine Schrift, Kosten, Zahlen, Rahmen, Seltenheitssymbole oder Benutzeroberfläche. Keine bekannten Figuren oder Logos; kein neuer kanonischer Weltenursprung und keine Enthüllung über Eira.",
        "provenance": None, "license_review": "pending_asset_creation", "individual_illustration_complete": False,
    }


ORIGINAL_NAMES = {c["id"]: c["name"] for c in json.loads((ROOT / "data/alpha/cards.json").read_text())["cards"]}


def build():
    original_raw = (ROOT / "data/alpha/cards.json").read_bytes()
    original = json.loads(original_raw)
    species_overlay = json.loads((ROOT / "data/card_system/alpha_species.json").read_text())["species_by_card_id"]
    concepts = json.loads((ROOT / "data/lore/card-concepts.json").read_text())
    concept_pools = collections.defaultdict(list)
    for concept in concepts:
        concept_pools[(concept["affiliation"], concept["card_type"])].append(concept)
    cards = []
    authoring = []
    migration = []
    for old in original["cards"]:
        card = dict(old)
        if card["kind"] == "creature":
            card["species"] = species_overlay[card["id"]]
        card["art"] = {"status": "shared_concept", "asset_id": "shared:orafold-atlas", "provenance": "assets/ASSET_MANIFEST.md"}
        # Native55 handlers remain the sole implementation of these originals;
        # do not add a duplicate generic ability that would trigger twice.
        card["lore_status"] = "ARBEITSSTAND"
        card["archetypes"] = native_tags(card)
        card = revise_native(card)
        # Event/relic combat zeros from the old flat format are not creature stats.
        if card["kind"] != "creature":
            card.pop("atk", None)
            card.pop("hp", None)
        cards.append(card)
        changes = {key: {"old": old.get(key), "new": card.get(key)} for key in ["cost", "atk", "hp", "effect", "power", "description", "abilities"] if old.get(key) != card.get(key) and not (key in ["atk", "hp"] and old["kind"] != "creature")}
        migration.append({"old_id": old["id"], "new_id": old["id"], "decision": "revised_production_identity_preserved" if changes else "retained_native_handler", "name_changed": False, "stats_changed": any(key in changes for key in ["atk", "hp", "cost"]), "changes": changes})
    for power in POWERS:
        identifier = 0
        for kind, inventory in [("creature", CREATURES), ("event", EVENTS), ("relic", RELICS)]:
            names = rows(inventory[power])
            for index, row in enumerate(names):
                identifier += 1
                parts = row.split("|")
                name = parts[0]
                species = parts[1].split(",") if len(parts) > 1 else []
                abilities = creature_profile(power, index, species) if kind == "creature" else event_profile(power, index) if kind == "event" else relic_profile(power, index)
                rarity = rarity_for(index, len(names), kind)
                cost = design_cost(abilities, kind, index, rarity)
                card = {
                    "schema_version": 3, "id": f"of-{power}-{identifier:03d}", "name": name,
                    "faction": power, "order": power, "kind": kind, "rarity": rarity,
                    "cost": cost, "effect": "v2", "power": 0, "abilities": abilities,
                    "description": card_description(abilities, kind),
                    "archetypes": tags_for(abilities, kind), "lore_status": "VORSCHLAG",
                    "art": {"status": "missing", "asset_id": f"missing:of-{power}-{identifier:03d}", "provenance": "data/production/art_briefs.json"},
                }
                if any(a["mode"] == "reactive" for a in abilities):
                    card["reaction_window"] = "until_next_own_turn"
                if kind == "creature":
                    card["species"] = species
                    ability_budget = sum(1 if a["trigger"] in ["on_play", "on_summon", "on_death"] else 2 for a in abilities if a["mode"] != "passive") + sum(2 for a in abilities if a["mode"] == "passive")
                    budget = 2 * cost + 1 + {"common": 0, "rare": 1, "epic": 2, "legendary": 3}[rarity] - ability_budget
                    # Attack is weighted 1.15: the five independent lanes make
                    # exposed-hero pressure more valuable than symmetric bulk.
                    attack = max(1, round(max(3, budget) * (0.39 + (index % 3) * 0.06) / 1.15))
                    health = max(2, round(max(3, budget) - attack * 1.15))
                    card.update(atk=attack, hp=health)
                    if "haste" in [a["effect"] for a in abilities]:
                        card["archetypes"] = sorted(set(card["archetypes"]) | {"aggro"})
                concept_kind = {"creature": "Wesen", "event": "Impuls", "relic": "Relikt"}[kind]
                concept_pool = concept_pools[(POWER_NAMES[power], concept_kind)]
                source = concept_pool[index] if index < len(concept_pool) else None
                authoring.append({"card_id": card["id"], "name": name, "source_concept_id": source["id"] if source else None, "source_concept_status": "VORSCHLAG", "decision": "new_authored_name_and_composable_rules", "family": index % 14 if kind == "creature" else index % 8 if kind == "event" else index % 5, "cohort": index // 14 if kind == "creature" else index // 8 if kind == "event" else index // 5, "design_rationale_de": rationale(card), "lore_status": "VORSCHLAG"})
                cards.append(card)
    starter_path = OUT / "starters.json"
    starters = json.loads(starter_path.read_text()) if starter_path.exists() else original["starters"]
    result = {"version": "orafold-production-candidate-1", "schema_version": 3, "status": "candidate_requires_runtime_and_QA", "powers": POWER_NAMES, "source_alpha_sha256": hashlib.sha256(original_raw).hexdigest(), "cards": cards, "starters": starters}
    catalogue = OUT / "cards.json"
    artifacts = {
        catalogue: result,
        OUT / "authoring.json": {"status": "editorial_proposals_not_world_canon", "cards": authoring},
        OUT / "art_briefs.json": {"status": "individual_art_missing_unless_manifest_override_exists", "cards": [art_brief(card) for card in cards]},
        OUT / "migration.json": {"version": 1, "from_ruleset": "orafold-alpha-0.1", "to_ruleset": "orafold-production-candidate-1", "retained": migration, "removed_active_ids": [], "archived_pools": ["data/legacy/cards.json", "data/card_definitions.gd"], "historical_concepts": "data/lore/card-concepts.json"},
    }
    return artifacts


def native_tags(card):
    op = card["effect"]
    tags = {"strike": ["aggro"], "guard": ["block", "control"], "ward": ["shield", "convergence"], "mend": ["control"], "draw": ["midrange"], "rally": ["aggro", "midrange"], "weave": ["resonance"], "drain": ["aggro", "control"], "silence": ["control"], "pierce": ["aggro"], "shift": ["movement"], "harvest": ["resonance", "recurrence"], "retaliate": ["control"], "haste": ["aggro"], "weaken": ["control"], "pulse": ["midrange", "resonance"], "bolt": ["aggro", "impulse"], "heal": ["control", "impulse"], "stasis": ["time", "control", "impulse"], "surge": ["aggro", "impulse"], "recall": ["recurrence", "impulse"], "delay": ["time", "impulse"], "redirect": ["time", "impulse"], "displace": ["movement", "impulse"], "cascade": ["impulse", "aggro"], "relic_res": ["relic", "resonance"], "relic_ward": ["relic", "shield"], "relic_heal": ["relic", "control"], "relic_draw": ["relic", "midrange"]}[op]
    return sorted(tags)


def revise_native(card):
    """Explicit production changes; the Alpha archive is never rewritten.

    Three old pulse legends receive power-specific rules. A few repeated native
    bodies become attack/health trade-offs, not silent replacement IDs.
    """
    revisions = {
        "oa-ninth-c01": {"atk": 2, "hp": 2},
        "oa-houses-c02": {"atk": 1, "hp": 5},
        "oa-houses-c04": {"atk": 1, "hp": 5},
        "oa-ninth-c06": {"atk": 4, "hp": 4},
        "oa-morph-e02": {"cost": 2},
        "oa-morph-r01": {"cost": 1},
    }
    if card["id"] in revisions:
        card.update(revisions[card["id"]])
    special = {
        "oa-houses-c07": [
            ability("return_card", "self", count=1),
            ability("heal_target", "own_lowest_health", 2, trigger="on_turn_start", limit="once_per_turn"),
            ability("summon_card", "self", trigger="on_death", card_id="oa-houses-c01"),
        ],
        "oa-stillwatch-c07": [
            ability("grant_shield", "own_all", 2),
            ability("stun_unit", "opposite_enemy_unit", trigger="on_defend", limit="once_per_turn", count=1),
            ability("grant_block", "own_hero", 2, trigger="on_turn_start", limit="once_per_turn"),
        ],
        "oa-morph-c07": [
            ability("haste", "self", mode="passive", limit="while_on_board"),
            ability("move_unit", "self", trigger="on_play", steps=1),
            ability("modify_attack", "own_species", 1, trigger="on_lane_change", limit="once_per_turn", species="plant"),
        ],
        "oa-stillwatch-r01": [
            ability("grant_shield", "own_hero", 2, mode="activated", limit="once_per_turn"),
            ability("grant_block", "own_hero", 1, trigger="on_turn_start", limit="once_per_turn"),
        ],
        "oa-stillwatch-e02": [ability("stun_unit", "enemy_lowest_health", trigger="on_play", count=1), ability("grant_shield", "own_lowest_health", 1, trigger="on_play")],
    }
    if card["id"] in special:
        for key in ["trigger", "target", "duration", "limit"]:
            card.pop(key, None)
        card.update(schema_version=3, effect="v2", power=0, abilities=special[card["id"]])
        if card["id"] == "oa-houses-c07":
            card.update(atk=4, hp=7)
        elif card["id"] == "oa-stillwatch-c07":
            card.update(atk=3, hp=8)
        elif card["id"] == "oa-morph-c07":
            card.update(atk=5, hp=5)
        card["description"] = card_description(card["abilities"], card["kind"])
        card["archetypes"] = tags_for(card["abilities"], card["kind"])
    return card


def rationale(card):
    kind = {"creature": "Wesen", "event": "Impuls", "relic": "Relikt"}[card["kind"]]
    tags = ", ".join(card["archetypes"])
    return f"{kind} für {POWER_NAMES[card['faction']]}: {tags}. Kosten {card['cost']}; Fähigkeiten und begrenzte Auslöser werden aus generischen Operationen zusammengesetzt. Seltenheit {card['rarity']} ist ein erster Entwurfswert, keine Behauptung geprüfter Balance."


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if generated files differ; never rewrite during CI")
    args = parser.parse_args()
    differences = []
    for path, value in build().items():
        encoded = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if not path.exists() or path.read_text() != encoded:
                differences.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(encoded)
    if differences:
        raise SystemExit("Outdated production artifacts: " + ", ".join(differences))
    print("Production inventory generated" if not args.check else "Production inventory reproducible")


if __name__ == "__main__":
    main()
