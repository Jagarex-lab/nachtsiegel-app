# Monetarisierung: Annahmen, Kennzahlen und Aussagegrenzen

Stand: 10. November 2026. Dieses Dokument ergänzt die lokale Wirtschaftssimulation um eine unabhängige Prüfung kommerzieller Annahmen. **Szenarien sind keine Umsatzprognose, keine Preisfreigabe und kein Nachweis wirtschaftlicher Tragfähigkeit.** Die Implementierung enthält weiterhin keine Echtgeldkäufe. Alle Geldbeträge eines Rechenmodells sind hypothetische Eingaben; Goldpreise und zusätzliche Simulationsbooster legen keinen Wechselkurs oder Verkaufspreis fest.

## Drei getrennte Aussagen

| Aussage | Was eine Simulation belegen kann | Was zusätzliche Evidenz braucht |
|---|---|---|
| Sammlungszugang | Unter festgelegten Aktivitäten, Quellen, Senken und Zufallsregeln entsteht ein bestimmter Besitzpfad. | Reale Spielzeiten, Aufgabenerfüllung, fehlende Spieltage und finale Kartendaten. |
| Wettbewerb | Ressourcen für benannte Upgradepakete sind bis zu einem Zeitpunkt verfügbar. | Vollständige legale Decks, stärkere seltene Fähigkeiten, Matchups, Können und gemessene Gewinnraten. |
| Kommerzieller Betrieb | Eine angenommene Nutzer-/Kaufstruktur deckt angenommene Kosten oder verfehlt sie. | Tatsächliche Nachfrage, Zahlungsbereitschaft, Konversion, Retention, Plattformmix und Produktions-/Betriebskosten. |

Höhere Seltenheiten dürfen nach dem Auftrag bewusst stärkere Fähigkeiten besitzen. Eine gezielte kostenlose Legende oder ein zu 100% verfügbarer Ressourcenwarenkorb beweist deshalb keine kompetitive Parität. Das ist eine zentrale kommerzielle Abhängigkeit: Ein Modell kann kurzfristig Kaufdruck und Umsatz annehmen, während derselbe Vorteil später Vertrauen und Bindung schwächt. Diese Wirkung ist ohne Spielerdaten unbekannt; sie darf weder mit einem erfundenen positiven noch negativen Effekt als gemessen ausgegeben werden.

## Konkreter Analysevertrag

`data/economy/analysis/monetization.json` ist eine getrennte **Analysekonfiguration**. Ihre Modelle `baseline96`, `scarcity`, `protected_weekly` und `cosmetics_first` aktivieren keine Shopfunktion und ändern keine Runtime-Belohnungen. Der Name `protected_weekly` bezeichnet eine Szenariovariante; die Zielgrant-Meilensteine sind einmalige dauerhafte Matchzählerschritte ohne Wochenablauf.

Die kommerzielle Rechnung betrachtet eine Einstiegskohorte von 10.000 Konten über 24 Modellmonate ohne neue oder ersetzende Zugänge. Die beispielhafte Zurechnung laufender Fixkosten zu dieser Kohorte ist eine Kostensensitivität, keine Simulation eines wachsenden Unternehmens. Drei externe Retentions-/Kaufszenarien bleiben von den vier Wirtschaftsalternativen getrennt. Gleiche Retention im kontrollierten Vergleich verhindert, dass eine Alternative ohne Evidenz einen Bindungsbonus erhält.

Die fünf Kaufkörbe sind disjunkte Gruppen; Produktüberschneidungen liegen innerhalb des jeweiligen Korbs. Sammlungsnutzen beeinflusst nur eine als Hypothese gesetzte zusätzliche Kaufwahrscheinlichkeit für Booster. Kosmetik-/Passinteresse wird gesondert angenommen. Keine dieser Eingaben ist beobachtetes Kundenverhalten. Der Sensitivitätsfall mit geringerer Bindung durch Knappheit bleibt ebenfalls eine Vermutung.

Die Beispieldaten bezeichnen Ausgaben vor Gebühren und Rückerstattungen. Ihr Hinweis auf steuerexklusive Beträge und der Steuerparameter0 sind eine **explizite steuerliche Auslassung**, keine Feststellung steuerfreier Verkäufe. Der verwendete Aktivitätspfad und dessen Verknüpfung mit der Sammlung müssen im Ergebnisbericht offengelegt werden: Eine an allen Kalendertagen spielende Sammlungskurve passt nicht ohne Annahme zu sechs bis 14 Spieltagen je gebundenem Monat.

