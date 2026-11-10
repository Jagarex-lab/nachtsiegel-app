# Spielmodi, Kartenpools und Zugangsrechte

Keiner der zusätzlichen Online-Modi ist implementiert. Bestehendes Tutorial/Kampagne/Quick-Duell bleiben lokale Prototypfunktionen. Folgender ModeManifest-Vertrag ermöglicht spätere Erweiterung ohne ökonomische Spezialfälle in Kartenwerten.

## ModeManifest (ergänzender Entwurf)

Immutable Schlüssel `mode_id + revision`, Ruleset-/Capabilityrevision, Poolmanifest, Deckpolicy, erlaubte Zugangsquellen, Instanz-/Leihnutzung, Rewardpolicy, Admission-/Matchtimeout und Mindestclientversion. Katalogstatus oder Seltenheit allein entscheidet keine Moduslegalität. Server validiert bei Deckspeicherung unverbindlich und bei MatchTicket erneut verbindlich.

```json
{"schema_version":1,"mode_id":"classic-legacy","revision":1,"ruleset_ref":"legacy-v1-proposed","topology":{"lanes_per_side":5},"pool_ref":"legacy-test@1","deck_policy":{"min_size":20,"max_size":25,"max_copies":3,"legendary_max_copies":1},"ownership":{"allow_permanent":true,"allow_scoped_loans":false},"access":{"required_entitlement":null},"reward_policy_ref":"verified-classic@1","capabilities":["legacy-base"],"status":"draft"}
```

Diese Deckwerte spiegeln nur den historischen Validator wider. Auswahl für ein neues Produkt und vollständige Legacy-Kampfumsetzung sind offen. Ein Ranglistenformat mit fix25 ist eine gesonderte vorgeschlagene Modusrevision, keine Änderung bestehender Regeln.

| Modus | Kartenpool / Deckvalidierung | Teilnahme und Besitz | Rewardvertrag |
|---|---|---|---|
| Tutorial | Fixiertes vollständiges Starterbundle, geführte Regeln, keine Marktanforderung | Frei, kein Kauf; Leihstarter zum Lernen möglich bis atomarer dauerhafter Abschlussvergabe | Einmal pro Konto/Version bewusst festgelegter Erstabschluss; kompletter Starter ohne Zufall, kein wiederholtes Farming |
| Klassische Duelle | Freigegebener Constructed-Pool, versionierte Größe/Kopienregeln | Dauerbesitz; optional ausdrücklich zugelassene zeitliche Leihformate getrennt | Nur verifizierter Matchdienst, begrenzte Spielbelohnungen, keine Client-Siegprämien |
| Rangliste | Saison-/Banlistrevision und gleicher Rulesetstand für beide; vorgeschlagen fix25 | Verifizierter Account/Zugang, nur zulässige Karten; Freeze am Matchstart | Einmalige Match-/Saisonquellen; Ratingserver separat, Anti-Collusion und Caps |
| Draft | Serverseitig vorab erzeugte Draftsession/Picks; Deck aus dem eigenen Pickpool, keine freien Inventareinschübe | Ereignisberechtigung; erste Variante ausschließlich sessiongebundene Leihkarten | Teilnahme/Erfolg nach verifiziertem Abschluss; Behalten der Picks nur über ausdrücklich separaten Reward, nicht automatisch |
| Sealed | Sessionpool aus eigener serverseitiger versiegelter Zuteilung, Matchlegalität nur daraus | Zeitlich begrenzter Eventzugang und scoped card_loan | Getrennte Ergebnisrewards; Pool selbst kein Handelsvermögen |
| Zeitliche Events | Eventpool, UTC-Zeitraum, spezielle Deckpolicy/Caps | Event-Entitlement oder freie serverseitige Eligibility; Leihrechte optional | Pro Event/Periode; kein Claim nach bloßem Gerätezeitwechsel |
| Gildenkämpfe | Manifest + Gildenkader-/Roster-Snapshot, Pool-/Deckprüfung je Teilnehmer | Mitgliedschaft und Eligibility zum festgelegten Cutoff, kein Leader-Cashout | Gildenkasse und/oder Einzelreward getrennt, Unique(guild,event) und Unique(member,event) |
| Raum-Zeit-Spezialmodi | Separates experimentelles Ruleset, Capabilitywhitelist, Basistopologie weiterhin fünf Pfade | Freie oder zeitlich freigeschaltete Tests; Leihpool verhindert fehlende Sammlung als Testbarriere | Erst Sandbox; Live-Rewards erst nach deterministischen Regel-/Servernachweisen und Missbrauchsprüfung |

