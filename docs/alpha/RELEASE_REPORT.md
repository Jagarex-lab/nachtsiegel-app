# Alpha 0.1 – vorbereitet, nicht veröffentlicht

Stand:2026-11-09. Die neueste Nutzeranweisung autorisiert Implementierung, lokale Integration, Tests und Draft-PRs unabhängig von fehlenden Adminrechten. Sie verbietet develop-Merge, produktives Pages-Deployment und Sicherheitsänderungen. Der frühere administrative Implementierungshalt ist damit aufgehoben; die Releasegrenze bleibt bestehen.

## Lokale Integration

Draft-PR [#8](https://github.com/Jagarex-lab/nachtsiegel-app/pull/8), Branch `alpha/playable-0.1`, Basis develop. PR2→4→5→7 werden über PR7-Head `023a0e0` übernommen. Nur im Alpha-Branch lokal integriert: PR1 `c635e12`, PR6 `faea1cc`, PR3 `37d8fc5`. Auditdokumente aus PR1/2 sind identisch; der PR1-Merge erzeugte keine doppelten Baumdateien. Keine der bestehenden PRs wurde remote gemergt/retargetet. PR3 ist unabhängig,5 basiert auf4,7 auf5. Aktueller read-only GitHub-Snapshot im QA-Artefakt `pr-status-current.json`.

Develop bleibt `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`. Main und andere Repositories wurden nicht geändert. Es gab keinen Release-Dispatch, keine Pagesveröffentlichung und keine neue öffentliche Alpha-URL.

## Testbuild

`tools/build_alpha.sh` exportiert Godot4.6.3-Preset `Alpha Web QA` nach `work/alpha/web`. `build-info.json` bindet Sourcecommit, Version und beide Ruleset-IDs. Startet direkt im Alpha-Einstieg; das Archiv ist separat erreichbar. Für lokale Exporttemplates XDG_DATA_HOME setzen; CI behält die vom Godot-Setup installierte Standardposition.

Lokal starten: `python3 -m http.server 8788 --bind 127.0.0.1 --directory work/alpha/web`, dann `http://127.0.0.1:8788/`. HTTP erforderlich, nicht index.html als file öffnen. Der Testserver bindet nur localhost. Das Buildarchiv und QA-Nachweise werden über den Draft-PR/Actions als **Artefakt**, nicht über Pages bereitgestellt. Exakte SHA und Prüfsummen stehen im Artefaktmanifest.

## Sicherheit bleibt unverändert

Alter Publisher Workflow-ID406254158 bleibt `disabled_manually`. Workflowquelle im Alpha-Branch enthält nur Tests/Artefakte und keine Pages-Schreibberechtigung. Neue `alpha-qa.yml` ist ebenfalls read-only und veröffentlicht ausschließlich Actions-Testartefakte. Manuelles `pages-release.yml`/Guard aus PR6 bleibt geschützt und wurde nicht ausgeführt oder abgeschwächt. Der zukünftige CI-Artefaktpfad enthält erst nach Archiv- und Alpha-QA den Alpha-Web-Build; kein ungeprüfter alternativer Publisher.

Die historischen read-only/abgelehnten Admin-Prüfungen sind unverändert unter `evidence/preflight/` erhalten. Keine neuen Sicherheitseinstellungen gesetzt. Fehlende Reviewer/Self-review-Sperre/Branchschutz sind **kein Entwicklungsblocker**, bleiben aber Releasevoraussetzungen. Vollständigen Schutz nicht behaupten.

## Spätere Freigabecheckliste

1. Aktuellen Source-/Artefakt-SHA und alle Pflicht-QA prüfen; offene Pflichtfehler beheben. Draftreview abschließen.
2. Ausdrückliche neue Integration-/Releasefreigabe einholen. Erst dann PR-Abhängigkeiten auflösen und kontrolliert nach develop integrieren; keine bestehende Reviewpflicht umgehen.
3. Admin verifiziert required reviewer, prevent self-review, kein Adminbypass, ausschließlich develop als Deploymentbranch, Actions read-only, PagesSourceActions und Branchschutz. Ablauf in `docs/release/PAGES_RELEASE_SAFETY.md`.
4. Alter automatischer Publisher bleibt aus, bis der rein testende Workflow tatsächlich in develop liegt; keine automatische Veröffentlichung reaktivieren. Releaseworkflow auf Defaultbranch über separat genehmigten Prozess bereitstellen.
5. Erst nach bestätigtem Schutz Releasevariable und manuellen Release für exakt getesteten develop-SHA freigeben; tatsächlicher zweiter Reviewer nötig, wenn Dispatcher nicht selbst reviewen darf.
6. Echtes geschütztes Deployment und Live-Integritäts-/Browserprüfung erst PhaseB. Vorherige öffentliche Testversion bleibt unverändert.

Rollback: vor Veröffentlichung schlicht Alpha-PR nicht mergen/Featurebranch weiterführen. Nach einem späteren Release ausschließlich vorheriges bekannt gutes getestetes Artefakt über denselben geschützten manuellen Prozess freigeben; keine gh-pages-Abkürzung, kein Forcepush und kein pauschales Wiedereinschalten des alten Publishers.
