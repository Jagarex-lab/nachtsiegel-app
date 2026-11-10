# Protokoll v1 – lokaler Simulationsprototyp

Transport: JSON über HTTP und WebSocket; produktiv später HTTPS/WSS mit derselben
Origin für Webexport und API. Native Clients halten Bearertokens nur im Speicher.
Browser erhalten HttpOnly-/SameSite=Strict-Cookies, bei HTTPS zusätzlich Secure.
Keine Passwörter, Tickets, Tokens, vollständigen Matchzustände oder URLs mit
Sockettickets loggen. Kein Client meldet verbindliche Ressourcen oder Ergebnisse.

## Authentifizierte HTTP-Schnittstellen

Alle POSTs verlangen `Content-Type: application/json`, maximal 8192 Bytes und
strikte Schemas ohne zusätzliche Felder. Browser-Origin muss exakt stimmen.
Cookie-authentifizierte POSTs verlangen zusätzlich `X-CSRF-Token` und Origin.
CORS ist nicht freigegeben; Cross-origin-Webexports sind nicht integriert.

| Methode / Pfad | Eingabe / Verhalten |
|---|---|
| POST `/auth/register` | `{username,password,display_name}`; gültige Registrierung und bereits belegter Name liefern gleich `202 {accepted:true}` |
| POST `/auth/login` | `{username,password,client?:"native"}`; unbekannt/falsches Passwort identisch 401 |
| GET `/auth/session` | Cookie-/Bearer-Bootstrap: `{csrf_token,profile,expires_at}`, niemals Bearer in Cookieantwort |
| POST `/auth/rotate` | `{}` für Cookie, optional `client:"native"` für Bearer; altes Token wird widerrufen |
| POST `/auth/logout` | `{}`; serverseitiger Widerruf und Cookie entfernen |
| POST `/auth/recovery` | `{username}`; immer generische Bestätigung; noch kein automatischer Identitäts-/Versandprozess |
| POST `/auth/reset` | `{token,password}`; einmaliges, ablaufendes Operator-Recoverytoken erforderlich |
| GET `/profile` | Öffentliche Felder des eigenen Profils per Allowlist |
| GET `/account/export` | Eigene Account-/Profil-/Social-/Deck-/Collectiondaten und maximal 100 Historyeinträge; vollständiger Rechtsexport noch offen |
| POST `/account/delete` | `{password}`; erneute Passwortprüfung, Pseudonymisierung, Sessions ungültig, aktives Fixturematch abbrechen |
| POST `/transport/ticket` | `{}`; `{ticket,expires_in:30}`; einmalig, sitzungsgebunden |
| GET `/matches/history` | `{matches:[...]}`, nur eigene Matches, maximal 100 |
| GET `/matches/{id}/replay` | Nur Teilnehmer nach Abschluss/Abbruch; enthält dann serverseitigen Seed, Versionen, Aktionen und Ereignisse |
| GET `/health` | Prozess-/DB-Smoke, keine Nutzerdaten |

Login und Rotation liefern `{csrf_token,profile,expires_at}`. Nur native
Beareranmeldung/-rotation enthält zusätzlich `token`. `expires_at` und andere
Serverzeitstempel sind Unix-Millisekunden. Cookieauth kann nicht durch Rotation
in eine Bearerantwort umgewandelt werden. Recoverytoken-Ausstellung ist nur als
vertrauenswürdige Servicefunktion nach externer Identitätsprüfung vorhanden,
niemals als öffentlicher Endpoint.

## WebSocket

Ticket per HTTP anfordern und innerhalb von 30 Sekunden unter
`/ws?ticket=<einmaliges-ticket>` einlösen. Das Ticket wird beim Upgradeversuch
verbraucht. Keine langlebigen Tokens in URL oder WebSocket-Headern. Proxyzugriffslogs
müssen den Querystring unterdrücken. Native Clients dürfen Origin weglassen;
vorhandene Browser-Origin wird geprüft. Sitzungen werden bei jedem Frame und
zusätzlich sekündlich geprüft. Ping/Pong alle 15 Sekunden erkennt
stumme Verbindungen nach ungefähr 30 Sekunden; danach beginnt die Reconnectfrist. Rotation/Logout machen bestehende Autorität ungültig.

Jede Clientnachricht hat diese Pflichtfelder:

```json
{"protocol_version":1,"type":"session.resume","request_id":"req_unique_1"}
```

IDs: 1–80 Zeichen, `[A-Za-z0-9_-]`. Texte sind UTF-8. Binärframes, unbekannte
Versionen/Typen/Felder und verschachtelte Zusatzwerte werden abgelehnt.
Maximal 8192 Bytes pro Nachricht; WebSocketüberschreitung schließt mit 1009.
120 Frames pro Nutzer/Minute, höchstens zwei Sockets/Nutzer und 200 insgesamt.
Bei mehr als 64 KiB ausstehender Ausgabe wird ein langsamer Client geschlossen.

