# Alpha 0.1 – reproduzierbare QA

Stand:2026-11-09. Getesteter Modellstand `be60cd7`; Web-Testbuild `c2ad5b9c249ce0e52bc9f937fd38bcf443328824` (Canvas-Fix nach `6a8944e`). Buildmetadaten nennen den vollständigen Commit. Keine Live-QA und keine physischen Gerätetests.

## Abgeschlossene Prüfungen

| Prüfung | Ergebnis | Reproduktion / Beleg |
|---|---|---|
| Fixierte JS-Quelle und Originaldaten | 100 Originalkarten /5 Decks; Pin unverändert | `tools/test_legacy.sh`, source.lock.json |
| Node Legacy |30 Testgruppen ohne Fehler | Foundations8 + Engine7 + P05/P066 + P077 + komplette Partien2 |
| Node Alpha-Daten |4 Testgruppen ohne Fehler | `node --test tests/alpha_data.test.cjs` |
| Legacy Differential |1305 Fälle bestanden |441 Kern +366 P05/P06 +474 P07 +24 vollständige Partien |
| Legacy vollständige Partien |24 Partien /705 Spielerkommandos,0 Abweichungen | `tests/legacy_matches.gd`, Golden `full_matches_v1.json` |
| Alpha-Regeln |1704 Assertions,0 Fehler | `tests/alpha_rules.gd`;55 Karten auf beiden Seiten,4 Starter,64 komplette KI-Partien |
| Alpha-Replay |173 Assertions,0 Fehler | `tests/alpha_replay.gd`;4 vollständige Partien, JSON-Roundtrip, Manipulation/Ergebnisgrenze |
| Alpha-Touch/Layout |236 Assertions,0 Fehler | `tests/alpha_ui.gd`;844×390,915×412,844×320,1280×720,1600×900 |
| Releaseguard |6 Python-Testgruppen bestanden | `python3 -m unittest discover -s tests/release -v` |
| Web-Export/PCK |Export und Daten-/Feature-Smoke bestanden | `tools/build_alpha.sh`, `tests/alpha_exported.gd` |

Differentialfälle sind Szenarien, nicht Assertionzahl oder Anzahl jeder internen KI-Aktion. Unsupported `guarded_begin_wrong_side` ist nicht als bestanden gezählt. Ursprüngliche Referenz-Goldens/Kartenwerte nicht durch aktualisierte Sollwerte ersetzt. Der Namespace-Test wurde bewusst um die ausdrücklich autorisierte Alpha-Integrationsbrücke erweitert; das Archiv bleibt isoliert. Replayvergleiche prüfen sämtliche Alpha-Zustandsfelder statt Alpha-Instanzfelder im Legacy-Whitelistvergleich wegzulassen.

## Browser und CI

`tools/alpha_browser_qa.cjs` benutzt echte Canvas-Touches und nur eine lesende `?qa=1`-Zustandsprojektion, keine Zustandsinjektion. Profile:Chromium1280×720/1600×900/Android915×412/844×320 mit DPR2+SafeArea; WebKit844×390DPR3/915×412/844×320 mit SafeArea+reduzierter Bewegung. Prüfungen: Eröffnung,44CSS-Touchziele und Viewportgrenzen, legale Kartenaktionen, Sammlung/Speichern/Reload; zusätzlich vollständige Alpha-Desktop- und Legacy-Android-Partie samt Replayverifikation/Neustart.

**Lokale Browser-Gesamtprüfung bestanden:7 Profile,0 Fehler**, jeweils auf dem Build `c2ad5b9`. Chromium4 + WebKit3 getrennt ausgeführt; strukturierte [Einzelergebnisse](evidence/browser-results-c2.json). Beide vollständigen UI-Partien, Replayverifikation und Neustart bestanden. Die Alpha-Partie endete durch tatsächlich über die UI erklärte Konvergenz; die Legacy-Partie behielt ihren früheren Kontrollsieg. Keine Zustandsinjektion in diesen Partien.

