#!/usr/bin/env python3
"""Reproduce all economy evidence: python3 tools/economy/simulate_progression.py."""
import argparse, copy, csv, hashlib, json, math, re, statistics, time
from collections import Counter, defaultdict
from pathlib import Path
from model import CHECKPOINTS, RARITIES, ROOT, Collection, load_config, profile_run, summarize

OUT=ROOT/'docs/economy/results'

def write_csv(name, rows):
    if not rows:return
    with (OUT/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def plot_series(filename,title,series,ylabel,ymax=None):
    colors=['#62d9b5','#79a9ff','#e0b858','#e984c9','#ef775e']
    allv=[y for points in series.values() for x,y in points]
    ymax=ymax or max(allv)*1.1 or 1
    width=880;height=440;left=72;right=20;top=60;bottom=70
    def x(v):return left+v/365*(width-left-right)
    def y(v):return height-bottom-v/ymax*(height-top-bottom)
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="#141a28"/><g font-family="sans-serif" fill="#edf1f7"><text x="25" y="30" font-size="20">{title}</text>']
    for i in range(6):
        n=ymax*i/5;svg += [f'<path d="M{left} {y(n):.1f} H{width-right}" stroke="#354052"/><text x="10" y="{y(n)+4:.1f}" font-size="12">{n:.0f}</text>']
    for d in (1,30,90,180,365):svg.append(f'<text x="{x(d):.1f}" y="{height-bottom+22}" font-size="12">{d}</text>')
    for i,(key,points) in enumerate(series.items()):
        color=colors[i%len(colors)];coords=' '.join(f'{x(a):.1f},{y(b):.1f}' for a,b in points)
        svg.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="3"/>')
        svg.append(f'<text x="{left+i*145}" y="{height-15}" fill="{color}" font-size="13">{key}</text>')
    svg.append(f'<text x="{width/2}" y="{height-38}" font-size="13">Days · {ylabel}</text></g></svg>')
    (OUT/filename).write_text('\n'.join(svg))

def booster_trials(config, n, seed):
    c=Collection(config,seed)
    raw=Counter();actual=Counter();gap=0;gaps=[];packlegend=0;epicgap=0;maxepic=0
    # Base draws separate from guaranteed-pity process to avoid conflating displayed odds.
    base=Collection(config,seed+1)
    for _ in range(n):
        before=c.packs;rolled=c.booster();actual.update(rolled)
        if 'legendary' in rolled:gaps.append(gap+1);gap=0;packlegend+=1
        else:gap+=1
        if any(r in ('epic','legendary') for r in rolled):maxepic=max(maxepic,epicgap+1);epicgap=0
        else:epicgap+=1
        # Do not modify collection in base IID rate sampling.
        for slot in config['booster_rules']['slots']:
            for _ in range(slot['count']):raw[base.roll(slot['rates'])]+=1
    expected={r:sum(s['count']*s['rates'].get(r,0) for s in config['booster_rules']['slots'])/5 for r in RARITIES}
    rows=[]
    for r in RARITIES:
        p=raw[r]/(5*n);se=math.sqrt(p*(1-p)/(5*n))
        rows.append({'rarity':r,'base_expected_card_share':expected[r],'base_observed_card_share':p,'base_ci95_low':p-1.96*se,'base_ci95_high':p+1.96*se,'with_pity_card_share':actual[r]/(5*n),'card_samples':5*n})
    write_csv('booster_rates.csv',rows)
    return {'packs':n,'max_legendary_gap':max(gaps),'p95_legendary_gap':summarize(gaps)['p95'],'mean_legendary_gap':statistics.mean(gaps),'max_epic_or_better_gap':maxepic,'legendary_pack_fraction':packlegend/n,'rates':rows}

def milestone_trials(config,repetitions,seed):
    rows=[]
    for label in ('baseline','milestones400'):
        cfg=copy.deepcopy(config)
        if label=='baseline':
            for milestone in cfg['progression']['milestones']:
                if milestone['level'] in (5,10):milestone['reward']='challenge'
        values=[profile_run(cfg,cfg['scenarios']['profiles']['B'],cfg['scenarios']['models']['balanced'],seed+10000+i)[0] for i in range(repetitions)]
        for day in (7,30,90):
            rows.append({'model':label,'profile':'B','day':day,'n':repetitions,
                'key_access_complete_pct':100*statistics.mean(v[day]['key_access_complete'] for v in values),
                'target_complete_pct':100*statistics.mean(v[day]['target_complete'] for v in values),
                'target_pct_mean':statistics.mean(v[day]['target_pct'] for v in values)})
    write_csv('milestone_comparison.csv',rows)
    return rows

def run(repetitions=None,pack_trials=100000,config_snapshot=None):
    OUT.mkdir(parents=True,exist_ok=True)
    config=json.loads(Path(config_snapshot).read_text()) if config_snapshot else load_config();sc=config['scenarios'];repetitions=repetitions or sc['repetitions'];seed=sc['seed']
    rows=[];completion={};start=time.time()
    for si,(scenario,values) in enumerate(sc['models'].items()):
        for pi,(name,profile) in enumerate(sc['profiles'].items()):
            samples=defaultdict(list);days=[]
            for trial in range(repetitions):
                snapshots,complete=profile_run(config,profile,values,seed+si*1000000+pi*10000+trial)
                days.append(complete if complete is not None else 366)
                for day,snap in snapshots.items():
                    for metric,value in snap.items():samples[day,metric].append(value)
            completion[scenario,name]={'completed_by365_pct':100*sum(x<=365 for x in days)/len(days),**summarize(days)}
            for (day,metric),vals in samples.items():rows.append({'scenario':scenario,'profile':name,'day':day,'metric':metric,'n':repetitions,**summarize(vals)})
            print(f'{scenario}/{name}: {repetitions} trajectories in {time.time()-start:.1f}s',flush=True)
    write_csv('progression_summary.csv',rows)
    write_csv('target_completion.csv',[{'scenario':s,'profile':p,**v} for (s,p),v in completion.items()])
    if not config_snapshot:milestone_trials(config,repetitions,seed)
    booster=booster_trials(config,pack_trials,seed+9000000)
    # Pair identical random seeds to isolate hoarding, extension and welcome-shard assumptions.
    sensitivity=[]
    variants={'expansion181':{'expansion':True},'hoard_gold':{'hoard':True},'common_only_starters':{'starter_unique':40},'no_welcome_crafting':{},'no_upgrade_milestones':{}}
    for variant,kwargs in variants.items():
        cfg=copy.deepcopy(config)
        if variant=='no_welcome_crafting':cfg['rewards']['definitions']['onboarding']['crafting']=0
        if variant=='no_upgrade_milestones':
            for m in cfg['progression']['milestones']:
                if m['level'] in (5,10):m['reward']='challenge'
        samples=defaultdict(list)
        for trial in range(repetitions):
            snapshots,_=profile_run(cfg,sc['profiles']['B'],sc['models']['balanced'],seed+10000+trial,**kwargs)
            for day in (30,180,365):
                for metric,value in snapshots[day].items():samples[day,metric].append(value)
        for (day,metric),vals in samples.items():sensitivity.append({'variant':variant,'profile':'B','day':day,'metric':metric,'n':repetitions,**summarize(vals)})
    write_csv('sensitivity_summary.csv',sensitivity)
    lookup={(r['scenario'],r['profile'],r['day'],r['metric']):r for r in rows}
    for metric,title,limit in [('collection_pct','550-card collection: unique ownership',100),('target_pct','Target deck upgrade access proxy',100),('gold_earned','Cumulative gold earned',None)]:
        series={p:[(d,lookup['balanced',p,d,metric]['mean']) for d in CHECKPOINTS] for p in sc['profiles']}
        plot_series(metric+'.svg',title,series,metric,limit)
    metadata={'seed':seed,'repetitions_per_profile_scenario':repetitions,'profile_scenario_trajectories':repetitions*len(sc['models'])*len(sc['profiles']),'sensitivity_trajectories':repetitions*len(variants),'paired_milestone_trajectories':repetitions*2 if not config_snapshot else 0,'booster_pack_trials':pack_trials,'booster':booster,'elapsed_seconds':round(time.time()-start,2),'config_sha256':hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest(),'model_sha256':hashlib.sha256((ROOT/'tools/economy/model.py').read_bytes()).hexdigest(),'status':'provisional_synthetic_catalog_no_winrate_or_revenue_validation'}
    (OUT/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    if not config_snapshot:report(config,lookup,completion,sensitivity,metadata)

def report(config,lookup,completion,sensitivity,metadata):
    def stat(s,p,d,m):return lookup[s,p,d,m]['mean']
    comparison={(r['model'],int(r['day'])):r for r in csv.DictReader((OUT/'milestone_comparison.csv').open())}
    def cmp(model,day,metric):return float(comparison[model,day][metric])
    lines=['# Wirtschaftssimulation – vorläufige Alpha-Parameter','',
        '**Simuliert, nicht im Hauptspiel integriert.** Alle Wirtschaftswerte sind vorläufig. Synthetische IDs bilden 550 Karten ab; dieser Bericht behauptet weder 550 implementierte Kartenfähigkeiten noch gemessene Kampfstärke oder Umsatz.','',
        '## Reproduktion und Unsicherheit','',
        '`python3 tools/economy/simulate_progression.py` liest sämtliche Parameter aus `data/economy/*.json`. Python-Standardbibliothek; keine zusätzlichen Pakete. '+f"Seed {metadata['seed']}; {metadata['repetitions_per_profile_scenario']} unabhängige Trajektorien je Profil und Szenario, insgesamt {metadata['profile_scenario_trajectories']}, zusätzlich {metadata['sensitivity_trajectories']} Sensitivitätsläufe und {metadata['paired_milestone_trajectories']} gepaarte Meilensteinläufe; {metadata['booster_pack_trials']:,} Booster für Raten/Pity. ",
        '`target_completion.csv` verwendet Tag366 für bisTag365 unvollständige Decks; Mittelwert und Quantile sind dann rechtszensierte Kennzahlen. Bei den aktuellen Szenarien erreichen alle200 Trajektorien je Profil das vollständige Upgrade innerhalb365 Tagen.\n\nCSV-Dateien enthalten Mittelwert, empirische P05/P95 und approximatives 95%-Konfidenzintervall des Mittelwerts. P05/P95 beschreiben Spielerstreuung, nicht Konfidenz. Normalintervalle binärer Erfolgswerte sind nur Näherungen; 200 Läufe lösen extreme 0,1%-Randfälle nicht auf. Der harte Pity-Grenzwert wird zusätzlich deterministisch getestet.','',
        '## Annahmen','',
        '- Kennzahlen:`total_cards_acquired` zählt Starterkopien, sämtliche Boosterfunde (einschließlich später umgewandelter Duplikate) und hergestellte Karten. `cards_received` zählt ausschließlich Booster-Rohzufluss; `playable_copies` zählt den aktuell nutzbaren Besitz nach Umwandlung. `starter_copies` und `crafted_cards` schlüsseln den restlichen Zufluss auf.',
        '- Katalog:250 gewöhnliche,160 seltene,100 epische,40 legendäre Karten. Fraktionen sind Platzhalter; Seltenheit ist kein gemessener Stärkeparameter.',
        '- Starterbesitz modelliert den aktuellen Adapter:17 gewöhnliche IDs/51 Kopien,20 seltene IDs/56 Kopien,4 legendäre IDs/4 Kopien =41 IDs/111 gebundene physische Kopien. Vier Decklisten à30 teilen drei neutrale Kopien. Zielkarten sind zusätzliche IDs. Alle Zielkarten gehören derselben synthetischen Macht; Fraktionszugehörigkeit ist ein Ressourcenmodell, kein Nachweis einer legalen finalen550-Strategie.',
        '- Jede zehnminütige Partie wird als gültig abgeschlossen modelliert. Tagesaufgabe:1 Partie; optionale10 gespielte Karten werden ab2 Partien angenommen. Wochenaufgabe10 Partien wird konservativ am siebten Tag ausgezahlt. Kein Sieg, täglicher Login oder absichtlich schlechter Spielzug erforderlich. Teilnahme/Questquoten sind Modellannahmen, keine Telemetrie.',
        '- Kampagnenkapitel werden an Tagen1/3/7/14/30 abgeschlossen; deren Spielzeit ist in den Partien enthalten. Keine Kampagnenschwierigkeit simuliert.',
        '- Gold wird sofort für Standardbooster ausgegeben. Boosterbudgets D/E sind externe Modellparameter ohne Echtgeldbetrag und ohne implementierten Shop. Gleichmäßige monatliche Vergabe.',
        '- Crafting:fehlende Ziellegende und zwei gezielte epische Schlüsselkarten zuerst, danach übrige seltene und epische Zielkopien. Keine manuelle Verwertung brauchbarer oder gebundener Karten; kein Sammlungsvollständigkeits-Crafting nach dem Zieldeck. Daher sind spätere Shardbestände eine bewusste konservative Senkenannahme.',
        '- Zieldeckzugang ist ein Ressourcenproxy:18 vorhandene Starterkopien +8 seltene Kopien (4 IDs×2),3 epische IDs×1,1 legendäre ID. Vier Starterstrategien gelten als verfügbar; eine fünfte Strategie wird nur als Proxy nach vollständigen12 Upgradekopien gezählt. Keine Decklegalitäts-, Siegquoten- oder Balancegarantie.',
        '- Spielerlevel5 und10 gewähren jeweils400 Herstellungsressource zusätzlich zu50Gold/50XP. Diese einmaligen Meilensteine wurden anhand der Simulation ergänzt; Gold-/XP-Werte sonst gleich.',
        '- Onboarding enthält300 Gold,5 Booster und1200 Herstellungsressource; die Ziellegende kann direkt hergestellt werden. Alle Starter-Legenden bleiben zusätzlich gebunden. Preise sind reine Gold-Testwerte.',
        '- Godot und Python verwenden verschiedene Zufallsgeneratoren. Die gleichen Datenregeln werden modelliert, keine bitidentische Folge behauptet. Die Simulation ist keine serverseitige Sicherheitsevidenz.','',
        '## Profile und Balanced-Ergebnisse','',
        '|Profil|Min/Tag|Extra-Booster/30 Tage|Tag30 Booster|Tag30 Sammlung|Tag90 Sammlung|Tag365 Sammlung|',
        '|---|---:|---:|---:|---:|---:|---:|']
    for p,v in config['scenarios']['profiles'].items():lines.append(f"|{p}|{v['minutes_per_day']}|{v['purchased_boosters_per_30_days']}|{stat('balanced',p,30,'packs'):.1f}|{stat('balanced',p,30,'collection_pct'):.1f}%|{stat('balanced',p,90,'collection_pct'):.1f}%|{stat('balanced',p,365,'collection_pct'):.1f}%|")
    lines+=['','|Profil|Schlüsselkarten Tag30 vollständig|12 Upgrades Tag30 Mittel/P05|12 Upgrades vollständig Tag30|Tag365 spielbare Kopien|Tag365 Legendäre Kopien|','|---|---:|---:|---:|---:|---:|']
    for p in config['scenarios']['profiles']:
        r=lookup['balanced',p,30,'target_pct'];lines.append(f"|{p}|{100*stat('balanced',p,30,'key_access_complete'):.1f}%|{r['mean']:.1f}% / {r['p05']:.1f}%|{100*stat('balanced',p,30,'target_complete'):.1f}%|{stat('balanced',p,365,'playable_copies'):.1f}|{stat('balanced',p,365,'legendary'):.1f}|")
    lines+=['','![Sammlungsfortschritt](results/collection_pct.svg)','', '![Zieldeckzugang](results/target_pct.svg)','',
        '## Booster und Pity','',
        'Vier Basisslots:80% gewöhnlich/17% selten/2,5% episch/0,5% legendär; ein garantierter Slot:80% selten/18% episch/2% legendär. Die Basis-Chance auf mindestens eine Legende pro Booster ist `1−0,995⁴×0,98 =3,945%`. Pity ersetzt den letzten Slot bei Bedarf:spätestens Booster5 episch oder höher, Booster20 legendär. Legendär setzt beide Zähler zurück; Pity läuft über Sitzungen weiter.','',
        f"Gemessen:{metadata['booster']['legendary_pack_fraction']*100:.2f}% Booster mit Legende einschließlich Pity; mittlerer Abstand {metadata['booster']['mean_legendary_gap']:.2f}, P95 {metadata['booster']['p95_legendary_gap']:.1f}, maximal {metadata['booster']['max_legendary_gap']}; maximaler episch-oder-besser-Abstand {metadata['booster']['max_epic_or_better_gap']}. Basisslot-Raten und Konfidenzintervalle: `results/booster_rates.csv`. Pity verändert effektive Gesamtwahrscheinlichkeiten, nicht die veröffentlichten Basisslot-Chancen.",'',
        '## Szenarienvergleich und Fairness','',
        '|Szenario|B Booster Tag30|B Sammlung Tag90|B Schlüsselkarten vollständig Tag30|B12 Upgrades Tag30|B12 Upgrades vollständig Tag90|','|---|---:|---:|---:|---:|---:|']
    for s in config['scenarios']['models']:lines.append(f"|{s}|{stat(s,'B',30,'packs'):.1f}|{stat(s,'B',90,'collection_pct'):.1f}%|{100*stat(s,'B',30,'key_access_complete'):.1f}%|{stat(s,'B',30,'target_pct'):.1f}%|{100*stat(s,'B',90,'target_complete'):.1f}%|")
    gap=stat('balanced','E',30,'collection_pct')-stat('balanced','B',30,'collection_pct')
    lines+=['',f"Der zahlungs-/zeitbedingte B→E-Abstand an Tag30 beträgt {gap:.1f} Prozentpunkte einzigartige Sammlung. B und D unterscheiden sich nur im externen Boosterbudget; B und E zusätzlich in Spielzeit. Seltenheit kann stärkere Fähigkeiten bedeuten:größere Auswahl und frühere Upgrades bleiben ein Pay-to-win-Risiko. Ohne stabile Decks, Matchmaking und Kampfsimulation ist eine tatsächliche Überlegenheit nicht quantifizierbar.",
        'Messbares vorläufiges Fairnessziel aus der Konfiguration:regelmäßige F2P-Spieler sollen bisTag30 eine gezielte Legende und zwei epische Karten erreichen. `key_access_complete` misst dieses Zugangsziel; `target_pct`/`target_complete` messen getrennt das anspruchsvollere vollständige12-Kopien-Upgrade. Diese beiden Maße sind keine Wettbewerbsgarantie. Bewertung außerdem anhand der P05-Zielkopienquote. Ein hoher Mittelwert allein erfüllt dieses Ziel nicht. Vier Starter und eine gezielt herstellbare Legende begrenzen den Ausschluss, garantieren aber keine kompetitive Parität.','',
        '## Inflation, Erweiterung und Senken','',
        '|Profil|Tag365 Gold erhalten|Gold ausgegeben|Goldbestand|Shardbestand|Duplikate|','|---|---:|---:|---:|---:|---:|']
    for p in config['scenarios']['profiles']:lines.append(f"|{p}|{stat('balanced',p,365,'gold_earned'):.0f}|{stat('balanced',p,365,'gold_spent'):.0f}|{stat('balanced',p,365,'gold_balance'):.0f}|{stat('balanced',p,365,'shards'):.0f}|{stat('balanced',p,365,'duplicate_cards'):.0f}|")
    lines+=['','Geschlossene Ökonomie ohne Spielerhandel:Goldhortung ist Kaufkraftüberhang, keine Marktpreis-Inflation. Ausgeben hält Gold unter einem Boosterpreis; ein Sparer kann einen großen Bestand bilden. Herstellungsressourcen akkumulieren nach Erreichen des Zieldecks, weil das Modell weitere Crafts bewusst aussetzt. Eine echte Expansion/Handelsökonomie braucht serverseitige Bestands- und Senkenregeln; lokale Bestände dürfen keinen Marktwert bekommen.','',
        'Sensitivität für Profil B, Balanced (`results/sensitivity_summary.csv`):hypothetische110-Karten-Erweiterung abTag181 bei gleichen Slots/Preisen und gemeinsamem Pity; Goldhortung; alternative40×3 gewöhnliche Starter; Onboarding ohne1200 Herstellungsressource; Zugang ohne die neuen400er-Meilensteine. Die Erweiterung senkt die Vollständigkeitsquote durch den größeren Nenner und verdünnt gezielte Ziehchancen. Bestehende Karten, Ressourcen und Pity werden nicht gelöscht.','',
        'Crafting-Senken sind strikt teurer als Verwertung:Kosten40/100/400/1200, Erlös5/20/80/240. Craft→Verwerten verliert mindestens80% (gewöhnlich87,5%); Starter und kosmetische Varianten erzeugen keine wiederholbaren Ressourcen. Goldquellen sind an einmalige Quellen-IDs, Tageslimits und Questperioden zu binden; der lokale Simulationsseed beweist keinen Manipulationsschutz.','',
        '## Optimierung gegenüber dem Ausgangsmodell','',
        f"Eine gepaarte{metadata['repetitions_per_profile_scenario']}-Seed-Untersuchung fürProfilB hielt Gold/Booster und die Priorisierung der drei Schlüsselkarten konstant. Ohne400er-Craftingmeilensteine erreichten{cmp('baseline',7,'key_access_complete_pct'):.1f}% die drei Schlüsselkarten bisTag7 und{cmp('baseline',30,'key_access_complete_pct'):.1f}% bisTag30; mit400 Ressource aufLevel5 und10 erreichten{cmp('milestones400',7,'key_access_complete_pct'):.1f}% diese Ziele bereits bisTag7. Die vollständigen12 Upgrades stiegen anTag30 von{cmp('baseline',30,'target_complete_pct'):.1f}% auf{cmp('milestones400',30,'target_complete_pct'):.1f}%; durchschnittliche Kopienabdeckung von{cmp('baseline',30,'target_pct_mean'):.1f}% auf{cmp('milestones400',30,'target_pct_mean'):.1f}%. Quelle:`results/milestone_comparison.csv`. Deshalb wurden die beiden einmaligen Ressourcenmeilensteine in die vorläufige Konfiguration aufgenommen.",'', 
        'Das frühere Ausgangsmodell mit Legende→selten→episch-Priorität ist vollständig als `baseline_config.json`, `baseline_progression_summary.csv` und `baseline_metadata.json` erhalten. Reproduktion ohne Überschreiben der finalen CSVs:`python3 tools/economy/simulate_progression.py --config-snapshot docs/economy/results/baseline_config.json --output-dir /tmp/orafold-baseline`. Der Bericht enthält die finalen Werte; der archivierte Baseline-CSV beschreibt die ältere Craftingpriorität und einen ursprünglichen, fraktionsgemischten Ressourcenwarenkorb gleicher Seltenheitsverteilung. Die finale Zielauswahl verwendet eine Macht. `no_upgrade_milestones` isoliert dagegen die Ressourcenänderung unter gleicher finaler Priorität.','',
        'Die Verbesserung ist ein gezielter kostenloser Zugangspfad und keine beliebige Freischaltung aller Strategien. Dass innerhalb eines Jahres viele Sammlungen beinahe vollständig werden und große Shardbestände entstehen, begrenzt ein Geschäftsmodell mit ausschließlich Sammlungsbeschleunigung. Neue Erweiterungen und optionale Kosmetik sind zu prüfen; künstliche Ressourcenlöschung oder verpflichtender Grind sind daraus nicht abzuleiten.','',
        '## Grenzen und nächste Entscheidungen','',
        '- Die endgültigen550 IDs, Fraktionsverteilung, Seltenheiten und Starterqualität sind externe Integrationsabhängigkeiten. Der heutige Alpha-Katalog enthält keine epischen Karten; der synthetische Pool wird ausdrücklich als Testdatensatz verwendet.',
        '- Aktuelles Modell setzt tägliche Teilnahme voraus. Fehlende Wochen/Tage kosten nur ausbleibende Belohnung; es gibt keine Verluststrafe oder Loginserie. Retention und Frust müssen mit realer Telemetrie validiert werden.',
        '- Keine Verkaufspreise, Erlösprognosen, Käufe, Handel oder produktive Servertransaktionen implementiert. Wirtschaftliche Tragfähigkeit kann aus Packbudgets allein nicht abgeleitet werden.',
        '- Deckzugang, Kampfstärke und Vielfalt brauchen stabile Katalog-/Kampfschnittstellen. Kosmetikfinanzierung, Ranked-Normalisierung und garantierte wettbewerbsfähige Deckpfade bleiben Produktentscheidungen.',
        '- Vollständige Checkpoints1/7/30/90/180/365 mit Gold, Packs, Karten, Seltenheiten, Crafting, Kopien, Sammlung und Strategieproxies sind in den CSV-Dateien enthalten; Konfidenzintervalle und Seeds ermöglichen Wiederholung.']
    sensitivity_lookup={(r['variant'],r['day'],r['metric']):r['mean'] for r in sensitivity}
    table=['|B Sensitivität|Tag365 Goldbestand|Tag365 Sammlung|Tag365 Shards|Schlüsselkarten Tag30 vollständig|','|---|---:|---:|---:|---:|']
    for variant in dict.fromkeys(r['variant'] for r in sensitivity):
        table.append(f"|{variant}|{sensitivity_lookup[variant,365,'gold_balance']:.0f}|{sensitivity_lookup[variant,365,'collection_pct']:.1f}%|{sensitivity_lookup[variant,365,'shards']:.0f}|{100*sensitivity_lookup[variant,30,'key_access_complete']:.1f}%|")
    insertion=next(i for i,line in enumerate(lines) if line.startswith('Crafting-Senken'))
    lines[insertion:insertion]=table+['']
    rendered='\n'.join(lines)+'\n'
    for old,new in [('Tag30','Tag 30'),('Tag90','Tag 90'),('Tag365','Tag 365'),('Tag181','Tag 181'),('Tag7','Tag 7'),('Level5','Level 5'),('Level10','Level 10'),('ProfilB','Profil B'),('fürProfil','für Profil '),('gepaarte200','gepaarte 200'),('Ohne400','Ohne 400'),('mit400','mit 400'),('und10','und 10'),('und8%','und 8%'),('erreichten2,5%','erreichten 2,5%'),('erreichten100%','erreichten 100%'),('vollständigen12','vollständigen 12'),('endgültigen550','endgültigen 550'),('Checkpoints1/','Checkpoints 1/'),('Kosten40/','Kosten 40/'),('Erlös5/','Erlös 5/'),('ohne1200','ohne 1200'),('neuen400er','neuen 400er'),('hypothetische110','hypothetische 110'),('alternative40','alternative 40'),('Spielerlevel5','Spielerlevel 5'),('jeweils400','jeweils 400'),('zu50Gold/50XP','zu 50 Gold/50 XP'),('enthält300','enthält 300'),('Gold,5','Gold, 5'),('und1200','und 1200'),('Katalog:250','Katalog: 250'),(',160',', 160'),(',100',', 100'),(',40',', 40'),('Basisslots:80','Basisslots: 80'),('Slot:80','Slot: 80'),('Bedarf:spätestens','Bedarf: spätestens'),('Booster5','Booster 5'),('Booster20','Booster 20'),('als120','als 120'),('Tag1/','Tag 1/'),('an Tagen1/','an Tagen 1/'),('Tagesaufgabe:1','Tagesaufgabe: 1'),('optionale10','optionale 10'),('ab2','ab 2'),('Wochenaufgabe10','Wochenaufgabe 10'),('Mittelwerts. Normal','Mittelwerts. Normal'),('Ziellegende und zwei','Ziellegende und zwei'),('Ressourcenproxy:18','Ressourcenproxy: 18'),(' +8',' + 8'),(',3 epische',', 3 epische'),(',1 legendäre',', 1 legendäre'),('vollständigen12','vollständigen 12'),('B12 Upgrades','B: 12 Upgrades')]:
        rendered=rendered.replace(old,new)
    rendered=re.sub(r'\b(bis|an|ab|auf)(Tag|Level)',r'\1 \2',rendered)
    for old,new in [('Adapter:17','Adapter: 17'),(',20 seltene',', 20 seltene'),(',4 legendäre',', 4 legendäre'),('=41','= 41'),('à30','à 30'),('Crafting:fehlende','Crafting: fehlende'),('Gemessen:7','Gemessen: 7'),('bedeuten:größere','bedeuten: größere'),('Konfiguration:regelmäßige','Konfiguration: regelmäßige'),('vollständige12','vollständige 12'),('Spielerhandel:Goldhortung','Spielerhandel: Goldhortung'),('):hypothetische','): hypothetische'),('Verwertung:Kosten','Verwertung: Kosten'),('mindestens80','mindestens 80'),('gewöhnlich87','gewöhnlich 87'),('für Profil  B','für Profil B'),('von0,5','von 0,5'),('auf13','auf 13'),('von70,0','von 70,0'),('auf83,9','auf 83,9'),('Quelle:`','Quelle: `'),('CSVs:`','CSVs: `')]:rendered=rendered.replace(old,new)
    rendered=re.sub(r'\b(erreichten|und|von|auf)(?=\d)',r'\1 ',rendered)
    destination=ROOT/'docs/economy/SIMULATION-REPORT.md' if OUT.resolve()==(ROOT/'docs/economy/results').resolve() else OUT/'SIMULATION-REPORT.md'
    destination.write_text(rendered)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--repetitions',type=int);p.add_argument('--pack-trials',type=int,default=100000);p.add_argument('--config-snapshot');p.add_argument('--output-dir');args=p.parse_args()
    if args.output_dir:OUT=Path(args.output_dir)
    run(args.repetitions,args.pack_trials,args.config_snapshot)
