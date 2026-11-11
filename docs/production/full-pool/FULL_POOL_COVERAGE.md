# Full-Pool-Selbstspiel: Coverage-Stichprobe

**BESTANDEN**: 256/256 vollständig protokollierte Matrixversuche, 256 beendet, 0 zensiert, 0 mit Enginefehler. Für 0 geplante Fälle liegt kein abgeschlossener Versuch vor: Sie wurden entweder noch nicht begonnen oder mitten in der Ausführung unterbrochen. Sie erhalten keine erfundenen Sieger oder Unentschieden.

Die 32 legalen Decklisten enthalten zusammen 550/550 Identitäten. Tatsächlich erfolgreich ausgespielt wurden **546/550** verschiedene IDs aus beobachteten KI-Kommandos; 546 davon erscheinen auch in vollständig beendeten fehlerfreien Partien. 4 IDs wurden nicht ausgespielt. Mitgliedschaft, Beschwörung und gedruckte Fähigkeiten zählen nicht als Ausspielnachweis.

Zusätzlich 8/8 Wiederholungen und 4/4 frische Konstruktoren. Diese Kontrollen werden nicht zur Matrix-Coverage addiert. 320 Öffnungsproben sind keine vollständigen Partien. 19 beschädigte Nachweiskopien wurden abgewiesen; diese Prüfungen spielen keine weiteren Partien.

## Methode und Grenzen

Die vorhandene Produktionsengine und KI bleiben unverändert. Der Sampler erbt Aufbau, tatsächliche Zugausführung und Messung aus production_simulations.gd; er ist keine zweite Engine. Acht Decks je Macht besitzen einen Starterkern und echte wiederkehrende Angriffswachstums-Relikte. Je Deck werden zwei vorab festgelegte Gegner und je zwei Seeds pro erster Sitzposition gespielt: 64 gerichtete Paarungen × vier Fälle = 256 geplante Partien.

Der separate Plan wird vor der ersten vollständigen Partie geschrieben und per SHA-256 gebunden. Alle bestehenden Modell-, Daten-, KI- und geerbten Testdateien werden gegen den angegebenen Core-Commit geprüft; der Lauf bindet zusätzlich Deckfixture, Generator und Orchestrierung. Nur die gemessene Wandzeit ist aus vollständigen Wiederholungsvergleichen ausgeschlossen.

Diese heuristische Stichprobe untersucht breitere tatsächliche Interaktionen und Laufzeiten. Sie beweist weder vollständige Interaktionsabdeckung noch menschliche oder vollständige 550-Karten-Balance. Nicht ausgespielte Karten sind keine automatisch schwachen oder defekten Karten. Ein 500-Aufrufe-Horizont ist ein technischer Abbruch und keine Unentschiedenregel.

## Fehler, Zensierung und nicht ausgeführte Fälle

Keine Fehler/Zensierung und alle geplanten Fälle/Kontrollen vollständig.

Die unveränderten Rohdaten, der Plan und gegebenenfalls das geflushte Journal bleiben erhalten. Die JSON-Zusammenfassung enthält jeden tatsächlichen Fall samt Digest und die vollständigen Listen fehlgeschlagener und nicht ausgeführter Fälle. Bei Unterbrechung werden nur vollständig geflushte Journalzeilen rekonstruiert; unvollständige letzte Zeilen bleiben im Originaljournal erhalten.

Engine-Log geprüft: 0 Fehlerzeilen. `last_case_start_seen` nennt nur die zuletzt protokollierte Fallöffnung, keine bewiesene Fehlerursache. Beobachteter Engine-Exitcode: 0.

## Ressourcen und tatsächliche Effekte

Energie wird als beobachtete Aktionsphasen-Verfügbarkeit, bekannte gedruckte Kosten erfolgreicher Ausspielvorgänge und Restenergie beim Zugabschluss ausgewiesen. Diese Werte sind keine geschlossene Bruttobilanz. Resonanzwerte sind Nettodifferenzen je Aktion; gleichzeitige Erzeugung und Verbrauch können sich aufheben. Peaks erfassen beobachtete Grenzen, nicht jeden internen Zwischenwert.

