# Master550: tatsächliche Erreichbarkeit von Scroll-Controls

Der WebKit-Lauf auf `5654b48` scheiterte bei `action('difficulty')` an
`difficulty inside viewport`. Die tatsächlich veröffentlichte QA-Geometrie war:

| Beobachtung | CSS-Rechteck |
|---|---|
| Viewport | `0, 0, 844, 390` |
| Nutzbarer Settings-Scrollbereich | `48, 50, 748, 315` |
| Schwierigkeitsschaltfläche | `48, 399, 367, 44` |
| Sichtbarer Teil der Schaltfläche | `0, 0, 0, 0` |

Die Einstellungen besitzen einen funktionsfähigen ScrollContainer. Der bisherige
Master-Prüfer versuchte den sofortigen Tap, ohne das Ziel zu erreichen. Der
Produktbildschirm wurde für diese Testkorrektur nicht geändert.

`tools/master550_browser_qa.cjs` erreicht solche Ziele jetzt mit tatsächlicher
Browsereingabe. Chromium verwendet CDP-Touch, WebKit vertrauenswürdige
Mausbewegungen durch Godots konfigurierte Touch-Emulation. Vor dem Loslassen hält
der gemeinsame `settleHeldPan`-Beobachter den unbewegten Pointer für mindestens
vier frisch veröffentlichte QA-Berichte und 250 ms. Das unterbindet die zuvor
nachgewiesene Scrollträgheit im Testablauf. Der Produkt-Flick-Regressionsfall im
Premium-Prüfer bleibt schnell und ohne diese Haltephase.

Nach jedem Pan müssen Seite, Dialogidentität und Inspektionskarte unverändert
sein. Vor dem Tap wartet der Prüfer erneut auf frische stabile Geometrie. Das
vollständige tatsächliche Control muss mindestens 44 CSS-Pixel je Achse besitzen
und vollständig innerhalb von Viewport, Vorfahren-Clip und sichtbarem Rechteck
liegen. Die bisherigen Karten-, Pfad-, Abbruch-, Replay-, Filter-, Paging- und
Drag-Prüfungen sowie beide Browserprofile bleiben erhalten. Es gibt keine
Scrollpositions-, Modell-, Karten- oder Schwierigkeitsinjektion.

Der reine `master_input_contract.cjs` validiert nur gelesene Rechtecke. Die
Vertragstests enthalten den tatsächlichen CI-Fall, einen verdeckten Button trotz
passendem Viewport, die bisherigen vollständigen Karten-/44-Pixel-Anforderungen
und fehlende Clip-Diagnostik. Ein bestandener Geometrievertrag ersetzt keinen
Browserlauf.

Validierung dieser Korrektur: Node-Vertragsprüfungen und JavaScript-Syntaxcheck
bestanden. Der vollständige echte Master-Browserlauf wird separat protokolliert;
er ist zum Zeitpunkt dieses Commits noch ausstehend. Die Logs und Screenshots
werden wie bisher unter `work/master550/browser/` gesammelt und von den
bestehenden CI-Artefakten erfasst. WebKit-Dragfälle mit synthetischen TouchEvents
bleiben entsprechend gekennzeichnet; dies sind keine physischen Gerätetests.

## Tatsächlicher erster Lauf und Aufnahmedefekt

Der erste vollständige Lauf des korrigierten Scroll-Treibers (`938897d`,
Spielartefakt `b3d44411761cc1d30f4c7c2c6a7385892c2683c5`) erreichte den
Schwierigkeitsbutton mit einem echten, kontrollierten Pan. Chromium bestand
anschließend mehrere Touch- und Maus-Dragfälle, scheiterte aber nach 880
Prüfungen bei einem Maus-Drop ohne Modellkommando. WebKit wurde in diesem Lauf
noch nicht gestartet. Der damalige Fehler ist kein bestandener Gesamttest.
Die Ursache des konkreten Drops ist noch nicht bewiesen. Der neue Treiber
protokolliert deshalb zusätzlich passive DOM-, DPR-, Canvas-, Fokus- und
Eingabezeitpunkte, ohne die Eingabe- oder Spielregeln zu verändern.

Unabhängig davon wurde ein tatsächlicher Aufnahmedefekt bewiesen: In einer
kleinen **Nicht-Spiel-Canvas-Testseite**, mit demselben Chromium-Kontext und
DPR 2, änderte der alte rohe CDP-Aufruf mit `captureBeyondViewport:true` und
`clip.scale:2` die tatsächlich beobachtete DPR von 2 auf 1. Das Canvas wechselte
von 1688×780 auf 844×390. Derselbe Fehler trat nach Hochformatwechsel und
Rückkehr ins Querformat erneut auf, insgesamt dreimal. Ein anschließend mit
Playwright erstellter nativer Screenshot stellte die ursprüngliche DPR wieder
her. Belege: `work/premium-mobile/master-dpr-fixture/report.json` samt kleinen,
ausdrücklich als Nicht-Spiel-Aufnahmen gekennzeichneten PNGs. Das beweist den
Treiberfehler, nicht rückwirkend die genaue Ursache des vorherigen Maus-Drops.

