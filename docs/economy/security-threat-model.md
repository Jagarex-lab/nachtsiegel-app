# Sicherheitsbedrohungsmodell

Entwurf, keine Aussage über implementierte Schutzmechanismen. Schutzgüter: eindeutiger Besitz, verfügbare/reservierte Goldbeträge, Pack-/Rewardansprüche, Kauf-/Ergebnisprovenienz, Kontozugang, Pityzustand, Gildenvermögen und personenbezogene Daten. Angreifer können Client, lokalen Speicher, Requests, mehrere Konten und Zeitabläufe kontrollieren. Auch gestohlene Dienst-/Supportrechte sind zu berücksichtigen.

Bewertung: Wahrscheinlichkeit W und Schaden S jeweils1 niedrig bis5 sehr hoch unter künftigem frei handelbarem F2P-Betrieb, ordinaler Prioritätswert W×S, keine empirische Eintrittsprognose. Restrisiken verlangen Produkt-/Betriebskontrollen, nicht nur technische Tests.

| Szenario / Angriff | W | S | Wert | Gegenmaßnahme und späterer Nachweis |
|---|---:|---:|---:|---|
| Bot wiederholt Tutorial-/Siegmeldungen für kostenlose Packs | 5 | 4 | 20 | Nur verifizierte Quellen, fachliche Unique-Keys, Rewards/Caps pro Periode; Replay mit neuen Requestkeys bringt nichts. Challenge/Matchsimulator statt vertrauensvollem Clientflag. |
| Accountfarm erzeugt Gratisstarter und verkauft an Hauptkonto | 5 | 4 | 20 | Explizite Starterbindung erwägen, Handelszugang/Reifung/Quoten und Herkunftsgraph; mehrere Konten/Netze im Test. Kein Beweis durch Gerätefingerprint allein. |
| Modifizierter Client setzt Inventar/Gold lokal hoch | 5 | 5 | 25 | Kein Client-Schreibpfad für Salden/Assets; authentisierte Absichtscommands und serverseitige FK-/Berechtigungsprüfung. Manipulierte Save-/JSON-Payload vollständig wirkungslos. |
| Gleichzeitiges Öffnen desselben Packs mit verschiedenen Keys | 4 | 5 | 20 | Packlock + UNIQUE(opening.pack_id), atomare Mint/Consumed/Pity; zwei echte DB-Verbindungen, Crash vor/nach Commit. |
| Rennen Verkauf/Salvage/Match, Itemduplikation | 4 | 5 | 20 | Eine aktive Reservation, CAS/Ownershiplock, keine Teilmutation; property-basierte interleavings und Reconciliation. |
| Goldduplikation durch Timeoutrefund + erfolgreiches Settlement | 4 | 5 | 20 | Ein Settlement/Stornopfad, persistente Antworten und Double-Entry, keine Refunds aus Clienttimeout. Fault-Injection aller Abbruchpunkte. |
| Gefälschte oder doppelte Kaufbestätigung | 4 | 5 | 20 | Providerprüfung, Account-/Produkt-/Environmentbindung, UNIQUE tatsächliche Transaktion/Einheit, Webhook-Inbox separat. Doppelte Notification und falsches Konto testen. |
| Chargeback nach Öffnen und Verkauf an Dritte | 4 | 5 | 20 | Ursprungsgraph, Risikoreserven, veröffentlichte Halte-/Quarantäneregeln, Review; Umgang mit gutgläubigem Käufer vor Freigabe entscheiden. Keine Behauptung vollständiger Rückabwickelbarkeit. |
| Wash Trading mit zwei Konten erzeugt Volumen/Referenzpreise | 5 | 4 | 20 | Keine Volumenrewards, Zyklen-/Gegenparteigraph, Gebühren, robuste Preisindizes; echte private Trades nicht allein wegen Korrelation bestrafen. |
| Marktmanipulation/Cornering einer knappen Karte | 4 | 4 | 16 | Bestands-/Orderlimits, robuste Preisbänder, Liquiditätsalarm, Poolzugänglichkeit; keine kurzfristige Preisautomatik aus einem Trade. Kartell bleibt möglich. |
| Preisabsprachen in Gilden | 4 | 3 | 12 | Aggregierte Marktüberwachung, verbundene öffentliche/interne Trades, Kommunikations-/Moderationsprozess mit Rechtsgrundlage; kein automatisches Lesen privater Chats als Default. |
| Gestohlenes Konto liquidiert Vermögen | 4 | 5 | 20 | MFA/Reauth bei sensiblen Trades/Kassenaktionen, Sitzungswiderruf, neues Gerät/hoher Wert Review, Verlust-/Restoreverfahren mit Audit. |
| Externer Echtgeldmarkt kauft Gold/Karten indirekt | 5 | 4 | 20 | Account-/Assettransferregeln, Risikosignale, Transferlimits und Enforcement; Cashoutverbot beseitigt private Außenmärkte nicht. |
| Echtgeld→Booster→Karten→Gold umgeht „kein Goldverkauf“ | 5 | 4 | 20 | Als beabsichtigten oder verbotenen Produktfluss entscheiden, Limits/Transparenz/Rechtsprüfung; technisch nicht als unmöglich ausgeben. |
| Pity-/Duplikatschutz durch Verkauf, Account-/Saisonwechsel manipuliert | 4 | 3 | 12 | Unveränderliche Erwerbshistorie und account+family-Locks; Policykontinuität. Vorher/nachher-Verkäufe und parallele Packs testen. |
| Leihkarte wird als eigene Instanz verkauft oder behalten | 4 | 4 | 16 | Kein Instanzmint aus Loan, scope/permissions und serverseitige Marketable-Prüfung; eigener Reward nötig. Alle Commandpfade einschließlich Gilde testen. |
| Gildenleiter/Support stiehlt Kasse oder minted Vermögen | 3 | 5 | 15 | Least privilege, zwei Freigaben, Kassenlimits, alle Supportactions im gleichen Ledger, unabhängige Audit-/Alarme; keine freien SQL-Saldoedits. |
| IDOR fremde Decks/Inventare/Listings oder Replay alter Tokens | 4 | 4 | 16 | Principalbindung, Objektberechtigung pro Command/Query, kurze Sessions/Rotation/Reauth und Request-Raten; Idempotenz ersetzt Authentisierung nicht. |
| Policy-/RNG-Manipulation oder erratbare Zufallsfolge | 3 | 5 | 15 | Signierte versionierte Policies, Changeapproval, Server-CSPRNG ohne Clientseed, Secret-/Keyrotation; deterministischer JS-LCG nur Testoracle, nicht Live-Drops. |
| Raum-/Zeitrollback setzt verbrauchten Reward zurück | 3 | 5 | 15 | Kampfzustand strikt getrennt vom Wirtschaftsledger, unveränderliche source-ID; beliebige Combat-Rewindfolgen ohne Neugrant. |
| Inflation/Deflation durch misskalibrierte Quoten/Fees | 4 | 4 | 16 | Simulationsökonomie/Monitoring, kontrollierte Konfigurationsänderung, Caps und Kill-Switches; keine ad-hoc Guthabenlöschung. |

