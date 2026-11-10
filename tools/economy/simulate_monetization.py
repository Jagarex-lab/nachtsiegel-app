#!/usr/bin/env python3
"""Reproduce the analysis-only collection/commercial comparison for PR #16."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from model import ROOT, load_config as load_economy
from monetization_collection import run_collection
from monetization_revenue import load_config, run_revenue, validate_config

DEFAULT_OUT = ROOT / 'docs/economy/monetization-results'
LABELS = {'baseline96': 'Bisherige Vergabe', 'scarcity': 'Sammlungsknappheit',
          'protected_weekly': 'Geschützter Deckpfad', 'cosmetics_first': 'Kosmetikschwerpunkt'}


def render_report(config, collection, revenue, report_path, output_dir):
    def profile(mid, pid='F2P45'):
        return collection['models'][mid]['profiles'][pid]
    def value(mid, day, metric, pid='F2P45'):
        return profile(mid, pid)['checkpoints'][str(day)][metric]['mean']
    def horizon(scenario, mid, months=24):
        return revenue['results'][scenario][mid]['expected']['horizons'][str(months)]
    def threshold(mid, key):
        t = profile(mid)['thresholds'][key]
        median = t['observed_median_days']
        return ('–' if median is None else f'{median:.0f}') + f" / {100*t['censored_fraction']:.1f}%"
    try:
        relative = output_dir.relative_to(report_path.parent)
    except ValueError:
        relative = output_dir
    def link(filename):
        return str(relative / filename)
    lines = [
        '# Kommerzielle Tragfähigkeit: vorläufige Monetarisierungsanalyse', '',
        '**Analyse und Simulation, keine aktivierte Produktwirtschaft.** Alle Geldbeträge, Retentionswerte, Kaufquoten, Kaufkörbe und Kosten sind unbestätigte Annahmen. Die Untersuchung ändert weder Echtgeldprodukte noch aktive Wirtschaftswerte oder Kampfregeln.', '',
        '## Empfehlung', '',
        'Den **geschützten kostenlosen Deckpfad** als nächsten Produktkandidaten testen: geringerer wiederholbarer Boosterzufluss, ein dauerhafter gezielter Zugangspfad und optionale Kosmetik beziehungsweise ein rein kosmetischer Saisonpass. Diese Empfehlung setzt den kostenlosen Zugang als Nebenbedingung voraus. Sie ist keine bestätigte Umsatz- oder Gewinnprognose. Das Knappheitsmodell erzeugt zusätzlichen Sammlungsbedarf, verstärkt aber bei bewusst stärkeren hohen Seltenheiten den wirtschaftlich bedingten Leistungsvorsprung. Ein bloßes Kürzen kostenloser Belohnungen ist deshalb keine ausreichende Lösung.', '',
        'Die aktive Vergabe bleibt unverändert. Vor einem Produktentscheid müssen die unten ausgewiesenen Deckzugangs-, Nachfrage- und Kostenschwellen mit finalen Karten und freiwilligen Spieltests geprüft werden. Die Bezeichnung `protected_weekly` ist nur eine Szenario-ID: die Zielmeilensteine verfallen nicht wöchentlich.', '',
        '## Reproduktion und Stichprobe', '',
        '```sh',
        'python3 tools/economy/simulate_monetization.py',
        'python3 -m unittest discover -s tests -p "economy*_test.py" -v',
        '```', '',
        f"Seed {config['seed']}; {collection['metadata']['repetitions']} gepaarte Sammlungsläufe je Modell und Profil, {collection['metadata']['base_trajectories']} Grundtrajektorien, {collection['metadata']['sensitivity_trajectories']} Sensitivitätsläufe über {config['horizon_days']} Tage. Finanzrechnung: {config['repetitions']} endliche Kohortenstichproben je Modell/Retentionsszenario, insgesamt {config['repetitions']*len(config['models'])*len(config['revenue_scenarios'])}, über {config['cohort']['months']} Modellmonate.", '',
        'CSV und JSON enthalten Mittelwerte, P05/P95 beziehungsweise Konfidenznäherungen. Streuung der Zufallsstichprobe und unbekannte Produktannahmen sind unterschiedliche Unsicherheiten. 200 erfolgreiche Läufe sind kein Beweis einer garantierten Spielerquote; für extreme Randfälle ist die Stichprobe zu klein. Nicht erreichte Zeitschwellen werden zensiert ausgewiesen, nicht als tatsächlicher Fertigstellungstag ausgegeben.', '',
        '## Vier kontrollierte Wirtschaftsmodelle', '',
        '| Modell | Wiederholbares Gold relativ | Boosterpreis in Gold | Zusätzlicher kostenloser Deckpfad |',
        '|---|---:|---:|---|',
    ]
    for mid, model in config['models'].items():
        protection = model['target_protection']
        grant = 'Keiner' if not protection['enabled'] else '4 × 300 zielgebundenes Herstellungsbudget bei 10/20/30/40 Partien'
        lines.append(f"| {LABELS[mid]} | {model['recurring_gold_multiplier']:.2f} | {model['booster_price_gold']} | {grant} |")
    lines += ['',
        'Onboarding, vorhandene vier Starter, Pity, Seltenheitsraten, reguläre Herstellungskosten und bestehende XP-Meilensteine bleiben als Grundlage erhalten. Nur das wiederholbare Gold wird multipliziert; einmaliges Level-/Kampagnengold bleibt erhalten. Das zusätzliche Zielbudget ist eine **Analyseannahme für gebundene Zielkarten**, keine neu implementierte Währung. Es wird pro Konto höchstens einmal gewährt und nicht als unbeschränkte Sammlungskaufkraft gezählt.', '',
        'Der vollständige Deckpfad umfasst zwölf gezielte Upgradekopien zusätzlich zu angenommenen Starterkopien. Die Kennzahl Schlüsselkarten umfasst eine Legende und zwei bestimmte epische Karten. Ab Tag 180 wird ein zweiter Warenkorb derselben Macht als Metawandel angenommen. Der synthetische Katalog beweist weder Decklegalität noch tatsächliche Matchup-Stärke.', '',
        '## Kostenloser Fortschritt und Kaufvorsprung', '',
        '| Modell | F2P45 kostenlose Booster Tag 30 | Schlüsselkarten komplett Tag 30 | Vollständiges Upgrade Tag 30 F2P45 | Dasselbe mit 40 Extra-Boostern/30 Tage |',
        '|---|---:|---:|---:|---:|',
    ]
    for mid in config['models']:
        lines.append(f"| {LABELS[mid]} | {value(mid,30,'free_packs'):.0f} | {100*value(mid,30,'key_access_complete'):.1f}% | {100*value(mid,30,'first_target_complete'):.1f}% | {100*value(mid,30,'first_target_complete','paid40'):.1f}% |")
    lines += ['',
        '| Modell | Zugang zu nutzbaren Kopien, seltenheitsgewichtet Tag 30 F2P45 | Vorsprung mit 40 Extra-Boostern: moderate / starke Gewichtung in Prozentpunkten | Zweites Upgrade Tag 180 F2P45 / mit 40 Extra-Boostern vollständig |',
        '|---|---:|---:|---:|',
    ]
    for mid in config['models']:
        moderate = value(mid,30,'rarity_weighted_access_moderate','paid40')-value(mid,30,'rarity_weighted_access_moderate')
        steep = value(mid,30,'rarity_weighted_access_steep','paid40')-value(mid,30,'rarity_weighted_access_steep')
        lines.append(f"| {LABELS[mid]} | {value(mid,30,'rarity_weighted_access_moderate'):.1f}% | {moderate:.1f} / {steep:.1f} | {100*value(mid,180,'meta_target_complete'):.1f}% / {100*value(mid,180,'meta_target_complete','paid40'):.1f}% |")
    lines += ['',
        'Gewichte für gewöhnlich/selten/episch/legendär: moderat 1/1,5/2/3 und stark 1/2/4/8. Sie sind offengelegte Sensitivitätsannahmen für Zugang zu stärkeren Seltenheiten, keine geschätzten Siegwahrscheinlichkeiten. Trotz gleichem ersten Zieldeck bleibt durch breitere Kartenverfügbarkeit ein potenzieller Leistungsvorteil. Zwei feste Warenkörbe decken die Vielfalt einer realen Meta nicht vollständig ab.', '',
        'Die Nachhol-Sensitivität spielt an nur drei Tagen je Woche und vergibt ausschließlich erreichte dauerhafte Matchmeilensteine. Die Ergebnisse sind in `collection_sensitivity.csv` enthalten; es wird keine tägliche Loginserie vorausgesetzt.',
    ]
    lines += ['',
        'Die Kaufvergleiche verwenden dieselbe Spielzeit von 45 Minuten und dieselben Seeds. Dadurch wird der frühere Vergleich eines normalen mit einem zusätzlich viel aktiveren Budgetspieler entkoppelt. Die Boosterbudgets 4 und 40 sind Kartenfluss-Sensitivitäten. Sie sind keine Behauptung über eine tatsächlich beobachtete Ausgabenverteilung.', '',
        '| Modell F2P45 | 90% einzigartige Karten: Median / zensiert | 95% einzigartige Karten: Median / zensiert | 90% spielbare Kopien: Median / zensiert | Sammlung Tag 365 | Durch Essenz bezahlbare einzigartige Sammlung Tag 365 |',
        '|---|---:|---:|---:|---:|---:|',
    ]
    for mid in config['models']:
        lines.append(f"| {LABELS[mid]} | {threshold(mid,'unique90')} | {threshold(mid,'unique95')} | {threshold(mid,'playset90')} | {value(mid,365,'collection_pct'):.1f}% | {value(mid,365,'affordable_unique_pct'):.1f}% |")
    lines += ['',
        'Die Zeitschwellen beziehen sich auf den Grundkatalog ohne Erweiterung. Bezahlbare Sammlung ist eine alternative Verwendung vorhandener regulärer Essenz, keine zusätzliche tatsächlich gebuchte Sammlung. Einzigartige Definitionen und spielbare Kopiensätze werden getrennt betrachtet.', '',
        '## Schwächen 96 kostenlose Booster den Kaufanreiz?', '',
        '**Für dauerhaft aktive Sammler: ja, sie verkürzen im Modell den Zeitraum mit wesentlichem zusätzlichem Sammlungsnutzen. Eine bestimmte Kaufquote lässt sich daraus nicht ableiten.** Die Zahl 96 ist zudem der erste Monat eines täglich aktiven 45-Minuten-Profils mit erledigten Aufgaben und Kampagnenbelohnungen. Sie ist kein gemessener Mittelwert aller Spieler. Spätere Monate enthalten weniger einmalige Einstiegsbelohnungen.', '',
        '| Modell | Kostenlose Booster Monat 1 | Monat 3 | Monat 12 | Neue einzigartige Karten durch einen Extra-Booster Tag 30 | Tag 180 | Tag 360 |',
        '|---|---:|---:|---:|---:|---:|---:|',
    ]
    for mid in config['models']:
        months = profile(mid)['monthly']
        # Marginal one-pack probes are measured at month boundaries; month6=day180.
        lines.append(f"| {LABELS[mid]} | {months[0]['mean_free_packs_in_month']:.0f} | {months[2]['mean_free_packs_in_month']:.0f} | {months[11]['mean_free_packs_in_month']:.0f} | {months[0]['marginal_new_unique_per_pack']:.2f} | {months[5]['marginal_new_unique_per_pack']:.2f} | {months[11]['marginal_new_unique_per_pack']:.2f} |")
    lines += ['',
        'Die letzte Spalte verwendet die nächstliegende Monatssonde Tag 360; genaue Proben für Tag 365 stehen in `collection_marginality.csv`. Neue epische/legendäre Definitionen, Duplikatessenz und verkürzte Zieldeckzeit stehen dort gesondert. Die Messung eines neuen Kartenfundes ist keine Zahlungsbereitschaftsmessung.', '',
        f"![Zusatznutzen weiterer Booster]({link('collection_marginality.svg')})", '',
        '## Bindung, Kaufquote und Ausgabenannahmen', '',
        '| Szenario | Hypothetische Bindung Tag 1 / 30 / 365 | Kaufabsicht je gebundenem Monat | Aktivitätsparameter Spieltage/Monat |',
        '|---|---:|---:|---:|',
    ]
    for sid, scenario in config['revenue_scenarios'].items():
        retention = scenario['retention_probability']
        lines.append(f"| {sid} | {100*retention['1']:.1f}% / {100*retention['30']:.1f}% / {100*retention['365']:.1f}% | {100*scenario['monthly_payer_probability']:.1f}% | {scenario['active_days_per_retained_month']} |")
    lines += ['',
        'Alle Wirtschaftsmodelle teilen im kontrollierten Fall dieselben Bindungs- und Kaufabsichtsparameter. Es wird kein erfundener Bindungsbonus für das empfohlene Modell angenommen. Die Kurve beschreibt vereinfachte absorbierende Kohortenbindung, keine gemessene klassische Return-Retention und keinen Wiedereinstieg. Monatlich gebundene Konten, Aktivitätstage und tatsächliche zahlende Konten sind getrennte Kennzahlen.', '',
        'Kaufkörbe sind disjunkte Gruppen mit möglichen Produktkombinationen innerhalb einer Gruppe. ARPPU wird aus Ausgaben geteilt durch tatsächlich zahlende Konten berechnet. Kaufabsicht vor Sammlungssättigung ist daher nicht gleich realisierte Käuferquote. Einsteigerpakete zählen einmal; der Pass wird freiwillig zu Saisonbeginn angeboten und enthält ausschließlich Kosmetik. Hypothetische Produktbudgets und Ausgabenmultiplikatoren sind in der Analysekonfiguration offengelegt. Steuerexklusive Modellbeträge sind keine genehmigten Preise.', '',
        'Der Umsatz verwendet eine stark vereinfachte Verknüpfung mit dem zusätzlichen Sammlungsnutzen des `paid4`-Inventarprofils. Dieses spielt täglich; eine zeitgleiche Übertragung auf gelegentlich aktive Kunden kann die Sättigung überschätzen und die Nachfrage unterschätzen. Es gibt keine vollständige Rückkopplung zwischen individuellen Käufen, Inventaren und späteren Käufen. Das Verhalten bei Booster-Nachfragekollaps und geringer Kosmetiknachfrage wird deshalb gesondert ausgewiesen.', '',
        '## Bedingte Umsatz- und Kostenrechnung', '',
        f"Eine einzelne Kohorte mit {config['cohort']['acquired_players']:,} erworbenen Konten, ohne weitere Zugänge, über 24 Modellmonate. Steuern werden nicht bestimmt; die Eingaben sind steuerexklusiv. Erstattungen ({100*config['costs']['refund_fraction']:.0f}%), Plattformabzüge ({100*config['costs']['platform_fee_fraction']:.0f}%), variable Kosten, Fixkosten ({config['costs']['fixed_cost_per_month_eur']:.0f} EUR/Monat) und angenommene Akquisitionskosten werden getrennt berücksichtigt.", '',
        '| Annahme | Modell | Ausgaben vor Gebühren 12 Monate EUR | 24 Monate EUR | Deckungsbeitrag je gewonnenem Konto vor CAC/Fixkosten EUR | Ergebnis nach zugerechneten Fixkosten/CAC EUR |',
        '|---|---|---:|---:|---:|---:|',
    ]
    for sid in config['revenue_scenarios']:
        for mid in config['models']:
            t12, t24 = horizon(sid, mid, 12), horizon(sid, mid)
            lines.append(f"| {sid} | {LABELS[mid]} | {t12['gross_spend_ex_vat_eur']:.0f} | {t24['gross_spend_ex_vat_eur']:.0f} | {t24['contribution_ltv_before_cac_eur']:.3f} | {t24['operating_profit_after_acquisition_eur']:.0f} |")
    lines += ['',
        '| Basisszenario | P05 bis P95 der 24-Monats-Ausgaben EUR |',
        '|---|---:|',
    ]
    for mid in config['models']:
        sample = revenue['results']['base'][mid]['sampling_intervals']['24']['gross_spend_ex_vat_eur']
        lines.append(f"| {LABELS[mid]} | {sample['p05']:.0f}–{sample['p95']:.0f} |")
    lines += ['', 'Diese Bänder zeigen ausschließlich Zufallsstreuung der endlichen Kohorte bei festgehaltenen Annahmen. Die tatsächliche Unsicherheit über Bindung, Kaufinteresse und Ausgaben ist wesentlich größer und nicht durch dieses Band abgedeckt.']
    lines += ['',
        f"![Bedingte Umsätze]({link('revenue_scenarios.svg')})", '',
        '### Tatsächliche Käuferquote und durchschnittliche Ausgaben', '',
        '| Szenario, geschützter Deckpfad | Realisierte Käuferquote Monat 1 | Ausgaben je zahlendem Konto Monat 1 EUR | Monat 12 EUR |',
        '|---|---:|---:|---:|',
    ]
    for sid in config['revenue_scenarios']:
        monthly = revenue['results'][sid]['protected_weekly']['expected']['monthly']
        lines.append(f"| {sid} | {100*monthly[0]['realized_payer_probability']:.2f}% | {monthly[0]['gross_monthly_arppu_eur']:.2f} | {monthly[11]['gross_monthly_arppu_eur']:.2f} |")
    lines += ['',
        'Die Werte gelten vor Gebühren und bei steuerexklusiven Eingaben. Monatlich zahlende Konten werden über Produkte hinweg einmal gezählt; die Summe der Zahler-Monate ist keine Anzahl unterschiedlicher Jahreskunden. Saisonbeginn und Einmalangebot beeinflussen den Monatsvergleich.', '',
        '| Geschützter Deckpfad: Ausgabenmultiplikator bei unveränderter Kaufabsicht | Deckungsbeitrag pro gewonnenem Konto vor CAC/Fixkosten EUR |',
        '|---|---:|',
    ]
    for row in revenue['spending_sensitivity']:
        if row['model'] == 'protected_weekly':
            lines.append(f"| {row['assumed_basket_spend_multiplier']:.1f}× | {row['contribution_ltv_before_cac_eur']:.3f} |")
    lines += ['',
        'Die Multiplikatoren variieren hypothetische Ausgaben, nicht empirisch geschätzte Preiselastizitäten. Unterstellte höhere Budgets beweisen keine Nachfrage bei einem höheren tatsächlichen Verkaufspreis.', '',
        '### Organische Zugänge und Kostendeckung', '',
        '| Modell, Basisszenario | Erforderliche organische Neuzugänge pro Monat bei 0 CAC | Erforderliche durchschnittliche Ausgaben pro Zahler-Monat bei 50000 Neuzugängen EUR | Erforderliche Kaufabsicht bei 50000 Neuzugängen |',
        '|---|---:|---:|---:|',
    ]
    for row in revenue['steady_state_organic_sensitivity']:
        if row['monthly_organic_new_users'] == 50000:
            minimum = row['minimum_monthly_organic_new_users_for_fixed_cost']
            arppu = row['required_gross_weighted_monthly_arppu_eur']
            conversion = row['required_pre_utility_monthly_payer_probability']
            lines.append(f"| {LABELS[row['model']]} | {'nicht erreichbar' if minimum is None else f'{minimum:.0f}'} | {'–' if arppu is None else f'{arppu:.2f}'} | {'–' if conversion is None else f'{100*conversion:.2f}%'} |")
    lines += ['',
        'Diese separate stationäre Rechnung überlagert 24 Alterskohorten bei konstantem organischem Zufluss. Sie ist kein Ergebnis der Einmalkohorte, keine Zusage entsprechender Reichweite und enthält keinen Kundenwert nach dem betrachteten Horizont. Ein negativer Roh-CAC-Spielraum bedeutet, dass auch kostenlos gewonnene Kunden ihre zugerechneten Kosten nicht decken; ein auf null begrenzter Wert darf das nicht verdecken.', '',
        '### Nachfrage- und Bindungssensitivitäten', '',
        '| Modell | Basis: 24 Monate Ausgaben EUR | Geringe Kosmetiknachfrage EUR | Keine Boosterkäufe EUR | Kopiensatzlücke statt einzigartiger Karten als Nachfrageproxy EUR |',
        '|---|---:|---:|---:|---:|',
    ]
    for mid in config['models']:
        low = revenue['behavior_sensitivities']['low_cosmetic_demand'][mid]['horizons']['24']['gross_spend_ex_vat_eur']
        collapse = revenue['behavior_sensitivities']['pack_demand_collapse'][mid]['horizons']['24']['gross_spend_ex_vat_eur']
        copies = revenue['inventory_demand_sensitivity'][mid]['playset_gap_proxy']['horizons']['24']['gross_spend_ex_vat_eur']
        lines.append(f"| {LABELS[mid]} | {horizon('base',mid)['gross_spend_ex_vat_eur']:.0f} | {low:.0f} | {collapse:.0f} | {copies:.0f} |")
    frustration = revenue['behavior_sensitivities']['scarcity_frustration']['scarcity']['horizons']['24']['gross_spend_ex_vat_eur']
    lines += ['',
        f'Die zusätzlich angenommene Bindungsschwächung im Knappheitsfall ergibt {frustration:.0f} EUR über 24 Monate. Das ist eine Verhaltenshypothese; ein gemessener kausaler Retentionseffekt wird nicht behauptet.', '',
        'Der Haupt-Nachfrageproxy berücksichtigt neue einzigartige Karten und die Ersetzbarkeit durch vorhandene Essenz. Er kann null werden, obwohl spielbare Kopien fehlen. Die Kopiensatz-Sensitivität sowie ein schneller gesättigtes `paid40`-Inventar begrenzen diese Annahme in unterschiedliche Richtungen. Keiner dieser Proxys misst die tatsächliche Kaufbereitschaft.', '',
    ]
    lines += ['',
        ('**Kein Modell trägt mit dieser Einmalkohorte die zugerechneten laufenden Unternehmenskosten.**' if all(horizon(sid,mid)['operating_profit_after_acquisition_eur'] < 0 for sid in config['revenue_scenarios'] for mid in config['models']) else '**Ob die Einmalkohorte ihre zugerechneten Kosten deckt, unterscheidet sich nach Modell und Annahme; maßgeblich sind die ausgewiesenen Ergebnisse.**') + ' Daraus folgt keine allgemeine Prognose für das Unternehmen. Ein nachhaltiges Unternehmen benötigt ausreichende neue oder organische Zugänge, belegte Bindung/Nachfrage und passende Kosten. Der Deckungsbeitrag je Konto vor Fixkosten ist keine frei verfügbare Marketingmarge.', '',
        'Die vollständige Rechnung enthält separat ein stationäres Zufluss-Szenario, erforderliche organische Zugänge sowie Kaufquoten-/Ausgaben-/CAC-Sensitivitäten. Stationäre Schwellen verwenden nur die betrachteten 24 Altersmonate; Erlöse danach werden nicht als ewige Rente angenommen. Individuelle Inaktivität und der Hochbudgetanteil bleiben eigene Modellgrenzen.', '',
        '## Zielkonflikte und Produktentscheidung', '',
        '- **Sammlungsknappheit:** mehr fehlende Karten und längerer Boosterbedarf; gleichzeitig größeres Risiko früher Stärkevorteile durch Käufe. Ein angenommener Umsatzvorteil rechtfertigt keine systematische Wettbewerbssperre.',
        '- **Geschützter Deckpfad:** gezielte kostenlose Ressourcen erhalten den Einstieg, während allgemeine Sammlung und weitere Strategien länger wachsen. Eine einzige geschützte Strategie genügt bei wechselnder Meta nicht; der zweite Zielkorb und Seltenheitsgewichtungen zeigen verbleibenden Prüfbedarf.',
        '- **Kosmetikschwerpunkt:** geringere Abhängigkeit vom Kartenkauf, aber eigene Nachfrage- und Produktionsrisiken. Die Umsatzrechnung setzt den angenommenen Kosmetikkauf nicht mit einem bewiesenen Kaufanreiz gleich.',
        '- **Bindung:** kostenlose klare Ziele, Nachholen und freiwillige kosmetische Ziele sind testbare Produktideen. Ein positiver oder negativer Retentionseffekt ist derzeit unbekannt. Der Fall `scarcity_frustration` ist eine ausdrückliche Verhaltenshypothese.',
        '- **Erweiterungen:** vier hypothetische Ergänzungen um je 110 Karten erhalten Bestände und Pity. Sie verursachen zusätzliche Inhalts-/Balancekosten und beweisen keinen dauerhaften Kaufbedarf. Ein automatischer Reset wertvoller Bestände wird nicht simuliert.', '',
        'Vor Aktivierung sollten echte konkurrenzfähige Decks kostenlos innerhalb eines überschaubaren Aktivitätsbudgets erreichbar sein; weitere Gegenstrategien müssen ohne Zahlung zugänglich bleiben. Danach sind freiwillige Nachfrageexperimente mit transparenten Kosmetikangeboten, einmaligem Einsteigerangebot und nachholbarem Pass zu prüfen. Eine Variante wird nur weiterverfolgt, wenn gemessene Beiträge die Kosten decken und Deck-/Matchuptests den kostenlosen Wettbewerbszugang bestätigen.', '',
        '## Artefakte und Grenzen', '',
        f"[Sammlung und Stichprobe]({link('collection_summary.json')}) · [Sammlungsvergleich]({link('collection_metrics.csv')}) · [Zeit bis Sammlungsziele]({link('collection_thresholds.csv')}) · [Gekaufte Booster und Vorsprung]({link('collection_paid_gaps.csv')}) · [Sensitivitäten]({link('collection_sensitivity.csv')}) · [Umsatzrechnung]({link('revenue_summary.json')})", '',
        'Weitere Produkt- und Annahmendetails: [MONETIZATION-DESIGN.md](MONETIZATION-DESIGN.md) und [MONETIZATION-ASSUMPTIONS.md](MONETIZATION-ASSUMPTIONS.md).', '',
        'Kein tatsächlicher Umsatz, keine empirische Retentions-/Conversion-Schätzung, keine finale Preisliste und keine Gewinnratenbehauptung. Der finale 550-Karten-Katalog, serverautorisierte Eigentumsdaten, Markt, Zahlungsanbieter und Produktfreigaben bleiben außerhalb dieses Pakets.',
    ]
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def run(config_path, output_dir, repetitions=None, report_path=None, reuse_collection=False):
    config = load_config(config_path)
    if repetitions is not None:
        config['repetitions'] = repetitions
    validate_config(config)
    output_dir = Path(output_dir)
    if reuse_collection:
        collection = json.loads((output_dir/'collection_summary.json').read_text())
        expected = {'analysis_config_sha256': hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest(),
                    'economy_config_sha256': hashlib.sha256(json.dumps(load_economy(),sort_keys=True).encode()).hexdigest(),
                    'module_sha256': hashlib.sha256((ROOT/'tools/economy/monetization_collection.py').read_bytes()).hexdigest(),
                    'base_model_sha256': hashlib.sha256((ROOT/'tools/economy/model.py').read_bytes()).hexdigest()}
        if any(collection['metadata'].get(key) != value for key,value in expected.items()):
            raise ValueError('Stale collection evidence: reproduce collection before reuse')
    else:
        collection = run_collection(config, repetitions=config['repetitions'], output_dir=output_dir)
    revenue = run_revenue(config, collection, output_dir, repetitions=config['repetitions'])
    plot_revenue(config, revenue, output_dir)
    report_path = Path(report_path or (ROOT/'docs/economy/MONETIZATION-REPORT.md' if output_dir == DEFAULT_OUT else output_dir/'MONETIZATION-REPORT.md'))
    render_report(config, collection, revenue, report_path, output_dir)
    sources = ['tools/economy/model.py', 'tools/economy/monetization_collection.py',
               'tools/economy/monetization_revenue.py', 'tools/economy/simulate_monetization.py']
    metadata = {'status': 'provisional_analysis_no_purchases_no_business_forecast',
                'seed': config['seed'], 'repetitions': config['repetitions'],
                'source_sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},
                'effective_analysis_config_sha256': hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest(),
                'runtime_modified': False}
    (output_dir/'analysis_metadata.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print(f'Monetization comparison written to {report_path}')
    return collection, revenue


def plot_revenue(config, revenue, output_dir):
    import html
    scenarios = list(config['revenue_scenarios'])
    maximum = max(revenue['results'][sid][mid]['expected']['horizons']['24']['gross_spend_ex_vat_eur'] for sid in scenarios for mid in config['models']) or 1
    colors = ['#ef917a', '#82b5ff', '#76d4b3']
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="470" viewBox="0 0 960 470">',
           '<rect width="960" height="470" fill="#141a28"/><g fill="#edf1f7" font-family="sans-serif">',
           '<text x="25" y="28" font-size="18">Hypothetical 24-month ex-VAT spending, 10,000 acquired accounts</text>',
           '<text x="25" y="50" font-size="12">Scenario assumptions; before refunds, fees and costs; no observed sales</text>']
    for i in range(6):
        y = 370-i*58
        svg.append(f'<path d="M70 {y} H930" stroke="#354052"/><text x="8" y="{y+4}" font-size="12">{maximum*i/5:.0f}</text>')
    for mi,mid in enumerate(config['models']):
        for si,sid in enumerate(scenarios):
            amount = revenue['results'][sid][mid]['expected']['horizons']['24']['gross_spend_ex_vat_eur']
            height = amount/maximum*290
            svg.append(f'<rect x="{100+mi*210+si*42}" y="{370-height:.2f}" width="35" height="{height:.2f}" fill="{colors[si]}"/>')
        svg.append(f'<text x="{95+mi*210}" y="397" font-size="12">{html.escape(mid)}</text>')
    for si,sid in enumerate(scenarios):
        svg.append(f'<text x="{150+si*250}" y="445" fill="{colors[si]}" font-size="14">{html.escape(sid)}</text>')
    svg.append('</g></svg>')
    (output_dir/'revenue_scenarios.svg').write_text('\n'.join(svg)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT/'data/economy/analysis/monetization.json')
    parser.add_argument('--output-dir', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--repetitions', type=int)
    parser.add_argument('--reuse-collection', action='store_true', help='Reuse only hash-verified matching collection evidence')
    args = parser.parse_args()
    run(args.config, args.output_dir, args.repetitions, args.report, args.reuse_collection)