Die identische rohe Aufnahmestrategie war in vier Treibern enthalten:

| Treiber | Beibehaltenes Aufnahmelimit | Erwartete DPR |
|---|---|---|
| `tools/master550_browser_qa.cjs` | 45 s | 2 |
| `tools/alpha_browser_qa.cjs` | 30 s | vorhandenes Profil, einschließlich Android-Bars 2 |
| `tools/alpha02_browser_qa.cjs` | 30 s | 3 |
| `tools/production/browser_migration_qa.cjs` | 45 s | vorhandenes Profil 1 beziehungsweise 3 |

Diese vier Treiber verwenden nun `page.screenshot({scale:'device'})` und den
reinen `native_capture_contract.cjs`. Vor und nach jeder Aufnahme müssen echte
`window.devicePixelRatio`, Fenster- und Bodybreite, Canvas-CSS-Rechteck sowie
beide Canvas-Backing-Achsen zum unveränderten Profil passen. Anschließend müssen
auch die PNG-Pixelmaße passen. Die gelesenen Vorher-/Nachher-Werte werden im
Ergebnis und bei Fehlern gespeichert. Der Prüfer skaliert keine Bilder hoch,
setzt keine Emulationsparameter zurück und verändert weder Canvas noch Modell.

Die bisherigen Chromium-Master-PNGs mit roher CDP-Skalierung sind daher **kein
verlässlicher Retina-Nachweis**, auch wenn ihre Ausgabemaße passen. Die bereits
bestandenen vollständigen WebKit-DPR-3-Partien verwendeten Playwright-Aufnahmen
und bleiben davon getrennte Nachweise. Der Premium-Treiber mit expliziter DPR 1
und CDP-Skalierung 1 wird durch diese eng begrenzte Korrektur nicht geändert.

Fünf zusätzliche Verträge prüfen tatsächliche DPR 1/2/3, niedrige Auflösung
trotz großem PNG, einseitig zu kleine Backingbuffer, Geometrieänderungen und
die unveränderten Aufnahmelimits. 27 Vertragsgruppen und die Syntaxprüfungen
aller vier Treiber bestehen. Der erneute vollständige Master-Lauf mit der
korrigierten Aufnahme und passiven Eingabeprotokollen ist noch ausstehend.

## Native-DPR-Lauf und künstliche Maus-Zwischenschritte

Der nächste echte Chromium-Lauf (`d71bcf3`, unverändertes b3d-Spielartefakt)
scheiterte nach 773 Prüfungen beim Anheben einer Handkarte in Kommando 21.
Alle fünf bis dahin erstellten Spielaufnahmen behielten tatsächlich DPR 2
und 1688×780 beziehungsweise 1688×640 Canvas-Pixel. WebKit wurde in diesem
abgebrochenen Gesamtlauf noch nicht ausgeführt.

Das passive Ereignisprotokoll belegt hier die konkrete Ursache: Die alte
`mouse.move(...,{steps:4})`-Unterteilung zerlegte die 34-CSS-Pixel-Anhebebewegung
in vier einzeln bestätigte Schritte. Der erste legte nur 8,5 CSS-Pixel zurück,
weniger als Godots unveränderte Aktivierungsschwelle von 12 CSS-Pixeln. Die
nächste Bewegung kam auf dem Softwaregrafik-Host erst 21,322 Sekunden später an;
danach folgten Abstände von 12,372 und 13,353 Sekunden. Der unveränderte
Acht-Sekunden-Leerlaufschutz hatte die angefangene Geste bereits abgebrochen.
DPR, Canvasgröße und DOM-Abbruchzähler blieben unverändert; es gab weder
Fokus-/Orientierungswechsel noch Modellkommando oder Modellfehler. Belege:
`work/premium-mobile/master-native-d71/failure-analysis.json` und das unveränderte
`work/master550/browser/chromium-error.json` samt Screenshot.

Der Test verwendet deshalb für jede geplante Mausposition jetzt einen einzelnen
vertrauenswürdigen Browser-Mausbewegungsaufruf. Die tatsächlichen Positionen
Quelle → Anheben um 34 Pixel → gültiges/ungültiges Ziel sowie Loslassen,
Maus-/Touchfälle, Abbruch- und Rotationsprüfungen bleiben erhalten. Es gibt
keine künstlichen Bestätigungspausen nach vier Unterpunkten. Produktcode,
Acht-Sekunden-Abbruchschutz und 120-Sekunden-Prüflimits bleiben unverändert.
Die passiven Zeit- und Ereignisprotokolle bleiben aktiv. Ein erneut langsamer
Einzelaufruf darf weiterhin fehlschlagen; er wird nicht durch eine verlängerte
Produkt-Lease als bestanden gewertet.

Diese Messung erklärt den konkreten d71-Lauf. Die frühere 938-Störung bei
Kommando 33 bleibt mangels damaliger Zeitdaten rückwirkend ungeklärt. Der neue
vollständige Zweibrowserlauf ist noch ausstehend; der 773-Prüfungs-Lauf ist
weiterhin ausdrücklich fehlgeschlagen.
