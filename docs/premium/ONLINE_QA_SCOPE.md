# Online-QA: Transportfixture und tatsächliches Produktionsduell

## Nachgewiesener Fehler

Im PR-Lauf für Quellstand `5654b48` scheiterte Job `130758057284` im
180-Sekunden-Schritt `online-demo-fixture`. Alle 34 vorhergehenden
Node-Servertests bestanden. Das Demo-Log enthielt nur den npm-Starttext; danach
beendete `timeout` den Prozess mit Status 124. Die anschließende
Bridge-Verbindungsrücksetzung trat beim Aufräumen auf und belegt für sich keinen
vorhergehenden Stillstand der Kampfengine.

Seit Commit `568dc80` führen **beide** npm-Aliase `demo` und `demo:duel` dieselbe
Datei `tools/real-duel.ts` aus: eine vollständige Partie mit der produktiven
Godot-Engine. Der Integrationswrapper behandelte den ersten Aufruf weiterhin
als kurzes Transportfixture mit 180 Sekunden, den zweiten als vollständiges
Produktionsduell mit 900 Sekunden. Die Partien erhalten jeweils einen zufälligen
Serverseed; ihre Laufzeit ist deshalb verschieden. Jede akzeptierte Aktion
rekonstruiert und prüft das bisherige Kampfjournal.

Eine zusätzliche, ausschließlich diagnostische Ausführung des unveränderten
Produktionsduells auf lokalem Stand
`3e213824b7db9b1b1b2cc5f58eede3dc2eed9725` protokollierte die Bridge-Aufrufe:

- Runde 25, 87 gespeicherte Kommandos: `play` begann nach 179,135 Sekunden.
- Die Aktion wurde nach 5,550 Sekunden erfolgreich beantwortet; danach enthielt
  das Journal 88 akzeptierte Kommandos.
- `endTurn` begann nach 184,705 Sekunden. Der Prozess wurde an der vorher
  festgelegten 190-Sekunden-Diagnosegrenze beendet: **Status 124, kein Testpass,
  keine abgeschlossene Partie**.
- Ein anschließender kontrollierter Worker-Stop bestand mit Status 0.

Das beweist, dass das kurze Zeitbudget eine noch regelkonform fortschreitende
Partie abbrechen kann. Der genaue zufällige Seed des ursprünglichen fehlgeschlagenen
CI-Demos wurde dort nicht protokolliert; dessen individueller Verlauf wird
deshalb nicht als rekonstruiert ausgegeben. Es gibt keinen behaupteten Fix der
Bridge oder der Kampfregeln.

Diagnosebelege: `work/premium-mobile/online-timeout/diagnosis.json`,
`progress.log`, `worker.log` und `shutdown.log`. Das sind lokale Arbeitsartefakte.
Der vollständige ursprüngliche Fehlversuch bleibt im GitHub-Actions-Protokoll
und im Artefakt `13887034435` erhalten.

## Korrektur und unveränderte Grenzen

`tools/test_alpha03.sh` ruft im 180-Sekunden-Schritt ausdrücklich das bestehende
`npm run demo:transport` auf. Dieses Werkzeug verwendet absichtlich den
gekennzeichneten Simulationsadapter und prüft Registrierung, Anmeldung,
Matchmaking, authentifizierte WebSockets, Duplikatschutz, Ablehnung eines
manipulierten Befehls, Reconnect, Abschluss und Historie. **Es ist kein
ORAFOLD-Kampf- oder Balancingnachweis.**

Der separate 900-Sekunden-Aufruf `npm run demo:duel` bleibt eine vollständig
gespielte Partie mit der produktiven Godot-Engine und den 550 Karten. Die
34 Servertests, Sicherheitsprüfung, Godot-Clienttests und der Vergleich des
Offline-Ziehübergangs bleiben erhalten. Kein Timeout wurde erhöht und kein
Workflow oder Testjob entfernt. Es gibt keine automatische Wiederholung.

Der neue Prüfer `tools/alpha03/check_online_demo.py` trennt beide Nachweise:

