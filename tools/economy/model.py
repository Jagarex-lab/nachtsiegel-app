"""Deterministic economy model; synthetic cards are never production card IDs.

The Godot implementation uses different RNG. Distribution/rule parity, not bit parity.
"""
from __future__ import annotations
import copy, json, math, random, statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RARITIES = ('common', 'rare', 'epic', 'legendary')
CHECKPOINTS = (1, 7, 30, 90, 180, 365)

def _reject_duplicate_keys(pairs):
    result={}
    for key,value in pairs:
        if key in result:
            raise ValueError(f'duplicate JSON key: {key!r}')
        result[key]=value
    return result

def _reject_nonfinite_constant(value):
    raise ValueError(f'non-finite JSON constant: {value}')

def load_config(directory=None):
    """Load raw config before keys can silently overwrite earlier definitions."""
    directory=Path(directory) if directory is not None else ROOT/'data/economy'
    result={}
    for path in sorted(directory.glob('*.json')):
        try:
            result[path.stem]=json.loads(path.read_text(encoding='utf-8'),
                object_pairs_hook=_reject_duplicate_keys,
                parse_constant=_reject_nonfinite_constant)
        except (ValueError,UnicodeError) as exc:
            raise ValueError(f'{path}: {exc}') from exc
    return result

def synthetic_catalog(distribution=None, expansion=False):
    distribution = distribution or dict(zip(RARITIES, (250,160,100,40)))
    cards = {}
    for rarity, count in distribution.items():
        for index in range(count):
            cid = f'{"exp" if expansion else "sim"}:{rarity}:{index:03d}'
            cards[cid] = {'id':cid, 'rarity':rarity, 'faction':('houses','stillwatch','morph','ninth')[index%4], 'bound':False}
    return cards

