# ORAFOLD Alpha 0.1 – Integrationsgrenze vor dem ersten Merge

Stand: 2026-11-09. Der neue Masterauftrag erlaubt Integration und genau einen getesteten Alpha-Release, verlangt aber ausdrücklich einen Halt, wenn erforderliche GitHub-Einstellungen/Freigaben nicht eingerichtet werden können. **Diese Grenze wurde erreicht. Keine PRs gemergt, keine Alpha veröffentlicht.** Dieser Bericht ist ein Nachtrag in Sicherheits-PR #6, kein neuer Dokumentations-PR und keine vermeintliche Alpha-Implementierung.

## Tatsächlich ausgeführte Arbeit

- Aktuelle Heads, Zielbranches, Mergeability und CI aller sieben offenen PRs frisch gelesen. Vor diesem Dokumentationsnachtrag alle MERGEABLE und alle erforderlichen vorhandenen Läufe SUCCESS; Deployjobs SKIPPED. #5/#7 weiterhin Entwurf. [Snapshot](evidence/preflight/pr-status.json).
- PR #6 bei c37a244 und #7 bei 023a0e0 einschließlich ihrer zuletzt noch laufenden Web-QA inzwischen erfolgreich. Diese vorhandenen Läufe wurden geprüft, nicht als in diesem Schritt neu ausgeführte Tests ausgegeben. Der historische Legacy-Nachweis bleibt 1280 Differentialfälle / 28 Node-Gruppen; die lokalen Touch-/Shutdownfehler aus #7 bleiben offen.
- Alten automatischen Publisher `.github/workflows/web-preview.yml`, Workflow-ID406254158, per autorisiertem PUT disable **erfolgreich deaktiviert** und Status `disabled_manually` nachgelesen. [Beleg](evidence/preflight/publisher-after.json). Keine laufenden/queued develop-Runs in der abgefragten Liste. Keine neue Veröffentlichung. Nicht wieder aktivieren, solange develop noch den automatischen Publishjob enthält.
- Environment-Konfiguration mit erforderlichem tatsächlichem Reviewer und Self-Review-Sperre versucht: **HTTP403 Resource not accessible by integration**. Nicht angewendet. Actions-Einstellungen, Releasevariable und develop-Branchschutz ebenfalls HTTP403. [Zugriffsprüfungen](evidence/preflight/access-results.json), [abgelehnter Schreibversuch](evidence/preflight/environment-write-result.json).
- github-pages nach dem Versuch unverändert: keine required reviewers, Admin-Bypass erlaubt, main und develop als Deploymentbranches. Pages steht bereits auf Workflowmodus. Defaultbranch ist main. [Environment](evidence/preflight/environment-after.json), [Branches](evidence/preflight/branch-policies.json).

Der alte Publisher ist eingefroren. **Das ist noch keine vollständig eingerichtete Releasekontrolle.** Es gab keinen Merge, keinen Release-Dispatch, keinen Settings-Bypass, keine neue Alpha-Karte und keine Änderung an Spielregeln/Assets. Die Live-Adresse wurde in diesem Schritt nicht ersetzt oder als neue Alpha getestet. Der zuletzt abgefragte Deploymentdatensatz zeigte SHA1d248153e27f87786b3219c69bf827825756ed84; das ist kein neuer Live-Browser-/Build-Integritätsnachweis.

## Exakte manuelle Schritte durch einen Repository-Administrator

