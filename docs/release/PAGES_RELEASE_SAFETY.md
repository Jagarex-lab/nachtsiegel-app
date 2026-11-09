# Pages: CI getrennt von ausdrücklich freigegebenen Releases

Stand: 2026-11-09. **Nur Implementierungs-PR gegen develop. Keine Einstellungen geändert, kein Merge, kein Dispatch, keine Veröffentlichung. Der Schutz ist im bestehenden Repository noch NICHT aktiviert.** Bis zur genehmigten Integration läuft dort weiterhin der alte automatische Veröffentlichungspfad.

## Bestandsaufnahme und Grenzen

Vorher: `web-preview.yml` testet/exportiert bei develop-/Feature-Push, PR nach develop und manuellem Dispatch. Bei Ref develop und Nicht-PR lädt derselbe Workflow ein Pages-Artefakt hoch und veröffentlicht mit pages:write/id-token:write. Sowohl ein Merge als auch direkter Push oder manueller develop-Dispatch kann daher veröffentlichen. Tags sind nicht abonniert. Der separate Legacy-Workflow besitzt keinen Deployjob. Keine workflow_run/repository_dispatch/release/workflow_call- oder Shell-/gh-pages-Publisher im untersuchten develop-/Feature-Quellbaum gefunden. origin/main enthält derzeit keine .github-Workflows; die Actions-API kennt die zwei historischen CI-Workflows. Ein neuer Workflow auf einem Nicht-Defaultbranch ist nicht als dauerhaft dispatchbar vorauszusetzen.

Pages: `build_type=workflow`; die angezeigte source main / ist bei diesem Typ kein aktiver Branch-Publisher. Environment github-pages: nur branch_policy, **keine required reviewers**, `can_admins_bypass=true`, Branches **main und develop** erlaubt. [Read-only-Nachweise](evidence/). Defaultbranch main. Actions-Repository-/Tokenberechtigungen und develop-Branchprotection: API 403, daher nicht verifiziert. Keine stillschweigende Schutzbehauptung aufgrund fehlender Leserechte.

Dies schützt gegen versehentliche Veröffentlichung aus gewöhnlicher CI und unfreigegebenem Release, nicht gegen einen Repository-Administrator, der Schutzregeln bewusst entfernt, oder beliebige bereits kompromittierte externe PATs/Apps. Workflow-Autoren, Actions-Abhängigkeiten und Admins bleiben Vertrauensgrenzen. App-/PAT-/Deploy-Key-, Webhook- und Drittanbieter-Publisher müssen zusätzlich durch den Eigentümer inventarisiert werden; diese Inventur ist hier nicht vollständig nachgewiesen.

## Implementierung

- `web-preview.yml`: unveränderte QA/Export-/Browserprüfungen und gewöhnliches QA-Artefakt; keinerlei Pages-Artefaktupload, Publishjob, Pages-/OIDC-Schreibrecht mehr. Push, PR und CI-Dispatch veröffentlichen nie.
- `pages-release.yml`: ausschließlich workflow_dispatch, ausschließlich develop, Repositoryvariable `PAGES_RELEASE_ENABLED` muss exakt `true` sein (fehlend/false ist aus). Vollständiger SHA und Bestätigung `PUBLISH <SHA>`, numerische QA-Run-ID erforderlich. Keine Tag-/Push-/Release-/Completion-Trigger.
- Read-only-Preflight prüft live: exakt aktueller develop-HEAD = Dispatch-SHA = eingegebener SHA; erfolgreiche abgeschlossene **develop-Push**-Web-QA desselben SHA/Repositories/Workflowpfads; genau ein nicht abgelaufenes QA-Artefakt. Keine fremden Runs, PR-Mergecommits, nicht bestandenen oder laufenden Tests.
- Reale Reviewer müssen konfiguriert sein, Self-Review und Admin-Bypass gesperrt, nur develop als branch zugelassen; Pages muss Workflowmodus sein. Fehlende Felder, HTTP403 oder andere API-Fehler brechen ab. API-Lesbarkeit mit dem begrenzten GITHUB_TOKEN ist noch nicht in einem Release ausgeführt; bei 403 bleibt Release blockiert. Keine PAT-Ausweichlösung.
- Separater publish-Job benötigt preflight success und github-pages-Environmentfreigabe. Nach Freigabe werden alle API-/SHA-/Schalterbedingungen erneut geprüft. Ein während der Wartezeit fortgeschrittener develop-HEAD sperrt den alten Kandidaten.
- Nur dieser Job erhält pages:write und id-token:write. Er lädt das **bereits getestete** QA-Artefakt aus der benannten Run-ID; kein Rebuild nach Freigabe. build-info muss SHA und Kanal develop bestätigen, Symlinks werden abgelehnt, Dateien mit SHA256 protokolliert. Deploy-Abhängigkeiten auf Commit-SHAs fixiert. Globale Release-Concurrency ohne Cancel verhindert parallele manuelle Publisher; sie schützt nicht vor alten bereits gestarteten Workflowversionen.
- AGENTS.md: ältere generelle Auto-Publish-Erlaubnis durch expliziten Merge-/Releasevorbehalt ersetzt. Kein Änderungen an Spielen/Assets/Regeln.

