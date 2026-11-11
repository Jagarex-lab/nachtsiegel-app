# Hochformat-Karten in Sammlung und Deckbuilder

Implementiert und durch tatsächliche Godot-Control-Geometrie geprüft. Visuelle Screenshots aus dem integrierten Premium-Renderer werden zusätzlich benötigt; dieser Bericht behauptet keine physische Geräteabnahme.

## Ursache und Korrektur

Die Bibliothek verwendete unabhängig von der verfügbaren Spaltenbreite eine feste Kartenhöhe von 176 Pixeln. Auf einem 390 Pixel breiten Smartphone führte das zu beinahe quadratischen Kartenfeldern. Der neue Premium-Renderer hält dagegen das Format 63:88 ein; in einem quadratischen Control bliebe deshalb ungenutzte Fläche.

`Shell.library_panel()` misst nun nach der Containeranordnung die **tatsächlich zugewiesene Scroll-Pane-Breite**. `scripts/premium/library_geometry.gd` berechnet daraus Spaltenzahl, Kartenbreite und die passende 63:88-Höhe. Dadurch berücksichtigt die Desktop-Ansicht auch den nebenan stehenden Deckbereich. Eine feste Reserve für den thematischen vertikalen Scrollbalken verhindert Breitenwechsel zwischen kurzen und langen Suchergebnissen.

Die Tiles besitzen ausdrücklich bemessene Breiten und Höhen. Das Raster schrumpft auf seinen Inhalt; ein einzelnes Suchergebnis wird daher nicht zu einer breiten Textleiste gestreckt. Bei 390 Pixeln Bildschirmbreite entstehen etwa 175–180 Pixel breite und 244–251 Pixel hohe Karten. Desktop verwendet je nach echter Pane-Breite bis zu sechs Spalten, schmale Ansichten bis zu vier. Die Seitengrenzen bleiben unverändert: zwölf aktive Karten auf Mobile, 24 auf Desktop. Es werden keine 550 gleichzeitigen Karten-Controls erzeugt.

Filter, Suche, Kartentippen zum Hinzufügen, separate Details-/Hinzufügen-Aktionen und Pagination bleiben erhalten. Auf kurzen Querformatansichten kann eine gesamte Hochformatkarte höher als der Scrollbereich sein. Die QA prüft deshalb die tatsächlich geclippte Touchfläche und die per Scrollen erreichbare Details-Schaltfläche. Sie behauptet ausdrücklich nicht, dass jede Karte oder alle Kartentexte gleichzeitig vollständig im sichtbaren Bereich liegen.

## Nachweis

```sh
godot --headless --path . --audio-driver Dummy --script tools/premium/test_library_geometry.gd
```

Godot 4.6.3 Headless: **197 Assertions, 0 Fehler**, ohne Runtimefehler oder Ressourcenrest.

Geprüft wurden 390×844, 320×568, 844×390, 1280×720 und 1600×900: tatsächlicher 550-Karten-Katalog, unveränderte begrenzte Seitengröße, sichtbare Pagination, 63:88-Control-Abmessungen, mindestens eine reale geclippte 44-Pixel-Kartenfläche, Desktop mit zwei Panels, leere und kurze Suchergebnisse, Hinzufügen genau einer legalen Kopie sowie durch Scrollen erreichbare 44-Pixel-Details mit tatsächlicher Karteninspektion.

Das sind Layout- und Aktionsprüfungen in Godot, keine physischen Touch- oder Qualitätsurteile über Bildschirmfotos. Kartenrahmen, Texte und Illustrationen stammen weiterhin aus dem gemeinsamen Premium-Kartenrenderer; dieses Paket verändert keine Kartendaten, Kampfregeln oder Assetzuordnungen.
