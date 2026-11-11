# Premium Mobile – QA und Nachweise

## Prüfstatus

Ausgangsstand ist Develop `10782185cf41f2013607ba47da0bbfcb737e89e2`.
Dieser Bericht trennt die tatsächlich ausgeführten Prüfungen von den noch
ausstehenden Integrationsprüfungen. Frühere Alpha-0.3-Ergebnisse sind keine
Freigabe eines neuen Commits.

| Prüfung | Tatsächlicher Stand |
| --- | --- |
| Native Vorher-Aufnahmen | 9 echte Godot-Aufnahmen des Ausgangsstands erstellt; fünf Querformatgrößen, Inspektion sowie Menü/Starter/Deckbuilder im Hochformat |
| Browser-Vertragsprüfungen | 10 Node-Tests bestanden, 0 Fehler, 0 übersprungen; prüfen die Prüflogik, keine Spielbarkeit behauptet |
| Inaktive Release-Vorbereitung | 31 Python-Tests und 7 Node-HTTP-Testgruppen bestanden; aktiver Publisher und Guard byteidentisch |
| Unveränderter Kartenkatalog | 550 Definitionen, 110 je Zugehörigkeit, 357 Wesen/133 Impulse/60 Relikte; 0 Validierungsfehler/Warnungen |
| Illustrationsdateien | Vollständiger Manifest-/Prüfsummenlauf: 550 individuelle Dateien, 0 fehlende, 0 verwaiste; keine neue kommerzielle Rechtsfreigabe behauptet |
| Syntax der Browserharnesses | `node --check` bestanden |
| Neuer Export in Chromium/WebKit | Noch auf dem zusammengeführten Kandidaten auszuführen |
| Vollständige KI-Partien/Replay/Neustart | Vorhandenes echtes Eingabeharness erhalten; auf dem Kandidaten erneut auszuführen |
| Physisches iPhone/Android | Nicht vorhanden; ausdrücklich offen |
| Veröffentlichung | Durch diesen Prüfauftrag nicht ausgelöst |

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
nur echte Canvas-Taps und Browser-Scroll-Eingaben. `window.orafoldQA` dient
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
