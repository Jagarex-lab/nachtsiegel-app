# Integrationsprüfung PR #1–#4

Stand 2026-11-09. **Keine PRs gemergt, keine Remote-Branches umgeschrieben, kein Deployment und im Prüfschritt keine Workflow-/Environment-Konfiguration geändert. Der spätere P05/P06-Folgecommit ergänzt ausschließlich den nicht deployenden Legacy-Testworkflow um seinen gestapelten Basisbranch; der Pages-Publishworkflow und Environmenteinstellungen bleiben unangetastet.** Eine ausdrückliche Mergefreigabe steht aus. Der anschließend beauftragte P05/P06-Branch basiert separat auf PR #4; diese Prüfung verändert dessen alte Commits nicht.

## Geprüfte Ausgangspunkte und Entscheidung

`develop`: `b1f5ea59a4754bac19df31e279bff8a295cb6ea8`.

| PR | Head / Commits gegenüber Basis | Basis / Dateien | GitHub-Status und CI | Fachliche Empfehlung |
|---|---|---|---|---|
| [#1](https://github.com/Jagarex-lab/nachtsiegel-app/pull/1) | `51ad544087dba200846b4420e493fcbe656c634f`,1 | develop /30 | OPEN, MERGEABLE/CLEAN; QA SUCCESS, Deploy SKIPPED | Dokumentation fachlich freigabefähig; rein historische Paritätsbestandsaufnahme |
| [#2](https://github.com/Jagarex-lab/nachtsiegel-app/pull/2) | `2ff70549d3c5e1c95f4b54c7990acd4d8970363d`,2 | develop /84 | OPEN, MERGEABLE/CLEAN; Legacy-CI und beide QA-Läufe SUCCESS, Deploy SKIPPED | Grundlagen fachlich freigabefähig;100 Datenkarten sind noch keine100 implementierten Kampfeffekte |
| [#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4) | `e36c9262b3854518afe6ced02f74ae130c1adbde`,1 | feature/legacy-foundations /48 | OPEN, MERGEABLE/CLEAN; Legacy-CI und QA SUCCESS, Deploy SKIPPED | Freigabefähig **als begrenzter P01–P04-Kernel**, nicht als vollständige JS-Kampfengine; P05/P06/P07/P10/P11-Grenzen und defensive Raw-API-Abweichungen sind dokumentiert |
| [#3](https://github.com/Jagarex-lab/nachtsiegel-app/pull/3) | `d3634b462444760665ba169dcd2be7df86baddfe`,1 | develop /13 | OPEN, MERGEABLE/CLEAN; QA SUCCESS, Deploy SKIPPED | Separat fachlich freigabefähige Architektur, keine implementierte Wirtschaft. Mermaid nicht gerendert, Rechtslinks keine abgeschlossene Rechtsprüfung |

**Tatsächliche Mergefreigabe: für alle vier PRs derzeit NEIN unter der Vorgabe „kein Deployment“.** Grund ist der vorhandene develop-Publishpfad, nicht ein festgestellter Karten-/Kampfregelfehler. Auch nach Lösung dieses Blockers erst nach ausdrücklicher Freigabe des Auftraggebers mergen.

## Dokumentübernahme und lokale Integrationssimulation

Alle30 versionierten Dateien aus `docs/migration/` von PR #1 gegen PR #2 byteweise verglichen: **vollständig identisch**. PR #2 übernimmt diese Dateien bewusst als Kopie, nicht als Git-Abhängigkeit des Auditcommits. Kein zweites Auditverzeichnis und keine widersprüchliche Kopie anlegen. Die spätere Historienannotation in PR #4 ist gewollt und erfolgt erst nach dieser unveränderten Übernahme.

Mit `git merge-tree --write-tree` und nicht referenzierten lokalen `git commit-tree`-Objekten Reihenfolge **#1 → #2 → #4 → #3** geprüft: alle vier Schritte konfliktfrei. Kein Worktree-/Indexmerge, kein Branchref auf diese Simulation, keine PR-/Remoteänderung. Baum-/Commitobjekte und Schutzdateiliste stehen in [simulation.json](integration-review/simulation.json). Aktuelle GitHub-Mergeability und simulierte spätere Mergefolge sind unterschiedliche Nachweise.

Der resultierende kombinierte Baum erhält byteidentisch: Arena, Prototyp-Kampfmodell, sieben Prototypkarten, Projekt-/Exportkonfiguration und Pages-Workflow. PR #1/#3 sind Dokumentation; PR #2 ergänzt isolierte Katalog-/Testdaten; PR #4 ergänzt isolierten Kernel und Legacy-Testworkflow. Es gibt keine produktive UI-/Regelaktivierung. Neue Legacy-JSON-Ressourcen sind noch nicht als produktiv gepackte API abgenommen. Keine Abweichung als heimlicher Name-/Lore-/Balancewechsel gefunden.

## Deploymentblocker — konkret überprüft

`.github/workflows/web-preview.yml` reagiert auf Push nach `develop` und `feature/**`. Die Jobschritte zum Pages-Artefaktupload sowie `deploy` haben Bedingung:

```yaml
if: github.event_name != 'pull_request' && github.ref == 'refs/heads/develop'
```

Nach erfolgreichem Test-/Exportjob hat deploy `pages:write` und `id-token:write` und ruft `actions/deploy-pages@v4` auf. **Ein Merge in develop erzeugt den passenden Push, auch bei docs-only.** Ein manueller workflow_dispatch auf develop kann denselben Pfad erfüllen. Grüne PR-CI/Deploy-SKIPPED beweist keine Sperre beim Merge.

GitHub-Environment `github-pages` read-only abgefragt: custom branch policy aktiv; Schutzregel ausschließlich branch_policy, **keine required reviewers / Wartefreigabe** in der gelesenen Antwort. Auf keine unbewiesene manuelle Sperre vertrauen. Die separate Abfrage der develop-Branch-Protection scheiterte mit HTTP403 „Resource not accessible by integration“; ob Statuschecks/Reviews dort zwingend vorgeschrieben sind, konnte nicht verifiziert werden. Das ist keine Aussage, dass der Branch ungeschützt sei. [Read-only-Nachweise](integration-review/deployment-review.json). Der Legacy-Testworkflow hat dagegen nur contents:read und keinen Publishjob.

Vor Integration ohne Veröffentlichung eine **gesondert autorisierte und überprüfte** Maßnahme wählen: Publishworkflow während der Integration wirksam deaktivieren, oder einen expliziten standardmäßig ausgeschalteten Deploymentgate über einen eigenen freigegebenen Workflowchange einführen, oder eine tatsächlich wirksame Environmentfreigabe konfigurieren und jede Ausführung daran blockieren. Änderungen an Repoeinstellungen/Workflows wurden in diesem Prüfauftrag **nicht** vorgenommen. `[skip ci]`, spät gestartetes Canceln und Hoffnung auf Fehler sind kein belastbarer Schutz.

## Mergecheckliste und Retarget/Rebase

1. [ ] Aktuelle Heads/CI nach jeder Änderung erneut prüfen; PR #1–#4 bleiben bis zur Freigabe offen.
2. [ ] Deploymentblocker separat lösen und Wirksamkeit für develop-Push **und** workflow_dispatch prüfen; keine verdeckte Publikation auslösen.
3. [ ] Auftraggeber erteilt ausdrückliche Mergefreigabe für konkret benannte Heads und Reihenfolge.
4. [ ] PR #1 nach develop integrieren. PR #2 anschließend gegen diesen develop-Stand neu prüfen; identische Auditdateien nicht doppelt kopieren oder überschreiben. In der simulierten Folge kein Rebase erforderlich, bei zwischenzeitlichen Änderungen gegebenenfalls lokales Update und neue CI.
5. [ ] PR #2 nach develop integrieren. PR #4 **danach** von feature/legacy-foundations nach develop retargeten, Diff erneut auf ausschließlich Kernel-Folgeänderungen kontrollieren und vollständige Legacy-/Godot-CI neu ausführen.
6. [ ] Bei Squash/Rebase-Merge von #2 kann #4 sonst die bereits integrierten Elterncommits erneut zeigen. Dann nur den Kernel-Commitbereich transplantieren: sinngemäß `git rebase --onto origin/develop 2ff70549d3c5e1c95f4b54c7990acd4d8970363d <kernel-branch>`; vorher Sicherungsref, lokale Konflikt-/Diff-/Testprüfung und gesonderte Freigabe vor Remote-Umschreibung. Hier nicht ausgeführt.
7. [ ] PR #4 nach erfolgter Retarget-/CI-Abnahme integrieren. PR #3 ist unabhängig und kann separat vor/nach der Kernelkette folgen, braucht aber dieselbe Deploymentsperre und Freigabe. Kein F2P-Implementierungsclaim.
8. [ ] Ergebnisbaum/Schutzdateien und Pipelinezustand nach jedem Merge prüfen. Das ist keine Erlaubnis, die Live-Version zu veröffentlichen.

Ein neuer P05/P06-PR wird zunächst gegen den unveränderten Kernelbranch von #4 gestapelt. Erst nach dessen tatsächlicher Integration retargeten; bei Squash nur die eigenen Folgecommits rebasen. Nicht in offene Elternbranches mergen, nur um Abhängigkeiten vermeintlich aufzulösen.

## Tests, Risiken und Aussagegrenzen

Frisch auf dem **unveränderten PR-#4-Head vor P05/P06-Codeänderungen**: `tools/test_legacy.sh` erfolgreich mit15 Node-Testgruppen,2171 Grundlagen-/2099 Kernel-Assertions und370 Differentialfällen.72 Originalfälle explizit unsupported; kein Ganzpartie-/Replay-Paritätsclaim. Vorhandene GitHub-QA für alle vier Heads erfolgreich; eigene vollständige Desktop-Godot-Regression vor den Codeänderungen ebenfalls erfolgreich:9547 Assertions plus Audio/Kontrast. Der neue Folgeauftrag hat separate Nachweise im [P05/P06-Bericht](LEGACY_ENGINE_P05_P06.md). [Head-/CI-Abfrage](integration-review/pr-status.json), [unveränderter Legacy-Baselinelauf](integration-review/baseline-legacy.log), [produktiver Baselinelauf](integration-review/baseline-production.log).

Bei den zusätzlichen P05/P06-Ereignisprüfungen wurde eine Lücke in der typisierten Beobachtungsspur von #4 gefunden (Feldentfernung vor Ablage nicht separat protokolliert); die Kampf-/Endzustände waren korrekt. #4 behauptet kein P11-kompatibles Ereignisprotokoll. Der Folgebranch ergänzt diese Beobachtung für strengere Ereigniszustandsvergleiche.

Die historischen Upstreamfehler (20 statt25 START, unvollständiger UI-Mock, externe check.js-Eingabe fehlt), Raw-Queue-Härtung und before-AI-Grenzen von #4 sind bekannte Grenzen, keine neu entdeckte Produktionsregression. Audit-/Grundlagendokumente sind historische Nachweise; aktuelle Fortschrittsberichte dürfen ihre alten „offen“-Zeilen nicht als jetzigen Stand ausgeben.

Raum-/Zeit-/Monetarisierungsfunktionen sind nicht Bestandteil der Integration. Der aktuelle Quellstand verwendet weiterhin die vorhandene Markenidentitätskonfiguration; die im Folgeauftrag erwähnte Bezeichnung ORAFOLD wird weder als bereits vorhandener Produktname ausgegeben noch hier eingestellt.

**Freigabeempfehlung zusammengefasst:** #1/#2/#3 fachlich ja; #4 ja für seinen ausdrücklich begrenzten Kernelvertrag. Ausführung aller Merges blockiert bis Deploymentschutz und ausdrücklicher Mergefreigabe. Keine dieser Empfehlungen ist ein automatischer Mergeauftrag.
