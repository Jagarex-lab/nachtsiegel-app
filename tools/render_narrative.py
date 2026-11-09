#!/usr/bin/env python3
"""Render the bilingual creative bible from the canonical localization catalogs."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LABELS={'name':'Name','premise':'Prämisse','origin':'Ursprung','key_event':'Schlüsselereignis','conflict':'Zentraler Konflikt','magic':'Magiesystem','limits':'Grenzen und Kosten','paths':'Bedeutung der fünf Pfade','religion':'Religion','politics':'Politik','everyday':'Alltag','player':'Spielerperspektive','boundaries':'Grenze zwischen Welt und Regeln','event':'Ereignis','purpose':'Bedeutung','symbol':'Zeichen','description':'Beschreibung','philosophy':'Philosophie','goal':'Ziel','culture':'Kultur','inner_conflict':'Innerer Konflikt','creatures':'Kreaturen','architecture':'Architektur','visual':'Visuelle Identität','role':'Rolle','introduction':'Fraktionsvorstellung','biography':'Biografie','flaw':'Innerer Widerspruch','quote':'Stimme','hook':'Ausgangslage','events':'Verlauf','climax':'Konfrontation','outcome':'Folge','dilemma':'Dilemma','line':'Dialog','logline':'Kurzfassung','motive':'Motiv','staging':'Inszenierung','rules':'Regelbindung','first_summon':'Erste Beschwörung','first_hit':'Erster Treffer','victory':'Sieg','defeat':'Niederlage','learning':'Lernziel','truth':'Autorenwissen','question':'Leitfrage','visual':'Bild / Material','voice':'Sprechertext','audio':'Ton'}
def generate():
    manifest=json.loads((ROOT/'data/narrative/content.json').read_text());cols=manifest['collections']
    de=json.loads((ROOT/'data/narrative/locales/de.json').read_text());en=json.loads((ROOT/'data/narrative/locales/en.json').read_text())
    def header(title):return '# '+title+'\n\n**KREATIVENTWURF – GEGENMASS / COUNTERMEASURE (ARBEITSTITEL).** Keine Freigabe eines Produktnamens oder Änderung der veröffentlichten Welt. Quelle: `data/narrative/`; diese Datei wird mit `python3 tools/render_narrative.py` erzeugt.\n\n'
    def entity(item,fields=None):
        name=item['texts'].get('name');s='## '+(de[name] if name else item['id'])+'\n\n'
        s+='Stabile ID: `'+item['id']+'`. '
        if 'status' in item:s+='Status: `'+item['status']+'`. '
        if 'lane_index' in item:s+='Bestehender Pfad '+str(item['lane_index']+1)+'. '
        if 'year' in item:s+='Jahr '+str(item['year'])+' nach Nullwinter. '
        if 'start_seconds' in item:s+=str(item['start_seconds'])+'–'+str(item['end_seconds'])+' Sekunden. '
        if 'legacy_name' in item:s+='Bestandsbezug: '+item['legacy_name']+'. '
        if 'legacy_portrait_proposal' in item and item['legacy_portrait_proposal']:s+='Vorgeschlagener Porträtbezug: '+item['legacy_portrait_proposal']+' (nicht aktiviert). '
        s+='\n\n'
        for field,key in item['texts'].items():
            if field=='name' or (fields is not None and field not in fields):continue
            s+='### '+LABELS.get(field,field)+'\n\n'+de[key]+'\n\n**EN:** '+en[key]+'\n\n'
        return s
    world=header('Worldbuilding-Bibel')
    for group in ['world','timeline','paths','locations']:
        world+='---\n\n'
        for item in cols[group]:world+=entity(item)
    world+='## Zehn zentrale Figuren\n\nVollständige Biografien und Stimmen: [Erzählerische Inhalte](05-narrative.md). Alle Figuren sind neu vorgeschlagen; die beiden bestehenden Porträtnamen begründen keine bereits vorhandenen Biografien.\n\n'
    for item in cols['characters']:world+=entity(item,['role','goal','flaw'])
    world+='## Autorenwissen und langfristige Handlungsstränge\n\nDie folgenden Wahrheiten sind Spoiler, keine Behauptungen über den bisherigen Prototyp.\n\n'
    for group in ['secrets','arcs']:
        for item in cols[group]:world+=entity(item)
    factions=header('Vier Fraktionen')+'Die mechanischen Rollen sind vorsichtige Interpretationen des Bestands. Es werden keine passiven Fraktionsfähigkeiten eingeführt. Die Farbangaben sind Materialentwürfe; bestehende semantische UX-Farben aus `ui_tokens.gd` haben Vorrang.\n\n'
    for item in cols['factions']:
        factions+=entity(item)+'Materialpalette: '+', '.join('`'+c+'`'for c in item['concept_palette'])+'.\n\n'
    story=header('Erzählerische Inhalte – Deutsch / English')+'## Eröffnungsmonolog\n\nEigenständiger Langtext, ungefähr 150 Wörter pro Sprache; nicht der Sprechertext der 40-Sekunden-Sequenz.\n\n'+de[manifest['opening_key']]+'\n\n**EN:**\n\n'+en[manifest['opening_key']]+'\n\n## Intro-Skript – 40 Sekunden\n\nDie fünf Einstellungen dauern zusammen 40 Sekunden. Separate kurze Sprechertexte lassen Raum für Geräusche und Pausen. Film, Vertonung und Kampagnenmenü werden in diesem Task nicht implementiert. Timing ist ein Animatic-Plan; ein eingesprochenes Timing steht aus.\n\n'
    for group in ['intro','campaign','chapters']:
        for item in cols[group]:story+=entity(item)
    story+='## Zwanzig kurze Kartentexte\n\nDie ersten sieben beziehen sich auf vorhandene Karten. Weitere 13 sind ausdrücklich Konzepttexte und erweitern weder Kartenpool noch Deck. Alle Zeilen sind Flavor, keine Fähigkeitstexte.\n\n| ID / Status | Name DE / EN | Flavor DE | Flavor EN |\n|---|---|---|---|\n'
    for item in cols['cards']:
        t=item['texts'];story+='| `'+item['id']+'` / '+item['status']+' | '+de[t['name']]+' / '+en[t['name']]+' | '+de[t['flavor']]+' | '+en[t['flavor']]+' |\n'
    story+='\n## Sechs Heldenbiografien und vier weitere Figuren\n\nDie ersten sechs Einträge sind Heldenkonzepte. Sie verleihen keine neuen Heldenfähigkeiten.\n\n'
    for item in cols['characters']:story+=entity(item)
    story+='## Erster Bosskampf\n\nEin vollständiger Encounter-Entwurf, noch keine implementierte Kampagne oder garantierte Zugfolge. Die kanonische Datendatei bindet den Entwurf ausdrücklich nicht an den laufenden Duel-Controller.\n\n'
    for item in cols['boss']:story+=entity(item)
    return {'03-world-bible.md':world,'04-factions.md':factions,'05-narrative.md':story}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args();changed=[]
    for name,content in generate().items():
        path=ROOT/'docs/creative'/name
        if not path.exists() or path.read_text()!=content:
            changed.append(name)
            if not args.check:path.write_text(content)
    if args.check and changed:raise SystemExit('Creative views out of date: '+', '.join(changed))
    print('CREATIVE VIEWS: 3 bilingual documents synchronized')
if __name__=='__main__':main()
