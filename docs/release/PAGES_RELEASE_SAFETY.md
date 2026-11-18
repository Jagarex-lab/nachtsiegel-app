# Automatischer Pages-Release im Alpha-Betrieb

Der Owner hat die automatische Veröffentlichung der Alpha-Testversion von `develop` ausdrücklich freigegeben. Diese Freigabe ersetzt die frühere manuelle Veröffentlichungssperre und die vorbereitete Ein-Klick-Policy. Bestehende GitHub-Branch-, Review- und Environment-Schutzregeln bleiben verbindlich. Vor einer kommerziellen Veröffentlichung muss die Releasepolicy erneut geprüft werden.

## Freigabe und regulärer Merge

Owner-freigegebene PRs dürfen regulär integriert werden, sobald sämtliche erforderlichen Checks auf dem aktuellen, erwarteten PR-Head erfolgreich sind. Die aktuelle stehende Owner-Freigabe umfasst Codex-Arbeiten innerhalb des beauftragten Umfangs; dafür ist keine weitere Rückfrage vor einem zulässigen Merge erforderlich. Unmittelbar vor dem Merge müssen Head-SHA und Checks erneut übereinstimmen. Keine Admin-Umgehung, kein GitHub Native Auto-Merge, kein privilegierter Dienst zum automatischen Mergen beliebiger PRs und keine Änderung von Repository- oder Environment-Einstellungen gehören zu diesem Ablauf.

Ein regulärer Merge durch den Owner oder eine autorisierte GitHub App erzeugt den `develop`-Push, auf dem die vollständige QA erneut läuft. Ein ausschließlich mit `GITHUB_TOKEN` ausgeführter Merge unterdrückt nachfolgende Push-Workflows und wird nicht unterstützt. Fehlende Post-Merge-QA blockiert den Release; ein zusätzlicher Token oder alternativer Publisher ist kein Ausweg.

## Ablauf und Pflichtnachweise

1. Der einzige aktive Publisher ist `.github/workflows/pages-release.yml`. Erfolgreiche abgeschlossene `push`-Läufe einer der sieben nachstehenden QA-Suiten auf `develop` können seinen `workflow_run`-Pfad starten. Das Workflow-Event muss aus dem eigenen Repository stammen; der Publisher läuft ausschließlich auf dem Defaultbranch `develop`. Der Trigger allein ist noch keine Veröffentlichung.
2. Der Read-only-Preflight validiert Event, Repository, Quellbranch und tatsächlichen API-Run. `candidate.py select` ermittelt den aktuellen `develop`-HEAD und verlangt die jüngsten passenden erfolgreichen Post-Merge-Push-Läufe aller sieben Suiten auf genau diesem Commit. Läufe von PRs, Forks, Tags oder anderen Branches werden abgewiesen. Fehlt eine Suite noch oder läuft sie noch, lautet das Ergebnis `ready=false`: Dieser frühe Trigger veröffentlicht nichts. Ein späterer erfolgreicher Suiteabschluss kann erneut prüfen. API- und Integritätsfehler bleiben Fehler.
3. Alle 29 benannten Pflichtjobs sowie zusätzlich vorhandene Jobs müssen erfolgreich abgeschlossen sein. Kein Rückgriff auf einen älteren grünen Lauf, wenn ein neuerer Versuch läuft oder fehlgeschlagen ist. Run-ID, Versuch, Commit und Jobidentitäten werden im Kandidaten festgehalten.
4. Genau ein nicht abgelaufenes `nachtsiegel-arena-qa`-Artefakt der vollständigen Main-QA muss Run und SHA zugeordnet sein und einen unveränderlichen v4-SHA256-Digest besitzen. Veröffentlicht werden diese getesteten Bytes; im Release wird kein Spielbuild erstellt.
5. Erst bei `ready=true` erreicht der Publish-Job das bestehende Environment `github-pages`. GitHub setzt dessen aktive Reviewer-, Timer- und Branchregeln durch. Der Prozess verändert diese Regeln nicht und verlangt keine zusätzliche zweite Identität. Nach dem Environment-Gate wird der vollständige Kandidat erneut geprüft.
6. Beim Download werden ZIP-Digest, Bytezahl und sichere Archivpfade geprüft. Nur `build/web/` wird entpackt; Commit und Kanal aus `build-info.json` müssen stimmen. Der Release ergänzt `release-evidence.json` mit Kandidat und Ressourcenhashes. Sein SHA256 über die unveränderten Rohbytes wird separat als Job-Output an die öffentliche Prüfung übergeben. Unmittelbar vor dem Deployment erfolgt eine weitere vollständige Kandidatenprüfung.
7. Nach dem Deployment prüft ein separater Read-only-Job die tatsächliche öffentliche URL: zunächst den erwarteten SHA256 der rohen `release-evidence.json`, danach deren Inhalt, Commit, Provenienz und die SHA256-Hashes der ausgelieferten Spielressourcen. Chromium und WebKit müssen das tatsächliche Spiel bis zum Hauptmenü und allen vier Startern öffnen. Ergebnisdaten und Screenshots bleiben als Releaseartefakt erhalten. Erst mit erfolgreicher öffentlicher Prüfung gilt die Veröffentlichung als verifiziert.

