# Produktions-Balancing: tatsächlicher Simulationsbericht

## Ausführungsstatus

**BESTANDEN: 2688 Prüfungen, 0 Fehler.** 848/848 Matrixpartien (784 Strategie-, 64 Starterpartien), zusätzlich 18 vollständige Wiederholungen. Davon 8 Kontrollen mit vollständig neuen Modellkonstruktoren statt geteilter unveränderlicher Konfiguration. Quellen während der Ausführung verändert: [].

Alle Fälle laufen über die tatsächliche Produktionsengine. Es gibt keine verkürzte Schadensberechnung, erfundenen Sieger oder vom Sollbestand entfernten Unsupported-Fälle. Die 550 aktiven Daten wurden als tatsächlicher Katalog geladen. Eine Partie mit einem Deck belegt nur dessen tatsächlich aufgetretene Interaktionen.

- Vollständig beendet: 848; abgebrochen/unentschieden ohne Ergebnis (`censored`): 0; Enginefehler: 0; regelkonforme Unentschieden: 0.
- Startspieler-Siege: 493/848, 58.1% (54.8–61.4%). Jede geordnete Paarung enthält gleich viele erste Züge für beide Sitzpositionen.
- Durchschnitt: 26.24 Halbzüge; Median 23. Dies ist keine gemessene menschliche Spielzeit.
- Konvergenzsiege: 48; übrige Helden-LP-Siege: 800. Der historische JSON-Feldname `hero_damage_wins` umfasst alle Nicht-Konvergenz-LP-Siege einschließlich Impuls-, direktem Kampf- und Erschöpfungs-/Recyclingschaden; diese Messung trennt die letzte Schadensquelle nicht zuverlässig.
- Tatsächlich ausgespielte unterschiedliche Karten: 233/550. Nicht ausgespielte Karten sind nicht automatisch fehlerhaft oder zu schwach.
- Längste native Queue: 3; längste generische Queue: 6; Partien mit mindestens zehn generischen Queueeinträgen: 0.
- Generische Effektausgänge: `{"applied": 70735, "fizzled": 12}`.

## Regeln und Fairness

30 Karten, genau eine Macht plus neutrale Karten, höchstens drei normale und eine legendäre Kopie, 30 Helden-LP, fünf Pfade und beide Siegbedingungen. Das normale Energielimit bleibt 8, alle neuen Kosten liegen zwischen 1 und 8. Die KI erhält keine zusätzlichen Ressourcen, Karten oder Sicht auf verborgene gegnerische Kartenidentitäten. Die ursprüngliche Regel für direkte Heldenangriffe bei leerem Gegenfeld bleibt erhalten.

Die separate Policy-Grundprüfung `tools/test_production_ai.sh` bestand **187 Prüfungen, 0 Fehler und 20 vollständige Partien** über dem archivierten 55-Karten-Alpha-Profil. Sie prüft unter anderem Schwierigkeitsfairness, unverändernde Entscheidungen, tatsächliche Zielregeln, freie Gegenpfade, Konvergenzabwehr sowie vollständige Zustands-/Ereignis-/Entscheidungsdeterministik. Diese 20 Partien sind nicht in den Produktionszahlen oben enthalten.

## Deck-Ergebnisse

Spiegelpartien zählen zwei Deckteilnahmen pro Partie. Die Intervalle sind deskriptive Wilson-Intervalle; gemeinsam genutzte Seeds, dieselbe Policy und korrelierte Decklisten erfüllen keine Annahme unabhängiger menschlicher Partien.

### Strategie-Referenzdecks

| Deck | Teilnahmen | Siege | Sieganteil mit 95%-Wilson-Intervall | Konvergenzsiege |
|---|---:|---:|---|---:|
| prod-aggro | 112 | 77 | 68.8% (59.7–76.6%) | 2 |
| prod-block | 112 | 46 | 41.1% (32.4–50.3%) | 3 |
| prod-control | 112 | 78 | 69.6% (60.6–77.4%) | 4 |
| prod-convergence | 112 | 78 | 69.6% (60.6–77.4%) | 4 |
| prod-impulse | 112 | 67 | 59.8% (50.6–68.4%) | 3 |
| prod-midrange | 112 | 75 | 67.0% (57.8–75.0%) | 2 |
| prod-movement | 112 | 22 | 19.6% (13.3–28.0%) | 2 |
| prod-recurrence | 112 | 22 | 19.6% (13.3–28.0%) | 1 |
| prod-relic | 112 | 17 | 15.2% (9.7–23.0%) | 1 |
| prod-resonance | 112 | 34 | 30.4% (22.6–39.4%) | 3 |
| prod-resource | 112 | 36 | 32.1% (24.2–41.3%) | 2 |
| prod-shield | 112 | 64 | 57.1% (47.9–65.9%) | 7 |
| prod-species | 112 | 76 | 67.9% (58.7–75.8%) | 5 |
| prod-time | 112 | 92 | 82.1% (74.0–88.1%) | 3 |

### Sichtbare Starterdecks

| Deck | Teilnahmen | Siege | Sieganteil mit 95%-Wilson-Intervall | Konvergenzsiege |
|---|---:|---:|---|---:|
| starter-houses | 32 | 20 | 62.5% (45.3–77.1%) | 1 |
| starter-morph | 32 | 13 | 40.6% (25.5–57.7%) | 0 |
| starter-ninth | 32 | 18 | 56.2% (39.3–71.8%) | 3 |
| starter-stillwatch | 32 | 13 | 40.6% (25.5–57.7%) | 2 |
## Auffällige Referenzdecks

- `prod-aggro`: 77/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-control`: 78/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-convergence`: 78/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-midrange`: 75/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-movement`: 22/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-recurrence`: 22/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-relic`: 17/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-resonance`: 34/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-resource`: 36/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-species`: 76/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-time`: 92/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.

