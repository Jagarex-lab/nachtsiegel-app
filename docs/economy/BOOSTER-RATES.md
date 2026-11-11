# Boosterwahrscheinlichkeiten und Schutzregeln

Alle Werte sind **vorläufige Testparameter**, keine freigegebene Produktbalance oder Verkaufspreise. Implementiert sind ein isolierter lokaler Prototyp und eine synthetische 550-Karten-Wirtschaft; keine Echtgeldeinkäufe. Die Laufzeit liest `data/economy/booster_pools.json`, `booster_rules.json`, `collection_rules.json` und `crafting.json`.

## Inhalt und Grundwahrscheinlichkeiten

Ein Standardbooster kostet im ausgeglichenen Testszenario **100 Gold** und enthält fünf Karten. Vier Positionen verwenden die erste Tabellenzeile; die fünfte garantiert mindestens Selten. Alle Ziehungen verwenden vor einem gegebenenfalls notwendigen Pity-Eingriff die folgenden Wahrscheinlichkeiten.

| Position | Anzahl | Gewöhnlich | Selten | Episch | Legendär |
|---|---:|---:|---:|---:|---:|
| Grundposition | 4 | 80 % | 17 % | 2,5 % | 0,5 % |
| Garantieposition | 1 | 0 % | 80 % | 18 % | 2 % |

Beide Zeilen summieren sich exakt zu 100 %. Erwartet werden ohne Pity pro Booster 3,20 gewöhnliche, 1,48 seltene, 0,28 epische und 0,04 legendäre Karten. „0,04 legendäre Karten“ ist ein Erwartungswert für die Kartenanzahl, nicht die Wahrscheinlichkeit eines legendären Fundes.

Ohne Pity beträgt die Wahrscheinlichkeit mindestens einer legendären Karte `1 − 0,995⁴ × 0,98 = 3,94534894 %`. Mindestens eine epische **oder legendäre** Karte erscheint mit `1 − 0,97⁴ × 0,80 = 29,17657520 %`. Mehrere höhere Seltenheiten in einem Booster sind möglich. Die zufällige Auswahl einer Karte erfolgt gleichverteilt innerhalb ihrer gewürfelten Seltenheit und des aktiven Pools, gegebenenfalls nach Duplikatschutz.

Nur der Standardpool ist aktiv. Macht-, Erweiterungs- und Eventpools besitzen deaktivierte Definitionen. Sie erhalten erst nach validiertem Katalog, eigenen offengelegten Regeln und Integrationsentscheidung einen aktiven Einstiegspunkt.

## Pity und dauerhafte Ergebnisse

- Spätestens der **fünfte Booster ohne epischen oder legendären Fund** liefert mindestens Episch.
- Spätestens der **zwanzigste Booster ohne legendären Fund** liefert Legendär.
- Zuerst werden alle fünf Seltenheiten gewürfelt. Fehlt der fällige Fund, wird ausschließlich die fünfte Position aufgewertet. Ein ohnehin gewürfelter passender Fund löst keine zusätzliche Karte aus.
- Legendär hat bei gleichzeitiger Fälligkeit Vorrang und setzt beide Zähler zurück. Episch setzt nur den Episch-Zähler zurück.
- Zähler und Zufallszustand werden zusammen mit Verbrauch, Kartenbesitz und Umwandlung gespeichert. Ein Überspringen, Abbrechen oder Wiederholen der Enthüllung würfelt keine Karten neu.

Der implementierte Zähler gilt pro Boosterpool. Im Alpha-Prototyp ist nur `standard` aktiv. Ein späteres Teilen von Zählern zwischen Poolarten benötigt eine explizite Migrations- und Produktentscheidung.

Die Pity-Regel erhöht die effektiven Fundraten. Als analytische Referenz liegt ohne weitere Interaktion die mittlere Wartezeit auf einen Booster mit mindestens einer legendären Karte bei `Σ(k=0…19)(1−p)ᵏ ≈ 14,015` Boostern; das entspricht langfristig rund **7,135 %** solcher Booster. Die natürliche Wahrscheinlichkeit zwanzig Booster ohne legendären Fund zu öffnen wäre rund **44,706 %**; die implementierte Garantie verhindert diese Folge. Tatsächlich gemessene Raten, Stichprobengrößen und Unsicherheiten stehen im [Simulationsbericht](SIMULATION-REPORT.md). Die Positionstabelle beschreibt immer die Grundraten; höhere effektive Pity-Raten dürfen nicht als zusätzliche unabhängige Slotwahrscheinlichkeit addiert werden.

