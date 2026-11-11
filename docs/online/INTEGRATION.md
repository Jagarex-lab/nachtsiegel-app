# Integrationsvertrag zur bestehenden Regelengine

Status: Schnittstelle vorbereitet, echte Engine **noch nicht integriert**.
Diese Arbeit ändert weder `scripts/alpha/model.gd` noch den Legacy-Kernel,
Effektadapter, Triggerbridge, Kartendaten oder bestehende UI-Szenen.

## Autoritative Laufzeit

Bevorzugt wird ein interner Godot-Headless-Worker, der die tatsächlich getesteten
Alpha-/Kernel-/Effektartefakte ausführt. Node bleibt verantwortlich für Accounts,
Verbindungen und Matchpersistenz. Godot erhält ausschließlich intern validierte
Start-/Aktionsaufträge, keine öffentlichen RPCs oder Dateipfade vom Client.

Eine TypeScript-Portierung der Regeln ist nicht autorisiert. Die jetzige
`SimulationAdapter`-Implementierung ist eine endliche Protokollfixture ohne
Karten-/Schadens-/Energie-/Resonanzauflösung und darf keine Wirtschaft anstoßen.

## Verbindlicher Adaptervertrag

Die ausführbaren Typen unter `server/src/matches/` sind die lokale Referenz;
für die echte Engine sind folgende Eigenschaften zusätzlich zwingend:

| Operation | Eingabe | Ausgabe / Invariante |
|---|---|---|
| `create` | Match-ID, zwei vom Server bestimmte Spieler, Regelprofil, Katalogversion, validierte Decksnapshots, serverseitiger Seed | Vollständiger interner Initialzustand; keine clientbestimmten Ressourcen/Zufallswerte |
| `validate_action` | Interner Zustand, authentifizierte Spieler-ID, reine Spielabsicht | Strukturierter stabiler Fehlercode oder zulässig; keine Mutation und kein RNG-Verbrauch |
| `apply_action` | Vollständiger Zustand, validierte Absicht, serverseitiger deterministischer RNG-Kontext | Neuer Zustand und deterministisch geordnete Ereignisse; Anwendung genau einmal |
| `get_player_view` | Zustand, Spieler-ID | Eigene erlaubte private Daten + öffentliche Daten; keine gegnerische Hand/Deckreihenfolge, Seeds oder internen Snapshots |
| `get_public_events` | Zustand/Ereignisoffset | Nur explizit öffentliche Nutzlasten; Ereignisprotokolle der existierenden Engine enthalten teilweise komplette Zustände und sind keine Netzwerkereignisse |
| `get_result` | Zustand | Nicht beendet oder ausschließlich aus Enginebedingungen abgeleitetes Resultat samt Abschlussgrund |
| `serialize` / `restore` | Interner Zustand bzw. versionierter Snapshot | Vollständige Wiederherstellung aller logischen Felder; bitgenau gleiche folgenden Aktionen/Ereignisse |

Die Seiten `hero`/`enemy` werden einmalig an Spieler-IDs gebunden. Jeder Befehl
muss für beide Menschen funktionieren. `start_match`, `finish_opening` und
`end_turn` dürfen keine automatisch ausführenden Gegner-Komfortpfade aufrufen.
Auch Mulligan, Ursprung und zweite Eröffnungsänderung benötigen zwei unabhängige
Eingabeseiten statt der aktuellen lokalen Gegnerentscheidungen.

## Zustand, Versionen und Determinismus

Ein Match pinnt Protokollversion, Regelprofilversion, Kartenkatalogversion und
Hash des ausführbaren Regelartefakts. Laufende Matches wechseln diese Versionen
nicht. Neue Kataloge erhalten neue unveränderliche IDs/Hashes; Namensgleichheit
ist kein Regelidentitätsnachweis.

