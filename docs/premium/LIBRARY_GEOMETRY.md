# Hochformat-Karten in Sammlung und Deckbuilder

Implementiert und durch tatsächliche Godot-Control-Geometrie geprüft. Visuelle Screenshots aus dem integrierten Premium-Renderer werden zusätzlich benötigt; dieser Bericht behauptet keine physische Geräteabnahme.

## Ursache und Korrektur

Die Bibliothek verwendete unabhängig von der verfügbaren Spaltenbreite eine feste Kartenhöhe von 176 Pixeln. Auf einem 390 Pixel breiten Smartphone führte das zu beinahe quadratischen Kartenfeldern. Der neue Premium-Renderer hält dagegen das Format 63:88 ein; in einem quadratischen Control bliebe deshalb ungenutzte Fläche.

`Shell.library_panel()` misst nun nach der Containeranordnung die **tatsächlich zugewiesene Scroll-Pane-Breite**. `scripts/premium/library_geometry.gd` berechnet daraus Spaltenzahl, Kartenbreite und die passende 63:88-Höhe. Dadurch berücksichtigt die Desktop-Ansicht auch den nebenan stehenden Deckbereich. Eine feste Reserve für den thematischen vertikalen Scrollbalken verhindert Breitenwechsel zwischen kurzen und langen Suchergebnissen.

Die Tiles besitzen ausdrücklich bemessene Breiten und Höhen. Das Raster schrumpft auf seinen Inhalt; ein einzelnes Suchergebnis wird daher nicht zu einer breiten Textleiste gestreckt. Bei 390 Pixeln Bildschirmbreite entstehen etwa 175–180 Pixel breite und 244–251 Pixel hohe Karten. Desktop verwendet je nach echter Pane-Breite bis zu sechs Spalten, schmale Ansichten bis zu vier. Die Seitengrenzen bleiben unverändert: zwölf aktive Karten auf Mobile, 24 auf Desktop. Es werden keine 550 gleichzeitigen Karten-Controls erzeugt.

Die erste CI-Gesamtprüfung deckte zusätzlich einen Fehler beim Verkleinern einer
bereits geöffneten Bibliothek auf: `SCROLL_MODE_DISABLED` übernahm die frühere
Raster-Mindestbreite in den Scrollbereich. Nach einem Wechsel von Querformat zu
320×568 konnte der Bereich deshalb rund 896 Pixel breit bleiben. Die nächste
Messung verwendete erneut diese zu große Breite; der Machtwähler lag außerhalb
des Bildschirms. Eine frische 320-Pixel-Instanz zeigte diesen Fehler nicht.

Die horizontale Achse verwendet nun `SCROLL_MODE_SHOW_NEVER`: Der Elternbereich
kann den Scrollbereich auf die tatsächliche Bildschirmbreite begrenzen; das
Raster wird anschließend auf genau diese Breite angepasst. Nach dem Layout
bleibt auch keine versteckte horizontale Überbreite. Es werden weder Karten
noch Bedienelemente kleiner skaliert, um den Fehler zu verdecken.

Filter, Suche, Kartentippen zum Hinzufügen, separate Details-/Hinzufügen-Aktionen und Pagination bleiben erhalten. Auf kurzen Querformatansichten kann eine gesamte Hochformatkarte höher als der Scrollbereich sein. Die QA prüft deshalb die tatsächlich geclippte Touchfläche und die per Scrollen erreichbare Details-Schaltfläche. Sie behauptet ausdrücklich nicht, dass jede Karte oder alle Kartentexte gleichzeitig vollständig im sichtbaren Bereich liegen.

## Nachweis

```sh
godot --headless --path . --audio-driver Dummy --script tools/premium/test_library_geometry.gd
```