Der ausführbare Erlösansatz in `tools/economy/monetization_revenue.py` beginnt am angenommenen ersten Rückkehrtag 1 nach Akquisition. Er erhebt keine Day-1-Retention aus Telemetrie; Aktivität und mögliche Käufe am Akquisitionstag 0 sind nicht enthalten. Monatsmitglieder haben im Modell eine garantierte Aktivität am Monatsanfang. Das ist eine definierte absorbierende Überlebens-/Aktivitätsannahme, keine allgemeine MAU-Schätzung bei Rückkehrern.

Der Nachfrageanschluss verwendet die täglich aktive `paid4`-Sammlungskurve im selben Kalenderalter. Er bildet die langsamere Inventarentwicklung bei sechs/zehn/14 Spieltagen je Monat und Rückwirkungen tatsächlich getätigter Käufe nicht individuell nach. Diese bewusst stärker gesättigte Näherung kann Nachfrage zu früh abschwächen; sie darf nicht als vollständig gekoppelte Kundenverhaltenssimulation beschrieben werden.

Der konkrete `unsaturation_factor` verwendet zusätzliche **einzigartige IDs** eines Boosters und den noch nicht aus normaler Essenz bezahlbaren einzigartigen Fehlbestand. Bei vollständigen einzigartigen IDs wird er 0, selbst wenn spielbare Kopien fehlen. Zusätzliche Kopien, Essenz für spätere Erweiterungen und subjektiver Sammlerwert gehen nicht in diese Nachfrageformel ein. Das ist eine konservative strukturelle Näherung, keine Messung des gesamten Boosternutzens. Sie betrifft nur Booster; Kosmetik- und Passumsatz bleiben weitere unabhängige Hypothesen.

## Sammlungssättigung und Kaufanreiz

Im bisherigen Einjahresmodell bleiben alle simulierten Spieler täglich aktiv. Das Balanced-Modell erreicht bei Profil B im Mittel 99,8% einzigartige Karten nach 365 Tagen; das ist **nicht** dasselbe wie ein vollständiger spielbarer Kopiensatz. Das Modell stellt nach Fertigstellung eines Zielpakets keine weiteren Sammlungskarten her. Gleichzeitig entstehen große Herstellungsbestände. Ein anderes Craftingziel verändert sowohl den Kopienfortschritt als auch den späteren Ressourcenvorrat.

Daraus folgt ein zu prüfender Zielkonflikt, keine geschätzte Kaufquote:

- Früher Zugriff auf konkurrenzfähige Karten verbessert den kostenlosen Einstieg. Eine hohe Konversion kann daraus nicht automatisch abgeleitet werden.
- Nahezu vollständige Sammlungen und große Vorräte verringern den zusätzlichen Sammlungsnutzen weiterer Booster. Konstante angenommene Boosterumsätze über diesen Punkt hinaus sind ein **exogenes Budget-/Stressszenario**, kein nachgewiesenes Nachfrageverhalten.
- Erweiterungen schaffen neue Ziele, aber vorhandene Essenz und Gold bleiben Kaufkraft. Bestände dürfen für ein günstigeres Ergebnis weder still zurückgesetzt noch nachträglich wertlos gemacht werden. Vorab definierte Senken/Setregeln müssen gesondert auf Fairness geprüft werden.
- Ein Modell mit sofort vollständig besessener Sammlung misst Nachfrage nach Sammlungsbeschleunigung kaum noch. Es eignet sich als Sättigungsgrenze oder Kostensensitivität, nicht als Beleg für Boosterattraktivität.
- Kosmetik kann eine zusätzliche Einnahmehypothese sein. Sie benötigt eigene Nachfrage-, Produktions- und Nutzungsannahmen; fehlende Kartennachfrage darf nicht ohne Evidenz durch garantierte Kosmetikkäufe ersetzt werden.

Mehrjahresberichte müssen daher getrennt ausweisen: einzigartige Karten, vollständige Playsets, Zieldeckzugang, freie Herstellungsressource, Goldvorrat und Erweiterungskarten. Ein sinkender Prozentsatz nach einer Erweiterung kann allein durch den größeren Nenner entstehen; er belegt keinen Besitzverlust. Die Versorgung eines bereits aufgebauten Kontos darf nicht mit dem Einstieg eines neuen Spielers im selben Kalenderjahr gleichgesetzt werden.

## Kohorten, Aktivität und Retention

Eine Kohorte enthält Spieler mit demselben Einstiegszeitraum. Alter seit Einstieg und Kalendermonat sind getrennte Größen. Für jeden Monat werden alte Kohorten fortgeschrieben und tatsächlich neue Zugänge separat hinzugefügt. Eine anfängliche Nutzerzahl wird nicht jeden Monat erneut als Neukohorte eingebucht.