Der Restorevertrag umfasst mindestens beide Spielerzustände, Phasen,
Pendingziele, UID-Zähler, verzögerte Effekte, Eröffnung, Relikte, Gewinnzustand,
RNG-Zustand und Aufrufzahl, Queue-/Fail-stop-Zustände sowie Triggerbindings und
bereits verarbeitete Ereignis-IDs. Ein vorhandener `snapshot()`-Vergleich allein
beweist noch kein vollständiges Resume. Adapter-/Nativequeuebudgets müssen
gemeinsam gegen unendliche oder zu teure Ketten begrenzen.

Zufallsseed: kryptografisch auf dem Server erzeugen, anschließend nur die
versionierte deterministische Enginefolge konsumieren. Der vorhandene 32-Bit-LCG
ist vorhersagbar, sobald genug Zustand bekannt wird. Deshalb Seeds/RNG-Zustände
und ableitbare versteckte Konsumdetails während Matches nicht veröffentlichen.
Eine spätere RNG-Änderung erfordert explizite Regelversion und Paritätstests;
dieser Auftrag verändert die vorhandene RNG nicht.

Canonical-JSON/Hashing muss Sprachgrenzen berücksichtigen: Feldreihenfolge,
Ganzzahlgrenzen, Nullwerte, Unicode, Floats und Godot-JSON-Zahlen festlegen.
Wirtschaftliche Zähler und IDs nicht verlustbehaftet in JavaScript-Floats senden.

## Fehler und Persistenz

Ungültige Aktionen verändern weder Zustand noch RNG und verbrauchen keine
zulässige Aktionssequenz. Technischer Enginefehler ist kein Spielzugfehler und
kein vom Client behaupteter Sieg: Match anhalten, Diagnose-ID ohne Geheimnisse
erzeugen und reproduzierbare Untersuchung ermöglichen. Bereits begonnene
Fail-stop-Ketten dürfen nicht stillschweigend als vollständiger Erfolg gelten.

Aktion, neuer Snapshot, Ereignisse und Idempotenzbeleg gehören in dieselbe
Schreibtransaktion. Erfolg erst nach Commit bestätigen. Bei Wiederholung identisch
bestätigen, bei gleichem Request-Key mit anderer Absicht ablehnen. Nach Workercrash
aus dem letzten Commit neu starten und Replayhash vergleichen. Interne Worker-
Timeouts erzeugen keine zusätzlichen Karten, Ressourcen oder Belohnungen.

## Replay und Freigabeprüfung

Vollständiger Replay: Teilnehmer, Startparameter, Regel-/Katalogartefakt, Seed,
akzeptierte Aktionen, geordnete Ereignisse, Abschlussergebnis und Zeitstempel.
Keine Zugangsdaten. Die lokale Simulation erlaubt vollständige Replays nur den
beiden Teilnehmern nach Abschluss/Abbruch; die echte Engineintegration erhält
dadurch keine automatische Freigabe. Auch nach Matchende kann
Deck-/Strategieprivatsphäre eine gesonderte Produktentscheidung erfordern.
Während des Matches ausschließlich gefilterte Teilnehmeransichten.

Vor Aktivierung sind erforderlich:

1. Zwei menschliche Seiten durch sämtliche Eröffnungs-/Pending-/Reaktionsphasen.
2. Differentialtests gegen genau denselben lokalen Kernel und dieselben Daten.
3. Wiederholung/Restore an jeder Aktionsgrenze mit identischen Zustands-/Eventhashes.
4. Negativtests für fremde Match-ID, Karte, Ziel, Ressourcen, Reihenfolge und Seed.
5. Leaktests für Spieler A/B/Zuschauer, Fehlermeldungen und Ereignisreconnect.
6. Workerabbruch vor/nach DB-Commit, Doppelzustellung, Ablauf und Zeitfenster.
7. Godot-Headless-Lastmessung mit realen Effekten, begrenztem CPU/RAM und Kettenbudget.
8. Kontinuierliche Offline-Regressionsprüfung ohne erreichbaren Onlineserver.
9. Abgestimmter Besitz-/Deck-/Ergebnisvertrag mit dem Economyauftrag.
10. Explizite Freigabe eines getrennten Produktionsrollouts.
