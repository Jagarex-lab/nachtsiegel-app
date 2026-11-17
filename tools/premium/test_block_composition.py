"""Data regressions for the measured Block reference deck; no simulated wins."""
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
BASELINE='10782185cf41f2013607ba47da0bbfcb737e89e2'


class BlockCompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proposal=json.loads((ROOT/'tools/premium/block_deck_proposal.json').read_text())
        cls.old=json.loads((ROOT/'tools/premium/block_reference_baseline.json').read_text())
        cls.active=json.loads((ROOT/'data/production/test_decks.json').read_text())
        cls.cards=json.loads((ROOT/'data/production/cards.json').read_text())['cards']
        cls.by={card['id']:card for card in cls.cards}

    def test_frozen_control_lists_are_the_actual_public_baseline(self):
        raw=subprocess.check_output(['git','show',BASELINE+':data/production/test_decks.json'],cwd=ROOT)
        self.assertEqual(raw,(ROOT/'tools/premium/block_reference_baseline.json').read_bytes())
        self.assertEqual(hashlib.sha256(raw).hexdigest(),self.proposal['baseline_test_decks_sha256'])

    def test_only_the_one_reference_deck_changed(self):
        self.assertEqual(len(self.active['decks']),14)
        changed=[]
        for old,new in zip(self.old['decks'],self.active['decks']):
            self.assertEqual(old['id'],new['id'])
            if old!=new:changed.append(old['id'])
            if old['id']=='prod-block':
                self.assertEqual(old['cards'],self.proposal['before_cards'])
                self.assertEqual(new['cards'],self.proposal['candidate_cards'])
        self.assertEqual(changed,['prod-block'])

    def test_exact_eight_copy_change_retains_block_identity(self):
        before=Counter(self.proposal['before_cards']);after=Counter(self.proposal['candidate_cards'])
        self.assertEqual(sum((before-after).values()),8)
        self.assertEqual(sum((after-before).values()),8)
        self.assertEqual(sum((before&after).values()),22)
        self.assertEqual(dict(before-after),self.proposal['removed'])
        self.assertEqual(dict(after-before),self.proposal['added'])
        self.assertEqual(after['of-stillwatch-097'],2,'both original Block/growth relics remain')
        cards=[self.by[id] for id in self.proposal['candidate_cards']]
        self.assertEqual(len(cards),30)
        self.assertEqual(Counter(card['kind'] for card in cards),{'creature':23,'event':5,'relic':2})
        self.assertEqual(Counter(card['faction'] for card in cards),{'stillwatch':19,'neutral':11})
        for id,count in after.items():self.assertLessEqual(count,1 if self.by[id]['rarity']=='legendary' else 3)
        block=sum(card.get('effect')=='guard' or any(ability['effect']=='grant_block' for ability in card.get('abilities',[])) for card in cards)
        self.assertEqual(block,24,'Block remains a property of 80 percent of the list')

    def test_rules_cards_resources_policy_and_starters_are_unchanged(self):
        for path in ['data/production/cards.json','data/production/starters.json','scripts/card_system/production_model.gd','scripts/production/ai_policy.gd','scripts/alpha/model.gd','scripts/legacy/battle_engine.gd']:
            with self.subTest(path=path):
                original=subprocess.check_output(['git','show',BASELINE+':'+path],cwd=ROOT)
                self.assertEqual(original,(ROOT/path).read_bytes())

    def test_generator_reproduces_every_active_deck(self):
        spec=importlib.util.spec_from_file_location('decks',ROOT/'tools/production/build_test_decks.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        self.assertEqual([module.build(self.cards,config) for config in module.CONFIGS],self.active['decks'])


if __name__=='__main__':unittest.main()