## Rechte sind nicht gleichbedeutend

| Recht | Speicherung | Bedeutung |
|---|---|---|
| Dauerhafte Modusfreischaltung | Entitlement kind=mode_unlock, expires_at=null | Zugang zum Modus, nicht Besitz seiner Karten |
| Zeitlicher Eventzugang | kind=event_access, UTC-Fenster | Darf in Zeitraum ein gültiges Ticket erzeugen |
| Temporäre Kartennutzung | kind=card_loan, Scope Mode/Session/Pool, permission play | Kein Asset, nicht listen/verkaufen/verwerten/gildenintern übertragen |
| Dauerhafte Karte als Eventreward | Neue CardInstance aus eigenem einmaligem Reward | Eigene UUID/Provenienz/Bindung; kein Umflaggen des Leihrechts |

Entitlement darf nicht mit `owned[count]` zusammengeführt und als handelbarer Bestand exportiert werden. Für Deckprüfung entstehen zwei explizite Quellen `owned_instances` und `loan_allowances`; Berechtigungsschnittmenge mit Modus bildet `usable_count`. Ein globales `owned=null` ist nur für bewusst kontrollierte Test-/Leihvalidierung zulässig, nicht als Umgehung der Livebesitzprüfung.

## MatchTicket und unveränderlicher Matchsnapshot

Server prüft Mode-/Poolrevision, Deckgröße/Kopienlimits, Accountstatus, Zugangszeit, Entitlements und konkrete Instanzverfügbarkeit. Für kompetitive Livepartien benötigte eigene Instanzen reservieren; Tickets sind kurz gültig, account-/modegebunden und nur einmal konsumierbar. Karte während aktiver Reservation weder handeln noch verwerten. Deckänderung später beeinflusst Matchsnapshot nicht.

Leihrecht muss bei Ticket-/Matchbeginn gültig sein; danach bis autoritativem Ende dieses Matches nutzbar, keine neuen Matches nach Ablauf. Match-/Reservationtimeout wird vom Server nach Ergebnis-/Abbruchregel beendet, nicht vom Client. Verkauf/Verwertung und Matchstart konkurrieren unter derselben Reservation-/DB-Sperre. Ein verlorener Clientkontakt ist kein automatischer Gewinn und kein zweimaliger Reward. MatchTicket und Ergebnis-ID bleiben für Idempotenz nachvollziehbar.

## Raum-/Zeit-Erweiterungen ohne Wirtschaftsrewind

Es gibt noch keine festgelegte Fähigkeit oder Implementierung. Vorgeschlagene technische Grenzen: deterministische Command-/Eventqueue, begrenzte Zusatzaktionen, explizite Ziel-/Zeitfenster, maximaler Kettenumfang, kanonischer Snapshot samt RNG-Zustand/Rulesetversion. Moduspool enthält nur vollständig serverseitig ausführbare Effekte; Capability unbekannt → Eintritt ablehnen.

Eine künftige Rücknahme einer Kampfaktion ist ein neues **Kampfereignis** mit Regeln, keine Datenbankwiederherstellung. Käufe, Dropentscheidungen, Belohnungsquellen, verbrauchte Tickets, Ledger und Handelsescrows werden niemals zurückgesetzt. Abgebrochene/rewound Matches liefern höchstens einen nach Abschlussregel gültigen Reward. Lorekonflikt zur unveränderbaren Vergangenheit bleibt Produkt-/Narrativentscheidung; hier keine neuen Storybehauptungen.

Abnahme später: identische Matchsnapshots auf Server/Client, keine Leihkartenübertragung über Market/Salvage/Gilde, Ablauf während Match versus danach, Verkauf beim Matchstart, Slot-/Time-Manipulation ohne zusätzliche Rewards, zwei Geräte mit demselben Ticket und Moduswechsel mit ungültigem Pool.
