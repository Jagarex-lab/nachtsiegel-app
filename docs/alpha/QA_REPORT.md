# Alpha 0.1 – geprüfter spielbarer Kandidat

Stand:2026-11-09. **Spiel-/CI-Stand `8c1d3427d0208862e712dc88da5be9086c6a9194` vollständig grün**, sowohl [Branchlauf42713094196](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42713094196) als auch [PR-Testmerge42713103955](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42713103955). Native, Chromium und WebKit jeweils SUCCESS; [maschinenlesbarer Nachweis](evidence/ci-8c-summary.json). Testmerge ist keine Integration in develop.

## Tatsächlich bestandene Prüfungen

| Prüfung | Ergebnis | Reproduktion |
|---|---|---|
| Fixierte JS-Quelle / Originaldaten |100 Karten,5 Decks, Pin/Hashes unverändert | `tools/test_legacy.sh` |
| Node |34 Gruppen,0 Fehler |30 Legacy +4 Alpha |
| Legacy Differential |1305 Fälle,0 Abweichungen |441 Kern +366 P05/P06 +474 P07 +24 vollständige Partien |
| Vollständige JS/Godot-Partien |24 Partien,705 Spielerkommandos inklusive Original-KI | `tests/legacy_matches.gd` |
| Alpha-Regeln |1704 Assertions,0 Fehler;64 vollständige KI-Partien | `tests/alpha_rules.gd` |
| Native Replays |173 Assertions,0 Fehler;4 vollständige Partien | `tests/alpha_replay.gd` |
| Alpha-Touch/Layout |237 CI-Assertions,0 Fehler (lokal236) | `tests/alpha_ui.gd` |
| Browser pro Gesamtlauf |7 Archiv- und7 Alpha-Profile,0 Fehler | `tools/browser_qa.cjs`, `tools/alpha_browser_qa.cjs` |
| Wiederholte Kaltstarts |6 frische WebKitprozesse,0 Fehler,3 Archiv/3 Alpha | `tools/alpha_boot_qa.cjs` |
| Releaseguard |6 Python-Gruppen,0 Fehler | `python3 -m unittest discover -s tests/release -v` |
| Export |Native PCK-Smokes und tatsächliche Browserabläufe bestanden | `tests/alpha_exported.gd`, Browserjobs |

Assertionzahlen variieren im UI-Test mit der seedabhängigen Handgröße; beide dokumentierten Läufe haben0 Fehler. Differentialfälle sind Szenarien, nicht jede interne KI-Aktion oder jede Assertion. Der defensive Raw-helper-Fall `guarded_begin_wrong_side` bleibt ausdrücklich unsupported und ist nicht in1305 enthalten. Alte Referenz-Goldens wurden nicht durch Godot-Sollwerte ersetzt. Die sieben Prototypkarten/Produktionsregeln und Originalkartendaten sind [byteidentisch zu PR7](evidence/source-isolation.json).

Alpha-Invarianten nach jedem KI-Zug:30 Karten pro Seite einschließlich Deck/Hand/Ablage/Lanes/Relikt, Ressourcen- und Handlimits, eindeutige positive Instanz-IDs und keine toten Kreaturen auf dem abgeschlossenen Spielfeld. Alle55 Alpha-Karten werden auf beiden Seiten tatsächlich ausgeführt; künstliche Grenzfallzustände sind getrennt von vollständigen Partien. Effektketten10/25/50/100 sowie expliziter Zyklusfehler geprüft. Das belegt Queue-Kapazität, nicht hundert natürlich entstehende Starter-Kombinationen.

Native Replayvergleiche prüfen sämtliche Alpha-Zustandsfelder, einschließlich UID/Schutz/Relikt/Bindung. JSON-Roundtrip, komplette Endzustände, abgelehnte Aktionen, Hashmanipulation und Ergebnisverriegelung sind abgedeckt. Format ist ORAFOLD-LOCAL-REPLAY v1/SHA256; kein originaler JS audit-v4-/FNV1a-Paritätsclaim.

## Browserbedingungen

