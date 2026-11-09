# Wirtschaftliche Risiken, Simulation und rechtliche Prüfbedarfe

Kein beschlossenes Geschäftsmodell oder juristisches Gutachten. Alle Risiken betreffen eine zukünftige Kombination aus F2P, Zufallsboostern und handelbaren Karten. Es werden keine Erträge, Preisstabilität, bestimmte Behördeneinordnung oder Storezulassung zugesichert.

## Bestände und Flüsse getrennt bilanzieren

Für eine Periode: Goldbestand am Periodenende = Anfang + autorisierte Goldrewards − endgültige Goldsinks. Handel zwischen Nutzern verändert den Gesamtbestand nicht; Handelsgebühren verringern den Nutzerumlauf, nicht die Double-Entry-Gesamtsumme einschließlich Systemkonten. Reserviertes Gold bleibt Bestand, aber ist vorübergehend nicht verfügbar. Bezahlte Karten erzeugen **nicht automatisch neues Gold**: Sie lassen Käufergeld in bestehendes Gold anderer Spieler umtauschen und ändern Verteilung/Nachfrage.

Handelbare Karten je Typ = Anfang + freie/bezahlte ungebundene Mints + explizite Rewards − Verwertung/definierte endgültige Entzüge. Bindung/Quarantäne/Matchlock verringert Verfügbarkeit, löscht aber keinen Besitz. Leihrechte zählen nicht als Kartensupply. Für Analysen erworbene, umlaufende, verfügbare und jemals besessene Kopien getrennt halten.

| Risiko | Mechanismus | Technische/Produktantwort und Messung |
|---|---|---|
| Echtgeld→Gold indirekt | Gekaufte Booster erzeugen handelbare Karten, Verkauf bringt Gold; größerer Echtgeldaufwand verbessert Kaufkraft | Fluss offen benennen, Herkunft auditieren, Limits/Reifung/Review; kein falsches „keine Echtgeldkonvertierung“. Paid-Trading-Gate vor Verkauf. |
| Pay-to-win | Zugang zu mehr Karten/Gold beschleunigt Deckstärke, auch wenn gleiche Einzelkarte gleiche Werte hat | Voller Gratisstarter und erreichbare kostenlose Booster; kompetitives Leih-/Draftformat erwägen; Zeit bis konkurrenzfähiges Deck und Winrate bei Skill-/Zeitkontrolle messen. „Keine Premiumwerte“ allein reicht nicht. |
| Goldinflation | Zu viele belohnte Konten, Farmen oder Quoten im Verhältnis zu Sinks | Quoten am verifizierten Ursprung, robuste Aktivitäts-/Farmmetriken, modellierte Goldsinks; Geldmenge/proaktivem Nutzer und Preisindex überwachen. Keine geheime Saldenentwertung. |
| Golddeflation | Gebühren/Sinks größer als Belohnungszufluss, inaktiver Goldbestand, neue Spieler ohne Kaufkraft | Umlauf/Reserven/Verteilung getrennt; verfügbare Gratis-Goldquellen und Gebühren simulieren. Nicht automatisch „mehr Booster“ minten: das behebt Goldmangel nicht. |
| Kartendeflation | Viele bezahlte Packs erhöhen Supply häufiger Karten, Duplikate verdrängen F2P-Erträge | Seltenheits-/Poolmix, freiwillige Salvagesinks und gratis Erreichbarkeit simulieren; keine garantierten Wiederverkaufswerte versprechen. |
| Knappheit/Cornering | Kleiner Pool, Rotations-/Bannews, konzentrierte Holdings | Breiter Zugang, Konzentrationsmetriken, transparente Revisionen, Handelslimits/Preisreferenzen; Balancekommunikation darf Insiderhandel nicht begünstigen. |
| Wash Trading/Kartelle | Eigenhandel setzt scheinbare Marktpreise und Volumen | Keine volumenbasierten Rewards, robustes Referenzpricing, Kreis-/Gegenparteigraph, Gebühren. Gebühren beseitigen nicht jeden profitablen Manipulationsanreiz. |
| Farming-Schleife | Gratispack + garantierte Rarität + Pity + Duplikatschutz + Salvage finanziert weitere Freipacks | Erwerbshistorie, nichtaktueller Besitz; Quoten/Caps; geschlossene Kreisläufe und optimale Botstrategie modellieren, nicht nur Durchschnittsspieler. |
| Chargeback-Arbitrage | Zahlung zurückgezogen, Karten/Gold schon weitergereicht | Herkunftsgraph, Reserven/Review/konfigurierte Haltefrist; Investor-/Buyerclaims nicht durch pauschales Löschen Dritter lösen. Verlust-/Ersatzbudget und Freezeverfahren beschließen. |
| Externer Echtgeldmarkt | Nicht auszahlbares Gold wird privat gegen Geld oder Accountzugang übertragen | Betriebsregeln/Erkennung/Enforcement; legal/Store-Einordnung berücksichtigen, Risiko nicht mit Cashoutverbot für erledigt erklären. |
| Gilden als Waschpfad | Spenden/Discounts/Leaderentnahmen umgehen öffentliche Gebühren oder Caps | Gleicher Ledger/Marketpfad, separate Principalbudgets, zunächst keine privaten Auszahlungen; verbundene Graphanalyse. |
| Saison-/Policyrisiko | Rate-/Poolwechsel entwertet bereits bezahlte Erwartungen | Packpolicy pinnen, Pityfamilie festlegen, transparente Übergangsregeln; keine rückwirkende heimliche Umschreibung. |

