# Mobile Kampfarena und Handkarten – Korrektur

Status: Native Godot-Prüfungen auf Präsentationsstand `6c531fa` bestanden; Browser-/Integrationsabnahme und Veröffentlichung stehen noch aus. Diese Datei wird nach den tatsächlichen Messungen ergänzt. Keine physische iPhone-/Android-Abnahme behauptet.

Der anschließend mit der Karteninspektion zusammengeführte lokale Stand
`240ac74da4b4512dbfc760fda532d684c5e48963` besteht außerdem die acht tatsächlichen
Godot-UI-Suites: Inspektion **3399/0**, Shell-Geometrie **1018/0**, Drag-Abbruch
**112/0**, Spielfeld-Eröffnung **3852/0**, Alpha-UI **353/0**, Alpha02-UI
**4439/0**, Orientierung **96/0**, kurze Querformate **430/0**. Der Alpha-UI-Zähler
kann wegen des lokalen gespeicherten Seeds variieren. Diese Entwicklungsnachweise
ersetzen weder endgültige Head-CI noch neue Merge-Commit-QA.

Eine zusätzliche reproduzierbare Aufnahme der wirklichen Starthand mit freien
Pfaden ist über `tools/premium/render_arena_qa.gd -- --include-opening` verfügbar.
Ohne dieses optionale Aufnahmeflag bleibt die bestehende Pflichtsuite bei genau
neun Hauptaufnahmen plus dem getrennten Effektdiagramm; keine Prüfung entfällt.

## Ausgangslage und Abgrenzung

Die Änderung startet von develop `81ec5701d1600f2e80738a2dd0b3a05a9f9973a0` und betrifft ausschließlich Präsentation und deren Tests. Spielregeln, Kartenwerte/IDs, RNG, fünf Pfade, Energie/Resonanz, Siegbedingungen, KI und Assetzuordnungen bleiben unverändert. Die experimentelle echte 3D-Variante bleibt erhalten. Es findet keine globale Umstellung der Kartenrahmen statt; die Fractal-Fold-Studie hat einen eigenen Freigabeweg.

Tatsächliche Startszene: `scenes/alpha_shell.tscn`, Controller `scripts/alpha/shell.gd`. Die ältere `scripts/arena.gd`-Szene ist kein Nachweis für die aktuelle Alpha-Oberfläche.

Die Vorher-Aufnahmen des veröffentlichten Ausgangsbuilds befinden sich in dessen reproduzierbaren öffentlichen QA-Nachweisen. Für den Vergleich werden zusätzlich dieselben bewusst arrangierten zehn Wesen und sechs Handkarten mit `tools/premium/render_arena_qa.gd` vor und nach der Änderung gerendert. Diese Darstellungsfixtures sind keine gespielten Partien.

## Tatsächlich implementiert

- Die gemeinsame 2,5D-Bühne zeigt fünf durchgehende, gegeneinander abgegrenzte Steinpfade, ausgeformte Licht-/Schattenfacetten, dunkle Fugen und eine leuchtende mittlere Raumfalte. Eine feste Beleuchtungsrichtung kommt von links oben. Die eigene und gegnerische Hälfte unterscheiden sich durch kühle/wärmere Materialtönung und die Richtung der Pfadmarkierungen.
- Freie Positionen überdecken die Arena nicht mehr mit zehn permanenten Rechteckflächen. Kleine eingelassene Siegel kennzeichnen freie Plätze. Gültige Ziele und Auswahl werden mit klaren Eckmarkierungen innerhalb derselben unveränderten Touchfläche hervorgehoben.
- Die Hand erhält im normalen Querformat mehr Höhe; das Aktionsdock wird schmaler. Sechs Karten bleiben vollständig nebeneinander sichtbar und besitzen weiterhin 63:88-Seitenverhältnis. Kosten, Namen und Werte werden nicht von Nachbarkarten verdeckt. Der bestehende Notfall-Budgetschutz bei sehr niedrigen Safari-Viewports bleibt wirksam.
- Der Renderer bevorzugt gemessene vollständige Wörter. Muss ein einzelnes deutsches Kompositum auf einer kleinen Karte geteilt werden, werden die letzten Teile ausgeglichen. Ein einzelner abgetrennter Endbuchstabe und Ellipsen werden vermieden. Kartennamen und IDs selbst werden nicht verändert.
- Treffer, Schild, Block und Heilung verwenden unterschiedliche Silhouetten: kurze Trefferstrahlen, sechseckiger Schild, Blockplatte und Heilungszeichen. Alle Effekte sind kurze, begrenzte Darstellungsaufträge; sie besitzen keine Kampf-Callbacks. Höchstens 24 visuelle Jobs bleiben gleichzeitig aktiv. Reduzierte Bewegung verwendet stationäre, kurze Rückmeldungen.
- Die Bühne erhält für alle Ansichten eine Kopie derselben zehn öffentlichen Präsentationszustände. Dadurch können Bereitschaft und Position angezeigt werden, ohne auf die Kampflogik zurückzuschreiben.

## Unveränderte Eingabe- und Regelgrenzen

`ArenaStage.slot_rect()` und `slot_hit()` bleiben unverändert. Die Ebene kann perspektivisch wirken; die wirklichen Touchrechtecke bleiben aufrecht, mindestens 44 logische Pixel groß und überschneidungsfrei. Ursprung, kontrollierte Pfade und Gegner-/Spielerseite verwenden weiter die vorhandenen Indizes. Die reale 3D-Kamera, ihr Sichtfeld-Fit und die projizierten Zielrechtecke werden nicht ersetzt.