| Messwert über Matrixversuche | Wert |
|---|---:|
| resonance_peak_observed | 15 |
| turns_observed | 6150 |
| energy_at_action_phase | 35036 |
| known_card_energy_paid | 25750 |
| known_card_resonance_paid | 0 |
| unspent_energy_at_end | 7888 |
| action_net_resonance_gained | 3570 |
| action_net_resonance_spent | 3394 |
| failed_action_attempts | 0 |

Generische Operationen zählen tatsächliche Runtime-Einträge nach Effekt und Status; native Ereignisarten sind Trace-Zähler, keine vollständige Einzelhandler-Abdeckung. Ausspiel- und Effektzahlen stammen nicht aus den gedruckten Fähigkeitslisten.

| Tatsächlicher Effekt/Status | Runtime-Einträge |
|---|---:|
| deal_damage/applied | 785 |
| delay_damage/applied | 989 |
| discard_card/applied | 100 |
| draw_cards/applied | 651 |
| gain_energy/applied | 302 |
| gain_resonance/applied | 2337 |
| gain_resonance/fizzled | 1 |
| grant_block/applied | 1854 |
| grant_shield/applied | 3208 |
| heal_target/applied | 1803 |
| modify_attack/applied | 3616 |
| move_unit/applied | 80 |
| return_card/applied | 1237 |
| stun_unit/applied | 754 |
| summon_card/applied | 111 |
| weaken_unit/applied | 344 |

## Gerichtete Paarungen

