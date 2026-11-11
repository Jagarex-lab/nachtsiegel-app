# Vorläufiges Fortschrittsmodell

Quelle aller Werte: `data/economy/progression.json`, `rewards.json`, `quests.json`. Keine Werte sind endgültig freigegeben.

Level 1 beginnt mit 0 Lebenszeit-XP. Der Schritt von Level L nach L+1 kostet `100 + 25*(L-1)` XP. Level 100 ist die sichtbare Obergrenze; es gibt keine wiederholbare Maximallevelbelohnung. Ein Levelaufstieg vergibt 50 Gold. Meilensteine werden separat einmalig gespeichert: Level 5 und 10 jeweils 400 Essenz, 50 Gold und 50 XP; Level 25, 50 und 100 jeweils 50 Gold und 50 XP. Die beiden Essenzvergaben sind das Ergebnis des gepaarten Simulationsvergleichs und ermöglichen den gezielten kostenlosen Zugang zu weiteren epischen Schlüsselkarten.

Eine abgeschlossene Partie bringt 40 XP und 10 Gold; das Partiegold endet bei 100 pro UTC-Tag. Das XP-Budget ist nicht dasselbe wie das Goldbudget. Ein sehr aktiver Spieler kann deshalb schneller aufsteigen, aber keine unbegrenzten Levelbelohnungen erzeugen. Die tatsächliche Spielzeit hängt von Partiedauer und Abschlussrate ab; die Simulation verwendet 10 Minuten je Partie.

| Aufgabe | Ziel | Belohnung | Druckbegrenzung |
|---|---|---|---|
| Täglich spielen | 1 abgeschlossene Partie | 60 Gold, 50 XP | Kein Sieg nötig |
| Optionale Vielfalt | 10 Karten spielen | 40 Gold, 50 XP | Macht- und seltenheitsunabhängig |
| Wöchentlich spielen | 10 abgeschlossene Partien | 300 Gold, 200 XP, 2 Booster | Keine tägliche Loginpflicht |

Die Woche wird aus `floor(UTC-Tag/7)` bestimmt, nicht aus einer persönlichen siebentägigen Serie. Verpasste Tage werden nicht bestraft; tägliche Belohnungen können dennoch ein gefühltes Teilnahmegefälle erzeugen. Retention, Wochenlastigkeit und alternative Wochenbudgets müssen mit Spielertests überprüft werden.

Fünf Kampagnenkapitel können je einmal 150 Gold, 100 XP und einen Booster vergeben. Diese Sandboxoperation bestätigt keinen tatsächlichen Sieg. Ein zukünftiger Kampagnenadapter muss eindeutige Abschlussbelege liefern, statt gespeicherte Sieganzahlen in wiederholbare Belohnungen umzuwandeln.

Die Simulationsprofile A–E verwenden dieselbe Konfiguration und unterschiedliche Zeit-/Boosterbudgets. Vier kostenlose Starter sind von Beginn an verfügbar. Die gezielte Upgradebereitschaft ist ein Verfügbarkeitsindikator; sie beweist weder Decklegalität aller Testkombinationen noch konkurrenzfähige Gewinnraten. Messergebnisse, Unsicherheit und vorläufige Anpassungen stehen im Simulationsbericht.