Die Bedeutung der Retentioneingabe muss eindeutig sein:

| Eingabe | Bedeutung | Keine zulässige Gleichsetzung |
|---|---|---|
| Überlebenswahrscheinlichkeit `S(a)` | Konto ist im Kohortenalter `a` noch nicht dauerhaft abgewandert. | Kein gemessener monatlicher Besuch ohne zusätzliche Aktivitätsannahme. |
| Periodenretention | Anteil einer Einstiegskohorte, der im bezeichneten Zeitraum aktiv ist. | Keine stetige Überlebenskurve, sofern Rückkehrer möglich sind. |
| Spieltagswahrscheinlichkeit | Wahrscheinlichkeit eines Spieltags bei noch gebundenem Konto. | Kein vollständiger täglicher Fortschritt an allen Kalendertagen. |
| MAU | Unterschiedliche Konten mit mindestens einer Aktivität im Kalendermonat. | Weder Summe der täglichen Aktiven noch ein einzelner Tagesbestand. |

Bei explizit einmaligem dauerhaftem Churn ohne Rückkehr sind überlebende Konten eine zulässige Modellvereinfachung. Die Ausgabe muss dies benennen. Bei zufälligen Spieltagen ist für MAU die Wahrscheinlichkeit mindestens einer Monatsaktivität zu verwenden; bei unabhängig angenommenem täglichem `p` und 30 lebenden Tagen wäre sie `1−(1−p)^30`. Reale Spieltage sind häufig korreliert; dieser Ausdruck ist keine empirische Retentionkurve.

Fehlende Spieltage müssen denselben Aktivitätenpfad in Sammlung und Einnahmen beeinflussen. Keine Gold-/XP-/Questvergaben an Nichtspielern, keine automatisch vollendeten Wochenaufgaben nach einer Spielpause. Kampagnenbelohnungen benötigen eine begründete Verschiebung auf tatsächliche Teilnahme. Falls die kommerzielle Rechnung nur externe MAU annimmt und das Sammlungsmodell täglich aktive Idealprofile verwendet, bleibt diese **fehlende Kopplung eine ausdrücklich benannte Grenze**.

## Kaufsegmente und ARPPU

Kaufneigung und Kaufbetrag sind getrennte Eingaben. Ein Spielerkonto kann in einem Monat Karten und Kosmetik kaufen. Die Umsatzströme dürfen addiert werden; die Käufer werden dabei nicht doppelt gezählt.

Für eine korrekte Berechnung gibt es beispielsweise die disjunkten Segmente `kein Kauf`, `nur Karten`, `nur Kosmetik`, `beides`. Alternativ wird die Überschneidung ausdrücklich vorgegeben. Bei lediglich angenommener Unabhängigkeit gilt für den Anteil aller Käufer `p(Karten)+p(Kosmetik)−p(Karten)×p(Kosmetik)`; die Unabhängigkeit selbst bleibt eine Hypothese.

- **Käuferquote:** unterschiedliche zahlende Konten der Periode / unterschiedliche aktive Konten derselben Periode.
- **Brutto-ARPPU:** Bruttoumsatz der Periode / unterschiedliche zahlende Konten derselben Periode.
- **Netto-ARPPU:** ausdrücklich bezeichnete Nettoerlöse / dieselben unterschiedlichen zahlenden Konten. Er darf nicht als Bruttozahl beschriftet werden.
- **ARPU:** Umsatz / alle aktiven Konten. Das ist eine andere Kennzahl.

Ein vorgegebener Monatsbetrag pro Käufer ist eine Eingabe, keine aus der Economy berechnete ARPPU-Evidenz. Einmalige Starterkäufe, wiederkehrende Monatsausgaben und unregelmäßige Käufe sind getrennte Zeitpfade. Die Annahme, jeder frühere Käufer zahle in jedem Folgemonat erneut, braucht eine eigene Käuferpersistenz. Kleine Vielzahlergruppen erfordern Verteilungs-/Konzentrationssensitivität; ihr Mittelwert darf nicht als typischer Spielerbetrag beschrieben werden.

## Erlöse, Kosten und Deckungsbeitrag

Jeder Geldbericht braucht Einheit, Zeitraum und Brutto-/Nettoabgrenzung. Umsatzsteuer, Plattform-/Zahlungsgebühren, Rückerstattungen und Chargebacks dürfen weder ausgelassen noch doppelt abgezogen werden. Als Modellvereinfachung gemeinsam verwendete Erlösabschläge sind so zu beschriften; sie ersetzen keine spätere Plattformabrechnung.

