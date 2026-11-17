# Vorbereiteter Ein-Klick-Release — ausdrücklich noch inaktiv

## Lieferstatus

Implementiert ist ein vollständiger Vorschlag für einen manuellen **Run workflow** ohne SHA-, Run-ID- oder Bestätigungstextfelder. Er veröffentlicht ausschließlich das bereits vollständig getestete Web-Artefakt des beim Start festgehaltenen aktuellen `develop`-Commits. Es entsteht kein neuer Spielbuild während der Veröffentlichung.

Der neue Ablauf ist **nicht aktiviert**: `.github/release-staging/pages-one-click.yml.in` liegt außerhalb des GitHub-Workflowverzeichnisses und besitzt keine ausführbare `.yml`-Endung. Der produktive Workflow und sein bisheriger Guard bleiben byteidentisch:

| Aktive Datei | SHA256 |
| --- | --- |
| `.github/workflows/pages-release.yml` | `cac935fa33f36c39d31acaf7133595bf94954886e3f8312d0b7e84f18bb0a2dd` |
| `tools/release/guard.py` | `008496e6298dd7c23ea4c80516ebbb08b7faa1a8dce6ca60b829f5fba430a45a` |

Damit wird die ausdrückliche Anweisung eingehalten: „Die bestehende manuelle Freigabesperre darf erst nach ausdrücklicher Nutzerfreigabe umgestellt werden.“ Weder ein Merge dieses Pakets noch ein Push, Tag oder PR startet eine Veröffentlichung. Es wurden keine Repository-, Branch-, Pages- oder Environment-Einstellungen geändert. Es wurde kein Deployment gestartet.

## Konkreter vorbereiteter Ablauf

1. Einen geprüften Feature-PR regulär integrieren. GitHub setzt die aktiven Merge- und Branchschutzregeln durch.
2. Die vollständige Main-CI und Release Safety laufen **erneut auf dem tatsächlichen neuen Develop-Commit**. Alte PR-/Merge-/QA-Nachweise werden nicht übernommen.
3. Nach gesonderter Aktivierungsfreigabe startet der Owner den neuen Workflow auf `develop` mit **Run workflow**. Keine weiteren Eingaben sind nötig. Der Klick bleibt die ausdrückliche Veröffentlichungsentscheidung für den privaten Alpha-Betrieb.
4. `candidate.py select` hält den Dispatch-SHA fest und liest den aktuellen Develop-HEAD. Er verlangt die jüngsten passenden Main- und Release-Safety-Läufe desselben Commits aus demselben Repository. PR-/Fork-/Tag-Läufe sind unzulässig. Ein neuerer fehlgeschlagener, laufender oder abgebrochener Lauf führt zur Ablehnung; kein Rückfall auf einen älteren grünen Lauf.
5. Jeder Job muss erfolgreich abgeschlossen sein, einschließlich zusätzlicher neuer Jobs. Die 20 Main-Jobs dieses Kandidaten sind einzeln verpflichtend: zwei reguläre Browser und zwei zusätzliche Premium-/PWA-Browser, Native Desktop/Android, Audio, Systemintegration, Paket-/Illustrationsprüfungen, Ressourcen, vollständiger Kartenpool, vier Balance-Shards und Aggregation sowie der gepaarte Blockdeck-Vergleich. Eine Umbenennung erfordert eine nachvollziehbare Anpassung dieses Vertrags.
6. Genau ein unexpired `nachtsiegel-arena-qa`-Artefakt muss denselben Run und SHA referenzieren. Es muss einen unveränderlichen GitHub-v4-SHA256-Digest besitzen. Fehlende Daten oder403/404 sind Fehler und werden nicht durch zusätzliche Tokens oder alternative Publisher umgangen.
7. Nur der Publish-Job erhält Pages-/OIDC-Schreibrechte und verwendet unverändert das Environment `github-pages`. Aktive Reviewer, Timer und Branchregeln gelten weiterhin. Es wird kein zweites Konto verlangt, keine aktive Schutzregel entfernt und kein Admin-Bypass benutzt.
8. Nach dem Environment-Gate werden HEAD, sämtliche Jobs, Run-Versuche und Artefaktidentität erneut geprüft. Ändert sich etwas, wird abgebrochen und ein neuer ausdrücklicher Start benötigt.
9. Der Download prüft den tatsächlichen ZIP-Digest und die Bytezahl. Authentifizierung wird ausschließlich an `api.github.com` geschickt; Weiterleitungen zu zugelassenem HTTPS-Artefaktspeicher erhalten keinen Authorization-Header. ZIP-Pfadtraversal, Symlinks, doppelte/nichtkanonische Pfade, verschlüsselte Einträge und übergroße Archive werden abgelehnt. Nur `build/web/` wird entpackt; SHA und Kanal in `build-info.json` müssen stimmen.
10. Die getesteten Spielbytes bleiben unverändert. Ergänzt wird `release-evidence.json` mit Source-SHA, Main-/Safety-Run und Versuch, Artefakt-ID/-Digest sowie SHA256 aller veröffentlichten Spielressourcen. Unmittelbar vor `deploy-pages` erfolgt eine weitere HEAD-/QA-Prüfung.
11. Ein separater Read-only-Job prüft die echte öffentliche URL: Commit und Provenienz sowie die tatsächlichen SHA256-Hashes des ausgelieferten `index.html`, PCK, WASM und der Einstiegsskripte/Metadaten. Dadurch genügen neue Metadaten neben alten Spielbytes nicht als Nachweis. Die Dateien werden begrenzt und als Stream gelesen; ein anderes Redirectziel, fehlende Dateien oder ein Hashfehler brechen ab. Danach folgen tatsächlicher WebAssembly/Godot-Start, fehlgeschlagene Ressourcen, Hauptmenü, erreichbare Deckauswahl und alle vier Starter in Chromium und WebKit. Screenshots und Ergebnisdaten werden als Artefakt aufbewahrt. Diese Prüfung behauptet keine physische Geräteabnahme. Eine vollständige Partie ist Bestandteil der vorgelagerten Main-QA; der öffentliche Smoke wird ausdrücklich nicht als zweite vollständige Partie ausgegeben.

