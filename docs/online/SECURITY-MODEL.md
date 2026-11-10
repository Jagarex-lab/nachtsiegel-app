# Sicherheitsmodell

Stand: lokaler Prototyp, keine externe Penetrationsprüfung, keine
Produktionsfreigabe. Die tatsächlich ausgeführten automatisierten Prüfungen
stehen in [QA.md](QA.md). Ein bestandener Test ist kein Nachweis gegen alle
Web-/Multiplayerangriffe.

## Schutzziele und Angreifer

Ein Angreifer kontrolliert seinen Client, Netzwerkneustarts, Requestreihenfolge
und sämtliche übermittelten Nutzlasten. Er kann bekannte Spieler-/Match-IDs
erraten oder kopieren, Nachrichten wiederholen, viele Verbindungen aufbauen und
vermeintliche Karten-/Ressourcen-/Seed-/Resultatwerte senden. Er hat keinen
berechtigten direkten Datenbank- oder internen Workerzugriff.

Geschützt werden Accountzugriff, verdeckte Matchinformationen, Zustandsintegrität
und spätere Eigentums-/Resultatautorität. Offline-Spielstände bleiben offline
veränderbar und dürfen keine wirtschaftliche Autorität erhalten.

| Angriff | Implementierte Grundlage | Grenze / Produktionsbedarf |
|---|---|---|
| Passwortdiebstahl aus DB | Argon2id, 64 MiB, drei Iterationen, Parallelität 1; kein Klartext | Backups/DB-Zugriff schützen, Hashkosten nach Hardwaremessung prüfen |
| Gestohlene Session | 32 kryptografisch zufällige Bytes, nur SHA-256-Digest persistiert, Ablauf/Widerruf/Rotation | TLS, sichere Endgeräte, sichere native Speicherung und Reauth für sensible Vorgänge |
| Brute-force/Hash-DoS | Begrenzter RateLimiter, HTTP-/WS-Limits im Transport | Prozesslokal; verteilte Limits, Proxygrenzen und Alarmierung erst vor öffentlichem Betrieb |
| Account-Enumeration | Gleicher Loginfehler für unbekannt/falsches Passwort, Dummyhash; Recovery antwortet generisch; Registrierung antwortet für neue und vorhandene gültige Handles HTTP 202 | Kein perfekter Timingschutz oder Schutz vor allen beobachtbaren Seiteneffekten behauptet |
| CSRF/WebSocket-Hijacking | HttpOnly-Cookiemodell, CSRF- und Originprüfung im Transport, kurzlebiges einmaliges Socketticket | Same-origin HTTPS-Hosting prüfen; kein wildcard-CORS mit Credentials |
| DNS-Rebinding | Hostheader wird mit Listeneradresse bzw. konfigurierter Origin verglichen, auch beim Socketupgrade | Künftigen Reverse Proxy nur mit ausdrücklich vertrauenswürdigem Host-/Forwarded-Vertrag anbinden |
| Fremde Match-ID | Teilnehmerprüfung aus authentifizierter Session bei Query/Aktion/Reconnect/Replay | Zuschauer benötigen eigenen späteren Rechtevertrag |
| Doppelte/umgeordnete Aktionen | Persistenter Requesthash/-beleg, eigene Aktionssequenz, Transaktion | Idempotenzaufbewahrung und längere Replayfenster vor Produktion festlegen |
| Manipulierte Werte | Strikte Runtime-Schemas, bekannte Nachrichtentypen, Maximalgröße; nur `advance`/`concede` in Simulation | Echte Karten-/Ziel-/Kostenprüfung erst durch bestehende Engineintegration |
| Verdeckte Informationen | Erlaubnisliste in `get_player_view`; öffentlicher Eventkanal separat | Vollständige Kernel-Snapshots/Events niemals direkt senden; echte Engine mit Leaktests prüfen |
| Gefälschte Resultate/Rewards | Client darf keine verbindlichen Resultate senden; Simulation vergibt keine Rewards | Separate Economyautorität, Resultatquelle und genau-einmalige Vergabe noch zu integrieren |
| SQL-Injection | Parameterbindung, Fremdschlüssel/Constraints, transaktionale Änderungen | SQL-/DB-Rollen für PostgreSQL und Backups noch einzurichten |
| Freundschafts-/Einladungsspam | Mengenlimits, Blockierung beider Richtungen, Einladungscodehash und Ablauf | Meldung/Moderation und produktive Limits fehlen |

## Sessions auf Web und nativen Clients

Web soll same-origin über sichere HttpOnly-Cookies mit `SameSite` arbeiten. Der
lokale HTTP-Loopbackmodus benötigt eine Entwicklungs-Cookiekonfiguration;
unverschlüsseltes HTTP gehört nicht ins öffentliche Netz. CSRF-Token ist an die
Session gebunden und wird für zustandsändernde Cookieanfragen geprüft. Origin
zusätzlich prüfen, auch für Login und WebSocketaufbau.