class Collection:
    def __init__(self, config, seed=1, starter_unique=None):
        self.config=config
        self.rng=random.Random(seed)
        self.cards=synthetic_catalog(config['scenarios']['catalog']['rarity_counts'])
        self.owned={}
        self.bound={}
        self.shards=0
        self.packs=0
        self.raw_cards=0
        self.crafted_cards=0
        self.duplicates=0
        self.generated_shards=0
        self.spent_shards=0
        self.pity={'epic':0,'legendary':0}
        self.by_rarity={r:[k for k,v in self.cards.items() if v['rarity']==r] for r in RARITIES}
        legacy=config['scenarios'].get('target_shape')=='legacy_mixed_basket'
        rare_indices=range(4) if legacy else (0,4,8,12)
        epic_indices=range(3) if legacy else (0,4,8)
        self.target={**{f'sim:rare:{i:03d}':2 for i in rare_indices}, **{f'sim:epic:{i:03d}':1 for i in epic_indices}, 'sim:legendary:000':1}
        self.key_cards=('sim:legendary:000',)+tuple(f'sim:epic:{i:03d}' for i in list(epic_indices)[:2])
        if starter_unique is None:
            # Adapter-shaped union:17C*3,16R*3+4R*2,4L*1=111 bound copies.
            for rarity,counts in [('common',[3]*17),('rare',[3]*16+[2]*4),('legendary',[1]*4)]:
                for i,n in enumerate(counts):
                    cid=f'sim:{rarity}:{i+20:03d}'
                    self.owned[cid]=n;self.bound[cid]=n
        else:
            for i in range(starter_unique):
                cid=f'sim:common:{i+20:03d}'
                self.owned[cid]=3;self.bound[cid]=3
    def cap(self, rarity):
        return self.config['collection_rules']['copy_limits'][rarity]
    def add(self, cid):
        rarity=self.cards[cid]['rarity']
        self.raw_cards+=1
        if self.owned.get(cid,0)>=self.cap(rarity):
            n=self.config['crafting']['salvage'][rarity]
            self.shards+=n; self.generated_shards+=n; self.duplicates+=1
            return True
        self.owned[cid]=self.owned.get(cid,0)+1
        return False
    def roll(self, rates):
        n=self.rng.random(); acc=0
        for r in RARITIES:
            acc+=rates.get(r,0)
            if n<acc: return r
        raise ValueError('rates do not sum to one')
    def booster(self, disable_pity=False):
        rules=self.config['booster_rules']
        rolled=[]
        for slot in rules['slots']:
            rolled.extend(self.roll(slot['rates']) for _ in range(slot['count']))
        if not disable_pity:
            if self.pity['legendary']>=rules['pity']['legendary']-1 and 'legendary' not in rolled:
                rolled[-1]='legendary'
            if self.pity['epic']>=rules['pity']['epic']-1 and not any(r in rolled for r in ('epic','legendary')):
                rolled[-1]='epic'
        for r in ('epic','legendary'):
            hit=any(RARITIES.index(x)>=RARITIES.index(r) for x in rolled)
            self.pity[r]=0 if hit else self.pity[r]+1
        for rarity in rolled:
            pool=self.by_rarity[rarity]
            if rarity in rules['duplicate_protection']:
                unfilled=[c for c in pool if self.owned.get(c,0)<self.cap(rarity)]
                if unfilled: pool=unfilled
            self.add(self.rng.choice(pool))
        self.packs+=1
        return rolled
    def craft_target(self):
        # Targeted key cards first:1L+2E, then remaining rare/epic deck upgrades.
        if self.config['scenarios'].get('crafting_policy')=='legendary_then_rare_then_epic':
            priorities=['sim:legendary:000']+[cid for cid in self.target if ':rare:' in cid]+[cid for cid in self.target if ':epic:' in cid]
        else:
            priorities=list(self.key_cards)
            priorities += [cid for cid in self.target if cid not in priorities]
        for cid in priorities:
            count=self.target[cid];rarity=self.cards[cid]['rarity']
            cost=self.config['crafting']['costs'][rarity]
            while self.owned.get(cid,0)<count and self.shards>=cost:
                self.shards-=cost;self.spent_shards+=cost
                self.owned[cid]=self.owned.get(cid,0)+1
                self.crafted_cards+=1
    def expand(self):
        # Hypothetical 100-card expansion; pity carries over, same standard pool.
        extra=synthetic_catalog(self.config['scenarios']['expansion']['rarity_counts'], expansion=True)
        self.cards.update(extra)
        for cid, card in extra.items(): self.by_rarity[card['rarity']].append(cid)
    def snapshot(self):
        counts={r:sum(n for c,n in self.owned.items() if self.cards[c]['rarity']==r) for r in RARITIES}
        required=sum(self.cap(c['rarity']) for c in self.cards.values())
        target_have=sum(min(self.owned.get(cid,0),n) for cid,n in self.target.items())
        return {'packs':self.packs,'cards_received':self.raw_cards,
                'starter_copies':sum(self.bound.values()),'crafted_cards':self.crafted_cards,
                'total_cards_acquired':sum(self.bound.values())+self.raw_cards+self.crafted_cards,'unique':len(self.owned),'playable_copies':sum(self.owned.values()),**counts,
                'shards':self.shards,'shards_generated':self.generated_shards,'shards_spent':self.spent_shards,'duplicate_cards':self.duplicates,
                'collection_pct':100*len(self.owned)/len(self.cards),'playset_pct':100*sum(self.owned.values())/required,
                'key_access_pct':100*sum(self.owned.get(cid,0)>0 for cid in self.key_cards)/3,
                'key_access_complete':int(all(self.owned.get(cid,0)>0 for cid in self.key_cards)),
                'target_pct':100*target_have/sum(self.target.values()),'target_complete':int(target_have==sum(self.target.values())),
                'available_strategy_proxies':4+int(target_have==sum(self.target.values()))}

def summarize(values):
    values=sorted(values); n=len(values)
    if not n: raise ValueError('empty sample')
    def q(frac):
        pos=(n-1)*frac; lo=int(pos); return values[lo]+(values[min(lo+1,n-1)]-values[lo])*(pos-lo)
    mean=statistics.mean(values)
    se=statistics.stdev(values)/math.sqrt(n) if n>1 else 0
    return {'mean':mean,'p05':q(.05),'p95':q(.95),'ci95_low':mean-1.96*se,'ci95_high':mean+1.96*se}

