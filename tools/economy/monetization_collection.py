#!/usr/bin/env python3
"""Analysis-only, paired Monte Carlo collection and marginal-pack study.

No runtime settings, purchase prices, retention or battle outcomes are changed.
"""
from __future__ import annotations
import argparse, copy, csv, hashlib, json, math, statistics, time
from collections import defaultdict
from pathlib import Path
from model import Collection, RARITIES, ROOT, load_config, summarize, synthetic_catalog

DEFAULT_CONFIG=ROOT/'data/economy/analysis/monetization.json'
DEFAULT_OUT=ROOT/'docs/economy/monetization-results'
WEIGHTS={'equal':(1,1,1,1),'moderate':(1,1.5,2,3),'steep':(1,2,4,8)}
SECOND_TARGET={**{f'sim:rare:{i:03d}':2 for i in (40,44,48,52)},**{f'sim:epic:{i:03d}':1 for i in (40,44,48)},'sim:legendary:004':1}
SECOND_KEYS=('sim:legendary:004','sim:epic:040','sim:epic:044')

def _hash(value):return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()
def _write_csv(path,rows):
    if not rows:return
    with path.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
def _clone(c):
    clone=copy.copy(c);clone.owned=c.owned.copy();clone.pity=c.pity.copy()
    clone.rng=__import__('random').Random();clone.rng.setstate(c.rng.getstate())
    return clone

def _basket(c,basket):
    filled=sum(min(c.owned.get(cid,0),n) for cid,n in basket.items())
    return 100*filled/sum(basket.values()),int(all(c.owned.get(cid,0)>=n for cid,n in basket.items()))

def _craft(c,basket,keys,essence):
    # Restricted essence buys only first/second target baskets; no gold or general collection.
    order=list(keys)+[cid for cid in basket if cid not in keys]
    for cid in order:
        cost=c.config['crafting']['costs'][c.cards[cid]['rarity']]
        while c.owned.get(cid,0)<basket[cid] and c.shards+essence>=cost:
            special=min(essence,cost);essence-=special;normal=cost-special
            c.shards-=normal;c.spent_shards+=normal;c.crafted_cards+=1
            c.owned[cid]=c.owned.get(cid,0)+1
    return essence

def _expand(c,index,distribution):
    extra=synthetic_catalog(distribution,expansion=True)
    for old,card in extra.items():
        cid=old.replace('exp:',f'exp{index:03d}:',1)
        if cid in c.cards:raise ValueError('expansion ID collision')
        c.cards[cid]={**card,'id':cid};c.by_rarity[card['rarity']].append(cid)

