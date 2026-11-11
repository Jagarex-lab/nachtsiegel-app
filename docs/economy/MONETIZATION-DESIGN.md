# Vorläufige Produktarchitektur für die Monetarisierungsanalyse

Dieses Dokument erweitert PR #16 um untersuchbare Produktentscheidungen. Es implementiert weder Shop noch Zahlungen, Saisonpass oder eine geänderte aktive Wirtschaft. Die Eingaben unter `data/economy/analysis/` gelten ausschließlich für Simulationen. Geldbeträge dort sind hypothetische Ausgabenannahmen und keine freigegebenen Verkaufspreise.

## Produkte und Kaufanreize

| Produkt | Untersuchte Motivation | Schutz des kostenlosen Wettbewerbszugangs | Offene wirtschaftliche Frage |
|---|---|---|---|
| Zusätzliche Standardbooster | Mehr Auswahl, weitere Strategien, schnellere Sammlung | Gleiche Kartenregeln, offengelegte Wahrscheinlichkeiten und Pity; gezielter kostenloser Deckpfad parallel | Wie schnell sinken neue brauchbare Funde und damit die Kaufbereitschaft? |
| Kosmetik | Ausdruck der Machtidentität, Sammelwert, Personalisierung | Ausschließlich Erscheinung; keine besseren Werte, zusätzlichen Informationen oder schlechter lesbaren Gegnerkarten | Reichen Qualitätsniveau, Vielfalt und tatsächliche Nachfrage für die Produktionskosten? |
| Einsteigerpaket | Einmaliger verständlicher Einstieg und Individualisierung | In der Umsatzsimulation kosmetisches Einmalangebot; keine exklusiven kampfstarken Karten; pro Spieler höchstens ein Kauf | Wie hoch sind die einmalige Conversion und der verdrängte Umsatz anderer Angebote? |
| Saisonpass | Planbare kosmetische Ziele und kuratierte Inhalte | Bezahlte Seite rein kosmetisch. Kostenlose Deckpfade sind separat erreichbar und nicht zahlungspflichtig | Welche Abschlussquote, Wiederkaufrate und Inhaltskosten sind realistisch? |

Ein Booster mit überwiegend überzähligen Karten verliert seinen Nutzen für Sammler, auch wenn der nominelle Inhalt unverändert bleibt. Deshalb misst die Analyse sowohl tatsächlich neue Karten als auch durch vorhandene Essenz bereits bezahlbare fehlende Kopien. Ein hoher angezeigter Fehlbestand bei gleichzeitig ausreichender Essenz ist kein belastbarer Kaufanreiz.

Kosmetische Kandidaten sind Kartenrückseiten, Profilgestaltung, Macht-Embleme und zusätzliche visuelle Präsentationen auf dem vorhandenen Kartendesign. Lesbarkeit, Trefferflächen, Informationen, Animationstempo beim Überspringen und reduzierte Bewegung müssen gleichwertig bleiben. Diese Kandidaten sind Produktideen; neue Assets oder UI werden nicht als geliefert ausgegeben.

Einsteigerangebote werden als eigene einmalige Umsatzquelle modelliert. Ein kostenpflichtiges Paket mit Boostern oder Essenz wäre ein anderes Produkt: Seine Inhalte müssten zusätzlich in den Sammlungsläufen und im Wettbewerbsvorteil berücksichtigt werden. Es darf nicht durch einen kosmetischen Umsatzparameter als bereits fair bewertet werden.

## Saisonpass ohne täglichen Teilnahmezwang

Der bezahlte Pass soll keine exklusiven Kartenfähigkeiten, zusätzlichen Kampfinformationen, stärkeren Kartenvarianten oder wirtschaftlich notwendigen Schlüsselressourcen enthalten. Bei einer späteren Umsetzung sind Fortschritt durch normale Partien, Wochenbündel, Nachholen verpasster Aufgaben und eine klare Vorschau aller Inhalte vorzusehen. Bezahlen allein beweist keine spätere Freischaltung: Abschlussquote, Einlösung und Wiederkauf sind getrennte Größen. Die Finanzsimulation ist deshalb keine technische Passabnahme.

Vor einem Produktentscheid sollten ein nachträglich kaufbarer oder langfristig abschließbarer Pass und direkt kaufbare kosmetische Sammlungen gegen ein zeitlich begrenztes Modell getestet werden. Eine kurze künstliche Saison oder verlorene bezahlte Belohnungen dürfen nicht stillschweigend als Bindungserfolg verbucht werden. Transparente Bedingungen und freiwilliges Wiederkommen sind eigenständige Produktziele.

## Höhere Seltenheit und Stärke

Da seltenere Karten bewusst stärkere Fähigkeiten besitzen dürfen, kann die Sammlungsgeschwindigkeit einen echten Leistungsvorteil vermitteln. Die Analyse bewertet daher mindestens drei verschiedene Zugänge: eine gezielte Legende plus zwei epische Karten, ein vollständiges definiertes Upgrade sowie weitere Deckoptionen nach einem hypothetischen Metawandel. Keine dieser Ressourcenmetriken beweist mit dem synthetischen Katalog tatsächliche Matchup-Parität.

Ein geschützter kostenloser Deckpfad soll auf abgeschlossenen Partien beruhen. Er benötigt weder Kauf noch tägliche Loginserie oder absichtlich ungünstige Spielzüge. In den Alternativen werden die betreffenden kostenlosen Ressourcen genau einmal in das Budget eingerechnet; sie sind kein zusätzlicher unsichtbarer Bonus aus einem kostenpflichtigen Pass. Der Schutz einer einzigen Strategie reicht bei häufig wechselnder Meta nicht aus. Ein späteres Produkt muss einen überprüfbaren Zugang zu neuen Schlüssel- und Gegenkarten erhalten.

## Entscheidung vor Aktivierung

Eine Empfehlung aus dieser Analyse bleibt bedingt. Vor Aktivierung sind mindestens erforderlich:

- Gemessener kostenloser Zugang zu tatsächlich konkurrenzfähigen Decks mit stabilen Karten und Matchups; gesonderte Prüfung der stärkeren hohen Seltenheiten.
- Beobachtete Retention, Kaufquote, Ausgabenverteilung, Passabschluss und Nachfrage nach Kosmetik mit freiwilligen Spieltests; Simulationseingaben ersetzen diese Daten nicht.
- Kostenplan für Karten-/Kosmetikproduktion, Audio, Technik, Server, Kundendienst, Betrugsbearbeitung, Livebetrieb und Kundengewinnung.
- Belastbare Erlösabrechnung nach Erstattungen, Plattformabzügen und gegebenenfalls Steuern. Die Modellrechnung allein ist keine geprüfte Gewinn- oder Umsatzprognose.
- Serverautorisierte Wirtschaft und rechtlich/produktspezifisch freigegebene Zahlungsprodukte. Lokale Sandboxbestände werden nicht als wirtschaftlich vertrauenswürdiges Inventar übernommen.

Die Entscheidung sollte den gemessenen kostenlosen Wettbewerbspfad als harte Nebenbedingung behandeln und anschließend die kommerziellen Schwellenwerte vergleichen. Ein Modell mit höherem angenommenem Umsatz und systematischem Ausschluss kostenloser Spieler erfüllt das Ziel nicht.
