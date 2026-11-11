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
| Browser-Vertragsprüfungen | 33 Node-Vertragsprüfungen bestanden, 0 Fehler, 0 übersprungen; Browser, öffentliche Dateiintegrität, PWA und Worker; keine Spielbarkeit allein daraus behauptet |
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