## Häufig gespielte Karten

Nutzung und Siege sind durch Deckauswahl und die heuristische Policy verzerrt. Die folgende Tabelle ist eine Suchhilfe für weitere Tests und keine kausale Rangliste der Kartenstärke.

| Karte | Ausspielvorgänge | Partieteilnahmen mit Ausspielen | Davon Siege |
|---|---:|---:|---:|
| Zweiter Abschied (`of-houses-057`) | 924 | 284 | 100 |
| Kupferhüterin (`of-houses-001`) | 791 | 131 | 38 |
| Fehlende Schwester (`of-houses-043`) | 726 | 156 | 31 |
| Erinnerungsfresser (`of-houses-015`) | 457 | 152 | 31 |
| Ungebrochene Scheibe (`of-stillwatch-097`) | 392 | 392 | 242 |
| Kreis aus Eis (`of-stillwatch-081`) | 378 | 271 | 190 |
| Kupferner Beichtstuhl (`of-houses-056`) | 376 | 178 | 36 |
| Der späte Gast (`of-ninth-043`) | 342 | 234 | 162 |
| Stummer Mitschreiber (`of-houses-014`) | 341 | 95 | 20 |
| Zeugin der Lücke (`of-ninth-050`) | 326 | 214 | 116 |
| Wiederholte Warnung (`of-ninth-070`) | 316 | 221 | 159 |
| Knochenrestaurator (`of-houses-028`) | 309 | 165 | 37 |
| Nächster Augenblick (`of-ninth-065`) | 295 | 188 | 131 |
| Sekundenkollektor (`of-ninth-022`) | 294 | 167 | 53 |
| Panzerhüter (`of-stillwatch-026`) | 291 | 146 | 73 |
| Namenhüter (`oa-houses-c01`) | 283 | 146 | 42 |
| Gepanzerter Keim (`of-stillwatch-043`) | 274 | 194 | 104 |
| Pendelfresser (`of-ninth-046`) | 271 | 185 | 131 |
| Wuchernder Schatten (`of-morph-032`) | 268 | 203 | 130 |
| Die achte Sekunde (`of-ninth-051`) | 266 | 186 | 129 |

## Ressourcenmessung

Gemessene Energie zu Beginn tatsächlicher Aktionsphasen: 130728; bekannte gedruckte Energiekosten erfolgreich gespielter Karten: 98185; ungenutzte Energie beim Zugabschluss: 29646. Reliktkosten und automatische Energiegewinne sind keine vollständige Bruttobilanz in diesen drei Werten.

Netto-Resonanzgewinne je KI-Aktion: 11619; Netto-Verbrauch: 11190. Gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die vollständigen Reihen der zu Aktionsphasenbeginn beobachteten Resonanzwerte stehen pro Partie im Rohbericht. Fehlgeschlagene optionale Aktionsversuche: 0; illegale Kartenaktionen verursachen dagegen einen expliziten Engine-/Policyfehler.

## Beweisgrenzen und nächste Balancing-Schritte

- Diese Selbstspiel-Stichprobe beweist weder vollständige menschliche Balance noch sämtliche Interaktionen aller 550 Karten. Karten-Daten-/Effekt-/Triggerprüfungen sind separate Tests.
- Vierzehn Referenzdecks und vier Starter sind echte Zusammensetzungen, keine optimalen oder erschöpfenden Decks.
- Die erhaltenen nativen Gegnerpfade wählen automatisches Verbrennen und einzelne ursprüngliche Ankunftseffekte teilweise nach älteren Heuristiken. Gleiche Regeln/Ressourcen und gegenbalancierte Startseiten bedeuten keine vollkommen identischen Entscheidungspfade beider Sitzpositionen.
- Die vorangegangene echte Schild/Kontroll-Blockade und die daraufhin geprüften vorhandenen Wachstumsrelikte sind in `DEFENSIVE_DECK_REGRESSION.md` und `FAILED_BASELINE.json` erhalten. Jene fehlgeschlagene Stichprobe wird nicht zum finalen bestandenen Lauf addiert.
- Der als `resource_control` geführte Referenz-Archetyp untersucht Ressourcenführung und Kartenfluss. Die implementierten Ressourcenoperationen erzeugen eigene Energie/Resonanz; gezielter gegnerischer Energie-/Resonanzentzug ist noch nicht implementiert und wird nicht als geprüft behauptet. Angriffsschwächung ist kein Ressourcenentzug.
- Auffällige Decks zuerst mit weiteren Seeds, anderen legalen Zusammensetzungen und menschlichen Partien untersuchen. Änderungen an Werten benötigen einen neuen gebundenen Quelldigest und eine erneute vollständige Matrix.
- Keine stillschweigende Entfernung langer, fehlerhafter oder nicht beendeter Partien. Die ungekürzten Resultate dokumentieren jeden Fall.

## Reproduktion und Nachweise

```sh
bash tools/test_production_ai.sh
bash tools/test_production_simulations.sh
python3 tools/production/report_simulations.py
```

Engine: `4.6.3-stable (official)`. Die vollständigen Seeds, Zustands-/Ereignisdigests, Aktionszahlen, Kartennutzungen, Quellen-SHA-256 und Messgrenzen stehen in `work/production/simulations.json` (CI-Artefakt), SHA-256 `0379dbe163dc5fcea5bdbc967e4fb9296fd7f90997e9a367006b7dfec27ae175`. Der eingecheckte kompakte Nachweis steht in `docs/production/simulation-results.json`; er enthält Zusammenfassung und Quellenbindung, keine behaupteten zusätzlichen Partien.