## Wahrscheinlichkeiten und Fairnessnachweise

In der **Testpolicy** aus [booster-rules.md](booster-rules.md) ohne Pityzustand betragen die Legendärchancen der drei Slots1%,1%,3⅓%. Mindestens eine Legendäre: `1 − 0,99² × 29/30 = 5,257%`. Das ist keine beschlossene Dropchance; mit Pity verändern sich bedingte und langfristige Raten. Der erwartete Kartenwert hängt vom Markt ab und ist keine feste Auszahlung.

Simulationen sollen denselben veröffentlichten Policyalgorithmus benutzen. Szenarien: ausschließlich kostenlos, moderater/viel Kauf, starke Farmer, geringe Marktliquidität, Saisonrotation, Preisabsprachen, Chargebackwelle und halbierte aktive Nutzerzahl. Parameter/Seeds/Versionen dokumentieren, Verteilungen statt nur Mittelwerte: Median/P90/P99 Sammlungsvollständigkeit, F2P-Zeit bis konkurrenzfähige Auswahl, Konzentration von Gold/Karten, Handelsquote, Quellen/Sinks pro realer Aktivität, Marktspread/-tiefe, Retention-/Kaufdruckindikatoren und Schaden je Fraudtyp.

Abnahme nicht durch „Spieler kaufen genug“: kostenlose Erreichbarkeit, stabile Invarianten, vertretbare Konzentration/Verlustbudgets und transparente Regeländerungen als eigene Produktziele. Zielwerte, Beobachtungszeiträume und Stopkriterien sind noch zu beschließen. Eine statistisch korrekte Ziehung kann wirtschaftlich unfair oder rechtlich problematisch bleiben.

## Rechtliche und Plattform-Prüfliste vor Phase F

Offizielle Ausgangspunkte, **keine in diesem Auftrag durchgeführte umfassende Länder-/Aktualitätsrecherche**:

- [EU-Verbraucherrechte-Richtlinie 2011/83/EU](https://eur-lex.europa.eu/eli/dir/2011/83/oj): Informationspflichten, digitale Inhalte, Vertrags-/Widerrufs-/Erstattungsabläufe und ausdrückliche Zustimmungen im konkreten Vertrieb prüfen.
- [Richtlinie über unlautere Geschäftspraktiken 2005/29/EG](https://eur-lex.europa.eu/eli/dir/2005/29/oj): transparente Zufallschancen/Preise, Rabatte, künstliche Verknappung und Kaufansprache Minderjähriger überprüfen.
- [Digitale-Inhalte-Richtlinie 2019/770](https://eur-lex.europa.eu/eli/dir/2019/770/oj): Leistungsbeschreibung, Änderungen, Mängel-/Abhilferechte; Definitionen/Poolrevisionen und nachträgliche Entzüge juristisch abklären.
- [DSGVO](https://eur-lex.europa.eu/eli/reg/2016/679/oj): Account-/Fraudgraphen, Alters-/Gerätesignale, Rechtsgrundlage, Datenminimierung, Minderjährigendaten, automatisierte Entscheidungen, Aufbewahrung und Betroffenenrechte. Append-only nicht als Ausnahme von Datenschutz verstehen.
- [Digital Services Act](https://eur-lex.europa.eu/eli/reg/2022/2065/oj): Anwendbarkeit auf konkrete Plattform-/Marktplatz-/Moderationsfunktionen prüfen, nicht pauschal voraussetzen.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) und [Google Play Developer Policy](https://play.google.com/about/developer-content-policy/): aktuelle Vorgaben zu digitalen Gütern, Zahlwegen, Zufallsgegenständen/Chancenoffenlegung, Minderjährigen und handelbaren Gütern pro Region prüfen. Regionale Ausnahmen nicht ohne Rechts-/Storeprüfung nutzen.

Länderspezifisch prüfen: Einordnung bezahlter Zufallsbooster **mit handelbaren Karten und möglicher externer Verwertung**, nationale Glücksspiel-/Jugendschutzregeln, Altersverifikation/Elterneinwilligung, Limits und Länderbeschränkungen. Nicht auszahlbares Betreiber-Gold ist kein Beweis, dass keine relevante Gewinn-/Wertkomponente existiert. Auch reine Gratis-/Eventsysteme getrennt prüfen; keine pauschale Europaweit-Zulässigkeit behaupten.

Zusätzlich klären: Steuer-/Umsatz-/Belegpflichten, Rückerstattung und Chargebackhaftung, Plattformrolle beim Nutzerhandel, Nutzungs-/Handelsbedingungen, Moderation/Beschwerden und Beweisdaten. Spielledger ist kein Ersatz für buchhalterische Echtgeldabrechnung. Karten-/Code-/Assetrechte vor kommerziellem Betrieb klären; die Herkunft aus Legacy-Repository allein beweist keine Lizenzfreigabe.

Verantwortlich: qualifizierte Rechtsberatung je Zielmarkt, Produkt-/Finance-/Datenschutzverantwortliche und Storefreigabe. Bis zu diesen Entscheidungen keine Live-Geldprodukte/paid tradable Economy einschalten. Dieser Entwurf trifft keine abschließende Rechtsbewertung.
