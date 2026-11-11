# Premium Mobile – QA und Nachweise

## Prüfstatus

Ausgangsstand ist Develop `10782185cf41f2013607ba47da0bbfcb737e89e2`.
Dieser Bericht trennt die tatsächlich ausgeführten Prüfungen von den noch
ausstehenden Integrationsprüfungen. Frühere Alpha-0.3-Ergebnisse sind keine
Freigabe eines neuen Commits.

Die endgültige Abnahme des jeweils aktuellen Heads wird im
[Prüfprotokoll von PR #28](https://github.com/Jagarex-lab/nachtsiegel-app/pull/28)
mit den zugehörigen GitHub-Läufen und Artefakten festgehalten. Die nachstehenden
Quellstände und Zahlen sind unveränderliche Iterationsbelege; ein späterer grüner
Lauf ändert weder ihre ursprüngliche Quelle noch das Ergebnis eines Fehlversuchs.

| Prüfung | Tatsächlicher Stand |
| --- | --- |
| Native Vorher-Aufnahmen | 9 echte Godot-Aufnahmen des Ausgangsstands erstellt; fünf Querformatgrößen, Inspektion sowie Menü/Starter/Deckbuilder im Hochformat |
| Browser-Vertragsprüfungen | 36 Node-Vertragsprüfungen bestanden, 0 Fehler, 0 übersprungen; Browser, öffentliche Dateiintegrität, PWA und Worker; keine Spielbarkeit allein daraus behauptet |
| Inaktive Release-Vorbereitung | 31 Python-Tests und 7 Node-HTTP-Testgruppen bestanden; aktiver Publisher und Guard byteidentisch |
| Unveränderter Kartenkatalog | 550 Definitionen, 110 je Zugehörigkeit, 357 Wesen/133 Impulse/60 Relikte; 0 Validierungsfehler/Warnungen |
| Illustrationsdateien | Vollständiger Manifest-/Prüfsummenlauf: 550 individuelle Dateien, 0 fehlende, 0 verwaiste; keine neue kommerzielle Rechtsfreigabe behauptet |
| Syntax der Browserharnesses | `node --check` bestanden |
| Vorhandene Alpha-02-Oberflächenregression | Nach Korrektur tatsächlicher 320-Pixel-Rotation und Textpalette: 4.435 native Godot-Prüfungen, 0 Fehler; Screenshots und Log unter `work/premium-mobile/shutdown-diagnostic/` |
| Neuer Export in Chromium/WebKit | Zwischenexport `6cd4e955`: Chromium 185 und WebKit 190 Prüfungen, je 17 echte Screenshots und fünf Größen, 0 Browser-/Godotfehler; kein endgültiger Nachweis der anschließend korrigierten schmalen Layouts |
| Vollständige KI-Partien/Replay/Neustart | Vorhandenes echtes Eingabeharness erhalten; End-to-End-Läufe werden zusätzlich zu den Layoutprüfungen ausgeführt und separat protokolliert |
| Physisches iPhone/Android | Nicht vorhanden; ausdrücklich offen |
| Veröffentlichung | Durch diesen Prüfauftrag nicht ausgelöst |

## Identität und ausgeführte Prüfungen

Der erneute vollständige native Premium-Lauf nach den drei UI-Korrekturen
bestand insgesamt **57.418 Assertions/Checks, 0 Fehler**: alle erforderlichen
nativen Suiten, drei Rahmenkonzepte, neun echte Hauptansichten und neun reale
2D-/2,5D-/3D-Vergleiche. Die Einzelzahlen sind keine Anzahl verschiedener Partien.
Der vollständig committed Laufzeitcode ist `a44ead71`; begleitende spätere
CI-/Dokumentationsänderungen werden erneut auf GitHub geprüft. Reproduzierbarer
Abschluss und Summen: `work/premium-mobile/final-native/summary.json`, vollständiges
Log `work/premium-mobile/final-native/gate.log`.


Der erste vollständige neue native Präsentationslauf auf lokalem `4fdcd4c`
bestand: 14.416 Rahmen-/Namensprüfungen, 7.434 Layoutprüfungen, 829 tatsächliche
Shell-Geometrieprüfungen, 22.897 Text-/Werteprüfungen, 2.816 räumliche
Geometrieprüfungen, 46 Sicherungs- und 197 Bibliotheksprüfungen. Hinzu kamen drei
tatsächliche Rahmenkonzepte, neun Vorher-/Nachher-Ansichten und neun räumliche
Vergleichsrenderings. Die vollständige Bildkettenprüfung zeichnete alle 550 Karten
in Hand, Bibliothek und Vollinspektion sowie alle 357 Wesen auf dem Feld;
**7.491 Prüfungen, 0 Fehler**. Diese Zahlen gehören zu diesem Lauf; spätere
zusätzliche Prüfungen werden nicht rückwirkend hinzugezählt.

Die erneute vollständige Bildkettenprüfung nach den Korrekturen bestand
**8.591 Prüfungen, 0 Fehler**: dieselben 550 Hand-/Bibliotheks-/Vollansichten und
357 Feldwesen, jetzt zusätzlich mit je 550 Prüfungen des tatsächlich zuletzt
gezeichneten Vollbilds und seiner sichtbaren Bindung. Dieser neue Lauf wird
getrennt vom früheren 7.491-Prüfungen-Lauf geführt.

Der lokal exportierte `6cd4e955` und GitHub-Head `567add86` besitzen denselben
vollständigen Git-Baum `6e3b502c5b42c61bcc8372abd9a0375efc06189e`.
Unterschiedliche Commit-IDs entstehen durch die kontrollierte Übertragung über
den verbundenen GitHub-Connector. Jeder spätere Kandidat benötigt eigene CI.
Die im PR angezeigten Läufe sind die maßgeblichen Nachweise des aktuellen Heads;
ein grüner Teillauf ist keine Freigabe des gesamten PRs. Es wird weder auf Develop
integriert noch veröffentlicht, solange die erforderlichen Prüfungen fehlen.

Der Zwischenexport bestand in Chromium 158 und WebKit 27.2. Die Ergebnisdateien
liegen unter `work/premium-mobile/browser-final-6cd/chromium-results.json` und
`work/premium-mobile/browser-webkit-scroll-6cd/webkit-results.json`. Beide prüfen
unter anderem sechs durch reale Befehle gezogene Handkarten, Karteninspektion,
Rotation, vollständige Modell-/RNG-Erhaltung und exaktes Resume nach Reload.
Chromium schaltete echtes Browser-Vollbild ein und aus; WebKit zeigte die
Safari-Installationshilfe. Diese 34 PNGs und 375 Prüfungen sind nach den späteren
320-Pixel-/Kontrastkorrekturen ausdrücklich **Zwischennachweise**, keine
vorgezogene finale Freigabe oder vollständige KI-Partie.

Zusätzlich tatsächlich ausgeführt:

- 16 zusätzliche Primäreingabeprüfungen: langsame Doppel-Taps, nächste bewusste Eingabe, optionale Pfadwahl, Replay und neuer Duellstart; 258 aktualisierte Bibliotheksprüfungen einschließlich lebender Rotation und verstecktem horizontalen Überlauf.
- 94 Eingabeprüfungen für abgebrochene Berührungen, echte Kartenaktionen,
  Mehrfachberührungen, Tastaturauswahl, Rotation und veraltete Eingabestempel.
- 609 vorhandene Vollbild-Lieferprüfungen, 51 Vorschauprüfungen und 18 neue
  Transport-/Wiederherstellungsprüfungen. Der neue Renderer-Beobachter hat
  sieben eigene Prüfungen und beobachtet nur bereits gezeichnete Pixel.
- 31 Python-Prüfungen des unveränderten Releaseschutzes und der inaktiven
  Ein-Klick-Vorbereitung; drei Python-PWA-Staging-Prüfungen.
- 47 Node-Prüfungen der Export-Staging-/Datenverträge nach Korrektur der
  Testfixture für die tatsächlich notwendige PWA-Staging-Datei.
- Bestehende Legacy-Differential-/Replay-Prüfung einschließlich 24 vollständiger
  Duelle mit 705 Befehlen; kein neuer Legacy-Regelpfad.
- Neue 848-Partien-Matrix mit 18 getrennten deterministischen Wiederholungen,
  sowie gepaarte Blockdeck-Prüfung mit 224 Partien und acht Kontrollen. Umfang,
  negative Gegenproben, exakte Quellen und Grenzen: [BALANCE.md](BALANCE.md).

Die Original-550-Kartendaten, beide produktiven Modelle, vier Starter und der
aktive Pages-Publisher bleiben unverändert. Die aktive Illustration umfasst
weiterhin 550 eindeutige Dateien. Die einzige Datenanpassung betrifft acht Kopien
im gemessenen Block-Referenzdeck, nicht die Kartenwerte oder Kampfregeln.

## Während der QA gefundene und behobene Fehler

**Abgebrochene Berührung wurde zur Auswahl:** Godots GUI-Signal konnte vor dem
ursprünglichen Touch-Cancel-Ereignis eintreffen. Handaktionen werden nun erst nach
der Eingabeverarbeitung mit unveränderlichem Press-Stempel, Modell-/Befehlsstand
und Kartenidentität bestätigt. Eine abgebrochene oder veraltete Eingabe spielt
keine Karte und öffnet keine unbeabsichtigte Inspektion. Keine zusätzliche
Zeitverzögerung oder erfundene Spielregel wird verwendet.

**Verspäteter Bildtransfer wurde dem falschen Bild zugeordnet:** Ein bereits
geplanter HTTP-Abschluss des wiederverwendeten Request-Knotens konnte einen neuen
Transfer abbrechen beziehungsweise seine Antwort als falsche Bytezahl ablehnen.
Der Fehler wurde zunächst mit zwei fehlgeschlagenen Gegenproben reproduziert.
Jeder Transfer besitzt jetzt einen eigenen Request-Knoten und eine geprüfte
Sequenz-/Bildidentität. Ein noch sichtbares, tatsächlich fehlgeschlagenes Bild
versucht nach der bestehenden 30-Sekunden-Frist erneut zu laden. Größen- und
Prüfsummenschutz bleiben vollständig erhalten. Die Vollinspektion prüft das
wirklich zuletzt gezeichnete Bild, nicht bloß einen Cacheeintrag. Details und
reproduzierbare Gegenprobe: [ART_TRANSFER_IDENTITY.md](../qa/ART_TRANSFER_IDENTITY.md).

**Prüfharness statt Produktfunktion:** Die erste Browserfassung erwartete den
Status `final` im Lieferzustand; dieser heißt dort korrekt `ready`. Die Prüfung
verlangt jetzt zusätzlich Vollauflösung, exakte Manifestmaße, sichtbare tatsächliche
Zeichnung und die passende Karten-ID. Das ist strenger als eine bloße Statuskorrektur.
Der erste WebKit-Lauf auf `6cd4e955` brach an Playwrights fehlender Mausradunterstützung im mobilen WebKit ab. Der korrigierte Prüfer verwendet eine protokollierte Canvas-Ziehgeste mit sicherer Startfläche; das ist keine Produkt-Scrollmutation. Frühe fehlgeschlagene Läufe bleiben als solche erhalten. Ein fehlgeschlagener
Download oder ein nicht ausgeführtes Szenario wird nicht als bestanden gezählt.

**Rotation der Bibliothek konnte Bedienelemente hinausschieben:** Der deaktivierte
horizontale Scrollmodus leitete die alte Mindestbreite des Kartengitters an den
Container zurück. Nach Querformat → 320-Pixel-Hochformat maß die Anpassung dadurch
immer wieder die zu breite Fläche. Die Kopfzeile war aus dem sichtbaren Bereich
geschoben; ein tatsächlicher Tap konnte die Machtauswahl nicht öffnen. Die neue
Regression mit derselben lebenden Bibliothek schlug vor der Korrektur in 37
Prüfungen fehl. Der unsichtbare, begrenzte horizontale Scrollmodus lässt den
Elterncontainer jetzt die reale Breite vorgeben; das angepasste Kartengitter darf
anschließend keinen horizontalen Überlauf besitzen. Karten und Deck bleiben gleich.

**Materialfarbe war als kleiner Text zu dunkel:** Die festgelegte Amethystfarbe
`#9867BE` bleibt am Rahmen erhalten. Für kleine Machtbeschriftungen wird separat
`#B58BD8` eingesetzt. Die Textpalette wird gegen alle drei tatsächlich verwendeten
Informationsflächen mit unverändert mindestens 4,5:1 geprüft. Es wird nicht die
Materialfarbe aufgehellt oder das Kontrastziel abgesenkt.

**Langsamer Frame konnte zwei primäre Aktionen annehmen:** Ein tatsächlicher
Canvas-Eingabetest bestätigte Nachziehen und Zugende im selben Prozessframe, wenn
zwischen zwei bereits anstehenden Taps mehr als 180 ms Rechenzeit vergingen.
Der zusätzliche Frame-Stempel verhindert diesen zweiten veralteten Befehl; die
vorhandene monotone 180-ms-Sperre bleibt erhalten. Eine neue bewusste Eingabe im
nächsten Frame nach Ablauf der Sperre muss weiterhin funktionieren. Dies betrifft
nur UI-Eingaben und ändert keine zugelassenen Engine-Befehle oder Zugphasen.

## CI-Infrastruktur und exakter Kandidat

Die ersten GitHub-Läufe von `567add86` enthalten sowohl den tatsächlichen
320-Pixel-Oberflächenfehler als auch gesonderte Fehler vor Testbeginn durch
Ubuntu-Mirror-DNS. Sie bleiben fehlgeschlagene Läufe. Der eng begrenzte
[Abhängigkeitsinstaller](CI_DEPENDENCIES.md) besitzt 17 eigene Gegenproben einschließlich eines tatsächlichen APT-Mirror-Parserlaufs,
erhält Playwrights vollständige Abhängigkeits-/Hostprüfung und darf nach einem
bestätigten Paketfehler einmal offizielle Ubuntu-HTTPS-Mirrors verwenden.
Scheitert auch das, bleibt CI fehlgeschlagen. Temporäre Konfiguration wird
wiederhergestellt; keine Repository-Sicherheitseinstellung wird geändert.

Die unabhängige Nachprüfung deckte außerdem ein Start-Rennen in einer neuen
Installer-Testfixture auf: Ihre 0,2-Sekunden-Frist konnte unter Last bereits vor
dem Schreiben der Kindprozess-ID enden (14 bestanden, ein Testfehler). Jetzt
meldet der tatsächliche Test-Kindprozess seine Bereitschaft nach Installation
des Signalhandlers. Ein auf zehn Sekunden begrenzter Test-Handshake wartet auf
diese Meldung; anschließend bleibt die ursprüngliche Produktions-Timeout- und
Prozessgruppenprüfung unverändert streng. Alle 15 Verträge bestanden danach
zweimal unter Browserlast, ebenso eine zusätzliche gezielte Wiederholung.
Vorher-/Nachher-Logs liegen unter `work/premium-mobile/independent-review/`.
Geändert wurde ausschließlich die Testfixture, nicht der Installer oder Spielcode.

Der Main-Nativjob erhält für die zusätzlichen vollständigen Bildrenderings und
neun räumlichen Vergleichsläufe 20 Minuten zusätzliches Gesamtbudget (45 → 65).
Die einzelnen 600-Sekunden-Testgrenzen und die Anforderungen bleiben erhalten. Der zusätzliche Premium-Browserjob erhält für seine kombinierte Layout-/Vollpartie-/Replay-Prüfung 45 statt 25 Minuten Gesamtbudget; alle bestehenden Aktions- und Fehlergrenzen bleiben erhalten. Die bisherigen Main-/Alpha-Browserjobs erhalten für ihre unveränderten vollständigen Profile jeweils 75 Minuten Gesamtbudget; insbesondere werden die drei Chromium-Partien nicht verkürzt oder entfernt. Diese Budgets berücksichtigen die gemessene Emulationslaufzeit, nicht angenommene physische Gerätegeschwindigkeit.
Es werden keine Tests deaktiviert oder Fehler in Erfolg umgewandelt. Die
abschließenden GitHub-Prüfungen müssen den tatsächlich aktuellen PR-Head testen;
die älteren Quellenbelege dieses Berichts dienen der nachvollziehbaren Iteration.

Zwei weitere Integrationsfehler wurden am tatsächlichen CI-Lauf erkannt:
`production_desktop_hand.gd` hatte im neuen Fixture-Untertyp zwei Tabulatoren,
während die bestehende Testdatei Leerzeichen verwendet. Die Datei scheiterte
bereits beim Parsen. Die unveränderten Größenanforderungen werden tatsächlich
erfüllt (115,48 Pixel kleine Öffnungskarten; 170,91 Pixel auf Desktop). Die
Einrückung ist korrigiert; alle 32 geänderten GDScripts bestehen jetzt eine
explizite Godot-`--check-only`-Prüfung. Der Alpha-Artefaktupload enthält nun auch
die vorhandenen Produktions-Testlogs, damit solche Fehler direkt einsehbar sind.

Der neue Ubuntu-Mirror-Fallback enthielt ein falsches Leerzeichen vor
`priority:1`; APT benötigt dort einen Tabulator. Sobald DNS wieder antwortete,
war dadurch ein tatsächlicher HTTP-400-Fehler sichtbar. Ein zusätzlicher Test
mit dem echten APT-Parser und einem isolierten lokalen HTTP-Server reproduziert
den alten fehlerhaften Pfad und prüft die korrekt getrennten Pfade. Der erwartete
Fehler für ein nicht vorhandenes signiertes Repository bleibt dabei ein Fehler;
die Prüfung schaltet weder Paket- noch Signaturkontrollen ab. Dies bestätigt das
Mirrorformat, nicht bereits die Erreichbarkeit der echten Ubuntu-Server.

## Abschließende Hinweistexte und vollständige Syntaxprüfung

Die letzte Sichtung korrigiert sechs tatsächliche Textprobleme in der Shell:
Fortsetzen wird nicht mehr pauschal verneint und Speicherung nicht garantiert;
Speicherfehler können mehrere ungesicherte Spielzüge betreffen. Der KI-Modus
benötigt kein Konto, während vorhandene Online-Anmeldung und Gold-Booster nicht
mehr durch „Keine Konten oder Käufe“ verneint werden. Echtgeldkäufe bleiben
inaktiv. Ergebnisfenster verwenden klare Spielersprache und einen neutralen
Protokollhinweis statt einer unbelegten „Kontrollentscheidung“. Befehle,
Spielregeln, Schaltflächen und Reaktionstiming bleiben unverändert.

Die zusätzliche Einzelprüfung aller 214 GDScripts fand außerdem einen bereits im
Ausgangsstand vorhandenen Typinferenzfehler in `scripts/ritual_board.gd`. Die
aktuell nicht referenzierte Archivkomponente war weiterhin im Paket enthalten.
Eine explizite `Vector2`-Deklaration behebt den Parserfehler ohne Änderung der
Berechnung. Der Fehler wurde an einer Kopie des ursprünglichen Git-Blobs
reproduziert; die korrigierte Datei kompiliert. Alle 214 damaligen GDScripts kompilieren nach der Korrektur; 213 sind sauber. Bei `authority_model.gd` bleiben zwei Catalog-GDScriptressourcen beim Prozessende erhalten. Das ist auch im Ausgangsstand und bei einer tatsächlichen Öffnungssequenz nachgewiesen, also kein rein compilerbezogener Hinweis. 24 erstellte/freigegebene Modelle bestehen 228 Prüfungen mit unverändert 1.687 Objekten, 174 Ressourcen und 0 verwaisten Knoten in jeder Probe. Es wurde kein fortschreitender Modellverlust beobachtet. Diese bestehende begrenzte Shutdown-Retention bleibt als bekannte Einschränkung offen; die Engine wurde dafür nicht verändert.

Die zwei vollständigen lokalen Browserpartien gehören weiterhin ausdrücklich
zum Export `8bfb5e2b`; sie werden wegen dieser letzten Hinweistexte und der
Archivtypisierung nicht in einen anderen Quellstand umbenannt. Der anschließende
GitHub-Lauf muss den neuen exakten Kandidaten erneut exportieren und prüfen.

## Tatsächliche WebKit-Scrollfehler und Korrektur

Die vollständige CI auf `5ed407c` bestand alle nativen Prüfungen und fünf
separate System-Workflows. Ihre drei Browserfehler bleiben ausdrücklich Fehler:
Eine schnelle Wischfolge öffnete vor dem abschließenden Tap eine falsche
Sammlungskarte; in kurzen Einstellungen oszillierte der Prüfer mit zu großen
festen Wischstrecken über das gesuchte Ziel. Zwei neue WebKit-Kontexte des alten
Exports reproduzierten die falsche Inspektion **nach Pan 2 und vor jedem Tap**.
Ein dritter Kontext erreichte wegen Starttimeout keinen vergleichbaren Zustand
und wird nicht als bestanden gezählt. Rohdaten/Prüfsummen:
`work/premium-mobile/scroll-diagnostic-8bfb/receipt.json`.

Die neue Oberfläche bestätigt Aktionen in Scrollbereichen erst nach dem
ursprünglichen Eingabepaket. Zeiger-/Tastaturabsicht, Bewegung, Abbruch,
Scrollposition, Fokus und Seiten-/Fensteridentität müssen stimmen. Jede Absicht
wird einmalig verbraucht. Karten und Schaltflächen lassen echte Wischbewegungen
an ihren Scrollbereich weiterreichen; eine Karte mit `MOUSE_FILTER_STOP` hatte
diesen Weg zuvor blockiert. Es gibt keine zusätzliche Zeitverzögerung und keinen
Test- oder Programmsignal-Bypass. Die bisherigen Handkarten bleiben unter ihrem
getrennten Eingabeschutz.

Der neue Gestentest besteht **46 Prüfungen, 0 Fehler**, einschließlich normaler
Touch-/Maus-Taps, kleiner Fingerbewegung, echter Bewegung auf Karten,
mehrerer Finger, Abbruch, Tastatur, doppelter GUI-Ereignisse und frischer
nachfolgender Eingaben. Die Hand-/Primär-/Bibliotheks-/Selektorprüfungen bleiben
erhalten. Fünf bisherige Fixture-Treiber verwenden jetzt tatsächliche
Input-Ereignisse statt direkten `pressed.emit()`-Aufrufen. Die native
Produktions-UI besteht 5.507 Prüfungen. Die Anwendungsintegration besteht
37 Prüfungen; sie wartet auf die tatsächlich aktive Kampagnenmusik und den
natürlichen Wechsel zurück zur Menümusik (beobachtet 1.891 ms) statt auf eine
unbelegte feste Zahl an Bildern. Keine Audioimplementierung wurde geändert.

Beide Browserprüfer verwenden passende Reststrecken statt fixer 147-Pixel-Pans
und prüfen nach jeder Geste Seiten-/Modalidentität. Die schnelle zweifache
Wischfolge ist eine eigene tatsächliche Browserregression. Ein unerwarteter
Inspector wird sofort als Fehler gemeldet; es wird nicht durch ihn hindurch
getippt oder eine andere Karte als vermeintlich bestanden ausgewählt. Alle
44-Pixel-/Sichtbarkeitsanforderungen bleiben bestehen.

Der anschließende neue Webexport und seine frische vollständige CI sind für die
endgültige Abnahme erforderlich. Frühere 375 lokale Checks und zwei vollständige
Partien bleiben korrekt an `8bfb5e2b` gebunden und werden nicht umetikettiert.

## Nachgewiesene Ausgangsprobleme

Die unveränderte Anwendung wurde mit einer isolierten, reproduzierbaren
Präsentationsszene tatsächlich durch Godot 4.6.3/OpenGL Compatibility gerendert.
Bei 844×390 sind sechs Handkarten jeweils **133×80 Pixel** groß; das Verhältnis
von 1,66 macht aus dem vorgesehenen Kartenformat 63:88 eine breite Textleiste.
Ein eigener Feldplatz misst **161×88 Pixel**, verwendet in der bisherigen
Kompaktansicht aber nur einen schmalen Illustrationsbereich neben dem Text.
Die dauerhaft sichtbaren Schaltflächen Protokoll und Neu sowie mehrzeilige
Heldenbeschriftungen verbrauchen wertvolle Höhe. Das ist in den tatsächlichen
Aufnahmen sichtbar und kein aus CSS abgeleiteter Verdacht.

Die Baseline liegt unter `work/premium-mobile/before/`:

- `battle-844x390.png`, `battle-852x393.png`, `battle-932x430.png`,
  `battle-1024x768.png`, `battle-1600x900.png`
- `inspection-844x390.png`
- `menu-390x844.png`, `starters-390x844.png`, `deckbuilder-390x844.png`
- `manifest.json` mit Quellcommit, Karten- und Renderer-Prüfsummen,
  allen 16 festgelegten Karten-IDs, vollständigen arrangierten Zuständen und
  tatsächlich gemessenen Control-Rechtecken.

Die Szene arrangiert bewusst volle Felder und sechs Handkarten. Sie ist ein
visueller Vergleich und **keine regelkonform ausgespielte Partie**. Für die
Gameplayprüfung werden ausschließlich echte Browser-Eingaben verwendet.
Ihre lokale `PresentationShell` deaktiviert ausschließlich für diese Szene die
automatische Duell-Sicherung. Ein arrangierter Zustand darf nicht als scheinbar
gültiges Replayjournal in einem Spielstand landen. Die Aufnahme verwendet einen
eigenen isolierten XDG-Datenpfad; der Produktcode erhält keinen Testmutator.

Die Bilddateiprüfung wurde im sparse QA-Checkout zunächst zweimal abgebrochen,
weil historische Dokumentationsbelege (`source-references/` beziehungsweise
`edit-inputs.json`) nicht ausgecheckt waren. Die unveränderten Belege wurden
gezielt bereitgestellt; der anschließende vollständige Lauf bestand. Die ersten
Logs bleiben erhalten. Dies war kein fehlendes Laufzeitbild und wurde nicht als
bestandener Teiltest gezählt.

## Unabhängige visuelle Gegenprüfung während der Umsetzung

### Gepackter CI-Eingabetreiber und kinetische Testgesten

Auf GitHub-Kandidat `5dcf82c` bestanden die neue native Premium-Suite und beide
Premium-Browserjobs einschließlich der schnellen Zwei-Pan-Regression. Die drei
nativen Exportjobs scheiterten jedoch an ihrem gemeinsamen älteren Menütreiber.
Dieser sendete direkt `pressed`, ohne ursprüngliche Eingabe. Die gezielte
gepackte Gegenprobe zeigte zusätzlich den tatsächlichen Headless-Standardviewport
von nur64×64: Das Startziel lag bei y80 außerhalb des Clips. Der ausschließlich
für QA konfigurierte1280×720-Viewport und echte Touch-Ereignisse beheben beides;
Details und die begrenzte lokale PCK-Provenienz stehen im separaten Abschnitt
zum nativen Exporttreiber. Die vollständigen offiziellen nativen Exporte bleiben
ein erforderlicher frischer CI-Nachweis.

Der allgemeine WebKit-Lauf erreichte nach vollständigen iPhone-/iPhone-wide-
Partien den besonders niedrigen Settings-Clip `[48,50,748,245]`. Ein adaptiver
118px-Drag brachte den44px-Schalter zunächst von y351 nach y55; anschließend
rollte er bis y−389 weiter. Die Gegenbewegung überschoss wieder bis y351.
Die adaptive Strecke allein verhinderte diese tatsächliche kinetische
Oszillation noch nicht. Seite, Dialog und Modell blieben dabei unverändert.
Diese fehlgeschlagenen5dcf-Läufe werden nicht als bestanden gezählt.

Der normale Browser-Testhelfer hält deshalb den ursprünglichen Zeiger vor dem
Loslassen unbewegt, bis vier **neu veröffentlichte** QA-Beobachtungen mindestens
250ms ruhige Geometrie und denselben Kontext bestätigen. Die Wartezeit ist auf
zehn Sekunden begrenzt; Loslassen und Handle-Freigabe erfolgen auch bei Fehlern.
Das entspricht dem tatsächlichen stationären Geschwindigkeitssampling im
[Godot4.6.3-ScrollContainer](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/gui/scroll_container.cpp).
Die vorhandenen44px-, Kontext- und Nachlaufprüfungen bleiben erhalten. Die beiden
schnellen Produkt-Regressionsgesten erhalten ausdrücklich **keinen** Ruheabschnitt
und lassen weiterhin sofort los. Kein Scrolloffset wird per Script gesetzt,
keine Spielphysik verändert und keine Testgröße oder Partie entfernt.

18 Node-Vertragsgruppen bestehen, einschließlich der realen CI-Positionsfolge,
staler Beobachtungen, fehlender Ruhezeit, Kontextwechsel und Handle-Fehler.
Die tatsächlichen Browserprotokolle und die frische Gesamt-CI des jeweils
benannten Kandidaten liefern den zusätzlichen Ausführungsnachweis; diese
Beschreibung ist keine Veröffentlichungsgenehmigung.

Die erste tatsächlich gerenderte Rahmenfassung ließ Seltenheit bei 84×117 Pixeln
weiter überwiegend über kleine Diamanten und feine Kanten erkennen. Diese
Darstellung wurde nicht als ausreichender Abschluss gewertet. Nach der Rückmeldung
entstanden größere epische Kristallgruppen und eine breite legendäre Faltenkrone
mit seitlichen Scharnieren innerhalb der gemeinsamen Kontur. Die zweite echte
Godot-Nahaufnahme zeigt vier Seltenheiten mit identischem Motiv sowohl in
Originalgröße als auch bei 2,5-facher Godot-Zeichenskalierung; sie ist ausdrücklich
eine Rahmenstudie und verändert keine produktiven Kartendaten.

Die kleinen Seltenheitsstufen sind dadurch strukturell unterscheidbar, während
Machtfarben und Illustration sichtbar bleiben. Die lesbare Vollinspektion bleibt
für lange Namen und vollständige Fähigkeiten notwendig. Diese Sichtung von
Arbeitsbaum-Aufnahmen ersetzt nicht die abschließenden Screenshots des späteren
exakten Integrationscommits.

## Reproduzierbare Befehle

```sh
bash tools/test_premium.sh

# Tatsächliche Godot-Präsentation, identischer Zustand vor/nach Änderung:
XDG_DATA_HOME="$PWD/work/premium-mobile/xdg/data" \
XDG_CONFIG_HOME="$PWD/work/premium-mobile/xdg/config" \
XDG_CACHE_HOME="$PWD/work/premium-mobile/xdg/cache" \
DISPLAY=:99 LP_NUM_THREADS=1 godot --path . --audio-driver Dummy \
  --script tools/premium/render_arena_qa.gd \
  -- --output=res://work/premium-mobile/after

# Tatsächlicher Webexport; EXPECTED_COMMIT muss dessen exakter Commit sein.
EXPECTED_COMMIT=<40-stelliger-Kandidatencommit> \
GAME_URL=http://127.0.0.1:8893/ QA_ENGINES=chromium,webkit \
  node tools/premium/browser_qa.cjs

# Vollständige mobile Partien, Aktionen, generische Relikte, Replay, Neustart:
EXPECTED_COMMIT=<derselbe-Kandidatencommit> \
GAME_URL=http://127.0.0.1:8893/ QA_ENGINES=chromium QA_PROFILES=android \
  node tools/alpha_browser_qa.cjs
EXPECTED_COMMIT=<derselbe-Kandidatencommit> \
GAME_URL=http://127.0.0.1:8893/ QA_ENGINES=webkit QA_PROFILES=iphone \
  node tools/alpha_browser_qa.cjs
```

Die vorhandenen Engine-, Karten-, Legacy-, Replay-, Kampagnen-, Economy-, Audio-,
Online- und Release-Safety-Suiten bleiben zusätzlich erforderlich. Keine davon
wird durch die neuen Geometrieprüfungen ersetzt oder abgeschaltet.

## Was die Browserprüfung belegt

`tools/premium/browser_qa.cjs` startet die tatsächliche exportierte Anwendung,
prüft `build-info.json` gegen den ausdrücklich angegebenen Commit und verwendet
nur echte Canvas-Taps und Browser-Zieheingaben. Chromium verwendet für Wischbewegungen CDP-Touchereignisse; Mobile-WebKit stellt im verfügbaren Werkzeug kein kontinuierliches Touch-Move bereit und verwendet deshalb vertrauenswürdige Browser-Zeigerereignisse über Godots bestehende Touch-Emulation. Diese Einschränkung wird pro Geste protokolliert und nicht als physischer iOS-Wischtest ausgegeben. `window.orafoldQA` dient
ausschließlich als lesender Beobachtungskanal. Es gibt keine Zustandsinjektion,
keinen erzwungenen Sieg und keine JavaScript-Aufrufe produktiver Spielaktionen.

Die Prüfung umfasst:

- reale Sammlung mit 550 IDs, Karteninspektion mit vollem Namen und finaler
  Illustration, Deckspeicherung und vier vorhandene Starterquellen;
- drei vollständige Hoch-/Querformatwechsel während des Mulligans mit
  Vergleich des vollständigen Modellzustands und der Befehlsanzahl;
- sechs Handkarten, ausschließlich durch tatsächliche Nachzieh-/Zugbefehle;
- 844×390, 852×393, 932×430, 1024×768 und 1600×900 im selben laufenden Duell;
- zehn getrennte, geordnete Pfad-Touchflächen von mindestens 44 CSS-Pixeln;
- sichtbare aufrechte Handkarten mit eigenen, nicht verdeckten Touchflächen;
- final gebundene Illustrationen aller sichtbaren Karten, richtige Auflösung,
  echte Rendererrollen, Rahmenvariante und Seltenheit;
- tatsächlich passende vollständige Handkartennamen und sichtbare
  Spielbarkeitszustände, die mit den legalen Aktionen des Modells übereinstimmen;
- Illustration innerhalb der Kartenkontur und mindestens ein Viertel der
  kompakten Darstellung als tatsächlich sichtbare Bildfläche;
- vollständige Kartendetails in allen fünf Größen, sekundäres Kampfprotokoll,
  unveränderten Modellzustand beim Öffnen und Schließen;
- Querformat-Reload, sichtbare Wiederaufnahme und Replay-geprüfte Wiederherstellung
  des vollständigen laufenden Duells;
- tatsächliche Web-App-Fähigkeiten und erreichbare Installationshilfe;
- PNGs mit Prüfsummen sowie Startup-/Eingabe-/Ressourcen-Messwerte und Fehlerlogs.

## Messgrenzen

Die verfügbare Umgebung rendert auf Linux mit Mesa llvmpipe und begrenzter CPU.
Startup und Touch-zu-UI-Messungen enthalten Test-Polling und Host-Scheduling.
Chromiums JS-Heap ist nicht der gesamte WebAssembly-, GPU- oder Gerätespeicher.
Die Werte dürfen weder als iPhone-Leistungszertifizierung noch als physischer
Safari-/Android-Test bezeichnet werden. WebKit-Emulation ergänzt die Abdeckung;
die echte Geräteabnahme bleibt eine eigenständige offene Aufgabe.

## Korrektur der exportierten Native-QA-Eingaben

Die nachfolgende CI meldete in Linux-/Windows- und Audio-Native-QA dieselben vier
Menüfehler. `scripts/qa/production_native_smoke.gd` verwendete noch
`control.pressed.emit()` ohne ursprüngliches Zeigerereignis. Der neue Schutz für
Scrollgesten lehnte diese künstlichen Aktivierungen korrekt ab. Der vollständig
berechnete KI-Kampf bestand bereits; die vier Menübehauptungen waren nicht belegt.

Der QA-Einstieg verwendet jetzt selbst enthaltene `InputEventScreenTouch`-Press-/
Release-Eingaben auf tatsächlich geclippten Flächen von mindestens 44 Pixeln und
wartet begrenzt auf das erwartete Seitenziel. Ein Verweis auf `tests/` wurde
vermieden, da diese Dateien aus den nativen Paketen ausgeschlossen sind.
Zusätzlich zeigte die Paketdiagnose, dass der headless Native-Displayserver das
Rootfenster mit **64×64** startet. Der QA-Einstieg richtet deshalb ausdrücklich
sein Desktop-Prüfprofil **1280×720** ein. Die Sichtbarkeitsprüfung bleibt bestehen;
Produktauflösung, Benutzeroberfläche und Eingabeschutz wurden nicht geändert.

Der lokale kontrollierte Paketvergleich reproduzierte zunächst **29 Assertions,
4 Fehler**. Mit den korrigierten QA-Eingaben und dem eingerichteten Prüfviewport
bestanden **29 Assertions, 0 Fehler**; alle bisherigen Prüfungen bleiben erhalten.
Spielen öffnete die Deckauswahl, Sammlung, Deckbuilder und Einstellungen ihre
jeweiligen tatsächlichen Seiten. Das eine Ergebnisdokument protokolliert die vier
Touchflächen: 520×48 beziehungsweise 256×44 Pixel. Der vollständige echte
KI-Modellkampf endete in beiden Paketen unverändert in Runde 25 mit Helden-Sieg
und demselben Katalogfingerprint. Kein Gewinner wurde eingesetzt.

**Prüfgrenze:** Dieser fokussierte Daten-PCK wurde aus einem isolierten QA-Projekt
mit echtem `native_smoke_qa`-Exportmerkmal erzeugt und aus einem leeren
Arbeitsverzeichnis mit Godot 4.6.3 ausgeführt. Die Laufzeit war der Editor-Build;
Original-Kartenbilder wurden wegen des lokalen Speicherlimits aus diesem
zusätzlichen PCK ausgeschlossen. Das ist kein Ersatz für die erneuten offiziellen
Linux-/Windows-Template-Läufe, Android-Paketprüfungen oder vollständige native
Illustrationsprüfungen der CI. Keine physische Geräteprüfung wird behauptet.

Rohprotokolle, Paketprüfsummen, Eingabeflächen und die Negativdiagnose liegen unter
`work/premium-mobile/native-export-input/`. Ein erster reiner Eingabetreiber-Versuch
scheiterte noch an dem nachgewiesenen 64×64-Fenster und bleibt ausdrücklich als
fehlgeschlagener Zwischenlauf erhalten. Eine Diagnose las nach erfolgreicher
Navigation einen inzwischen freigegebenen alten Control und brach deshalb ab;
dies war ein Fehler dieser Diagnose, kein nachgewiesener Produktabsturz.

## Audio-Browser: frische PCM-Blöcke statt momentaner Analysatorprobe

Die unveränderte Audio-Laufzeit meldete in den neuen CI-Läufen zwei fehlgeschlagene
positive Bereitschaftsprüfungen. Im PR-Audiojob `130758059381` wartete die Prüfung
nach dem Schließen des Pausenmenüs zehn Sekunden lang auf einen einzelnen
`AnalyserNode`-RMS-Wert. Dessen abgefragter Wert blieb null. Das unabhängig auf dem
Audiothread beobachtete Signal desselben Fehlerdokuments enthielt nach dem zuvor
protokollierten Pausen-Endpunkt dagegen **244 frische PCM-Blöcke**, davon **122
positive**, über **10,87 Sekunden**. Generation, tatsächlicher AudioContext und
Routing blieben gültig; die Musik war entpaust und ihr Abspielstand schritt voran.
Der Push-Audiojob `130758182755` scheiterte an derselben momentanen Prüfung bereits
nach der Kampferöffnung: In den letzten drei Sekunden seines Fehlerdokuments
liegen 61 tatsächliche PCM-Blöcke mit 29 positiven über 2,65 Sekunden, obwohl die
abgefragte Analysatorprobe null war. Diese Diagnose macht beide fehlgeschlagenen
CI-Läufe ausdrücklich **nicht** nachträglich erfolgreich.

Der reine Browser-Test verwendet für alle sieben positiven Musik-Bereitschafts-
stellen jetzt `tests/audio/pcm_readiness.cjs`. Vor der tatsächlichen Aktion wird
der Audiozeit-Endpunkt festgehalten; die Prüfung verlangt zusätzlich Daten nach
dem Abschluss der Aktion. Nur neue Audiothread-Blöcke der aktuellen Generation,
nach deren tatsächlicher Routing-Epoche und innerhalb der aktuellen Audiozeit
zählen. Mindestens sechs positive Blöcke müssen eine volle Sekunde überdecken.
Die Laufzeit muss zugleich aktive, freigegebene, ungemutete Musik ohne pausierten
Mixer oder laufende kurze Effektstimmen melden. Die erste tatsächlich beobachtete
Phase ohne hörbare Effektstimmen setzt einen weiteren frischen Zeit-Endpunkt. Nur PCM
nach diesem Endpunkt zählt; neue hörbare Effektstimmen oder eine Pause setzen ihn zurück.
Dadurch genügt auch ein auf einem überlasteten Testhost zeitlich gestreckter
UI-Klick nicht als Musiknachweis. Ein alter Peak, ein früheres
Öffnungsgeräusch oder bereits vor der Aktion beobachtete PCM-Blöcke genügen nicht.
Die bisherigen Zeitgrenzen von zehn beziehungsweise fünfzehn Sekunden bleiben
erhalten. Die nachfolgenden vollständigen PCM-Aufnahmen mit mindestens einer
Sekunde positiver Wiedergabe und sämtliche Stille-/Mute-/Pause-Gegenprüfungen
bleiben unverändert bestehen. Produkt-Audiocode und Audiodateien werden dadurch
nicht verändert.

Vierzehn Node-Verträge prüfen die tatsächliche archivierte PR-Fehlerprobe sowie
stille Ausgabe, alte Generationen, alte Epochen, zukünftige/nicht endliche Werte,
einen einzelnen UI-Klick, vor Aktionsabschluss liegende Signale, Muting/Pausen,
fehlende Musik, Effektstimmen, fehlendes Routing und Fehler des unabhängigen
Beobachters. Das kleine Referenzdokument nennt Originaljob, Artefakt und SHA256
des unveränderten Rohberichts. Es ist eine statische Testeingabe und keine neue
Audio-Abnahme. Die Verträge laufen verpflichtend im bestehenden Audio-Testskript.
Der neue vollständige reale Browserlauf wird separat protokolliert; die
abschließende CI des neuen Quellstands bleibt zusätzlich erforderlich.

Der erste zusätzliche lokale Gesamtlauf brach vor dem vollständigen Abschluss
an einer weiteren ursprünglichen Testannahme ab: Der Audio-Eingabehelfer verlangte
einen pauschalen Abstand von zehn Pixeln zur Fensterunterkante. Die neue Arena
verwendet tatsächlich acht Pixel; dadurch behandelte der Helfer einen vollständig
sichtbaren primären Button als scrollbedürftig. Sein paralleles unverändertes
30-Sekunden-Fenster für eine echte Mausfreigabe konnte während solcher unnötigen
Scrollversuche verfallen. Die zunächst noch unbeobachtete Promise-Ablehnung
beendete Node vor der strukturierten Fehlerausgabe. Dieser Lauf ist als Fehler
unter `work/premium-mobile/audio-pcm/chromium-first-capture-failure.log` erhalten.

Der Test entscheidet jetzt über die tatsächlichen beobachteten Vorfahren-Clips,
das vollständige Buttonrechteck und das Browserfenster. Beide Achsen müssen
wirklich mindestens 44 Pixel groß sein; teilweise verdeckte Buttons werden nicht
angetippt. Es gibt keine erfundenen 55-/10-Pixel-Grenzen. Ein echtes Mausrad wird
nur für vertikal geclippte Flächen verwendet; jede endgültige Touchfläche wird mit
Phase und Disabled-Status protokolliert. Drei zusätzliche Node-Verträge prüfen
792 Pixel Unterkante bei 800 Pixel Fensterhöhe als gültigen Fall, echte
Vorfahren-/Fenster-Clips sowie fehlende, nicht endliche oder zu kleine Flächen.
Zusammen mit den vierzehn PCM-Verträgen bestehen **17/17** Tests. Beide parallel
laufenden Mess-/Eingabe-Promises erhalten unmittelbar ihre Fehlerhandler; die
ursprünglichen Fehler und sämtliche Zeitgrenzen bleiben erhalten. Ein neuer
reeller Gesamtlauf und anschließend neue CI sind weiterhin erforderlich.

Der stille Messbeginn bleibt bei mindestens sechs frischen, aufeinanderfolgenden
Nullblöcken über mindestens 0,2 Sekunden und derselben Zehn-Sekunden-Frist. Die
frühere feste Grenze von acht Meldungen war bei 96 kHz/Stereo mathematisch zu
kurz: Sie enthält höchstens 0,149 Sekunden. Statt dieser festen Zeilenanzahl wird
nun der begrenzte aufeinanderfolgende stille Endabschnitt der vorhandenen
512-Meldungen-Historie geprüft; ein positiver oder ungültiger Block unterbricht
ihn. Die Gegenproben für 48/96 kHz, einen positiven Endimpuls und alte/futuristische
Meldungen bestehen. Dies erklärt ausdrücklich nicht den lokalen Fehler mit
44,1 kHz. Der zweite lokale Gesamtlauf scheiterte an diesem bisherigen stillen
Messbeginn; sein vollständiger strukturierter Fehlerbericht bleibt erhalten.
Der folgende unveränderte Gesamtablauf ergänzt deshalb passive Zustands- und
PCM-Zwischenbeobachtungen innerhalb derselben Frist, einschließlich Spielerseite,
Phase, tatsächlichem Enabled-Status und Effektstimmen. Es wird kein Audio direkt
gestoppt, kein Pegel als Fehlerumgehung verändert und kein Gegnerzug übersprungen.

Der dritte lokale Gesamtlauf bestätigte erstmals die Zwischenbeobachtungen:
Nach der Eröffnung war tatsächlich der Held am Zug, die Phase war Nachziehen und
der echte primäre Button war freigegeben. Vier noch aktive endliche
Eröffnungs-Effektstimmen lagen neben einer tatsächlich gemessenen stillen Lücke.
Sechs aufeinanderfolgende Nullblöcke über 0,232 Sekunden erfüllten den bestehenden
statischen Mindestvertrag; der echte bestätigte Nachzieh-Sound bestand danach.
Dies beweist nicht die Ursache des vorherigen Zehn-Sekunden-Timeouts, dessen
Zwischenzustand nicht erfasst wurde. Der neue stille Endabschnitt entfernt eine
zufällige zusätzliche Zeilenanforderung, ohne sechs Blöcke oder 0,2 Sekunden zu
unterschreiten.

Später brach dieser dritte Lauf an der strengeren Musikisolation nach dem Reload
ab: Nach zehn Sekunden waren noch zwei endliche Eröffnungsstimmen aktiv; die
Musik spielte und hatte im Software-Renderer erst rund 1,34 Sekunden
Abspielzeit erreicht. Die frische PCM-Prüfung lehnte diese gemischte Ausgabe
korrekt als noch nicht isolierten Musiknachweis ab. Der vollständige Fehlerbericht
liegt unter `work/premium-mobile/audio-pcm/chromium-third-readiness-failure.json`.

Deshalb richtet der reine Browser-Test nach dieser Eröffnung seine isolierte
Musik-Messvoraussetzung durch normale, echte Menüeingaben ein. Er wartet zuerst
innerhalb der bestehenden Aktionsfrist auf den tatsächlichen eigenen Zug und
einen freigegebenen primären Button. Dann öffnet er das reguläre Pausenmenü,
prüft echte PCM-Stille und schließt es wieder. Die bestehenden normalen
Produktregeln verwerfen dabei vorübergehende Effektstimmen. Der Test ruft keinen
Mixer-Stopp auf und ändert keine Lautstärke. Er vergleicht vor und nach diesen
Eingaben das vollständige beobachtete Kampf-Snapshot, die Befehlsanzahl und alle
Audioeinstellungen. Ein eigener RNG-Zustandskanal ist in diesem Browserbeobachter
nicht verfügbar und wird hier nicht behauptet. Erst anschließend beginnt die
unveränderte Zehn-Sekunden-Prüfung neuer isolierter Musikblöcke. Alle späteren
ursprünglichen Pause-/Resume-, Gain-, Mute-, Reload- und Speicherfehlerprüfungen
bleiben bestehen. Die zusätzlichen Menüeingaben sind eine ausdrücklich
protokollierte Messvorbereitung, kein zusätzlicher bestandener Kampf und kein
Eingriff in den Produktcode.

## Audio: lokale Messgrenzen und nächster CI-Nachweis

Auch der vierte vollständige lokale Lauf bleibt fehlgeschlagen. Die zusätzliche
reale Menüvorbereitung bestand: Befehlsanzahl 3 vor/nach, identische vollständige
beobachtete Kampf-Snapshots, unveränderte Audioeinstellungen und tatsächlich
stille Pausenausgabe. Alle neuen frischen Musik-Bereitschaftsprüfungen bestanden;
nach dem späteren regulären Resume wurden acht neue positive Blöcke über
1,858 Sekunden beobachtet. Die anschließend unverändert verlangte zusätzliche
2,5-Sekunden-Aufnahme enthielt auf diesem Software-Host jedoch nur vier
JavaScript-Abfragen, 21 frische PCM-Meldungen und drei positive Meldungen über
0,372 Sekunden. Die ursprüngliche Mindestanforderung von einer Sekunde wurde
damit ausdrücklich **nicht** erfüllt. Der Bericht bleibt unter
`work/premium-mobile/audio-pcm/chromium-fourth-span-failure.json` erhalten.

Zwei weitere ausdrücklich als `focus: resume` bezeichnete lokale Diagnosen
ändern daran nichts; sie sind keine vollständigen Audio-Abnahmen. Die erste
zeigte zudem, dass noch laufende Effektspieler bei angeforderten Nullpegeln
und tatsächlich gemuteten UI-, SFX- und Ambience-Bussen nicht hörbar beitragen.
Der Quellcode des echten Mixers routet seinen Stimmenpool ausschließlich auf UI
oder SFX; Musik und Ambience besitzen getrennte Spieler. Der Test akzeptiert
diesen eng begrenzten Isolationsfall nur, wenn beide tatsächlichen Bus-Mutes
**und** die Nullpegel übereinstimmen und Ambience ebenfalls aus ist. Teilweise
oder widersprüchliche Mute-Zustände bleiben ausgeschlossen. Eine weitere
Node-Gruppe prüft sechs entsprechende Gegenfälle. Der vollständige Test mit
nichtnull UI-/SFX-Pegeln verlangt weiterhin, dass die Effektstimmen beendet sind.

Die passiven zusätzlichen Messfelder dokumentieren nun Wandzeit, Start-/Endzeit
des realen AudioContexts, Routing-Generation, Frischegrenzen und erste/letzte
übermittelte PCM-Zeitstempel. Sie verändern weder das Ende der vorhandenen
2,5-Sekunden-Aufnahme noch Pegelgrenzen, Fristen oder die Signalprüfung. Tatsächliche
Ergebnisse aus der letzten fokussierten Diagnose:

| Aufnahme | Wandzeit | Fortschritt AudioContext | Letzte übermittelte PCM-Zeit relativ zum End-Context | Ergebnis |
| --- | ---: | ---: | ---: | --- |
| Menü | 2,783 s | 2,380 s | 0,372 s zurück | Positive PCM über 1,811 s |
| Kampf vor Pause | 5,952 s | 3,741 s | 2,278 s zurück | Letzte übermittelte Daten decken noch nicht das nominelle 2,5-s-Audiofenster ab |
| Erstes Resume | 2,586 s | 2,119 s | 0,781 s zurück | Positive PCM nur über 0,697 s; ursprüngliche Prüfung fehlgeschlagen |

Damit sind sowohl verspätete Datenübermittlung auf dem ausgelasteten
Browser-Mainthread als auch langsamerer Fortschritt des tatsächlichen
AudioContexts beobachtet. Das ist ausdrücklich **kein** Beleg, sämtliche
fehlenden Sekunden seien bereits erzeugte, lediglich verspätete Musikdaten.
Es wurde kein zukünftiges Signal nachträglich gesammelt und kein Fenster zum
Erzwingen eines Erfolgs verlängert. Die lokale Diagnose verwendet Playwright
1.65.0 / Chromium 158.0.8127.18; die vorhandene Audio-CI verwendet unverändert
Playwright 1.62.1 / Chromium 151.0.7922.34. Diese Umgebungen werden nicht
gleichgesetzt. Vollständige Audio-CI des nächsten tatsächlichen Commits bleibt
erforderlich; kein vollständiger lokaler Audio-Erfolg oder physischer
iPhone-/Android-Audiotest wird behauptet.

Die neuen logischen Testverträge bestehen **17/17**, ohne übersprungene Tests.
Die unveränderte App-Laufzeit dieser lokalen Messungen ist der ausdrücklich
mit `build-info.json` dokumentierte Export `b3d4441`; die Audio-Testdateien gehören
zum neueren Feature-Arbeitsstand. `source-bindings.json` im lokalen Evidence-
Verzeichnis enthält die jeweiligen Prüfsummen und diese Prüfgrenze. Das ist kein
Release-Nachweis für einen anderen Commit.
