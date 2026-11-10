#!/usr/bin/env python3
"""Reproducible public inventory and migration notes from actual card records."""
from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path

from build_catalog import ROOT, POWER_NAMES, SPECIES
from validate_catalog import validate

TYPE = {"creature": "Wesen", "event": "Impuls", "relic": "Relikt"}
RARITY = {"common": "Gewöhnlich", "rare": "Selten", "epic": "Episch", "legendary": "Legendär"}


def escape(value):
    return str(value).replace("|", "\\|").replace("\n", "<br>")


def build_docs():
    data = json.loads((ROOT / "data/production/cards.json").read_text())
    audit = validate(data)
    assert audit["ok"], audit["errors"]
    cards = data["cards"]
    by_id = {card["id"]: card for card in cards}
    migration = json.loads((ROOT / "data/production/migration.json").read_text())
    output = ROOT / "docs/production"
    catalogue = [
        "# ORAFOLD – Produktionskatalog mit 550 Karten", "",
        "Dieser Katalog wird aus `data/production/cards.json` erzeugt. Er dokumentiert die tatsächlich vorhandenen Daten; er ersetzt keine Ausführungstests und behauptet weder vollständige Balance noch 550 fertige Illustrationen.", "",
        "**Datenbestand:** 550 Karten, je 110 für Zwölf Häuser, Stillwacht, Vielgestalt, Neunte Stunde und Neutral. 357 Wesen, 133 Impulse und 60 Relikte. 243 gewöhnliche, 172 seltene, 96 epische und 39 legendäre Karten. 500 Karten verwenden die generische Effektdefinition; 50 verwenden ausdrücklich weiter den vorhandenen nativen Handler.", "",
        "Alle 550 Einträge unterscheiden sich auch mechanisch, wenn Name, ID, Illustration und Machtzugehörigkeit aus dem Vergleich entfernt werden. Verglichen werden Kosten, Werte, gültige Wesensarten, Effekte, Auslöser, Zielregeln und das Kopienlimit. Dies bedeutet **nicht**, dass 550 völlig verschiedene Einzeloperationen existieren: Karten kombinieren ein gemeinsames, parametrisierbares Vokabular.", "",
        "**Lorestatus:** Die 495 neu verfassten Motive sind Vorschläge. Die 55 übernommenen Kartenidentitäten bleiben Arbeitsstand. Kartennamen begründen keine neuen kanonischen Weltereignisse, Herrscher oder Enthüllungen über Eira. Maßgeblich bleibt [die Lore-Bibel](../LORE-BIBLE.md).", "",
        "**Illustrationen:** Der [Asset-Manifest](../../data/production/art_manifest.json) trennt fehlende Bilder, individuell erzeugte Konzepte und freigegebene Endillustrationen. Ein Art-Brief oder ein geteiltes Konzeptbild zählt nicht als fertige Einzelillustration.", "",
        "## Leseschlüssel", "",
        "E = Energiekosten, ANG/LP = Ausgangswerte. Bei Impulsen und Relikten sind ANG/LP und Wesensarten nicht vorhanden. Beide Arten eines Wesens sind gleichwertig. Die vollständigen Auswahl- und Zeitregeln stehen im [Glossar](GLOSSARY.md).", "",
    ]
    for power in POWER_NAMES:
        catalogue += [f"## {POWER_NAMES[power]}", "", "| ID | Name | Typ | E | ANG/LP | Seltenheit | Wesensarten | Vollständiger Kartentext |", "|---|---|---|---:|---|---|---|---|"]
        for card in cards:
            if card["faction"] != power:
                continue
            stats = f"{card['atk']}/{card['hp']}" if card["kind"] == "creature" else "—"
            species = ", ".join(SPECIES[species] for species in card.get("species", [])) or "—"
            catalogue.append("| " + " | ".join(escape(value) for value in [card["id"], card["name"], TYPE[card["kind"]], card["cost"], stats, RARITY[card["rarity"]], species, card["description"]]) + " |")
        catalogue.append("")
    migration_lines = [
        "# ORAFOLD – Kartenbereinigung und Migration", "",
        "## Aktiver und historischer Bestand", "",
        "Der Produktionskatalog ist `data/production/cards.json` und wird ausschließlich über `scripts/production/catalog.gd` gewählt. Er enthält exakt 550 Karten. Historische Pools werden nicht automatisch beigemischt.", "",
        "| Bestand | Behandlung | Grund |", "|---|---|---|",
        "| 55 Alpha-Identitäten | Alle IDs und Namen bleiben im Produktionspool gültig; elf werden ausdrücklich überarbeitet | Bestehende gespeicherte Decks behalten ihre Referenzen |",
        "| `data/alpha/cards.json` mit 55 alten Definitionen | Unverändert als historisches Regelprofil erhalten | Alpha-Regressionen und alte Replays bleiben nachvollziehbar |",
        "| `data/legacy/cards.json` mit 100 Karten | Außerhalb des aktiven Produktionskatalogs erhalten | Fixierte JavaScript-Parität und Legacy-Tests |",
        "| `data/card_definitions.gd` mit sieben frühen Prototypkarten | Nicht Bestandteil der Produktionssammlung | Historische Arena-Regressionen |",
        "| `data/lore/card-concepts.json` mit 550 Konzepten | Historische Vorschläge, nicht automatisch ausführbare oder kanonische Karten | Herkunft und verworfene Entwurfsentscheidungen bleiben sichtbar |",
        "| 495 neue Produktionskarten | Neue stabile `of-…`-IDs, Namen, Werte, Arten und kombinierte Regeln | Keine Wortpermutation der alten Vorlagen, kein automatischer Import von Lorebehauptungen |", "",
        "**Physisch gelöschte Referenzdaten: keine. Entfernte aktive Alpha-IDs: keine.** Der Sicherheitsgewinn entsteht durch explizite Katalogauswahl statt unkontrolliertem Löschen. Alle 55 alten IDs werden in `data/production/migration.json` einzeln aufgeführt.", "",
        "## Elf ausdrücklich überarbeitete Alpha-Identitäten", "",
        "Die Originaldefinitionen verbleiben im Alpha-Archiv. Folgende Änderungen gelten ausschließlich für das Produktionsprofil. Die Zahlen sind erste Balancing-Entwürfe und keine aus großen Stichproben abgeleitete Endbalance.", "",
        "| ID | Name | Änderungen |", "|---|---|---|",
    ]
    for entry in migration["retained"]:
        if not entry["changes"]:
            continue
        delta = []
        for field, value in entry["changes"].items():
            if field in ["description", "abilities"]:
                continue
            delta.append(f"{field}: `{value['old']}` → `{value['new']}`")
        if "abilities" in entry["changes"]:
            delta.append("neue generische Fähigkeiten: " + by_id[entry["new_id"]]["description"])
        migration_lines.append("| " + " | ".join(escape(value) for value in [entry["old_id"], by_id[entry["new_id"]]["name"], "; ".join(delta)]) + " |")
    migration_lines += [
        "", "Die drei früher gleichen Puls-Legenden erfüllen nun verschiedene Rollen: Die letzte Erbin arbeitet mit Wiederkehr und Nachlass, die unbewegte Königin mit Schild und Kontrolle, die Vielstimmige mit Bewegung und Pflanzen. Der neunte Zeuge behält als einzige dieser vier Karten den nativen Puls. Die Titel begründen weiterhin keine bestätigte Führungsrolle in der Welt.", "",
        "## Decks und Spielstände", "",
        "Die vier neuen Starter stammen aus `data/production/starters.json`. Sie ersetzen die Vorlagen, nicht automatisch bereits gespeicherte individuelle Decks. Alte 30-Karten-Decks mit den 55 erhaltenen IDs bleiben nach der ursprünglichen Macht- und Kopienregel gültig. Laufende Partien und Replays benötigen zusätzlich das passende mechanische Regelprofil; eine Karten-ID allein beweist keine replayfähige Gleichheit.", "",
        "Die neue Neunte-Stunde-Vorlage enthält tatsächliche Erzeuger verzögerter Ereignisse und Umleitung. Der Datencheck beweist diese Voraussetzung im Deck; erst der zugehörige Engine-Test beweist, dass Vorbereitung, Umleitung und spätere Auflösung in richtiger Reihenfolge funktionieren. Ein altes individuelles Deck ohne Erzeuger wird nicht ungefragt umgebaut.", "",
        "## Herkunft und Grenzen", "",
        "`data/production/authoring.json` ordnet die 495 neuen Karten den bisherigen Konzeptvorschlägen zu, soweit Typ und Macht passen. Eine fehlende Zuordnung ist eine neue Redaktion, keine behauptete historische Karte. Andere Typverteilungen wurden bewusst gewählt: Vielgestalt enthält mehr Wesen, Neunte Stunde mehr Impulse; Relikte sind wegen des einzelnen aktiven Reliktplatzes begrenzt.", "",
        "Die Bereinigung entfernt keine für Tests, Archivkampagne oder Migration benötigten Referenzen. Die alte Arvess-Kampagne bleibt ein historischer Prototyp und wird nicht durch Kartendaten nachträglich zu ORAFOLD-Kanon. Verwaiste Illustrationen werden erst nach vollständiger Herkunfts- und Referenzprüfung gelöscht; dieser Schritt behauptet keine bislang ungeprüfte Löschung.", "",
        "## Reproduzierbare Datenprüfungen", "", "```sh", "python3 tools/production/build_catalog.py --check", "python3 tools/production/build_starters.py --check", "python3 tools/production/build_test_decks.py --check", "python3 tools/production/validate_catalog.py", "python3 tools/production/test_catalog.py", "python3 tools/production/build_docs.py --check", "```", "",
        "Der Python-Katalogtest umfasst 31 Testgruppen einschließlich negativer Datendefinitionen, Ziel- und Parameterfehlern, unerreichbarer Bedingungen, Textbeispielen, alten Deckreferenzen und Reproduzierbarkeit. Er zählt keine unsupported Runtime-Szenarien als bestanden.", "",
    ]
    return {output / "CARD_CATALOG.md": "\n".join(catalogue), output / "MIGRATION.md": "\n".join(migration_lines)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    differences = []
    for path, content in build_docs().items():
        if args.check:
            if not path.exists() or path.read_text() != content:
                differences.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    if differences:
        raise SystemExit("Outdated production docs: " + ", ".join(differences))
    print("Production catalogue and migration documentation reproducible" if args.check else "Production catalogue and migration documentation generated")


if __name__ == "__main__":
    main()
