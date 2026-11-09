# Alpha 0.1 – reproduzierbare QA

Stand:2026-11-09. Getesteter Modellstand `be60cd7`; Präsentations-/CI-Fix `6a8944e`. Buildmetadaten nennen den vollständigen Commit. Keine Live-QA und keine physischen Gerätetests.

## Abgeschlossene Prüfungen

| Prüfung | Ergebnis | Reproduktion / Beleg |
|---|---|---|
| Fixierte JS-Quelle und Originaldaten | 100 Originalkarten /5 Decks; Pin unverändert | `tools/test_legacy.sh`, source.lock.json |
| Node Legacy |30 Testgruppen ohne Fehler | Foundations8 + Engine7 + P05/P066 + P077 + komplette Partien2 |
| Node Alpha-Daten |4 Testgruppen ohne Fehler | `node --test tests/alpha_data.test.cjs` |
| Legacy Differential |1305 Fälle bestanden |441 Kern +366 P05/P06 +474 P07 +24 vollständige Partien |
| Legacy vollständige Partien |24 Partien /705 Spielerkommandos,0 Abweichungen | `tests/legacy_matches.gd`, Golden `full_matches_v1.json` |
| Alpha-Regeln |737 Assertions,0 Fehler | `tests/alpha_rules.gd`;55 Karten auf beiden Seiten,4 Starter,64 komplette KI-Partien |
| Alpha-Replay |173 Assertions,0 Fehler | `tests/alpha_replay.gd`;4 vollständige Partien, JSON-Roundtrip, Manipulation/Ergebnisgrenze |
| Alpha-Touch/Layout |236 Assertions,0 Fehler | `tests/alpha_ui.gd`;844×390,915×412,844×320,1280×720,1600×900 |
| Releaseguard |6 Python-Testgruppen bestanden | `python3 -m unittest discover -s tests/release -v` |
| Web-Export/PCK |Export und Daten-/Feature-Smoke bestanden | `tools/build_alpha.sh`, `tests/alpha_exported.gd` |

Differentialfälle sind Szenarien, nicht Assertionzahl oder Anzahl jeder internen KI-Aktion. Unsupported `guarded_begin_wrong_side` ist nicht als bestanden gezählt. Ursprüngliche Referenz-Goldens/Kartenwerte nicht durch aktualisierte Sollwerte ersetzt. Der Namespace-Test wurde bewusst um die ausdrücklich autorisierte Alpha-Integrationsbrücke erweitert; das Archiv bleibt isoliert. Replayvergleiche prüfen sämtliche Alpha-Zustandsfelder statt Alpha-Instanzfelder im Legacy-Whitelistvergleich wegzulassen.

## Browser und CI

`tools/alpha_browser_qa.cjs` benutzt echte Canvas-Touches und nur eine lesende `?qa=1`-Zustandsprojektion, keine Zustandsinjektion. Profile:Chromium1280×720/1600×900/Android915×412/844×320 mit DPR2+SafeArea; WebKit844×390DPR3/915×412/844×320 mit SafeArea+reduzierter Bewegung. Prüfungen: Eröffnung,44CSS-Touchziele und Viewportgrenzen, legale Kartenaktionen, Sammlung/Speichern/Reload; zusätzlich vollständige Alpha-Desktop- und Legacy-Android-Partie samt Replayverifikation/Neustart.

Browser-Gesamtstatus wird nach dem vollständigen Lauf ergänzt. Chromium meldete nach der Idle-Redraw-Optimierung einen Screenshot-Timeout; regelmäßige Canvas-Frames wurden wiederhergestellt, Wiederholungsprüfung ausstehend. Erster WebKit-iPhone-DPR3-Test bestanden; noch kein pauschaler Sieben-Profil-Erfolg behauptet. Früher diagnostischer Chromiumlauf wurde vor Abschluss beendet und zählt nicht als bestandene Partie. Der Testspieler verwendet nun auch die echte Konvergenzschaltfläche, statt diese Siegbedingung im Spielerablauf auszulassen.

Neue CI `.github/workflows/alpha-qa.yml`:read-only, kein Deployjob, Tests→Archiv-WebQA→Alpha-WebQA→Artefakt. Alte Publisher-Workflow-ID406254158 bleibt global deaktiviert. CI-Fehler1: lokaler XDG-Exportpfad verdeckte installierte CI-Templates; korrigiert. CI-Fehler2:Ubuntu-latest wechselte auf26.04, von Playwright1.56.1 nicht unterstützt; Browserrunner jetzt explizit24.04. Letzte CI und Artefaktlink werden nach Laufende angegeben.

## Bekannte lokale Testbefunde

- Archivsuite erneut ausgeführt. `INPUT/LAYOUT` meldete unter gleichzeitigem Software-Rendering1 Zeitfehler beim Doppel-Touch-Zugende1600×900 (379/380 erfolgreich). Deadline blieb unverändert; kein Grün durch stilles Verlängern. Andere Archivresultate getrennt ausweisen.
- Ein manueller Godot-UI-Aufruf ohne die dokumentierten XDG-Verzeichnisse konnte im eingeschränkten Dateisystem kein user:// anlegen und stürzte ab. Mit beschreibbaren Workspace-XDG-Verzeichnissen wiederholt:233 UI-Assertions erfolgreich; erweiterter Decktausch-/Neuladetest anschließend236 erfolgreich. Kein Spielregeldefekt daraus abgeleitet.
- Frühe Entwicklungsfehler: immediate Entfernen von Controls während Input erzeugte `can_process`-Fehler, behoben durch deferred/coalesced Rendern; spätere UI-Prüfungen fehlerfrei. Touch-Helfer an `Input.parse_input_event` angepasst. Zwei frühe Schadenassertionen enthielten fälschlich nicht zurückgesetzte Test-Eröffnungsschilde; Testhelper korrigiert, keine Schadensregeln geändert.
- Lokale WebKit-Systembibliotheken aus offizieller Debianquelle im ignorierten Browserbundle bereitgestellt. `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` umgeht nur die ldconfig-Vorabprüfung für lokal gebündelte Libraries; tatsächlicher Browserstart/WebGL und alle Appassertionen bleiben aktiv. CI installiert regulär die Abhängigkeiten.

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

Screenshots stammen aus tatsächlichen Godot-/Browser-Renderings. Keine Mockups oder Bildgenerator-Arbeitsentwürfe. Darstellung/Atlas sind Platzhalterproduktion; Screenshots beweisen keine physischen Geräteeigenschaften.
