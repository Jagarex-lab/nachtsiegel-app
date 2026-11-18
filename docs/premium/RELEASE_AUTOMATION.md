# Freigegebene automatische Alpha-Veröffentlichung

Die ausdrückliche Owner-Freigabe aktiviert den automatischen Alpha-Publisher in `.github/workflows/pages-release.yml` und ersetzt die bisherige manuelle Freigabesperre. Die stehende Freigabe erlaubt reguläre Merges beauftragter, owner-freigegebener Codex-PRs ohne weitere Rückfrage, sobald alle erforderlichen Checks am aktuellen erwarteten Head grün sind. GitHub-Schutzregeln gelten unverändert. Vor einer kommerziellen Veröffentlichung ist eine erneute Policyprüfung erforderlich.

## Automatischer Ablauf

Ein regulärer Merge nach `develop` startet die vollständige Post-Merge-QA. Der Publisher reagiert auf erfolgreiche abgeschlossene `push`-Läufe der sieben freigegebenen Suiten. Der Preflight prüft vor jedem privilegierten Schritt das eigene Repository, den Defaultbranch `develop`, den tatsächlichen Trigger-Run und den aktuellen Quellcommit. Eine erfolgreiche einzelne Suite reicht nicht: Alle sieben jüngsten passenden Suiten müssen denselben aktuellen `develop`-SHA vollständig bestanden haben.

| Suite | Pflichtjobs |
| --- | ---: |
| Main — `NACHTSIEGEL CI (no deployment)` | 20 |
| Alpha — `ORAFOLD isolated Alpha QA (no deployment)` | 4 |
| Safety — `Release safety (no deployment)` | 1 |
| Legacy — `Legacy P01-P07 (no deployment)` | 1 |
| Economy — `ORAFOLD isolated economy QA (no deployment)` | 1 |
| Campaign — `ORAFOLD campaign QA (no deployment)` | 1 |
| Online — `ORAFOLD online authority integration QA (no deployment)` | 1 |

Damit sind 29 benannte Jobs verpflichtend; zusätzliche vorhandene Jobs müssen ebenfalls erfolgreich sein. Main umfasst unter anderem beide Browserengines, Premium-/PWA-Browser, native Plattformen, Audio, Systemintegration, Paket-/Illustrationsprüfungen, Ressourcen, vollständigen Kartenpool, Balance-Shards und deren Aggregation. Umbenennungen oder Erweiterungen des Vertrags müssen nachvollziehbar mit dem Publisher getestet werden.

`candidate.py select` liefert bei einer legitim noch fehlenden oder laufenden Suite `ready=false`. Der Workflow endet dann ohne Veröffentlichung; ein späterer erfolgreicher Suiteabschluss kann erneut auswählen. Fehlerhafte API-Antworten, falsche Identitäten und Integritätsfehler werden nicht als Erfolg behandelt. Ein neuerer fehlgeschlagener oder laufender QA-Versuch darf nicht durch einen älteren grünen Lauf verdeckt werden. Der Kandidat bindet Commit, sämtliche Run-IDs und Versuche sowie die unveränderliche Artefaktidentität.

Als Fallback kann der Owner **Run workflow** auf `develop` auslösen. Der Dispatch besitzt keine Eingaben und verwendet denselben aktuellen Commit, dieselben sieben Post-Merge-Suiten und dieselben Sicherheitsprüfungen. Manuelle Commit-, QA-Run-ID- oder Bestätigungseingaben gibt es nicht mehr. Weder PR-, Featurebranch-, Fork- noch Tag-Läufe dürfen Quellnachweise liefern.

## Ausschließlich getestete Artefakte

Die Main-QA liefert genau ein nicht abgelaufenes `nachtsiegel-arena-qa`-Artefakt mit unveränderlichem GitHub-v4-SHA256-Digest. Der Publish-Job erstellt keinen Spielbuild. Er prüft ZIP-Digest und Bytezahl, lehnt Pfadtraversal, Symlinks, doppelte oder nichtkanonische Pfade, verschlüsselte Einträge und übergroße Archive ab und entpackt ausschließlich `build/web/`. Commit und Kanal in `build-info.json` müssen zum Kandidaten passen.

Authentifizierung geht ausschließlich an `api.github.com`. Weiterleitungen zu zugelassenem HTTPS-Artefaktspeicher erhalten keinen Authorization-Header. Fehlende Daten oder API-Fehler, einschließlich403/404, werden nicht durch zusätzliche Tokens oder alternative Publisher umgangen.