def profile_run(config, profile, scenario, seed, expansion=False, hoard=False, starter_unique=None):
    config=copy.deepcopy(config)
    for rarity,cost in config['crafting']['costs'].items():
        config['crafting']['costs'][rarity]=int(round(cost*scenario.get('craft_cost_multiplier',1)))
    c=Collection(config,seed,starter_unique)
    defs=config['rewards']['definitions']
    welcome=defs.get('welcome', defs.get('onboarding',{}))
    gold=int(welcome.get('gold',0)); total_gold=gold; spent_gold=0
    c.shards=int(welcome.get('crafting',0))
    for _ in range(int(welcome.get('boosters',{}).get('standard',0))):c.booster()
    xp=int(welcome.get('xp',0)); level=1
    out={}; completion_day=None
    curve=config['progression']['xp_curve']
    match=config['progression']['match']
    base_price=config['booster_pools']['pools']['standard']['price_gold']
    price=scenario.get('booster_price_gold',base_price)
    mult=scenario.get('gold_multiplier',1)
    session=config['scenarios']['session']
    matches=max(1,int(profile['minutes_per_day']/session['minutes_per_match']))
    c.craft_target()
    for day in range(1,366):
        if expansion and day==181:c.expand()
        earned=min(matches*match['gold'],match['daily_gold_cap'])
        earned_xp=matches*match['xp']
        # Acceptance model: completed fair play quests; no login streak or victory assumption.
        daily=defs.get('daily_play',{})
        weekly=defs.get('weekly_play',{})
        if matches>=1:
            earned+=daily.get('gold',0);earned_xp+=daily.get('xp',0);c.shards+=daily.get('crafting',0)
        if matches>=session['daily_variety_matches']:
            variety=defs['daily_variety'];earned+=variety.get('gold',0);earned_xp+=variety.get('xp',0);c.shards+=variety.get('crafting',0)
        # Weekly payout at week end; conservative timing vs immediate target claim.
        if day%7==0 and matches*7>=session['weekly_qualifying_matches']:
            earned+=weekly.get('gold',0);earned_xp+=weekly.get('xp',0);c.shards+=weekly.get('crafting',0)
            for _ in range(weekly.get('boosters',{}).get('standard',0)):c.booster()
        if day in session['campaign_chapter_days']:
            reward=defs['campaign_chapter'];earned+=reward.get('gold',0);earned_xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
            for _ in range(reward.get('boosters',{}).get('standard',0)):c.booster()
        earned=int(round(earned*mult)); xp+=earned_xp
        while level<curve['max_level']:
            threshold=curve['base']+(level-1)*curve['per_level']
            if xp<threshold:break
            xp-=threshold;level+=1
            earned+=int(config['progression']['level_reward'].get('gold',0)*mult)
            for milestone in config['progression'].get('milestones',[]):
                if milestone['level']==level:
                    reward=defs[milestone['reward']]
                    earned+=int(reward.get('gold',0)*mult)
                    xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
        gold+=earned;total_gold+=earned
        # Model pack budgets, not purchase prices. Equal monthly schedule across seeds.
        budget=profile.get('purchased_boosters_per_30_days',0)
        extras=(day*budget)//30-((day-1)*budget)//30
        for _ in range(extras):c.booster()
        if not hoard:
            while gold>=price:gold-=price;spent_gold+=price;c.booster()
        c.craft_target()
        if completion_day is None and all(c.owned.get(cid,0)>=n for cid,n in c.target.items()):completion_day=day
        if day in CHECKPOINTS:
            out[day]={**c.snapshot(),'gold_earned':total_gold,'gold_spent':spent_gold,'gold_balance':gold,'level':level,'xp_remainder':xp,
                      'paid_pack_budget_used':day*budget//30}
    return out,completion_day
