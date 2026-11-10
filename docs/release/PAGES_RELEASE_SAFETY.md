# Manueller Pages-Release im Solo-Alpha-Betrieb

Aktuelle Freigabe des Auftraggebers: Die Testversion darf ersetzt werden. Eine zweite GitHub-Identität ist nicht erforderlich. Diese Entscheidung ersetzt die frühere verpflichtende Zwei-Personen-Freigabe, nicht bestehende GitHub-Schutzregeln.

## Ablauf

1. PR8 mit allen enthaltenen Legacy-Abhängigkeiten vollständig testen. Ihre Heads sind bereits enthalten: PR1–7 nicht erneut integrieren. Alten automatischen Publisher deaktiviert lassen, bis develop nachweislich den reinen CI-Workflow enthält.
2. Grünen PR8 regulär nach develop integrieren. GitHub-Branchschutz beachten, keine Admin-/Review-Umgehung.
3. Reine `NACHTSIEGEL CI (no deployment)` auf dem tatsächlichen develop-Head erfolgreich ausführen. Ihr Artefakt `nachtsiegel-arena-qa` enthält den getesteten Alpha-Webbuild. Weder Push noch PR veröffentlichen.
4. `Manual production Pages release` ausdrücklich auf develop starten: vollständiger Commit-SHA, erfolgreiche develop-QA-Run-ID, Bestätigung `PUBLISH <SHA>`. Kein zusätzlicher Repository-Variablenschalter notwendig.
5. Der Guard verlangt aktuellen develop-Head, übereinstimmenden Dispatch-SHA, richtige Repository-/Workflow-/Run-Identität, abgeschlossene erfolgreiche QA und ein unexpired Artefakt. Vor und nach eventuell aktiven GitHub-Environment-Gates wird erneut geprüft. Keine Neuerstellung des Spiels während des Releases: veröffentlicht wird das getestete Artefakt.
6. Live `build-info.json`, Ressourcen unter `/nachtsiegel-app/`, Hauptmenü und vollständige KI-Partie im Browser prüfen. SHA/Run dokumentieren; vorher keinen Veröffentlichungserfolg behaupten.

## Minimale GitHub-Einstellungen

Pages muss GitHub Actions verwenden. Das bestehende Environment `github-pages` muss develop erlauben. Aktive Reviewer-/Timer-/Branchschutzregeln werden von GitHub selbst durchgesetzt; der Prozess löscht oder umgeht sie nicht. Kein zweiter Reviewer wird durch den Guard verlangt. Eine zusätzlich erlaubte main-Branch im Environment ist kein Releasepfad: der Workflow selbst akzeptiert ausschließlich develop und keine Tags.

Manuelle Workflows müssen auf dem Defaultbranch verfügbar sein. Falls Defaultbranch main den Releaseworkflow noch nicht enthält, kann der Owner nach getesteter Integration den Defaultbranch auf develop setzen (Settings → General → Default branch). Das ändert keine Dateien auf main und keine Branchschutzregeln. Anschließend den jetzt reinen CI-Workflow aktivieren, falls er noch disabled_manually ist. Kein Wiederaktivieren des alten Publishers vor dieser Integration.

Keine Releasevariable, kein zweites Konto, kein alternativer Token/Publisher erforderlich. Fehlende API-Berechtigungen bleiben echte Fehler und werden nicht verschluckt.

## Rollback

Bei fehlerhafter Veröffentlichung den gewünschten vorherigen Quellstand als regulär geprüften Revert-PR nach develop bringen, vollständige QA auf dessen aktuellem SHA abwarten und denselben manuellen Release auslösen. Keine historischen ungeprüften Artefakte und keine direkte Umgehung von Branch-/Environmentregeln. Live-SHA danach erneut prüfen.

## Automatische Nachweise

`python3 -m unittest discover -s tests/release -v`: acht Testgruppen, einschließlich Push/PR/Tags/Workflow-Run-Ablehnung, ungültiger Bestätigung, falscher/veralteter SHA, fremder QA, fehlendem/abgelaufenem Artefakt, Solo-Environment und Privilegiengrenzen. Ausschließlich der manuelle Releaseworkflow besitzt Pages-/OIDC-Schreibrechte.
