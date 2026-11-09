# Roadmap: offline beginnen, Autorität später sicher übertragen

Alle Pakete sind zukünftige Arbeit, außer dem vorliegenden **Dokumentationsanteil** von A. Keine Phase B–F ist implementiert. Eine simulierte Transaktion ist kein Nachweis serverseitiger Sicherheit. Kein automatischer Merge/Deploy als Folge dieses Plans.

Komplexität relativ: S = kleines isoliertes Modul, M = mehrere Module/Verträge, L = Systemintegration, XL = verteilte/externe und betriebliche Abhängigkeiten. Grobe Planung unter unbekannter Teamgröße: S einige Tage, M mehrere Wochen, L mehrere Wochen bis Monate, XL offen/mehrmonatig. Keine belastbare Termin-/Kostenkalkulation ohne Scope, Team und externe Anbieter.

## Phase A — Architektur und Datenverträge (M)

Voraussetzung: stabiler develop-Stand, Audit-PR #1 lesbar, getrennte Entscheidung über Legacy-Regelziel. PR #2 prüfen, nicht implizit mergen. Dieser PR liefert Architektur, keine ausführbaren Schemas oder Dienste.

| Paket | Abhängigkeit / Ergebnis | Test-/Abnahmekriterium |
|---|---|---|
| A1 Status-/ADR-Review | vorliegende Dokumente, Produktverantwortung | Bestand vs Konzept, offene Produktentscheidungen und alle Trust Boundaries explizit bestätigt |
| A2 JSON-/DB-Verträge | A1; 10 Modelle und ergänzende Operation/Pack/Policy-Schemas | JSON-Schema-Positiv/Negativtests, UUID/Integer/UTC-Grenzen, Migrationsfixtures und unbekannte Revisionen |
| A3 Kerninvarianten/Ports | A2; Query-/Command-/Error-/Versionverträge | Identischer Contracttest für InMemory- und zukünftige Adapter; kein UI-/Commerceimport im Karten-/Deckkern |
| A4 Katalog-/Modus-Mapping | separate Review von PR #2, keine ökonomische Balanceänderung | Original100 IDs/Werte und fünf Decklisten unverändert; Prototyp7 getrennt; keine Namensheuristik |

Risiken: unklare Regelversion, Identitätsvermischung, implizite Besitzfreischaltung. Gate A: reviewte Datenverträge und feste Beispielszenarien; aktuelle Dokumente allein erfüllen keine Implementierungsabnahme.

## Phase B — Lokale Inventar- und Boostersimulation (M–L)

Voraussetzung A2–A4; keine produktiven Identitäten/Zahlmittel. Lokale transaktionale Speicherung/Plugin für PC/Android/iOS evaluieren; im ersten Testadapter vollständig offline.

| Paket | Ergebnis | Tests / Abnahme |
|---|---|---|
| B1 Sandboxinventar und Ledger | Lokale UUIDs, Sandboxprincipal, einzelne Instanzen, reservierte/verbrauchte Zustände | Atomarer Save/Crash-Restore, keine doppelte Instanz, Ledgergruppen balanciert, keine Nutzerüberziehung |
| B2 Policyengine und PackUnit | Konfigurierbare Pools/Raten/Garantien/Pity/Bindung, injizierbare RNG/Uhr | Exakte garantierte Grenzen, Summe10000, leerer Pool, Duplicate-Historie, Commitfehler; statistische Verteilung ergänzend |
| B3 Tutorial-/Gratisrewards | Vollständiger fixierter Starter, einmalige Quellschlüssel/Perioden | Zwei wiederholte Claims gleicher Effekt; alle25 Starterkopien gratis; neue Periode nicht aus Gerätezeit manipulativ ableiten (Simulation vertrauenslos markieren) |
| B4 Simulator-UI/Ports | Eindeutig „Simulation“, kein angeblicher echter Kauf | Gleiches Datenformat/Errors wie A3, kein automatischer Sandboxexport nach live, vorhandene Arena unverändert sofern nicht eigener Auftrag |

