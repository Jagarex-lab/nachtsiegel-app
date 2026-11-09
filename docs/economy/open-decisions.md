# Offene Entscheidungen und Freigabegates

Alle Empfehlungen sind Vorschläge; der Architekturauftrag erteilt keine Produkt-, Monetarisierungs-, Rechts- oder Deploymentfreigabe. Technik kann Entscheidungen abbilden, nicht Ziele wie Fairness, Länderzulässigkeit oder Chargebackhaftung eigenständig festlegen.

| ID | Entscheidung / Vorschlag | Verantwortlich | Blockiert / benötigter Nachweis |
|---|---|---|---|
| O01 | Legacy-Regeln als Ziel oder eigener Modus? Prototyp7 und Legacy100 getrennt, IDs nie per Namen mappen | Produkt + Gameplay | Spielbare Legacy-Modi/Starterwahl; Review von PR #1/#2 und Regelparität |
| O02 | Welcher vollständige Gratisstarter? Bei Legacy vorgeschlagen unveränderte START-Multimenge25 | Produkt + Balance | Tutorial-Livegrant; tatsächliche Spielbarkeit und kostenloser Abschluss |
| O03 | Gratisstarter account_bound? Empfehlung wegen Farmrisiko, aber nicht verbindlich | Produkt + Fraud | Freier Handel mit Starterkopien; Fairness/Farmmodell. Boosterdefault bleibt unbound |
| O04 | Konkrete Gratis-/Premiumprodukte, Mengen/Raten/Pity/Schutz und Saisonfamilien | Produkt + Economy | Veröffentlichte Packpolicies; Simulation, Chancenoffenlegung, F2P-Erreichbarkeit |
| O05 | Direkter Goldkauf? Empfehlung zunächst nein; paid Cards erlauben trotzdem indirekten Goldzugang | Produkt + Recht + Finance | Gold-/Marktdesign und Kommunikation; kein falsches „kein Echtgeld→Gold“ |
| O06 | Bezahlte Boosterkarten handelbar wann/wo? Defaultgrundsatz unbound, ggf. expliziter veröffentlichter Sicherheitscooldown | Produkt + Recht + Store + Fraud | **Paid-Trading-Livegate**; Ländermatrix, Chargebackbudget, Review/Appeal und Storefreigabe |
| O07 | Gutgläubige Dritte nach Chargeback: Reserve, Ersatz, Quarantäne, Haftung? | Produkt + Recht + Support + Finance | Jede Echtgeld-Handelskette; keine pauschale nachträgliche Kartenlöschung als versteckter Default |
| O08 | Gebühren, Limits, Laufzeiten/Preisgrenzen und handelbare Quellen | Economy + Fraud | Marktplatz-Livegate; Liquiditäts-/Farm-/Wash-Simulation und verständliche Quotes |
| O09 | Draft/Sealed-Leihen oder Picks behalten? Empfehlung zuerst nur Leihe, Reward separat | Produkt + Gameplay + Recht | Moduspools/Entitlements; Eintrittskosten-/Zufallsproduktprüfung falls später bezahlt |
| O10 | Ranglistenpool/Kopien/Deckgröße/Rotation und Leihnutzung | Gameplay + Balance | ModeManifest und Matchtickets; Tests der tatsächlichen Regeln statt Wirtschaftsstub |
| O11 | Gildenrollen, Eligibility, Kassenverteilung/Auflösung und private Auszahlungen | Produkt + Fraud | Gildenvermögen live; Empfehlung zunächst keine privaten Kassenentnahmen, Zwei-Personen-Freigabe |
| O12 | Raum-/Zeitmechaniken und möglicher Lorekonflikt | Gameplay + Narrative | Spezialmodus; definierte Capabilities/Topologie/Determinismus, kein Economic-Rewind |
| O13 | Backendruntime, Identityanbieter, Hosting/Regionen, Datenbankbetrieb | Backend + Security + Betrieb | Phase E; Lastmodell, Kosten, Datenschutz und Kompetenzen. PostgreSQL-Monolith ist begründeter Startvorschlag |
| O14 | Lokale DB/Pluginunterstützung für PC/Android/iOS | Clienttechnik | Phase B; Plugin-/Lizenz-/Crash-/Plattformtests, kein Scheinsicherheitsclaim |
| O15 | Zielalter, Länder, Store-/Verbraucher-/Glücksspiel-/Datenschutzprüfung | Recht + Produkt + Datenschutz | Phase F; aktuelle fachliche Beratung, keine Annahme europaweiter Zulässigkeit |
| O16 | RPO/RTO, Monitoringgrenzen, Verlust-/Fraudbudgets, Supportprozesse | Betrieb + Finance + Security | Phase E/F; Restore-/Incidenttests und messbare SLOs |
| O17 | Sandbox-/Altstand-Welcome-Konzept | Produkt + Security | Serverstart/Migration; Empfehlung keine Übernahme untrusted Werte, ggf. feste einmalige Kulanz |
| O18 | Freie Sammlungserreichbarkeit und Pay-to-win-Ziele | Produkt + Economy | Wirtschaftliche Freigabe; Zeit-/Skillkontrollierte Metriken und öffentliche Produktversprechen |
| O19 | Aufbewahrung/Löschung von Ledger-, Kauf-, Fraud- und Auditdaten | Recht + Datenschutz + Security | Phase E/F; pseudonymes Audit, eingeschränkter Personenbezug, Rechtsgrundlagen und Löschkonzept |
| O20 | Kommerzielle Rechte an Legacycode, Karten und Assets | Rechteinhaber + Recht | Kommerzielle Produktfreigabe; keine LICENSE im fixierten Legacy-Stand als bloße Herkunftslücke dokumentiert |

## Vorschläge, die ohne Monetarisierungsentscheidung tragfähig sind

Definition/Instanz/Entitlement trennen; versionierte Contracts; keine Clientautorität; eine ACID-Grenze; Integerledger; idempotente fachliche Sources; echte Escrowlocks; kostenloser vollständiger Starter; klare Sandboxtrennung. Diese Entscheidungen ermöglichen die Offlinephasen, **ohne** bezahlte Produkte oder die konkrete Handelsökonomie vorwegzunehmen.

## Abbruch- und Neureviewkriterien

Neue Echtgeld-/Goldpfade, frei transferierbare Leihrechte, Gildenauszahlungen, bezahlte exklusive Stärke, dynamische personalisierte Dropraten, Änderung vorhandener Packgarantien oder unmittelbare Übernahme lokaler Spielstände erfordern neue Entscheidung. Bei ungelöster Duplikation/negativen Nutzerkonten/fehlender Quellenverifikation oder ungeklärten Länder-/Storepflichten bleibt das jeweilige Livefeature deaktiviert. Diese Gates sind Bestandteil des **zukünftigen** Designs; in diesem Dokumentationsauftrag wird kein Dienst aktiviert oder umkonfiguriert.