| `type` | Weitere Felder | Wirkung |
|---|---|---|
| `session.resume` | keine | Aktuelles Match oder leerer Sitzungsstatus |
| `matchmaking.join` | `mode:"casual",region:"local"|"eu"|"na"|"asia"` | Serverseitige Suche; kein Clientrating |
| `matchmaking.leave` | keine | Suche verlassen |
| `private.create` | keine | Zeitlich begrenzten Einladungscode erzeugen |
| `private.join` | `invite_code` | Einmalige Einladung annehmen |
| `match.ready` | `match_id` | Startbereitschaft; beide Spieler müssen bestätigen |
| `match.action` | `match_id,sequence,action:{type:"advance"|"concede"}` | Ausschließlich Simulationsaktion; keine ORAFOLD-Kartenregeln |
| `match.reconnect` | `match_id,after_sequence` | Eigener Snapshot und verpasste öffentliche Ereignisse |
| `social.list` | keine | Eigener privater Freundschaftsgraph |
| `social.request/accept/remove/block` | `target_user_id` | Anfrage/Zustimmung/Entfernen/Blockierung |

Die JSON-Schema-Quelle ist `server/src/transport/protocol.ts`; der erzeugte Vertrag
liegt in `shared/schemas/client-message-v1.schema.json`. Regeneration mit
`npm run schema`; der Protokolltest prüft Drift. Fixtures liegen in `shared/fixtures`.

## Zwei Sequenzen und Idempotenz

`match.action.sequence` ist die nächste **pro Spieler und Match** erlaubte
Aktionsnummer, beginnend mit 1. Der Server liefert `next_action_sequence`.
`match.state.sequence` ist der **globale öffentliche Ereigniscursor** des Matches.
`match.reconnect.after_sequence` bezieht sich auf diesen globalen Cursor. Beide
Zähler dürfen nicht verwechselt werden; abgelehnte Aktionen verbrauchen keine Nummer.

Akzeptierte Match-/Suchrequests werden zusammen mit Zustand/Ereignissen und
Payloadhash atomar gespeichert. Dieselbe Nutzer-/Request-ID mit identischem
Inhalt liefert die ursprüngliche Antwort; anderer Inhalt ergibt
`REQUEST_ID_CONFLICT`. Antworten können inzwischen veraltet sein: den aktuellen
Snapshot verarbeiten. Receipts werden nach 24 Stunden bereinigt; Aktionssequenzen,
Matchphase und Einladungsverbrauch verhindern erneut ausgeführte Matchaktionen.
Social-Operationen sind über ihre Zustandsbedingungen wiederholbar, besitzen
keinen dauerhaften Requestcache. Das ist keine Exactly-once-Zusage für zukünftige
Wirtschaftstransaktionen; diese benötigen eigene persistente Transaktionsschlüssel.

## Serverantworten und Fehler

`match.found` benennt die Match-ID. Pushs und Ready-/Action-/Reconnectantworten
liefern `match.state` mit `match_id,status,rule_version,catalog_version,sequence,
next_action_sequence,deadline,state,events`. Abschluss ist `status:"finished"`
oder `"cancelled"` plus `state.result`; es wird kein separater Finishpush benötigt.
`state` enthält ausschließlich die Spieleransicht, nie Gegnerhand, Deckreihenfolge
oder laufenden Seed. Zuschaueransicht ist nur als Adapterfunktion vorbereitet.

```json
{"protocol_version":1,"type":"error","request_id":"req_unique_1","code":"INVALID_SEQUENCE"}
```

Bei nicht parsebarem JSON oder ungültiger Request-ID fehlt die Korrelation.
Wichtige Codes: `INVALID_MESSAGE`, `INVALID_JSON`, `MESSAGE_TOO_LARGE`,
`UNAUTHENTICATED`, `INVALID_CREDENTIALS`, `CSRF_REJECTED`, `ORIGIN_REJECTED`,
`HOST_REJECTED`, `RATE_LIMITED`, `AUTH_BUSY`, `MATCH_NOT_FOUND`,
`INVALID_SEQUENCE`, `REQUEST_ID_CONFLICT`, `NOT_YOUR_TURN`,
`INVALID_MATCH_PHASE`, `REPLAY_NOT_AVAILABLE`, `INTERNAL_ERROR`.
HTTP verwendet passende 4xx/5xx-Statuscodes; keine Stacktraces oder DBdetails.
Eine ungültige Session schließt den Socket mit 1008.

## Integration

Der heutige Vertrag akzeptiert absichtlich kein `play_card`. Der spätere
Godot-Regeladapter muss für echte Intents ein neues geprüftes Schema/eine
explizite Version liefern. Der Integrationsvertrag in [INTEGRATION.md](INTEGRATION.md)
regelt Determinismus, Fehleratomarität, private Ansichten und Regelartefakte.