Chromium meldete auf dem vorherigen Idle-Redraw-Stand einen Screenshot-Timeout; regelmäßige Canvas-Frames wurden wiederhergestellt und alle Profile anschließend bestanden. Früher abgebrochene diagnostische Läufe zählen nicht als bestandene Partien.

Neue CI `.github/workflows/alpha-qa.yml`:read-only, kein Deployjob, Tests→Archiv-WebQA→Alpha-WebQA→Artefakt. Alte Publisher-Workflow-ID406254158 bleibt global deaktiviert. CI-Fehler1: lokaler XDG-Exportpfad verdeckte installierte CI-Templates; korrigiert. CI-Fehler2:Ubuntu-latest wechselte auf26.04, von Playwright1.56.1 nicht unterstützt; Browserrunner jetzt explizit24.04. CI-Run [42705469676](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42705469676) scheiterte nach sechs erfolgreichen Archivprofilen am Start des siebten WPE-Profils (90s, kein gelockerter Test). PR-Testmerge `7c2d5f6` und Branch `c2ad5b9` haben denselben Git-Baum `89f51ce502cee764b06fdc3c73a6af45df8cd226`. Der separate Pushlauf42705454623 hat alle sieben Archivprofile bestanden; seine Alpha-Chromiumprofile einschließlich beider vollständiger Partien bestanden, danach scheiterte der erste WebKit-Alpha-Start mit einem WASM-Nullreferenzfehler. Kein insgesamt grüner PR-Check behauptet.

Der Archiv-Testharness startet nun einen frischen Browserprozess je Profil und sichert Startdiagnosen/Screenshots im Artefakt. Alle Assertions und Timeouts bleiben erhalten. Isolierte lokale Wiederholung des betroffenen WebKit-Profils `iphone-reduced`: vollständiges Tutorial, Reload/Sammlung und0 Fehler. Neuer Gesamtlauf auf dem Folgecommit erforderlich. Der nachfolgende Alpha-Bootfehler ist als P1-Kompatibilitätsbefund offen, nicht als bloßer Timeoutharnessfehler wegklassifiziert. CI trennt deshalb native Prüfungen/Exports und Browserjobs mit je eigenem frischem Runner für Chromium/WebKit; Browserprozesse außerdem je Profil isoliert. Keine Browserprüfung wird ausgelassen oder als unsupported bestanden gezählt.

## Bekannte lokale Testbefunde

- Früher Archivlauf unter gleichzeitigem Software-Rendering:1 Zeitfehler beim Doppel-Touch-Zugende1600×900. Späterer vollständiger Archivlauf erfolgreich, zusätzlich isolierte Wiederholung `archive-input-single.log`:380 Assertions,0 Fehler bei unveränderter Deadline. Die zwischenzeitlich überlappenden lokalen Archivläufe teilen historische work-Dateien; deshalb ist der isolierte Input-Nachweis ausdrücklich getrennt. Kein stilles Verlängern der Deadline.
- Ein manueller Godot-UI-Aufruf ohne die dokumentierten XDG-Verzeichnisse konnte im eingeschränkten Dateisystem kein user:// anlegen und stürzte ab. Mit beschreibbaren Workspace-XDG-Verzeichnissen wiederholt:233 UI-Assertions erfolgreich; erweiterter Decktausch-/Neuladetest anschließend236 erfolgreich. Kein Spielregeldefekt daraus abgeleitet.
- Frühe Entwicklungsfehler: immediate Entfernen von Controls während Input erzeugte `can_process`-Fehler, behoben durch deferred/coalesced Rendern; spätere UI-Prüfungen fehlerfrei. Touch-Helfer an `Input.parse_input_event` angepasst. Zwei frühe Schadenassertionen enthielten fälschlich nicht zurückgesetzte Test-Eröffnungsschilde; Testhelper korrigiert, keine Schadensregeln geändert.
- Lokale WebKit-Systembibliotheken aus offizieller Debianquelle im ignorierten Browserbundle bereitgestellt. `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` umgeht nur die ldconfig-Vorabprüfung für lokal gebündelte Libraries; tatsächlicher Browserstart/WebGL und alle Appassertionen bleiben aktiv. CI installiert regulär die Abhängigkeiten.

