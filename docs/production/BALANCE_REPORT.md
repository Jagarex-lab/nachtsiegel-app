# Produktions-Balancing: tatsächlicher Simulationsbericht

## Ausführungsstatus

**BESTANDEN: 2688 Prüfungen, 0 Fehler.** 848/848 Matrixpartien (784 Strategie-, 64 Starterpartien), zusätzlich 18 vollständige Wiederholungen. Davon 8 Kontrollen mit vollständig neuen Modellkonstruktoren statt geteilter unveränderlicher Konfiguration. Quellen während der Ausführung verändert: [].

Alle Fälle laufen über die tatsächliche Produktionsengine. Es gibt keine verkürzte Schadensberechnung, erfundenen Sieger oder vom Sollbestand entfernten Unsupported-Fälle. Die 550 aktiven Daten wurden als tatsächlicher Katalog geladen. Eine Partie mit einem Deck belegt nur dessen tatsächlich aufgetretene Interaktionen.

- Vollständig beendet: 848; abgebrochen/unentschieden ohne Ergebnis (`censored`): 0; Enginefehler: 0; regelkonforme Unentschieden: 0.
- Negative Nachweiswächter: 10. Absichtlich beschädigte Kopien echter Laufdaten müssen unter anderem bei fehlenden/zusätzlichen Fällen, gemischten Quellen, falschen Startseiten oder zensierten Partien abgelehnt werden. Diese Integritätsprüfungen zählen keine zusätzlichen Partien.
- Startspieler-Siege: 528/848, 62.3% (59.0–65.5%). Jede geordnete Paarung enthält gleich viele erste Züge für beide Sitzpositionen.
- Durchschnitt: 23.17 Halbzüge; Median 21. Dies ist keine gemessene menschliche Spielzeit.
- Konvergenzsiege: 35; übrige Helden-LP-Siege: 813. Der historische JSON-Feldname `hero_damage_wins` umfasst alle Nicht-Konvergenz-LP-Siege einschließlich Impuls-, direktem Kampf- und Erschöpfungs-/Recyclingschaden; diese Messung trennt die letzte Schadensquelle nicht zuverlässig.
- Tatsächlich ausgespielte unterschiedliche Karten: 176/550. Nicht ausgespielte Karten sind nicht automatisch fehlerhaft oder zu schwach.
- Längste native Queue: 3; längste generische Queue: 6; Partien mit mindestens zehn generischen Queueeinträgen: 0.
- Generische Effektausgänge: `{"applied": 56400, "fizzled": 5}`.

## Regeln und Fairness

30 Karten, genau eine Macht plus neutrale Karten, höchstens drei normale und eine legendäre Kopie, 30 Helden-LP, fünf Pfade und beide Siegbedingungen. Das normale Energielimit bleibt 8, alle neuen Kosten liegen zwischen 1 und 8. Die KI erhält keine zusätzlichen Ressourcen, Karten oder Sicht auf verborgene gegnerische Kartenidentitäten. Die ursprüngliche Regel für direkte Heldenangriffe bei leerem Gegenfeld bleibt erhalten.

Die separate Policy-Grundprüfung `tools/test_production_ai.sh` bestand **187 Prüfungen, 0 Fehler und 20 vollständige Partien** über dem archivierten 55-Karten-Alpha-Profil. Sie prüft unter anderem Schwierigkeitsfairness, unverändernde Entscheidungen, tatsächliche Zielregeln, freie Gegenpfade, Konvergenzabwehr sowie vollständige Zustands-/Ereignis-/Entscheidungsdeterministik. Diese 20 Partien sind nicht in den Produktionszahlen oben enthalten.

## Deck-Ergebnisse

Spiegelpartien zählen zwei Deckteilnahmen pro Partie. Die Intervalle sind deskriptive Wilson-Intervalle; gemeinsam genutzte Seeds, dieselbe Policy und korrelierte Decklisten erfüllen keine Annahme unabhängiger menschlicher Partien.

Der erste vollständige Lauf bleibt in `BALANCE_BASELINE.json` erhalten. Der kontrollierte Vergleich von fünf legalen Deckzusammensetzungen mit 240 tatsächlichen Partien, vollständigen Vorherlisten und allen Ergebnissen steht in `DECK_COMPOSITION_EXPERIMENT.md` beziehungsweise `.json`. Das Zeitdeck, alle sichtbaren Starter, Kartenwerte und Regeln wurden für diese Deckübernahme unverändert gehalten. Der anschließende vollständige Lauf vor der separat geprüften Reliktbeobachter-Korrektur bleibt in `POST_DECK_BEFORE_KILL_WATCHER_FIX.json` erhalten. Diese historischen Läufe werden nicht zu den oben ausgewiesenen Partien addiert; jede Aussage gilt für ihre ausdrücklich gebundenen Quellen.

### Strategie-Referenzdecks