## Vor JEDEM ersten Merge erforderliche manuelle Checkliste

Alle Punkte benötigen ausdrückliche Eigentümerfreigabe; hier **nicht ausgeführt**:

- [ ] Alten Test-and-Publish-Workflow vor Integration wirksam deaktivieren; laufende/queued develop-Publishjobs und bereits auf Freigabe wartende Runs prüfen und stornieren. Nicht erst nach einem Merge reagieren. Offene PRs #1–#5 nicht mergen.
- [ ] github-pages: reale verantwortliche Reviewer benennen, required reviewers aktivieren, prevent self-review aktivieren, Admin-Bypass deaktivieren. GitHub verlangt typischerweise einen der benannten Reviewer; das ist keine Zweipersonen-Reviewquorum-Behauptung. Falls der Plan Einstellungen nicht unterstützt, Release bleibt gesperrt.
- [ ] Environment ausschließlich selected branch `develop` erlauben; main, Tags und Wildcards entfernen.
- [ ] Pages Source dauerhaft GitHub Actions / workflow, kein Deploy-from-branch. Branch-Publisher/gh-pages und alternative Deploy-Apps/PATs/Keys/Webhooks ausschließen bzw. separat sperren.
- [ ] Default-Workflow-Verfügbarkeit herstellen: entweder Defaultbranch nach ausdrücklicher Freigabe auf develop setzen **oder** denselben geprüften Release-/Safety-Workflow und Guard über einen eigens freigegebenen Prozess auf main bringen. Kein verstecktes main-Update. Dispatch muss anschließend ausdrücklich **develop** wählen; main wird abgelehnt.
- [ ] Rulesets/Branchschutz für develop und relevante Workflowzweige: kein direkter unreviewter Push, kein Forcepush/Bypass, erforderliche Reviews und CI; CODEOWNERS für `.github/workflows/`, `tools/release/`, `tests/release/`, `AGENTS.md` mit tatsächlich schreibberechtigten Releaseverantwortlichen einrichten und Reviewpflicht aktivieren. Besitzer/Team nicht erfunden. Actions-/Token-Default auf read-only, Actions-PR-Freigaberecht deaktivieren; App-/Bot-Bypässe prüfen.
- [ ] Automatisierte Safety-CI als Pflichtcheck einrichten. Sie ist Regressionserkennung, keine Sicherheit gegen Administratoren oder Autoren, die Workflow und Test zugleich entfernen können.
- [ ] Diesen PR ausdrücklich freigeben und separat integrieren; QA/Legacy-PRs bleiben davon unberührt. Diff-/Konfliktprüfung bei späteren Integrationen darf den entfernten Publishjob nicht wiederherstellen.
- [ ] Geänderten reinen CI-Workflow wieder aktivieren, neue develop-Push-CI erfolgreich abschließen lassen. Dabei darf kein Deployjob/Pages-Artefakt entstehen.
- [ ] `PAGES_RELEASE_ENABLED` **nicht setzen oder false lassen**; erster produktiver Release ist weiterhin NICHT autorisiert. Erst nach bestätigten Einstellungen und gesonderter Releasefreigabe zeitweise auf true setzen.
- [ ] Repository-/Environment-Einstellungen erneut read-only exportieren und gegen Guard prüfen. Gegenwärtige Belege sind Vorherzustand, keine abgeschlossene Konfiguration.

