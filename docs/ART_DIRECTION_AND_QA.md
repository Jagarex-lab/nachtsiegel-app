# NACHTSIEGEL — Visual Direction & Acceptance Gate (2026-11-04)

## Zielbild
Eigenständiges, kommerziell anmutendes Dark-Fantasy-Sammelkartenspiel. Referenz ist das **Qualitätsniveau** hochwertiger digitaler Kartenspiele, nicht deren konkrete UI, Marken, Kartenrahmen, Ikonografie oder Assets. Fünf Pfade sind das zentrale NACHTSIEGEL-Merkmal.

### Art Direction
- Obsidian-Kathedrale, gebrochener schwarzer Stein, gedämpftes Gold, kaltes Mondlicht und sparsame magische Akzente.
- Vier eigene Fraktionssprachen: Aschensturm (Glut/Kupfer), Gezeitenwall (Tiefsee/Türkis), Dornenwacht (Moos/Dornen), Nachtgewebe (Violett/Silber).
- Illustrierte Karten und Kreaturen statt einfacher geometrischer 3D-Einheiten.
- 3D-Tisch nur als Tiefen-/Lichtkulisse; Interaktionen und Kartentexte in scharfer 2D-UI.
- Kreaturen auf Pfaden als eigenständige kleine Portraitkarten, Handkarten größer und mit klaren Werten.
- Keine Verwendung geschützter Designs oder unverändert übernommener Referenzgrafiken.

## Mobile Composition (Landscape first)
- Safe areas und Safari-Browserleisten respektieren; keine UI außerhalb des sichtbaren Canvas.
- Hauptfläche: 5 Pfade mit klarer Gegner-/Spieler-Hälfte, mindestens 50 % der nutzbaren Höhe.
- Kartenhand: große Artworks, Kosten, Name, Angriff/LP; Karte antippen -> fokussierte Vergrößerung -> Pfad wählen.
- Statusanzeigen: Gegner oben, Spieler unten; Runden-/Energiewerte ohne textlastige Sammelzeile.
- Touch-Ziele: mindestens ca. 44 CSS-Pixel; Spielzüge dürfen keine Mikroschrift erfordern.
- Keine persistenten Debug-Buttons auf dem Spielfeld.

## Design-Gates (keine geschätzten Prozentwerte)
1. **Erkennbarkeit:** Fraktion, Kartentyp, Kosten, Angriff, LP und Zielpfad bei realer iPhone-Querformatgröße sofort unterscheidbar.
2. **Komposition:** Kein abgeschnittener Button, keine überlappenden Karten/Statusanzeigen, keine großen ungenutzten schwarzen Bereiche.
3. **Kartenqualität:** Jede Pilotkarte hat eine individuelle, original erstellte Fantasy-Illustration; nicht nur generische Symbole.
4. **Materialität:** Arena, Rahmen, Porträts und UI haben kohärente Beleuchtung, Textur, Kontrast und Hierarchie.
5. **Animation:** Karten ziehen, auswählen, ausspielen, treffen und sterben jeweils mit verständlicher Reaktion.
6. **Spielbarkeit:** Beschwören, Zauberziele und Zugende auf echtem iPhone zuverlässig und ohne versehentliche Eingaben.
7. **Technik:** Godot-Webexport erfolgreich; Laufzeit-Screenshot auf iPhone geprüft; keine ungeklärten Start-/Skriptfehler.
8. **Regelwerk:** Vollständige v2.5-Regeln separat portieren und anhand von Kampflogs testen; Design darf Regeln nicht verdecken.
9. **Rechte:** Asset-Herkunft, Bearbeitungsrechte und kommerzielle Lizenzen pro Asset dokumentiert.

## Evaluierung des ersten Stilentwurfs
**Stärken:** Fünf Pfade klar, starker Dark-Fantasy-Ton, Kartenillustrationen als Hauptmotiv, deutliche Fraktionsfarben.
**Schwächen:** Zu viele Ornamente, sehr kleine Kartentexte, Statuspanel rechts beansprucht wertvolle Breite, vier Handkarten konkurrieren mit dem Spielfeld; iPhone-Usability nicht verifiziert.
**Entscheidung:** Nur als Concept Art akzeptiert; NICHT als freigegebenes Produktionslayout. Keine behauptete Hearthstone-Prozentqualität.

## Umsetzung in überprüfbaren Schritten
A. Responsive, lesbares 2D-Board mit fünf Pfaden und Handkarten bei fester Landscape-Safe-Area; keine Kugel-/Kegel-Kreaturen.
B. Drei bis fünf hochwertige ORIGINAL-Artworks in kommerziell verwendbarem Format und zugehörige Kartenrahmen.
C. Zug-/Beschwörungs-/Trefferanimationen mit konkreten mobilen Screenshot- und Interaktionstests.
D. Vollständige Kampfregeln und deterministische Regressionstests.
E. Erst nach bestandenen Gates mehr Karten, weitere Arena-Skins, Audio und native Builds.

**Status:** Art Direction dokumentiert. Produktionslayout und Asset-Integration sind noch nicht implementiert oder verifiziert.