## Trust Boundaries und Betrieb

TLS schützt Transport, nicht vor einem vom Nutzer kontrollierten Client. Server prüft Tokens und Objektberechtigung, DB erzwingt Eindeutigkeit/Atomizität. Externe Providerereignisse erst nach Signatur-/Serverprüfung vertrauen. Analyse-/Lesecaches besitzen keinen Rückschreibpfad. Produktions-/Sandboxdatenbanken, Credentials und IDs strikt getrennt; Snapshotimport als Angriff behandeln.

Auditrecords: actor/pseudonymous principal, operation/business-ID, cause, Policyrevision, before/after-Versionen und vermögensrelevante Deltas. Kein Passwort, Receiptgeheimnis, Volltoken oder unnötiger Personenbezug in Logs. Append-only innerhalb Anwendung, separate restriktive Archivierung/Integritätssicherung; privilegierter DB-/Backupzugriff bleibt Restrisiko. Aufbewahrung und Löschkonzept mit Datenschutz abstimmen.

Missbrauchsreaktion: proportionale Drosselung/Step-up/Quarantäne, nachvollziehbare Gründe, Review/Beschwerde und begrenzte Supportrechte. Geräte-/Netzsignale sind Risikosignale, keine eindeutige Personenidentität. Erkennungsmesswerte inkl. False Positives und Rücknahmequote überwachen.

## Sicherheitsfreigabe vor Livevermögen

Schemafuzzing, Auth-/IDOR-Tests, echte DB-Konkurrenztests, Invarianten über zufällige Commandfolgen, Providerstub mit widersprüchlichen/doppelten Meldungen, Pity-/RNG-/Policyreview, Restore-/Outbox-Replay und unabhängige Sicherheitsprüfung. Phase B–D simuliert Verhalten; nur Phase E kann tatsächliche Mehrprozess-/Datenbankgarantien belegen. Vor Phase F zusätzlich Store-Sandboxnachweise, Incidentrunbook und Fraud-/Chargebackbudget. Alle diese Nachweise stehen noch aus.