Die Handhöhenfraktion wird im normalen Querformat von 0,345 auf 0,40 angehoben. Unter 374 logischen Pixeln nutzbarer Höhe gleitet sie auf 0,37 zurück, damit permanente Kampf-/Bereitschaftswerte die Wesenillustration nicht verdrängen; die Dockbreitenfraktion von 0,255 auf 0,205 reduziert (weiterhin begrenzt). Das ist eine Layoutänderung, keine Änderung von Handlimit, Kartenzahl oder Zugphasen. Die vollständige Karteninspektion wird separat im ersten UX-PR korrigiert.

## Prüfungen und echte Nachweise

Native Erstprüfung unter Godot im isolierten Testprojekt durchgeführt; die vollständige Abschlussprüfung des endgültigen Integrationsstands steht noch aus. Die tatsächlichen Läufe und daraus folgenden Korrekturen sind unten getrennt aufgeführt.

```sh
godot --headless --path . --audio-driver Dummy --script tests/premium_battle_layout.gd
godot --headless --path . --audio-driver Dummy --script tests/premium_battle_text.gd
godot --headless --path . --audio-driver Dummy --script tests/premium_arena_geometry.gd
godot --headless --path . --audio-driver Dummy --script tests/premium_battle_geometry.gd
godot --path . --audio-driver Dummy --script tools/premium/render_arena_qa.gd -- --output=res://work/mobile-correction/after
```

### Tatsächliche Iterationen

| Stand | Tatsächliches Resultat | Korrektur |
| --- | --- | --- |
| `79f7893` | Layout 7.455 Prüfungen, 0 Fehler; Arena-/3D-Geometrie 3.158, 0 Fehler; Shell-Geometrie 997, 0 Fehler; neun echte Shell-Renderings plus Effektdiagramm ohne gemeldeten Rendererfehler. Text 30.597 Prüfungen, 358 Fehler. | Bei 756 × 299 beanspruchte die vergrößerte Hand zu viel Höhe: 357 Wesen unterschritten den bestehenden 25-%-Illustrationsanteil. Ein vollständiger langer Name benötigte vier Zeilen. |
| `bb730f5` | Layout 7.455/0, Arena-/3D-Geometrie 3.158/0. Alle 357 Illustrationsfehler behoben. Text 30.597 Prüfungen, noch zwei Fehler für denselben langen Namen bei 756 × 299 und 756 × 320. | Handanteil gleitet bei sehr niedrigen Safari-Viewports zurück; normale iPhone-Querformatgrößen behalten die größere Hand. |
| `8ffcefc`, geprüft auf `6c531fa` | Alle vier nativen Prüfungen bestanden: Layout **7.455/0**, Text **30.597/0**, Arena-/3D-Geometrie **3.158/0**, Shell-Geometrie **997/0**. Alle 550 tatsächlichen Namen und die 357 Wesen wurden in den jeweiligen Größen geprüft. | Die opake Namensplatte nutzt die Breite innerhalb der Kartenkontur statt ausschließlich der schmaleren Illustrationsöffnung. Schriftminimum, Drei-Zeilen-Grenze und sämtliche Assertions bleiben bestehen. |

Die tatsächlichen 844-×-390- und 932-×-430-Aufnahmen wurden visuell geprüft: sechs illustrierte Karten und ihre Kosten/Werte sind sichtbar, fünf Pfade und beide Seiten bleiben eindeutig, keine erkennbare Überlagerung wichtiger Aktionen. Die Anweisung zum zweiten Antippen stammt aus der alten Basis und wird durch den vorausgehenden Inspektions-PR ersetzt. Eine vollständig besetzte Darstellungsfixture belegt nicht allein die Gestaltung freier Pfade und nicht die Spielbarkeit einer Partie.

Die Geometrietests prüfen neun Bildschirm-/Safe-Area-Größen, ein bis sechs Karten, alle Auswahlen, die vollständigen Kartenkonturen und zehn gültige Touchziele. Der Texttest misst alle 550 tatsächlichen Namen und die Kampfwerte der vorhandenen Wesen. Neue Prüfungen verlangen vollständige Zeichenfolgen ohne Ellipsen und ohne isolierte Endbuchstaben.

Die nativen Aufnahmen umfassen weiterhin dieselben neun Shell-Zustände. Zusätzlich rendert eine isolierte Godot-SubViewport-Fixture Schild/Block/Heilung mit identischem weißen Pigment und identischem Alter. Nichtleere, unterschiedliche Pixelmasken belegen tatsächlich unterschiedliche Geometrien statt bloß anderer Farben. Dieses Effektdiagramm erzeugt keinen Schaden und verändert keinen Kampfzustand.

Nach dem kontrollierten Aufsetzen auf den vorausgehenden Inspektions-PR müssen dieselben nativen Prüfungen auf dem integrierten Commit erneut bestehen. Die bestehenden Browsermatrizen und vollständigen gespielten KI-Partien müssen anschließend beide Browser-Engines, Touch, Rotation, Mulligan, erlaubtes/unerlaubtes Ausspielen, Replay und Neustart absichern. Ein Layoutfixture ersetzt diese Prüfungen nicht.

## Performance und Grenzen

Die neue 2,5D-Fläche benötigt keine Shader, zusätzlichen Texturen, dynamischen Lichter oder Partikelsysteme. Sie wird bei geänderten Daten/Größe neu gezeichnet, nicht durch einen eigenen Daueranimationsloop. Die 3D-Vergleichsvariante behält ihre bestehende begrenzte Geometrie und eingefrorenen Karten-SubViewports.

Messwerte zu Framezeiten, Prozess-RSS und tatsächlichen Touchgrößen fehlen noch. Linux-/Software-Rendering-Messungen werden ausdrücklich nicht als physischer iPhone- oder Android-Benchmark bezeichnet. Safari-Adressleisten, Safe Areas und echte Gerätestarts benötigen weiterhin eine physische Abnahme.
