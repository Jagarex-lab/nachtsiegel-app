# Task B – Premium-Komposition und visuelles System

Basis `develop` bei `2bce5c3`, Umsetzung auf `feature/premium-arena`. Der Produktname bleibt NACHTSIEGEL. Dieser Bericht beschreibt tatsächlich in Godot implementierte Komponenten; die Screenshots sind echte Renderings, keine gemalten UI-Mockups.

## Audit

Die Ausgangsszene `scenes/arena.tscn` baut ihre Oberfläche in `scripts/arena.gd`. Zwei übereinanderstehende Helden links und ein hoher Bedienblock rechts engen das Spielfeld ein. Zehn verkleinerte Handkarten wiederholen dieselben Informationen; die Hintergrundgrafik verleiht ihnen keinen gemeinsamen Standpunkt. Die Auswahl vergrößerte sich nur um sieben Prozent. Verfügbare Smartphone-Breite blieb für Karten ungenutzt. Die vorhandene Kontrastpalette ist dagegen tragfähig und wird erhalten.

## Drei gerenderte Konzepte

Identischer Zustand: sechs Handkarten, drei eigene und drei gegnerische Kreaturen, zehn Energie, ausgewählte Nebelqualle. Alle Konzepte verwenden dieselben echten Spielkomponenten und dieselben Bildressourcen. Die Dateien `arena_composition.gd` und `arena_stage.gd` enthalten die drei Varianten reproduzierbar.

| Konzept | 1600×900 | 844×390 | Bewertung |
|---|---|---|---|
| Monumentale Ritualbühne | [Bild](screenshots/concept-ritual-1600x900.png) | [Bild](screenshots/concept-ritual-844x390.png) | Stärkere perspektivische Verengung und seitliche Helden; atmosphärisch, aber die linke Leiste kostet Spielfläche |
| Hochwertiger Spieltisch | [Bild](screenshots/concept-table-1600x900.png) | [Bild](screenshots/concept-table-844x390.png) | Ruhige Tischplatte, Energie oben, seitliche Helden; gute Übersicht, auf dem Smartphone dichter Kopfbereich |
| Breite Mobile-Arena | [Bild](screenshots/concept-mobile-1600x900.png) | [Bild](screenshots/concept-mobile-844x390.png) | Gegner oben, eigener Held bei der Hand, breite Pfade, kompakte rechte Aktionen; beste nutzbare Breite und klare Blickführung |

Redaktionelle Bewertung, 1–5; keine Nutzerstudie. Kriterien gleich gewichtet:

| Konzept | Lesbarkeit | Spielfläche | Touch | Material | Eigenständigkeit | Mittel |
|---|---:|---:|---:|---:|---:|---:|
| Ritualbühne | 3 | 3 | 4 | 5 | 4 | 3,8 |
| Spieltisch | 4 | 4 | 4 | 4 | 4 | 4,0 |
| Mobile-Arena | 5 | 5 | 5 | 4 | 4 | 4,6 |

**Entscheidung: Mobile-Arena.** Nicht ein zusätzlicher Rahmen, sondern ein neuer Flächenplan: Helden entstapelt, durchgehende rechte Seitenleiste entfernt, Handzone vom Kampfplatz getrennt und Kartenbreite nach verfügbarer Breite berechnet. Die native Geometrieprüfung verlangt mindestens 70 Prozent horizontale Spielfeldspanne und kontrolliert die tatsächlichen Textflächen der sechs Karten auf Überdeckung.

## Tatsächlich implementiert

- Perspektivische Steinbühne mit sichtbarer Vorderkante, Kontaktschatten, fünf durchgehenden Bahnen und körperlichen Plinthen. Die Steinoberfläche ist ein neu erzeugtes Konzeptmaterial; UI und Spielfiguren werden unabhängig in Godot gerendert.
- Eigene Darstellung für ausgespielte Kreaturen: große Porträtmedaillons, Angriff, Leben und Fraktionszeichen. Redundante Energiekosten und winzige Kartennamen stehen auf dem Feld nicht nochmals im Weg; Antippen öffnet die vollständigen Details.
- Adaptive Handkartenbreite, leichte Fächerung, 24 Prozent größere Auswahl und seitlich ausweichende Nachbarkarten. Kosten, Namen und Werte bleiben frei. Vollständige Namen werden für alle vier geforderten Standardauflösungen automatisch geprüft.
- Metallfassung, Schiefer, oberes linkes Kantenlicht und nach rechts unten fallende Schatten verbinden Handkarten, Kreaturen, Helden, Kartenrückseite und Buttons. Der eigene vorhandene Reliquienrahmen wird als Materialbestandteil wiederverwendet.
- Reale Ziehstapeldarstellung mit eigener Kartenrückseite und tatsächlicher Restkartenzahl; keine erfundene gegnerische Kartenhand.
- Glyphen für vier Fraktionen und Zauber; eindeutige Kosten-Sechsecke, schräge Angriffsplättchen und Lebensschilde.
- Abgesetzte Dialogblätter mit geschlossenem Innenbereich und abdunkelnder Umgebung; konsistente Hover-Tooltips und geformte Hauptaktionen.
- Kurze Auswahl-/Ziehanimationen, getrennte Angriffsbewegungen beider Seiten und reduzierte Bewegung. Keine zusätzliche Verzögerung der Kampfregeln.
- Hinweise und vollständiger Auswahlname teilen eine kontextabhängige Kopfzone, anstatt die Karte oder Kampfwerte zu überdecken.