Risiken: lokale DB wird als sicher verkauft, unbemerkte Bool-/Float-Coercion, Pitydivergenz. Gate B: Reproduzierbarkeit, lokale Crashkonsistenz, Contracttests und Quellen/Sinks nachvollziehbar; keine Anti-Cheat-/Mehrprozessbehauptung.

## Phase C — Deckverwaltung und Spielmodi (L)

Voraussetzung B1/A4; spielbare Legacy-Modi zusätzlich erst nach Audit-Paketen P02d–P11 und eigenen Kampftests. Wirtschaftstests können mit Stubmatch laufen, aber keine echten Siege behaupten.

| Paket | Ergebnis | Tests / Abnahme |
|---|---|---|
| C1 Definition-/Instanz-/Deckansichten | Sammlung zeigt Dauerbesitz, Leihnutzung und Konzepte getrennt | Deckgrößen/Kopien-/Pool-/Besitztests; keine Leihkarte als verkäufliche Kopie |
| C2 ModeManifest/Entitlement | Tutorial/classic/ranked/event-Policystubs, permanente/zeitliche/scoped Rechte | Clock-Grenzen, unbekanntes Ruleset, Rotation, zwei Geräteversionen im Adaptertest |
| C3 Draft/Sealed-Simulation | Sessionpool/Picks/Tickets, Leihe default | Kein Poolwechsel, keine Inventareinschübe, Leihe weder salvage noch trade, Reward explizit separat |
| C4 Matchreservation-/Rewardvertrag | Reservierte konkrete Instanzen, einmalige Ergebnissource | Verkauf vs Start, abgebrochenes Match, doppeltes Resultat; Space-Time nur Capabilityvertrag, nicht neue Fähigkeit |

Risiken: Regelport und Ökonomie blockieren sich; künstliche Matchrewards versehentlich als verifiziert. Gate C: Spieler kann Starter/Booster/Deck/Leihmodus ohne Geld testen; regelabhängige Livefeatures bleiben deaktiviert bis separater Nachweis.

## Phase D — Simulierter Markt und Gilden (L)

Voraussetzung B/C, ausschließlich Sandboxkonten. Mehrere simulierte Principals ermöglichen Rennen, ersetzen aber keine DB-Lasttests.

| Paket | Ergebnis | Tests / Abnahme |
|---|---|---|
| D1 Sell/Buy/Escrow | Ein Exemplar/Festpreis, Fees, Expiry/Cancel, reserviertes Gold | Ein Fill pro Listing, Goldsumme, item-lock, Storno/Fill-Rennen, Gebührenrundung |
| D2 Gildenrollen/Kasse | Separater Principal, Rechte/Spenden/Gildenrewards | Ownernachfolge, Rollenänderungsrennen, kein Privatcashout, Wiederbeitritt ohne Zusatzreward |
| D3 Simulationsökonomie | Verschiedene Käufer-/F2P-/Farm-/Marktakteure, Telemetrie | Quellen/Sinks, Gold-/Kartenkonzentration, Pity/Salvageschleifen und Preismanipulation reproduzierbar |

Risiken: Schätzung durchschnittlichen Verhaltens verkennt optimale Bots, Markt ohne Liquidität. Gate D: technische Invarianten + dokumentierte Sensitivitätsanalyse, **keine** Behauptung wirtschaftlicher Stabilität ohne reale Daten.

## Phase E — Serverpersistenz und Transaktionssicherheit (XL)

Voraussetzung reviewte A-Verträge, B–D-Contracttests, Backend-/Auth-/Betriebsentscheidungen. Noch keine Echtgeldprodukte.

