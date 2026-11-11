"""Validate complete paired production matches and report a reference-deck trial.

No simulated outcomes are manufactured here. A result is accepted only when all
112 predeclared pairs and eight exact fresh-constructor controls are present.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OPPONENTS={'prod-aggro','prod-midrange','prod-control','prod-shield','prod-block','prod-recurrence','prod-resonance','prod-movement','prod-species','prod-relic','prod-impulse','prod-convergence','prod-time','prod-resource'}
EVIDENCE_FIELDS=('case_index','variant','opponent','tested_side','first','seed_block','seed','difficulty','winner','round','convergence','censored','error','action_limit_reached','event_sha256','final_state_sha256','rng_state','rng_calls','pilot')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def summarize(data: dict) -> dict:
    require(data['format']=='ORAFOLD-BLOCK-DECK-RESULTS' and data['version']==1,'unknown experiment format')
    require(data['failures']==0,'engine assertions failed')
    plan=data['plan'];games=data['games'];repeats=data['verification_games']
    hashes=data['source_hashes']
    require(len(hashes)>=21 and hashes==plan['source_hashes'],'incomplete or mismatched executed source manifest')
    require(all(isinstance(value,str) and len(value)==64 and all(char in '0123456789abcdef' for char in value) for value in hashes.values()),'invalid source digest')
    require(len(plan['cases'])==112 and len(games)==224 and len(repeats)==8 and data['total_actual_games']==232,'incomplete actual matches')
    expected=Counter((side,first,block) for side in ('hero','enemy') for first in ('hero','enemy') for block in (0,1))
    coverage=defaultdict(Counter)
    seen_seeds=set()
    for index,case in enumerate(plan['cases']):
        require(type(case['index']) is int and case['index']==index,'invalid case index')
        require(type(case['seed']) is int,'integer seed required')
        require(case['seed'] not in seen_seeds,'reused case seed')
        seen_seeds.add(case['seed'])
        require(case['seed_search_start']<=case['seed']<case['seed_search_start']+500,'seed escaped its predeclared block')
        coverage[case['opponent']][case['tested_side'],case['first'],case['seed_block']]+=1
    require(set(coverage)==OPPONENTS and all(counts==expected for counts in coverage.values()),'lost opponent/seat/coin/seed-block coverage')
    by_case={}
    def validate_game(game):
        require(game['winner'] in ('hero','enemy','draw') and game['censored'] is False and game['error']=='' and type(game['action_limit_reached']) is int and game['action_limit_reached']==0,'incomplete/failed/unsupported game')
        require(game['difficulty']==2,'unapproved policy or resource advantage')
        for field in ('event_sha256','final_state_sha256'):
            require(isinstance(game[field],str) and len(game[field])==64 and all(c in '0123456789abcdef' for c in game[field]),'invalid deterministic digest')
        require(type(game['rng_state']) is int and 0<=game['rng_state']<=4294967295 and type(game['rng_calls']) is int and game['rng_calls']>=0,'missing actual RNG observation')
        require(type(game['case_index']) is int and 0<=game['case_index']<112,'invalid observed case index')
        case=plan['cases'][game['case_index']]
        require(all(game[key]==case[key] for key in ('opponent','tested_side','first','seed_block','seed','pilot')),'game differs from frozen plan')
        require(game['variant'] in ('baseline','candidate'),'unknown variant')
        tested='prod-block-'+game['variant']
        require(game[game['tested_side']]==tested,'wrong controlled reference deck')
        other='enemy' if game['tested_side']=='hero' else 'hero'
        require(game[other]==game['opponent'],'opponent changed between variants')
    for game in games:
        validate_game(game)
        key=game['case_index'],game['variant']
        require(key not in by_case,'duplicate matrix result')
        by_case[key]=game
    require(set(by_case)=={(index,variant) for index in range(112) for variant in ('baseline','candidate')},'missing A/B result')
    expected_repeats={(index,variant) for index in plan['repeat_cases_both_variants'] for variant in ('baseline','candidate')}
    seen_repeats=set()
    for game in repeats:
        validate_game(game)
        key=game['case_index'],game['variant']
        require(key in expected_repeats and key not in seen_repeats,'wrong or duplicate verification control')
        seen_repeats.add(key)
        original=by_case[key]
        require(all(game[field]==original[field] for field in ('event_sha256','final_state_sha256','rng_state','rng_calls','winner')),'fresh replay diverged')
    require(seen_repeats==expected_repeats,'incomplete deterministic repeats')
    stats={variant:{'games':0,'wins':0,'draws':0,'round_sum':0,'by_role':{},'by_first':{},'pilot':{'games':0,'wins':0},'known_card_energy_paid':0,'energy_at_action_phase':0,'unspent_energy_at_end':0,'action_net_resonance_spent':0,'failed_action_attempts':0,'relic_activations':0,'fortify_uses':0,'distinct_cards_played':set()} for variant in ('baseline','candidate')}
    opponents={opponent:{'games_per_variant':0,'baseline_wins':0,'candidate_wins':0} for opponent in sorted(coverage)}
    improved=regressed=0
    for case in plan['cases']:
        pair=[by_case[case['index'],variant] for variant in ('baseline','candidate')]
        won=[game['winner']==game['tested_side'] for game in pair]
        improved+=won==[False,True]
        regressed+=won==[True,False]
        opponents[case['opponent']]['games_per_variant']+=1
        for game,win in zip(pair,won):
            row=stats[game['variant']];side=game['tested_side'];metrics=game['metrics'][side]
            row['games']+=1;row['wins']+=win;row['draws']+=game['winner']=='draw';row['round_sum']+=game['round']
            opponents[case['opponent']][game['variant']+'_wins']+=win
            for key,value in [('by_role',side),('by_first','first' if game['first']==side else 'second')]:
                group=row[key].setdefault(value,{'games':0,'wins':0});group['games']+=1;group['wins']+=win
            if game['pilot']:row['pilot']['games']+=1;row['pilot']['wins']+=win
            for key in ('known_card_energy_paid','energy_at_action_phase','unspent_energy_at_end','action_net_resonance_spent','failed_action_attempts'):row[key]+=metrics[key]
            row['relic_activations']+=metrics['actions'].get('activate_relic',0)
            row['fortify_uses']+=metrics['actions'].get('fortify',0)
            row['distinct_cards_played'].update(metrics['cards_played'])
    for row in stats.values():
        row['win_rate']=row['wins']/row['games'];row['mean_half_turns']=row.pop('round_sum')/row['games']
        row['distinct_cards_played']=sorted(row['distinct_cards_played'])
        row['card_energy_utilization']=row['known_card_energy_paid']/max(1,row['energy_at_action_phase'])
    discordant=improved+regressed
    sign_p=sum(math.comb(discordant,k) for k in range(improved,discordant+1))/2**discordant if discordant else 1.0
    gain=stats['candidate']['wins']-stats['baseline']['wins']
    criteria=data['proposal']['promotion_criteria']
    require(criteria=={'minimum_additional_wins':12,'maximum_paired_sign_p_one_sided':0.05,'no_lower_wins_in_either_board_role':True,'all_games_completed_no_errors_no_action_limits':True,'full_state_event_rng_verification_games':8},'changed prespecified promotion criteria')
    require(plan['promotion_criteria']==criteria,'plan criteria changed after selection')
    role_ok=all(stats['candidate']['by_role'][side]['wins']>=stats['baseline']['by_role'][side]['wins'] for side in ('hero','enemy'))
    promote=gain>=criteria['minimum_additional_wins'] and sign_p<=criteria['maximum_paired_sign_p_one_sided'] and role_ok
    return {'matrix_games':224,'fresh_verification_games':8,'total_actual_games':232,'paired_cases':112,'failures':0,'variants':stats,'opponents':opponents,'candidate_only_wins':improved,'baseline_only_wins':regressed,'paired_sign_p_one_sided':sign_p,'additional_candidate_wins':gain,'gain_percentage_points':gain/112*100,'no_role_regression':role_ok,'prespecified_promotion_criteria':criteria,'promote_reference_composition':promote,'limits':['One existing policy at difficulty2, not optimal human play or a whole-pool balance proof.','Opening-coin-conditioned seeds and repeated strategy conditions do not establish independent human-game probabilities. The paired sign tail is a diagnostic, not a product-balance certification.','Only the Block reference composition may change; no rule, card, starter, resource or policy adjustment follows from this trial.']}


def verify_rejections(data):
    mutations=[
        lambda d:d['games'].pop(),
        lambda d:d['games'].append(d['games'][0]),
        lambda d:d['games'][0].update(censored=True),
        lambda d:d['games'][0].update(error='unsupported'),
        lambda d:d['games'][0].update(action_limit_reached=1),
        lambda d:d['games'][0].update(difficulty=5),
        lambda d:d['games'][0].update(first='enemy' if d['games'][0]['first']=='hero' else 'hero'),
        lambda d:d['games'][0].update(opponent='invented-deck'),
        lambda d:d['games'][0].update(rng_state=True),
        lambda d:d['games'][0].update(case_index=False),
        lambda d:d['verification_games'][0].update(event_sha256='0'*64),
        lambda d:d['verification_games'][0].update(final_state_sha256='0'*64),
        lambda d:d['verification_games'][0].update(rng_calls=d['verification_games'][0]['rng_calls']+1),
        lambda d:d['verification_games'].pop(),
        lambda d:d['source_hashes'].clear(),
        lambda d:d['proposal']['promotion_criteria'].update(minimum_additional_wins=0),
    ]
    for index,mutate in enumerate(mutations):
        broken=copy.deepcopy(data);mutate(broken)
        try:summarize(broken)
        except (ValueError,KeyError):continue
        raise ValueError(f'corrupted evidence case{index} was accepted')
    return len(mutations)


def write_evidence(data, plan_path: Path, destination: Path) -> dict:
    destination.mkdir(parents=True,exist_ok=True)
    files={}
    for filename,key in [('block-games.jsonl','games'),('block-verification.jsonl','verification_games')]:
        rows=sorted(data[key],key=lambda row:(row['case_index'],row['variant']))
        text=''.join(json.dumps({field:row[field] for field in EVIDENCE_FIELDS},sort_keys=True,separators=(',',':'))+'\n' for row in rows)
        path=destination/filename;path.write_text(text)
        require(len(path.read_text().splitlines())==len(rows),'compact evidence lost a game')
        files[filename]=hashlib.sha256(path.read_bytes()).hexdigest()
    target=destination/'block-plan.json';target.write_bytes(plan_path.read_bytes())
    files[target.name]=hashlib.sha256(target.read_bytes()).hexdigest()
    require(files[target.name]==data['plan_sha256'],'copied frozen plan changed')
    return files


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=ROOT/'work/premium-balance/results.json');parser.add_argument('--output',type=Path,default=ROOT/'work/premium-balance/summary.json');parser.add_argument('--check-sources',action='store_true');parser.add_argument('--verify-rejections',action='store_true');parser.add_argument('--evidence-dir',type=Path);args=parser.parse_args()
    data=json.loads(args.source.read_text());result=summarize(data)
    plan_path=args.source.parent/'plan.json'
    require(plan_path.is_file() and hashlib.sha256(plan_path.read_bytes()).hexdigest()==data['plan_sha256'] and json.loads(plan_path.read_text())==data['plan'],'frozen plan file does not match executed evidence')
    if args.check_sources:
        require(all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest for path,digest in data['source_hashes'].items()),'executed source bytes changed; do not relabel this historical report')
        require(json.loads((ROOT/'tools/premium/block_deck_proposal.json').read_text())==data['proposal'],'executed proposal differs from report')
    if args.verify_rejections:result['rejected_evidence_mutations']=verify_rejections(data)
    if args.evidence_dir:result['committed_evidence_sha256']=write_evidence(data,plan_path,args.evidence_dir)
    result['raw_sha256']=hashlib.sha256(args.source.read_bytes()).hexdigest();result['plan_sha256']=data['plan_sha256'];result['source_hashes']=data['source_hashes']
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True))


if __name__=='__main__':main()
