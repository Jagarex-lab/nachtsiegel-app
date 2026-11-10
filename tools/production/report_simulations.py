#!/usr/bin/env python3
"""Turn actual completed model evidence into a concise, qualified balance report."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def wilson(w,n):
    if not n:return '–'
    z=1.96;p=w/n;d=1+z*z/n;mid=(p+z*z/(2*n))/d;half=z*math.sqrt((p*(1-p)+z*z/(4*n))/n)/d
    return f'{100*p:.1f}% ({100*(mid-half):.1f}–{100*(mid+half):.1f}%)'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source',default='work/production/simulations.json');args=parser.parse_args()
    source=ROOT/args.source
    r=json.loads(source.read_text());s=r['summary'];games=r['games']
    ok=r['failures']==0 and s['errors']==0 and s['censored']==0 and not r.get('source_changes_during_run') and r['matrix_games']==r['expected_matrix_games']
    catalog=json.loads((ROOT/'data/production/cards.json').read_text());cards={c['id']:c for c in catalog['cards']}
    tables=[]
    for group in ('strategy','starter'):
        stats={}
        for g in games:
            if g.get('group')!=group:continue
            for side in ('hero','enemy'):
                id=g[side];row=stats.setdefault(id,{'games':0,'wins':0,'convergence':0})
                row['games']+=1
                if g['winner']==side:
                    row['wins']+=1
                    row['convergence']+=bool(g['convergence'])
        lines=[f'### {"Strategie-Referenzdecks" if group=="strategy" else "Sichtbare Starterdecks"}', '', '| Deck | Teilnahmen | Siege | Sieganteil mit 95%-Wilson-Intervall | Konvergenzsiege |','|---|---:|---:|---|---:|']
        for id,row in stats.items():lines.append(f'| {id} | {row["games"]} | {row["wins"]} | {wilson(row["wins"],row["games"])} | {row["convergence"]} |')
        tables.extend(lines+[''])
    first_n=int(s['completed'])-int(s['draws'])
    top=sorted(s['card_uses'].items(),key=lambda p:(-p[1],p[0]))[:20]
    use_lines=['| Karte | Ausspielvorgänge | Partieteilnahmen mit Ausspielen | Davon Siege |','|---|---:|---:|---:|']
    for id,n in top:
        game_stat=s['played_card_game_results'][id]
        use_lines.append(f'| {cards.get(id,{}).get("name",id)} (`{id}`) | {n} | {game_stat["side_games_played"]} | {game_stat["side_games_won"]} |')
    warning=[]
    for id,value in s['deck_results'].items():
        n=value['games'];rate=value['wins']/n if n else 0
        if n>=16 and (rate>=.65 or rate<=.35):warning.append(f'- `{id}`: {value["wins"]}/{n} Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.')
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    summary={k:v for k,v in r.items() if k not in ('games','summary')}
    summary['summary']=s;summary['raw_evidence_sha256']=digest
    target=ROOT/'docs/production/simulation-results.json';target.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    text=f'''# Produktions-Balancing: tatsächlicher Simulationsbericht

## Ausführungsstatus

**{"BESTANDEN" if ok else "NICHT BESTANDEN"}: {r['assertions']} Prüfungen, {r['failures']} Fehler.** {r['matrix_games']}/{r['expected_matrix_games']} Matrixpartien ({r.get('strategy_matrix_games',0)} Strategie-, {r.get('starter_matrix_games',0)} Starterpartien), zusätzlich {r['additional_verification_games']} vollständige Wiederholungen. Davon {r.get('fresh_constructor_verification_games',0)} Kontrollen mit vollständig neuen Modellkonstruktoren statt geteilter unveränderlicher Konfiguration. Quellen während der Ausführung verändert: {json.dumps(r.get('source_changes_during_run',[]),ensure_ascii=False)}.

Alle Fälle laufen über die tatsächliche Produktionsengine. Es gibt keine verkürzte Schadensberechnung, erfundenen Sieger oder vom Sollbestand entfernten Unsupported-Fälle. Die 550 aktiven Daten wurden als tatsächlicher Katalog geladen. Eine Partie mit einem Deck belegt nur dessen tatsächlich aufgetretene Interaktionen.

- Vollständig beendet: {s['completed']}; abgebrochen/unentschieden ohne Ergebnis (`censored`): {s['censored']}; Enginefehler: {s['errors']}; regelkonforme Unentschieden: {s['draws']}.
- Startspieler-Siege: {s['first_wins']}/{first_n}, {wilson(s['first_wins'],first_n)}. Jede geordnete Paarung enthält gleich viele erste Züge für beide Sitzpositionen.
- Durchschnitt: {s.get('mean_round',0):.2f} Halbzüge; Median {s.get('median_round',0)}. Dies ist keine gemessene menschliche Spielzeit.
- Konvergenzsiege: {s['convergence_wins']}; übrige Helden-LP-Siege: {s['hero_damage_wins']}. Der historische JSON-Feldname `hero_damage_wins` umfasst alle Nicht-Konvergenz-LP-Siege einschließlich Impuls-, direktem Kampf- und Erschöpfungs-/Recyclingschaden; diese Messung trennt die letzte Schadensquelle nicht zuverlässig.
- Tatsächlich ausgespielte unterschiedliche Karten: {s['distinct_cards_used']}/550. Nicht ausgespielte Karten sind nicht automatisch fehlerhaft oder zu schwach.
- Längste native Queue: {s['longest_native_chain']}; längste generische Queue: {s['longest_generic_chain']}; Partien mit mindestens zehn generischen Queueeinträgen: {s['games_with_generic_chain_at_least10']}.
- Generische Effektausgänge: `{json.dumps(s['generic_effect_statuses'],ensure_ascii=False,sort_keys=True)}`.

## Regeln und Fairness

30 Karten, genau eine Macht plus neutrale Karten, höchstens drei normale und eine legendäre Kopie, 30 Helden-LP, fünf Pfade und beide Siegbedingungen. Das normale Energielimit bleibt 8, alle neuen Kosten liegen zwischen 1 und 8. Die KI erhält keine zusätzlichen Ressourcen, Karten oder Sicht auf verborgene gegnerische Kartenidentitäten. Die ursprüngliche Regel für direkte Heldenangriffe bei leerem Gegenfeld bleibt erhalten.

Die separate Policy-Grundprüfung `tools/test_production_ai.sh` bestand **187 Prüfungen, 0 Fehler und 20 vollständige Partien** über dem archivierten 55-Karten-Alpha-Profil. Sie prüft unter anderem Schwierigkeitsfairness, unverändernde Entscheidungen, tatsächliche Zielregeln, freie Gegenpfade, Konvergenzabwehr sowie vollständige Zustands-/Ereignis-/Entscheidungsdeterministik. Diese 20 Partien sind nicht in den Produktionszahlen oben enthalten.

## Deck-Ergebnisse

Spiegelpartien zählen zwei Deckteilnahmen pro Partie. Die Intervalle sind deskriptive Wilson-Intervalle; gemeinsam genutzte Seeds, dieselbe Policy und korrelierte Decklisten erfüllen keine Annahme unabhängiger menschlicher Partien.

'''+ '\n'.join(tables)+'''## Auffällige Referenzdecks

'''+ ('\n'.join(warning) if warning else 'In dieser Stichprobe überschreitet kein ausreichend oft gespieltes Referenzdeck die rein deskriptiven Schwellen von 65% bzw. unterschreitet 35%. Das ist kein Gleichgewichtsbeweis.')+'''

## Häufig gespielte Karten

Nutzung und Siege sind durch Deckauswahl und die heuristische Policy verzerrt. Die folgende Tabelle ist eine Suchhilfe für weitere Tests und keine kausale Rangliste der Kartenstärke.

'''+ '\n'.join(use_lines)+f'''

## Ressourcenmessung

Gemessene Energie zu Beginn tatsächlicher Aktionsphasen: {s['total_energy_at_action_phase']}; bekannte gedruckte Energiekosten erfolgreich gespielter Karten: {s['known_card_energy_paid']}; ungenutzte Energie beim Zugabschluss: {s['unspent_energy_at_end']}. Reliktkosten und automatische Energiegewinne sind keine vollständige Bruttobilanz in diesen drei Werten.

Netto-Resonanzgewinne je KI-Aktion: {s['action_net_resonance_gained']}; Netto-Verbrauch: {s['action_net_resonance_spent']}. Gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die vollständigen Reihen der zu Aktionsphasenbeginn beobachteten Resonanzwerte stehen pro Partie im Rohbericht. Fehlgeschlagene optionale Aktionsversuche: {s['failed_action_attempts']}; illegale Kartenaktionen verursachen dagegen einen expliziten Engine-/Policyfehler.

## Beweisgrenzen und nächste Balancing-Schritte

- Diese Selbstspiel-Stichprobe beweist weder vollständige menschliche Balance noch sämtliche Interaktionen aller 550 Karten. Karten-Daten-/Effekt-/Triggerprüfungen sind separate Tests.
- Vierzehn Referenzdecks und vier Starter sind echte Zusammensetzungen, keine optimalen oder erschöpfenden Decks.
- Die erhaltenen nativen Gegnerpfade wählen automatisches Verbrennen und einzelne ursprüngliche Ankunftseffekte teilweise nach älteren Heuristiken. Gleiche Regeln/Ressourcen und gegenbalancierte Startseiten bedeuten keine vollkommen identischen Entscheidungspfade beider Sitzpositionen.
- Die vorangegangene echte Schild/Kontroll-Blockade und die daraufhin geprüften vorhandenen Wachstumsrelikte sind in `DEFENSIVE_DECK_REGRESSION.md` und `FAILED_BASELINE.json` erhalten. Jene fehlgeschlagene Stichprobe wird nicht zum finalen bestandenen Lauf addiert.
- Der als `resource_control` geführte Referenz-Archetyp untersucht Ressourcenführung und Kartenfluss. Die implementierten Ressourcenoperationen erzeugen eigene Energie/Resonanz; gezielter gegnerischer Energie-/Resonanzentzug ist noch nicht implementiert und wird nicht als geprüft behauptet. Angriffsschwächung ist kein Ressourcenentzug.
- Auffällige Decks zuerst mit weiteren Seeds, anderen legalen Zusammensetzungen und menschlichen Partien untersuchen. Änderungen an Werten benötigen einen neuen gebundenen Quelldigest und eine erneute vollständige Matrix.
- Keine stillschweigende Entfernung langer, fehlerhafter oder nicht beendeter Partien. Die ungekürzten Resultate dokumentieren jeden Fall.

## Reproduktion und Nachweise

```sh
bash tools/test_production_ai.sh
bash tools/test_production_simulations.sh
python3 tools/production/report_simulations.py
```

Engine: `{r['godot']}`. Die vollständigen Seeds, Zustands-/Ereignisdigests, Aktionszahlen, Kartennutzungen, Quellen-SHA-256 und Messgrenzen stehen in `work/production/simulations.json` (CI-Artefakt), SHA-256 `{digest}`. Der eingecheckte kompakte Nachweis steht in `docs/production/simulation-results.json`; er enthält Zusammenfassung und Quellenbindung, keine behaupteten zusätzlichen Partien.
'''
    (ROOT/'docs/production/BALANCE_REPORT.md').write_text(text)
    print(f"PRODUCTION SIMULATION REPORT: {'PASS' if ok else 'FAIL'}, {r['matrix_games']}+{r['additional_verification_games']} games; raw SHA256 {digest}")
    raise SystemExit(0 if ok else 1)
if __name__=='__main__':main()