Playwright **1.65.0**, Chromium158.0.8127.18, WebKit27.2, Godot4.6.3, Ubuntu24.04 auf CI. Chromium:1280×720,1600×900,915×412DPR1 und844×320DPR2/SafeAreas. WebKit:844×390DPR3,915×412DPR1 und844×320DPR1/SafeAreas/reduzierte Bewegung. Native zusätzlich844×390/915×412/844×320/1280×720/1600×900.

Readonly-Bridge nur mit `?qa=1`; keine Zustandsinjektion in den vollständigen Browserpartien. Tatsächliche Canvas-Touches prüfen Eröffnung,44CSS-Touchziele, Viewportgrenzen, legale Kartenaktionen und Speichern/Reload. **Nur zwei Alpha-Harnessprofile spielen vollständige Partien:** Chromium-desktop im Alpha-Modus (UI-Konvergenzsieg) und Chromium-android im Legacy-Modus (Original-Kontrollsieg), jeweils Replay identisch und Neustart erfolgreich. Die übrigen fünf Profile prüfen Eröffnung/legale Züge/Deckspeicherung. Nicht als sieben vollständige Partien zählen.

Auch lokal sind alle sieben Alpha-Profile auf dem exakt heruntergeladenen früheren CI-ExportC2 mit dem aktuellen Browserstack bestanden, plus sechs Kaltstarts: [genau zugeordnete Ergebnisse](evidence/local-qa-current.json). SeitC2 unterscheiden sich die Spielressourcen nur in zwei Kernel-Kommentarzeilen; Folgeänderungen betreffen Tests/CI/Dokumentation. JS/WASM von lokalem und CI-C2-Export sind bytegleich; PCK-Pakete werden nicht als bytegleich behauptet.

**Keine physischen iPhone-/Android-Tests.** Keine Browser-/GPU-Simulation wird als tatsächliche Geräte-, Energieverbrauchs-, FPS- oder App-Store-Abnahme ausgegeben.

## Archivregression

Der grüne integrierte CI-Lauf enthält die vollständige bestehende Desktop-/Browserregression. Lokaler kompletter Archivlauf:Rules684, Creative2253, Narrative97, Experience715, Input380, Premium1720, UX2350, Combat725, CombatSequence622 Assertions jeweils0 Fehler. Archiv-Kontrast:89 Zustände/3839 Regionen ohne Fehler. Das ist kein separater WCAG-Gesamtnachweis der neuen Alpha-Oberfläche.

## Fehler und Iterationen – offen dokumentiert

1. Frühe Namespaceprüfung verbot noch jede UI-Anbindung des isolierten Legacy-Katalogs. Bewusst um die nun ausdrücklich autorisierte Alpha-Brücke erweitert; Archiv-Prototyp bleibt getrennt. Alte fixtures/wertgleiche Referenzen nicht geändert.
2. Frühe GUI-Tests verwendeten die falsche Touch-Injektion; auf tatsächliches `Input.parse_input_event` umgestellt. Controls während Input sofort entfernt → `can_process`-Fehler; durch deferred/coalesced Rendern behoben. Spätere UI-Läufe fehlerfrei. Zwei Schadenassertionen hatten alte Test-Eröffnungsschilde nicht zurückgesetzt; Testhelper korrigiert, Schadensregeln unverändert.
3. Früher lokaler Archivlauf:ein Touch-Zeitfehler bei1600×900 unter parallelem Software-Rendering. Später vollständiger Archivlauf und isolierte Wiederholung380/0 bei **unveränderter Deadline**. Überlappende historische work-Logs sind kein sauberer Einzelnachweis; deshalb isolierter Nachweis und frische CI zusätzlich.
4. CI-Export fand Templates wegen überschriebenem XDG-Pfad nicht:Exportskripte behalten nun die installierte Standardposition. Ubuntu-latest wechselte auf26.04, vom alten Playwright nicht unterstützt:Runner explizit24.04.
5. Idle-Redraw-Optimierung erzeugte einen Chromium-Screenshot-Timeout. Regelmäßige Canvas-Frames wiederhergestellt; anschließende komplette Profile und Partien bestanden.
6. Playwright1.56.1/WebKit26 zeigte sporadische WASM-Nullreferenz-/Out-of-bounds-Bootfehler, auch im Archiv vor Spielstart. Prozessisolation allein war kein nachgewiesener Fix; Fehlversuche erhalten. Aktueller stabiler Stack1.65.0/27.2 ist fixiert, beide aktuellen CI-Läufe einschließlich sechs Kaltstarts grün. Kein unbewiesener Engine-Root-Cause-Claim und keine Aussage über ältere physische Safari-Versionen.
7. Schneller neuer Chromiumstart erreichte den HTTP-Fixtureserver vor dessen Listen-Socket (`ECONNREFUSED`). Explizite HTTP-/Commit-Readiness vor Browserstart ergänzt. Kein App-Startup-Retry, keine entfernten Assertions, keine verlängerten90s-Spiel-Timeouts.

