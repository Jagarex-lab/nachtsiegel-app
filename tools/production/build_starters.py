#!/usr/bin/env python3
"""Four visible production starter decks, derived from real reference decks.

The archived Alpha starter arrays are not changed. Mandatory cheap anchors make
turn-one plays discoverable; Ninth explicitly includes three same-power delayed
sources plus the original Umleitung for an actual legal prerequisite path.
"""
import argparse
import collections
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CONFIGS={
    'houses': ('prod-midrange',{'oa-houses-c01':3,'of-houses-001':2}),
    'stillwatch': ('prod-shield',{'oa-stillwatch-c01':3,'of-stillwatch-001':2}),
    'morph': ('prod-aggro',{'oa-morph-c01':3,'of-morph-001':2}),
    'ninth': ('prod-time',{'oa-ninth-c01':3,'of-ninth-001':3,'of-ninth-056':2,'oa-ninth-e01':2}),
}

def build(source,templates):
    by_id={c['id']:c for c in source['cards']}
    by_deck={d['id']:d for d in templates['decks']}
    result={}
    for power,(base,required) in CONFIGS.items():
        deck=by_deck[base]['cards'].copy()
        for id,n in required.items():
            assert by_id[id]['faction']==power
            while deck.count(id)<n:
                kind=by_id[id]['kind']
                removable=[x for x in deck if deck.count(x)>required.get(x,0)]
                assert removable
                # Prefer replacing the same kind, then expensive cards. Avoid
                # removal of another mandatory anchor before its own turn.
                old=max(removable,key=lambda x:(by_id[x]['kind']==kind,int(by_id[x]['cost']),x))
                deck.remove(old);deck.append(id)
        counts=collections.Counter(deck)
        assert len(deck)==30
        assert all(n<=(1 if by_id[id]['rarity']=='legendary' else 3) for id,n in counts.items())
        assert {by_id[id]['faction'] for id in deck}<={power,'neutral'}
        assert any(by_id[id]['faction']==power for id in deck)
        assert sum(1 for id in deck if by_id[id]['kind']=='creature' and by_id[id]['cost']==1)>=5
        deck.sort(key=lambda id:(by_id[id]['cost'],by_id[id]['kind'],id))
        result[power]=deck
    return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    source=json.loads((ROOT/'data/production/cards.json').read_text())
    templates=json.loads((ROOT/'data/production/test_decks.json').read_text())
    decks=build(source,templates)
    text=json.dumps(decks,ensure_ascii=False,indent=2)+'\n'
    path=ROOT/'data/production/starters.json'
    if args.check:assert path.read_text()==text,'Production starters differ from generator'
    else:path.write_text(text)
    print('PRODUCTION STARTERS: 4 legal 30-card decks; cheap anchors on all powers; Ninth delayed-source prerequisite included')
if __name__=='__main__':main()