## Duplikate und Herstellung

Die bestehenden Deckregeln erlauben drei spielbare Kopien gewöhnlicher, seltener und epischer Karten und eine legendäre Kopie. Karten oberhalb dieser Grenze werden automatisch in die Herstellungsressource umgewandelt. Epische und legendäre Ziehungen wählen zunächst gleichverteilt unter Karten ihrer Seltenheit, deren spielbare Kopiengrenze noch nicht erreicht ist. Sind alle ausgeschöpft, gilt wieder der vollständige Pool derselben Seltenheit; Überzählige werden regulär verwertet. Der Schutz verändert die Seltenheitswahrscheinlichkeiten nicht.

| Seltenheit | Spielbare Kopien | Herstellung | Verwertung pro überzähliger Karte |
|---|---:|---:|---:|
| Gewöhnlich | 3 | 40 | 5 |
| Selten | 3 | 100 | 20 |
| Episch | 3 | 400 | 80 |
| Legendär | 1 | 1.200 | 240 |

Herstellen und direktes Verwerten erzeugt stets einen Ressourcenverlust. Gebundene Starterkopien sind nicht verwertbar. Manuelle Verwertung erfordert Bestätigung; gesperrte und im übergebenen Deckschutz referenzierte Kopien bleiben geschützt. Kosmetische Varianten sind vom spielbaren Besitz getrennt und werden nicht als zusätzliche Deckkopien gezählt. Es gibt keinen aktiven Handel; lokale Besitzdaten sind nicht vertrauenswürdig und werden nie als serverseitiger Eigentumsbeweis akzeptiert.

Die vier Starterdecks werden als Vereinigung ihrer benötigten Kopien vergeben: gemeinsame Karten zählen mit der höchsten benötigten Anzahl, nicht viermal. Aktuell sind das 41 verschiedene Karten und 111 physische spielbare Kopien; jedes der vier Decks enthält 30 Karten, darunter 15 gewöhnliche, 14 seltene und eine legendäre. Die Adapter lesen diese Definitionen dynamisch, ohne instabile produktive IDs in Wirtschaftsdaten festzuschreiben.

## Kataloggrenze und Validierung

Der produktive Alpha-Katalog besitzt **55 Karten, darunter keine epischen Karten**. Seine Daten werden nicht geändert oder künstlich umgestuft. Der Alpha-Adapter meldet deshalb `booster_pool_missing_rarity:epic`; ein Standardbooster mit den obigen Raten darf darauf nicht geöffnet werden. Wahrscheinlichkeiten werden nicht stillschweigend umverteilt.

Der funktionsfähige isolierte Prototyp verwendet ausdrücklich markierte, nicht spielbare `economy-fixture-*`-Datensätze: 250 gewöhnliche, 160 seltene, 100 epische und 40 legendäre Karten. Die 550 Einträge sind ein Wirtschaftstestmodell und keine Implementierung des parallelen Kartenkatalogs. Ihre Starterdefinitionen bewahren die Seltenheiten, Kopien und Überschneidungen der tatsächlichen Alpha-Starter über einen dynamischen Adapter. Der Umstieg auf den endgültigen Katalog benötigt vollständige Seltenheitspools und eine bewusste Migration; Fixture-Besitz darf nicht in echte Güter übernommen werden.

`tests/economy_config.gd` prüft unter anderem mathematische Raten, unbekannte Seltenheiten, leere/fehlerhafte Pools, fehlende Karten-IDs, negative und gebrochene Werte, Craftingzyklen, ungültige Belohnungen und unerreichbare Fortschrittskurven. Weitere Laufzeittests prüfen Pity, Transaktionswiederholungen, Duplikate und Speicherfehler. Reproduktion: `bash tools/economy/test.sh`.