def _affordable(c):
    # Potential ownership under cheapest-missing crafting, without actually spending stocks.
    owned_unique={r:sum(c.owned.get(cid,0)>0 for cid in pool) for r,pool in c.by_rarity.items()}
    owned_copies={r:sum(c.owned.get(cid,0) for cid in pool) for r,pool in c.by_rarity.items()}
    unique=len(c.owned);copies=sum(owned_copies.values());unique_budget=c.shards;copy_budget=c.shards
    for rarity in sorted(RARITIES,key=lambda r:c.config['crafting']['costs'][r]):
        cost=c.config['crafting']['costs'][rarity];pool=c.by_rarity[rarity]
        n=min(len(pool)-owned_unique[rarity],unique_budget//cost);unique+=n;unique_budget-=n*cost
        n=min(len(pool)*c.cap(rarity)-owned_copies[rarity],copy_budget//cost);copies+=n;copy_budget-=n*cost
    total=sum(len(pool)*c.cap(r) for r,pool in c.by_rarity.items())
    return {'affordable_unique_pct':100*unique/len(c.cards),'affordable_playset_pct':100*copies/total},owned_copies

def _snapshot(c,essence,granted,paid,gold,oneoff,recurring,first_day,second_day,meta_before):
    snap=c.snapshot();potential,counts=_affordable(c);snap.update(potential)
    first,full=_basket(c,c.target);meta,metafull=_basket(c,SECOND_TARGET)
    snap.update({'key_access_complete':int(all(c.owned.get(cid,0)>0 for cid in c.key_cards)),
        'first_target_pct':first,'first_target_complete':full,'meta_target_pct':meta,'meta_target_complete':metafull,
        'meta_key_access_complete':int(all(c.owned.get(cid,0)>0 for cid in SECOND_KEYS)),
        'meta_natural_readiness_at180_pct':meta_before if meta_before is not None else 0,
        'target_essence_balance':essence,'target_essence_granted':granted,'paid_packs':paid,'free_packs':c.packs-paid,
        'gold_balance':gold,'oneoff_gold_earned':oneoff,'recurring_gold_earned':recurring})
    for label,weights in WEIGHTS.items():
        denominator=sum(len(c.by_rarity[r])*c.cap(r)*weights[i] for i,r in enumerate(RARITIES))
        snap['rarity_weighted_access_'+label]=100*sum(counts[r]*weights[i] for i,r in enumerate(RARITIES))/denominator
    return snap

def _marginal(c):
    after=_clone(c);before_unique=len(c.owned);before_high=sum(c.owned.get(cid,0)>0 for r in ('epic','legendary') for cid in c.by_rarity[r]);before_shards=c.shards
    before_first=_basket(c,c.target)[0];before_meta=_basket(c,SECOND_TARGET)[0]
    before_potential,_=_affordable(c)
    after.booster()
    new=len(after.owned)-before_unique
    missing_owned=len(c.cards)-before_unique
    missing_affordable=len(c.cards)*(1-before_potential['affordable_unique_pct']/100)
    # Explicit demand proxy, not an estimated willingness-to-pay or retention effect.
    factor=(new/c.config['booster_rules']['cards_per_booster'])*(missing_affordable/max(1,missing_owned))
    return {'marginal_new_unique_per_pack':new,
        'marginal_new_high_rarity_per_pack':sum(after.owned.get(cid,0)>0 for r in ('epic','legendary') for cid in after.by_rarity[r])-before_high,
        'marginal_crafting_per_pack':after.shards-before_shards,
        'marginal_first_target_pct':_basket(after,c.target)[0]-before_first,
        'marginal_meta_target_pct':_basket(after,SECOND_TARGET)[0]-before_meta,
        'unsaturation_factor':max(0,min(1,factor))}

def trajectory(economy,model,profile,seed,horizon=730,checkpoints=(),expansions=False,active_days_per_week=7,marginality=True,extra_booster_day=None,stop_on_full=False):
    c=Collection(economy,seed);defs=economy['rewards']['definitions'];welcome=defs['onboarding']
    c.shards=welcome.get('crafting',0);gold=welcome.get('gold',0);oneoff=gold;recurring_total=0;paid=0
    for _ in range(welcome.get('boosters',{}).get('standard',0)):c.booster()
    xp=welcome.get('xp',0);level=1;matches_total=0;week_matches=0;essence=0;granted=0
    protection=model['target_protection'];milestones=set();price=model['booster_price_gold'];mult=model['recurring_gold_multiplier']
    matches=max(1,profile['minutes_per_day']//economy['scenarios']['session']['minutes_per_match'])
    curve=economy['progression']['xp_curve'];match=economy['progression']['match'];first_day=None;first_key_day=None;second_day=None;meta_before=None
    thresholds={x:None for x in ('unique90','unique95','playset90')};snapshots={};monthly={};benchmarks={}
    targets=set(checkpoints)|set(range(30,horizon+1,30));essence=_craft(c,c.target,c.key_cards,essence)
    expansion_n=0
    for day in range(1,horizon+1):
        if expansions and day>180 and (day-1)%180==0:
            expansion_n+=1;_expand(c,expansion_n,economy['scenarios']['expansion']['rarity_counts'])
        active=(day-1)%7<active_days_per_week;earned=0;earned_xp=0;oneoff_today=0
        if active:
            before=matches_total;matches_total+=matches;week_matches+=matches
            earned=min(matches*match['gold'],match['daily_gold_cap']);earned_xp=matches*match['xp']
            daily=defs['daily_play'];earned+=daily.get('gold',0);earned_xp+=daily.get('xp',0);c.shards+=daily.get('crafting',0)
            if matches>=economy['scenarios']['session']['daily_variety_matches']:
                reward=defs['daily_variety'];earned+=reward.get('gold',0);earned_xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
            if protection.get('enabled'):
                for target in protection['checkpoints']:
                    if before<target<=matches_total and target not in milestones:
                        milestones.add(target);amount=protection['essence_per_checkpoint'];essence+=amount;granted+=amount
        if day%7==0:
            if week_matches>=economy['scenarios']['session']['weekly_qualifying_matches']:
                reward=defs['weekly_play'];earned+=reward.get('gold',0);earned_xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
                for _ in range(reward.get('boosters',{}).get('standard',0)):c.booster()
            week_matches=0
        # Fixed baseline campaign timing; missed-play variant banks it until the next active day.
        for index,due in enumerate(economy['scenarios']['session']['campaign_chapter_days']):
            source=f'campaign:{index}'
            if active and day>=due and source not in milestones:
                milestones.add(source);reward=defs['campaign_chapter'];oneoff_today+=reward.get('gold',0);earned_xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
                for _ in range(reward.get('boosters',{}).get('standard',0)):c.booster()
        earned=int(round(earned*mult));recurring_total+=earned;xp+=earned_xp
        while level<curve['max_level']:
            required=curve['base']+(level-1)*curve['per_level']
            if xp<required:break
            xp-=required;level+=1;oneoff_today+=economy['progression']['level_reward'].get('gold',0)
            for reward_def in economy['progression'].get('milestones',[]):
                if reward_def['level']==level:
                    reward=defs[reward_def['reward']];oneoff_today+=reward.get('gold',0);xp+=reward.get('xp',0);c.shards+=reward.get('crafting',0)
        oneoff+=oneoff_today;gold+=earned+oneoff_today
        budget=profile.get('purchased_boosters_per_30_days',0);extras=day*budget//30-(day-1)*budget//30
        for _ in range(extras):c.booster();paid+=1
        if day==extra_booster_day:c.booster();paid+=1
        while gold>=price:gold-=price;c.booster()
        essence=_craft(c,c.target,c.key_cards,essence)
        if first_key_day is None and all(c.owned.get(cid,0)>0 for cid in c.key_cards):first_key_day=day
        if first_day is None and all(c.owned.get(cid,0)>=n for cid,n in c.target.items()):first_day=day
        if day>=180:
            if meta_before is None:meta_before=_basket(c,SECOND_TARGET)[0]
            essence=_craft(c,SECOND_TARGET,SECOND_KEYS,essence)
            if second_day is None and all(c.owned.get(cid,0)>=n for cid,n in SECOND_TARGET.items()):second_day=day
        copies=sum(c.bound.values())+c.raw_cards+c.crafted_cards-c.duplicates
        total=sum(len(pool)*c.cap(r) for r,pool in c.by_rarity.items())
        for key,met in [('unique90',len(c.owned)>=.9*len(c.cards)),('unique95',len(c.owned)>=.95*len(c.cards)),('playset90',copies>=.9*total)]:
            if thresholds[key] is None and met:thresholds[key]=day
        if day in targets:
            snapshots[day]=_snapshot(c,essence,granted,paid,gold,oneoff,recurring_total,first_day,second_day,meta_before)
        if marginality and day%30==0:monthly[day]=_marginal(c)
        if marginality and day in (30,90,180,365):benchmarks[day]=_marginal(c)
        if stop_on_full and first_day is not None:break
    return {'snapshots':snapshots,'monthly':monthly,'benchmarks':benchmarks,'thresholds':thresholds,'first_target_day':first_day,'first_key_day':first_key_day,'meta_target_day':second_day,'completed_matches':matches_total,'essence_granted':granted}


def run_collection(configanalysis,output_dir=None,repetitions=None):
    economy=load_config();out=Path(output_dir or DEFAULT_OUT);out.mkdir(parents=True,exist_ok=True)
    reps=repetitions if repetitions is not None else configanalysis['repetitions'];horizon=configanalysis['horizon_days'];seed=configanalysis['seed'];models=configanalysis['models'];profiles=configanalysis['profiles'];checkpoints=configanalysis['checkpoints']
    all_runs={};rows=[];months=[];threshold_rows=[];marginal_rows=[];summary={'metadata':{},'models':{}};start=time.time()
    for mid,model in models.items():
        summary['models'][mid]={'profiles':{}}
        for pid,profile in profiles.items():
            # Same seed across models and profiles is a common-random-number pairing.
            runs=[trajectory(economy,model,profile,seed+i,horizon,checkpoints) for i in range(reps)];all_runs[mid,pid]=runs
            pdata={'checkpoints':{},'monthly':[],'thresholds':{}}
            for day in checkpoints:
                metrics={key:summarize([r['snapshots'][day][key] for r in runs]) for key in runs[0]['snapshots'][day]}
                pdata['checkpoints'][str(day)]=metrics
                rows.extend({'model':mid,'profile':pid,'day':day,'metric':metric,'n':reps,**value} for metric,value in metrics.items())
            previous_free=0
            for day in range(30,horizon+1,30):
                snaps=[r['snapshots'][day] for r in runs];mean=lambda key:statistics.mean(s[key] for s in snaps)
                free=mean('free_packs');entry={'month':day//30,'day':day,'mean_unique_pct':mean('collection_pct'),'mean_playset_pct':mean('playset_pct'),'mean_affordable_unique_pct':mean('affordable_unique_pct'),'mean_free_packs_cumulative':free,'mean_free_packs_in_month':free-previous_free,'mean_paid_packs_cumulative':mean('paid_packs'),'mean_oneoff_gold_cumulative':mean('oneoff_gold_earned'),'mean_recurring_gold_cumulative':mean('recurring_gold_earned')}
                for key in runs[0]['monthly'][day]:entry[key]=statistics.mean(r['monthly'][day][key] for r in runs)
                entry['mean_unique_gap_pct']=100-entry['mean_unique_pct'];entry['mean_playset_gap_pct']=100-entry['mean_playset_pct']
                pdata['monthly'].append(entry);months.append({'model':mid,'profile':pid,**entry});previous_free=free
            for key in (*runs[0]['thresholds'],'key_access','first_target','meta_target'):
                field={'key_access':'first_key_day','first_target':'first_target_day','meta_target':'meta_target_day'}.get(key)
                values=[r[field] if field else r['thresholds'][key] for r in runs];observed=[v for v in values if v is not None];capped=[v if v is not None else horizon+1 for v in values]
                item={'completed_fraction':len(observed)/reps,'censored_fraction':1-len(observed)/reps,'restricted_mean_days':statistics.mean(capped),'observed_median_days':statistics.median(observed) if observed else None,**{f'capped_{k}':v for k,v in summarize(capped).items()}}
                pdata['thresholds'][key]=item;threshold_rows.append({'model':mid,'profile':pid,'threshold':key,'n':reps,**item})
            for day in (30,90,180,365):
                for metric in runs[0]['benchmarks'][day]:marginal_rows.append({'model':mid,'profile':pid,'day':day,'metric':metric,'n':reps,**summarize([r['benchmarks'][day][metric] for r in runs])})
            summary['models'][mid]['profiles'][pid]=pdata
            print(f'collection {mid}/{pid}: {reps} paired trajectories, {time.time()-start:.1f}s',flush=True)
    gaps=[]
    for mid in models:
        free=all_runs[mid,'F2P45']
        for paid in ('paid4','paid40'):
            for day in sorted(free[0]['snapshots']):
                for metric in ('collection_pct','playset_pct','affordable_unique_pct','epic','legendary','first_target_pct','meta_target_pct','rarity_weighted_access_equal','rarity_weighted_access_moderate','rarity_weighted_access_steep'):
                    delta=[p['snapshots'][day][metric]-f['snapshots'][day][metric] for p,f in zip(all_runs[mid,paid],free)]
                    gaps.append({'model':mid,'profile':paid,'day':day,'metric':metric,'n':reps,**summarize(delta)})
    # Actual extra-pack timing: continue only cases with incomplete first basket at injection.
    timing=[]
    for mid,model in models.items():
        base=all_runs[mid,'F2P45']
        for day in (30,90,180,365):
            values=[]
            for i,original in enumerate(base):
                before=original['first_target_day'] or horizon+1
                if before<=day:values.append(0);continue
                changed=trajectory(economy,model,profiles['F2P45'],seed+i,horizon,(),marginality=False,extra_booster_day=day,stop_on_full=True)
                values.append(before-(changed['first_target_day'] or horizon+1))
            timing.append({'model':mid,'profile':'F2P45','day':day,'metric':'extra_one_pack_restricted_target_days_saved','n':reps,**summarize(values)})
    sensitivity=[]
    for label,mid,kwargs in [('protected_3_active_days_per_week','protected_weekly',{'active_days_per_week':3}),*[(f'{mid}_expansion_every180',mid,{'expansions':True}) for mid in models]]:
        model=models[mid];profile=profiles['F2P45'];runs=[trajectory(economy,model,profile,seed+i,horizon,checkpoints,marginality=False,**kwargs) for i in range(reps)]
        for day in checkpoints:
            for metric in ('packs','free_packs','collection_pct','playset_pct','affordable_unique_pct','key_access_complete','first_target_pct','meta_target_pct','target_essence_granted'):
                sensitivity.append({'variant':label,'model':mid,'profile':'F2P45','day':day,'metric':metric,'n':reps,**summarize([r['snapshots'][day][metric] for r in runs])})
        summary['models'][mid].setdefault('sensitivities',{})[label]={'completed_matches_mean':statistics.mean(r['completed_matches'] for r in runs),'essence_granted_mean':statistics.mean(r['essence_granted'] for r in runs)}
    metadata={'seed':seed,'repetitions':reps,'horizon_days':horizon,'base_trajectories':reps*len(models)*len(profiles),'sensitivity_trajectories':reps*5,'extra_pack_timing_cases':len(timing)*reps,'analysis_config_sha256':_hash(configanalysis),'economy_config_sha256':_hash(economy),'module_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'base_model_sha256':hashlib.sha256((ROOT/'tools/economy/model.py').read_bytes()).hexdigest(),'elapsed_seconds':round(time.time()-start,2),'status':'illustrative_analysis_not_implemented_prices_or_retention_evidence','target_essence_policy':'Once/account300at10/20/30/40completedmatches; permanent, target-baskets-only; noweeklyexpiry','crafting_policy':'First1L2Ethenfull12basket; secondbasketfromday180. Regularshardsremainbankedaftertargets. Affordablemetricsindependentlypricecheapestmissingcards; noextraownershipclaimed.','unsaturation_formula':'mean((extra_pack_new_unique/5)*(missing_unique_after_spending_regular_shards/max(1,missing_owned_unique))); clipped[0,1]. Conjecturalpack-demandproxy, notwillingness-to-pay.','weight_sets':WEIGHTS,'censoring':'Unreachedthresholdat730iscensored; cappedstatisticsuse731andarenotobservedcompletionmeans.','weekly_timing':'Earned10-matchweeklyrewardbankedatday7evenifofflineday; noadditionalclaimplayassumed.','expansion_sensitivity':'110syntheticcardsaddedat181/361/541/721; distinctIDs; existingcards/stocks/pityretained; noactualreleasecommitment.'}
    summary['metadata']=metadata
    _write_csv(out/'collection_metrics.csv',rows);_write_csv(out/'collection_monthly.csv',months);_write_csv(out/'collection_thresholds.csv',threshold_rows);_write_csv(out/'collection_marginality.csv',marginal_rows+timing);_write_csv(out/'collection_paid_gaps.csv',gaps);_write_csv(out/'collection_sensitivity.csv',sensitivity)
    (out/'collection_summary.json').write_text(json.dumps(summary,indent=2)+'\n');(out/'collection_metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    _plot(out,summary)
    return summary

def _plot(out,summary):
    colors=['#59bd9d','#ee8c6c','#83afff','#d5a7ef'];svg=['<svg xmlns="http://www.w3.org/2000/svg" width="900" height="470" viewBox="0 0 900 470"><rect width="900" height="470" fill="#141a28"/><g fill="#edf1f7" font-family="sans-serif"><text x="30" y="30" font-size="20">F2P45: marginal pack utility proxy (hypothetical demand link)</text>']
    for i in range(6):
        y=380-i*64;svg.append(f'<path d="M60 {y} H870" stroke="#354052"/><text x="12" y="{y+4}" font-size="12">{i/5:.1f}</text>')
    for i,(mid,item) in enumerate(summary['models'].items()):
        values=item['profiles']['F2P45']['monthly'];points=' '.join(f'{60+v["month"]/24*810:.1f},{380-v["unsaturation_factor"]*320:.1f}' for v in values)
        svg.append(f'<polyline points="{points}" fill="none" stroke="{colors[i]}" stroke-width="3"/><text x="{60+i*210}" y="435" fill="{colors[i]}" font-size="13">{mid}</text>')
    svg.append('<text x="400" y="410" font-size="13">Months 1–24</text></g></svg>');(out/'collection_marginality.svg').write_text('\n'.join(svg))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--config',default=str(DEFAULT_CONFIG));parser.add_argument('--repetitions',type=int,default=200);parser.add_argument('--output-dir');args=parser.parse_args()
    run_collection(json.loads(Path(args.config).read_text()),output_dir=args.output_dir,repetitions=args.repetitions)
