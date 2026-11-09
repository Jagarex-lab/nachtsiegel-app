# Bekannte Einschränkungen und nächste Schritte

Stand:2026-11-09. Keine Einschränkung wird als bestandener Test gezählt.

## Noch nicht implementiert

1. **P11c/d:** Originales JS audit-v4/replayVersion2 mit JS-JSON-/FNV1a-Semantik und Import echter Legacy-Exports. Der neue native SHA256-Replayvertrag ist ein separates Format. Nächster unabhängiger Schritt: Unicode/Zahlen/Feldreihenfolge-Goldens, dann Originalexport-Import gegen fixierten Oracle.
2. **P12c:** Import/Export alter v09/v06/v05-Saves. Eigenes Alpha-Profil verhindert versehentliches Überschreiben, ersetzt aber keinen Migrationsadapter. Atomare Konvertierung einschließlich Besitz/Deck/Wins/Losses/Settings separat testen.
3. Alte lokale Ökonomie/P12d wird nicht als Alpha-Funktion eingeführt. Kein Shop, Booster, Konto, Echtgeld oder Monetarisierungszustand. Architektur aus PR3 bleibt nur Referenz.
4. Vollständige historische regelbasierte Angriffsvorschau und alle game.js-Nebenwege;250 Oraclepartien/1000 breite Simulationen aus Audit-GateC sind noch nicht erreicht. Aktuell24 vollständige Differentialpartien und64 Alpha-Simulationen.

## Offener CI-Kompatibilitätsbefund (P1)

Pushlauf42705454623 bestand alle Archivprofile und alle vier Alpha-Chromiumprofile samt beiden vollständigen UI-Partien, scheiterte anschließend beim ersten WebKit-Alpha-Start: `RuntimeError: access to a null reference (entryFunction(argc,argv))`. Screenshot zeigt den Godot-Bootfehler, keinen Kampfzustand. Derselbe Build bestand lokal alle drei WebKit-Profile. Ursache noch nicht bewiesen; kein behobener Gameplayfehler behauptet. CI verwendet im Folgecommit getrennte frische Runner pro Engine und frische Browser pro Profil; Bestätigung ausstehend. Vor Freigabe muss der WebKit-CI-Start reproduzierbar funktionieren oder der tatsächliche Engine-/Browserdefekt geklärt werden.

## QA und Produktqualität

- Browser-/Touchprofile sind Desktop-Simulationen, **keine physischen iPhone-/Android-Tests**. Kein App-Store-/Play-Store-Build abgenommen.
- Archiv-UI meldete lokal erneut `Touch end turn locked against duplicate tap (1600,900)` unter Software-Rendering. Späterer kompletter Archivlauf und isolierter Inputlauf bestanden (380/0 bei unveränderter Deadline). Der frühe Timingbefund bleibt als Flakiness-Risiko dokumentiert, nicht als nachgewiesener Alpha-Kernfehler.
- Originalquelle der Hilfs-API `block.retained_during_other_begin` bleibt `guarded_begin_wrong_side` unsupported: regulärer Spielvertrag verbietet falsche aktive Seite. Nicht in1305 bestandenen Fällen enthalten.
- Bilder sind wiederverwendete Atlas-Platzhalter, nicht55 einzigartige finale Illustrationen. Neue Arena verbessert Bedienung/Trennung, erreicht aber noch keine abschließend abgenommene Premium-Art-Produktion.
- Unter296 logischen Höhenpixeln zeigt die Arena einen verständlichen Platzhinweis statt abgeschnittener Kampfcontrols. Browserleisten/Softwaretastatur schließen; Partie bleibt erhalten.
- Balance unbewiesen; lange Collapse-Partien und asymmetrische kleine Stichprobe siehe BALANCE_REPORT.
- BrowserCI anfangs Exporttemplatepfad/Ubuntu26.04 inkompatibel; beide Infrastrukturursachen korrigiert. Zusätzlicher sporadischer WPE-Archivstart auf CI: sechs Profile bestanden, siebtes Timeout; separater Pushlauf bestand die Archivprofile. Browserprozesse nun je Profil isoliert; betroffener Einzellauf lokal bestanden. Gesamtlaufstatus in QA_REPORT, kein pauschales CI-Grün.

## Phase B – ausdrücklich nicht ausgeführt

Kein develop-Merge und kein produktives Deployment. Admin-Einstellungen für geschützten Pages-Release sind nicht nachweislich vollständig eingerichtet. Alte Publisher-ID406254158 deaktiviert lassen. Releaseregeln nicht durch Featurebranch-Hosting umgehen. Siehe RELEASE_REPORT.


## Browser-Kompatibilitätsnachtrag – 2026-11-09

Der getrennte PR-Lauf42708751068 bestand die vollständigen WebKitprüfungen; der Pushlauf42708739069 scheiterte dagegen im dritten **Archiv**-WebKitprofil vor Spielstart mit `Out of bounds memory access (entryFunction)`. Prozessisolation allein ist damit kein verlässlich nachgewiesener Fix. Auch dieses Scheitern bleibt erhalten, kein automatischer Retry wird als uneingeschränkter Erfolg gezählt.

Das exakte zuvor fehlgeschlagene CI-Alpha-Artefakt wurde lokal geöffnet: WebKit-iPhone-Flow und PCK-Smoke bestanden. JS/WASM des CI- und lokalen Exports sind bytegleich. Der verwendete Playwright1.56.1-/WebKit26-Stack wird für Folgeprüfungen auf den aktuellen stabilen, ausdrücklich fixierten Playwright1.65.0-/WebKit27.2-Stack aktualisiert. Erster lokaler iPhone-Flow des CI-Artefakts auf27.2 bestanden. Vollständige Folgeprüfungen ausstehend; keine behauptete Root-Cause-Behebung oder physische Geräteabnahme.
