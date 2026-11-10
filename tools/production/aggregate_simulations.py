#!/usr/bin/env python3
"""Validate disjoint real simulation shards and aggregate the exact complete matrix.

This does not generate matches, winners or replacement evidence. Every accepted
record must appear in one successful Godot result and its predeclared case set.
"""
from __future__ import annotations
import argparse
import collections
import copy
import tempfile
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def case_key(c):
    assert isinstance(c['seed'],int) and not isinstance(c['seed'],bool) and c['seed']>=0,'Invalid exact seed in match evidence'
    return (c['group'],c['hero'],c['enemy'],c['seed'])


def summary_equal(actual,expected):
    if isinstance(expected,dict):return isinstance(actual,dict) and actual.keys()==expected.keys() and all(summary_equal(actual[k],v) for k,v in expected.items())
    if isinstance(expected,list):return isinstance(actual,list) and len(actual)==len(expected) and all(summary_equal(a,b) for a,b in zip(actual,expected))
    if isinstance(expected,float):return isinstance(actual,(int,float)) and math.isfinite(actual) and math.isclose(actual,expected,rel_tol=1e-12,abs_tol=1e-12)
    return actual==expected


def summarize(records):
    s=dict(games=len(records),completed=0,censored=0,errors=0,draws=0,first_wins=0,convergence_wins=0,hero_damage_wins=0,round_sum=0,deck_results={},power_results={},matchups={},card_uses={},unknown_card_ids=[],event_counts={},total_energy_at_action_phase=0,known_card_energy_paid=0,unspent_energy_at_end=0,action_net_resonance_gained=0,action_net_resonance_spent=0,failed_action_attempts=0,longest_native_chain=0,longest_generic_chain=0,games_with_generic_chain_at_least10=0,generic_effect_statuses={},played_card_game_results={})
    rounds=[]
    for r in records:
        s['censored']+=bool(r['censored']);s['completed']+=not r['censored'];s['errors']+=bool(r['error']);s['draws']+=r['winner']=='draw';s['first_wins']+=r['winner']==r['first']
        s['convergence_wins']+=bool(r['convergence']);s['hero_damage_wins']+=not r['convergence'] and r['winner'] in ('hero','enemy')
        s['round_sum']+=int(r['round']);rounds.append(int(r['round']))
        for name in ('longest_native_chain','longest_generic_chain'):s[name]=max(s[name],int(r[name]))
        s['games_with_generic_chain_at_least10']+=int(r['longest_generic_chain'])>=10
        for status,n in r['generic_effect_statuses'].items():s['generic_effect_statuses'][status]=s['generic_effect_statuses'].get(status,0)+int(n)
        for side in ('hero','enemy'):
            for group,key in (('deck_results',r[side]),('power_results',r[side+'_power'])):
                value=s[group].setdefault(key,dict(games=0,wins=0,first_games=0,first_wins=0,convergence_wins=0,nonmirror_games=0,nonmirror_wins=0))
                value['games']+=1;value['first_games']+=side==r['first'];value['wins']+=side==r['winner'];value['first_wins']+=side==r['first']==r['winner'];value['convergence_wins']+=side==r['winner'] and r['convergence']
                value['nonmirror_games']+=r['hero_power']!=r['enemy_power'];value['nonmirror_wins']+=r['hero_power']!=r['enemy_power'] and side==r['winner']
            m=r['metrics'][side]
            for name in ('known_card_energy_paid','unspent_energy_at_end','action_net_resonance_gained','action_net_resonance_spent','failed_action_attempts'):s[name]+=int(m[name])
            s['total_energy_at_action_phase']+=int(m['energy_at_action_phase'])
            for id,n in m['cards_played'].items():
                s['card_uses'][id]=s['card_uses'].get(id,0)+int(n)
                value=s['played_card_game_results'].setdefault(id,dict(side_games_played=0,side_games_won=0))
                value['side_games_played']+=1;value['side_games_won']+=side==r['winner']
        pair=r['hero']+'/'+r['enemy'];value=s['matchups'].setdefault(pair,dict(games=0,hero_wins=0,enemy_wins=0,draws=0,censored=0));value['games']+=1
        value['hero_wins']+=r['winner']=='hero';value['enemy_wins']+=r['winner']=='enemy';value['draws']+=r['winner']=='draw';value['censored']+=bool(r['censored'])
        for kind,n in r['event_counts'].items():s['event_counts'][kind]=s['event_counts'].get(kind,0)+int(n)
    if rounds:s['mean_round']=sum(rounds)/len(rounds);s['median_round']=sorted(rounds)[len(rounds)//2]
    s['distinct_cards_used']=len(s['card_uses']);s['first_win_rate']=s['first_wins']/max(1,s['completed']-s['draws'])
    return s


def aggregate(paths):
    assert paths,'No actual shard evidence supplied'
    loaded=[(p,json.loads(p.read_text())) for p in paths]
    first=loaded[0][1]
    n=int(first['shard_count']);per_first=int(first['seeds_per_first_side'])
    assert n>1,'Aggregation expects actual split runs'
    assert len(loaded)==n,f'Expected {n} successful shard files, got {len(loaded)}'
    indices=[int(r['shard_index']) for _,r in loaded]
    assert sorted(indices)==list(range(n)),f'Missing/duplicate shard indices: {indices}'
    assert not first['quick'],'Quick ring is not the full matrix'
    source=json.loads((ROOT/'data/production/test_decks.json').read_text())
    catalog=json.loads((ROOT/'data/production/cards.json').read_text())
    deck_ids=[d['id'] for d in source['decks']];starter_ids=['starter-'+p for p in ('houses','stillwatch','morph','ninth')]
    assert len(deck_ids)==14 and len(set(deck_ids))==14
    expected_pairs={('strategy',a,b) for a in deck_ids for b in deck_ids}|{('starter',a,b) for a in starter_ids for b in starter_ids}
    expected_global=len(expected_pairs)*per_first*2
    assert int(first['expected_global_matrix_games'])==expected_global
    records=[];planned={};actual={};verified=0;fresh_verified=0;assertions=0;by_shard=[]
    for path,r in loaded:
        assert r['profile']==first['profile'] and r['godot']==first['godot']
        assert r['source_sha256']==first['source_sha256'],'Shards ran different source contents'
        assert int(r['shard_count'])==n and int(r['seeds_per_first_side'])==per_first and not r['quick']
        assert int(r['expected_global_matrix_games'])==expected_global
        assert r['failures']==0 and not r['source_changes_during_run'],f'Failed or non-frozen shard: {path}'
        assert len(r['games'])==r['matrix_games']==r['expected_matrix_games']>0
        assert r['additional_verification_games']==r['expected_verification_games']
        assert summary_equal(r['summary'],summarize(r['games'])),f'Shard summary differs from its actual match records: {path}'
        shard=int(r['shard_index'])
        for c in r['planned_cases']:
            key=case_key(c);pair=key[:3]
            assert pair in expected_pairs,f'Unexpected planned pair: {pair}'
            global_pair=(deck_ids.index(c['hero'])*14+deck_ids.index(c['enemy'])) if c['group']=='strategy' else 196+starter_ids.index(c['hero'])*4+starter_ids.index(c['enemy'])
            assert global_pair%n==shard,f'Case assigned to wrong shard: {key}'
            assert key not in planned,f'Overlapping planned case: {key}'
            assert c['first'] in ('hero','enemy') and isinstance(c['seed'],int) and c['seed']>=0
            planned[key]=c
        for g in r['games']:
            key=case_key(g)
            assert key not in actual,f'Overlapping actual case: {key}'
            assert not g['censored'] and not g['error'] and not g['action_limit_reached'],f'Incomplete/error case {key}'
            assert g['winner'] in ('hero','enemy','draw')
            assert len(g['event_sha256'])==64 and len(g['final_state_sha256'])==64
            actual[key]=g;records.append(g)
        verified+=int(r['additional_verification_games']);fresh_verified+=int(r['fresh_constructor_verification_games']);assertions+=int(r['assertions'])
        by_shard.append(dict(index=shard,games=r['matrix_games'],verification_games=r['additional_verification_games'],file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    assert set(planned)==set(actual),f'Planned/actual cases differ: missing={set(planned)-set(actual)}, extra={set(actual)-set(planned)}'
    assert len(actual)==expected_global,f'Incomplete global matrix {len(actual)}/{expected_global}'
    assert {key[:3] for key in actual}==expected_pairs,'Missing directed pair'
    for pair in expected_pairs:
        rows=[g for key,g in actual.items() if key[:3]==pair]
        assert len(rows)==per_first*2
        assert collections.Counter(g['first'] for g in rows)=={'hero':per_first,'enemy':per_first},f'Unbalanced first sides: {pair}'
        assert all(planned[case_key(g)]['first']==g['first'] for g in rows)
    assert verified==18,f'Expected18 directed-deck replay controls globally, got {verified}'
    assert fresh_verified>=2,'Missing fresh-constructor equivalence controls'
    for relative,digest in first['source_sha256'].items():
        assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest,f'Current checkout differs from executed source {relative}'
    records.sort(key=lambda g:case_key(g))
    valid_ids={c['id'] for c in catalog['cards']}
    summary=summarize(records)
    assert set(summary['card_uses'])<=valid_ids,'Unrecognized card in actual use evidence'
    report=dict(schema_version=1,profile=first['profile'],godot=first['godot'],quick=False,shard_index=0,shard_count=n,aggregated=True,shards=sorted(by_shard,key=lambda x:x['index']),seeds_per_first_side=per_first,expected_global_matrix_games=expected_global,expected_matrix_games=expected_global,matrix_games=len(records),strategy_matrix_games=sum(g['group']=='strategy' for g in records),starter_matrix_games=sum(g['group']=='starter' for g in records),additional_verification_games=verified,expected_verification_games=18,fresh_constructor_verification_games=fresh_verified,assertions=assertions,failures=0,measurement_notes=first['measurement_notes']+['Aggregate verifies every successful shard source binding, disjoint predeclared case sets, exact212 directed pair coverage,848 cases at default sampling, and balanced first sides; it generates no games.'],source_sha256=first['source_sha256'],source_changes_during_run=[],planned_cases=[planned[k] for k in sorted(planned)],games=records,summary=summary)
    return report


def verify_rejections(paths):
    """Negative guard checks mutate only copies of actual completed evidence.

    They are metadata-integrity tests, not generated or additional played games.
    """
    actual=[json.loads(p.read_text()) for p in paths]
    checks=0
    def reject(label,mutate):
        nonlocal checks
        rows=copy.deepcopy(actual)
        rows=mutate(rows) or rows
        with tempfile.TemporaryDirectory(prefix='orafold-negative-evidence-') as directory:
            files=[]
            for i,row in enumerate(rows):
                target=Path(directory)/f'{i}.json';target.write_text(json.dumps(row));files.append(target)
            try:aggregate(files)
            except (AssertionError,KeyError,ValueError):checks+=1
            else:raise AssertionError('Corrupt actual evidence was accepted: '+label)
    reject('missing shard',lambda rows:rows[:-1])
    def duplicate(rows):rows[1]['shard_index']=rows[0]['shard_index']
    reject('duplicate shard index',duplicate)
    def hash_mismatch(rows):rows[1]['source_sha256'][next(iter(rows[1]['source_sha256']))]='0'*64
    reject('mixed executed sources',hash_mismatch)
    def missing_case(rows):rows[0]['games'].pop()
    reject('missing actual game',missing_case)
    def wrong_winner(rows):rows[0]['games'][0]['winner']=None
    reject('nonexistent winner',wrong_winner)
    def wrong_first(rows):
        game=rows[0]['games'][0];game['first']='enemy' if game['first']=='hero' else 'hero'
    reject('wrong first-side record',wrong_first)
    def missing_replay(rows):
        rows[0]['additional_verification_games']=0;rows[0]['expected_verification_games']=0
    reject('omitted replay control',missing_replay)
    def checkout_mismatch(rows):
        for row in rows:row['source_sha256'][next(iter(row['source_sha256']))]='0'*64
    reject('current checkout differs',checkout_mismatch)
    def extra_case(rows):
        record=copy.deepcopy(rows[0]['games'][0]);record['seed']=999999;rows[0]['games'].append(record)
        rows[0]['matrix_games']+=1;rows[0]['expected_matrix_games']+=1
    reject('extra unplanned actual case',extra_case)
    def censored(rows):rows[0]['games'][0]['censored']=True
    reject('censored game',censored)
    return checks


def main():
    parser=argparse.ArgumentParser();parser.add_argument('files',nargs='+',type=Path);parser.add_argument('--output',type=Path,default=ROOT/'work/production/simulations.json');parser.add_argument('--verify-rejections',action='store_true');args=parser.parse_args()
    report=aggregate(args.files)
    if args.verify_rejections:report['negative_evidence_guard_tests']=verify_rejections(args.files)
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(f"PRODUCTION AGGREGATE: {len(report['shards'])} successful disjoint shards; {report['matrix_games']} exact real matches +{report['additional_verification_games']} verification games; no missing/extra cases")
if __name__=='__main__':main()
