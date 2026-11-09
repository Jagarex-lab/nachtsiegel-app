# Inventar-, Ledger- und Kauftransaktionen

## Autorität und Constraints

Alle folgenden Abläufe sind Entwürfe. DB-Constraints ergänzen Handlerprüfungen, ersetzen aber nicht Policy-/Berechtigungsprüfungen.

| Invariante | Persistente Sicherung |
|---|---|
| Ein einmaliger Grant | UNIQUE(realm,beneficiary,source_kind,source_id,period) |
| Ein Kauf nur einmal geliefert | UNIQUE(provider,environment,provider_transaction_id,line_item); Produktmenge/Einheiten deterministisch indiziert |
| Ein Booster nur einmal geöffnet | PackUnit UUID + owner + state, UNIQUE(opening.pack_unit_id) |
| Ein Exemplar nur einmal besessen/gesperrt | CardInstance PK mit owner-FK; UNIQUE aktive AssetReservation(instance_id) |
| Ein Listing nur einmal abgewickelt | UNIQUE(settlement.listing_id); CAS open → filled |
| Ein Request nur eine Wirkung | UNIQUE(principal,realm,operation_kind,idempotency_key) plus Payloadhash |
| Kein negativer Nutzerbestand | Geprüfte Ledgeraddition unter Kontosperre, DB-Limit, eingeschränkte Ledger-Prozedur |
| Keine halbe Vergabe | Asset-, Reward-, Ledger-, Version- und Outboxzeilen in einer DB-Transaktion |

Realm-FKs binden Asset, Besitzer, Grant, Reservation und Ledgeroperation an denselben Realm (z.B. zusammengesetzte FK auf realm/inventory_id); globale UUIDs allein verhindern Cross-Realm-Zugriff nicht.

Ledger: pro Transaktionsgruppe und Währung Summe0, sonst kein Commit (deferrable Constraint/abgesicherte Buchungsprozedur). Erträge kommen von ausdrücklich autorisierten Systemquellen mit Rate-/Tagesbudget. Gebühren auf Fee-/Sinkkonten, keine negativen Nutzerkonten. Reserve: available → reserved; Freigabe umgekehrt, kein neues Gold. Operative Walletprojektion muss jederzeit aus Ledger rekonstruierbar sein. Reconciliationabweichung sperrt betroffene Commands und alarmiert, sie wird nicht durch stilles Neuschreiben der Historie kaschiert.

## Gemeinsamer Commandablauf

1. Authentisierung, Realm, Berechtigung, Schema und Payloadgröße prüfen. Idempotency-Key auf dieselbe Principal-/Operationsgrenze binden; kanonischer Payloadhash enthält Ressourcen, Menge und freigegebene Angebotsrevision.
2. Operation exklusiv beanspruchen/finden. Gleicher Key/gleicher Payload: gespeicherte Antwort oder Fortschritt zurückgeben. Gleicher Key/anderer Payload:409, keine Mutation. Antwortcache darf ablaufen, logischer Duplikatnachweis bleibt über fachliche Unique-Keys/Tombstones erhalten.
3. Betroffene Principals (Nutzer/Gilden) in global sortierter Reihenfolge mit Transaktionslocks serialisieren. Danach Ressourcen gemäß einheitlicher Tabellen-/ID-Reihenfolge sperren und aktuelle Versionen/Besitz/Policies erneut prüfen. Bei Listing zuerst unverbindlich Gegenpartei lesen, nach Locks revalidieren; geänderte Gegenpartei → Retry, keine Entscheidung auf altem Read.
4. Wirtschaftseffekte und Ledger atomar schreiben, Aggregateversionen erhöhen, Ergebnis und Outbox in derselben Transaktion persistieren. Keine externen Store-/Pushaufrufe während langer DB-Locks.
5. Commit, dann Response/Push. Bei Netztimeout nach Commit dieselbe Operation abfragen/wiederholen; nicht mit neuem Key „vorsichtshalber“ neu buchen. Outbox liefert mindestens einmal, Konsumenten deduplizieren `event_id`/fachlichen Schlüssel. Keine globale Exactly-once-Netzwerkgarantie behaupten.

Isolation: konservativ SERIALIZABLE für Wirtschaftscommands plus explizite Locks; Serialization-/Deadlock-Retries begrenzt und mit gleichem Key. Lastannahmen messen; spätere Optimierung nur mit identischen Invariantentests. Alle Mutationspfade einschließlich Support, Expiryworker und Gildenaktionen nutzen dieselbe Sperrkonvention.

## Boosteröffnung

PackUnit enthält `pack_unit_id`, owner/realm, immutable booster_policy_ref, state `sealed/opened/quarantined`, version, origin_purchase/grant. Kein Client kann selbst eine PackUnit erzeugen.

```mermaid
sequenceDiagram
    participant C as Godot
    participant A as API
    participant D as DB
    participant R as Server RNG / Policy
    C->>A: OpenPack(pack_id, key, expected_version)
    A->>D: Begin; Operation / Principal / Pack / Pity sperren
    D-->>A: Besitzer, sealed, fixierte Policy
    A->>A: Pool, Zugriff, Caps und aktuelle Version prüfen
    A->>R: Ziehen nach exakter Policy, CSPRNG
    R-->>A: Ergebnis + Pity-Folgezustand + Auditdaten
    A->>D: Instanzen, Öffnung, consumed-Pack, Pity, Version, Outbox
    A->>D: Commit als eine Einheit
    D-->>A: Durable Ergebnis
    A-->>C: Gleiche operation_id und Instanz-IDs auch bei Retry
```

