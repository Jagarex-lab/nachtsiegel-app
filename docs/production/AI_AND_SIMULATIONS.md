# Produktions-KI und reproduzierbare Partiensimulation

## Implementiert

`scripts/production/ai_policy.gd` ist eine deterministische, von Darstellung und Sammlung getrennte Strategieauswertung. Sie führt ausschließlich vorhandene Modellaktionen aus. Die historische Alpha-KI bleibt im Alpha-Profil erhalten; die neue Policy wird ausdrücklich im Produktionsprofil gesetzt.

Die Policy berücksichtigt legal ausspielbare Karten, freie Gegenpfade, unmittelbaren tödlichen Schaden, gegnerische Konvergenzvorbereitung, Heilbedarf, Angriffsbereitschaft, Pfadwechsel, Kartennachschub, Resonanzgrenzen, Reliktaktivierung und Entfesselungen. Zielentscheidungen, Ziehphase und Pflichtverbrennen verwenden dieselben Modellfunktionen wie Spielereingaben. Die drei Schwierigkeitsstufen ändern Auswertung und Auswahl zusätzlicher Taktiken, niemals Startkarten, Lebenspunkte, Ressourcen oder Regeln.

Die Policy liest eigene Karten und öffentliche gegnerische Helden-/Spielfeldwerte. Sie sieht nicht die Identität oder Reihenfolge gegnerischer Hand- und Stapelkarten. Für Gleichstände gelten stabile Karten-/Pfadreihenfolgen. Sie verwendet kein zusätzliches RNG. Die Entscheidungsauswertung verändert den Spielzustand nicht.

Für große Simulationsläufe teilen frische Modellinstanzen nur den unveränderlichen, validierten Katalog und dessen Konfiguration. Jede Partie erhält eigenen Zustand, RNG, FIFO, Verwendungszähler und Policy. Zwei der vollständigen Wiederholungen verwenden zusätzlich vollständig neue Konstruktoren und müssen exakt dieselben Endzustände und Ereignisse ergeben. So wird die Produktionsengine getestet, ohne hunderte identische Kartendatenprüfungen je Zug zu wiederholen.

## Grenzen

Die Auswertung ist heuristisch. Sie durchsucht nicht den vollständigen Spielbaum und beweist keine optimalen Ketten, menschlichen Siegraten oder optimale Deckzusammensetzungen. Automatische Reaktionen werden vom Regelmodell ausgelöst; die Policy erfindet kein zusätzliches Reaktionsfenster. Pro eigener Aktionspassage existiert eine technische Grenze von 64 Ausspielentscheidungen. Eine erreichte Grenze wird im Testbericht ausgewiesen und darf nicht als uneingeschränkt erfolgreicher Fall gezählt werden.

## Referenzdecks

`data/production/test_decks.json` enthält vierzehn tatsächliche 30-Karten-Zusammensetzungen. Der Generator `tools/production/build_test_decks.py` verwendet die implementierten Karten, Archetypen, Fähigkeiten und Kosten. Er prüft Machtzugehörigkeit, Kopiengrenzen und Unterschiede zwischen den Decks. Es entstehen keine zusätzlichen Karten oder Sonderregeln.

Enthalten sind Aggro, Midrange, Kontrolle, Schild, Block, Wiederkehr, Resonanz, Positionswechsel, Wesensarten, Relikte, Impulskombinationen, Konvergenz, Zeitmanipulation und Ressourcenfluss. Das Arten-Deck gewährt keinen erfundenen globalen Artenbonus. Nur entsprechend definierte Karten gewähren Synergien. Das Ressourcen-Deck behauptet keinen gegnerischen Energieentzug, wenn die gewählten Fähigkeiten nur eigenen Ressourcenfluss beeinflussen.

## Reproduktion

```sh
python3 tools/production/build_test_decks.py --check
bash tools/test_production_simulations.sh --quick
bash tools/test_production_simulations.sh
# Größere Stichprobe, dieselben Standardregeln:
bash tools/test_production_simulations.sh --per-first=8
```

Der Schnelllauf enthält einen Ring aus vierzehn geordneten Paarungen mit je einer Partie pro Startseite: 28 Strategiepartien. Zusätzlich laufen stets die 16 geordneten Paarungen der vier sichtbaren Starterdecks, im Schnelllauf mit 32 Partien: zusammen 60 Matrixpartien. Der vollständige Standardlauf enthält sämtliche 196 geordneten Paarungen mit je zwei deterministisch ausgewählten Seeds pro Startseite: 784 Strategiepartien plus 64 Starterpartien, zusammen 848 Matrixpartien. Achtzehn zusätzliche Wiederholungen vergleichen vollständige Endzustände und Ereignisreihenfolgen. Die größere Variante ergibt 3.136 Strategiepartien plus 256 Starterpartien, zusammen 3.392 Matrixpartien plus Wiederholungen. Vorhandene, fehlerhafte oder nicht ausführbare Szenarien werden nicht aus der Sollzahl entfernt.

Ausgaben: `work/production/simulations.json` und `simulations.log`. Der Bericht bindet die ausgeführten Quellen per SHA-256 und enthält pro Partie Seed, Startseite, Ergebnis, Zugzahl, Fehler, Abbruchstatus, Ereignis- und Zustandsdigest, Kartennutzung sowie Ressourcen-/Aktionsbeobachtungen.

## Messgrenzen

`known_card_energy_paid` zählt die gedruckten Energiekosten tatsächlich erfolgreich ausgespielter Karten. Es umfasst keine Reliktkosten und keine automatischen Gewinne. `action_net_resonance_*` misst den Nettozustandswechsel je KI-Aktion. Gleichzeitig erzeugte und ausgegebene Resonanz kann sich darin aufheben; automatische Ereignisse zwischen zwei KI-Aktionen sind keine vollständige Bruttostromrechnung. Die Werte sind entsprechend benannt und dürfen nicht als exakte vollständige Ressourcenbilanz ausgegeben werden.

Eine nicht beendete Partie bleibt `censored=true`. Regel- oder Queuefehler bleiben separat erfasst. Beide führen im normalen Prüflauf zum Fehlschlag. Ergebnisse gegen dieselbe heuristische KI sind Hinweise auf auffällige Karten und Decks, keine abschließende Bewertung des menschlichen Metagames.