- Transport: ein vollständig lesbares JSON-Ergebnis, ausdrücklich
  `simulation-only`, zwei Teilnehmer, ein abgeschlossenes Match, ein Reconnect,
  eine erwartete Sicherheitsablehnung, mindestens zwölf vollständig erfolgreiche
  gemessene Anfragen und keine unerwarteten Fehler.
- Produktion: `simulation: false`, das tatsächliche 550-Karten-Regelprofil,
  beide Mulligans und Ursprünge, abgeschlossener Spielstart und Kampf,
  reguläres terminales Duellergebnis, konsistente Kommando-/Replayanzahl und
  vollständiger SHA256-Endzustand. Ein reguläres Unentschieden bleibt zulässig.
- Abgeschnittene Ergebnisse, mehrere Ergebnisobjekte und nachfolgende
  Fehlerausgaben scheitern. Lediglich die bekannte npm-Updateinformation nach
  einem vollständigen Ergebnis ist zulässig. Der bestehende strikte
  Laufzeitfehler-/Leakscanner läuft zusätzlich weiter.

## Ausgeführte Prüfungen

Am 11.11.2026 wurden für diese Korrektur ausgeführt:

| Prüfung | Ergebnis und tatsächlicher Umfang |
| --- | --- |
| Neues reales `demo:transport` | Exit 0; zwei lokale Accounts, 12 erfolgreiche WebSocket-Anfragen, 1 abgelehnter manipulierter Befehl, 1 Reconnect, 1 abgeschlossenes Simulationsmatch, 0 unerwartete Fehler; Werkzeugdauer 1,433 s |
| Strikter Transportparser auf diesem tatsächlichen Log | Bestanden; einschließlich realer nachfolgender npm-Updateinformation |
| Acht Python-Vertragsgruppen | Bestanden; gültige und ungültige Ergebnisse, unvollständige Matches, simuliertes Ergebnis im Produktionspfad, falsche Replayanzahl, frühes Aufgeben, abgeschnittenes JSON, doppelte Ergebnisse, Fehler nach Ergebnis, feste Wrapperbefehle und unveränderte Fristen |
| Produktionsparser auf zwei bereits abgeschlossenen tatsächlichen CI-Duellen | Beide bestanden; 87 bzw. 115 Aktionen, regulärer Sieger und Endzustandhash. Herkunft: erfolgreicher Main-PR-Job `130758059372`, Run `43088210427`, Quellstand `5654b48`/Mergecheckout `ce60f54`; keine neu erfundenen oder erneut gespielten Partien |
| Shellsyntax und Whitespace | `bash -n tools/test_alpha03.sh` und `git diff --check` bestanden |

Die künstlichen JSON-Daten in den Python-Vertragstests sind ausdrücklich
Parser-Unitdaten und werden nicht als gespielte Partien gezählt. Der alte
190-Sekunden-Diagnoseabbruch wird ebenfalls nicht als bestanden gezählt.

Die vollständige Integrations-CI muss auf dem neuen Commit erneut bestehen.
Diese fokussierte Korrektur ist weder ein vollständiger neuer CI-Pass noch ein
Nachweis für einen öffentlich betriebenen Multiplayer-Server, physische
iPhone-/Android-Geräte oder eine Veröffentlichung.

## Reproduzieren

```sh
python3 tests/alpha03_runner_contract_test.py
bash -n tools/test_alpha03.sh
# Vollständige verpflichtende Integration, einschließlich beider Onlinepfade:
bash tools/test_alpha03.sh

# Nach einem vollständigen Wrapperlauf die beiden Nachweise erneut prüfen:
python3 tools/alpha03/check_online_demo.py transport work/alpha03/online-demo-fixture.log
python3 tools/alpha03/check_online_demo.py production work/alpha03/online-production-duel.log
```

Die reguläre CI installiert die gepinnten Abhängigkeiten. Lokal wurde nur ein
temporärer Dependency-Symlink auf eine bereits installierte identische
`package-lock.json` mit SHA256
`9bd974a81cf8f6ea6bf8ab00e368fc4fe55b5ad7b155dac1a7443a2160409190`
verwendet und nach der Prüfung entfernt. Es wurden keine Zugangsdaten, Server,
Produktionsdaten oder Sicherheitseinstellungen geändert.
