"""Meaningful invariants for the independently executable economic model."""
import copy, pathlib, sys, tempfile, unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools/economy'))
from model import Collection, load_config, profile_run, summarize

class EconomySimulationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.config=load_config()
    def test_catalog_and_starters(self):
        c=Collection(self.config,12)
        self.assertEqual(len(c.cards),550)
        self.assertEqual(len(c.owned),41)
        self.assertEqual(sum(c.owned.values()),111)
        self.assertEqual(sum(c.bound.values()),111)
        self.assertEqual(c.snapshot()['legendary'],4)
        self.assertEqual({c.cards[cid]['faction'] for cid in c.target},{'houses'})
    def test_raw_json_duplicate_reward_definition_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=pathlib.Path(directory)/'rewards.json'
            path.write_text('{"definitions":{"onboarding":{"gold":1},"onboarding":{"gold":2}}}')
            with self.assertRaisesRegex(ValueError,r"rewards\.json: .*duplicate JSON key: 'onboarding'"):
                load_config(directory)
    def test_raw_json_same_field_in_separate_rewards_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            path=pathlib.Path(directory)/'rewards.json'
            path.write_text('{"definitions":{"one":{"gold":1},"two":{"gold":2}}}')
            config=load_config(directory)
            self.assertEqual(config['rewards']['definitions']['one']['gold'],1)
            self.assertEqual(config['rewards']['definitions']['two']['gold'],2)
    def test_raw_json_nonfinite_value_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            (pathlib.Path(directory)/'rewards.json').write_text('{"definitions":{"onboarding":{"gold":NaN}}}')
            with self.assertRaisesRegex(ValueError,'non-finite JSON constant: NaN'):
                load_config(directory)
    def test_card_totals_include_starters_boosters_and_crafts(self):
        c=Collection(self.config,12)
        self.assertEqual(c.snapshot()['total_cards_acquired'],111)
        c.booster()
        self.assertEqual(c.snapshot()['total_cards_acquired'],116)
        c.shards=1200;c.craft_target()
        snap=c.snapshot()
        self.assertEqual(snap['starter_copies'],111)
        self.assertEqual(snap['cards_received'],5)
        self.assertEqual(snap['crafted_cards'],1)
        self.assertEqual(snap['total_cards_acquired'],117)
        self.assertEqual(snap['total_cards_acquired']-snap['duplicate_cards'],snap['playable_copies'])
    def test_pity_hard_limits_with_no_natural_hits(self):
        c=Collection(self.config,12)
        c.roll=lambda rates:'common' if rates.get('common',0)>0 else 'rare'
        for i in range(100):
            rolled=c.booster()
            self.assertEqual(len(rolled),5)
            self.assertLess(c.pity['legendary'],self.config['booster_rules']['pity']['legendary'])
            self.assertLess(c.pity['epic'],self.config['booster_rules']['pity']['epic'])
        self.assertEqual(c.pity['legendary'],0)
    def test_duplicate_protection_until_playset(self):
        c=Collection(self.config,42)
        c.roll=lambda rates:'legendary'
        for _ in range(7):c.booster()
        self.assertEqual(c.duplicates,0)
        self.assertEqual(c.snapshot()['legendary'],39)
        c.booster()
        self.assertEqual(c.snapshot()['legendary'],40)
        self.assertEqual(c.duplicates,4)
        self.assertEqual(c.shards,4*self.config['crafting']['salvage']['legendary'])
    def test_seed_reproducible_and_varies(self):
        a,b,c=[Collection(self.config,s) for s in (7,7,8)]
        for _ in range(40):a.booster();b.booster();c.booster()
        self.assertEqual(a.snapshot(),b.snapshot());self.assertEqual(a.owned,b.owned)
        self.assertNotEqual(a.owned,c.owned)
    def test_crafting_sink_and_targeting(self):
        for rarity,cost in self.config['crafting']['costs'].items():
            self.assertGreater(cost,self.config['crafting']['salvage'][rarity])
        c=Collection(self.config,7);c.shards=1200;c.craft_target()
        self.assertEqual(c.owned['sim:legendary:000'],1)
        self.assertEqual(c.shards,0)
        self.assertEqual(c.spent_shards,1200)
    def test_expansion_preserves_ownership_and_pity(self):
        c=Collection(self.config,7);c.booster();before=copy.deepcopy(c.owned);pity=copy.deepcopy(c.pity)
        c.expand()
        self.assertEqual(len(c.cards),660)
        self.assertEqual(c.owned,before);self.assertEqual(c.pity,pity)
    def test_profile_gold_budget_and_limits(self):
        sc=self.config['scenarios'];snapshots,_=profile_run(self.config,sc['profiles']['B'],sc['models']['balanced'],7)
        for day,s in snapshots.items():
            self.assertGreaterEqual(s['gold_balance'],0)
            self.assertLess(s['gold_balance'],100)
            self.assertEqual(s['gold_earned']-s['gold_spent'],s['gold_balance'])
            self.assertGreaterEqual(s['shards'],0)
            self.assertLessEqual(s['collection_pct'],100)
            self.assertEqual(s['paid_pack_budget_used'],0)
        paid,_=profile_run(self.config,sc['profiles']['D'],sc['models']['balanced'],7)
        self.assertEqual(paid[30]['paid_pack_budget_used'],4)
    def test_hoard_preserves_source_total(self):
        sc=self.config['scenarios'];normal,_=profile_run(self.config,sc['profiles']['B'],sc['models']['balanced'],7)
        hoard,_=profile_run(self.config,sc['profiles']['B'],sc['models']['balanced'],7,hoard=True)
        self.assertEqual(normal[365]['gold_earned'],hoard[365]['gold_earned'])
        self.assertEqual(hoard[365]['gold_spent'],0)
        self.assertGreater(hoard[365]['gold_balance'],normal[365]['gold_balance'])
    def test_quantiles_and_mean_interval(self):
        s=summarize([0,10,20]);self.assertEqual(s['mean'],10)
        self.assertEqual(s['p05'],1);self.assertEqual(s['p95'],19)
        self.assertLess(s['ci95_low'],10);self.assertGreater(s['ci95_high'],10)
    def test_targeted_key_access_without_purchase(self):
        sc=self.config['scenarios']
        for seed in range(10):
            snapshots,_=profile_run(self.config,sc['profiles']['A'],sc['models']['balanced'],seed)
            self.assertEqual(snapshots[30]['key_access_complete'],1)
            self.assertEqual(snapshots[30]['paid_pack_budget_used'],0)
    def test_empirical_base_odds(self):
        import math
        from collections import Counter
        c=Collection(self.config,5502026)
        for slot in self.config['booster_rules']['slots']:
            n=25000;counts=Counter(c.roll(slot['rates']) for _ in range(n))
            for rarity,p in slot['rates'].items():
                tolerance=6*math.sqrt(p*(1-p)/n)+1/n
                self.assertLessEqual(abs(counts[rarity]/n-p),tolerance)
    def test_rate_mass_and_no_negative_probability(self):
        for slot in self.config['booster_rules']['slots']:
            self.assertAlmostEqual(sum(slot['rates'].values()),1,places=12)
            self.assertTrue(all(v>=0 for v in slot['rates'].values()))
            self.assertGreater(slot['count'],0)

if __name__=='__main__':unittest.main()
