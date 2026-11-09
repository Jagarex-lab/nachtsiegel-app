# Legacy P07: Resonanz, Ordensreaktionen und Sonderaktionen

Stand 2026-11-09. Eigener Branch `feature/legacy-engine-p07`, direkt aus PR #5 bei `27c39f3ee3c20d751bb9fa0caedb5c05f9ab5548`, gestapelte Basis `feature/legacy-engine-p05-p06`. PR #5 Web-QA ist abgeschlossen: [Run 42668573208](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42668573208) SUCCESS, Deploy SKIPPED; dessen Legacy-CI ebenfalls SUCCESS. Kein Eltern-PR gemergt oder umgeschrieben.

Unveränderte fachliche Referenz: duel-deck `34b3062c3f22c0950d9323ad9b97b17c41d1d14f`, engine.js SHA256 `abf880e049080a7ec39a43fefa805ba9e8de18f7638633bef6d7096dc5a78dd1`. Vorhandene Pins/Kataloge/Decks/Goldens werden nicht überschrieben. Erweitert wird nur der bestehende Legacy-Kernel. Keine produktive UI, KI, F2P, Raum-Zeit-/Reliktmechanik, neue Fraktion, Kartenbalance, Marken-/Lore-/Assetänderung oder Pages-Konfiguration. Der separate Sicherheits-PR #6 wird nicht heimlich übernommen. Auch der alte Standing-Publishtext in AGENTS.md dieses Elternzweigs ist durch den aktuellen ausdrücklichen Auftrag „kein Merge/Deployment“ überstimmt.

## Implementierter Originalvertrag P07a–e

Resonanz cap 15, Schild cap 25, Energiebeginn bei Resonanz >=5/10/15 je +1, exakt 15 zusätzlich +2 Schild. Begin löscht attune sowie burstUsed/tacticUsed/fortifyUsed/cycled und summons, setzt Block zurück und führt die vorhandene Nachziehphase unverändert aus. Schwellen 0/4/5/9/10/14/15, beide Seiten und Level 1/5 sind gegen JS geprüft.

### Reaktionen

`play` validiert alle bisherigen Kosten/Ziele/Phase/Pending-/Zwei-Beschwörungen-Gates; kein pauschaler Andersorden-Guard mehr. Reihenfolge exakt: Handentnahme → Energiepreis → summons++ → Einheit auf Feld → summon-Beobachtung mit bisherigem attune → bei andersartigem Folgeorden +2 Resonanz, dann gerichtete Reaktion → attune setzen → bestehende Gewinnerprüfung → nur ohne Gewinner Ankunftseffekt/FIFO. Ein tödlicher Wechsel verbraucht die Karte und stellt sie aufs Feld, unterdrückt aber den folgenden draw/strike/pierce-Effekt. Keine Reaktion beim ersten oder gleichordentlichen Ruf.

| Von → Nach | Zusätzliche Reaktion nach den +2 Resonanz |
|---|---|
| ash → tide | 2 geschützter gegnerischer Heldenschaden |
| ash → thorn | +3 eigener Block |
| ash → veil | 2 geschützter gegnerischer Heldenschaden |
| tide → ash | +1 weitere Resonanz |
| tide → thorn | +3 eigener Schild |
| tide → veil | +1 eigene Energie |
| thorn → ash | +2 eigener Schild |
| thorn → tide | +1 weitere Resonanz |
| thorn → veil | +2 eigene Helden-HP bis maxHp |
| veil → ash | Gegner weak=max(weak,1) |
| veil → tide | +2 eigener Block |
| veil → thorn | +2 eigener Schild |

Die zugehörige Beobachtung erfolgt mit altem attune und bereits angewendeten Ressourcen/Schäden, wie die JS-Reaktionsmeldung. Keine separate erfundene Queue oder Effektstärke. Direkter Angriff bei leerem Gegenüber sowie Block→Schild→HP bleiben unverändert.

### Entfesselungen

Aktive main-Phase, kein Gewinner, Resonanz mindestens 15, einmal je Zug und mindestens eine eigene Kreatur des gewählten Originalordens. Kosten exakt 8; n zählt nur passende Einheiten. **PendingTarget/PendingShift sperren burst laut Quelle nicht**. Keine KI-Entfesselung ergänzt.

