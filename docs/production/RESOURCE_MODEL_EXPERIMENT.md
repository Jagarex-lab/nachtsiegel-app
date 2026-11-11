# Ressourcenvergleich auf der Produktionsengine

Empfehlung: **8 Energie / 15 Resonanz beibehalten.** Im gepaarten Vergleich 8/15 → 10/15 ändern sich die beobachtete ungenutzte Energie von 2952 auf 3701 und die gedruckten Kartenzahlungen von 6157 auf 6211. Der beobachtete Resonanzpeak beträgt 15 bei 10/15 und 16 bei 10/20. Die vollständigen Verläufe beider Profile sind verschieden; daraus folgt ohne weitere Deck- und Menschentests keine Freigabe eines Ressourcenwechsels.

## Tatsächlicher Nachweis

1435 Engineprüfungen, 0 Fehler; 192 vollständige Matrixpartien und 10 zusätzliche Kontrollpartien. Vier reale 30-Karten-Starter über dem tatsächlichen 550-Karten-Katalog, alle 16 gerichteten Paarungen, je zwei Seeds mit jeder Startseite pro Profil. Dieselben 64 Paar-/Seed-Fälle laufen unverändert in allen drei Profilen. Keine zensierten oder fehlerhaften Partien werden als Ergebnis gezählt.

Die 64 Standardpartien bestätigen Sieger, Halbzugzahl, Konvergenz sowie vollständige Zustands- und Ereignisdigests des vor dem Getter-Eingriff ausgeführten 848-Partien-Laufs. Sechs zusätzliche Wiederholungen und vier Kontrollen des gewöhnlichen Produktionskonstruktors prüfen Determinismus und die Gleichheit der Test-Subclass bei 8/15. Historische Partien und manipulierte Nachweiskopien werden nicht zu den 202 neuen Partien addiert.

## Korrigierter Kernel und explizite Baseline

Diese Messung verwendet den Kernel nach den Korrekturen der gedruckten optionalen/sequenziellen Effekte, Wesenreaktionen und nativen KillWatcher-Pfade. Die Cap-Getter wurden darauf aufgesetzt; die Semantikfixes bleiben erhalten.

Die aktive 64er-Baseline ist eine byteidentische Kopie von `PRE_GETTER_STARTER_BASELINE.json`, Ankercommit `5cd7d8af657e95f1dd9ad76ef108af9a23711b68`, vollständiger Pre-Getter-848-Rohbericht `5315796e48eb14c9428a0efb8f9a89f1ce2f4b9a928a8e396ea6241eba0da6d8`. Ihre 18 ausgeführten Quellenhashes werden gegen diesen Commit geprüft. Die neue Standardbedingung muss die tatsächlichen neuen Zustands-/Ereignisdigests bestätigen; die früheren Digests werden nicht auf neue Ergebnisse umgeschrieben.

Die bisherigen Pre-Semantik-Nachweise bleiben unter `resource-history/pre-semantics-b328500/` mit Hashmanifest byteidentisch erhalten. Sie sind historische Ergebnisse und werden nicht zu den aktuellen 192+10 Partien addiert.

## Gepaarte Ergebnisse

| Energie/Resonanz | Partien | Ø Halbzüge | Startspieler-Siege | Konvergenz | Andere Sieger als 8/15 | Andere Ereignisdigests | Ø Halbzugdifferenz zu 8/15 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8/15 | 64 | 25.3438 | 36/64 | 3 | 0 | 0 | +0.0000 |
| 10/15 | 64 | 24.7812 | 34/64 | 2 | 4 | 51 | -0.5625 |
| 10/20 | 64 | 24.6562 | 34/64 | 2 | 4 | 51 | -0.6875 |

## Ressourcenmessung

Summen über beide Sitzpositionen und 64 Partien je Profil. Energie zu Aktionsbeginn, bekannte gedruckte Kosten erfolgreich gespielter Karten und ungenutzte Energie sind getrennte Beobachtungen, keine geschlossene Bruttobilanz: Reliktkosten, automatische Effekte und Energiegewinne sind darin nicht vollständig aufgeschlüsselt. Resonanzwerte sind Nettodifferenzen pro KI-Aktion; gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die Peaks erfassen beobachtete Aktionsgrenzen, keine lückenlose interne Verlaufsmessung.

| Energie/Resonanz | Energie zu Aktionsbeginn | Gedruckte Kartenzahlungen | Ungenutzte Energie | Netto-Resonanzgewinn | Netto-Verbrauch | Beobachteter Peak | Partien mit Peak >15 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8/15 | 9349 | 6157 | 2952 | 711 | 657 | 15 | 0 |
| 10/15 | 10144 | 6211 | 3701 | 663 | 650 | 15 | 0 |
| 10/20 | 10064 | 6176 | 3651 | 659 | 652 | 16 | 1 |

## Gerichtete Paarungen

Je Feld: Siege Hero / Unentschieden / Siege Enemy; anschließend mittlere Halbzüge. Jede Zelle umfasst dieselben vier Seeds, davon zwei erste Züge pro Sitzposition. Spiegelpartien zählen hier weiterhin vier Partien und keine acht unabhängigen Fälle.

