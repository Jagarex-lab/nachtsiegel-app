# Hosting und Kapazitätsplanung

Die folgenden Werte sind **Planungsannahmen vom 10.11.2026**, keine Angebote,
garantierten Preise oder gemessenen Godot-Leistungswerte. Steuern, Region,
Trafficpreise und Anbieterbedingungen können die Kosten stark verändern.
Es wird kein kostenpflichtiger Dienst für den lokalen Prototyp benötigt.

## Vergleich

| Modell | Nutzen | Grenze |
|---|---|---|
| Lokaler Nodeprozess + SQLite | Keine Cloudkosten, Debugging/Tests | Rechner muss laufen; kein öffentlicher Dienst, keine HA |
| Docker Compose lokal | Gleicher Dienst und persistentes Volume reproduzierbar | Container ist kein Sicherheits-/Kapazitätsnachweis; lokale Dockerverfügbarkeit prüfen |
| Günstiger VPS | Feste kleine Kosten, Reverse Proxy/WSS, eigene Backups | Betreiber verantwortet Updates, TLS, DDoS-/Loginlimits, Restore und Monitoring |
| Managed App + PostgreSQL | Weniger DB-Betrieb, Skalierungsoptionen | WebSocket-Idlelimits, Sleep/Cold-start, dauerhafte Prozesse und Egresspreise prüfen |
| Containercluster | Isolation und mehrere Worker | Orchestrierung/DB/Routing/Leases/Observability teuer; erst bei gemessenem Bedarf |
| Statisches GitHub Pages | Bestehender Godot-Webclient | Kein Nodeprozess, keine DB und kein autoritativer Matchserver |

## Explizite Lastannahmen

- Ein DAU spielt im Mittel 3 Duelle pro Tag; zwei Spieler pro Duell.
- Mittlere Duelldauer 10 Minuten; 30 Tage pro Monat.
- Spitzenlast beträgt das Vierfache der über 24 Stunden verteilten mittleren Last.
- 50 kB initiale Daten pro Client und 2 kB/s pro aktivem Client als
  Planungsbudget für Snapshots/Ereignisse inklusive Reserve; kein gemessener Wert.
- 100 kB intern gespeicherter Replay-/Ereignislog pro Duell; 30 Tage heiß vorhalten.
- Noch keine Illustrationen, Downloads, Voice/Chat, Zuschauer, Angriffsverkehr
  oder Backupegress in diesem Netzwerkmodell.

Formeln:

```text
Duelle/Tag              = DAU × 3 / 2
mittlere aktive Duelle  = Duelle/Tag × 10 / 1440
Spitzenduelle           = mittlere aktive Duelle × 4, aufgerundet
aktive Spitzenclients  = Spitzenduelle × 2
Monatsdaten            ≈ Duelle/Tag × 30 × (2 × 50 kB + 2 × 600 s × 2 kB/s)
Replaydaten / 30 Tage   = Duelle/Tag × 30 × 100 kB
```

| DAU | Duelle/Tag | mittlere / Spitzen-Duelle | Spitzenclients | Traffic/Monat (dezimal) | Replaydaten/30 Tage |
|---:|---:|---:|---:|---:|---:|
| 100 | 150 | 1,04 / 5 | 10 | 11,25 GB | 0,45 GB |
| 1.000 | 1.500 | 10,42 / 42 | 84 | 112,5 GB | 4,5 GB |
| 10.000 | 15.000 | 104,17 / 417 | 834 | 1,125 TB | 45 GB |
| 100.000 | 150.000 | 1.041,67 / 4.167 | 8.334 | 11,25 TB | 450 GB |

Diese Spitzen können durch regionale Spielzeiten, Events und Loginwellen
deutlich überschritten werden. Speicherbedarf umfasst zusätzlich Accounts,
Indizes, WAL, Backups und Datenbankfreiraum. Drei vollständige Backups der heißen
Replaydaten erfordern allein ungefähr das Dreifache der letzten Spalte; inkrementelle
Backups und spätere Archivierung ändern das Modell.

## CPU, RAM und Geld: noch unbewiesene Größen

Der Protokollsimulator bildet keine Effektauswertung ab. Seine Messungen sind
keine Kapazitätstests einer Godot-Engine. Argon2id mit 64 MiB pro parallelem Hash
dominiert mögliche Loginspitzen; gleichzeitige Hashes müssen begrenzt werden.
Eine physische oder gemeldete vCPU allein sagt wenig über nutzbare CPUzeit aus.

```text
Worker-RAM = Spitzenmatches × gemessene Bytes/Match + Prozess-/DB-/Cachebudget
CPU-Bedarf = Aktionen/s × gemessene CPU-ms/Aktion / 1000 + Auth/Transportreserve
Kosten     = Compute + DB + Speicher + Backup + Egress + Monitoring + Betriebszeit
```

Für die Budgetdiskussion können folgende **unverbindliche monatliche EUR-
Korridore** dienen. Sie beruhen auf typischen Größenklassen selbst betriebener
Infrastruktur, nicht auf abgefragten Angeboten oder Lastgarantien; Personal,
Steuern, Rechtsprüfung und DDoS-Sonderkosten sind nicht enthalten.

| DAU | Zu untersuchende Größe, kein Leistungsversprechen | Budgetkorridor/Monat |
|---:|---|---:|
| 100 | 1 kleiner VPS, etwa 2 vCPU/2–4 GB, Backup außerhalb des Hosts | 10–40 € |
| 1.000 | 2–4 vCPU/4–8 GB, PostgreSQL auf demselben oder eigenem Host je Messung | 25–120 € |
| 10.000 | Mehrere API-/Regelworker, PostgreSQL, separates Backup/Monitoring; etwa 8–32 vCPU/16–64 GB Gesamtbudget zunächst vermessen | 150–900 € |
| 100.000 | Verteilter Workerpool + HA-DB/Routing, etwa 32–256+ vCPU/64–512+ GB nur als Benchmarkrahmen | 1.000–8.000+ € |

Vor einer Kaufentscheidung mindestens zwei aktuelle Anbieterangebote für die
Zielregion vergleichen. Auf enthaltenes Egressvolumen, Mehrtraffic, WSS-Zeitlimits,
Backupaufbewahrung, Support, Datenstandort und AV-Vertrag achten. Hohe
Godot-Prozesskosten oder Managed-Premium können alle Korridore überschreiten.

## Nächste Messung

Die tatsächlich ausgeführten lokalen Stufen und Grenzen stehen in [QA.md](QA.md).
Vor Produktion: echte Godot-Worker mit typischen und maximalen Effektketten
profilieren; gleichzeitig Loginlast, DB-Commits, Reconnectwellen und Backupjobs
fahren. p50/p95/p99, Fehlerrate, Eventloop-Lag, CPUzeit, RSS/Peak-RAM,
DB-Wartezeit und Netzvolumen erheben. Danach Zielauslastung/Reserve festlegen und
dieses Modell mit Messwerten ersetzen. Bis dahin ist keine Spielerzahl zugesagt.
