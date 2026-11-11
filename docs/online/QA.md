# QA und Abnahmestand – 10.11.2026

**Funktionierender lokaler Multiplayer-Infrastrukturprototyp, kein vollständig
spielbarer ORAFOLD-Online-Multiplayer.** Ausschließlich Transportfixtures; kein
Kartenkampf, keine Echtgeldfunktion und keine öffentliche Bereitstellung.

## Statuskategorien

| Status | Nachweis / Grenze |
|---|---|
| Implementiert | Accounts/Argon2id, SQLite, Sessions, HTTP/WS, striktes Protokoll, Casualqueue, private Codes, Freundschaft/Blockierung, Ready, Reconnect, Matchhistorie/Replay, Regel-/Economyports, Elo-Sandbox, optionale Godotadapter, Compose/CI und Dokumentation |
| Lokal getestet | 31 echte Node-Testgruppen bestanden; TypeScriptprüfung bestanden; 22 Godotadapter-Assertions plus29 native Live-Assertions und echter Chromium-Transportsmoke; bestehende Offline-Regeln 1704 / Offline-Replay173 Assertions ohne Fehler; Laststufen2/10/30; Dockerimage und Compose gesund |
| Sicherheitstechnisch geprüft | Gezielte automatisierte Manipulationstests und Quellprüfung; npm audit meldet0 bekannte Abhängigkeitsschwachstellen nach Aktualisierung |
| Produktionsbereit | Nein; Prozess lehnt NODE_ENV=production ab; kein unabhängiges Pentest-/Rechts-/Betriebsfreigabeverfahren abgeschlossen |
| Noch nicht integriert | Echte Godot-Headless-Regeln, Kartenkatalog/Ownership, Economy/Rewards/Handel, produktives Ranking, zentrale UI, plattformübergreifende Endabnahme |
| Blockiert / abhängig | Regelvertrag bis stabiler paralleler Effekt-Engine; Recovery bis verifizierter Identität/Versand; öffentlicher Betrieb bis Betriebskonzept und ausdrücklicher Freigabe |

## Reproduzieren

```sh
cd server
npm ci
npm run typecheck
npm test
npm run demo
npm run load -- 2 10 30
npm audit --audit-level=moderate
```

Node24.22.1 / Godot4.6.3 unter Linux in einer gemeinsam genutzten Cloudumgebung;
Dockerimage Node24.13.0. Gemeldeter Host:5 CPU /17,59GiB RAM; das ist keine
reservierte Benchmarkmaschine. Tests benötigen lokale Netzwerklistener. In dieser
Agentensandbox wurde Listen zunächst mit EPERM verweigert; derselbe vollständige
Testlauf außerhalb dieser Listenerbeschränkung bestand31/31,0 übersprungen.
`--test-isolation=none` ist beabsichtigt: der hier beobachtete separate Node-Runner
zählte sonst nur Datei-Wrapper. Maßgeblich sind die tatsächlich ausgeführten
31 Testgruppen, nicht die Zahl der Dateieinträge.

## Testumfang

- Auth: Argon2id, Profil-Allowlist, SQLparameter, generische Login-/Recoveryfehler,
  Sessionablauf/Rotation/Widerruf/Limits, SQLite-Neuöffnung, Recoveryeinmaligkeit,
  Passwortwechsel während asynchroner Prüfung und passwortgeschützte Löschung.
- Matches: eindeutige Zuweisung, beidseitiges Ready, atomare Deduplizierung,
  Payloadkonflikte, pro-Spieler-Sequenz, Zugberechtigung, fremde Match-ID,
  private Ansichten/Seed-/Deckschutz, reconnect ohne Zusatzaktion, Prozessneustart,
  History, reproduzierbarer Fixtureabschluss, Ready-/Zug-/Reconnect-/Queuefristen,
  ablaufende Einladungen, Blockierung und Accountabbruch.
- Transport: echte HTTP-/WS-Clients, Cookie HttpOnly/SameSite, CSRF/Origin,
  einmaliges Ticket, widerrufene und abgelaufene Sockets, ungültiges JSON,
  übergroße Frames1009, falsche Version/Typen, gefälschte Schadens-/Ressourcenwerte,
  Host-/DNS-Rebindingablehnung und nicht vertrauenswürdige Forwardingheader.