Ein manueller Godot-Aufruf ohne Workspace-XDG konnte im eingeschränkten Dateisystem kein user:// anlegen; mit beschreibbaren XDG-Verzeichnissen wiederholt erfolgreich. Lokale Browserdeps aus offiziellen Debianpaketen im ignorierten Browserbundle bereitgestellt. Skip-host-validation umgeht dort nur die ldconfig-Vorabprüfung, nicht tatsächlichen Start/WebGL oder Appassertionen; CI installiert normale Dependencies.

## Verifiziertes Testartefakt

`work/alpha/orafold-alpha-0.1-8c1d3427d020.zip` – **19.862.070 Bytes**, Sourcecommit8c1d342, SHA256 **ad7a883e316df6a087a404a80c20634a294e6d06465e67318023b25d1d7ebc43**. Direkt aus dem [erfolgreichen CI-Artefakt](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42713094196/artifacts/13715564954) heruntergeladen, innere ZIP-Prüfung und sämtliche Manifest-Dateihashes erneut geprüft. Das äußere Actions-Artefakt enthält zusätzlich Screenshots/Logs; darin liegt dieses eigenständige Spiel-ZIP.

`artifact-manifest.json` bindet alle exportierten Dateien. Verpackung hat feste Zeitstempel; wiederholtes Verpacken derselben Exportdateien ergab identische Bytes. Kein Versprechen OS-unabhängig bitidentischer Godot-Exports. Dies ist ein vorbereitetes Testartefakt, keine Veröffentlichung.

## Reproduktion

```sh
node --test tests/alpha_data.test.cjs
bash tools/test_legacy.sh
DISPLAY=:99 bash tools/test_alpha.sh
DISPLAY=:99 bash tools/test.sh
python3 -m unittest discover -s tests/release -v
# Für lokale Templates; CI behält ihren installierten Standardpfad.
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
bash tools/build_alpha.sh
python3 tools/package_alpha.py
python3 -m http.server 8788 --bind 127.0.0.1 --directory work/alpha/web
# Zweites Terminal: Playwright1.65.0 und dessen Browserdeps installieren.
NODE_PATH="$PWD/work/qa-browser/node_modules" \
EXPECTED_COMMIT="$(git rev-parse HEAD)" node tools/alpha_browser_qa.cjs
```

ZIP testen:entpacken, im entpackten Verzeichnis `python3 -m http.server 8788 --bind 127.0.0.1`, dann `http://127.0.0.1:8788/`. Nicht als file:// öffnen. Kein neuer Pages-Link.

## Tatsächlich gerenderte Screenshots

[Arena844×390](evidence/arena-844x390.png) · [Arena1280×720](evidence/arena-1280x720.png) · [Deckbuilder915×412](evidence/deckbuilder-915x412.png) · [WebKitDPR3](evidence/webkit-iphone-dpr3.png) · [UI-Konvergenzsieg](evidence/convergence-ui-victory.png) · [Legacy-UI-Sieg](evidence/legacy-ui-victory.png).

Bilder sind tatsächliche Godot-/Browseraufnahmen, keine Mockups. Vollständige Rohlogs/Screenshots liegen in den benannten CI-Artefakten. [Verbleibende Grenzen](KNOWN_ISSUES.md).