Native Clients können einen Bearer-Token verwenden. Die beiliegende Godot-Session
hält ihn ausschließlich im Arbeitsspeicher. Für späteres dauerhaftes Login sind
Android Keystore/iOS Keychain bzw. OS-Credentialstore nötig. Kein Token in
`user://`-JSON, localStorage, URL-Queryparametern oder Replaydateien speichern.
Nur das einmalige 30-Sekunden-Socketticket wird für den browserkompatiblen
WebSocketaufbau als Queryparameter verwendet; Reverse-Proxy-Accesslogs müssen
diesen Querystring vollständig auslassen.

Ein Socketticket autorisiert nur einen kurzlebigen Verbindungsaufbau und ist an
die Session gebunden. Bei jeder Nachricht und beim Widerruf muss der Transport
den aktuellen Sessionstatus beachten. Nach Rotation/Logout werden alte
Berechtigungen ungültig; ein vorhandener Socket darf das nicht umgehen.

Vorläufige Transportgrenzen: HTTP 600 Anfragen/IP/Minute, Auth 100/IP/zehn
Minuten und zehn/Loginhandle/zehn Minuten, Socketupgrade 100/IP/Minute,
120 Frames/Nutzer/Minute, höchstens 200 Sockets insgesamt und zwei pro Nutzer.
Maximal zwei gleichzeitige Argon2-Aufträge; weitere werden mit `AUTH_BUSY`
abgelehnt. Bodies/Frames höchstens 8 KiB, ausgehender Socketpuffer 64 KiB.
Maximal 1.024 ausstehende Tickets, 30 Ticketanforderungen/Nutzer/Minute und
30 Sekunden Ticketgültigkeit. Der Limiter hält höchstens 10.000 aktive Keys und
verweigert bei voller Kapazität weitere neue Keys. Das sind lokale Testgrenzen,
keine finalen Betriebs- oder Balancingwerte. Vom Client gesetzte
Forwarded-/X-Forwarded-For-Header werden nicht als IPautorität benutzt.

Default-Sessions laufen nach 30 Minuten ab, maximal acht pro Account. Rotation
widerruft den alten Token. Passwortreset widerruft alle Sessions und verbraucht
den Recoverytoken einmalig. Wiederherstellung benötigt weiterhin einen
verifizierten externen Identitätsnachweis: Die öffentliche Anfrage selbst
verschickt keine Mail. `issueRecoveryToken` ist nur für einen vertrauenswürdigen
Operator nach unabhängiger Identitätsprüfung vorgesehen und darf kein
öffentlicher Endpoint werden.

## Verdeckte Zustände und Replayzugang

Die Simulation hält serverseitig zwei getrennte private Fixturehände und
Deckreihenfolgen. Teilnehmer sehen nur eigene Hand und öffentliche Zähler.
Zuschaueransicht des Adapters enthält keine private Hand; es existiert kein
öffentlicher Zuschauerzugang. Seed und komplette interne Zustände fehlen in
laufenden Netzwerknachrichten. Teilnehmer können ausschließlich abgeschlossene
simulierte Replays erhalten; deren Seedfreigabe ist keine beschlossene Politik
für zukünftige echte Spielerdecks.

Die DB enthält absichtlich vollständige interne Zustände und Replayseeds. Ein
DB-Leak würde verdeckte Informationen verraten. Dateirechte, verschlüsselte
Host-/Backupspeicherung und getrennte Operatorrollen bleiben notwendig. Logische
Clientfilter schützen nicht vor kompromittiertem Server.

## Logs und Anomalien

Keine Passwörter, Bearertokens, Cookies, CSRF-/Recovery-/Sockettickets oder
kompletten Requestbodies protokollieren. Metriken und stabile Fehlercodes sollen
ungültige Schemas, Sequenzkonflikte, fremde Zugriffe, Limits und Verbindungsfehler
als aggregierte Ereignisse erfassen. Keine Clientfingerprints oder unnötige
personenbezogene Daten. Ein Anomaliesignal allein ist kein automatischer Bann.

## Produktionsblocker

Der Startschutz verweigert `NODE_ENV=production`. Dieser Guard ist eine
Entwicklungsgrenze, kein Ersatz für Netzwerkisolation. Standardmäßig nur
Loopback binden. Weder Featurebranch noch Dockerstart autorisieren öffentliche
Verfügbarkeit.

Vor Freischaltung erforderlich: echte Godot-Regelintegration samt Leaktests,
TLS-/Cookie-/Proxyprüfung, Recoveryidentität und externe Providerplanung,
persistente verteilbare Rate-Limits, DB-/Backuprrollen/Restoreübungen,
Aufbewahrung/Löschung, Monitoring/Incidentprozess, echte Workerlast und
unabhängiger Sicherheitsreview. Kein laufender ORAFOLD-Kampf darf vor diesen
Integrationen als sicher geprüft beworben werden.