| Hero / Enemy | Versuche | Beendet | Zensiert | Fehler | Siege Hero/Enemy/Draw | Ø beobachtete Halbzüge |
|---|---:|---:|---:|---:|---|---:|
| full-pool-houses-01/full-pool-stillwatch-01 | 4 | 4 | 0 | 0 | 3/1/0 | 19.75 |
| full-pool-houses-01/full-pool-morph-04 | 4 | 4 | 0 | 0 | 2/2/0 | 19.00 |
| full-pool-houses-02/full-pool-stillwatch-02 | 4 | 4 | 0 | 0 | 3/1/0 | 23.25 |
| full-pool-houses-02/full-pool-morph-05 | 4 | 4 | 0 | 0 | 2/2/0 | 19.50 |
| full-pool-houses-03/full-pool-stillwatch-03 | 4 | 4 | 0 | 0 | 3/1/0 | 30.75 |
| full-pool-houses-03/full-pool-morph-06 | 4 | 4 | 0 | 0 | 4/0/0 | 23.00 |
| full-pool-houses-04/full-pool-stillwatch-04 | 4 | 4 | 0 | 0 | 4/0/0 | 25.50 |
| full-pool-houses-04/full-pool-morph-07 | 4 | 4 | 0 | 0 | 3/1/0 | 20.25 |
| full-pool-houses-05/full-pool-stillwatch-05 | 4 | 4 | 0 | 0 | 3/1/0 | 25.75 |
| full-pool-houses-05/full-pool-morph-08 | 4 | 4 | 0 | 0 | 4/0/0 | 22.50 |
| full-pool-houses-06/full-pool-stillwatch-06 | 4 | 4 | 0 | 0 | 4/0/0 | 25.50 |
| full-pool-houses-06/full-pool-morph-01 | 4 | 4 | 0 | 0 | 3/1/0 | 24.25 |
| full-pool-houses-07/full-pool-stillwatch-07 | 4 | 4 | 0 | 0 | 2/2/0 | 36.50 |
| full-pool-houses-07/full-pool-morph-02 | 4 | 4 | 0 | 0 | 2/2/0 | 18.00 |
| full-pool-houses-08/full-pool-stillwatch-08 | 4 | 4 | 0 | 0 | 3/1/0 | 23.75 |
| full-pool-houses-08/full-pool-morph-03 | 4 | 4 | 0 | 0 | 3/1/0 | 21.75 |
| full-pool-stillwatch-01/full-pool-morph-01 | 4 | 4 | 0 | 0 | 3/1/0 | 21.75 |
| full-pool-stillwatch-01/full-pool-ninth-04 | 4 | 4 | 0 | 0 | 1/3/0 | 27.25 |
| full-pool-stillwatch-02/full-pool-morph-02 | 4 | 4 | 0 | 0 | 3/1/0 | 19.25 |
| full-pool-stillwatch-02/full-pool-ninth-05 | 4 | 4 | 0 | 0 | 2/2/0 | 32.00 |
| full-pool-stillwatch-03/full-pool-morph-03 | 4 | 4 | 0 | 0 | 2/2/0 | 23.50 |
| full-pool-stillwatch-03/full-pool-ninth-06 | 4 | 4 | 0 | 0 | 1/3/0 | 21.75 |
| full-pool-stillwatch-04/full-pool-morph-04 | 4 | 4 | 0 | 0 | 2/2/0 | 21.00 |
| full-pool-stillwatch-04/full-pool-ninth-07 | 4 | 4 | 0 | 0 | 2/2/0 | 20.50 |
| full-pool-stillwatch-05/full-pool-morph-05 | 4 | 4 | 0 | 0 | 2/2/0 | 24.00 |
| full-pool-stillwatch-05/full-pool-ninth-08 | 4 | 4 | 0 | 0 | 1/3/0 | 26.25 |
| full-pool-stillwatch-06/full-pool-morph-06 | 4 | 4 | 0 | 0 | 3/1/0 | 19.75 |
| full-pool-stillwatch-06/full-pool-ninth-01 | 4 | 4 | 0 | 0 | 2/2/0 | 31.00 |
| full-pool-stillwatch-07/full-pool-morph-07 | 4 | 4 | 0 | 0 | 2/2/0 | 25.00 |
| full-pool-stillwatch-07/full-pool-ninth-02 | 4 | 4 | 0 | 0 | 2/2/0 | 34.00 |
| full-pool-stillwatch-08/full-pool-morph-08 | 4 | 4 | 0 | 0 | 3/1/0 | 21.75 |
| full-pool-stillwatch-08/full-pool-ninth-03 | 4 | 4 | 0 | 0 | 1/3/0 | 33.25 |
| full-pool-morph-01/full-pool-ninth-01 | 4 | 4 | 0 | 0 | 0/4/0 | 19.00 |
| full-pool-morph-01/full-pool-houses-04 | 4 | 4 | 0 | 0 | 1/3/0 | 21.25 |
| full-pool-morph-02/full-pool-ninth-02 | 4 | 4 | 0 | 0 | 0/4/0 | 18.50 |
| full-pool-morph-02/full-pool-houses-05 | 4 | 4 | 0 | 0 | 3/1/0 | 16.75 |
| full-pool-morph-03/full-pool-ninth-03 | 4 | 4 | 0 | 0 | 0/4/0 | 16.00 |
| full-pool-morph-03/full-pool-houses-06 | 4 | 4 | 0 | 0 | 1/3/0 | 20.75 |
| full-pool-morph-04/full-pool-ninth-04 | 4 | 4 | 0 | 0 | 0/4/0 | 15.50 |
| full-pool-morph-04/full-pool-houses-07 | 4 | 4 | 0 | 0 | 2/2/0 | 17.00 |
| full-pool-morph-05/full-pool-ninth-05 | 4 | 4 | 0 | 0 | 0/4/0 | 18.00 |
| full-pool-morph-05/full-pool-houses-08 | 4 | 4 | 0 | 0 | 2/2/0 | 18.00 |
| full-pool-morph-06/full-pool-ninth-06 | 4 | 4 | 0 | 0 | 1/3/0 | 17.25 |
| full-pool-morph-06/full-pool-houses-01 | 4 | 4 | 0 | 0 | 2/2/0 | 22.50 |
| full-pool-morph-07/full-pool-ninth-07 | 4 | 4 | 0 | 0 | 1/3/0 | 15.25 |
| full-pool-morph-07/full-pool-houses-02 | 4 | 4 | 0 | 0 | 2/2/0 | 20.00 |
| full-pool-morph-08/full-pool-ninth-08 | 4 | 4 | 0 | 0 | 0/4/0 | 19.00 |
| full-pool-morph-08/full-pool-houses-03 | 4 | 4 | 0 | 0 | 2/2/0 | 22.50 |
| full-pool-ninth-01/full-pool-houses-01 | 4 | 4 | 0 | 0 | 2/2/0 | 25.50 |
| full-pool-ninth-01/full-pool-stillwatch-04 | 4 | 4 | 0 | 0 | 3/1/0 | 27.25 |
| full-pool-ninth-02/full-pool-houses-02 | 4 | 4 | 0 | 0 | 3/1/0 | 36.75 |
| full-pool-ninth-02/full-pool-stillwatch-05 | 4 | 4 | 0 | 0 | 4/0/0 | 29.00 |
| full-pool-ninth-03/full-pool-houses-03 | 4 | 4 | 0 | 0 | 3/1/0 | 35.25 |
| full-pool-ninth-03/full-pool-stillwatch-06 | 4 | 4 | 0 | 0 | 4/0/0 | 34.50 |
| full-pool-ninth-04/full-pool-houses-04 | 4 | 4 | 0 | 0 | 3/1/0 | 30.25 |
| full-pool-ninth-04/full-pool-stillwatch-07 | 4 | 4 | 0 | 0 | 3/1/0 | 54.25 |
| full-pool-ninth-05/full-pool-houses-05 | 4 | 4 | 0 | 0 | 4/0/0 | 21.00 |
| full-pool-ninth-05/full-pool-stillwatch-08 | 4 | 4 | 0 | 0 | 4/0/0 | 25.50 |
| full-pool-ninth-06/full-pool-houses-06 | 4 | 4 | 0 | 0 | 2/2/0 | 24.00 |
| full-pool-ninth-06/full-pool-stillwatch-01 | 4 | 4 | 0 | 0 | 1/3/0 | 21.75 |
| full-pool-ninth-07/full-pool-houses-07 | 4 | 4 | 0 | 0 | 2/2/0 | 27.00 |
| full-pool-ninth-07/full-pool-stillwatch-02 | 4 | 4 | 0 | 0 | 2/2/0 | 26.00 |
| full-pool-ninth-08/full-pool-houses-08 | 4 | 4 | 0 | 0 | 3/1/0 | 21.75 |
| full-pool-ninth-08/full-pool-stillwatch-03 | 4 | 4 | 0 | 0 | 4/0/0 | 22.50 |