| Deck | Teilnahmen | Siege | Sieganteil mit 95%-Wilson-Intervall | Konvergenzsiege |
|---|---:|---:|---|---:|
| prod-aggro | 112 | 58 | 51.8% (42.6–60.8%) | 2 |
| prod-block | 112 | 20 | 17.9% (11.9–26.0%) | 1 |
| prod-control | 112 | 56 | 50.0% (40.9–59.1%) | 4 |
| prod-convergence | 112 | 58 | 51.8% (42.6–60.8%) | 4 |
| prod-impulse | 112 | 47 | 42.0% (33.2–51.2%) | 3 |
| prod-midrange | 112 | 53 | 47.3% (38.3–56.5%) | 1 |
| prod-movement | 112 | 56 | 50.0% (40.9–59.1%) | 0 |
| prod-recurrence | 112 | 51 | 45.5% (36.6–54.8%) | 0 |
| prod-relic | 112 | 83 | 74.1% (65.3–81.3%) | 1 |
| prod-resonance | 112 | 79 | 70.5% (61.5–78.2%) | 1 |
| prod-resource | 112 | 72 | 64.3% (55.1–72.6%) | 3 |
| prod-shield | 112 | 35 | 31.2% (23.4–40.3%) | 4 |
| prod-species | 112 | 46 | 41.1% (32.4–50.3%) | 1 |
| prod-time | 112 | 70 | 62.5% (53.3–70.9%) | 4 |

### Sichtbare Starterdecks

| Deck | Teilnahmen | Siege | Sieganteil mit 95%-Wilson-Intervall | Konvergenzsiege |
|---|---:|---:|---|---:|
| starter-houses | 32 | 20 | 62.5% (45.3–77.1%) | 1 |
| starter-morph | 32 | 13 | 40.6% (25.5–57.7%) | 0 |
| starter-ninth | 32 | 18 | 56.2% (39.3–71.8%) | 3 |
| starter-stillwatch | 32 | 13 | 40.6% (25.5–57.7%) | 2 |
## Auffällige Referenzdecks

- `prod-block`: 20/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-relic`: 83/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-resonance`: 79/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.
- `prod-shield`: 35/112 Siege. Auffällig in dieser KI-Stichprobe; kein isolierter Nachweis einer zu starken oder zu schwachen Einzelkarte.

## Häufig gespielte Karten

Nutzung und Siege sind durch Deckauswahl und die heuristische Policy verzerrt. Die folgende Tabelle ist eine Suchhilfe für weitere Tests und keine kausale Rangliste der Kartenstärke.

| Karte | Ausspielvorgänge | Partieteilnahmen mit Ausspielen | Davon Siege |
|---|---:|---:|---:|
| Kupferhüterin (`of-houses-001`) | 1363 | 220 | 127 |
| Zweiter Abschied (`of-houses-057`) | 958 | 276 | 139 |
| Der späte Gast (`of-ninth-043`) | 759 | 438 | 271 |
| Wanderfeuer (`of-neutral-049`) | 657 | 375 | 227 |
| Kupferne Wiederkehr (`of-houses-062`) | 598 | 318 | 187 |
| Kausaljäger (`oa-ninth-c01`) | 520 | 254 | 169 |
| Kausalschneiderin (`of-ninth-044`) | 512 | 295 | 196 |
| Wuchernder Schatten (`of-morph-032`) | 459 | 307 | 140 |
| Möglichkeitsweber (`oa-ninth-c06`) | 430 | 202 | 137 |
| Zeugin der Lücke (`of-ninth-050`) | 397 | 212 | 126 |
| Resonanzträger (`oa-neutral-c09`) | 363 | 168 | 111 |
| Pfadkundiger (`oa-neutral-c01`) | 355 | 197 | 117 |
| Ungebrochene Scheibe (`of-stillwatch-097`) | 354 | 354 | 157 |
| Letzter Chronometer (`of-houses-052`) | 346 | 192 | 87 |
| Kreis aus Eis (`of-stillwatch-081`) | 342 | 243 | 136 |
| Zukunftsschuld (`of-ninth-082`) | 326 | 203 | 128 |
| Sprunglarve (`oa-morph-c01`) | 319 | 224 | 113 |
| Wiederholte Warnung (`of-ninth-070`) | 298 | 213 | 123 |
| Panzerhüter (`of-stillwatch-026`) | 286 | 149 | 47 |
| Nächster Augenblick (`of-ninth-065`) | 279 | 175 | 105 |

## Ressourcenmessung

Gemessene Energie zu Beginn tatsächlicher Aktionsphasen: 109831; bekannte gedruckte Energiekosten erfolgreich gespielter Karten: 82047; ungenutzte Energie beim Zugabschluss: 25244. Reliktkosten und automatische Energiegewinne sind keine vollständige Bruttobilanz in diesen drei Werten.

Netto-Resonanzgewinne je KI-Aktion: 9910; Netto-Verbrauch: 9423. Gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die vollständigen Reihen der zu Aktionsphasenbeginn beobachteten Resonanzwerte stehen pro Partie im Rohbericht. Fehlgeschlagene optionale Aktionsversuche: 0; illegale Kartenaktionen verursachen dagegen einen expliziten Engine-/Policyfehler.

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

Engine: `4.6.3-stable (official)`. Die vollständigen Seeds, Zustands-/Ereignisdigests, Aktionszahlen, Kartennutzungen, Quellen-SHA-256 und Messgrenzen stehen in `work/production/simulations.json` (CI-Artefakt), SHA-256 `fa507dc4a13b1043c1197094e5524cf61186e5ef2101969d0fa87586a67be681`. Der eingecheckte kompakte Nachweis steht in `docs/production/simulation-results.json`; er enthält Zusammenfassung und Quellenbindung, keine behaupteten zusätzlichen Partien.