## Freigabe und Veröffentlichung (hier nicht ausgeführt)

1. Auftraggeber genehmigt exakt einen SHA nach erfolgtem Merge und vollständig grünem develop-Push-QA. Erfolgreiche Run-ID und QA-Artefakt prüfen; kein Branchname als Versionsersatz.
2. Berechtigter Releaseverantwortlicher aktiviert nach Genehmigung den Schalter und startet **Manual production Pages release**, Ref develop, SHA, QA-Run-ID, Bestätigung `PUBLISH <SHA>`. Kein ausgelöster Release durch bloßes Setzen der Variable.
3. Zweite berechtigte Person prüft Run/SHA/CI und genehmigt Environment; Initiator darf nicht selbst freigeben. Preflight ist noch keine Releasefreigabe. Keine Freigabe für falschen/veralteten Commit.
4. Job veröffentlicht einmal das getestete Artefakt. Anschließend öffentliche URL/build-info und vorhandene Touch-/Browser-QA read-only überprüfen; Ergebnisse archivieren. Ein grüner Deployjob allein beweist keinen gesunden Spielbetrieb. Freigabevariable danach wieder false.

## Sicherer Rollback

Vor Veröffentlichung: abbrechen/ablehnen, Schalter false, queued Runs prüfen; Live-Version bleibt unverändert. Einstellungen- oder Workflowrollback darf **niemals** den alten automatischen Publisher wieder aktivieren.

Nach einer separat genehmigten Veröffentlichung: Schalter false und weitere Releases stoppen. Letzten funktionierenden Spielstand als reviewbaren Revert-PR gegen develop vorbereiten; manuelle Mergefreigabe, vollständige neue QA für den neuen HEAD, danach **eigene Rollback-Releasefreigabe** mit neuem SHA/Run und derselben Environmentprüfung. Kein automatischer Rollback-Deploy, kein Forcepush, kein Deployment eines alten ungeprüften Artefakts, keine branch-basierte Pages-Abkürzung. Bei Sicherheitsmängeln den Releaseworkflow deaktiviert lassen; Dienstabschaltung wäre ebenfalls gesondert zu genehmigen.

## Tests und Aussagegrenzen

`python3 -m unittest discover -s tests/release -v` mit Python3/PyYAML6.0.3: **6 Testgruppen bestanden**, einschließlich 90 Event/Ref/Schalterkombinationen, 6 ungültiger Eingabekontexte, 20 schwächerer Einstellungen/QA-Negativfälle sowie statischer Privileg-/Triggerprüfung aller Workflows. [Log](evidence/tests.log). Es wurden keine Settings geschrieben, keine Workflow-Dispatches ausgelöst, keine Artefakte in Pages hochgeladen und keine Deploy-API aufgerufen. Kein echter End-to-End-Release behauptet; eine tatsächliche Reviewerfreigabe und Token-Lesbarkeit können ohne freigegebenen Release nicht als erfolgreich getestet gelten.

### CI-Nachtrag

Quellcommit `8722076`: Sicherheits-CI [42679644472](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42679644472) und [42679657468](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42679657468) SUCCESS; vollständige unveränderte Desktop-/Export-/Chromium-/WebKit-QA [42679657438](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42679657438) SUCCESS. Dieser Lauf besitzt bereits keinen Deployjob mehr. Das ist kein Nachweis aktivierter Repository-Schutzregeln. Nachtrag ergänzt ausschließlich `pages:read` im Read-only-Preflight, damit die Pages-Metadatenabfrage ein explizites Leserecht besitzt, und wiederholt die sechs lokalen Safety-Gruppen erfolgreich. Der Publishjob allein behält Pages-/OIDC-Schreibrecht.

Die tatsächlichen gelesenen Environment-/Pages-/Branch-Policy-Snapshots wurden zusätzlich durch den Guard validiert: **abgelehnt, required reviewers missing** ([Log](evidence/current-settings-denial.log)). Der übrige Kandidaten-/QA-Kontext war dafür synthetisch gültig; kein echter Release-/Token-Integrationstest behauptet.
