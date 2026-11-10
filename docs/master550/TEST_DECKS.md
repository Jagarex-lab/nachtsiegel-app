# M7b – Zehn kuratierte Standard-Testdecks

Stand: 10.11.2026. [test_decks.json](../../data/card_system/test_decks.json) enthält zehn unterschiedliche Deckvorlagen ausschließlich aus den **55 vorhandenen Alpha-Karten**. Es werden keine Karten, Regeln, Fähigkeiten, Artenboni, Starterdefinitionen oder KI-Bewertungen ergänzt. Die Vorlagen sind keine neuen Starter und keine Behauptung eines ausgeglichenen Metagames.

## Datenvertrag und Auswahl

Die Datei trägt `format: ORAFOLD-TEST-DECKS`, `schema_version: 1` und die vorhandene `ruleset_id`. Jede Vorlage besitzt eine stabile ID, deutschen Namen, Strategie, Macht, Beschreibung, ausdrücklich benannte Grenzen, Schlüssel-Karten, tatsächlich enthaltene Effekt-IDs, optionalen Artenfokus und `cards` mit genau 30 expandierten Original-IDs. Werte, Namen, Fähigkeitstexte und Illustrationen werden weiterhin aus dem einzigen Alpha-Katalog bezogen. Es gibt keine Kopie der Kartendefinitionen.

Alle Vorlagen enthalten genau eine der vier Mächte plus neutrale Karten. Normale IDs erscheinen höchstens dreimal, legendäre höchstens einmal. Jede Vorlage unterscheidet sich von jeder anderen um mindestens **neun auszutauschende Kartenkopien** und ist mit keinem der vier vorhandenen Starter identisch. Ein anderer Name allein würde diese Unterscheidung nicht erfüllen.

| ID / Vorlage | Macht | Wesen / Impulse / Relikte | Tatsächlich vorhandener Schwerpunkt |
|---|---|---:|---|
| `test-aggro` – Offene Schneisen | Vielgestalt | 20 / 7 / 3 | Eile, Nachbarverstärkung, zusätzlicher Angriff, freie Gegenpfade |
| `test-control` – Die gehaltene Gegenwart | Stillwacht | 19 / 9 / 2 | Stasis, verzögerter Pfadschaden, Schwächung |
| `test-resonance` – Gespeicherte Möglichkeiten | Neunte Stunde | 22 / 5 / 3 | Resonanz durch Wesen und Wanderkompass; vorhandene Entfesselung |
| `test-shield` – Schichten aus Glas | Stillwacht | 22 / 4 / 4 | Heldenschild, zeitweiliger Block und Heilung getrennt |
| `test-recurrence` – Das zweite Gedächtnis | Zwölf Häuser | 23 / 5 / 2 | Letztes abgelegtes Wesen zurückbeschwören, Beschwörungseffekte erneut nutzen |
| `test-movement` – Wege im Wandel | Vielgestalt | 22 / 7 / 1 | Eigene optionale Verschiebung, gegnerische Nachbarverschiebung |
| `test-impulse-combo` – Zehn kleine Brüche | Neunte Stunde | 15 / 12 / 3 | Einzelne Impulse kombinieren, zehn geordnete Echosalven-Treffer |
| `test-relic` – Eine einzige Verankerung | Zwölf Häuser | 21 / 3 / 6 | Zwischen Heil-, Resonanz- und Schildrelikt wählen; nur ein aktiver Slot |
| `test-convergence` – Drei gehaltene Pfade | Stillwacht | 22 / 6 / 2 | Drei konkrete kampfbereite Instanzen gegen Gegenmaßnahmen halten |
| `test-species` – Die menschliche Überlieferung | Zwölf Häuser | 28 / 2 / 0 | Menschen über den Artenfilter zusammenstellen; Doppelarten gleichwertig |

Die Bezeichnungen beschreiben vorhandene Möglichkeiten, keine neue automatische Strategiemechanik. Insbesondere gibt es keinen automatischen Bonus für eine Folge von Impulsen oder eine bestimmte Wesenart. Die Artenvorlage erklärt ausdrücklich: **„Artenfilter und Deckzusammensetzung, keine implementierten automatischen Artenboni.“** Alle 28 Wesen darin besitzen nach den vorhandenen redaktionellen Metadaten `human`; der Prismaträger gehört gleichwertig auch `construct` an.

