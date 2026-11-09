# Marktplatz und Gildenvermögen

Entwurf für einen geschlossenen Kartenmarkt mit **nicht auszahlbarem Handelsgold**. Keine externe Geld-/Goldschnittstelle, kein Cashout und kein hier implementierter Shop. Echtgeldbooster mit handelbaren Karten erzeugen trotzdem indirekten Geldzufluss in die Handelsökonomie; siehe [Risiken](economic-risks.md).

## Angebots- und Preisvertrag

Zuerst ein Exemplar pro Angebot, Festpreis, keine Teilfüllung/Auktionen/Schulden. Beide Seiten werden modelliert: Verkaufsangebot reserviert konkrete Karte; Kaufangebot reserviert Gold für genau eine passende Karte. `price` ist Gesamtpreis dieses Exemplars, quote nennt FeePolicyrevision, mögliche Mindest-/Höchstpreise und Laufzeit. Verkaufspreis nicht als Eigentumsbeweis verwenden.

Preisband pro Pool/Kartentyp optional aus robustem zeitverzögertem Referenzpreis, mit Mindesthandelszahl, Ausreißerfilter und manueller Fallbackspanne. Ein einzelner Trade darf nicht unmittelbar das nächste Preislimit bestimmen. Dünne Märkte erfordern breite oder vorerst administrativ festgelegte Grenzen; Limits stoppen nicht jede Manipulation. Preise/Laufzeiten konkret offen. Gebührenbeträge vor Bestätigung sichtbar, Rundung/Minimum/Caps exakt in integerbasierter Policy.

Illustrativer Testfall: Preis100 Gold, Verkäufergebühr5%=5 Gold, Käufergebühr0. Settlement: Käufer−100, Verkäufer+95, Fee-Konto+5; Summe0. Bei Prozentberechnung etwa floor(price*bps/10000) und optional Mindestgebühr; Formel und Vorzeichen in veröffentlichter Revision fixieren, Überlauf prüfen. Keine stillen Gebührenänderungen an offenen Angeboten.

## Escrow und atomare Abwicklung

SellCreate: Eigentümer und Rechte authentisieren; verfügbare ungebundene, nicht geliehene/gesperrte Instanz prüfen; Karte mit aktiver Reservation an Listing binden und state escrow setzen; Angebot samt Deadline und Policy atomar anlegen. Besitz bleibt bis Settlement beim Verkäufer, aber Nutzung gesperrt. Open-Sell ohne gesperrte Karte ist ungültig.

BuyCreate: Wanted-Kartentyp/akzeptierte Bindung spezifizieren; available → reserved Gold inkl. maximaler Käufergebühr buchen, Listing gleichzeitig anlegen. Kein Gebot ohne vollständige Deckung. BuyFill: Verkäuferinstanz und Käuferreserve gemeinsam prüfen und übertragen; nur ein Fill. Im ersten Modell wird genau zum fixierten Kaufangebotspreis abgewickelt, ohne Teilfüllung oder Preisverbesserung. Reserve deckt Preis plus exakt berechnete Käufergebühr der fixierten Policy; beim Abschluss muss sie vollständig abgerechnet sein, sonst Rollback. Spätere Preisverbesserungen benötigen eine eigene Policyrevision. Nutzer dürfen nicht eigenes Listing oder gekoppelte kontrollierte Konten zum Farming von Handelsrewards nutzen; zunächst keine volumenabhängigen Handelsbelohnungen.

```mermaid
sequenceDiagram
    participant C as Käufer
    participant A as API / Market
    participant D as gemeinsame DB
    participant W as Outbox Worker
    C->>A: AcceptSellListing(id, expected_version, key)
    A->>D: Begin; Principals sortiert sperren; Listing/Asset/Wallet prüfen
    A->>D: Prüfe open, Deadline, Eigentümer, Bindung, Gold, Preis-/Feepolicy
    A->>D: Ledger: Käufer -100 / Verkäufer +95 / Fee +5
    A->>D: Ownerwechsel, Asset entsperren, Listing filled, Settlement unique
    A->>D: Inventoryversionen, Ergebnis und Outbox; Commit
    D-->>A: Durable Settlement
    A-->>C: settlement_id und aktuelle Version
    D->>W: Änderung später zustellen
```

Beim Kaufangebot ersetzt BuyerReserve den direkten available-Abzug. Diagramm zeigt den Testfall, keine Livegebühren. Alle schreibenden Teile teilen eine Transaktion; Outboxzustellung nicht im Geldpfad. Keine Remote-Networkcalls unter DB-Locks.

## Ablauf, Storno, Rennen und Handelshistorie

`open → filled` oder `open → cancelled/expired` atomar; `settling` nur transient innerhalb Transaktion, kein unklarer Dauerzustand. Deadlineprüfung mit Serverzeit nach Locks: `now >= expires_at` verhindert neue Füllung. Expiryworker und Accept/Cancel konkurrieren mit CAS. Genau ein Pfad gewinnt; Storno/Expiry lösen Karte/Goldreserve exakt einmal, bei filled kein Refund. Vor Commitcrash rollt zurück, danach Retry liefert Settlement.

