#!/usr/bin/env python3
"""Report the actual paired Alpha03 pilot; no inferred or synthetic games."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def summarize(report: dict) -> dict:
    games = report['games']
    errors = [g['index'] for g in games if g['error'] or g['censored'] or g['action_limit_reached'] or g['winner'] not in ('hero','enemy','draw')]
    if report['failures'] or errors or len(games) != 56 or report['matrix_games'] != 56:
        raise ValueError(f'Incomplete/failed pilot: {errors}')
    if report['total_actual_games'] != 60 or len(report['verification_games']) != 4:
        raise ValueError('Missing exact replay verification')
    seen = set()
    for repeat in report['verification_games']:
        index = repeat.get('index')
        if not isinstance(index, int) or index < 0 or index >= len(games) or index in seen:
            raise ValueError('Invalid or duplicate replay index')
        seen.add(index)
        if any(repeat.get(key) != games[index].get(key) for key in ('event_sha256','final_state_sha256')):
            raise ValueError('Replay diverges from actual matrix result')
    expected = Counter((difficulty, first) for difficulty in (1, 5) for first in ('hero', 'enemy'))
    pairings: dict[tuple, Counter] = defaultdict(Counter)
    for g in games:
        pairings[g['hero'], g['enemy']][g['difficulty'], g['first']] += 1
    if len(pairings) != 14 or any(c != expected for c in pairings.values()):
        raise ValueError('Lost paired difficulty/start balance')
    rows: dict[str, dict] = {}
    for g in games:
        for side in ('hero', 'enemy'):
            deck = g[side]
            row = rows.setdefault(deck, {'games':0,'wins':0,'first_games':0,'first_wins':0,'convergence_wins':0,'by_difficulty':{}})
            row['games'] += 1
            row['wins'] += g['winner'] == side
            row['first_games'] += g['first'] == side
            row['first_wins'] += g['winner'] == side and g['first'] == side
            row['convergence_wins'] += g['winner'] == side and g['convergence']
            level = row['by_difficulty'].setdefault(str(g['difficulty']), {'games':0,'wins':0})
            level['games'] += 1
            level['wins'] += g['winner'] == side
    first = sum(g['winner'] == g['first'] for g in games)
    return {'matrix_games':len(games),'replay_games':4,'errors':errors,'first_wins':first,'convergence_games':sum(g['convergence'] for g in games),'mean_half_turns':sum(g['round'] for g in games)/len(games),'decks':rows}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='work/alpha03/balance-fresh.json')
    parser.add_argument('--output', default='docs/alpha03/balance-fresh-summary.json')
    args = parser.parse_args()
    source = ROOT / args.source
    report = json.loads(source.read_text())
    result = summarize(report)
    result['raw_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    result['source_hashes'] = report['source_hashes']
    result['note'] = '56 targeted actual matches plus4 exact repeats; no human balance claim. These results belong only to the listed source hashes.'
    path = ROOT / args.output
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
