# ORAFOLD – PR-Konsolidierungsbericht vom 18.11.2026

## Ergebnis für den Projektinhaber

**Verifizierter Bearbeitungsstand am 18.11.2026, 19:02 UTC:** Alle sieben
ursprünglichen PRs sind geschlossen; die drei notwendigen Wartungs-PRs #32,
#34 und #35 wurden nach erfolgreicher eigener Head-QA regulär integriert.
Aktueller develop-Commit ist
`d7b34e78b6b8b79c69d8d00f90cd4811449c9897`, Baum
`04316d5ed7d6e1af9af6254755b9360c85349dea`.
Seine frische Merge-QA ist zu diesem Zeitpunkt mit 28/29 erfolgreichen
Pflichtjobs noch nicht vollständig: Main-Chromium läuft, Alpha einschließlich
beider Browser ist erfolgreich. Es gibt keinen fehlgeschlagenen Pflichtjob.
Bis zu einem tatsächlich erfolgreichen Publish und öffentlicher Prüfung bleibt
der zuletzt bestätigte Live-Commit
`6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Dieser abschließende Berichtsnachtrag ändert ausschließlich Dokumentation.
Sein eigener PR ist beim Verfassen noch nicht angelegt oder integriert.
Auch für ihn sind vollständige Head-QA, regulärer Merge, neue QA auf dem
exakten Merge-Commit und die bestehende automatische Veröffentlichung
verpflichtend. Der endgültige aktuelle Merge-, QA- und Live-Nachweis wird nach
tatsächlicher Ausführung im stabilen
[Abschlusskommentar von PR #35](https://github.com/Jagarex-lab/nachtsiegel-app/pull/35#issuecomment-6985608488)
einschließlich Verweis auf den Berichts-PR und in den unten verlinkten
öffentlichen Provenienzdateien dokumentiert. Ein Quellcommit kann seinen
eigenen späteren Merge-Hash nicht enthalten; daraus entsteht keine Ausnahme
von der Pflicht zu neuen, exakt zugeordneten QA-Nachweisen.

Alle **sieben ursprünglich offenen PRs** wurden geprüft und mit begründetem
Abschlusskommentar **ohne zusätzlichen Merge geschlossen**: fünf bereits
integriert, zwei durch die heutige Produktion abgelöst. **38 ursprüngliche
Branches** und alle **571 PR-/Dateiänderungen** sind erfasst. Die
Abschlusskontrolle fand **41 Branches**: alle ursprünglichen 38 bleiben
erhalten, die 37 ursprünglichen Nicht-develop-Heads sind unverändert; drei
neue Wartungsbranches entsprechen genau den integrierten PRs #32/#34/#35.
Kein Branch wurde gelöscht; historische Bilder, Herkunft, Lizenzen und
Prüfnachweise bleiben erhalten.

| PR | Zweck | Entscheidung | Begründung | CI | Endstatus |
| --- | --- | --- | --- | --- | --- |
| [#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4) | Legacy P01–P04 | C – BEREITS INTEGRIERT | Exakter Head ist develop-Vorfahr; 43/48 Dateien identisch, fünf weiterentwickelt. | Zwei historische Checks erfolgreich; Deployment übersprungen. | Geschlossen, kein neuer Merge. |
| [#5](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5) | Legacy P05/P06 | C – BEREITS INTEGRIERT | Gesamte Commit-Kette vorhanden; 53/58 Dateien identisch. | Zwei historische Checks erfolgreich; Deployment übersprungen. | Geschlossen, kein neuer Merge. |
| [#7](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7) | Legacy P07 | C – BEREITS INTEGRIERT | Gesamte Commit-Kette vorhanden; 35/40 Dateien identisch. | Zwei historische Checks erfolgreich; Deployment übersprungen. | Geschlossen, kein neuer Merge. |
| [#11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11) | Trigger-Bridge | C – BEREITS INTEGRIERT | Beide Patches exakt übernommen; aktuelle Engine mit allen 16 Triggern weiterentwickelt. | Alter Head 12/12 grün; gezielte aktuelle Engine-/Umleitungstests ohne Fehler. | Geschlossen, kein zweiter Kernel. |
| [#14](https://github.com/Jagarex-lab/nachtsiegel-app/pull/14) | Audio und 163 Originalclips | C – BEREITS INTEGRIERT | Alle drei Patches übernommen;369/380 Dateien identisch, elf verbessert. | Alter Head 12/13; historischer WebKit-Builderfehler bleibt dokumentiert. Aktueller Stand 6c99 separat grün. | Geschlossen, neuere Audioverbesserungen erhalten. |
| [#15](https://github.com/Jagarex-lab/nachtsiegel-app/pull/15) | Konzept-/Art-Vorbereitung | D – ÜBERHOLT | Alte Pipeline ersetzt; kleine fehlende Brief-Prüfung gezielt mit #32 in bestehende Pipeline portiert. | Alter Head 10/10; Ersatz lokal 38 Tests plus 550-Bild-Prüfung, #32-Head26/26. | Geschlossen; Piloten und alternative Entwürfe gesichert; Issue #31 completed. |
| [#26](https://github.com/Jagarex-lab/nachtsiegel-app/pull/26) | Alter manueller Release-Nachweis | D – ÜBERHOLT | Automatischer Release ersetzt die damaligen Eingaben; einzigartige Nachweise historisch archiviert. | Alter Head 22/22; keine Freigabe späterer Commits daraus abgeleitet. | Geschlossen; kein alter Publisher aktiviert. |
| [#32](https://github.com/Jagarex-lab/nachtsiegel-app/pull/32) | Bericht/Archive und fehlende Brief-Bindung | A – MERGEN | Eigenständige Guard-Lücke aus #15 adaptiert, ohne alte Pipeline zu übernehmen. | Head26/26 erfolgreich; frische183192-QA durch fremde APT429 blockiert, nicht veröffentlicht. | Regulär als183192 integriert; Folgekorrekturen in #34. |
| [#34](https://github.com/Jagarex-lab/nachtsiegel-app/pull/34) | CI-Quellen, Browser-Versionen, Test-Lebenszyklen | B – REPARIEREN UND MERGEN | Konkrete vier Fehlerklassen gezielt mit Quellen-/SDK-/Testkorrekturen behoben. | Finaler Head c45:27/27 erfolgreich; frischer Merge119ceb:26 erfolgreiche Einträge, Alpha-Nativ45m abgebrochen, Browser übersprungen; keine Releasefreigabe. | Regulär als119ceb integriert; Restkapazität in #35 gesichert. |
| [#35](https://github.com/Jagarex-lab/nachtsiegel-app/pull/35) | Vollständige native Alpha-Suite im endlichen Jobrahmen | B – REPARIEREN UND MERGEN | GitHub-Annotation beweist äußeres45m-Limit; gleicher Baum benötigte nach letztem Marker weitere12,91m. Nur äußerer Job75m, alle Tests/inneren Fristen unverändert. | Finaler Head7eba:26/26 erfolgreich; frische d7-Merge-QA28/29 erfolgreich, Main-Chromium noch aktiv. | Regulär alsd7b34 integriert; Issue #33 completed. Release noch nicht nachgewiesen. |
| [Abschließender Berichts-PR (dieser Nachtrag)](https://github.com/Jagarex-lab/nachtsiegel-app/tree/maintenance/consolidation-final-receipt) | Einheitliche vollständige Tabelle, aktuelle Zählung und Abschlussbelege | A – MERGEN nach erfolgreicher eigener QA | Nur diese Berichtsdatei; beseitigt getrennte Tabellen und überholte Ergebnisübersicht, erhält alle historischen Fehlernachweise. | Beim Verfassen noch ausstehend; eigene vollständige Head- und Merge-QA erforderlich. | Vorbereitet, noch nicht integriert; endgültiger PR und Status im [Abschlussnachweis](https://github.com/Jagarex-lab/nachtsiegel-app/pull/35#issuecomment-6985608488). |

**Zählweise zum genannten Bearbeitungsstand:** ursprünglich offen **7**;
davon **5 C / bereits integriert** und **2 D / abgelöst**, alle geschlossen
ohne erneuten Merge. Zusätzlich **3 Wartungs-PRs regulär gemergt**, davon
**2 B / repariert** (#34/#35); #32 ist ausschließlich A. Damit sind insgesamt
**10 PRs abgeschlossen** und vor Anlage dieses Berichts-PRs **0 PRs offen**.
Die Issues #31 und #33 sind closed/completed. Es bestehen **0 bekannte offene
Integrationsblocker**; noch laufende QA und fehlender Publish-Nachweis sind
ausstehende Freigabeschritte und werden nicht als bestanden gezählt.

Nach erfolgreicher Integration dieses zusätzlichen Dokumentations-PRs lautet
die abschließende Gesamtzählung **4 neue Merges, davon 2 repariert; 7 alte PRs
geschlossen (C5/D2)**. Das ist hier ein ausdrücklich noch ausstehender
Zielzustand, kein behaupteter Merge. Die tatsächlich erreichten Gesamtzahlen,
offenen PRs, Merge- und Live-SHAs werden im verlinkten Abschlussnachweis
erneut direkt über die API und öffentliche Anwendung bestätigt.

**Historischer geprüfter und tatsächlich veröffentlichter Ausgangscommit:**
`6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.
Die damaligen sieben Suiten mit 29 Pflichtjobs, öffentliche Chromium-/WebKit-
Prüfung und zusätzliche vollständige öffentliche KI-Partie mit Replay und
Neustart gehören genau zu diesem Ausgangscommit. Die endgültigen Merge-/
Release-SHAs dieses Wartungsberichts stehen nach tatsächlicher Ausführung im
stabilen PR-Abschlussnachweis und im öffentlichen
[Release-Nachweis](https://jagarex-lab.github.io/nachtsiegel-app/release-evidence.json)
sowie [Build-Nachweis](https://jagarex-lab.github.io/nachtsiegel-app/build-info.json).
So wird kein eigener zukünftiger Commit-Hash vorweggenommen und keine alte QA
auf einen neuen Commit übertragen.

Die folgenden Fortschreibungen bewahren die jeweiligen damaligen Zustände,
einschließlich fehlgeschlagener oder gesperrter Kandidaten. Ihre datierten
Pending-Angaben ersetzen nicht die aktuelle Ergebnisübersicht oder den
abschließenden, commitgebundenen Nachweis.

## Fortschreibung: Wartungsmerge und zusätzlicher CI-Provisionierungsblocker

PR [#32](https://github.com/Jagarex-lab/nachtsiegel-app/pull/32) wurde nach
**26/26 erfolgreichen Head-Jobs** regulär als
`183192f9974837a67876a86fa7194506e6be93cc` integriert. Der tatsächliche
Merge-Baum `c94b4ece5f396e920de0af999f1e55268fb80efe` entspricht exakt dem
geprüften Kandidaten; Issue #31 ist damit als completed geschlossen. Die
ursprünglichen sieben PRs bleiben abgeschlossen. Die Art-Korrektur ist
integriert; ihre Bilder, Karten, Rechte und Spielregeln bleiben unverändert.

Die anschließende frische QA auf **183192** fand einen neuen, unabhängigen
Einrichtungsfehler: [Main-Job134820510983](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44309750137/job/134820510983)
scheiterte vor Browserinstallation und integrierten Assertions an zwei
HTTP429-Antworten einer vorinstallierten Microsoft-APT-Quelle. Offizielle
Ubuntu-Indizes wurden erfolgreich geladen. Dieser Lauf bleibt **fehlgeschlagen**;
eine teilweise erfolgreiche Suite ist keine Releasefreigabe.
Der konkrete Blocker ist in [Issue #33](https://github.com/Jagarex-lab/nachtsiegel-app/issues/33)
gesichert; das unveränderte [Fehlarchiv](history/ci-183192/README.md) ist samt
GitHub-Artefakt-SHA256 konserviert. Die automatische Sperre hat eine
Veröffentlichung korrekt verhindert.

Dieses kleine Folgepaket begrenzt ausschließlich die Systemabhängigkeitsphase
unter unterstütztem GitHub Ubuntu24.04 auf vorhandene, streng geprüfte,
offizielle signierte Ubuntu-Quellen. Fremde Quellen und Schlüssel bleiben
unangetastet. Temporäre Auswahl und Spiegelkonfiguration werden vor
Browserinstallation und auf Fehlerpfaden wiederhergestellt. TLS, GPG,
strikte APT-Fehler, Paket- und Browser-Hostprüfung, Deadlines und maximal
zwei Systemversuche bleiben erhalten. Unsichere oder unbekannte
Konfiguration wird sichtbar zurückgewiesen; lokale Nicht-GHA-Abläufe bleiben
erhalten. Eine echte, netzwerkfreie APT-URI-Aufzählung prüft, dass die
Microsoft-Quelle während der Systemphase ausgeschlossen und vor der
Browserphase wieder vorhanden ist.

Der erste Folge-Head `5364d119e90c3f7fdd38fc9ea9b8319b3903a70e`
wurde nicht gemergt: Seine neue Rechteannahme scheiterte in allen zehn Browser-Installationsjobs vor APT.
Der abgeschlossene Head hatte 16 erfolgreiche und 10 fehlgeschlagene Jobs.
Die lokale Fixture bildete das echte Runner-Image noch nicht ab.
Der [unveränderte Nachweis](history/ci-183192/first-repair.json) erhält Fehler,
Job-IDs und beide Originalarchive. Das exakte offizielle
[Image-Skript](https://github.com/actions/runner-images/blob/fb099341ddaf44a428fb17495341cb7c2300faf2/images/ubuntu/scripts/build/configure-system.sh#L12)
setzt `/usr/share` rekursiv auf 777; der bereitgestellte Ubuntu-Keyring ist
dadurch beschreibbar. Diese Fehlversuche sind keine bestandenen Tests.

Die korrigierte Variante authentifiziert die einmal gelesenen Keyring-Bytes
mit SHA256 `80a36b0a6de2f69f49d2df75ef473ccde121e9e190b9ea01d20a4f63778d5c31`
aus dem unabhängig verifizierten offiziellen Noble-Paket. Nur dieses bekannte
Material und die streng geprüfte Quelle werden als root-eigene Snapshots mit Modus0644
verwendet; Signed-By verweist ausschließlich auf die geprüfte Kopie.
Originalbytes und Rechte bleiben unangetastet. Unbekannte Schlüssel,
Source-Injektionen, Symlinks und Kollisionen bleiben Fehler; alle Kopien
werden vor Browserinstallation und auf Fehlerpfaden entfernt.

[Vendor-/Signaturnachweis](history/ci-183192/ubuntu-keyring-provenance.json)
enthält Paket-URLs und Prüfsummen, das genaue Runner-Image sowie die
erfolgreiche tatsächliche gpgv-Prüfung aktueller Noble-, Updates- und
Security-InRelease-Dateien mit Fingerprint
`F6ECB3762474EDA9D21B7022871920D1991BC93C`. Die jeweiligen Packages.xz-Hashes
stimmen mit der signierten Release-Metadatenkette überein. Der aktuelle
Noble-Paketstand ist damit bestätigt; kein Ubuntu-26-Keyring, kein fremder
Trust und kein Netzwerk-Bootstrap zur Laufzeit werden eingeführt.

Lokal bestanden **50 CI-Vertragstests** einschließlich aller bisherigen 35,
**50 Release-Python-Tests** und **88 Node-Vertragstests**. Unabhängiges Review,
Syntax und Diffprüfung bestanden. Diese lokalen Ergebnisse ersetzen keine
frische GitHub-QA auf dem endgültigen Folge-Head oder dessen Merge.

**Stand dieses Nachtrags vor seiner eigenen Integration:** develop183192;
öffentlich weiterhin der vollständig geprüfte Ausgangscommit6c99dfc.
Ein neuer gesicherter CI-Blocker befindet sich in Korrektur; kein ursprünglicher
PR ist wieder offen. Der endgültige Ersatz-PR ist über Issue #33 verknüpft.
Nach seinem regulären Merge müssen alle sieben Suiten mit29Pflichtjobs auf
dem neuen exakten Commit bestehen. Erst danach darf der unveränderte
automatische Publisher veröffentlichen und die öffentliche Version prüfen.
Endgültige Commit-, QA- und Live-Nachweise werden in der
[Abschlussprüfung von PR #34](https://github.com/Jagarex-lab/nachtsiegel-app/pull/34#issuecomment-6979959291)
sowie den öffentlichen Provenienz-JSONs festgehalten; keine
veralteten Run-IDs und keine erfundenen zukünftigen Merge-SHAs.

## Technischer Detailnachweis

Seven old open PRs were audited against published develop `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f` (tree `8c84f6ed60213fbde77cb775319347b63af17dab`). Five are **C — already integrated**; two are **D — superseded**. **No old PR was merged or repaired.** The useful missing art-review guard is adapted in one small maintenance PR together with this report and historical preservation; it is not a new master task.

This report is a dated snapshot. All seven original PRs are now closed unmerged, with the five C and two D decision comments linked below. No original PR remains open and no original consolidation blocker remains. Issue #31 is addressed by the locally implemented replacement guard in this maintenance change; fresh CI is still pending. The new maintenance PR/head/merge and its fresh CI and public release remain pending confirmation. Old green QA never certifies a new maintenance head. The final authoritative outcome belongs in the maintenance PR final comment and the public release-evidence/build-info records after the actual merge and verification.

## Decisions and recorded end states

| PR | Purpose | Decision and why the old PR is not merged | Historical exact-head CI | Recorded end state |
| --- | --- | --- | --- | --- |
| [#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4) | Deterministic isolated P01–P04 kernel, RNG/turn/damage and differential evidence | C: exact head/commits are ancestors; 43/48 authored files identical, five shared files intentionally evolved. | 2 successful runs; deploy job skipped | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4#issuecomment-6976133136) |
| [#5](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5) | P05/P06 card cycle and 16 original creature abilities | C: exact head/commits are ancestors; 53/58 files identical, five shared files evolved. Preserve later engine and QA extensions. | 2 successful runs; deploy job skipped | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5#issuecomment-6976128070) |
| [#7](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7) | P07 reactions, resonance and original action chains | C: exact head/commits are ancestors; 35/40 files identical, five shared files evolved. Stacked merge adds no missing behavior. | 2 successful runs; deploy job skipped | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7#issuecomment-6976122480) |
| [#11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11) | Opt-in source-bound three-family trigger bridge | C: both commits have exact patch-equivalent integrated counterparts; original tests remain. Merging duplicates history and conflicts with production code. | Historical checks successful; not new-head certification | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11#issuecomment-6976277135) |
| [#14](https://github.com/Jagarex-lab/nachtsiegel-app/pull/14) | Isolated modular audio, 163 clips and integration contract | C: all three patches integrated equivalently; 369/380 blobs identical, 11 improved. All 163 original clips and imports/provenance retained. | PR jobs 10/10 passed; feature-push WebKit job failed and stays recorded | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/14#issuecomment-6976282174) |
| [#15](https://github.com/Jagarex-lab/nachtsiegel-app/pull/15) | 550 alternative art briefs, authoring checks and five provenance-rich pilots | D: proposal-only authoring package is independent and superseded by actual 550-card/art production. Keep alternative briefs/pilots; port only useful stale-brief guard. | 5 historical workflow runs successful | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/15#issuecomment-6977717477) |
| [#26](https://github.com/Jagarex-lab/nachtsiegel-app/pull/26) | Historical 345edb6 QA/artifact and manual-release proof | D: two unique historical documents contain obsolete manual inputs for 345edb6. Preserve exact originals as history, rather than current release instructions. | 22 historical check jobs successful; not current release authority | [Closed unmerged](https://github.com/Jagarex-lab/nachtsiegel-app/pull/26#issuecomment-6977722829) |

Totals at audit start: **7 open**. Decisions: **C5 / D2 / A0 / B0**. Old merges: **0**. Old-PR repairs/rebases: **0**. Recorded closures: **7**. Original open PRs remaining: **0**; original blockers remaining: **0**. Issue #31 is under replacement work: the authoring guard is locally fixed and awaits final maintenance CI. One new maintenance PR contains the guard and this preservation/reporting work. No branch was deleted.

## Source, target, activity, conflicts and dependencies

Full changed-path accounting is in [PR_CHANGED_PATHS_2026-11-18.json](PR_CHANGED_PATHS_2026-11-18.json): **571 PR/path records** (48+58+40+10+380+33+2), with original-base/head/current-develop blob SHAs and modes. This count includes a path again when changed by more than one PR. Every per-agent file list was checked against its exact Git diff; this is not a capped compare response. Detailed implementation, CI runs/jobs and all branch head SHAs are in [PR_CONSOLIDATION_EVIDENCE_2026-11-18.json](PR_CONSOLIDATION_EVIDENCE_2026-11-18.json).

### PR #4

Source `feature/legacy-engine-p01-p04@e36c9262b3854518afe6ced02f74ae130c1adbde`; target `feature/legacy-foundations`; authored-base SHA `2ff70549d3c5e1c95f4b54c7990acd4d8970363d`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-09T16:27:57Z`; issue/inline/review counts were `0/0/0`. Draft: `false`. GitHub mergeability: `true / clean` (clean relative to the original stacked target). These are audit-time observations, not future merge permission.

Dependencies and scope: Historical base foundations PR #2 at `2ff70549` is already ancestral; #5 and #7 depend on this head.

### PR #5

Source `feature/legacy-engine-p05-p06@27c39f3ee3c20d751bb9fa0caedb5c05f9ab5548`; target `feature/legacy-engine-p01-p04`; authored-base SHA `e36c9262b3854518afe6ced02f74ae130c1adbde`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-09T17:52:13Z`; issue/inline/review counts were `0/0/0`. Draft: `true`. GitHub mergeability: `true / clean` (clean relative to the original stacked target). These are audit-time observations, not future merge permission.

Dependencies and scope: Historical base PR #4; #7 depends on this head.

### PR #7

Source `feature/legacy-engine-p07@023a0e061504acee3f1f3009369065e87a10e968`; target `feature/legacy-engine-p05-p06`; authored-base SHA `27c39f3ee3c20d751bb9fa0caedb5c05f9ab5548`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-09T19:33:33Z`; issue/inline/review counts were `0/0/0`. Draft: `true`. GitHub mergeability: `true / clean` (clean relative to the original stacked target). These are audit-time observations, not future merge permission.

Dependencies and scope: Historical bases PR #5→#4→#2; all actual heads already ancestral.

### PR #11

Source `feature/generic-trigger-hooks@70cc08e482e17ac1bcec53a02ba95c78583df8bf`; target `develop`; authored-base SHA `fde508e85a2866e24653ef25d920a59832d2d653`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-10T17:18:29Z`; issue/inline/review counts were `0/0/0`. Draft: `true`. GitHub mergeability: `false / dirty` (conflicting against current develop). These are audit-time observations, not future merge permission.

Current-develop conflict paths: `scripts/card_system/trigger_model.gd (add/add)`, `scripts/legacy/battle_engine.gd (content)`.

Dependencies and scope: PR #10 merged develop fde508e; bridge head explicitly left 13 executable trigger families plus production Session/replay for later.
The original commits `230859ef18aa656321ab1cf8d0915c5227562b1e` and `70cc08e482e17ac1bcec53a02ba95c78583df8bf` match integrated `f468d1ac00a8ea9759785a10710884a415feac86` and `76fc5ab8b40f03185bd97cdd96498dcd0ad4769c`. Production later extends all 16 automatic trigger families and Session/replay; restoring the old snapshot ABI would discard that evolution.

### PR #14

Source `feature/orafold-audio@edc7309d2633c54fee23175f5213736d27a96bb3`; target `develop`; authored-base SHA `17121e40a49838f479d1655d88d354ed836ad20e`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-10T21:22:30Z`; issue/inline/review counts were `0/0/0`. Draft: `false`. GitHub mergeability: `false / dirty` (conflicting against current develop). These are audit-time observations, not future merge permission.

Current-develop conflict paths: `.github/workflows/audio-qa.yml (add/add)`, `docs/audio/AUDIO-DELIVERY.md (add/add)`, `docs/audio/AUDIO-INTEGRATION.md (add/add)`, `docs/audio/README.md (add/add)`, `scripts/audio/audio_manager.gd (add/add)`, `scripts/audio/audio_settings_panel.gd (add/add)`, `scripts/audio/music_controller.gd (add/add)`, `tests/audio/preview.gd (add/add)`, `tests/audio/run.sh (add/add)`, `tests/audio/runtime_suite.gd (add/add)`, `tests/audio/web_fixture/main.gd (add/add)`.

Dependencies and scope: Authored against `17121e4`; later production/audio integration and native/browser lifecycle fixes supersede isolated activation.
The historical failed feature-push WebKit assertion remains [failed job 130142962447](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/42904417456/job/130142962447): actual empty deck versus expected 30 cards. Successful PR jobs do not erase it. Current baseline QA is independent evidence; the old branch is not being repaired or merged.

### PR #15

Source `production/content-art-pipeline@868481419104a62bd044dae5a856357422614edb`; target `develop`; authored-base SHA `17121e40a49838f479d1655d88d354ed836ad20e`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-10T21:06:38Z`; issue/inline/review counts were `0/0/0`. Draft: `true`. GitHub mergeability: `false / dirty` (conflicting against current develop). These are audit-time observations, not future merge permission.

Current-develop conflict paths: `docs/production/ART_PIPELINE.md (add/add)`.

Dependencies and scope: Based on 17121e4; explicitly reserves PR #11 generic triggers and Session/replay work, observes PR #14 audio untouched, and requires a legal delayed source for Umleitung before activation. Later production engine/catalog/art work integrated through 345edb6 supersedes this preparation package.
The old source branch is retained for the 550 alternative scene/name briefs and five old PNGs. Only the exact five-pilot provenance manifest and immutable image/hash mapping are archived here. The current 550-image set does not imply those old pilots were integrated, nor does visual final status imply commercial clearance.

### PR #26

Source `production/release-ready-alpha03-345edb6@56a11cfc047d6a44c4cea66a38fc991350d5bcd2`; target `develop`; authored-base SHA `345edb6e683d4359b8141ef228683c0855773ac2`. Current audited develop is `6c99dfcbd1bc68b550b3aa61f9dc762f4be8635f`.

Last pre-maintenance activity: `2026-11-11T11:10:22Z`; issue/inline/review counts were `0/0/0`. Draft: `true`. GitHub mergeability: `true / clean` (separate clean historical add-only merge; still obsolete). These are audit-time observations, not future merge permission.

Dependencies and scope: Authored against `345edb6`; automatic develop publisher from PR #29 and synchronous QA from PR #30 supersede manual inputs.
Technical mergeability is not a reason to activate obsolete “current candidate” text or reuse historical QA-run/PUBLISH inputs. The originals are byte-identical only inside the conspicuously historical archive.

## Useful work preserved and adapted

PR #15 contained a real missing integrity guard: a meaningful art brief edit could retain an image’s old final/approved state because the current pipeline did not bind review to the reviewed brief digest. A synthetic one-image probe demonstrated that future-drift gap; it did not show a mismatch among the existing 550 images. [Issue #31](https://github.com/Jagarex-lab/nachtsiegel-app/issues/31) secures the narrow follow-up, implemented in this same maintenance change against the existing pipeline.

The adapted guard pins three original source blobs, stores a technical baseline and reviewed-brief binding, keeps `--check` read-only, and makes `--initialize-brief-baseline` refuse to refresh edited current briefs. Baseline metadata does not claim a new artistic or rights review. Local validation recorded **38 focused local tests (19+4+15)** and a full CLI result of **550 final / 0 missing / 0 orphan / 0 commercial clearance**. The runtime art manifest stayed unchanged; stripping only the added technical baseline/reviewed-brief fields reproduces the original source content. These are local implementation checks, **not new maintenance-head CI**; fresh exact-head and post-merge checks remain pending.

Preservation completed and hash-validated in this worktree:

- [PR #26 exact historical originals](history/pr26-345edb6/README.md), pinned to 56a11cfc, including source Git blobs 535aeaeb…/49239238… and full SHA-256 mapping.
- [Native original failure evidence](history/native-ada9/README.md): compact artifact 13896451760, 262,491 bytes, SHA-256 `95877df888e4b5a129a5bada8fa8032b06e7809623809acb93dff905ffec9bfc`; all eight bounded ZIP entries are logs/JSON and were not executed. Recovery success does not repair the original failure.
- [Five old pilot manifest/provenance](history/pr15-pilots/README.md): exact manifest blob 88e99da9…, full prompts, pending-rights notes and five PNG SHA/blob/permalink records. No old PNG was duplicated or imported; retain source branch before any future archive/deletion decision.
- [Actual published 6c baseline session](history/baseline-public-6c99/README.md): final proof, source-driver mapping, browser result and three real screenshots. Both initial environment failures before gameplay remain explicitly recorded, with TLS verification preserved and temporary CA restoration checked.

[history/archive-manifest.json](history/archive-manifest.json) records all exact copied file digests. [PRESERVATION_CHECKS_2026-11-18.json](PRESERVATION_CHECKS_2026-11-18.json) records successful copy/hash, bounded ZIP, sensitive-token and link checks; independent review found no blockers. `history/.gdignore` keeps these archives and screenshots outside Godot imports. No archived workflow was placed under `.github/workflows`.

The old Umleitung concern is already resolved in existing `production-550-v1`: a legal Ninth starter’s `of-ninth-001` creates an owned delayed hit which native `oa-ninth-e01` redirects. An exact current-source boundary fixture passed 21 assertions for both sides while preserving timing/power/owner/creature identity. The existing trigger suite passed 506 assertions and production-engine suite 4425 assertions / 940 ability fixtures / 1100 accepted real-card commands; these are focused prerequisites, not 1100 complete matches. No rules, costs, five paths or archived 55-card pool were changed.

## All 38 remote branches

This is the complete initial remote inventory (all PR history: 30 PRs, 23 merged, 7 open at audit start). Ahead/behind are branch-only/develop-only commit counts against 6c99dfc. Exact ancestry proves historical integration, not equality of an old whole tree. Full immutable heads, PR history, source commit lists, blockers and safe follow-ups are in the companion evidence. All refs remain retained; archive eligibility is not a deletion that occurred.

| Branch | Head | PR | Ahead/behind | Unique work / disposition |
| --- | --- | --- | --- | --- |
| `alpha/playable-0.1` | `53fb98b18119` | [#8](https://github.com/Jagarex-lab/nachtsiegel-app/pull/8) | 0/206 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `architecture/f2p-economy-design` | `d3634b462444` | [#3](https://github.com/Jagarex-lab/nachtsiegel-app/pull/3) | 0/238 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `audit/legacy-functional-parity` | `51ad544087db` | [#1](https://github.com/Jagarex-lab/nachtsiegel-app/pull/1) | 0/238 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `develop` | `6c99dfcbd1bc` | — | 0/0 | Retain active approved integration/publication source. |
| `feature/alpha-0.2-mobile-ux` | `d8053e9fe6c4` | [#9](https://github.com/Jagarex-lab/nachtsiegel-app/pull/9) | 0/190 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/alpha-automatic-release` | `c0d10e36a033` | [#29](https://github.com/Jagarex-lab/nachtsiegel-app/pull/29) | 0/4 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/arena-quality` | `f6f182f5e820` | — | 0/257 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/brand-world-bible` | `2bce5c33fa51` | — | 0/251 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/card-system-550` | `0835f7c0b058` | [#10](https://github.com/Jagarex-lab/nachtsiegel-app/pull/10) | 0/169 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/combat-presentation` | `b1f5ea59a475` | — | 0/239 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/generic-trigger-hooks` | `70cc08e482e1` | [#11](https://github.com/Jagarex-lab/nachtsiegel-app/pull/11) | 2/167 | C: closed unmerged; integrated content; retain ref through preservation review. |
| `feature/legacy-engine-p01-p04` | `e36c9262b385` | [#4](https://github.com/Jagarex-lab/nachtsiegel-app/pull/4) | 0/236 | C: closed unmerged; integrated content; retain ref through preservation review. |
| `feature/legacy-engine-p05-p06` | `27c39f3ee3c2` | [#5](https://github.com/Jagarex-lab/nachtsiegel-app/pull/5) | 0/233 | C: closed unmerged; integrated content; retain ref through preservation review. |
| `feature/legacy-engine-p07` | `023a0e061504` | [#7](https://github.com/Jagarex-lab/nachtsiegel-app/pull/7) | 0/231 | C: closed unmerged; integrated content; retain ref through preservation review. |
| `feature/legacy-foundations` | `2ff70549d3c5` | [#2](https://github.com/Jagarex-lab/nachtsiegel-app/pull/2) | 0/237 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/orafold-audio` | `edc7309d2633` | [#14](https://github.com/Jagarex-lab/nachtsiegel-app/pull/14) | 3/164 | C: closed unmerged; integrated content; retain ref through preservation review. |
| `feature/orafold-campaign` | `fdeaceff9dff` | [#18](https://github.com/Jagarex-lab/nachtsiegel-app/pull/18) | 0/157 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/orafold-economy` | `d230e7176129` | [#16](https://github.com/Jagarex-lab/nachtsiegel-app/pull/16) | 0/159 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/orafold-online` | `67c734b92d9f` | [#17](https://github.com/Jagarex-lab/nachtsiegel-app/pull/17) | 0/160 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/premium-experience` | `f3d3c7b0c082` | — | 0/244 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/premium-mobile-experience` | `2ce222a38642` | [#28](https://github.com/Jagarex-lab/nachtsiegel-app/pull/28) | 0/10 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/qa-synchronous-polling` | `bad5803e8b60` | [#30](https://github.com/Jagarex-lab/nachtsiegel-app/pull/30) | 0/1 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `feature/ux-contrast` | `927ae10cdfcf` | — | 0/254 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `lore/orafold-worldbuilding-550-draft` | `2a8d3390d4f7` | [#12](https://github.com/Jagarex-lab/nachtsiegel-app/pull/12) | 45/167 | 45 ahead commits are squashed history;31/31 authored blobs identical. Archive-eligible. |
| `main` | `caaa00169a7c` | — | 0/310 | Retain main unchanged. |
| `production/alpha03-final-integration` | `a52a1b571f7f` | [#27](https://github.com/Jagarex-lab/nachtsiegel-app/pull/27) | 0/26 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/audio-integration` | `8a16ad6d0666` | [#24](https://github.com/Jagarex-lab/nachtsiegel-app/pull/24) | 0/112 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/audit-cleanup` | `70e6c23480e2` | [#13](https://github.com/Jagarex-lab/nachtsiegel-app/pull/13) | 0/165 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/catalog-engine` | `82ded528c772` | [#19](https://github.com/Jagarex-lab/nachtsiegel-app/pull/19) | 0/48 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/content-art-pipeline` | `868481419104` | [#15](https://github.com/Jagarex-lab/nachtsiegel-app/pull/15) | 4/164 | D: retain source branch for550 alternative briefs/five PNG originals; guard port in this maintenance PR. |
| `production/full-pool-simulation-coverage` | `b157b4b36f8f` | [#25](https://github.com/Jagarex-lab/nachtsiegel-app/pull/25) | 0/106 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/individual-art-batch2` | `ba09e105cdcd` | [#23](https://github.com/Jagarex-lab/nachtsiegel-app/pull/23) | 0/49 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/kernel-printed-semantics` | `64c745ef3d3a` | [#21](https://github.com/Jagarex-lab/nachtsiegel-app/pull/21) | 0/122 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/native-platform-qa` | `5e4befc16515` | [#22](https://github.com/Jagarex-lab/nachtsiegel-app/pull/22) | 0/120 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `production/release-ready-alpha03-345edb6` | `56a11cfc047d` | [#26](https://github.com/Jagarex-lab/nachtsiegel-app/pull/26) | 1/47 | D: closed unmerged; exact 2 unique files archived; no manual input reuse. |
| `production/resource-models` | `cc5421f5db32` | [#20](https://github.com/Jagarex-lab/nachtsiegel-app/pull/20) | 0/121 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |
| `qa/recover-native-ada9` | `f75162851bbd` | — | 1/14 | Unique one-shot read-only workflow completed; evidence ZIP secured. Archive-eligible after durable acceptance/ref recheck. |
| `security/pages-release-gate` | `dadb8471eaea` | [#6](https://github.com/Jagarex-lab/nachtsiegel-app/pull/6) | 0/235 | Exact develop ancestor; no head-only commits. Archive-eligible after ref recheck. |

Among the 29 development branches without an initial open PR (excluding develop/main), 27 are exact ancestors, one lore branch is content-equivalent through squash `795be306`, and the only genuinely unique branch is the now-preserved native evidence recovery. No unintegrated product feature was found there. A naive “45 ahead means missing lore” or patch-ID-only conclusion would be false: all 31 authored lore/data blobs match exactly. Before later branch deletion, re-read the current remote head and develop, preserve its full SHA and ensure all required historical source/evidence has a durable home. PR #15 remains retained because its alternative briefs/old PNG content is not fully duplicated in this compact archive.

## Workflow and release hygiene

The pinned develop tree has 11 executable workflows; GitHub’s registry retains 13 active entries. Exactly **one publisher** exists: `.github/workflows/pages-release.yml`, the only workflow granting Pages/OIDC writes and using deploy-pages. The extra registry entries are completed branch-only `native-evidence-recovery.yml` and historical read-only authoring `production-content.yml`, both absent from develop. They do not create alternate release routes. Reusable audio/integration/native QA and existing overlapping gates are still used by the release contract; zero standalone runs is not evidence they are unused.

The staged `.yml.in`, historical manual guard rules and read-only activation review tool are inactive/history, not publishers. Keep automatic develop publication, immutable tested artifact selection, protected `github-pages` environment and concurrency. No workflow, branch-protection, environment, token or publisher setting was changed. Rulesets returned `[]`; classic develop protection returned 403, so its details are not established. The Pages environment allows develop/main, but the publisher itself still gates develop only.

## Baseline validation and final evidence contract

These results belong only to the audited, already published 6c99dfc baseline: all seven required post-merge suites and 29 jobs succeeded; six publisher events correctly skipped while waiting and [run 44250211904](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44250211904) published and verified the exact tested artifact. Main QA run 44243912891 used artifact 14401622092. Public Chromium/WebKit integrity/menu receipt: [artifact 14403288321](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44250211904/artifacts/14403288321). The separately archived actual-public Chromium Android-viewport full AI duel/replay/restart completed with 0 errors, without physical-device certification.

| Baseline suite | Exact 6c run | Jobs | Result |
| --- | --- | --- | --- |
| `alpha-qa.yml` | [44243912902](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912902) | 4 | success |
| `campaign-orafold-qa.yml` | [44243913060](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243913060) | 1 | success |
| `economy-qa.yml` | [44243912935](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912935) | 1 | success |
| `legacy-foundations.yml` | [44243912947](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912947) | 1 | success |
| `online-qa.yml` | [44243912927](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912927) | 1 | success |
| `release-safety.yml` | [44243912918](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912918) | 1 | success |
| `web-preview.yml` | [44243912891](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44243912891) | 20 | success |

The new maintenance PR/head, its eventual merge SHA, fresh exact-head CI, fresh post-merge 29 jobs and fresh publication/public verification are **pending** in this snapshot. The merge SHA cannot be known inside the commit whose content determines it. After the actual merge, the maintenance PR final comment must link that exact merge SHA, its seven QA suite runs / 29 jobs, publisher run/artifact and successful public verification; the live [release-evidence.json](https://jagarex-lab.github.io/nachtsiegel-app/release-evidence.json) and [build-info.json](https://jagarex-lab.github.io/nachtsiegel-app/build-info.json) are authoritative public provenance. This avoids an endless self-referential source-update cycle. Do not replace this pending statement with an invented SHA or reuse old QA for a new head.

All 550 cards/illustrations and premium frames, illustrated 2.5D arena and experimental 3D option, campaign/economy, audio, AI/deckbuilder, replay, PWA/touch/mobile behavior and automatic publication are preserved. There are no gameplay, lore, economy, rights-clearance or production image changes in this consolidation. Existing physical-device, commercial rights and listening acceptance limits remain explicit.


## Nachtrag: zusätzliche Lebenszyklusprüfung der Kampagnen-Präsentation

Der zweite Folge-Head `2b65e552206f8210e4464bac55004a882c5276f5`
wird ebenfalls nicht gemergt. Die authentifizierte Quellen-/Keyring-Auswahl,
APT-Wiederherstellung und Browserinstallation bestanden nun auf dem echten
GitHub-Runner. Danach meldete der tatsächliche integrierte
[Job 134852161496](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44318867224/job/134852161496)
beim Präsentationstest trotz 32 erfolgreichen Assertions ein ObjectDB-Leck
und zwei noch verwendete Ressourcen. Der strikte Guard hat die Suite korrekt
abgebrochen; folgende Online-/Hosted-Prüfungen liefen dort nicht.
[Originalarchiv und maschinenlesbarer Nachweis](history/ci-183192/presentation-failure.json)
erhalten den Fehler samt SHA256.

Die separate Untersuchung verwendet den exakten Kandidatenbaum und geprüfte
Abhängigkeiten. Der unveränderte lokale Test ließ sich ohne Leck beenden; die
konkreten zwei CI-Ressourcentypen waren im nicht-verbose CI-Protokoll nicht
benannt und werden nicht erfunden. Eine neue deterministische Prüfung fand
jedoch eine echte Test-Lebenszykluslücke: Nach Freigabe der UI sind ihr aktueller
Adapter, Session und Modell bereits frei, während die lokale Testvariable
`abandoned` den absichtlich verlassenen Adapter bis zum Shutdown hält.
Mit allen 32 ursprünglichen und vier zusätzlichen Prüfungen scheitert genau
diese letzte Ownership-Prüfung vor der Korrektur (36 Assertions, ein Fehler).

Die eng begrenzte Korrektur gibt ausschließlich diese test-eigene Referenz vor
dem echten Audio-Shutdown frei. Keine Produktreferenz wird künstlich gelöscht;
Runtime, Regeln, Leak-Guards und die ursprünglichen 32 Tests bleiben unverändert.
Fünf lokale Wiederholungen bestanden mit 36/0 Assertions ohne Runtime-/Leak-
Meldungen (ein verbose und vier unveränderte nicht-verbose Befehle). Das
unabhängige Review prüft die eng begrenzte Teständerung. Die vollständige
frische exakte Head-/Merge-QA bleibt erforderlich; deren Ergebnisse
werden erst nach ihrer tatsächlichen Ausführung im
[Abschlusskommentar von PR #34](https://github.com/Jagarex-lab/nachtsiegel-app/pull/34#issuecomment-6979959291)
als eigene Nachweise verlinkt. Alte fehlgeschlagene Heads bleiben Fehler.


## Nachtrag: dokumentierte Ubuntu-Quellenvarianten im separaten Kampagnenlauf

Der Head `af6f74eb2dbb4111a730b2f92074546b05c510ed` bleibt ebenfalls
ungemergt. Die integrierten Module bestanden nun tatsächlich vollständig:
Präsentation 36/0 ohne Leck, echtes Online-Produktduell, Hosted-Anwendung
37/0 und Match-Belohnungen 102/0. Die zusätzlich wegen des Testpfads gestartete
eigenständige Kampagnen-Suite bestand ihre nativen Tests ebenfalls, scheiterte
aber in [Job 134866753544](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44323018819/job/134866753544)
vor APT am gemeinsamen URI-Guard. Sie verwendete das andere offizielle
Image `ubuntu24/20261111.127.1`; der genaue zurückgewiesene URI wurde vom
bisherigen Guard nicht ausgegeben. Seine öffentlichen Image-Refs liefern404.
Eine konkrete historische URI wird deshalb nicht als nachgewiesen behauptet.

Der [vollständige erhaltene Job-Log und Quellenbeleg](history/ci-183192/campaign-source-variant.json)
verweist auf zwei immutable offizielle runner-images-Korrekturen: Cloud-Init
kann kanonische HTTP-Ubuntu-Adressen mit/ohne End-Slash hinterlassen; die
spätere AWS-Unterstützung behandelt zusätzlich exakt
`http://us-east-2.ec2.archive.ubuntu.com/ubuntu`. Der Installer normalisiert
ausschließlich die acht so dokumentierten Literale (archive, security, Azure,
dieser EC2-Host; je mit/ohne Slash) im geschützten Snapshot auf die bereits
erlaubten offiziellen archive-/security-HTTPS-Endpunkte. Kein HTTP- oder
Cloud-Host wird dabei kontaktiert; Originalquellen bleiben unverändert.

53 lokale CI-Vertragstests bestehen. Eine echte netzwerkfreie APT-Aufzählung
beweist EC2-Eingabe → ausschließlich offizielles HTTPS während der
Systemphase → Originalquellen nach Wiederherstellung. Unbekannte Hosts, andere
Regionen, Zugangsdaten, Ports, Parameter und Host-Suffixtricks bleiben Fehler.
Diagnosen begrenzen Scheme/Host und geben einen Hash aus, niemals Userinfo,
Pfad, Query, Fragment oder rohe Parserfehler. TLS/GPG, Schlüssel-Pin, strikte
APT-Fehler, Hostprüfung, Cleanup, Deadlines und Versuchsgrenzen bleiben aktiv.

Dieser weitere kleine Installer-/Testfix benötigt erneut vollständige frische
PR-QA (jetzt fünf Suiten/27 Pflichtjobs, einschließlich der eigenständigen
Kampagne) und anschließend sieben Suiten/29 Jobs auf dem tatsächlichen Merge.
Kein fehlgeschlagener oder abgebrochener alter Head liefert die Freigabe.


## Nachtrag: einheitliche Audio-/Browser-Testwerkzeuge

Auf demselben nicht gemergten Head af6 scheiterte zusätzlich die reale
[Audio-Produktprobe](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44323018870/job/134866986702):
Chromium bestand alle acht Prüfungen; WebKit bestand sechs einschließlich
echter PCM-/Settings-/Quota-Recovery-Prüfungen, stürzte aber beim dritten
vollständigen Produktladen für den Future-Version99-Spiegeltest ab.
`page.evaluate: Target crashed` ist ein echter fehlgeschlagener Test.
OOM oder konkrete Allokationsursache wurden nicht ausgegeben und werden
nicht behauptet. Das [unveränderte Originalartefakt und seine Prüfsummen](history/ci-183192/audio-probe-failure.json)
bleiben erhalten.

Nachweisbare Werkzeugabweichung: Die Audio-Suite verwendete als einzige
Playwright1.62.1, während die acht anderen npm-Browserinstallationen1.65.0
verwenden (neun Installationen in sieben bestehenden Workflows insgesamt).
Die einzige Workflowänderung dieses Wartungspakets gleicht genau diese eine
Versionszeile in `audio-qa.yml` an. Eine neue stdlib-Prüfung liest alle aktiven
Installationspfade und verlangt exakte, einheitliche Pins; sie scheiterte vor
der Korrektur am echten Drift und besteht danach. Keine Audioassertion, kein
Reload, keine Lifecycle-/Timing-Annahme, Berechtigung oder Freigabesperre
wird verändert. Der Publisher bleibt unverändert und allein zuständig.

Unabhängiges Review genehmigte die eng begrenzte Korrektur. Lokal bestanden
anschließend vollständig **54 CI-,50 Release-Python- und88 Node-Vertragstests**.
Anfängliche Auslassungen der sparsamen lokalen Arbeitskopie (fehlende
committete Staging-/Shell-/Mirror-Testdateien) sind im maschinenlesbaren
Nachweis samt begrenzten Fehl-/Teilresultaten erfasst; nach unveränderter
Materialisierung bestanden alle vollständigen Suiten. Kein Test wurde dafür
geändert oder entfernt. Das lokale WebKit-Probeexperiment hatte fehlende
Systembibliotheken und wird nicht als bestandene Produktprüfung gezählt.

Die Versionsangleichung beweist allein keine Ursache des alten Absturzes.
Erst die neue vollständige gehostete Chromium-/WebKit-QA mit unveränderter
Audio-Probe, dann die frischen Merge-Prüfungen und öffentliche Verifikation
können den endgültigen Kandidaten freigeben. Die endgültigen Nachweise
stehen nach tatsächlicher Ausführung im stabil verlinkten PR-Abschlusskommentar.


## Nachtrag: nichtvisuelle API-Identitätsprüfung ohne Paint-Abhängigkeit

Ein weiterer echter Fehler desselben af6-Heads war der kontrollierte
[WebKit-Pollingtest](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44323018870/job/134881337627),
vor allen eigentlichen Spiel-Journeys. Ein Blatt lief nach500ms aus, sieben
andere bestanden; Nodes zwei Fehler zählen dieses Blatt plus seine Elternsuite.
Der erste Kontrollfall benötigte auf dem Runner11,768s; beide realen
Produkt-Readiness-Positivfälle bestanden mit979/969ms. Ein konkreter
Scheduling-Trace des ursprünglichen Timeouts liegt nicht vor.
[Originalartefakt, exakter Fehlerauszug und Prüfsummen](history/ci-183192/polling-probe-failure.json)
trennen diese Fakten von der anschließenden kontrollierten Ursachenprobe.
Das kleine GitHub-Artefakt enthält ausschließlich Installationslogs; der
eigentliche Fehler steht im gesondert exakt erhaltenen stdout-Auszug.

Die reine Argument-Identitätsprüfung wartete bislang auf Animationsframes,
obwohl sie kein Rendering untersucht. Die enge Testkorrektur bestätigt zuerst
das vollständig bereite about:blank-Dokument im echten Main-World-Kontext
und verwendet ausschließlich für dieses Blatt20ms-Intervallpolling. Die
ursprüngliche500ms-Frist bleibt unverändert. Alle Assertions, der30s-Gesamtrahmen,
die250ms-Asynckontrolle, alle vier400ms-Negativkontrollen und beide realen
Produkt-Positivfälle mit Standard-RAF/4000ms bleiben unverändert.

Die tatsächliche kontrollierte Chromium-Probe zeigte: Bei absichtlich
angehaltenem RAF scheitert die alte Variante mit echtem Timeout nach502ms;
die neue liefert3 nach43ms, während das Node-Argument0 bleibt. Das beweist
die entfernte sachfremde Paint-Abhängigkeit, nicht den exakten ursprünglichen
CI-Schedulingverlauf. Die vollständige Chromium-Suite bestand9/9 (acht
Blätter plus Elternsuite); ein unabhängiges Review genehmigte die Änderung.
Lokale finale Verträge auf dem kombinierten Kandidaten:54CI-,50Release-
Python- und88Node-Tests erfolgreich.

Eine zusätzlich versuchte lokale WebKit-Einrichtung blieb an der unveränderten
Host-Prüfung für lokal extrahierte Bibliotheken stehen. Signierte Vendor-Herkunft
und tatsächliches Laden wurden geprüft, aber kein Hostcheck deaktiviert,
kein SDK gepatcht, kein alternativer Executable-Pfad zur Umgehung gewählt und
keine globale Konfiguration verändert. Es wird kein lokaler WebKit-Erfolg
behauptet. Erforderlich bleiben alle frischen fünf PR-Suiten/27 Jobs, dann
sieben Merge-Suiten/29 Jobs, automatischer Publisher und öffentliche Browserabnahme.


## Nachtrag: frische Merge-QA scheitert am äußeren nativen Zeitrahmen

PR #34 wurde erst nach eigenständiger roher API-Prüfung aller27 erfolgreichen
Head-Jobs auf c45 regulär als `119ceb09c4e6344a70e1dab38e9833a93c38e2aa`
integriert. Baum b94 entspricht exakt dem geprüften Kandidaten; Eltern sind
183192 und c45. Danach liefen alle sieben neuen develop-Suiten auf exakt119ceb.
Main20/20 und die fünf separaten Suiten bestanden; Alpha wurde im nativen Job
[134937011046](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44342790300/job/134937011046)
am äußeren45-Minuten-Limit beendet. Insgesamt26 erfolgreiche Jobeinträge sind
keine29er-Freigabe: der native Job ist cancelled und die unexpandierte
Browser-Abhängigkeit skipped.119ceb wurde nicht veröffentlicht.

Die [Originalannotation und der vollständige erhaltene Log](history/ci-119ceb-native-timeout/incident.json)
beweisen `The job has exceeded the maximum execution time of 45m0s`.
Einrichtungen/Import kosteten rund12Minuten; der letzte Selector-Marker23/0 lag
64Sekunden vor Abbruch. Weitere vorherige Marker: Board11516/0 und Desktop235/0.
Die laufende nächste Suite erreichte ihre eigene600s-Frist nicht. Im
vollständig erfolgreichen Lauf des identischen Inhaltsbaums (c45,23Minuten)
blieben nach diesem Marker noch12,91Minuten für native UI, Storage, Art,
Archiv, Sicherheitsprüfungen und drei Exporte. Diese ausstehenden Arbeiten
werden weder übersprungen noch aus älteren Nachweisen als bestanden übernommen.

Der notwendige kleine Folge-PR #35 startet direkt vom tatsächlichen119ceb und
ändert ausschließlich den äußeren nativen Orchestrierungsrahmen45→75 Minuten,
plus zwei erläuternde Kommentare. Vollständiger YAML-Semantikvergleich und
unabhängiges Review bestätigen alle anderen Befehle, Schritte, Jobs,
Prozess-/Aktions-/Matchfristen, Browserbudgets, Assertions, Leak-Guards,
Permissions und den unveränderten einzigen Publisher. Alle29 Pflichtjobs
bleiben verpflichtend.75Minuten sind endlicher Ausführungsraum, keine
behauptete erfolgreiche Prüfung und keine geänderte Produkt-Performance-SLA.

Lokal54CI-,50Release-Python- und88Node-Verträge erfolgreich. Der native
Komplettablauf muss auf dem endgültigen neuen PR-Head tatsächlich fertiglaufen;
danach bleibt erneut vollständige frische QA auf dem wirklichen Folge-Merge
notwendig. Keine partielle Wiederholung und kein alter QA-Run ersetzt sie.
Issue #33 wurde für den präzise belegten Folgeblocker wieder geöffnet; die
ursprünglichen sieben PR-Abschlüsse sowie die Integrationen #32/#34 bleiben
nachvollziehbar erhalten. Die Originalquellbranches werden nicht gelöscht.

Der tatsächlich ausgeführte automatische [Preflight44354187198](https://github.com/Jagarex-lab/nachtsiegel-app/actions/runs/44354187198)
wies119ceb ausdrücklich mit `Denied: QA not successful: .github/workflows/alpha-qa.yml`
zurück. Publish und öffentliche Verifikation wurden deshalb übersprungen.
Das ist der gesicherte Beleg der aktiven Sperre; keine Veröffentlichung aus
den26 erfolgreichen Teilresultaten wird behauptet.