- ash: 4+3*n geschützter Heldenschaden.
- tide: +6+2*n eigener Schild, cap 25.
- thorn: **alle** eigenen Kreaturen, auch andere Orden, +3 HP bis Originalbasis; eigener Held +3+n bis maxHp.
- veil: gegnerische weak **exakt2**, auch wenn vorher höher; nur passende eigene Einheiten +2 ATK.

Beobachtung nach vollständigem Effekt und Kosten/Flag, anschließend unveränderte Gewinnerprüfung. n=0/1/3/5, Resonanz14/15, verbrauchte Aktion, falscher Orden/Phase/Seite, Spielende, beide Pendingarten und erneute legale Nutzung nach begin geprüft.

### Pfadmanöver und Pfadwacht

Beide nur aktive main-Phase ohne Gewinner/offene Wahl, jeweils eigenes Einmal-Flag.

- Manöver: >=3 Resonanz, ganzzahlige gültige Felder, eigene Kreatur auf Ursprung und **benachbartes freies** Ziel; verschieben, −3, tacticUsed=true. Summoned/Stun/Einheitenkörper bleiben erhalten. **Kein** shift-Formationstrigger und kein Resonanzbonus für neue Nachbarschaft.
- Wacht: >=2 Resonanz, ganzzahliger gültiger eigener besetzter Pfad; −2, fortifyUsed=true, +2 Schild cap 25, Kreatur HP=min(Originalbasis,HP+1). Volle HP sind trotzdem gültig; bereits synthetisch überhöhte HP werden wie JS auf Basis gekappt.

Ungültige öffentliche Aktionen verändern weder Zustand noch Trace. `_reaction` ist interner Ablauf, kein frei aufrufbarer Spielercommand. execute ergänzt ausschließlich burst/tacticalMove/fortify mit geprüfter Argumentanzahl. Vorhandene defensive Raw-API-Unterschiede aus P04/P05 bleiben ausdrücklich bestehen.

## Tests und Abdeckung

| Nachweis | Ergebnis im Quelltestlauf |
|---|---|
| Bisheriger Kernelvergleich | 440 Fälle, 2237 Assertions, 0 Fehler; alle 415 vorherigen enthalten und **alle 25 P07-Altszenarien aktiviert** |
| P05/P06-Regression | 366 Fälle / 521 Übergänge, 2342 Assertions, 0 Fehler; bisherige Goldens unverändert |
| Neue P07-Suite | **474 Fälle / 1084 Übergänge, 7562 Assertions, 0 Fehler**, keine Skips |
| Grundlagen | 2171 Assertions, 0 Fehler |
| Node insgesamt | 8+7+6+7 = **28 Gruppen bestanden**, 0 Skips; byteidentische Reproduktion beider neuer Goldens |
| Differentialgesamtzahl | **1280 bestandene Fälle = 440+366+474**, keine vollständigen Duelle/Replays als Zahl ausgegeben |
| Kartenketten | **200 echte gemischte Zwei-Ruf-Ketten**, alle 100 Karten auf beiden Seiten mit Ankunftseffekt und anschließender Angriffsphase |
| RNG | P07-Aktionen verbrauchen keinen Match-RNG; Godot-Zähler/Zustand pro Übergang unverändert, Original-LCG zusätzlich read-only per Math.imul beobachtet |

Vollständige Vor-/Nachzustände und geordnete volle Ereigniszustände mit pendingDeath wie P05/P06 verglichen. Nur unmittelbar identische Beobachtungen zusammengefasst. Tode/harvest, Quell-/Zielwahl, Regenerierung von Ressourcen und Flags, lethal Reaktion, Schutz und Zustand vor Ankunft geprüft. **Keine P11-Rohlog-/Hash-/Command-ABI-Parität behauptet.** Falschreihenfolge und Feldmanipulation werden von den vorhandenen Negativvergleichstests erkannt.