Die getesteten Spielbytes bleiben unverändert. Ergänzt wird `release-evidence.json` mit Source-SHA, allen Suite-Identitäten, Artefakt-ID/-Digest und SHA256 der veröffentlichten Spielressourcen. Ein bereits im QA-Artefakt vorhandener Provenienzpfad wird abgewiesen. Der Download gibt den SHA256 der rohen Evidenzdatei als `evidence_sha256` aus; der Publish-Job reicht ihn an die öffentliche Prüfung weiter. Dadurch kann die öffentliche Datei nicht allein durch intern konsistente, aber ausgetauschte JSON-Daten als gültig erscheinen.

## Rechte, Environment und erneute Prüfung

Der Preflight besitzt ausschließlich Lesezugriff auf Contents, Actions und Pages. Nur der Publish-Job erhält Pages-/OIDC-Schreibrechte und nutzt unverändert das Environment `github-pages`. Aktive Reviewer, Timer und Branchregeln bleiben wirksam. Es wird keine Schutzregel entfernt, kein Admin-Bypass verwendet und keine zweite Identität zusätzlich verlangt. Publisher-Actions sind auf geprüfte offizielle Commit-SHAs gepinnt.

Nach jedem aktiven Environment-Gate und nochmals unmittelbar vor `deploy-pages` prüft `candidate.py recheck` HEAD, alle Suite-Jobs, Run-Versuche und Artefaktidentität. Ein geänderter Kandidat wird abgewiesen. Der gemeinsame Release-Lock `nachtsiegel-pages-release` hat `cancel-in-progress: false`; ein neuer Trigger bricht die laufende Veröffentlichung nicht ab.

GitHub bietet keine atomare Sperre zwischen dem letzten HEAD-Read und dem Deployment. Ein neuer Merge in diesem kurzen Zeitfenster kann dazu führen, dass noch der unmittelbar zuvor geprüfte Kandidat veröffentlicht wird. Dessen Bytes und Nachweise bleiben exakt gebunden; es gibt keine Garantie einer jederzeit atomaren Veröffentlichung des neuesten Branchstands.

## Öffentlicher Nachweis

Der separate Read-only-Job prüft an der tatsächlichen öffentlichen URL zuerst den erwarteten SHA256 von `release-evidence.json`, bevor er JSON interpretiert. Danach prüft er Commit, Provenienz und die tatsächlichen SHA256-Hashes der ausgelieferten Ressourcen einschließlich `index.html`, PCK, WASM und Einstiegsskripten/Metadaten. Neue Metadaten neben alten Spielbytes genügen nicht. Fehlende, übergroße, umgeleitete oder falsch gehashte Antworten brechen die Prüfung ab.

Anschließend starten Chromium und WebKit den tatsächlichen WebAssembly-/Godot-Build. Ressourcenfehler, Hauptmenü, erreichbare Deckauswahl und alle vier Starter werden geprüft. npm installiert die bestehende offizielle Playwright-Version `1.65.0`; der vorhandene netzwerkbewusste Installationshelfer installiert Chromium, WebKit und ihre Systemabhängigkeiten mit begrenztem offiziellen Mirror-Fallback. Screenshots und Ergebnisdaten bleiben als Releaseartefakt erhalten. Dieser Browser-Smoke behauptet keine physische Geräteabnahme und keine zweite vollständige Partie; diese bleibt Teil der vorgelagerten Main-QA. Eine fehlgeschlagene öffentliche Prüfung ist kein verifizierter Veröffentlichungserfolg.

## Betrieb und historische Vorlage

Der Workflow muss auf dem Defaultbranch `develop` verfügbar sein, Pages GitHub Actions verwenden und das vorhandene Environment `github-pages` den Branch `develop` zulassen. Die Implementierung verändert keine Repository-, Branch-, Pages- oder Environment-Einstellungen und behauptet deren unbekannten Livezustand nicht als verifiziert.

Ein Owner- oder autorisierter GitHub-App-Merge muss die normalen Push-Ereignisse erzeugen. Ein ausschließlich mit `GITHUB_TOKEN` ausgeführter Merge unterdrückt diese QA-Workflows und ist deshalb nicht unterstützt; fehlende Nachweise blockieren die Veröffentlichung. Native Auto-Merge-Einstellungen, ein privilegierter Merge-Daemon für beliebige PRs oder ein Ersatzpublisher werden nicht aktiviert.

`.github/release-staging/pages-one-click.yml.in` bleibt als historischer, inaktiver Ein-Klick-Vorschlag außerhalb von `.github/workflows/` erhalten. Sie ist keine zweite Veröffentlichungsroute. `python3 tools/release/review_activation.py` zeigt ausschließlich einen nicht mutierenden Review-/Aktivierungsstatus; es besitzt keinen Apply-Modus. Die alten Hash- und Manual-Input-Verträge des aktiven Workflows werden durch Tests der freigegebenen automatischen Policy ersetzt. `guard.py` und seine historischen manuellen Gegenproben bleiben erhalten.