- Social/Elo/Economy: Zustimmung, eigene Graphsicht, beidseitige Blocks, Mengen-
  und Eingabegrenzen; deterministische Elo-Sandbox/Ergebnisdeduplizierung/Saisons;
  fehlende Ownership-/Deck-/Transaktionsadapter verweigern Zugriff.
- Vertrag: veröffentlichte JSON-Schemadatei entspricht dem Runtimevalidator;
  Fixture und Zusatzfelder für Schaden, Heilung, Energie, Resonanz, Seed,
  Sieger und echte Kartenintents werden korrekt geprüft/abgelehnt.

Das ersetzt keinen unabhängigen Penetrationstest, Flood-/DDoS-Test oder vollständige
OWASP-/Mobile-Sicherheitsabnahme. DBberechtigungen werden lokal über Prozess und
Dateirechte begrenzt; PostgreSQL-Rollen/-Netzwerkzugriffe sind noch nicht implementiert.

## Lasttest – gemessener Kurzlauf

Rohdaten: [load-2026-11-10.jsonl](evidence/load-2026-11-10.jsonl).
Alle Level starteten eine eigene flüchtige SQLite-DB und Loopbackserver im selben
Messprozess wie Clients. Je zwei gleichzeitige Registrierungen/Logins begrenzen
Argon2last; danach gleichzeitige Suche und parallele Matches. Pro Match: Ready,
Snapshot, eine simulierte Aktion, identische Wiederholung, gefälschte Aktion,
Sockettrennung/Neuanmeldung per Ticket, Reconnect, Aufgabe und Historyprüfung.

| Clients / Matches | Erfolgreiche WSrequests | WS p50 / p95 / max ms | Gesamtdauer ms | WSreq/s inkl.Authsetup | Peak RSS MiB | CPU user / system ms | Unerwartete Fehler |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 /1 | 12 | 3,21 /7,28 /7,28 | 814 | 14,74 | 230,46 | 1140 /307 | 0 |
| 10 /5 | 60 | 9,81 /12,29 /12,43 | 2004 | 29,94 | 235,92 | 3149 /612 | 0 |
| 30 /15 | 180 | 30,46 /66,07 /66,43 | 6310 | 28,53 | 247,67 | 10480 /1640 | 0 |

Auth-/Verbindungssetup p95:760,79 /399,75 /407,38ms. Peak-RSS alle25ms
abgetastet; CPU misst den Gesamtprozess, nicht nur Serverarbeit. Alle21 Matches
abgeschlossen und21 Reconnects erfolgreich.21 erwartete gefälschte Aktionen
abgelehnt; keine unerwarteten Fehler. Duplikate erzeugten keine weitere Wirkung.
Die Zahlen sind Kurzlaufbeobachtungen, kein Sättigungs-/Soaktest. Netzwerkzeit ist
Loopback; DB ist in-memory und enthält nur Fixtures. Echte Godotlast, persistente
DB-I/O, TLS, reale Mobilnetze und Produktion können stark abweichen.

Bekannte lokale Grenzen: max200 Sockets,2/Nutzer,2 parallele Passwortjobs,
100 Authrequests/IP/10min,120 WSframes/Nutzer/min. Höhere Laststufen können
bewusst429 erzeugen. Über30 Clients wurde keine belastbare Kapazitätsgrenze
bestimmt; keine Zusage für10.000 oder100.000 DAU. [HOSTING.md](HOSTING.md) enthält
separate, ausdrücklich hypothetische Kosten-/Kapazitätsannahmen.

## Godot und Offlineerhalt

```sh
# im Repositoryroot; zuerst Ressourcen importieren
# XDG-Verzeichnisse müssen in eingeschränkten Umgebungen beschreibbar sein
godot --headless --editor --import --path . --quit
godot --headless --path . --script tests/online_client.gd
mkdir -p work/alpha
godot --headless --path . --script tests/alpha_rules.gd
godot --headless --path . --script tests/alpha_replay.gd
```