„Umleitung“ (`oa-ninth-e01`) ist in keiner Vorlage enthalten. Ihr erforderlicher eigener verzögerter Treffer kann im gegenwärtigen legalen Neunte-Stunde-Pool nicht hergestellt werden; die vorhandene Delay-Karte gehört Stillwacht. Diese bekannte Lücke wird weder durch eine unerlaubte Quermachtkarte noch einen erfundenen Effekt verdeckt. Der bestehende unveränderte Neunte-Stunde-Starter enthält sie weiterhin; eine solche bestehende Gegnerliste darf deshalb nicht mit den neuen bereinigten Vorlagen verwechselt werden.

## Einbindung in die Deckwerkstatt

Die Deckwerkstatt erhält den Einstieg **Testdecks**. Das scrollbare Vorlagenfenster zeigt alle zehn Beschreibungen einschließlich ihrer Einschränkungen. **Als Vorlage laden** setzt Macht und bearbeitbare Deckliste auf die ausgewählte Zusammensetzung. Es speichert das Deck nicht automatisch; bestehende gespeicherte Decklisten bleiben erhalten. Erst **Speichern** übernimmt eine Vorlage in den gewählten lokalen Macht-Slot. Die normale Startauswahl und die vier ursprünglichen Starter bleiben bestehen.

Diese Einbindung ist ein lokaler Deckentwurf, kein Account, Besitzsystem, Shop und keine zusätzliche Hauptnavigation. Der Machtwechsel darf die bestehende Macht-Einstellung aktualisieren; er darf gespeicherte Kartenlisten nicht still überschreiben.

## Prüfungen und tatsächlicher Nachweisstand

**Bereits ausgeführt:** Eine strukturierte Datenprüfung liest alle vorhandenen Kartendefinitionen und Artenmetadaten. Sie bestätigt je Vorlage 30 Karten, gültige Original-IDs, korrekte Macht, Kopiengrenzen, enthaltene Schlüssel-Karten/Effekte, Ausschluss von Umleitung, die 28 Menschen sowie den Mindestabstand von neun Kopien. Diese Datenprüfung ist kein Godot-Kampfnachweis.

[master550_test_decks.gd](../../tests/master550_test_decks.gd) führt folgende weitergehende Prüfungen aus:

1. Jede Liste wird direkt durch den tatsächlichen `AlphaCatalog.validate` geprüft; die deklarierte Macht muss dem Ergebnis entsprechen. Anzeigenamen, IDs, Strategien und die angegebenen Schwerpunkte werden geprüft.
2. Zwei vollständige deterministische KI-Partien je Vorlage, insgesamt 20. Pro Vorlage werden die kleinsten passenden Seeds für beide tatsächlichen Startspieler nach dem vorhandenen Mulligan gewählt, ohne die Münze zu überschreiben. Die Gegner rotieren durch die vier unveränderten Starter. Verwendet werden ausschließlich `AlphaModel` und seine geerbte Kampfengine/KI, keine zweite Engine.
3. Die Partien nutzen die tatsächliche Ursprungsauswahl und gegebenenfalls Zweite Möglichkeit. Nach jedem Hero-KI-Aufruf wird Kartenmengenerhaltung von 30 pro Seite geprüft. Ein Enginefehler, eine nicht beendete Partie nach 400 Aufrufen oder ein unbekanntes Ergebnis zählt als Fehler. Gewinnen zu müssen ist kein Akzeptanzkriterium eines Smoketests.
4. Die tatsächliche Shell wird bei **390×844** und **844×390** aufgebaut und geometrisch vermessen. Der Vorlageneinstieg und Schließen müssen sichtbar und mindestens 44×44 groß sein. Alle zehn Vorlagenaktionen müssen vorhanden und aktiv sein. Jede wird in den sichtbaren Scrollbereich gebracht und über ihr tatsächliches `pressed`-Signal geladen. Erwartet werden exakte Karten-IDs, richtige Macht, gültiges `deck_check`, bearbeitbare Decklistenansicht und unveränderte zuvor gespeicherte Decks.
5. Die Shell-Fixture legt gültige gespeicherte Starter als Kontrollbestand an, prüft dessen Erhaltung bei jedem Ladevorgang und stellt den vorherigen lokalen Testprofilinhalt anschließend wieder her. Die Produktions-Kartendatei muss unverändert bleiben.

**Tatsächlich ausgeführt:** Godot 4.6.3-stable (official), nativer **Headless**-Lauf mit Dummy-Audio; Exitcode 0. **1.887 Assertions bestanden, null Fehler; 20 vollständige Partien**, jede Vorlage einmal als tatsächlicher erster und einmal als zweiter Spieler. Keine Enginefehler oder zensierten Partien. Der Lauf bestätigt die Control-/Scrollgeometrie beider Shellgrößen und die exakten Ladeaktionen; er liefert keine Pixel-Screenshots und keinen Fingernachweis.