Abgeschlossener Archivlauf: Rules684, Creative2253, Narrative97, Experience715, Input380, Premium1720, UX2350, Combat725, CombatSequence622 Assertions jeweils0 Fehler. Gerenderter Kontrast:89 Zustände/3839 Regionen ohne Fehler. Diese Archiv-Kontrastmessung ist kein separater WCAG-Gesamtnachweis der neuen Alpha-Oberfläche.

Zusätzliche Alpha-Invarianten werden nach jedem KI-Zug geprüft:30 Karten je Seite inklusive Relikt/Lanes/Ablage, Handlimit, Ressourcenlimits, eindeutige positive Instanz-IDs und keine lebend gelisteten toten Kreaturen. Alle64 Simulationen bestanden. UI-Decktausch testet tatsächliches Entfernen/Ersetzen, Ablehnung von29 Karten und Neuladen des geänderten Decks.

## Testartefakt

Lokales ZIP `work/alpha/orafold-alpha-0.1-c2ad5b9c249c.zip` (19.856.495 Bytes), Sourcecommit `c2ad5b9c249ce0e52bc9f937fd38bcf443328824`, SHA256 `3d07e3852180ba1bcb9af1f9873dfe1c25bd29cd152b2b0066b1ff56c39a0025`. `artifact-manifest.json` enthält Einzeldateihashes. Zwei Verpackungen derselben Exportdateien mit festen ZIP-Zeitstempeln ergaben identische Bytes; keine Behauptung bitidentischer Godot-Exports auf beliebigen Betriebssystemen. `tests/alpha_exported.gd` besteht aus diesem PCK. Dies ist ein lokales Testartefakt, keine Veröffentlichung.

## Befehle

```sh
node --test tests/alpha_data.test.cjs
bash tools/test_legacy.sh
DISPLAY=:99 bash tools/test_alpha.sh
DISPLAY=:99 bash tools/test.sh
python3 -m unittest discover -s tests/release -v
# Lokal exportieren; CI nutzt ihre Standardtemplateinstallation.
export XDG_DATA_HOME="$PWD/work/xdg/data"
export XDG_CONFIG_HOME="$PWD/work/xdg/config"
export XDG_CACHE_HOME="$PWD/work/xdg/cache"
bash tools/build_alpha.sh
python3 -m http.server 8788 --bind 127.0.0.1 --directory work/alpha/web
# Zweites Terminal: Playwright1.56.1 installieren, Browserdeps installieren.
NODE_PATH="$PWD/work/qa-browser/node_modules" \
EXPECTED_COMMIT="$(git rev-parse HEAD)" node tools/alpha_browser_qa.cjs
```

Kein erfolgreicher Alpha-Release folgt aus einem lokalen Teiltest. [Bekannte Grenzen](KNOWN_ISSUES.md) bleiben vor einer Releasefreigabe sichtbar.

## Screenshots

- [Arena844×390](evidence/arena-844x390.png)
- [Arena1280×720](evidence/arena-1280x720.png)
- [Deckbuilder915×412](evidence/deckbuilder-915x412.png)
- [WebKit iPhone DPR3](evidence/webkit-iphone-dpr3.png)
- [Tatsächlicher UI-Konvergenzsieg](evidence/convergence-ui-victory.png)
- [Tatsächlicher Legacy-UI-Sieg](evidence/legacy-ui-victory.png)

Screenshots stammen aus tatsächlichen Godot-/Browser-Renderings. Keine Mockups oder Bildgenerator-Arbeitsentwürfe. Darstellung/Atlas sind Platzhalterproduktion; Screenshots beweisen keine physischen Geräteeigenschaften.
