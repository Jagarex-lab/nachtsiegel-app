# Ressourcenvergleich auf der Produktionsengine

Empfehlung: **8 Energie / 15 Resonanz beibehalten.** Die höheren Energielimits stellen in dieser kleinen Starter-Stichprobe vor allem mehr ungenutzte Energie bereit. Der Vergleich von 10/15 mit 10/20 erreicht keine beobachtete Resonanz über 15 und liefert identische Zustands- und Ereignisdigests; er kann einen Vorteil des höheren Resonanzlimits daher nicht beurteilen.

## Tatsächlicher Nachweis

1435 Engineprüfungen, 0 Fehler; 192 vollständige Matrixpartien und 10 zusätzliche Kontrollpartien. Vier reale 30-Karten-Starter über dem tatsächlichen 550-Karten-Katalog, alle 16 gerichteten Paarungen, je zwei Seeds mit jeder Startseite pro Profil. Dieselben 64 Paar-/Seed-Fälle laufen unverändert in allen drei Profilen. Keine zensierten oder fehlerhaften Partien werden als Ergebnis gezählt.

Die 64 Standardpartien bestätigen Sieger, Halbzugzahl, Konvergenz sowie vollständige Zustands- und Ereignisdigests des vor dem Getter-Eingriff ausgeführten 848-Partien-Laufs. Sechs zusätzliche Wiederholungen und vier Kontrollen des gewöhnlichen Produktionskonstruktors prüfen Determinismus und die Gleichheit der Test-Subclass bei 8/15. Historische Partien und manipulierte Nachweiskopien werden nicht zu den 202 neuen Partien addiert.

## Gepaarte Ergebnisse

| Energie/Resonanz | Partien | Ø Halbzüge | Startspieler-Siege | Konvergenz | Andere Sieger als 8/15 | Andere Ereignisdigests | Ø Halbzugdifferenz zu 8/15 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8/15 | 64 | 24.4688 | 32/64 | 6 | 0 | 0 | +0.0000 |
| 10/15 | 64 | 24.3281 | 32/64 | 4 | 4 | 47 | -0.1406 |
| 10/20 | 64 | 24.3281 | 32/64 | 4 | 4 | 47 | -0.1406 |

## Ressourcenmessung

Summen über beide Sitzpositionen und 64 Partien je Profil. Energie zu Aktionsbeginn, bekannte gedruckte Kosten erfolgreich gespielter Karten und ungenutzte Energie sind getrennte Beobachtungen, keine geschlossene Bruttobilanz: Reliktkosten, automatische Effekte und Energiegewinne sind darin nicht vollständig aufgeschlüsselt. Resonanzwerte sind Nettodifferenzen pro KI-Aktion; gleichzeitig erzeugte und ausgegebene Resonanz kann sich aufheben. Die Peaks erfassen beobachtete Aktionsgrenzen, keine lückenlose interne Verlaufsmessung.

| Energie/Resonanz | Energie zu Aktionsbeginn | Gedruckte Kartenzahlungen | Ungenutzte Energie | Netto-Resonanzgewinn | Netto-Verbrauch | Beobachteter Peak | Partien mit Peak >15 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 8/15 | 8889 | 5847 | 2823 | 636 | 565 | 15 | 0 |
| 10/15 | 9846 | 5852 | 3808 | 574 | 519 | 12 | 0 |
| 10/20 | 9846 | 5852 | 3808 | 574 | 519 | 12 | 0 |

## Gerichtete Paarungen

Je Feld: Siege Hero / Unentschieden / Siege Enemy; anschließend mittlere Halbzüge. Jede Zelle umfasst dieselben vier Seeds, davon zwei erste Züge pro Sitzposition. Spiegelpartien zählen hier weiterhin vier Partien und keine acht unabhängigen Fälle.

