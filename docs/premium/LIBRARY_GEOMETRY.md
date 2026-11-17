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

## Scrollen darf keine Karte auswählen

Die abschließende WebKit-Prüfung reproduzierte auf dem vorherigen Export einen
weiteren echten Eingabefehler: Nach zwei schnellen Wischbewegungen erschien
bereits eine fremde Karteninspektion, bevor der beabsichtigte Kartentap erfolgte.
Die Browser-Negativbelege enthalten unveränderte Beobachtungen vor und nach
jedem Flick; es wurde kein Spielzustand eingesetzt.

Scrollbare Schaltflächen werden nun erst nach dem vollständigen Eingabepaket
aktiviert. Ein vom ursprünglichen Zeigerstart bewachter Eingabe-Epochenschlüssel
unterscheidet echte neue Taps von nachträglichen GUI-Press-Signalen während einer
Bewegung. Bewegung ab acht CSS-Pixeln, Abbruch, mehrere Finger, geänderte
Scrollpositionen oder ein inzwischen erneuerter Control-Baum verhindern die
Aktivierung. Tastaturaktionen behalten ihren eigenen fokussierten Eingabeweg.
Es gibt keine zeitliche Sperre nach dem Scrollen.

Karten und normale Schaltflächen innerhalb eines Scrollbereichs verwenden
`MOUSE_FILTER_PASS`, damit auch ein Wischen direkt auf der Illustration den
Scrollbereich erreicht. Spielfeld, Handkarten und Audioregler werden dadurch
nicht umgestellt. Der native Eingabetest fordert ausdrücklich, dass ein solcher
160-Pixel-Wisch tatsächlich scrollt und weder Inspektion noch Kartenhinzufügen
auslöst. Ein anschließender echter Tap, ein Drei-Pixel-Wackler, Mausklick sowie
Leertaste und Enter müssen weiterhin sofort funktionieren.

`tests/premium_scroll_input.gd` bestand **46 Assertions ohne Fehler**. Enthalten
sind reale Touch-/Maus-Eingaben und klar markierte adversariale GUI-Signalfolgen;
die Signalfolgen werden nicht als physische Geräteprüfung ausgegeben. Die
vorhandenen 94 Handgesten-, 16 Primäraktions-, 258 Bibliotheks- und 23
Auswahl-Assertions bestanden zusätzlich unverändert. Betroffene UI-Testtreiber
verwenden nun echte `InputEventScreenTouch`-Eingaben mit gemessener geclippter
Touchfläche statt eines programmatischen `pressed.emit()`-Kurzschlusses. Es gibt
keine Freistellung des Produktcodes für Testaufrufe.

Auch unverändert bleibende Ansichten verbrauchen jeden ursprünglichen Tap genau
einmal. Doppelte GUI-Signale können dadurch beispielsweise einen Vollbildschalter
nicht erneut aktivieren. Fokussierte Tastaturaktionen besitzen einen eigenen
einmaligen Eingabeschlüssel; ein nachfolgender Zeigerstart entwertet alte
Tastatur-Signale. Die zusätzlichen Proben verwenden ausdrücklich einen
unveränderten UI-Zähler, damit ein zufälliger Ansichtswechsel diese Fehler nicht
verdecken kann. Der nächste echte Tap beziehungsweise Tastendruck bleibt sofort
verfügbar.

Die ursprüngliche native Zwischenprüfung meldete zunächst korrekt, dass Karten
mit `MOUSE_FILTER_STOP` nicht von der Illustration aus gescrollt werden konnten.
Eine weitere Zwischenprüfung enthielt einen Fehler im neuen Testtreiber: Ein
Drei-Pixel-Wackler wurde fälschlich mit einer relativen 20-Pixel-Vertikalbewegung
gesendet. Der Treiber wurde auf die tatsächliche Positionsdifferenz korrigiert;
die Anforderung an den ersten gültigen Tap wurde beibehalten. Beide ursprünglichen
Logs bleiben im QA-Artefakt erhalten.

Der zusätzlich ausgeführte echte native Anwendungstest machte eine vorhandene
asynchrone Testannahme sichtbar: Acht Frames reichen nicht zuverlässig aus, um
einen bereits laufenden Musikübergang abzuschließen. Der Test wartet jetzt
innerhalb von höchstens fünf Sekunden auf den tatsächlichen Kampagnenkontext und
nach dem Verlassen auf den vollständig abgeschlossenen Menüübergang. Beide
Kontextanforderungen bleiben ausdrückliche Assertions. Der native Lauf bestand
**37 Assertions ohne Fehler**; der protokollierte natürliche Übergang dauerte
1891 Millisekunden, ohne Pausierung oder erzwungene Audioänderung. Der produktive
Audiocode wurde nicht geändert.