| Vorlage | Seed / Start Hero | Seed / Start Enemy | Beide Partien beendet |
|---|---|---|---|
| Aggro | 0 / Sieg, Halbzug 21 | 2 / Sieg, Halbzug 26 | ja |
| Kontrolle | 0 / Sieg, Halbzug 27 | 2 / Sieg, Halbzug 28 | ja |
| Resonanz | 0 / Sieg, Halbzug 15 | 1 / Niederlage, Halbzug 21 | ja |
| Schild | 0 / Niederlage, Halbzug 24 | 1 / Niederlage, Halbzug 23 | ja |
| Wiederkehr | 0 / Sieg, Halbzug 83 | 1 / Sieg, Halbzug 40 | ja |
| Positionswechsel | 0 / Sieg, Halbzug 23 | 1 / Sieg, Halbzug 40 | ja |
| Impulskombinationen | 0 / Sieg, Halbzug 11 | 1 / Niederlage, Halbzug 19 | ja |
| Relikt | 0 / Niederlage, Halbzug 22 | 1 / Niederlage, Halbzug 29 | ja |
| Konvergenz | 0 / Sieg, Halbzug 51 | 2 / Sieg, Halbzug 26 | ja |
| Wesensarten | 0 / Sieg, Halbzug 27 | 1 / Sieg, Halbzug 42 | ja |

Sieben Partien endeten durch Konvergenz. Die längste beobachtete Effektqueue hatte zehn Einträge; Halbzugzahlen lagen zwischen 11 und 83. Diese Stichprobe ist eine Funktionsprüfung mit rotierenden Gegnern und vorhandener KI, keine vergleichbare Turnierwertung der zehn Strategien. Insbesondere sind weder die beiden Niederlagen der Schild-/Reliktvorlage noch die Erfolge anderer Listen allein eine Begründung für Regel- oder Werteänderungen.

Nachweise: `work/master550/test-decks-first.log` und `work/master550/test_decks.json` (rund 8 KB). Geprüfter Vorlagen-SHA-256: `1faad02d6edf46b4ed34ab8f593cfbd6cf477a74b487a59cb11fa17639fb48aa`. Das lokale Testprofil wurde wiederhergestellt. Weitere Bildrender-, Browser- und Touchprüfungen gehören zur gesonderten Gesamt-QA und werden hier nicht als durchgeführt ausgegeben.

Der vorbereitete UI-Test verwendet Signalaktivierung und echte Control-/Scrollgeometrie. Er ist kein echter Finger-/iPhone-Test und kein Ersatz für die gesonderten Browser-/Touch-Regressionsprüfungen. Die vorhandene Hero-KI nutzt optionale eigene Verschiebungen nur begrenzt; zwanzig beendete Partien würden weder optimale Strategieausführung noch die Balance der Vorlagen beweisen. Die bestehende Dominanz der Neunten Stunde ist im [Ressourcenbericht](RESOURCE_EXPERIMENTS.md) dokumentiert und bleibt eine separate Inhalts-/Balancingaufgabe.

## Reproduzierbarer nativer Lauf

```bash
LP_NUM_THREADS=2 \
XDG_DATA_HOME="$PWD/work/xdg/data" \
XDG_CONFIG_HOME="$PWD/work/xdg/config" \
XDG_CACHE_HOME="$PWD/work/xdg/cache" \
godot --headless --path . --audio-driver Dummy --script tests/master550_test_decks.gd
```

Der dokumentierte Lauf benötigt kein Display. Für einen zusätzlichen Bildrenderlauf kann `--headless` an einer vorhandenen Anzeige entfallen; der Test selbst erzeugt keine Screenshots. Kein zusätzliches Paket wird benötigt. Das Ergebnisartefakt wird unter `work/master550/test_decks.json` geschrieben: Quellhash, Godot-Version, Assertionzahlen sowie pro Partie Vorlage, Gegner, Seed, tatsächlicher Startspieler, Sieger, Halbzugzahl, Kettenmaximum und Ereignis-/Endzustandshashes. Das ignorierte `work/`-Artefakt ersetzt nicht den abschließenden Prüfbericht. Dieser Test löst keinen Merge oder Release aus.

Zusätzliche Kleinstgrößenprüfung nach dem ersten Lauf: Der vollständige Test wurde um **320×568 und 756×320** erweitert und erneut headless ausgeführt. Ergebnis: **2.031 Assertions, null Fehler, 20 vollständige Partien**. Alle Vorlagen blieben über die echte Scrollgeometrie erreichbar; die zusätzliche Abdeckung ist weiterhin kein Pixel- oder echter Gerätetest.