1. **Publisher eingefroren lassen:** [Actions / Godot Web Preview](https://github.com/Jagarex-lab/nachtsiegel-app/actions/workflows/web-preview.yml). Status disabled lassen. Unter Actions sowie Environment-Deployments prüfen, dass keine alten wartenden/running Publisher nachträglich veröffentlichen können. Nicht pauschal wieder aktivieren.
2. **Environment schützen:** [Settings / Environments](https://github.com/Jagarex-lab/nachtsiegel-app/settings/environments) → github-pages → Required reviewers aktivieren und tatsächlich berechtigten Reviewer benennen; Prevent self-review aktivieren; Allow administrators to bypass configured protection rules deaktivieren. Falls GitHub-Plan/Repository diese Optionen nicht anbietet, diese Grenze melden, keinen schwächeren Ersatz stillschweigend verwenden.
3. **Identitäten beachten:** Die bisherigen CI-Läufe und PRs laufen als Jagarex-lab. Startet auch der Release als Jagarex-lab, kann dieses Konto bei aktiver Self-Review-Sperre nicht zugleich den eigenen Release freigeben. Ein anderes tatsächlich berechtigtes Reviewerkonto oder eine getrennte legitime Dispatcheridentität ist erforderlich. Keine erfundene Person und kein Token in den Chat. Einziger Spieltester zu sein ersetzt diese technische Freigabe nicht.
4. **Deploymentbranches:** Im selben Environment Deployment branches and tags → Selected branches/tags → ausschließlich Branch develop. main und alle Tags/Wildcards entfernen.
5. **Pages prüfen:** [Settings / Pages](https://github.com/Jagarex-lab/nachtsiegel-app/settings/pages) → Source GitHub Actions beibehalten. Kein Deploy-from-branch und keine gh-pages-Abkürzung.
6. **Workflow verfügbar machen:** Nach Eigentümerentscheidung entweder [Settings / Branches](https://github.com/Jagarex-lab/nachtsiegel-app/settings/branches) → Default branch auf develop setzen, oder später denselben geprüften Releaseworkflow/Guard über separat freigegebenen Prozess auf main bereitstellen. Der neue manuelle Workflow aus #6 muss auf dem Defaultbranch vorhanden sein; keine verdeckte main-Änderung. Beim Release trotzdem Ref develop wählen.
7. **Branch-/Actions-Regeln prüfen:** [Rulesets](https://github.com/Jagarex-lab/nachtsiegel-app/settings/rules) bzw. Branch protection für develop: erforderliche Checks/Reviews tatsächlich durchsetzen, direkte unreviewte Pushes/Forcepush/Bypass verhindern. Bestehende Reviewpflicht nicht umgehen; wenn nötig echten zweiten Reviewer benennen. [Actions / General](https://github.com/Jagarex-lab/nachtsiegel-app/settings/actions) → Default Workflow permissions read-only, Actions darf PRs nicht selbst genehmigen. Workflowautoren und Apps/PATs/alternative Publisher prüfen; CODEOWNERS allein schützt keine Feature-Push-Workflows. Details im [Sicherheitsbericht](../release/PAGES_RELEASE_SAFETY.md).
8. **Release-Schalter auslassen:** [Actions variables](https://github.com/Jagarex-lab/nachtsiegel-app/settings/variables/actions) → PAGES_RELEASE_ENABLED nicht setzen oder false lassen. Nicht jetzt auf true setzen; weder Alpha noch integrierter Stand sind abgenommen.
9. Änderungen bestätigen bzw. Zugriff für deren read-only-Nachprüfung ermöglichen. Bei weiterhin unlesbaren Schutzwerten Einstellungen sichtbar nachweisen; fehlenden Beleg nicht als aktive Sperre ausgeben. Keine bloße erneute allgemeine Mergefreigabe nötig: diese ist im Masterauftrag bereits enthalten. Benötigt werden wirksame Einstellungen und später die echte Environmentfreigabe.

## Konkrete Fortsetzung nach verifiziertem Schutz

1. Erneut Heads/CI/Konflikte/Settings prüfen; #6 zuerst nach develop integrieren, automatische Publishschritte müssen entfernt bleiben. Danach reinen CI-Workflow kontrolliert wieder aktivieren. Erster develop-Push muss QA ohne Pages-Publisher ausführen. Release-Schalter bleibt aus.
2. #1 → #2 → #4 → #5 → #7 integrieren, nach Elternintegration gestapelte PRs retargeten und bei Squash nur eigene Folgecommits transplantieren; #3 getrennt als Architektur erhalten. Auditdateien byteweise deduplizieren. Merge-SHAs protokollieren. Drafts/Reviewpflichten nicht unbesehen aufheben.
3. M1: Legacy P08/P10 vervollständigen, P09-Bedienung, lokaler Deckbuilder/P12 und nachvollziehbares Replay/P11; bekannte Input-/Shutdownbefunde diagnostizieren. Gegen fixierten Oracle und vollständig integriertem Stand prüfen.
4. M2–M4: getrenntes Alpha-Regelprofil, Ursprung/Mulligan/Zweite Möglichkeit/Konvergenz, echte Karten/Relikte/Ereignisse, vier legale 30-Karten-Starter, KI und responsive UI implementieren. Keine 550-Karten-Attrappe. Umfang des wirklich funktionsfähigen Pools offen ausweisen.
5. M5: alle Pflichtprüfungen und Simulationen, exaktes getestetes Artefakt/SHA/Version; erst dann manuell freigegebener Alpha-Release mit echter Environmentprüfung und anschließender Live-QA. Kein Release bei fehlgeschlagenem Pflicht-Test.

## Status der angeforderten Alpha

| Ergebnis | Tatsächlicher Stand |
|---|---|
| Integrierte PRs / neue Mergecommits | Keine |
| Neue ORAFOLD-Karten / vier Alpha-Starter | 0 / nicht implementiert |
| Alpha-KI / Ursprung / Konvergenz / Relikte / Deckbuilder | Noch nicht implementiert |
| Legacy-Basis | Offener geprüfter P07-Branch; kein integrierter vollständiger Legacy-Modus |
| Neue Balance-/Alpha-Testbehauptungen | Keine |
| Veröffentlichung / neuer Release-SHA | Nein / keiner |

Die übrigen sechs Alpha-Dokumente werden mit der entsprechenden Implementierung erstellt, nicht als leere Fertigstellungsnachweise. Dieser Halt folgt Abschnitt1.1/16 des Masterauftrags und ist keine Behauptung eines fertigen Meilensteins oder Releases.
