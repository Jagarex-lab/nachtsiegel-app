# ORAFOLD – reproduzierbare Konzeptprüfung

Statische Bestandsprüfung; keine Spielbarkeits-, Bild-, Kanon- oder Balanceabnahme.

Erfasst: **550 Konzepte**, **55 aktive Alpha-Karten**, **0 gemeinsame IDs**.

| Zugehörigkeit | Konzepte |
|---|---:|
| Zwölf Häuser | 110 |
| Stillwacht | 110 |
| Vielgestalt | 110 |
| Neunte Stunde | 110 |
| Neutral | 110 |

| Kartentyp | Konzepte |
|---|---:|
| Wesen | 350 |
| Impuls | 125 |
| Relikt | 75 |

| Seltenheit | Konzepte |
|---|---:|
| Gewöhnlich | 250 |
| Selten | 160 |
| Episch | 100 |
| Legendär | 40 |

Strukturprüfung: bestanden (0 Fehler).
Vorschläge: 550; prototype_only: 550; Referenzmarkierung: 50.

| Wesensart | Wesen |
|---|---:|
| Menschen | 58 |
| Bestien | 48 |
| Geister | 23 |
| Konstrukte | 38 |
| Pflanzen | 25 |
| Amalgame | 23 |
| Morphiden | 12 |
| Paradoxe | 22 |
| Wiedergänger | 22 |
| Elementare | 33 |
| Zehrer | 20 |
| Mechanoide | 26 |

Artenzahl je Wesen: 350 mit 1. Beide Arten bleiben bei einer späteren Doppelklassifikation gleichwertig.
Referenzbestand: 80 Figuren, 20 Orte, 10 Organisationen und 140 Familien. Nicht kanonisierte Referenzkanten: 2200.

| Wiederverwendetes Feld | Unterschiedliche Werte | Zeilen in Mehrfachgruppen | Größte Gruppe |
|---|---:|---:|---:|
| name | 550 | 0 | 0 |
| visual_brief | 317 | 362 | 5 |
| art_direction | 109 | 538 | 14 |
| lore | 384 | 208 | 20 |
| flavor | 15 | 550 | 100 |
| story_hook | 10 | 550 | 55 |
| mechanical_intent | 5 | 550 | 110 |
| lore_without_card_name | 133 | 488 | 20 |

Namen mit technischem ID-Anhang: 20.
Figurenverweise mit anderer Zugehörigkeit: 394; mit anderer Region: 438. Diese Befunde verlangen redaktionelle Prüfung; wechselnde Zugehörigkeit oder Reisen sind möglich.

| Fehlendes Gameplayfeld | Betroffene Konzepte |
|---|---:|
| energy_cost | 550 |
| abilities | 550 |
| text_de | 550 |
| art | 550 |
| attack | 350 |
| health | 350 |

Konzepte mit sämtlichen geprüften Gameplayfeldern vorhanden: 0; keine Ausführbarkeit daraus abgeleitet.
Vollständige Partien in diesem Werkzeug: 0. Releasefreigabe: **nein**.

## Folgerungen für die nächste Autorencharge

Die bestehende Lore-Bibel bleibt die Kanonreferenz. Die Konzeptnamen, Orte, Figurenbeziehungen und Schauplätze bleiben Vorschläge. Ein formal existierender Verweis bestätigt weder eine Biografie noch die behauptete Beziehung der Karte zur Figur.

Wiederverwendete Konflikte können Kartenfamilien verbinden; jede Karte braucht dennoch eine konkrete eigene Szene, einen lesbaren individuellen Namen und eine eigene Funktion. Technische ID-Anhänge ersetzen keine eigenständigen Namen. Identische Texte sind hier exakt gemessen; ähnliche Texte können zusätzlich vorhanden sein.

Zuerst kleine kuratierte Chargen mit Gegenstrategien, Energie-/Resonanzkosten und tatsächlich unterstützten Effektprogrammen erstellen. Eine Feldanwesenheitsprüfung ersetzt keine Vertrags- und Ausführungstests. Ohne Zahlen und Effekte ist das Wertebudget nicht berechenbar; das Werkzeug erzeugt daher keine Scheinsimulation oder Siegraten.

Keine Alpha- oder Legacy-Karte wird durch diese Prüfung ersetzt oder gelöscht. Die Konzept-IDs sind ein getrennter Namensraum. Aktive Migration, Umleitung, Trigger-, Session- und Replayintegration bleiben von der zusammengeführten Enginearbeit und einer anschließenden Gesamtprüfung abhängig.

## Reproduktion

```sh
node tools/production/catalog_review.cjs --check
node tools/production/catalog_review.cjs --format markdown
node tools/production/catalog_review.cjs --require-release
```

`--check` prüft die Struktur der Vorschläge. `--require-release` schlägt bewusst fehl, solange Laufzeit-, Einzelbild- und Partiennachweise fehlen. Die Ausgabe erfolgt nur auf stdout; keine Quelldatei wird verändert.

## Quellenfingerabdrücke

```json
{
  "data/lore/card-concepts.json": "b7e6bfd396bf899df8ca00d46c138fefd18f23923313c68e86ff8caf9dc5668b",
  "data/lore/characters.json": "dea78b43dfdf3ba8608b1075ecbd6944cd3b378b7d98217d5d9fd0975c16010f",
  "data/lore/locations.json": "d984a1cb07cc5476fe2e92d6ebcd7a19c73fa2448fbcb1a31f5970fe20863ce4",
  "data/lore/organizations.json": "07f13dd406c859c903d598696775e2a44385a8ba9e455ddd1bc75cbaf6da71e8",
  "data/lore/card-families.json": "abf9d466a28b84503d64eeae5760dbc629b78212518a80a17bce21f4ea368bf2",
  "data/alpha/cards.json": "0e5fcc20589961c5bdca662642870bc9abfc483b0ef2aebfbbf88be2876355ef"
}
```