GitHub bietet keine atomare Sperre zwischen dem letzten HEAD-Read und dem Pages-Deployment. Falls in diesem kurzen Zeitraum ein neuer Commit integriert wird, bleiben die veröffentlichten Bytes der zuvor geprüfte, protokollierte Kandidat. Dieser Ablauf garantiert keine atomare Veröffentlichung des jederzeit neuesten Branchstands. Er veröffentlicht niemals absichtlich einen späteren ungeprüften Commit. Das gemeinsame Release-Concurrency-Lock verhindert parallele Publisher dieses Prozesses.

Ein vollständig unbeaufsichtigter `workflow_run`-Publisher ist **nicht aktiviert und nicht behauptet**. Der vorbereitete Ein-Klick-Prozess vermeidet die manuellen Identitätsfelder und wahrt eine eindeutige Einzelentwickler-Freigabe. Eine künftig gewünschte automatische Veröffentlichungsentscheidung nach jedem grünen Develop-Lauf benötigt eine zusätzliche ausdrückliche Policyfreigabe und Prüfung der dann aktuellen GitHub-Einstellungen.

## Einmalige Aktivierung — erst nach ausdrücklicher Freigabe

Der prüfbare vollständige Diff lässt sich ohne Dateiveränderung ausgeben:

```sh
python3 tools/release/review_activation.py
```

Der Helfer besitzt absichtlich keinen Apply-Modus. Er verweigert eine Diff-Erzeugung, wenn der bisherige aktive Workflow inzwischen verändert wurde.

Nach ausdrücklicher Zustimmung wird in einem separaten Feature-PR die Vorlage an die Stelle von `.github/workflows/pages-release.yml` übernommen. Die Aktivierungs-Tests müssen die dann freigegebene Policy abbilden; die vorhandenen Hash-/Manual-Input-Assertions dürfen erst in diesem gesondert geprüften Aktivierungs-PR geändert werden. Anschließend alle Release-Safety- und vollständigen Main-Tests auf dem tatsächlichen Integrations-SHA ausführen. Keine zweite Workflowdatei parallel als alternativen Publisher aktivieren.

Minimal durch den Repository-Owner zu prüfen, ohne neue Einstellungen zu erfinden:

- **Settings → Pages → Source: GitHub Actions.** Branchbasierte Veröffentlichung darf kein zusätzlicher Pfad sein.
- Das bestehende Environment **github-pages** erlaubt den Branch `develop`; aktive Reviewer, Timer und Branchschutz bleiben bestehen. Die Vorlage verlangt keine zweite Reviewer-Identität.
- Workflow ist auf dem Defaultbranch verfügbar; im Actions-Menü für die Veröffentlichung den Branch `develop` wählen. Tags, Featurebranches und Main werden durch den Guard abgelehnt.
- Die normalen Workflowberechtigungen für Actions-/Pages-Reads sowie Pages-/OIDC-Schreibrechte des Publish-Jobs müssen durch GitHub erlaubt sein. Bei403 nicht ausweichen, sondern die konkrete verweigerte Operation durch den Owner prüfen lassen. Dieses Paket behauptet nicht, unbekannte Repository-Einstellungen bereits verifiziert zu haben.
- Die aktuellsten vollständigen Main- und Release-Safety-Läufe des neuen Develop-Commits müssen grün sein; der QA-Upload muss ein nicht abgelaufenes v4-Artefakt mit Digest enthalten. Der Stand10782185 hatte am Prüfzeitpunkt17 erfolgreiche Main-Jobs und einen v4-Digest; diese historische Beobachtung ist kein Releasebeleg für diese Änderungen.

## Tests und tatsächliche Grenzen

```sh
python3 -W error::ResourceWarning -m unittest discover -s tests/release -v
node --test tests/release/public_integrity.test.cjs
node --check tools/release/public_probe.cjs
python3 -m py_compile tools/release/candidate.py tools/release/review_activation.py
```

Der strenge lokale Lauf besteht **31 Python-Testmethoden**: acht vorhandene Schutztests und23 neue Methoden mit zusätzlichen Gegenproben. Dazu kommen **sieben Node-Testgruppen mit echten lokalen HTTP-Antworten** für öffentliche Dateiintegrität: unveränderte Dateien, alter Index trotz frischer Metadaten, alte PCK/WASM/JS-Dateien, fehlende/übergroße Antworten, falsche Provenienz/Pfade, Redirects und ausführbare Dateien in Unterverzeichnissen. Syntaxprüfungen für Python und Node sowie `git diff --check` bestehen. Die Python-Suite prüft den unveränderten aktiven Schutz und die neue inaktive Vorlage, Source-/Repository-/Event-/Branch-/Attempt-Identität, sämtliche Pflichtjobs, zusätzliche fehlgeschlagene Jobs einschließlich noch unbekannter künftiger Prüfnamen, neuere fehlgeschlagene Läufe, API-Pagination und403, Artefaktidentität, ZIP-Digest/Bytezahl, sichere Weiterleitung ohne Auth-Header, ZIP-Pfade, Source-Metadaten und unveränderte getestete Dateien. Ein vorab im QA-Artefakt enthaltenes `release-evidence.json` wird abgewiesen, damit seine Überschreibung keine widersprüchliche Hashliste erzeugt. Die API- und ZIP-Gegenproben sind lokale synthetische Testeingaben und lösen keinerlei GitHub-Aktionen aus.

Der öffentliche Browser-Smoke ist implementiert und syntaktisch geprüft. Er wurde in diesem Paket nicht gegen eine neue öffentliche Version ausgeführt, weil kein Deployment autorisiert oder gestartet wurde. Auch der inaktive Workflow selbst kann erst nach gesonderter Freigabe real auf GitHub laufen. Daraus wird weder eine erfolgreiche Veröffentlichung noch eine vollständig verifizierte Repository-Konfiguration abgeleitet.

## Sicherer Rollback

1. Bei einem Livefehler den betroffenen Workflowlauf, SHA und `release-evidence.json` sichern. Fehlgeschlagene öffentliche QA bedeutet keine erfolgreiche Abnahme.
2. Gewünschten früheren Spielstand über einen regulären Revert-PR nach `develop` bringen, einschließlich nötiger Speicherkompatibilitätsprüfung.
3. Vollständige Main-QA und Release Safety des neuen aktuellen Revert-SHAs abwarten und den freigegebenen manuellen Release starten. Keine alten abgelaufenen Artefakte und keine historischen QA-Run-IDs wiederverwenden.
4. Bei einem Fehler in der neuen Releasekonfiguration selbst den bisherigen manuellen Publisher über einen separat getesteten Revert-PR wiederherstellen. Keine direkte Branchänderung oder Schutzregel-Umgehung.
5. Die öffentliche Provenienz und Browserprüfung erneut bestehen lassen. Bestehende Spielstände nicht pauschal löschen.