| Paket | Ergebnis | Tests / Abnahme |
|---|---|---|
| E1 Auth/Realm/API/DB-Migration | Eindeutige Serverprincipals, keine Client-Direktschreibrechte | Objektberechtigung/Token-/Schema-/Sandboxisolierung, Migrationsrollforward und Restore |
| E2 Atomare Wirtschaftscommands | Ledger, Idempotenz, Pack-/Reward-/Escrow-Constraints, Outbox | Echte konkurrierende DB-Verbindungen, verschiedene Requestkeys, Fault Injection an jeder Commitgrenze, keine Duplikation/Überziehung |
| E3 Verifizierte Belohnungsquellen | Serverfähiger Match-/Tutorial-/Eventvertrag | Client-Sieg/Savefälschung gibt nichts; Quelle genau einmal; Combatrewind vervielfacht keine wirtschaftlichen Wirkungen |
| E4 Remoteadapter und Cache | Gleiche Ports, Versionskonflikte, Offlineübungsmodus | Gerätewechsel/Pushverlust/409/Timeout/retry; keine lokalen Saldenimports; bestehende Komfortstände erhalten |
| E5 Betrieb/Sicherheit | Reconciliation, Kill-Switch, Monitoring, Backup/PITR, Incident/Supportrollen | Restore/Outbox-Replay, Alarm bei Ledgerdrift, unabhängiger Securityreview und Last-/Failovertests |

Risiken: verteilte Ergebnisherkunft, Auth-/IDOR, unzulängliche Recovery, ungedeckte Systemmints. Gate E: wirtschaftliche Invarianten unter echten Rennen/Abbrüchen bewiesen; sichere kostenlose Server-Beta vor Geldintegration. Kapazitäts-/RPO/RTO-Ziele nach Messung festlegen, nicht erfundene SLA garantieren.

## Phase F — Monetarisierung und Livebetrieb (XL + externe Wartezeiten)

Voraussetzung E-Gate; konkret freigegebene Produkte/Raten/Regionen/Altersregeln, Store-/Rechts-/Datenschutzprüfung und Entscheidung über paid tradable Cards/Chargebackfolgen. Unbeschlossene Gatefrage bedeutet Feature bleibt aus; kein Implementierungsautomatismus.

| Paket | Ergebnis | Tests / Abnahme |
|---|---|---|
| F1 Produkt-/Offenlegungsverträge | SKU/Angebot getrennt von Ziehpolicy, verständliche Chancen/Preise/Garantien/Bindungen | Raten über alle Pity-/Schutzzustände korrekt kommuniziert, Regions-/Altersgates geprüft |
| F2 Storeadapter und Inbox | Serververifikation, Providertransaktionskeys, Pending/Grant/Refundzustände | Store-Sandbox, doppelte/verspätete/falsche Receipts, App-/Environment-/Kontobindung, Mengen und Renewals getrennt |
| F3 Chargeback-/Fraudabwicklung | Herkunft, Reserven/Quarantäne, Support/Beschwerde | Verkaufskette nach Refund, gutgläubiger Dritter, kein stilles Negativkonto/Itemcloning |
| F4 Begrenzter Live-Rollout | Freigegebene Regionen/Kohorten, Limits, Notabschaltung, Support | Stopkriterien/Verlustbudget eingehalten, Backup/Recovery geprobt, keine Aktivierung weiterer Märkte ohne Review |

Risiken: Glücksspiel-/Jugendschutz-/Storebewertung, externer Echtgeldmarkt, Pay-to-win, Rücklastschäden und Kundenschutz. Gate F: schriftlich geklärte Produkt-/Rechts-/Betriebsfreigaben und technische Nachweise, **nicht** allein eine grüne Client-Testsuite.

## Priorisierung und Erweiterung

P0 A-Verträge + B-Invarianten; P1 C-Deck-/Leihtrennung; P2 D-Simulation; P0 vor jedem Livevermögen E-Sicherheit; F gesondert gated. Vollständige Gildenwirtschaft und Raum-Zeit-Spielregeln dürfen den kleinsten sicheren Starter-/Booster-/Deck-MVP nicht blockieren. Ein späterer Raum-Zeit-Modus bekommt eigenen Gameplayauftrag mit deterministischem Servermodell, keine Rückwirkung auf Wirtschaftsledger.

Kein bestehender Spielstand wird hier migriert. Ein künftiger Launch erstellt Serverbesitz aus überprüften Grants; eventuelle Welcome-Rewards sind feste serverseitige Kulanzaktionen mit eigener Unique-Quelle, kein Upload lokaler Gold-/Kartenzahlen.
