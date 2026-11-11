#!/usr/bin/env python3
"""Production data regression tests, including malicious/invalid definitions.

The tests distinguish validator acceptance, text assertions, stable save IDs and
actual runtime evidence. No fabricated Godot play function is used here.
"""
from __future__ import annotations

import copy
import json
import unittest

from build_catalog import ROOT, card_description, build
from validate_catalog import validate, validate_deck


class ProductionCatalogue(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads((ROOT / "data/production/cards.json").read_text())
        cls.index = {card["id"]: card for card in cls.document["cards"]}
        cls.generic_index = next(i for i, card in enumerate(cls.document["cards"]) if card["id"] == "of-houses-001")

    def changed(self, mutate):
        value = copy.deepcopy(self.document)
        mutate(value["cards"][self.generic_index])
        return validate(value)

    def assertInvalid(self, mutate, fragment):
        result = self.changed(mutate)
        self.assertFalse(result["ok"])
        self.assertTrue(any(fragment in error for error in result["errors"]), result["errors"])

    def test_full_inventory(self):
        result = validate(self.document)
        self.assertTrue(result["ok"], result["errors"])
        self.assertEqual(result["cards"], 550)
        self.assertEqual(result["generic_cards"], 500)
        self.assertEqual(result["native_cards"], 50)
        self.assertEqual(set(result["powers"].values()), {110})
        self.assertEqual(result["kinds"], {"creature": 357, "event": 133, "relic": 60})
        self.assertEqual(result["distinct_cross_power_mechanical_identities"], 550)

    def test_reproducible_outputs(self):
        for path, value in build().items():
            self.assertEqual(json.loads(path.read_text()), value, str(path))

    def test_exact_three_types(self):
        self.assertInvalid(lambda card: card.update(kind="anomaly"), "unknown main card kind")

    def test_unknown_card_field(self):
        self.assertInvalid(lambda card: card.update(pay_to_win=True), "unknown card fields")

    def test_boolean_energy_is_not_integer(self):
        self.assertInvalid(lambda card: card.update(cost=True), "energy outside")

    def test_unreachable_energy_rejected(self):
        self.assertInvalid(lambda card: card.update(cost=10), "energy outside")

    def test_negative_stats(self):
        self.assertInvalid(lambda card: card.update(atk=-1), "invalid creature stats")

    def test_three_species_rejected(self):
        self.assertInvalid(lambda card: card.update(species=["human", "beast", "plant"]), "one/two distinct")

    def test_echo_is_not_thirteenth_species(self):
        self.assertInvalid(lambda card: card.update(species=["echo"]), "one/two distinct")

    def test_duplicate_species_rejected(self):
        self.assertInvalid(lambda card: card.update(species=["human", "human"]), "one/two distinct")

    def test_unknown_operation_rejected(self):
        self.assertInvalid(lambda card: card["abilities"][0].update(effect="unimplemented_win"), "unknown executable operation")

    def test_unknown_trigger_rejected(self):
        self.assertInvalid(lambda card: card["abilities"][0].update(trigger="on_cashout"), "unknown trigger")

    def test_unreachable_condition_rejected(self):
        self.assertInvalid(lambda card: card["abilities"][0].update(trigger="on_condition", condition={"resource": "controlled_paths", "at_least": 6}), "unreachable condition threshold")

    def test_unknown_target_rejected(self):
        self.assertInvalid(lambda card: card["abilities"][0].update(target="anywhere"), "invalid target")

    def test_unknown_parameter_rejected(self):
        self.assertInvalid(lambda card: card["abilities"][0]["params"].update(unlimited=True), "operation parameters")

    def test_count_is_not_amount(self):
        self.assertInvalid(lambda card: card["abilities"][0].update(params={"amount": 1}), "count outside")

    def test_summon_unknown_card_rejected(self):
        self.assertInvalid(lambda card: card.update(abilities=[{"mode": "triggered", "trigger": "on_death", "effect": "summon_card", "target": "self", "params": {"card_id": "not-a-card"}, "limit": "once_per_event"}]), "existing own/neutral creature")

    def test_unapproved_lore_canon_rejected(self):
        self.assertInvalid(lambda card: card.update(lore_status="KANON"), "implicit lore canonization")

    def test_duplicate_name_rejected(self):
        self.assertInvalid(lambda card: card.update(name="Torwache"), "duplicate display name")

    def test_empty_ability_is_not_implemented(self):
        self.assertInvalid(lambda card: card.update(abilities=[]), "one to three actual abilities")

    def test_reactive_window_is_explicit(self):
        value = copy.deepcopy(self.document)
        card = next(card for card in value["cards"] if card.get("reaction_window"))
        del card["reaction_window"]
        result = validate(value)
        self.assertFalse(result["ok"])
        self.assertTrue(any("explicit expiry window" in error for error in result["errors"]))

    def test_impulses_never_get_combat_stats(self):
        value = copy.deepcopy(self.document)
        card = next(card for card in value["cards"] if card["kind"] == "event")
        card.update(atk=0, hp=0)
        self.assertTrue(any("must not contain creature stats" in error for error in validate(value)["errors"]))

    def test_all_original_ids_survive(self):
        original = json.loads((ROOT / "data/alpha/cards.json").read_text())
        self.assertEqual(len(original["cards"]), 55)
        for card in original["cards"]:
            self.assertIn(card["id"], self.index)
            self.assertEqual(self.index[card["id"]]["name"], card["name"])
        for deck in original["starters"].values():
            self.assertEqual(validate_deck(deck, self.index, "old saved starter"), [])

    def test_migration_documents_changes(self):
        migration = json.loads((ROOT / "data/production/migration.json").read_text())
        self.assertEqual(len(migration["retained"]), 55)
        self.assertEqual(migration["removed_active_ids"], [])
        changed = {entry["old_id"] for entry in migration["retained"] if entry["changes"]}
        self.assertEqual(changed, {"oa-ninth-c01", "oa-houses-c02", "oa-houses-c04", "oa-ninth-c06", "oa-morph-e02", "oa-morph-r01", "oa-houses-c07", "oa-stillwatch-c07", "oa-morph-c07", "oa-stillwatch-r01", "oa-stillwatch-e02"})

    def test_legendary_copy_limit(self):
        deck = self.document["starters"]["houses"].copy()
        deck[0:2] = ["oa-houses-c07", "oa-houses-c07"]
        self.assertTrue(any("copy limit" in error for error in validate_deck(deck, self.index, "bad legend")))

    def test_cross_power_deck_rejected(self):
        deck = self.document["starters"]["houses"].copy()
        deck[0] = "oa-ninth-c01"
        self.assertTrue(any("exactly the selected power" in error for error in validate_deck(deck, self.index, "mixed")))

    def test_ninth_starter_can_prepare_redirect(self):
        cards = [self.index[identity] for identity in self.document["starters"]["ninth"]]
        self.assertTrue(any(card["effect"] == "redirect" for card in cards))
        self.assertGreaterEqual(sum(any(a["effect"] == "delay_damage" for a in card.get("abilities", [])) for card in cards), 3)

    def test_generated_text_matches_effects(self):
        for card in self.document["cards"]:
            if card["effect"] == "v2":
                self.assertEqual(card["description"], card_description(card["abilities"], card["kind"]), card["id"])

    def test_selected_rule_text_independent_goldens(self):
        # These expectations intentionally do not call the renderer. They catch
        # object-case bugs and hand-vs-battlefield return promises found in review.
        self.assertEqual(self.index["of-houses-001"]["description"], "Wenn dieses Wesen besiegt wird: Nimm das zuletzt abgelegte eigene Wesen auf die Hand, falls Platz ist.")
        self.assertIn("Heile deinen Helden um 4 Leben.", self.index["of-houses-069"]["description"])
        self.assertIn("Versetze dieses Wesen um einen Pfad nach rechts", self.index["of-morph-002"]["description"])
        self.assertNotIn("Beschwöre", self.index["of-houses-001"]["description"])
        self.assertIn("3 Zugwechseln", self.index["of-ninth-065"]["description"])

    def test_power_legends_are_distinct(self):
        houses = self.index["oa-houses-c07"]
        still = self.index["oa-stillwatch-c07"]
        morph = self.index["oa-morph-c07"]
        ninth = self.index["oa-ninth-c07"]
        self.assertEqual(ninth["effect"], "pulse")
        self.assertEqual([houses["effect"], still["effect"], morph["effect"]], ["v2"] * 3)
        self.assertIn("return_card", {a["effect"] for a in houses["abilities"]})
        self.assertIn("grant_shield", {a["effect"] for a in still["abilities"]})
        self.assertIn("move_unit", {a["effect"] for a in morph["abilities"]})

    def test_art_briefs_are_not_final_images(self):
        briefs = json.loads((ROOT / "data/production/art_briefs.json").read_text())["cards"]
        self.assertEqual({brief["id"] for brief in briefs}, set(self.index))
        self.assertTrue(all(not brief["individual_illustration_complete"] and brief["status"] == "missing" for brief in briefs))
        # A separate provenance-checked illustration manifest may override a few
        # entries. These planning briefs never turn those into 550 finished assets.


if __name__ == "__main__":
    unittest.main(verbosity=2)
