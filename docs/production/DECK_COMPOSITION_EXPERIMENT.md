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

Alle fünf Kandidaten wurden als echte30-Karten-Referenzlisten übernommen.
Die reproduzierbare Definition steht in
`tools/production/build_test_decks.py` unter `MEASURED_COMPOSITIONS`.
Genau diese fünf Listen unterscheiden sich; alle neun übrigen Referenzlisten
und alle sichtbaren Starter bleiben exakt erhalten. Machtbindung und die
Grenzen von drei normalen beziehungsweise einer legendären Kopie bestehen.

## Quellen und Folgeprüfung

`DECK_COMPOSITION_EXPERIMENT.json` enthält sämtliche240 Ergebnisse mit Seed,
Sitzposition, erster Seite, Sieger, Rundenzahl und Zustands-/Ereignis-SHA-256;
außerdem die vollständigen14 Vorherlisten, alle fünf Kandidaten, die
Übergangszählungen und Quellbindungen. Der SHA-256 des ursprünglichen
Rohberichts und des ausgeführten Experimentskripts bleibt darin erhalten.

Der vollständige Lauf nach der Übernahme wird separat in `BALANCE_REPORT.md`
und `simulation-results.json` ausgewiesen. Die240 Kontrollpartien werden
weder zur ersten noch zur abschließenden848er-Matrix addiert.