| Post-Merge-Suite | Pflichtjobs |
| --- | ---: |
| `NACHTSIEGEL CI (no deployment)` | 20 |
| `ORAFOLD isolated Alpha QA (no deployment)` | 4 |
| `Release safety (no deployment)` | 1 |
| `Legacy P01-P07 (no deployment)` | 1 |
| `ORAFOLD isolated economy QA (no deployment)` | 1 |
| `ORAFOLD campaign QA (no deployment)` | 1 |
| `ORAFOLD online authority integration QA (no deployment)` | 1 |

Als Wiederanlauf steht `workflow_dispatch` auf `develop` ohne Eingabefelder zur Verfügung. Dieser Weg verwendet dieselbe Kandidatenwahl, sämtliche Post-Merge-Pflichtnachweise und dieselben Schutzregeln; manuelle SHAs, Run-IDs oder Bestätigungstexte können keine Nachweise ersetzen. Featurebranches, PR-Refs, Tags und `main` sind keine Releasepfade.

## Rechte und bestehende GitHub-Konfiguration

Pages muss GitHub Actions verwenden; das vorhandene Environment `github-pages` muss `develop` erlauben. Der Workflow muss auf dem Defaultbranch `develop` verfügbar sein. Die Implementierung verändert keine dieser Einstellungen. Fehlende Berechtigungen oder unpassende Einstellungen führen zur Ablehnung und werden nicht stillschweigend korrigiert.

Workflowweit gilt `contents: read`. Der Preflight liest zusätzlich Actions und Pages. Nur der Publish-Job besitzt `pages: write` und `id-token: write`; die öffentliche Prüfung besitzt keine Schreibrechte. Offizielle Actions sind im Publisher auf geprüfte unveränderliche Commit-SHAs gepinnt. Der gemeinsame Concurrency-Lock `nachtsiegel-pages-release` mit `cancel-in-progress: false` verhindert parallele Publisher dieses Ablaufs und bricht einen laufenden Release nicht für einen neueren Trigger ab.

`.github/release-staging/pages-one-click.yml.in` bleibt ein inaktiver historischer Vorschlag außerhalb des Workflowverzeichnisses. Er wird nicht als zweiter Publisher aktiviert. `review_activation.py` liefert ausschließlich eine nicht mutierende Status-/Reviewausgabe. Der historische `guard.py` und seine manuellen Schutztests bleiben erhalten; die aktive Automation verwendet `candidate.py`.

## Grenzen, Tests und Rollback

GitHub bietet keine atomare Sperre zwischen dem letzten HEAD-Read und dem Pages-Deployment. Ein Merge in diesem kurzen Intervall macht die bereits geprüften Bytes nicht ungeprüft; der veröffentlichte Kandidat bleibt exakt protokolliert. Der Ablauf garantiert keine jederzeit atomare Veröffentlichung des neuesten Branchstands. Eine fehlgeschlagene öffentliche Prüfung ist kein erfolgreicher Releasebeleg. Browseremulation ersetzt keine physische Geräteabnahme; die vollständige Spielpartie bleibt Teil der vorgelagerten Main-QA.

Die lokalen Release- und CI-Vertragstests prüfen Triggergrenzen, alle Pflichtjobs, unveränderliche Artefakte, erneute Kandidatenprüfungen, Schutzrechte und öffentliche Dateiintegrität. Tests sind keine Behauptung, dass bereits ein Deployment ausgeführt oder die unbekannte GitHub-Konfiguration bestätigt wurde.

Bei einem Livefehler SHA, Workflowlauf und `release-evidence.json` sichern. Den gewünschten früheren Quellstand als regulär geprüften Revert-PR nach `develop` bringen, nötige Speicherkompatibilität prüfen und alle sieben Suiten auf dem neuen Revert-SHA abwarten. Derselbe Publisher veröffentlicht anschließend dessen neu getestetes Artefakt. Keine historischen QA-Run-IDs, abgelaufenen Artefakte oder direkten Branch-/Environment-Umgehungen verwenden. Öffentliche Provenienz und Browserprüfung müssen erneut erfolgreich sein. Bestehende Spielstände nicht pauschal löschen.
