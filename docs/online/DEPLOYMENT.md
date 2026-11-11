# Lokale Entwicklung und späteres Deployment

Dieses Paket startet einen **lokalen Infrastrukturprototyp mit simulierten
Matches**. Kein öffentlicher Server, keine echten Kartenmatches, keine Zahlungen.
Ein separater Feature-PR wird nicht eigenständig gemergt oder veröffentlicht.

## Direkter Start

Voraussetzung: Node 24 (unterstützter Bereich siehe `server/package.json`), npm.
SQLite ist über `node:sqlite` enthalten; Argon2 benutzt ein natives Modul.

```sh
cd server
npm ci
npm run typecheck
npm test
npm start
```

`npm ci` verwendet die eingecheckte Lockdatei. Kompilation nativer Abhängigkeiten
kann auf Plattformen ohne passendes Prebuild eine lokale Toolchain benötigen.
Der Prozess führt Migrationen aus und muss Schreibrechte auf seinem lokalen
Datenverzeichnis besitzen. Tests verwenden eigene temporäre/in-memory-Datenbanken.
Start/Demo/Lastwerkzeuge verwenden `node --import tsx`; die Tests laufen über
`node --import tsx --test --test-isolation=none`. Dadurch ist kein separater
IPC-Listener des `tsx`-CLI für den normalen Serverstart nötig. Tests teilen sich
einen Prozess, isolieren ihre Datenbanken jedoch selbst.

Selbstständige Demo und Laststufen (starten jeweils einen eigenen flüchtigen
Loopbackserver; kein zusätzlicher `npm start` nötig):

```sh
cd server
npm run demo
npm run load -- 2 10 30
```

Die Demo erzeugt lokale Testaccounts, meldet zwei Clients an und führt
Matching/Ready/Simulation/Reconnect/Abschluss/History aus. Testzugangsdaten sind
keine Produktionskonten. Details und tatsächliche Lastparameter: [QA.md](QA.md).

## Konfiguration und Health

Beispielkonfiguration liegt unter `data/online/`; konkrete Umgebungsvariablen und
Defaults sind in `server/src/main.ts` maßgeblich:

| Variable | Lokal | Bedeutung |
|---|---|---|
| `HOST` | `127.0.0.1` | Listener; außer Loopback wird nur `0.0.0.0` mit `LOCAL_CONTAINER=1` zugelassen |
| `PORT` | `8787` | Lokaler HTTP-/WebSocketport |
| `DB_PATH` | `var/orafold.sqlite` | Persistente lokale DB relativ zum Startverzeichnis |
| `ORIGIN` | Eigene Server-URL nach Start | Exakt erlaubte Browser-Origin |
| `LOCAL_CONTAINER` | Nicht gesetzt | Nur für internen Containerlistener; Hostport weiterhin Loopback |
| `NODE_ENV` | Entwicklung | `production` wird bewusst verweigert |

Die erlaubte Origin muss exakt zum Browserclient
passen, inklusive Protokoll und Port. Kein `*` bei Cookies.

`GET /health` liefert eine minimale Prototypstatusantwort ohne Nutzer-, Session-
oder Matchdaten und prüft DB-Erreichbarkeit mit `SELECT 1`. Der CLIprozess schreibt jede Minute aggregierte Zähler und
CPU-/RAMwerte als JSON. Dies ist kein öffentlicher Metricsdienst und kein
vollständiges Monitoring.

`NODE_ENV=production` wird absichtlich abgelehnt. Ein Guard allein hält einen
falsch konfigurierten Entwicklungsserver nicht geheim: Netzwerkbindung und
Firewall müssen auch im lokalen Teamaufbau bewusst gesetzt werden. Keine
Produktionssecrets im Repository oder in Buildartefakten ablegen.

## Docker Compose

`server/Dockerfile` und `server/compose.yaml` starten API, persistentes
SQLite-Volume und Healthcheck. Aus dem Repositorywurzelverzeichnis:

```sh
docker compose -f server/compose.yaml config
docker compose -f server/compose.yaml up --build -d
curl --fail http://127.0.0.1:8787/health
docker compose -f server/compose.yaml logs online
docker compose -f server/compose.yaml down
```

Das Hostmapping ist ausdrücklich `127.0.0.1:8787:8787`; intern hört der
Non-root-Container mit `LOCAL_CONTAINER=1` auf `0.0.0.0`. Compose setzt ein
schreibgeschütztes Rootfilesystem, ein begrenztes `/tmp`, verwirft Linux-
Capabilities und deaktiviert Privilegienerweiterung. Das lokale Ressourcenbudget
ist eine CPU/512 MiB/64 Prozesse; diese Grenzen sind keine gemessene Kapazität.
Buildbasis ist `node:24.13.0-bookworm-slim`; gepinnte Digests/SBOM gehören vor
Distribution zur Lieferkettenprüfung. Ob Konfigurationsprüfung, Imagebau und
Laufzeittest in der Arbeitsumgebung tatsächlich möglich waren, steht getrennt
in [QA.md](QA.md).

Ein SQLite-Dateivolume darf niemals von mehreren APIreplicas gleichzeitig als
Cluster-Schreibgrenze genutzt werden. Lokale Daten nicht durch unkontrolliertes
`down -v` löschen. Für reproduzierbare Stresstests eigene Wegwerfdatenbanken
verwenden, keine bestehende Entwicklungs-DB überschreiben.

## Browser und Mobile

Bevorzugtes späteres Layout: Godot-Webexport und `/api`/`/ws` unter derselben
HTTPS-Origin über einen Reverse Proxy. Falls der Webclient auf Pages bleibt,
müssen Cross-origin-Cookie-/CORS-/CSRF-/WebSocketregeln separat geprüft werden;
ein third-party-Cookie kann insbesondere Safari blockieren.

Godot WebSocketPeer unterstützt den Zieltransport; Browser erlauben keine frei
gesetzten WebSocket-Authorizationheader, deshalb einmalige Sockettickets. Native
Clients melden sich über HTTPS an und halten Bearertokens geschützt. Bei App-
Hintergrund, Mobilfunkwechsel oder Safari-Tabpause Verbindung erneuern und
Serverzustand abgleichen. Ein reconnectender Client darf keine lokale Simulation
als verbindlichen Zustand hochladen.

Chromium/WebKit-/Android-/iOS-Kompatibilität des Protokolls bedeutet noch keine
getestete konkrete Gerätefreigabe. Tatsächlich ausgeführte Browser-/Godottests
werden getrennt in QA dokumentiert.

## Produktionsanforderungen

1. Echte Headless-Regelintegration und Ownershipvertrag abschließen.
2. PostgreSQL-Treiber, versionierte Migrationen und Upgrade-/Rollbacktests ergänzen.
3. HTTPS/WSS, HSTS, Secure-Cookies, Proxy-Origin/Forwarded-Headerregeln prüfen.
4. Secretbereitstellung, minimale DB-/Operatorrollen, aktualisierte Dependency-/Containerprüfung.
5. Begrenzte Verbindungen, Authhash-Concurrency, Backpressure, Timeouts und verteilte Limits.
6. Externe Recoveryidentität und Datenschutzhinweise/Export/Löschprozess fertigstellen.
7. Backups/Restore, Monitoring/Alarmierung und Incidentbetrieb nachweisen.
8. Lastmessung mit realer Engine statt Fixture; Kapazität/Reservierung festlegen.
9. Reviewbarer separater Rolloutplan mit ausdrücklicher Freigabe.

Weder vorhandene Pages-Releaseworkflows noch ihre geschützten Environments werden
für diesen Prototyp geändert. Keine öffentliche Infrastruktur wird angelegt.