Der ursprüngliche Godot-4.6.3-Headless-Lauf bestand **197 Assertions, 0 Fehler**,
ohne Runtimefehler oder Ressourcenrest. Die ergänzte Prüfung derselben lebenden
Bibliothek über mehrere Größen reproduzierte vor der Breitenkorrektur
**37 Fehler bei 250 Assertions**; unmittelbar danach bestanden
**253 Assertions ohne Fehler**. Der abschließende Wiederholungslauf einschließlich
fünf zusätzlicher Prüfungen auf verborgene horizontale Überbreite bestand
**258 Assertions, 0 Fehler**.

Geprüft wurden 390×844, 320×568, 844×390, 1280×720 und 1600×900: tatsächlicher 550-Karten-Katalog, unveränderte begrenzte Seitengröße, sichtbare Pagination, 63:88-Control-Abmessungen, mindestens eine reale geclippte 44-Pixel-Kartenfläche, Desktop mit zwei Panels, leere und kurze Suchergebnisse, Hinzufügen genau einer legalen Kopie sowie durch Scrollen erreichbare 44-Pixel-Details mit tatsächlicher Karteninspektion.

Das sind Layout- und Aktionsprüfungen in Godot, keine physischen Touch- oder Qualitätsurteile über Bildschirmfotos. Kartenrahmen, Texte und Illustrationen stammen weiterhin aus dem gemeinsamen Premium-Kartenrenderer; dieses Paket verändert keine Kartendaten, Kampfregeln oder Assetzuordnungen.

## Getrennte Material- und Textfarben

Die verbindlichen Machtpigmente bleiben unverändert. Amethyst `#9867BE` erreicht
als kleine Schrift auf der erhöhten UI-Fläche nur etwa **3,69:1**. Deshalb nutzt
die separate `Style.POWER_TEXT_COLORS`-Palette für diesen Text `#B58BD8`
(etwa **5,62:1**); Rahmen und Symbole behalten das originale Pigment. Startertitel
und die Machtwahl in Einstellungen verwenden die tatsächlich geprüfte
Textpalette. Die UI-Regression verlangt weiterhin mindestens **4,5:1** auf allen
drei verwendeten Flächentönen und prüft zusätzlich die exakten fünf
Materialpigmente. Kein Kontrastziel wurde reduziert.

Die tatsächliche native Alpha-0.2-UI-Regression mit Screenshots bestand nach
diesen Korrekturen **4435 Assertions, 0 Fehler**. Der zuvor verdeckte
`builder_power_houses`-Zugriff ist zusätzlich abgesichert: Ein fehlgeschlagener
echter Öffnungstap erzeugt eine explizite fehlgeschlagene Assertion und beendet
den Test, statt die Coroutine durch einen Dictionary-Zugriffsfehler bis zum
externen Timeout hängen zu lassen. Keine erwartete Schaltfläche wurde entfernt.

## Primäraktionen innerhalb eines langsamen Frames

Die Untersuchung reproduzierte außerdem zwei akzeptierte Primäraktionen im
selben Eingabeframe, wenn dieser mehr als die bisherigen 180 Millisekunden
benötigte: Ein doppelter Tap konnte zunächst Nachziehen bestätigen und direkt
danach den Zug beenden. Der vorhandene Zeitabstand bleibt bestehen; zusätzlich
wird nur eine Primäraktion je `Engine.get_process_frames()` akzeptiert. Der
sichtbare Bereitschaftszustand verwendet denselben Vertrag. Auch der optionale
Pfadwechsel verwendet diese gemeinsame primäre Aktionsfläche.

`tests/premium_primary_input.gd` bestand **16 Assertions, 0 Fehler**. Es prüft
tatsächliche Canvas-Taps, die deterministische langsame Eingabegruppe mit
220 Millisekunden innerhalb desselben Frames, vollständigen Zustand samt RNG
und Ereignissen, später zulässige Eingaben, Replay und den Neustart. Eine
gesondert markierte angeordnete Auswahl-Fixture prüft den Wechsel von
„Pfadwechsel auslassen“ zu „Zug beenden“; sie wird nicht als ausgespielte Partie
oder Replay-Nachweis gezählt. Die Kampfregeln werden nicht geändert.
