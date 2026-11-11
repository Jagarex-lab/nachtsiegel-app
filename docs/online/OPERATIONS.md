# Betriebsvorbereitung

Status: lokale Betriebswerkzeuge und Anforderungen; kein eingerichteter
Produktionsbetrieb. Verantwortlicher lokaler Prozess besitzt die SQLite-Datei.
Vor mehreren Prozessen müssen DB, Routing, Limits und Matchleases umgestellt sein.

## Zu beobachtende Signale

| Signal | Zweck / Reaktion |
|---|---|
| Aktive Sessions/Verbindungen/Matches | Kapazität und unerwartete Leaks erkennen; Sessions und Socketanzahl getrennt zählen |
| Queueanzahl und Wartezeit | Region-/Modusengpässe; keine Nutzerliste ins Monitoring schreiben |
| HTTP-/WS-Latenz p50/p95/p99 | Authhash-, DB- und Eventloopengpässe trennen |
| Verbindungsabbrüche/Reconnects | Mobile Wechsel, Proxy-Idlelimits und Reconnectstürme erkennen |
| Fehlerrate/DB-Fehler | Fehlgeschlagene Commits, Lockwartezeit und Migrationen beobachten |
| CPU/RSS/Eventloop-Lag | CPUlast von Hashing/Regeln vs. I/O; OOM vorzeitig erkennen |
| Ungültige Aktionen/Sequenzen/Fremdzugriffe/Limits | Aggregierte Missbrauchssignale; menschliche Analyse vor Sanktion |
| DB-/WAL-/Backupgröße und Backupalter | Speichererschöpfung und unbrauchbare Sicherungen vermeiden |

Der lokale CLIprozess schreibt minütlich JSON-Metriken zu HTTP-/Socketanfragen,
Ablehnungen, Serverfehlern, Verbindungen, Reconnects sowie CPU/RSS. Das ist kein
vollständig installiertes Prometheus-/Grafana-/Alarmierungssystem. Aktive
Sessions/Matches, Queueanzahl und älteste Wartezeit werden als Momentaufnahme
mitgeliefert; Betriebssystemmetriken, Latenzhistogramme und längere Zeitreihen
müssen später ergänzt werden. Keine per-Spieler-Metriklabels
mit unbeschränkter Kardinalität. Keine Tokens oder vollständigen Nutzlasten loggen.

## Lokale Sicherung und Wiederherstellung

SQLite läuft im WAL-Modus. Eine aktive `.sqlite`-Datei ohne WAL-/Checkpointwissen
einfach zu kopieren kann Daten verlieren. Für die einfache lokale Sicherung:

1. API sauber stoppen und sicherstellen, dass kein anderer Prozess schreibt.
2. Vollständiges Datenverzeichnis einschließlich zugehöriger WAL-/SHM-Dateien
   konsistent kopieren; Kopie außerhalb des Arbeitsbaums und vor fremdem Zugriff schützen.
3. Sicherung in ein **neues** Verzeichnis wiederherstellen; Original nicht überschreiben.
4. `PRAGMA integrity_check` und `PRAGMA foreign_key_check` in der Kopie ausführen.
5. API mit Kopie starten, Migrationen/Health prüfen und Testaccount anmelden.
6. Bestehendes Match/history kontrollieren; alte Socketpräsenzen werden beim Start
   ungültig, Reconnect muss authentifiziert neu erfolgen.

Für spätere Sicherung ohne Downtime SQLite-Backup-API bzw. geeignete konsistente
Backupwerkzeuge verwenden und unter Last testen. PostgreSQL erfordert ein eigenes
verschlüsseltes Backup-/PITR-/Restorekonzept mit minimalen Backuprollen. Ein
Backup auf demselben Host allein schützt nicht vor Hostverlust.

Die Anleitung ist keine Behauptung bereits bewiesener RPO/RTO. Vor Produktion
RPO/RTO vereinbaren, regelmäßige Restoreübungen durchführen, Ergebnisse und
Verschlüsselungs-/Schlüsselzugriff dokumentieren. Löschmarker nach Restore erneut
anwenden, damit gelöschte Accounts nicht unbeabsichtigt zurückkehren.

## Vorfälle und sicherer Neustart

Bei kompromittierter Session widerrufen, aktive Socketberechtigungen schließen
und ggf. Passwortreset auslösen. Bei Regelabweichung Match anhalten, keine
Client-Siegesbehauptung als Ersatz akzeptieren und auf versioniertem Artefakt
reproduzieren. Bei Datenbankfehler keine erfolgreiche Aktion bestätigen.

Ein Neustart darf aus DBzuständen weiterarbeiten, aber keine alte Netzwerkpräsenz
annehmen. Zeitlimits bleiben serverseitig. Wiederholte Requests verwenden dieselbe
Request-ID; neue Absichten erhalten neue IDs. Eine erneute Serverantwort darf
keine zweite Wirkung erzeugen. Alte Regelartefakte für historische Replays und
laufende Matches aufbewahren.

## Wartung und Aufbewahrung

Migration vorab mit einer Kopie testen, Backup erstellen, passende Binär-/Schema-
Version dokumentieren; bei inkompatibler Änderung Worker drainen. Ein Downgrade
darf kein unbekanntes Schema öffnen. Session-/Recovery-/Request-/Matchlogcleanup
gegen die vereinbarte Aufbewahrung testen. Produktive Auditlogs separat vor
unberechtigter Änderung schützen; lokale SQLite-Logs sind kein manipulationssicheres SIEM.

Dependencies regelmäßig gegen Lockdatei und bekannte Advisories prüfen.
Registrierte Secrets niemals in Fehlermeldungen oder Supportbundles aufnehmen.
Sicherheitsnachweise/Lastresultate gelten nur für den jeweils geprüften Commit.