Eine nachvollziehbare Rechnung lautet beispielsweise:

`hypothetische Bruttozahlungen − indirekte Steuern − Rückerstattungen/Chargebacks − Plattform-/Zahlungsgebühren = Nettoerlös`

`Nettoerlös − variable Betriebskosten − laufende Content-/Team-/Supportkosten − Nutzergewinnungskosten = operatives Modellergebnis`

Die genaue Bemessungsbasis der Gebühren muss festgelegt werden. Umsatz/Deckungsbeitrag/operatives Ergebnis sind verschiedene Größen. Ein positives Monatsergebnis beweist weder kumulierten Cash-Break-even noch die Amortisation vorangegangener Entwicklung. Keine doppelte Verbuchung derselben Teamkosten zugleich als laufende Kosten und nochmals als monatlicher Teil der Anfangsinvestition.

Mindestens zu variieren sind:

- Server, Datenbank, Monitoring, Backups, Netzwerk und Sicherheitsbetrieb nach tatsächlicher Aktivität; inklusive späterer autoritativer Match-/Inventardienste.
- Kartenillustrationen, Animationen, Audio, Lokalisierung, Kartendesign, Balancearbeit, Tests und Erweiterungsproduktion.
- Livebetrieb, Community, Moderation, Kundendienst, Betrugs-/Rückerstattungsbearbeitung und plattformspezifische Pflege.
- Nutzergewinnung: organische Zugänge und bezahlte Akquisition getrennt; CAC eindeutig pro gewonnenem Konto, aktivem Nutzer oder Käufer definieren.
- Entwicklungsvorlauf, notwendige Reserven und Kostenanstieg über mehrere Jahre; Kostentreiber nicht allein nach Umsatz skalieren.

Ein LTV/CAC-Vergleich benötigt vergleichbare Definitionen und einen dokumentierten Horizont. Umsatz-LTV ohne Gebühren/Betriebskosten darf nicht als profitabler Kundenwert gegen einen vollständig berechneten Akquisitionspreis verglichen werden. Bei endlichem Horizont bleiben spätere Erlöse und Kosten unbewiesen; ein unbegrenzter Restwert ist eine zusätzliche Annahme.

## Zirkelschlüsse vermeiden

Der Rechenweg bleibt transparent:

`extern angenommene Zugänge/Bindung/Kaufneigung/Budgets → hypothetische Aktivität und Zahlungen → Erlös-/Kostenrechnung`

`konfigurierte Aktivität/Booster/Crafting/Erweiterungen → Sammlungs- und Ressourcenpfad`

Eine spätere Verhaltenskopplung, etwa geringere Kartenkäufe bei Sättigung, ist eine **Sensitivitätsannahme**, bis Telemetrie oder ein kontrollierter Versuch sie stützt. Aus einem gewünschten Umsatz darf keine erforderliche Kaufquote als erwartete Kaufquote abgeleitet werden. Ebenso wenig darf eine gewünschte Retention aus kostenlosem Kartenzugang berechnet und anschließend zur Bestätigung derselben Balance verwendet werden.

Monte-Carlo-Streuung bei festen Hypothesen zeigt Zufallsunsicherheit im Modell. Sie erfasst keine unbekannte Marktnachfrage oder falsch angesetzte Retention. Enge Konfidenzintervalle durch viele Wiederholungen machen eine unbelegte Geschäftsannahme nicht zuverlässig.

## Konkrete Entscheidungshilfe

Ergebnisse sollten pro Szenario ihren Anteil an freien Eingaben ausweisen und mindestens ungünstige Bindung, schwache Konversion, niedrigere Ausgaben, hohe Kosten, fehlende Spieltage und Sammlungssättigung prüfen. Ein Break-even-Wert ist eine **notwendige Modellschwelle**, kein prognostizierter Markterfolg. Die günstigste Variante ist keine Empfehlung ohne Vergleich ihrer Fairness-, Nachfrage- und Produktionsanforderungen.

Nächste belastbare Evidenz entsteht aus einer spielbaren, fairen Deckbasis und freiwilligen Tests: tatsächliche Besuchstage, Sitzungsdauer, Aufgabenquoten, Abbruchpunkte, wahrgenommener Kaufdruck, Interesse an Kosmetik und wiederkehrenden Erweiterungen. Kaufpreise oder eine kommerzielle Veröffentlichung werden durch diese Simulationsarbeit nicht freigegeben. Bis zu solchen Daten lautet das Ergebnis: **technisch untersuchbare Optionen und transparente Schwellen; kommerzielle Tragfähigkeit weiterhin offen.**