## Laufzeitbeobachtung

Gemessen wird reale Wandzeit von Aufbau/Öffnung bis zur Rückkehr der vollständigen Zugschleife. Last, geteilte Hardware und Ausgabe beeinflussen diese Werte; sie sind keine garantierte Gerätegeschwindigkeit. Planungsproben und Berichtsausgabe gehören nicht zu den einzelnen Matrix-Wandzeiten.

| Wandzeit-Messwert | Mikrosekunden |
|---|---:|
| matrix_wall_usec_sum | 101664263 |
| control_wall_usec_sum | 3640680 |
| whole_run_elapsed_usec | 139780086 |
| minimum_usec | 129479 |
| median_usec | 349122.0 |
| p95_nearest_rank_usec | 811761 |
| maximum_usec | 3138913 |
| mean_usec | 397126.02734375 |

## Explizit nicht ausgespielte Karten

| ID | Name | Macht | Typ |
|---|---|---|---|
| oa-houses-r01 | Ahnenregister | houses | relic |
| of-houses-068 | Zurück ins Licht | houses | event |
| of-houses-100 | Die offene Chronik | houses | relic |
| of-morph-095 | Häutungsklinge | morph | relic |

## Quellen und Reproduktion

Core: `d3c7c7bf1e2d714aef896d39538bfd343d2365c2`. Godot: `4.6.3-stable (official)`. Der JSON-Bericht bindet Rohdaten-, Plan-, Journal-, Engine-Log- und Reporterhash sowie alle20 ausgeführten Quellen. Vollständige Decklisten und alle Fall-/Seed-/Startseitenangaben bleiben in den Rohdaten und im Plan.

Der Wrapper übergibt den tatsächlichen Engine-Exitcode. Der Wert 0 darf bei manueller Reproduktion nur für einen wirklich erfolgreichen Prozessabschluss verwendet werden; ein Fehlercode darf nicht durch 0 ersetzt werden. Ein fehlender Exitcode bleibt unverifiziert und kann keinen bestandenen Bericht erzeugen.

```sh
bash tools/test_production_full_pool_coverage.sh
python3 tools/production/report_full_pool_coverage.py --source work/production/full-pool-coverage.json --plan work/production/full-pool-coverage-plan.json --journal work/production/full-pool-coverage-journal.jsonl --engine-log work/production/full-pool-coverage.log --engine-exit-code 0 --verify-rejections
```