CSPRNG-Geheimnisse nicht an Client senden. Audit hält Policyhash, Pool, Ergebnis, serverseitig geschützte RNG-/Algorithmusreferenz und Zählerübergänge. Kein Preview vor Commit: Abbruch nach Ergebnissicht darf keine neue Ziehung erlauben. Absturz vor Commit → keine sichtbare Ziehung/kein Verbrauch; Retry kann neu intern ziehen, da kein Ergebnis veröffentlicht war. Absturz nach Commit → genau gespeichertes Ergebnis. Unter anderem gegen erneute Öffnung mit **anderem** Key schützt UNIQUE(pack_unit_id), nicht nur HTTP-Idempotenz.

## Reward und Verwertung

Tutorial: Serverquelle `tutorial_complete/tut-v1/once` und versionierte START-Multimenge; eine atomare Vergabe aller25 Kopien. Eine doppelte Meldung auf zwei Geräten liefert denselben Grant. Gegen Accountfarmen Starterbindung als explizite offene Empfehlung; reguläre Booster bleiben nach Policy handelbar. Offlineabschluss ist kein ausreichender Beleg für Live-Vermögen.

Salvage: verfügbare eigene Instanz sperren, Bindung/Leihe/Match/Escrow prüfen, state consumed + OwnershipEvent + konfigurierte Ausbeute in derselben Transaktion. Keine Verwertung geliehener oder verkaufter Karten; keine automatische Verwertung jedes Duplikats. Umkehr als neue explizite Kompensation mit neuer Instanz und Herkunft, nicht Wiederbelebung einer bereits anderweitig benutzten UUID.

## Käufe: entworfen, nicht integriert

Client sendet Receipt-Hinweis, nie `paid:true` oder eine zu mintende Menge. Backend prüft zukünftigen Store serverseitig: Signatur/Providerabfrage, App/Bundle, Produkt/SKU, Environment, Menge, Status, Nutzerbindung und widerrufene Transaktion. Netzwerkverifikation getrennt von kurzer Granttransaktion; erneuter Providerstatus kann später korrigieren.

Unterscheiden: Notification-ID dedupliziert Webhooks; tatsächliche provider_transaction_id/line_item dedupliziert die wirtschaftliche Lieferung. Eine Abo-Stamm-ID allein darf nicht alle Erneuerungen zusammenwerfen. Konsumierbare Packeinheiten `purchase-id + line + unit_index` eindeutig erzeugen; Appreceipt auf anderem Nutzer ist kein neuer Kauf. Zustände Purchase: received → verifying → verified → granted oder rejected; danach disputed/refunded/reversed als neue Ereignisse. Provider-Timeout bleibt pending, nicht grant.

Refund/Chargeback kann nicht atomar mit externem Store laufen: signiertes Ereignis dauerhaft inboxen, dann eine idempotente Kompensation. Ungeöffnete Pakete sperren/entziehen nach beschlossener Policy; geöffnete/weiterverkaufte Vermögenswege über Herkunftsgraf prüfen. Keine pauschale Löschung von Karten eines gutgläubigen Käufers und kein negatives Handelsgold ohne gesonderte freigegebene Schuldenregel. Risikofall einfrieren, Supportentscheidung/Reservebudget; bezahlter Handel darf vor dieser Entscheidung nicht live gehen.

## Crash-, Race- und Gerätematrix

| Fall | Erwartete Wirkung / Test |
|---|---|
| Zwei OpenRequests, unterschiedliche Keys, gleicher Pack | Genau ein Opening, zweite Antwort verweist auf consumed/Originaloperation |
| Commit erfolgreich, Antwort verloren | Retry gleiche IDs, kein erneutes Pity/Gold/Item |
| DB-Abbruch zwischen Mint und Verbrauch | Rollback aller Zeilen; kein halbes Pack |
| Gleichzeitiges Listing/Salvage/Matchstart | Genau eine aktive Reservation; andere ITEM_LOCKED/VERSION_CONFLICT |
| Käufer storniert während Füllung | Entweder komplett filled oder komplett cancelled, nie doppelte Erstattung |
| Veraltete Inventoryversion eines zweiten Geräts |409 + neuer Snapshot; kein Merge per Addition |
| Doppelte Storebestätigung/verspäteter Refund | Ein Grant, eine klar referenzierte Kompensation; Inbox- und Business-Keys getrennt |
| Outbox fällt aus | Commit bleibt wahr; Zustellung später dedupliziert, kein zweites Mint |
| Restore aus Backup | Reconciliation mit Provider-/Auditnachweisen, Tombstones erhalten; keine neuen Claims durch verlorene Responsecaches |
| Admin korrigiert Fehler | Eigener auditiert autorisierter Kompensationscommand; keine SQL-UPDATE-Saldenkorrektur |

Testverfahren: jede Schreibgrenze mit Fault Injection vor/nach Commit, mindestens zwei echte konkurrierende DB-Verbindungen, property-basierte Folgen und Restoreproben. Lokale Einprozesssimulation allein beweist diese Servergarantien nicht.
