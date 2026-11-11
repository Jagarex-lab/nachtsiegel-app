# Gemessene Referenzdeck-Zusammensetzungen

Die erste vollständige Matrix mit848 Partien blieb als `BALANCE_BASELINE.json`
erhalten. Danach wurden genau fünf zuvor schwache Referenzlisten mit jeweils
einem vorab zusammengestellten Kandidaten verglichen. Kartenwerte, Regeln, KI,
das starke Zeitdeck und alle sichtbaren Starter blieben unverändert.

## Tatsächlich ausgeführter Vergleich

240 vollständige Enginepartien: fünf Decks × drei unveränderte Gegner
(`prod-time`, `prod-aggro`, `prod-control`) × beide Sitzpositionen × vier Seeds
× zwei Zusammensetzungen. Jeder Vorher/Nachher-Fall nutzt denselben Seed und
dieselbe erste Sitzposition. Je Gegner und Bedingung sind acht Partien enthalten;
je Sitzposition beginnen zwei Seeds auf jeder Seite. Die geänderte Kartenliste
ändert naturgemäß die konkreten Karten des gemischten Stapels.

| Referenzdeck | Vorher | Kandidat | Verlust → Sieg | Sieg → Verlust |
|---|---:|---:|---:|---:|
| Relikt |0/24 |16/24 |16 |0 |
| Wiederkehr |2/24 |13/24 |11 |0 |
| Bewegung |2/24 |8/24 |7 |1 |
| Resonanz |3/24 |15/24 |12 |0 |
| Ressourcen-/Kartenfluss |4/24 |17/24 |13 |0 |

Alle240 Partien endeten mit regulärem Ergebnis: null Enginefehler, null
zensierte Fälle und keine Quellenänderung während des Laufs. Die Ergebnisse
sind ein kleiner kontrollierter KI-Vergleich, kein Nachweis menschlicher
Balance oder optimaler Einzelkarten. Für jeden Archetyp wurde genau ein
Kandidat getestet; kein nicht gezeigter Suchlauf wurde zum Erfolg addiert.

## Zusammensetzung und Spielplan

- Relikt: Drei vorhandene Wiederkehr-/Angriffswachstumsrelikte statt vier
  konkurrierender Relikte; günstige Wesen besetzen Pfade, Konstrukte und
  Wiederkehr tragen den langfristigen Plan. Weiterhin höchstens ein aktives Relikt.
- Wiederkehr: Frühe Pfadbesetzung und vorhandene Konstrukte ergänzen
  Rückholungen, Todesauslöser und Wachstumsrelikte; Rekursion erhält einen
  tatsächlichen Angriffsschluss statt bloßer Wiederholung.
- Bewegung: Günstige Besetzung und Nachbarverstärkung ergänzen bestehende
  Bewegungswesen, Seitenwechsel und Schutz beim Versetzen. Die Verbesserung
  bleibt gegen diese drei Gegner begrenzt und rechtfertigt keinen Balancebeweis.
- Resonanz: Vorhandene Resonanzquellen bleiben der Kern; frühe Wesen,
  wiederholbarer Resonanzaufbau und tatsächliche Schadensrelikte verbinden
  Ressourcengewinn mit Druck und Ausgabe.
- Ressourcen-/Kartenfluss: Bereits definierte Energie-/Resonanzquellen,
  Kartennachschub, verzögerter Schaden und aktivierbare Relikte bilden eine
  gemeinsame Kurve. Gegnerischer Energie-/Resonanzentzug wurde nicht hinzugefügt.

Alle fünf Kandidaten wurden als echte 30-Karten-Referenzlisten übernommen.
Die reproduzierbare Definition steht in
`tools/production/build_test_decks.py` unter `MEASURED_COMPOSITIONS`.
Genau diese fünf Listen unterscheiden sich; alle neun übrigen Referenzlisten
und alle sichtbaren Starter bleiben exakt erhalten. Machtbindung und die
Grenzen von drei normalen beziehungsweise einer legendären Kopie bestehen.

## Quellen und Folgeprüfung

`DECK_COMPOSITION_EXPERIMENT.json` enthält sämtliche240 Ergebnisse mit Seed,
Sitzposition, erster Seite, Sieger, Rundenzahl und Zustands-/Ereignis-SHA-256;
außerdem die vollständigen 14 Vorherlisten, alle fünf Kandidaten, die
Übergangszählungen und Quellbindungen. Der SHA-256 des ursprünglichen
Rohberichts und des ausgeführten Experimentskripts bleibt darin erhalten.

Der vollständige Lauf nach der Übernahme wird separat in `BALANCE_REPORT.md`
und `simulation-results.json` ausgewiesen. Die 240 Kontrollpartien werden
weder zur ersten noch zur abschließenden 848er-Matrix addiert.

## Vollständige Matrix nach der Deckübernahme

Die anschließenden 848 tatsächlichen Partien mit 18 zusätzlichen
Wiederholungskontrollen bestanden 2688 Prüfungen und 10 negative Nachweiswächter,
ohne Enginefehler, zensierte Fälle oder Änderungen gebundener Quellen.
Dieser Lauf ist als `POST_DECK_BEFORE_KILL_WATCHER_FIX.json` erhalten;
sein Rohbericht hat SHA-256
`49dc29f09f1cfb2c374eec83ffff5d6ca6b1aa3bfd3020f061a21209b8f6de21`.
Er liegt zeitlich vor der separat nachgewiesenen und anschließend korrigierten
Reliktbeobachtung generischer Wesen-Tötungen. Er wird deshalb als historischer
Lauf erhalten und ersetzt nicht die Matrix der korrigierten Engine.

| Referenzdeck | Siege / Teilnahmen | Sieganteil |
|---|---:|---:|
| Bewegung |56/112 |50,0% |
| Wiederkehr |51/112 |45,5% |
| Relikt |83/112 |74,1% |
| Resonanz |79/112 |70,5% |
| Ressourcen-/Kartenfluss |72/112 |64,3% |
| Unverändertes Zeitdeck |70/112 |62,5% |

Die wirksamen Verbesserungen gleichen das Feld nicht vollständig an: Relikt
und Resonanz sind nun auffällig erfolgreich, während das unveränderte Blockdeck
20/112 und Schild 35/112 Teilnahmen gewinnt. Der erste Spieler gewinnt 528/848
Partien (62,3%). Die sichtbaren Starterlisten und ihre 32 Teilnahmen pro Deck
bleiben exakt wie im ersten Lauf. Es wurden 176 unterschiedliche Karten
tatsächlich gespielt; weder die Referenzauswahl noch die erfasste längste
generische Kette von sechs Queueeinträgen ist ein 550-Karten-Vollbeweis.