## Lokale Prüfung und Rollback

Die CI-Provisionierung trennt Playwrights `install-deps` und `install` in zwei
eigene, begrenzte Phasen. Jede Phase besitzt standardmäßig 300 Sekunden. Nur
die Systemabhängigkeiten dürfen bei einem nachgewiesenen APT-Downloadfehler
einmal mit den offiziellen Ubuntu-Spiegeln wiederholt werden; deren temporäre
Konfiguration wird vor dem Browserdownload vollständig zurückgesetzt. Der
Browserdownload einschließlich der normalen Hostprüfung erhält genau einen
eigenen Versuch. Ein CDN-Fehler löst keinen APT-Spiegelwechsel aus.

Grund ist der tatsächliche fehlgeschlagene
[Bild-Browserjob 134476925062](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44204333910/job/134476925062):
Die Systempakete benötigten rund vier Minuten; der anschließende Chrome-Download
erreichte 100 Prozent, wurde aber von der gemeinsamen 300-Sekunden-Grenze vor
der Fertigstellung beendet. Die Bildtests liefen nicht und dieser Versuch
bleibt fehlgeschlagen. Die getrennten Installationsphasen ändern keine
Spiel-, Touch-, Audio- oder Browser-Testzeitgrenzen und ersetzen keine
fehlgeschlagene QA durch einen Erfolg.

Zwei weitere fehlgeschlagene WebKit-Läufe auf `60baaaa` bleiben ebenfalls als
Fehlversuche erhalten. Im Kampagnenjob `134494300084` war die tatsächliche
Übersicht bereits angezeigt, aber der getrennte Kampagnenbericht noch nicht vorhanden;
der alte Poll-Callback warf sofort einen `TypeError`. Die neue serialisierbare
Wartebedingung verlangt beide Berichte, den richtigen Kontext und Bildschirm
sowie bei Kämpfen einen tatsächlich vorhandenen Kampfzustand.

Im Migrationsjob `134494017498` zeigte der erfasste Fehlerzustand dagegen noch
`page=lobby`, Menüaktionen und `render_version=2`. Die leere Deckliste war ein
Menübericht nach einem verworfenen frühen Tap, kein Nachweis eines gelöschten
Spielstands; die unabhängige gespeicherte Version-2-Datei war davor bytegenau
korrekt. Der Treiber wartet vor seinem einzigen Touch auf frische stabile
Zielgeometrie und danach auf die tatsächliche Navigation. Die genaue
30-Karten-, Speicher-, neue-Karten-ID- und Partiestartprüfung bleibt bestehen;
es gibt keine Wiederholung des Taps bis zum Erfolg und kein Warten auf eine
passend gemachte Deckliste. Die erfassten Zustände sind verpflichtende
Regressionen. Produkt- und Speicherlogik bleiben unverändert; neue vollständige
Browserläufe müssen die korrigierten Treiber erst bestätigen.

```sh
python3 -W error::ResourceWarning -m unittest discover -s tests/release -v
python3 -m unittest discover -s tests/ci -v
node --test tests/release/public_integrity.test.cjs
node --check tools/release/public_probe.cjs
python3 -m py_compile tools/release/candidate.py tools/release/review_activation.py
git diff --check
```

Diese Tests prüfen unter anderem Event-/Repository-/Source-Identität, alle Pflichtjobs, neue fehlgeschlagene Versuche, API-Pagination und Fehler, unveränderliche Artefakte, sichere Downloads, unveränderte Spielbytes, minimale Rechte und die Integrität echter lokaler HTTP-Antworten. Sie lösen keine GitHub-Deployments aus. Ein erfolgreiches lokales Ergebnis ersetzt keine öffentliche Releaseprüfung.

Bei einem Livefehler Lauf, SHA und Evidenzdatei sichern. Den früheren gewünschten Quellstand über einen regulären Revert-PR nach `develop` bringen und gegebenenfalls Speicherkompatibilität prüfen. Alle sieben Suiten des neuen Revert-SHAs müssen erneut grün sein; derselbe automatische Publisher veröffentlicht dessen neu getestetes Artefakt. Keine alten abgelaufenen Artefakte, historischen QA-Run-IDs, direkten Branchänderungen oder Schutzregel-Umgehungen verwenden. Danach öffentliche Provenienz und Browserprüfung erneut bestehen lassen; Spielstände nicht pauschal löschen.
