# Alpha 0.2 – Umsetzung und Prüfnachweis

Status: Draft-PR [#9](https://github.com/Jagarex-lab/nachtsiegel-app/pull/9), Basis develop `f1d24ba9a15ae7bc74a21cfb674f61899ac4ac7a`. Kein Merge und keine Veröffentlichung. Vollständig geprüfter App-Code: `a19cbfce00b07e1eb97ae469595aaf69f831c744`. Paketabsicherung und Testhelfer: `eaeb7c68cc849afa5dd69c3dca5aaa28d1a4f567`. Nachfolgende Dokumentation ändert den App-Code nicht. Den aktuellen CI-Status zeigt der Draft-PR. Regeln und Kartenwerte bleiben unverändert. Der vollständige technische und Ressourcen-Audit steht in [AUDIT.md](AUDIT.md).

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
| 2 – Zustände und Eingaben | Unsichtbare kurze Primäraktionssperre konnte einen Browserklick verwerfen; Neurendern konnte einen Timer mit freigegebenem Control hinterlassen | Sichtbar deaktivierte Aktion bis Bereitschaft und schwache Control-Referenz. Der abschließende Langframe-Test zeigte zusätzlich eine Timerabweichung; die endgültige Freigabe verwendet dieselbe monotone Uhr wie die Eingabesperre. Echte Doppeltaps, Suchtext bei Resize, geändertes Deck statt unveränderter Vorlage prüfen. Erste fehlgeschlagene CI-Läufe bleiben als solche erkennbar. |
| 3 – Browserrotation und Regression | Chromium meldete nach 915×412 → 390×844 CSS915×1981 und Puffer2745×5943, wodurch Aktionen außerhalb lagen | Viewportgebundener Canvas trotz Engine-Inlinegrößen. Native DPR-Screenshots, vollständige Zustandsvergleiche und sichtbare Touchflächen bei Rückrotation. Chromium-CDP expliziter Viewport-Capture gegen Screenshot-Hänger; Pixelmaße werden weiterhin strikt geprüft. |

## Erster bestandener vollständiger Prüfstand d41f194

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
| Kampf | [Vorher](before/battle.png) | [Nachher – volles Layoutfixture](after/battle.png), [echte Eröffnung](after/battle-opening.png), [kompakt844×320](after/battle-compact.png), [verfügbare Höhe844×299](after/battle-browser-height.png) |
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

Der ZIP-Build `orafold-alpha-0.2-024887775e4b.zip` (20.754.369 Bytes; SHA256 `d52e0d766ec786fce6cb3855e1d1c12ab8871a29c8b6d58d905d6dd91239ee9d`) enthält Quellcommit, Dateihashes und START.txt. Entpacken, im Ordner `python3 -m http.server 8788 --bind 127.0.0.1` starten, dann `http://127.0.0.1:8788/` öffnen; kein file://. Für einen Handytest muss ein erreichbar gebundener isolierter Testserver im eigenen Netz verwendet werden. GitHub-Pages bleibt beim bisherigen Alpha0.1-Release. Keine Produktions- oder Sicherheitskonfiguration geändert.

### Lokale Browsermessung

Chromium158 im Software-Renderer:390×844 CSS,1170×2532 Zeichenpuffer, DPR3, Zoom1, keine Canvasrotation; erweiterter Porträt-/Dreh-/Speichertest bestanden,0 Konsolenfehler. Kaltstart bis QA-Bereitschaft20,33s, Median der29 automatisierten Aktionsabläufe9,091s, Maximum63,986s unter gleichzeitiger CPU-/Software-Renderlast. Diese Abläufe enthalten Warten auf Browser-/Godot-QA-Zustände und sind **keine** Finger-zu-Bild-Latenz. Eine mobile Leistungsfreigabe ist daraus nicht ableitbar. Rohdaten: [browser-chromium.json](data/browser-chromium.json).

Die öffentliche `build-info.json` wurde nur gelesen: weiter `f1d24ba9a15ae7bc74a21cfb674f61899ac4ac7a`, Alpha0.1.

WebKit27.2: derselbe erweiterte Ablauf bestanden,0 Konsolenfehler;390×844 CSS und1170×2532 Pixel beiDPR3, keine Lock-API. Gemessene QA-Kaltstartzeit90,488s auf dem Software-Testsystem; keine iPhone-Leistungsangabe. [Rohdaten](data/browser-webkit.json).

### Browser-CI auf d41f194

WebKit-Job129770485746 bestanden: drei Querformatprofile844×390,915×412,844×320 (Safe Areas/reduzierte Bewegung), vollständige UI-Partie im vorgesehenen Hauptprofil, neuer Porträt-/Rotations-/Speichertest und wiederholte frische Kaltstarts beider Testeinstiege. Der erweiterte Porträtstart war im frischen CI-Runner nach2,521s QA-bereit; auch dies ist kein echter iPhone-Benchmark. Die unterschiedlichen lokalen Zeiten zeigen die Abhängigkeit von Software-Renderer und gleichzeitiger Last.

Chromium-Job129770485853 ebenfalls bestanden: vier Querformatprofile, drei vollständige Alpha-UI-Duelle mit Replay/Neustart, privater Legacy-UI-Regressionskampf und erweiterter Porträt-/Rotations-/Speichertest; zusammen mit WebKit sieben Querformatprofile und vier vollständige Alpha-UI-Partien. Der ganze isolierte Alpha-QA-Lauf42798120322 ist grün. Im zusätzlichen allgemeinen Push-CI-Pfad42798108821 scheiterte dagegen der Export beim unerwünschten Import einer Playwright-Codicon-Schrift aus node_modules. Eine `.gdignore` wird deshalb vor weiteren Exporten für diesen Testordner angelegt; generierte work-Artefakte werden ebenfalls vom Assetimport ausgeschlossen. Dieser Fehler ist kein bestandener Test und wird durch einen neuen vollständigen CI-Lauf geprüft.

## Abschließender Prüfstand

Der App-Stand **a19cbfc** besteht sämtliche vorgesehenen CI-Läufe:

- [Isolierte Alpha-QA42803472609](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42803472609): native Regressionen, beide Browser, wiederholte Kaltstarts und768 Balancepartien grün.
- [Allgemeine PR-CI42803472599](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42803472599) und [Push-CI42803464755](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42803464755): native Tests, exportierte Daten, Archiv- und Alpha-Browserprüfungen grün. Der zuvor fehlgeschlagene Codicon-Importpfad ist damit erneut geprüft.
- Separate Legacy- und Release-Sicherheitsprüfungen auf demselben Kopf grün; kein Deployment ausgeführt.

Lokal auf a19cbfc: vier Node-Datentests,1.704 Alpha-Regelassertions/64 vollständige KI-Partien,173 Replayassertions,348 bisherige und**769 neue UI-Assertions**, jeweils0 Fehler. Der vorherige749er-Lauf hatte genau einen Fehler in der zeitabhängigen Schaltflächenfreigabe. Dieser Fehler wurde behoben, ohne die Prüfung abzuschwächen: Freigabe und Aktionssperre lesen nun dieselbe monotone Uhr. Ein SceneTreeTimer konnte bei langsamen Frames vorzeitig freigeben.

Der vierte Iterationszyklus deckt die echte knappe Feldhöhe ab: zehn Kreaturen und sechs Handkarten bei844×320 sowie844×299 als Gegenprobe für reduzierte verfügbare Höhe. Kompakte Kreaturen haben getrennte Namens-, Porträt- und Werteflächen. Absatzhöhe/Zeilenzahl werden gegen die Wertezeile geprüft und beide Ansichten tatsächlich gerendert.

### Browserergebnisse auf dem abschließenden App-Code

[Chromium-Rohdaten](data/browser-chromium-ci-a19.json), [WebKit-Rohdaten](data/browser-webkit-ci-a19.json): sieben Querformatprofile, vier vollständige Alpha-UI-Partien mit Replay und Neustart, privater Legacy-UI-Kampf, beide erweiterten Porträt-/Dreh-/Deckspeichertests bestanden. Neue echte Deckänderungen werden über Neuladen und tatsächlichen Spielstart geprüft, nicht nur anhand der Anzahl.

Kaltstart bis QA-Bereitschaft im erweiterten CI-Ablauf: Chromium2,863s, WebKit2,509s. Rückrotation:390×844 CSS,1170×2532 Pixel, DPR3, Zoom1. Bei ausschließlich simuliertem `visualViewport.height=500` bleibt der Canvas isotrop bei844 CSS-Höhenpixeln; die bedienbare UI passt in500. Auch350 sichtbare Pixel lassen das Gerät im Hochformat. Kein CSS-Canvas-Rotieren; WebKit hat keine nutzbare Lock-API. Alle diese Angaben sind Desktop-/CI-Browsermessungen.

### Paket-, Speicher- und Versionsprüfung

`tools/alpha02_pack_inventory.gd` prüft das tatsächlich exportierte Paket. Negativtest: veröffentlichter Altbuild enthält16 Tool-Dateien und wird bei `--reject-test-assets` mit Exit1 gezielt abgewiesen; kein Skriptfehler wird dafür als gültige Abweisung gezählt. Positivtest: Kandidat enthält0 Tool-Dateien und wird akzeptiert.145 von146 Ressourcen sind gegenüber dem vollständig geprüften App-Paket bytegleich, allein `.godot/uid_cache.bin` ist um Prüfskript-Metadaten ergänzt. [Vollständige Inventuren](data/package-candidate.json), [Vergleich](data/package-comparison.json).

Die gemessene PCK-Dateigröße sinkt von31.020.996 auf10.796.424 Bytes. Ursache sind entfernte ungenutzte Testgrafiken im Export, keine neu erfundene Grafikkompression oder verlorene Spielkarten. Die drei Firefox-Logotexturen im Altbuild allein belegen20.789.517 Bytes. Originale Spielgrafiken, Daten und Regeln bleiben erhalten.

`tools/alpha02_upgrade_qa.cjs` prüft einen echten Versionswechsel unter derselben isolierten HTTP-Origin mit normalen Cache-Regeln und unveränderlichen commitbenannten Assets: Im alten Build eine Häuserkarte entfernen, eine andere neutrale Karte hinzufügen, speichern und das geänderte Deck spielen; anschließend neue HTML-/WASM-/PCK-Version laden, vollständige gespeicherte Reihenfolge prüfen und dieses Deck erneut starten. [Nachweis a19cbfc](data/upgrade-a19.json). Laufende Partien werden bei diesem Reload erwartungsgemäß beendet; ihre Speicherung wird nicht behauptet.

Die Linux-Software-Chromium-Messung dieses Laufs erfasst proportionalen Prozessspeicher aller fünf zugehörigen Browser-/Renderer-/GPU-/Audio-/Netzwerkprozesse: Alt601.318KiB, neu612.886KiB (ca.587/599MiB). Das sind zwei Momentaufnahmen, keine Peak- oder Leckmessung und kein iPhone-RAM-Wert. Die separate JavaScript-Heapzahl erfasst WASM/GPU-Speicher nicht vollständig. Unkomprimierter lokaler HTTP-Transfer67.078.156 →46.853.536 Bytes; der Unterschied entspricht der Paketverkleinerung. GitHub-Kompression, LTE und echte Safari-Ladezeit werden daraus nicht abgeleitet.

Reproduktion mit ausgepackten alten/neuen Web-Builds:

```sh
OLD_BUILD=/path/to/f1d24ba-web NEW_BUILD=/path/to/candidate-web node tools/alpha02_upgrade_qa.cjs
godot --headless --main-pack /path/to/candidate.pck --script "$PWD/tools/alpha02_pack_inventory.gd" -- --reject-test-assets
```

Playwright1.65 muss wie in den CI-Workflows installiert und über NODE_PATH verfügbar sein. Für den Handybrowser ist ein vertrauenswürdiger **HTTPS-Testhost** nötig. Godot4.6.3 prüft Secure Context auch beim Single-Thread-Export. Die HTTP-Loopback-Ausnahme am Desktop gilt nicht für eine LAN-IP auf dem iPhone. Eine funktionierende lokale HTTPS-Anleitung steht unten; es wird keine Zertifikatsprüfung im Spiel deaktiviert.

### Noch offene Freigaben und Grenzen

Keine echten iPhone-/Android-Tests, keine mobile FPS-/Temperatur-/Peak-RAM-Freigabe. Hochauflösende individuelle Illustrationen bleiben erforderlich. Native Safari-Tastatur und echter Appwechsel müssen auf Geräten geprüft werden. Aktive Partien sind weiterhin speicherresident. Der Balancebefund zur Neunten Stunde und die ausreichende Stärke des Zweitspielerausgleichs benötigen menschliche Tests und weitere KI-Politiken. Keine Ressourcen- oder Siegbedingung geändert. Kein Merge und keine Veröffentlichung; die bestehende URL bleibt Alpha0.1 bis zu einem gesonderten Releaseauftrag.

Der gesicherte Paketstand eaeb7c6 wurde mit demselben Versionswechseltest erneut tatsächlich geladen: altes geändertes Deck in vollständiger Reihenfolge übernommen und im neuen Spiel gestartet;0 Konsolenfehler. [Kandidat-Nachweis](data/upgrade-candidate.json). Der Testbuild ist vorbereitet, nicht veröffentlicht.

## Handy-Test über HTTPS

Der ZIP-Testbuild enthält `serve_https.py` (Python3.9+) und START.txt. Alternativ einen bereits vorhandenen vertrauenswürdigen HTTPS-Testhost verwenden. Für eine lokale Test-CA mit mkcert:

1. ZIP in einen eigenen Spieleordner entpacken; Zertifikat und privaten Schlüssel in einem **anderen** Ordner erzeugen. Die Beispiel-IP durch die LAN-IP des Rechners ersetzen.

```sh
ORAFOLD_TEST_IP=192.168.1.20
mkcert -install
mkcert -cert-file /path/to/test-cert.pem -key-file /path/to/test-key.pem "$ORAFOLD_TEST_IP" localhost 127.0.0.1
mkcert -CAROOT
python3 serve_https.py --bind 0.0.0.0 --cert /path/to/test-cert.pem --key /path/to/test-key.pem
```

2. Auf dem iPhone nur das **öffentliche** `rootCA.pem` aus dem angezeigten CA-Verzeichnis als Testprofil installieren und unter Einstellungen → Allgemein → Info → Zertifikatsvertrauenseinstellungen vollständig vertrauen. Den privaten CA-Schlüssel niemals übertragen. Alternativ einen schon vom Gerät vertrauten HTTPS-Host verwenden.
3. Im selben Netz `https://<Rechner-IP>:9443/` öffnen. Der Zertifikatsname muss zu dieser IP passen. Nach dem Test eine nur hierfür installierte Test-CA wieder entfernen. Dies sind manuelle Geräteschritte; hier wurden keine Truststores oder GitHub-Einstellungen geändert.

Serverprüfung tatsächlich durchgeführt: HTTPS-Übertragung mit explizit validiertem Zertifikat, korrekter WASM-MIME-Type, Ablehnung desselben nicht vertrauten Zertifikats (curl Exit60), Ablehnung eines privaten Schlüsselpfads innerhalb des Webroots. [TLS-Nachweis](data/https-test.json). Das ist kein echter iPhone-Test. Der Server ist eine lokale Vorschau, kein Produktionshosting.

Fortschritt ist an Browser/Origin gebunden. Eine andere Domain, HTTPS statt HTTP oder ein anderer Port hat einen anderen lokalen Speicher; das ist kein behaupteter geräteübergreifender Account. Der Versionswechseltest bewahrt ausdrücklich dieselbe Origin.

## Ausgeliefertes Testpaket

Download-Build `024887775e4bc95b304c489966f02163bcc5c595` enthält den geprüften HTTPS-Helfer. Der tatsächliche Versionswechseltest wurde auch auf diesem Paket erneut bestanden: [Nachweis](data/upgrade-delivery.json). Gegenüber dem vollständig grün geprüften App-Code a19cbfc unterscheiden sich erneut nur UID-Metadaten; alle145 Spiel-/Engineprojekt-Ressourcen sind bytegleich. [Paketprüfung](data/package-delivery.json). ZIP-CRC, Gesamt-SHA256 und enthaltene Dateihashes geprüft; keine Zertifikate oder privaten Schlüssel eingepackt. Die zusätzliche Dokumentation ändert den Spielcode nicht. Der neue CI-Status ist im Draft-PR nachverfolgbar.

[Hauptmenü im Hochformat](after/menu.png). Der HTTPS-Vorschauserver sendet absichtlich `Cache-Control:no-store`, damit feste ZIP-Zeitstempel keinen alten Teststand festhalten. Die Versionswechselprüfung testet davon getrennt normale Cache-Regeln und commitbenannte Assets.
