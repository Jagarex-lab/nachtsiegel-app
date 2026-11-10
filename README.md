# ORAFOLD

Digitales Sammelkartenspiel in Godot 4.6.3: fünf Kampfpfade, lokale KI, 30-Karten-Decks, 30 Helden-Leben und die alternative Siegbedingung Konvergenz. Energie spielt Karten aus; Resonanz bezahlt besondere Eingriffe. Kämpfe sind für Querformat, Sammlung und Deckbuilder für mobile Hochformate ausgelegt.

**Spielen:** https://jagarex-lab.github.io/nachtsiegel-app/

**Tatsächlich veröffentlichter Commit:** [build-info.json](https://jagarex-lab.github.io/nachtsiegel-app/build-info.json). Ein Featurebranch oder grüner PR veröffentlicht nichts automatisch.

## Produktionskandidat

Der neue Kandidat verwendet genau 550 aktive Kartendefinitionen: je 110 für Zwölf Häuser, Stillwacht, Vielgestalt, Neunte Stunde und Neutral. Drei Haupttypen: Wesen, Impuls und Relikt. Die 100 Legacy-Kreaturen und der ursprüngliche 55er-Alpha-Katalog bleiben getrennte historische Regel-/Testprofile und erscheinen nicht zusätzlich in der regulären Sammlung.

**Diese Zahl ist keine Behauptung einer fertigen kommerziellen Version.** Individuelle Illustrationen, die Aussagekraft der Balance und Plattformprüfungen werden getrennt ausgewiesen. Aktuell liegen fünf individuelle Illustrationsentwürfe vor, keine 550 final freigegebenen Bilder. Der [Produktionsaudit](docs/production/AUDIT.md) beschreibt die Ausgangslage; [Umsetzungsplan](docs/production/PLAN.md), [Bereinigungsbericht](docs/production/CLEANUP.md) und die Paketberichte halten den jeweiligen Nachweis fest.

## Spielen und Decks

Im Hauptmenü: Spielen, Deckbuilder, Sammlung, Einstellungen. Vor dem Duell stehen vier sichtbare Starterdecks mit Vorschau bereit. Auf dem tatsächlichen Spielfeld werden Starthandkarten zum Austausch markiert, dann Ursprung und gegebenenfalls Zweite Möglichkeit gewählt. Handkarte antippen und ein gültiges Ziel wählen oder sicher auf einen hervorgehobenen Zielbereich ziehen. Abgebrochene Berührungen spielen keine Karte aus. Ein Wesen trifft bei leerem direkt gegenüberliegendem Feld den gegnerischen Helden; Block und Schild absorbieren nach Kampfregeln.

Sammlung und Deckbuilder bieten Suche, Macht-/Typ-/Arten-/Seltenheits-/Kostenfilter, Sortierung und paginierte Kartenansichten. Genau eine Macht plus neutrale Karten; 30 Karten; maximal drei normale oder eine legendäre Kopie pro ID. Die Strategietestdecks lassen sich als Vorlage laden und ausdrücklich speichern. Fortschritt und Decks liegen lokal; beschädigte oder unbekannte Daten werden aufbewahrt und nicht stillschweigend ersetzt. Es gibt keine Echtgeldkäufe, Serverkonten oder vorgetäuschte Besitzbeschränkungen.

## Entwickeln und prüfen

`project.godot` mit Godot 4.6.3 öffnen, F5 startet die reguläre Anwendung. Node 24 und Python 3 werden für Daten-/Buildprüfungen verwendet. GUI-Prüfungen benötigen ein Display, beispielsweise Xvfb:

```bash
tools/test_legacy.sh
xvfb-run -a tools/test_alpha.sh
xvfb-run -a tools/test_master550.sh
xvfb-run -a tools/test_production.sh
tools/test_production_simulations.sh
python3 -m unittest discover -s tests/release -v
```

`tools/build_alpha.sh` erzeugt einen isolierten Webkandidaten mit dem Quellcommit in `build-info.json`. `tools/package_alpha.py` erstellt ein reproduzierbares ZIP. Per lokalem HTTP nur über `localhost` testen; Smartphones benötigen HTTPS mit einer vom Gerät vertrauten Zertifikatskette. `file://` und unverschlüsseltes LAN-HTTP sind für den Webexport ungeeignet.

Der [manuelle Releaseprozess](docs/release/PAGES_RELEASE_SAFETY.md) veröffentlicht ausschließlich das Artefakt einer vollständig erfolgreichen CI auf dem aktuellen `develop`-Commit. Er umgeht keine GitHub-Schutzregeln. Native Debugexporte existieren für Linux und Android; ein Linux-/Browserlauf ist kein echter Android- oder iPhone-Gerätetest. iOS benötigt zusätzlich Apples Build-/Signierumgebung.

## Lore, Rechte und historische Inhalte

[docs/LORE-BIBLE.md](docs/LORE-BIBLE.md) ist die zentrale Storyreferenz. Bestätigter Kanon, Arbeitsstand, Vorschläge und historische Entwürfe bleiben getrennt. Die alte Arvess-Kampagne ist ein Archivprototyp und keine freigegebene ORAFOLD-Kampagne.

[Asset-Herkunft](assets/ASSET_MANIFEST.md) · [Kartenstil](docs/master550/CARD_STYLE_GUIDE.md) · [Legacy-Migration](docs/migration/LEGACY_PARITY_AUDIT.md)

Godot: MIT. Projektcode/-inhalte: bestehender Rechtevorbehalt laut `LICENSE-NOTICE.md`; Schriftlizenzen liegen bei. Generierte Einzelbilder sind Illustrationsentwürfe mit dokumentierter Herkunft und ausstehender Produktions-/Rechteprüfung. Eine spätere kommerzielle Freigabe wird nicht durch eine technische Datenprüfung ersetzt.
