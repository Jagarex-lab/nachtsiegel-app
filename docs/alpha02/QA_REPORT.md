# Alpha 0.2 – Umsetzung und Prüfnachweis

Status: Draft-PR [#9](https://github.com/Jagarex-lab/nachtsiegel-app/pull/9), Basis develop `f1d24ba9a15ae7bc74a21cfb674f61899ac4ac7a`. Kein Merge und keine Veröffentlichung. Geprüfter ausführbarer Code: `d41f1949e556df8dc1c1de0b868b9aafbf4e06c1`; nachfolgende Dokumentations-/Bildcommits werden gesondert ausgewiesen. Regeln und Kartenwerte bleiben unverändert. Der vollständige technische und Ressourcen-Audit steht in [AUDIT.md](AUDIT.md).

## Tatsächlich umgesetzt

- Kampf im Querformat mit fünf zentralen Pfaden, kompakten Kreaturen, sichtbaren Angriff/LP, Schild-/Blockwerten, Ursprung und Konvergenzmarkierung, gültigen/ungültigen Zielen und Angriffsbereitschaft. Eine primäre phasenabhängige Aktion; Sonderaktionen und Ressourcenhilfe separat. Die regelrelevante Nachziehphase bleibt erhalten.
- Hochformat-Kampf zeigt eine Drehaufforderung und einen bestätigten Menüausstieg. Keine erzwungene Safari-Orientierung und kein gedrehter Canvas. Rotation erhält Modell, RNG, Befehle und Auswahl. Sichere Auswahl: Karte antippen, Ziel antippen, abbrechen/wechseln; Details ohne Hover.
- Hochformatmenü mit Spielen, Werkstatt, Sammlung, Einstellungen. Spielen öffnet die vier bestehenden Starter mit Macht, Symbol, Spielstil, Schwierigkeitsangabe und vollständiger Listenansicht. Eigene gespeicherte Decks können dort gewählt werden.
- Werkstatt: Porträt-Tabs Bibliothek/Deck, Desktop-Zweispalten, illustrierte Karten, Kosten/Werte/Seltenheit/Typ/Macht, Suche, direkte Filterauswahl, Kopienzahl, gezieltes Entfernen, separate Inspektion, 0–30-Zähler, Kurve, lesbare Validierungsfehler und gespeicherte Vorlagenkopien. Keine redundanten Starterdefinitionen.
- Alpha-eigene MSDF-Schrift, adaptive vollständige Namen, vektorbasierte Rahmen und Seltenheitsmarken; Macht nicht ausschließlich über Farbe vermittelt. Mipmaps beim vorhandenen Atlas. Deck- und Kartendaten, Alpha-/Legacy-Kernel sowie der ursprüngliche Sieben-Karten-Prototyp unverändert.
- Tatsächliches Canvas-/CSS-Verhältnis bei Resize ermitteln. CSS verhindert die gemessene Rückkopplung nach Rückrotation (915-Pixel-Canvas auf 390-Pixel-Viewport). Safe Areas und Browserhöhe bleiben berücksichtigt.

## Drei Entwicklungszyklen

| Zyklus | Befund | Änderung / Nachprüfung |
|---|---|---|
| 1 – Bestandsaufnahme und Komposition | Hochformat quetscht fünf Pfade; versteckte Starter; überladene Aktionsleiste; Bitmap-Schrift und begrenzte Bildquellen | Vorherbilder der Alpha0.1, neue Orientierungsansichten, direkte Deckwahl, neue Werkstatt und MSDF; native Namen-/Bounds-/Touchprüfungen. |
| 2 – Zustände und Eingaben | Unsichtbare kurze Primäraktionssperre konnte einen Browserklick verwerfen; Neurendern konnte einen Timer mit freigegebenem Control hinterlassen | Sichtbar deaktivierte Aktion bis Bereitschaft; schwache Timerreferenz. Echte Doppeltaps, Suchtext bei Resize, geändertes Deck statt unveränderter Vorlage prüfen. Erste fehlgeschlagene CI-Läufe bleiben als solche erkennbar. |
| 3 – Browserrotation und Regression | Chromium meldete nach 915×412 → 390×844 CSS915×1981 und Puffer2745×5943, wodurch Aktionen außerhalb lagen | Viewportgebundener Canvas trotz Engine-Inlinegrößen. Native DPR-Screenshots, vollständige Zustandsvergleiche und sichtbare Touchflächen bei Rückrotation. Chromium-CDP expliziter Viewport-Capture gegen Screenshot-Hänger; Pixelmaße werden weiterhin strikt geprüft. |

## Bestandene native CI auf d41f194

[Alpha-QA-Lauf 42798120322](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42798120322), Job alpha-playable bestanden:

| Prüfung | Ergebnis |
|---|---|
| Legacy-Katalog / Decks | 2.171 Assertions, 100 Karten, fünf Decks |
| Legacy Differential | 441 P01–P04 + 366 P05/P06 + 474 P07 + 24 vollständige Duelle = 1.305 Fälle, keine Fehler |
| Alpha-Regeln | 1.704 Assertions, 55 Karten, vier Starter, 64 vollständige KI-Simulationen |
| Replay | 173 Assertions, vier vollständige native Replays |
| Bestehende Alpha-UI | 348 Assertions, fünf Querformatgrößen, echte synthetische Touchereignisse |
| Neue Alpha0.2-UI | 729 Assertions, Hochformat, Rotation, alle Namen, vier Starter, geändert gespeichertes Deck |
| Alte Arena/Anwendung | Rules684, Creative2253, Narrative97, Experience707, Input/Layout380, Premium1720, UX2350, Combat725 und Sequence631 Assertions; jeweils0 Fehler |
| Balancejob | 768 abgeschlossene KI-Partien,0 Enginefehler/Abbrüche; siehe Audit und Rohdaten |

Die Skripte prüfen zusätzlich Godot-Fehlerausgaben; eine grüne Assertion-Summe allein hätte den Timerfehler nicht übergangen. Die lokal gleichzeitig mit Software-Browsern gestartete Alpha-Regelsuite erreichte ihre180s-Grenze, und der alte animierte Eingabetest erreichte lokal eine5s-Frist noch mit busy=true, aber genau einem Rundenschritt. Diese lokalen Läufe gelten ausdrücklich nicht als bestanden. Die vollständige native CI auf d41f194 besteht mit den originalen Zeitgrenzen und vollständigen Animationen; die probeweise lokale Bewegungsreduktion wurde verworfen.

## Balanceentscheidung und verbleibende Grenzen

Energie: pro Alpha-Zug1…8, nicht angespart. Resonanz: gespeicherte Reserve bis15, für Rückholung5, Bewegung3, Wacht2 und Entfesselung (Schwelle15, Verbrauch8). Ressourcenhilfe erklärt Quellen und Kosten. Empfehlung: beide beibehalten; keine A/C-Regeländerung ohne eigene Freigabe. Alle zwölf Legacy-Reaktionen und vier Entfesselungen sind im Audit einzeln dokumentiert; gemischte Machtreaktionen sind bei normalen Ein-Macht-Alpha-Decks nicht erreichbar.

Offizielle256 KI-Partien: Erstspieler114 Siege (44,53%, Wilson95%38,57–50,66%), Konvergenz55 Siege (21,48%). Neunte Stunde90/96 Siege in nicht gespiegelten Paarungen ist ein prioritäres Balance-/KI-Prüfsignal. Die feste KI und asymmetrische Ursprung-/Shift-Heuristiken erlauben keine menschliche Balancebehauptung. Keine Werte geändert.

Keine physischen iPhone-/Android-Tests. Browseremulation belegt weder native Safari-Tastatur noch Appwechsel, thermische Leistung oder OS-Prozessbeendigung. Aktive Partien bleiben speicherresident; Profile/Decks sind lokal persistent. Keine gemessene iPhone-Peak-RAM- oder Finger-zu-Bild-Latenz. Der415×421-Illustrationsatlas und der1672×941-Hintergrund bleiben echte Quellauflösungsgrenzen, insbesondere in Retina-Großansichten. Eigenständige höher aufgelöste Illustrationen bleiben erforderlich.

## Vergleichsbilder

| Zustand | Alpha0.1 | Alpha0.2 |
|---|---|---|
| Kampf | [Vorher](before/battle.png) | [Nachher – volles Layoutfixture](after/battle.png), [echte Eröffnung](after/battle-opening.png) |
| Inspektion | [Vorher](before/inspection.png) | [Nachher](after/inspection.png) |
| Starterauffindbarkeit | [Vorher – Einstellungen](before/starter-discovery.png) | [Nachher – vier Starter](after/starter-selection.png) |
| Werkstatt | [Vorher](before/deckbuilder.png) | [Porträt](after/deckbuilder.png), [Desktop](after/deckbuilder-desktop.png) |

Das volle Feld ist ein beschriftetes Layoutfixture mit zehn echten Karteninstanzen, sechs Handkarten und Statusmarkern. Es wird nicht als abgeschlossene Partie gezählt.

## Reproduktion und isolierter Testbuild

```sh
tools/test_legacy.sh
xvfb-run -a tools/test_alpha.sh
xvfb-run -a tools/test.sh
python3 -m unittest discover -s tests/release -v
godot --headless --path . --script tests/alpha02_balance.gd
python3 tools/alpha02_balance_report.py
tools/build_alpha.sh
python3 tools/package_alpha.py
```

Browser: Playwright1.65, Chromium und WebKit; `tools/alpha_browser_qa.cjs` und `tools/alpha02_browser_qa.cjs`. Die Workflows installieren die Browser und dokumentieren Befehle/Artefakte. Native Tests umfassen844×390,915×412,1280×720,1600×900 sowie kleine Browserhöhen; neue Porträtprüfungen390×844,393×852,430×932,320×568. Safe Areas werden im Browser gezielt eingespeist; dies ist kein Notch-Gerätetest.

Der ZIP-Build `orafold-alpha-0.2-d41f1949e556.zip` (20.752.011 Bytes; SHA256 `ffb9234d646794547de1ce810ff342c081105307fc2e7e8e36d7c56bbe341ec5`) enthält Quellcommit, Dateihashes und START.txt. Entpacken, im Ordner `python3 -m http.server 8788 --bind 127.0.0.1` starten, dann `http://127.0.0.1:8788/` öffnen; kein file://. Für einen Handytest muss ein erreichbar gebundener isolierter Testserver im eigenen Netz verwendet werden. GitHub-Pages bleibt beim bisherigen Alpha0.1-Release. Keine Produktions- oder Sicherheitskonfiguration geändert.

### Lokale Browsermessung

Chromium158 im Software-Renderer:390×844 CSS,1170×2532 Zeichenpuffer, DPR3, Zoom1, keine Canvasrotation; erweiterter Porträt-/Dreh-/Speichertest bestanden,0 Konsolenfehler. Kaltstart bis QA-Bereitschaft20,33s, Median der29 automatisierten Aktionsabläufe9,091s, Maximum63,986s unter gleichzeitiger CPU-/Software-Renderlast. Diese Abläufe enthalten Warten auf Browser-/Godot-QA-Zustände und sind **keine** Finger-zu-Bild-Latenz. Eine mobile Leistungsfreigabe ist daraus nicht ableitbar. Rohdaten: [browser-chromium.json](data/browser-chromium.json).

Die öffentliche `build-info.json` wurde nur gelesen: weiter `f1d24ba9a15ae7bc74a21cfb674f61899ac4ac7a`, Alpha0.1.

WebKit27.2: derselbe erweiterte Ablauf bestanden,0 Konsolenfehler;390×844 CSS und1170×2532 Pixel beiDPR3, keine Lock-API. Gemessene QA-Kaltstartzeit90,488s auf dem Software-Testsystem; keine iPhone-Leistungsangabe. [Rohdaten](data/browser-webkit.json).

### Browser-CI auf d41f194

WebKit-Job129770485746 bestanden: drei Querformatprofile844×390,915×412,844×320 (Safe Areas/reduzierte Bewegung), vollständige UI-Partie im vorgesehenen Hauptprofil, neuer Porträt-/Rotations-/Speichertest und wiederholte frische Kaltstarts beider Testeinstiege. Der erweiterte Porträtstart war im frischen CI-Runner nach2,521s QA-bereit; auch dies ist kein echter iPhone-Benchmark. Die unterschiedlichen lokalen Zeiten zeigen die Abhängigkeit von Software-Renderer und gleichzeitiger Last.

Chromium-Job129770485853 ebenfalls bestanden: vier Querformatprofile, drei vollständige Alpha-UI-Duelle mit Replay/Neustart, privater Legacy-UI-Regressionskampf und erweiterter Porträt-/Rotations-/Speichertest; zusammen mit WebKit sieben Querformatprofile und vier vollständige Alpha-UI-Partien. Der ganze isolierte Alpha-QA-Lauf42798120322 ist grün. Im zusätzlichen allgemeinen Push-CI-Pfad42798108821 scheiterte dagegen der Export beim unerwünschten Import einer Playwright-Codicon-Schrift aus node_modules. Eine `.gdignore` wird deshalb vor weiteren Exporten für diesen Testordner angelegt; generierte work-Artefakte werden ebenfalls vom Assetimport ausgeschlossen. Dieser Fehler ist kein bestandener Test und wird durch einen neuen vollständigen CI-Lauf geprüft.