| Hero / Enemy | 8/15 | 10/15 | 10/20 |
|---|---|---|---|
| houses/houses | 2/0/2; 29.00 | 2/0/2; 30.00 | 2/0/2; 30.00 |
| houses/morph | 3/0/1; 17.75 | 3/0/1; 18.25 | 3/0/1; 18.25 |
| houses/ninth | 2/0/2; 46.50 | 2/0/2; 37.50 | 2/0/2; 37.50 |
| houses/stillwatch | 4/0/0; 32.00 | 3/0/1; 32.25 | 3/0/1; 32.25 |
| morph/houses | 3/0/1; 15.75 | 3/0/1; 15.75 | 3/0/1; 15.75 |
| morph/morph | 0/0/4; 15.00 | 0/0/4; 15.00 | 0/0/4; 15.00 |
| morph/ninth | 1/0/3; 18.25 | 1/0/3; 18.75 | 1/0/3; 18.75 |
| morph/stillwatch | 3/0/1; 18.75 | 3/0/1; 18.75 | 3/0/1; 18.75 |
| ninth/houses | 1/0/3; 25.50 | 2/0/2; 32.00 | 2/0/2; 30.00 |
| ninth/morph | 4/0/0; 17.00 | 4/0/0; 17.00 | 4/0/0; 17.00 |
| ninth/ninth | 3/0/1; 23.00 | 3/0/1; 23.00 | 3/0/1; 23.00 |
| ninth/stillwatch | 2/0/2; 26.00 | 1/0/3; 24.25 | 1/0/3; 24.25 |
| stillwatch/houses | 1/0/3; 24.75 | 1/0/3; 26.25 | 1/0/3; 26.25 |
| stillwatch/morph | 3/0/1; 20.75 | 3/0/1; 20.75 | 3/0/1; 20.75 |
| stillwatch/ninth | 1/0/3; 43.25 | 2/0/2; 35.25 | 2/0/2; 35.25 |
| stillwatch/stillwatch | 1/0/3; 32.25 | 1/0/3; 31.75 | 1/0/3; 31.75 |

## Einzelne Abweichungen bei höherem Resonanzlimit

- starter-ninth / starter-houses, Seed 2.0, erste Sitzposition enemy: Sieger hero → hero, Halbzüge 36 → 28, beobachteter Resonanzpeak 15 → 16 (10/15 → 10/20).

Diese wenigen verbundenen Fälle belegen konkrete Verlaufsunterschiede, aber keinen allgemeinen Vorteil oder eine menschliche Balancewirkung des höheren Limits.

## Grenzen und Umsetzung

Nur eine deterministische KI-Policy und vier unveränderte Starter: weder menschliche Balance noch sämtliche Interaktionen oder mögliche Decks der 550 Karten sind damit bewiesen. Gleiche Seeds erlauben einen kontrollierten Vergleich; sie sind keine 64 unabhängigen menschlichen Messungen. Bei 10/15 beträgt der beobachtete Peak 15, bei 10/20 beträgt er 16. Für einen Ressourcenwechsel wären weitere legale resonanzintensive Decks und menschliche Partien nötig.

Produktionsdefault, Session und UI bleiben bei 8/15. Nur die Test-Subclass überschreibt Getter. Energie-Refresh und generischer Energiegewinn verwenden denselben 8er-Default-Getter; gewöhnlicher Resonanzgewinn und natives Harvest verwenden denselben 15er-Default-Getter. Die Policy liest den Resonanzdeckel für Gewinnbewertungen und Reliktverfügbarkeit. Schwellen und Kosten der übrigen Aktionen ändern sich nicht. Grenztests prüfen beide Seiten und alle drei Profile einschließlich unverändertem 15er-Burst-Zugang.

Die Engine prüft den Quellenhash am Anfang und Ende. Der Berichtsgenerator verlangt danach denselben vollständigen Quellensatz wie im tatsächlichen Lauf und prüft die alte Baseline gegen deren Commit. 19 negative Evidenzwächter weisen beschädigte Kopien echter Ergebnisse zurück: fehlende, zusätzliche oder doppelte Fälle, Quellen-/Baselinewechsel, falsche Startseite, ungültige Ergebnisse, fehlende Kontrollen und manipulierte Standarddigests. Das sind Integritätsprüfungen, keine weiteren gespielten Partien.

## Reproduktion

```sh
bash tools/test_production_resources.sh
python3 tools/production/report_resources.py --verify-rejections
python3 tools/production/report_resources.py --verify-rejections --check
```

Rohdaten: `docs/production/RESOURCE_MODEL_GAMES.json`; kompakter Bericht: `RESOURCE_MODEL_EXPERIMENT.json`. Der Generator kann die eingecheckten Rohdaten mit `--source docs/production/RESOURCE_MODEL_GAMES.json` prüfen. Alle Seeds und Zustands-/Ereignisdigests bleiben im Rohbericht erhalten.

Rohdaten-SHA-256: `d64fcb5368b1412ed6ca05b3370557fe7586b6f441e8f7b92678f94e49e9f676`. Baseline des früheren 848-Partien-Laufs: `5315796e48eb14c9428a0efb8f9a89f1ce2f4b9a928a8e396ea6241eba0da6d8`.
