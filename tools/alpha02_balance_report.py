#!/usr/bin/env python3
"""Descriptive paired AI screening, not a human balance verdict."""
import collections,json,math,statistics
from pathlib import Path
rows=json.loads(Path('work/alpha02/balance.json').read_text())
assert len(rows)==768 and not any(r['error'] or r['censored'] for r in rows)
def wilson(w,n):
 z=1.96;p=w/n;d=1+z*z/n;c=(p+z*z/(2*n))/d;h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d
 return [round((c-h)*100,2),round((c+h)*100,2)]
report={}
for condition in ['official','convergence_off','origin_shield_off']:
 subset=[r for r in rows if r['condition']==condition];first=sum(r['winner']==r['first'] for r in subset)
 assert len(subset)==256 and sum(r['first']=='hero' for r in subset)==128
 powers={}
 for power in ['houses','stillwatch','morph','ninth']:
  games=[r for r in subset if r['hero']!=r['enemy'] and power in [r['hero'],r['enemy']]]
  wins=sum(r[r['winner']]==power for r in games)
  powers[power]={'wins':wins,'games':len(games),'wilson95_percent':wilson(wins,len(games))}
 report[condition]={'games':256,'first_wins':first,'first_wilson95_percent':wilson(first,256),'convergence_wins':sum(r['convergence'] for r in subset),'median_half_turns':statistics.median(r['round'] for r in subset),'max_half_turns':max(r['round'] for r in subset),'max_chain':max(r['longest_chain'] for r in subset),'non_mirror_power_results':powers}
reference={(r['hero'],r['enemy'],r['seed']):r for r in rows if r['condition']=='convergence_off'}
report['paired_winner_changes']=sum(r['winner']!=reference[r['hero'],r['enemy'],r['seed']]['winner'] for r in rows if r['condition']=='official')
Path('work/alpha02/balance-summary.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