[Initiale Gesamtsuite](p07-evidence/legacy-suite-initial.log), [finale Node-P07-Gruppen](p07-evidence/p07-node.log), [P07-Resultat](p07-evidence/p07-results.json), [bestehender Kernel und verbleibende Skips](p07-evidence/core-results.json). Die P05/P06-Guardtests wurden auf die nun gültigen P07-Befehle angepasst; deshalb dort sechs obsolete Unsupported-Assertions weniger. Goldens und reale Regelvergleiche wurden nicht gelöscht. Bestehender Kerneltest prüft zusätzlich, dass keiner der vorher unterstützten Fälle neu unsupported wird.

### Vollständige CI und lokale Diagnose

Quellcommit `6bc8734` hat die vollständigen Prüfungen auf GitHub bestanden:

- [Legacy-CI 42681393891](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42681393891): **SUCCESS**, alle 28 Node-Gruppen und 1280 Differentialfälle, Godot 2171/2237/2342/7562 Assertions ohne Fehler ([Zusammenfassung](p07-evidence/ci-source-summary.log)).
- [Desktop-/Web-QA 42681299906](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42681299906): **SUCCESS**, 9547 Desktop-Assertions ohne Fehler; 89 Kontrastzustände / 3838 Regionen ohne Fehler; Web-Export, Text-/Kampagnenprüfung im exportierten Paket und **alle sieben Chromium-/WebKit-Profile** bestanden. Deploy **SKIPPED**. [Zusammenfassung](p07-evidence/web-ci-source-summary.log), [Resultat](p07-evidence/ci-results.json). Screenshots, Browserresultate und Webbuild sind im Run-Artefakt `nachtsiegel-arena-qa` verfügbar, keine Pages-Veröffentlichung.

Lokal wurden alle Desktop-Gruppen ebenfalls vollständig ausgeführt, aber die Gesamtsuite ist **NICHT vollständig grün**:

1. `DISPLAY=:99 LP_NUM_THREADS=2 bash tools/test.sh`: 9538 Assertions, keine Assertionfehler, Audio/Kontrast bestanden; **Exit1** im abschließenden zentralen Check wegen zwei Ressourcenresten/ObjectDB-Leak beim Shutdown von tests/input_layout.gd. [Alle ursprünglichen Logs und Resultat](p07-evidence/desktop-first/).
2. Isolierte verbose-Wiederholung: 380 Assertions / **1 Fehler**, `Touch end turn locked against duplicate tap (1600, 900)` überschreitet die unveränderte Fünfsekundenfrist; keine Shutdown-Ressourcenmeldung in diesem Lauf. [Log](p07-evidence/input-recheck-failure.log).
3. Wiederholung mit `LP_NUM_THREADS=1`: derselbe Touch-Timeout, 380 Assertions / **1 Fehler**, Exit1; das Suite-Skript stoppt daraufhin gemäß set -e, spätere Gruppen in diesem Wiederholungslauf nicht erneut ausgeführt. [Log](p07-evidence/input-lp1-failure.log). Nicht als bestandener Gesamtlauf gezählt.

Software-Rendering/CPU-Quota ist ein möglicher Zusammenhang, **keine bewiesene Ursache**. Der grüne CI-Lauf ersetzt oder löscht diese lokalen Fehler nicht. Keine Produktionsanimation, Testfrist oder Erwartung wurde zum Erzwingen grüner Tests geändert. Der Inputtest, Arena und Audio sind byteidentisch zum Elternstand; aktuelle Grenzen müssen bei späterer UI-Integration erneut geprüft werden. [83 unveränderte übernommene Dateien](p07-evidence/protected-files.json), [SHA256 des geprüften Kernel-/Test-/Fixturestands](p07-evidence/source-manifest.json).

