# NACHTSIEGEL — Entwicklungsstand

## Implementiert im Branch develop
- Godot-4-Webexport mit GitHub Actions und GitHub Pages
- 2.5D-Obsidian-Arena mit fünf Pfaden und schräger 3D-Kamera
- Querformat-orientierte HUD-Anordnung und Hinweis für Hochformat
- Vergrößerte Handkarten mit Kosten, Angriff, Leben und Fraktionsfarben
- Animierte prozedurale 3D-Platzhalterkreaturen mit Angriff-/Lebenswerten
- Kartenauswahl, Zielpfad, maximal zwei Beschwörungen pro Zug
- 25-Karten-Testdeck, Kartenziehen, Energie, lokale Gegnerzüge
- Kreatur-gegen-Kreatur-Kampf, direkter Heldenschaden auf freien Pfaden
- Pfadkontroll-Testregel: drei freie Pfade in zwei eigenen Angriffsphasen
- Funkenstoß kann ausschließlich gegnerische Kreaturen treffen
- Safari-Diagnose für Startprobleme

## Noch NICHT fertig
- Originalillustrationen und individuelle 3D-Kreaturenmodelle
- Vollständiger Import der 100 Kreaturen und 16 Fähigkeiten aus dem Browser-Spiel
- Vollständige v2.5-Kampfregeln, Block/Schild/Resonanz und deterministische Logs
- Deckbuilder, Menüs, Audio, Animationen auf Produktionsniveau
- Multiplayer, Konten, Monetarisierung, native iOS/Android-Pakete
- Tests auf verschiedenen iPhones und Android-Geräten

## Nächste Meilensteine
1. CI-Build der neuen Arena verifizieren, iPhone-Querformat testen.
2. Original-Kartenillustrationen und Kreaturen-Assets mit kommerziell zulässiger Lizenz einpflegen.
3. Vorhandenes Kampfregelwerk systematisch portieren und mit Fixtures testen.
4. Responsive mobile UX, Audio, Effekte, Zuganimationen und Performance optimieren.
5. Native Builds und App-Store-Vorbereitung.