Vollständige Historie: Listingrevision, Ursprungs-/neuer Eigentümer, Asset, Brutto-/Netto-/Gebühr, CurrencyLedgerref, Policies, Zeit und Risikoentscheidung. Öffentliche Historie aggregiert/pseudonymisiert; interne Transaktionsdaten rollenbasiert und zeitlich begrenzt zugänglich. Rechts-/Betrugsaufbewahrung und Löschpflichten gemeinsam festlegen, keine persönlichen Daten in unveränderlichen Freitextlogs.

Fraudkontrollen: Accountalter/Übernahmeindikatoren, verifizierte Zugangsqualität, Handels-/Goldlimits, neue Geräte, Preisabweichung, gegenseitige Zyklen und Herkunft geöffneter bezahlter Packs. Maßnahmen proportional: stärkere Authentisierung, Drosselung, zeitliche Haltefrist, Quarantäne/Review. Kein alleiniger IP-Bann: Familien/Shared Networks sind nicht automatisch Farmen. Sicherheitscooldowns müssen explizit veröffentlicht und an Kartenherkunft nachvollziehbar sein.

## Gildenmodell und Kasse

| Rolle | Vorschlag | Kontrolle |
|---|---|---|
| owner | Nachfolge, Rollenverwaltung, Auflösungsantrag | Letzter Owner nicht ohne Nachfolge entfernen; sensible Aktion mit Reauth/MFA |
| admin | Mitglieder/Kader nach Policy | Keine Kassenentnahme allein aus Adminstatus |
| treasurer | Budgetvorschlag/zugelassene Gildenausgaben | Betrags-/Zeitraumlimit, ab Schwelle Zwei-Personen-Freigabe |
| member | Spenden, erlaubte Angebote, berechtigte Rewards | Kein freier Schreibzugriff auf Schatzkonto |

Gildeninventar und Wallet sind eigenständige Principals; Vermögen gehört nicht dem Leader und wandert nicht mit dessen Abgang. Mitgliedschaften/Rollen bei Commit erneut prüfen, Versionskonflikte auf zwei Geräten ablehnen. Vorgeschlagen pro Nutzer eine aktive Gilde; Ein-/Austritt und Eligibility-Cooldown versioniert, keine Aussage über „ein Mensch = ein Konto“ ohne gesonderte Policy.

Kassenquellen: verifizierte Gildenrewards, ausdrücklich konfigurierte Spenden. Kassenverwendung zunächst nur autorisierte Gildenleistungen, **keine direkte Auszahlung an Mitglieder**. Erweiterung benötigt Produktentscheidung gegen Farm-/Leaderdiebstahl. Spende ist Ledgertransfer, kein goldschöpfender Reward; Quote/Donation-Rewards vermeiden. Genehmigungen binden Betrag/Empfänger/Policy/Payloadhash und verfallen bei Rollenänderung, keine Blankosignatur.

Gildeninterner Handel kann als Sichtbarkeit `guild` über denselben Listing-/Escrow-/Ledgerpfad entstehen. Gleiche Bindung, Gebühren und Auditpflicht, kein versteckter Direkttransfer. Öffentliche und interne Märkte zusammen auf Wash Trading prüfen. Gildenrabatte/Gratisgeschenke nicht als Default: könnten Gebühren und Preisgrenzen umgehen. Transfers von Gildeneigentum zunächst nur freigegebene Ausgabepolicy, nicht per beliebigem Listing des Leaders.

Gildenbelohnungen: serververifizierter Eventabschluss, eingefrorener berechtigter Kader und Unique-Keys je Gilde/Event sowie Nutzer/Event. Ein-/Aus-/Wiederbeitritt oder Leaderwechsel vervielfacht keine Vergabe. Quoten zählen Zeitraum und wirtschaftliche Quelle, nicht nur aktuelle Mitgliedschaft. Auflösung blockiert neue Ausgaben, beendet offene Reserven, verteilt/verbrennt Rest nur nach vorher beschlossener auditiertem Vertrag; offene Entscheidung vor Live-Gildenvermögen.

## Spezifische Abnahmefälle

100 parallele Käufer auf ein Angebot → genau ein Settlement; Verkauf und Verwertung gleichzeitig → eine zulässige Wirkung; BuyCancel und Fill → keine doppelte Goldfreigabe; abgelaufenes Angebot nie füllen; Käufergebühr/Verkäufergebühr/Rundung/Summenprüfung; Leihe/Bindung/Quarantäne blockiert; Gebührenrevision während offenen Angebots unverändert; neue Rolle/Leaveraum während Kassencommand → Revalidierung; zwei Owner entfernen sich gleichzeitig → mindestens ein gültiger Owner; Farmen durch wiederholten Gildenbeitritt ohne Zusatzrewards.