## Zentrale Vorgaben

`ui_tokens.gd` definiert semantische Farben, Stein-/Metallwerte, Schriftunterlagen, Mindestschrift, 44-CSS-Pixel-Touchziel, Handmaß, Auswahlfaktor, Abstände, Schattenrichtung und Animationstempo. `arena_composition.gd` enthält den responsiven Flächenplan. `arena_stage.gd` rendert die körperliche Bühne, `card_face.gd` die gemeinsamen Porträt-/Wertekomponenten. Bestehende KI-Konzeptillustrationen bleiben Platzhalter; keine Fremdspielgrafik wurde übernommen.

Normaltext wird mit mindestens 4,5:1 gemessen, wesentliche Konturen und Symbole mit mindestens 3:1. Schrift hat tatsächlich deckende Unterlagen. Materialgravuren und schwache Umfeldreflexe sind dekorativ und vermitteln keine alleinige Spielinformation. Zustände verwenden zusätzlich ✓, ×, !, Vergrößerung, Kontur oder Beschriftung.

## Dokumentierte Iterationen

1. **Kompositionsversuche:** drei echte Layoutvarianten bei identischem Spielzustand. Befund: glatte Bühne, zu kleine Kreaturenausschnitte und ein von der Auswahl verdeckter Hinweis.
2. **Material und Hierarchie:** eigene Schiefertextur, größere Kreaturen, ruhigerer Untergrund und Verlagerung des Hinweises. Die Prüfungen fanden zwei zu breite Heldenbeschriftungen in sehr kurzen Fenstern; die eigene Seite wurde kompakt als „DU“ beschriftet.
3. **Hand und Modalität:** adaptive Kartenbreite, größere Auswahl, getrennte Nachbarn, Kartenrückseite und Dialogblatt. Ein Fehler in der Breitenformel verursachte außerhalb liegende Handkarten und gemessene Überdeckungen; Formel korrigiert, keine Kontrastgrenze abgesenkt.
4. **Härtung und Abnahme:** vier Standardauflösungen, alle Auswahlpositionen, geometrische Prüfung echter Schriftflächen, eigene gegnerische Angriffsbewegung und weitere Symbolmessungen. Die vollständige lokale Suite besteht.

## Vorher / nachher

| Zustand | Vorher | Nachher |
|---|---|---|
| Start | [Bild](screenshots/before-start-844x390.png) | [Bild](screenshots/start-844x390.png) |
| Auswahl | [Bild](screenshots/before-selected-valid-844x390.png) | [Bild](screenshots/selected-valid-844x390.png) |
| Voller Tisch / sechs Handkarten | [Bild](screenshots/before-full-board-six-hand-844x390.png) | [Bild](screenshots/full-board-six-hand-844x390.png) |
| Inspector | [Bild](screenshots/before-inspection-844x390.png) | [Bild](screenshots/inspection-844x390.png) |

Weitere echte Zustände: [Zauberziele](screenshots/spell-targets-844x390.png), [Kampf](screenshots/combat-844x390.png), [Sieg](screenshots/victory-844x390.png), [Niederlage](screenshots/defeat-844x390.png), [1600×900 mit voller Belegung](screenshots/full-board-six-hand-1600x900.png).

## Testnachweis vor Task C

7.484 Assertions ohne Fehler: 684 Regelassertions mit 30 Differential-Duellen, 2.253 Datenassertions, 97 Godot-Katalogabfragen, 380 reale Eingabe-/Layoutassertions, 1.720 neue Premium-Geometrieassertions und 2.350 UX-Assertions. **62 gepaarte Renderzustände, 2.627 Kontrastmessflächen, keine Unterschreitung.** Siehe [Log](qa/b-native-tests.log) und [Messwerte](qa/contrast-report.json).

Geforderte Auflösungen 844×390, 915×412, 1280×720, 1600×900 sowie zusätzliche kurze Fenster und simulierte Safe Areas. Physische iPhone-/Android-Gerätetests bleiben getrennt von Browseremulation; keine vollständige WCAG-Zertifizierung. Veröffentlichung und weitere Prüfungen werden gemeinsam mit dem anschließenden Task C dokumentiert.
