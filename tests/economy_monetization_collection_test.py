"""Analysis invariants: no changes to runtime economy or claims about battle strength."""
import copy,json,pathlib,sys,tempfile,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools/economy'))
from model import Collection,load_config,profile_run
from monetization_collection import trajectory,_clone,_marginal,_expand,_affordable,SECOND_TARGET,DEFAULT_CONFIG,run_collection

class MonetizationCollectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.economy=load_config();cls.analysis=json.loads(DEFAULT_CONFIG.read_text())
    def test_baseline_reproduces_existing_pack_curve(self):
        baseline=self.analysis['models']['baseline96'];profile=self.analysis['profiles']['F2P45']
        old,_=profile_run(self.economy,profile,self.economy['scenarios']['models']['balanced'],56112026)
        new=trajectory(self.economy,baseline,profile,56112026,365,(1,7,30,90,180,365),marginality=False)
        self.assertEqual(new['snapshots'][30]['packs'],96)
        self.assertEqual(new['snapshots'][365]['packs'],old[365]['packs'])
        for day in (1,7,30,90):
            for key in ('packs','unique','playable_copies','shards','collection_pct'):
                self.assertEqual(new['snapshots'][day][key],old[day][key],(day,key))
    def test_matched_paid_profiles_and_fixed_budget(self):
        self.assertEqual(self.analysis['profiles']['paid4']['minutes_per_day'],45)
        self.assertEqual(self.analysis['profiles']['paid40']['minutes_per_day'],45)
        model=self.analysis['models']['baseline96']
        for label,budget in (('paid4',4),('paid40',40)):
            result=trajectory(self.economy,model,self.analysis['profiles'][label],8,30,(30,),marginality=False)
            self.assertEqual(result['snapshots'][30]['paid_packs'],budget)
            self.assertEqual(result['snapshots'][30]['free_packs'],96)
    def test_protection_persistent_and_bounded_with_missed_days(self):
        model=self.analysis['models']['protected_weekly'];profile=self.analysis['profiles']['F2P45']
        result=trajectory(self.economy,model,profile,8,90,(7,30,90),active_days_per_week=3,marginality=False)
        self.assertEqual(result['snapshots'][7]['target_essence_granted'],300)
        self.assertEqual(result['snapshots'][30]['target_essence_granted'],1200)
        self.assertEqual(result['snapshots'][90]['target_essence_granted'],1200)
        self.assertEqual(result['snapshots'][30]['key_access_complete'],1)
    def test_repeated_expansion_unique_ids_and_stocks(self):
        c=Collection(self.economy,12);c.booster();owned=c.owned.copy();pity=c.pity.copy();c.shards=1234
        for i in range(1,5):_expand(c,i,self.economy['scenarios']['expansion']['rarity_counts'])
        self.assertEqual(len(c.cards),990)
        self.assertEqual(c.owned,owned);self.assertEqual(c.pity,pity);self.assertEqual(c.shards,1234)
        self.assertEqual(sum(len(v) for v in c.by_rarity.values()),990)
    def test_marginal_pack_does_not_modify_original_or_rng(self):
        c=Collection(self.economy,12);before=c.snapshot();rng=c.rng.getstate();cloned=_clone(c)
        result=_marginal(c)
        self.assertEqual(c.snapshot(),before);self.assertEqual(c.rng.getstate(),rng)
        self.assertGreaterEqual(result['unsaturation_factor'],0);self.assertLessEqual(result['unsaturation_factor'],1)
        c.booster();cloned.booster();self.assertEqual(c.owned,cloned.owned)
    def test_affordable_collection_is_not_owned_and_suppresses_demand(self):
        c=Collection(self.economy,12);before=c.owned.copy();c.shards=1000000
        potential,_=_affordable(c)
        self.assertEqual(potential['affordable_unique_pct'],100)
        self.assertEqual(potential['affordable_playset_pct'],100)
        self.assertEqual(c.owned,before)
        self.assertEqual(_marginal(c)['unsaturation_factor'],0)
    def test_meta_basket_single_power_and_distinct_from_first(self):
        c=Collection(self.economy,12)
        self.assertFalse(set(c.target)&set(SECOND_TARGET))
        self.assertEqual({c.cards[cid]['faction'] for cid in SECOND_TARGET},{'houses'})
    def test_summary_censoring_and_all24months(self):
        cfg=copy.deepcopy(self.analysis)
        with tempfile.TemporaryDirectory() as directory:
            result=run_collection(cfg,output_dir=directory,repetitions=2)
            self.assertEqual(result['metadata']['base_trajectories'],40)
            for model in result['models'].values():
                for profile in model['profiles'].values():
                    self.assertEqual(len(profile['monthly']),24)
                    self.assertTrue(all(0<=v['unsaturation_factor']<=1 for v in profile['monthly']))
                    self.assertIn('censored_fraction',profile['thresholds']['unique95'])
            self.assertTrue((pathlib.Path(directory)/'collection_paid_gaps.csv').exists())

if __name__=='__main__':unittest.main()