Onlineparser/-session/-client kompilieren,22 Assertions bestehen. Der native
Godot-Live-Smoke gegen Compose besteht29 Assertions mit zwei echten
Adapterinstanzen (Register/Login/Ticket/WS/Matching/Ready/Logout). Ein erster
Lauf fand die Umwandlung von null-Match-IDs in Text im optionalen Client;
Typprüfung und Regressionstests beheben dies, Wiederholung grün. Offline:
1704 Regelassertions mit64 vollständigen KI-Simulationen und173 Replayassertions
mit vier vollständigen Partien bestehen. Ein erster direkter Offline-Regellauf
scheiterte an dem vom vorhandenen Wrapper erwarteten fehlenden Ausgabeordner
`work/alpha`; mit dessen regulärer Verzeichnisvorbereitung bestand er unverändert.
Keine Spielquelldatei, Karte, Szene, Projekt-/Autoload- oder Offlinekonfiguration
wurde geändert. Das bewahrt den vorhandenen Spielpfad; eine erneute vollständige
visuelle Desktop-/Export-/Geräteabnahme wurde hier nicht durchgeführt.


## Browsertransport und nativer Client

Optional, bei laufendem lokalem Compose-Server:

```sh
godot --headless --path . --script tests/online_native.gd
# Playwright samt Browsern muss als separates QA-Werkzeug vorhanden sein.
# Optional PLAYWRIGHT_MODULE=/absoluter/modulpfad und CHROMIUM_EXECUTABLE setzen.
node server/tools/browser-smoke.mjs
```

Chromium156 besteht reale Cookieanmeldung, HttpOnly/SameSite-Prüfung, fehlenden
scriptlesbaren Bearer, CSRF403, Cookiebootstrap, Ticket-WebSocket und Logout.
Die Test-HTML wird unter derselben Origin durch Playwright bereitgestellt.
Chromiums reguläre Local-Network-Berechtigung wird nur für diese lokale
Test-Origin erteilt; ohne diese blockierte Chromium den WebSocket mit
ERR_BLOCKED_BY_LOCAL_NETWORK_ACCESS_CHECKS. Kein Serverauthschutz wurde
ausgeschaltet. WebKit-Start wurde versucht: ausführbare Laufzeit
`webkit-2336/pw_run.sh` fehlt. Kein bestandener WebKit-/Safari-Test behauptet.
Diese Prüfung ist kein Godot-Webexport und keine physische Geräteprüfung.

## Container und CI

Dockerimage erfolgreich gebaut; Compose startet non-root mit persistentem
SQLite-Volume, read-only Root-FS und ausschließlich127.0.0.1:8787. Health liefert
200 und prüft auch DBzugriff. Erster Start deckte unlesbare COPY-Dateirechte für
den node-Nutzer auf; durch explizites COPY--chown behoben und erneut grün geprüft.
Die verwaltete Dockerumgebung meldet fehlende cgroup-Unterstützung für effektive
Ressourcenbegrenzung; Composegrenzen sind dort keine garantierten Limits.

Die eigene `.github/workflows/online-qa.yml` prüft TypeScript, echte Tests, Demo,
Dependency-Audit und Godotadapter ohne Deploymentpfad. Ergebnisse externer
GitHubjobs erst nach ihrem tatsächlichen Abschluss als grün bewerten. Bestehende
Release-/Pages-Workflows bleiben unverändert. Kein Merge und keine Veröffentlichung.

## Verbleibende Abnahme

Echte Engine/Ownership integrieren, langfristige Replayversionen/Retention,
PostgreSQL/Mehrprozessleases, Recoveryidentität, Datenschutzprozesse,
Backup-/Restoreübung, TLS-/Proxyhärtung, unabhängiger Pentest, Dauer-/Missbrauchslast,
WebKit sowie Chromium mit tatsächlichem Godot-Webexport sowie physische Android-/iOS-Geräte prüfen.
Ein vollständiges spielbares Online-Duell ist noch nicht abgenommen.