| Hero / Enemy | 8/15 | 10/15 | 10/20 |
|---|---|---|---|
| houses/houses | 2/0/2; 29.00 | 2/0/2; 30.00 | 2/0/2; 30.00 |
| houses/morph | 3/0/1; 17.75 | 3/0/1; 18.25 | 3/0/1; 18.25 |
| houses/ninth | 2/0/2; 34.00 | 4/0/0; 23.50 | 4/0/0; 23.50 |
| houses/stillwatch | 4/0/0; 34.00 | 3/0/1; 33.25 | 3/0/1; 33.25 |
| morph/houses | 3/0/1; 15.75 | 3/0/1; 15.75 | 3/0/1; 15.75 |
| morph/morph | 0/0/4; 15.00 | 0/0/4; 15.00 | 0/0/4; 15.00 |
| morph/ninth | 1/0/3; 15.75 | 1/0/3; 15.75 | 1/0/3; 15.75 |
| morph/stillwatch | 3/0/1; 19.25 | 3/0/1; 19.25 | 3/0/1; 19.25 |
| ninth/houses | 1/0/3; 20.75 | 1/0/3; 22.25 | 1/0/3; 22.25 |
| ninth/morph | 4/0/0; 16.25 | 4/0/0; 16.25 | 4/0/0; 16.25 |
| ninth/ninth | 4/0/0; 20.75 | 4/0/0; 20.25 | 4/0/0; 20.25 |
| ninth/stillwatch | 2/0/2; 39.50 | 3/0/1; 43.75 | 3/0/1; 43.75 |
| stillwatch/houses | 1/0/3; 24.75 | 1/0/3; 26.25 | 1/0/3; 26.25 |
| stillwatch/morph | 3/0/1; 20.75 | 3/0/1; 20.75 | 3/0/1; 20.75 |
| stillwatch/ninth | 2/0/2; 35.50 | 2/0/2; 37.25 | 2/0/2; 37.25 |
| stillwatch/stillwatch | 1/0/3; 32.75 | 1/0/3; 31.75 | 1/0/3; 31.75 |

## Grenzen und Umsetzung

Nur eine deterministische KI-Policy und vier unveränderte Starter: weder menschliche Balance noch sämtliche Interaktionen oder mögliche Decks der 550 Karten sind damit bewiesen. Gleiche Seeds erlauben einen kontrollierten Vergleich; sie sind keine 64 unabhängigen menschlichen Messungen. Bei 10/15 beträgt der beobachtete Peak 12, bei 10/20 beträgt er 12. Diese Profile sind deshalb kein Belastungsnachweis für einen ausgeschöpften 20er-Speicher. Für einen Ressourcenwechsel wären weitere legale resonanzintensive Decks und menschliche Partien nötig.

Produktionsdefault, Session und UI bleiben bei 8/15. Nur die Test-Subclass überschreibt Getter. Energie-Refresh und generischer Energiegewinn verwenden denselben 8er-Default-Getter; gewöhnlicher Resonanzgewinn und natives Harvest verwenden denselben 15er-Default-Getter. Die Policy liest den Resonanzdeckel für Gewinnbewertungen und Reliktverfügbarkeit. Schwellen und Kosten der übrigen Aktionen ändern sich nicht. Grenztests prüfen beide Seiten und alle drei Profile einschließlich unverändertem 15er-Burst-Zugang.

Die Engine prüft den Quellenhash am Anfang und Ende. Der Berichtsgenerator verlangt danach denselben vollständigen Quellensatz wie im tatsächlichen Lauf und prüft die alte Baseline gegen deren Commit. 19 negative Evidenzwächter weisen beschädigte Kopien echter Ergebnisse zurück: fehlende, zusätzliche oder doppelte Fälle, Quellen-/Baselinewechsel, falsche Startseite, ungültige Ergebnisse, fehlende Kontrollen und manipulierte Standarddigests. Das sind Integritätsprüfungen, keine weiteren gespielten Partien.

## Reproduktion

```sh
bash tools/test_production_resources.sh
python3 tools/production/report_resources.py --verify-rejections
python3 tools/production/report_resources.py --verify-rejections --check
```

Rohdaten: `docs/production/RESOURCE_MODEL_GAMES.json`; kompakter Bericht: `RESOURCE_MODEL_EXPERIMENT.json`. Der Generator kann die eingecheckten Rohdaten mit `--source docs/production/RESOURCE_MODEL_GAMES.json` prüfen. Alle Seeds und Zustands-/Ereignisdigests bleiben im Rohbericht erhalten.

Rohdaten-SHA-256: `afb9cbfb7489329177b3931ba1e66e032a335231dd9e0e1d93ac78df4b05ba82`. Baseline des früheren 848-Partien-Laufs: `fa507dc4a13b1043c1197094e5524cf61186e5ef2101969d0fa87586a67be681`.
