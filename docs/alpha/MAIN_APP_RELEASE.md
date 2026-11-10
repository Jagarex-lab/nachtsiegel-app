# ORAFOLD als reguläre Hauptanwendung – 2026-11-10

**Aktualisierte Solo-Freigabe:** Die frühere verpflichtende zweite Reviewer-Identität ist aufgehoben. Die unten dokumentierte ursprüngliche Administrationshürde ist historisch. Maßgeblich ist jetzt [der manuelle Solo-Releaseprozess](../release/PAGES_RELEASE_SAFETY.md), ohne Releasevariable und ohne Eingriff in aktive GitHub-Schutzregeln. Aktuelle Integration/Live-SHA werden im Abschlussbericht und PR8 dokumentiert.

Freigabe:Der Auftraggeber genehmigt Integration und Ersatz des bisherigen Pages-Testbuilds, unter Beachtung bestehender Schutzregeln. Der neue Stand ersetzt die normale Navigation, nicht die Legacy-Regelreferenz.

## Umsetzung

Normale Hauptszene jetzt `scenes/alpha_shell.tscn` für Web/Desktop/Android. Vier echte Hauptmenüpunkte:Spielen, Deckbuilder, Sammlung, Einstellungen. Starterdeck, Schwierigkeit und Bewegung werden lokal gespeichert. Spielen startet unmittelbar die Partie inklusive Mulligan/Ursprung/Zweiter Möglichkeit. Sammlung ist durchsuchbar/filterbar mit Großansicht und ohne Deckbearbeitung.

Öffentlich entfernt:Archivknopf, Alpha-/Legacy-Umschalter, alter Alpha-Vorschau-Link, indirekte Startumleitung und ungenutzte Gameplayvideo-Kopie im Alpha-Webexport. Kein URL-Schalter aktiviert Legacy. Alte UI-Komponenten bleiben dort erhalten, wo Regressionstests sie tatsächlich benutzen. `Archive Web QA`/`Legacy UI QA` sind separate Testexporte, keine öffentliche Navigation. Normales `Web QA` startet ebenfalls Alpha.

Die Heads aller PRs1–7 sind bereits Vorfahren des PR8-Heads9af6ff9. Kein erneutes Cherry-Pick oder blinder Merge dieser Änderungen nötig. PRs bleiben bis erlaubter Integration unverändert. Referenzengine, Kartenwerte, Kampflogik und F2P bleiben unverändert.

## Prüfungen

Neue Tests prüfen alle vier Hauptmenüpunkte, keine öffentlichen Alt-Modi, Sammlung/Detail, gespeicherte Einstellungen und alle vier Starter in der tatsächlichen UI. Browser-QA benutzt `/nachtsiegel-app/` und spielt vier Alpha-Partien (je Macht eine) sowie das erhaltene Legacy-Duell im separaten QA-Build. Bestehende Node-/Godot-/Archivregression bleibt aktiv. Endgültiger Kandidat und CI-Nachweise:aktualisierte Beschreibung von PR8; frühere QA_REPORT-Abnahme8c1d342 ist historisch und kein Nachweis für diese Änderung.

## Noch nicht veröffentlicht – bestehende Sicherheitsgrenze

Read-only-Abfrage:Pages-Quelle=workflow, URL unverändert, alter Publisher406254158 weiterhin disabled_manually. Environment github-pages hat **keine required reviewers**, erlaubt Adminbypass und main/develop. Administration für Branchschutz/Actions/Releasevariable liefert mit den verfügbaren App-Zugangsdaten HTTP403. Nominales admin:true in Repo-Metadaten ersetzt diese fehlenden API-Berechtigungen nicht. Nur Jagarex-lab als aktueller Collaborator gefunden; kein zweiter Reviewer erfunden.

Der bestehende Guard (`tools/release/guard.py`) verlangt einen echten Reviewer, Self-Review-Sperre, ausgeschlossenen Adminbypass und ausschließlich develop. Kein alternativer Publisher/Token umgeht diese Vorgaben. Daher bis zur nachweislich wirksamen Einrichtung kein develop-Merge und kein Release-Dispatch. Freigabe zur Veröffentlichung ist vorhanden, technische Voraussetzungen noch nicht.

## Kurze Administrator-Anleitung

1. Settings → Environments → github-pages:Echten berechtigten Reviewer benennen, Prevent self-review aktivieren, Adminbypass deaktivieren; ausgewählte Deploymentbranches nur develop. Ein Dispatcher darf seinen eigenen Release nicht freigeben.
2. Develop-Branchschutz und Actions-read-only prüfen. Pages bleibt GitHub Actions. Alten Publisher deaktiviert lassen, bis dessen Develop-Datei garantiert nur CI enthält.
3. Den vollständig grünen aktualisierten PR8 regulär integrieren, während der alte Publisher noch deaktiviert ist. Dann den nun nachweislich reinen CI-Workflow aktivieren. Kein separater Merge von PR1–7 nötig, ihre Heads sind bereits enthalten; keine Admin-/Review-Umgehung.
4. Den geschützten manuellen Releaseworkflow auf dem Defaultbranch verfügbar machen (z.B. Defaultbranch nach Integration auf develop setzen). Die reine Web-QA auf develop manuell auslösen und den vollständigen Erfolg für den tatsächlichen Mergecommit abwarten. Der bestehende Guard akzeptiert zusätzlich zum Push diese manuelle QA bei unverändert strikter SHA-/Branch-/Artefakt-/Environmentprüfung.
5. PAGES_RELEASE_ENABLED=true setzen und `Manual production Pages release` auf develop mit exaktem SHA, QA-Run-ID und `PUBLISH <SHA>` starten; Environmentreview durchführen. Danach Schalter wieder false. URL/build-info und Desktop-/Touchabläufe live prüfen.

Bei fehlendem zweiten berechtigten Reviewer oder nicht unterstützten Schutzoptionen ist eine konkrete Änderung des Freigabeprozesses separat zu entscheiden; keine stillschweigende Abschwächung. Rollback bleibt derselbe geschützte, getestete Releaseweg. Bis zum tatsächlichen Deploy zeigt die bekannte Pages-URL weiterhin den alten Stand.