Lokaler Browserwerkzeug-Aufbau: Playwright1.56.1 und Browser unter work/qa-browser, npm-Cache lokal. System-Pakethelper fehlt, apt-Konfigurationslesung ist beschränkt. Fehlende WebKit-Bibliotheken deshalb aus offiziellem Debian-trixie-Index heruntergeladen, SHA256 gegen Index geprüft und nur im ignorierten Arbeitsbaum entpackt. Tatsächliches dlopen und reale Chromium-/WebKit-Prozesse/DOM-Smoke erfolgreich. Weil der Playwright-DLOPEN-Precheck nur den globalen ldconfig-Cache prüft, war für den lokalen Smoke `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` nötig; keine Anwendungstests deaktiviert. [Pakete und Aufbau](p07-evidence/local-browser-setup.txt). **Die vollständigen sieben Browserprofile wurden auf CI ausgeführt, lokal nicht nochmals als kompletter Lauf behauptet.** Keine Systemkonfiguration oder exportierte Assets geändert.

Historische Upstream-JS-Probleme aus P05/P06 (START-Erwartung, unvollständiger UI-Mock, fehlende externe check.js-Datei) bleiben unverändert dokumentiert; der neue Oraclevergleich verwendet ausschließlich die fixierten tatsächlichen Enginebytes, keine Reparatur des Oracles.

## Verbleibende Grenzen und nächste Pakete

**Keine P07-unsupported-Szenarien mehr.** Zwei ausdrücklich nicht als bestanden gezählte alte Fälle:

1. `endTurn.valid.enemy_response`: automatischer vollständiger enemyTurn, **P10**. Kernel endet am vorhandenen before-AI-Zuggrenzpunkt; kein erfundener Controller.
2. `block.retained_during_other_begin`: JS-Raw-Helper erlaubt Aufruf für nichtaktive Seite; Godot lehnt defensiv ab. Bestehende bewusst dokumentierte API-Schutzabweichung, kein offener Ordens-/Resonanzeffekt. Nicht als neu hergestellte Parität ausgegeben.

**P08 nur vorbereitet:** Vorhandene checkWinner-/Pfadkontrollregeln bleiben unverändert, P07 ruft die bestehenden Prüfpunkte in Originalreihenfolge auf und prüft lethal-Reaktion/Entfesselung regressiv. Kein Umbau der allgemeinen Ergebnislogik und keine pauschale vollständige P08-Abnahme. Als nächstes separate P08-Matrix für simultane HP0, Priorität HP gegen Kontrolle, Pendingzustände bei Ende, Folgequeue-Abbruch und beide Kontrollserien vervollständigen. P10 danach automatischer Ressourcen-/Kandidaten-/Taktikcontroller. P09 UI, P11 vollständiger Rohlog-/Replayvertrag, P12 Produkt-/Sammlungsintegration bleiben später.

100 Karten sind nun auch in gemischten Ketten im isolierten Kernel regelkonform ausführbar; das ist keine Aktivierung in der produktiven Arena, keine KI-/vollständige Match-API-/Plattformfreigabe. Native iPhone-/Android-Geräte wurden nicht getestet. Die vorhandene Browser-QA prüft die unveränderte Produktoberfläche, **nicht** eine bereits integrierte Legacy-Webarena. Die vorhandenen Exportfilter schließen tests und Legacy-JSON aus; keine heimliche Änderung dieser Produktionsfilter.

## Reproduktion und sichere Integration

```bash
bash tools/test_legacy.sh
node tools/legacy/generate_p07.cjs          # byte check, kein Überschreiben
node tools/legacy/generate_p07_edges.cjs    # byte check
DISPLAY=:99 LP_NUM_THREADS=2 bash tools/test.sh
# Nach lokalem Web-QA-Export und HTTP-Server, nicht gegen Pages:
NODE_PATH="$PWD/work/qa-browser/node_modules" PLAYWRIGHT_BROWSERS_PATH="$PWD/work/qa-browser/browsers" PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 EXPECTED_COMMIT="<SHA des frisch getesteten Exports>" node tools/browser_qa.cjs
```

Neuer PR gegen `feature/legacy-engine-p05-p06`, ausdrücklich abhängig von #5 → #4 → #2. Nach tatsächlicher Integration retargeten; bei Squash nur eigene Folgecommits transplantieren und Tests wiederholen. Sicherheits-PR #6 separat, seine Entfernung automatischen Publishings und Freigabecheckliste dürfen nicht überschrieben werden. Keine bestehenden PRs mergen, kein Auto-Merge, kein Deployment/Dispatch und keine Settingsänderung aus diesem Auftrag.
