# Diagnose langer Produktionssimulationen

Diese Messungen stammen aus einem Linux-Container mit zwei CPU-Kernen als Quote und zeitweilig mehreren parallelen Godot-Prüfungen. Sie sind **keine Messungen auf einem iPhone, Android-Gerät oder schwachen Mobilgerät**.

## Tatsächlich beobachtete Kandidaten

1. Ein früher Produktionskandidat baute beim Validierungsprobe-Konstruktor wiederholt den 550-Karten-Katalog und dessen Bindungen auf. Die diagnostische Messung zeigte etwa 1,39 Sekunden für den Hauptkonstruktor und 2,38–3,02 Sekunden für einen eigenen plus gegnerischen KI-Zug. Der unvollständige erste Matrixversuch wurde nach vier Partien für diese technische Diagnose beendet und nicht als bestandener Test gezählt (`work/production/simulations-pre-fast-probe-incomplete.log`).
2. Nach kontrollierter Wiederverwendung unveränderlicher Validierungskonfiguration lagen im Diagnoseprogramm der Konstruktor bei etwa 0,71 Sekunden und die ersten eigenen plus gegnerischen Züge bei 0,115–0,208 Sekunden (`constructor-fast-profile.log`). Zwischen den Kandidaten änderten sich auch Karten-/Starterdaten und parallele CPU-Last. Die Zahlen sind deshalb keine kontrollierte A/B- oder mobile Performance-Studie.
3. In der späteren echten Produktionsmatrix beendeten die ersten 120 Fälle ohne gemeldete Enginefehler. Die anschließende Kontrollspiegel-Paarung dauerte erheblich länger. Ein separater, unveränderter Regelnachbau mit demselben tatsächlichen Produktionsmodell und `prod-control` auf beiden Seiten, Seed 0, endete regulär im Halbzug 118: Gegner gewinnt, Held 0 LP, Gegner 27 LP, 3.738 protokollierte Ereignisse. In späten Abschnitten dauerten eigene plus gegnerische Züge etwa 0,5–1,5 Sekunden. Dieser Fall beweist **keine Endlosschleife**.

Das vollständige Diagnoseprogramm, Zwischenzustände und Endzustand sind in `work/production/control_probe.gd`, `control-probe.log` und `control-probe-final.json` erhalten. Der eigene vollständige Simulationsprozess wurde während der fokussierten Diagnose zeitweilig pausiert und anschließend mit unveränderten Quellen fortgesetzt. Die Pause ist in seiner lokalen Laufzeit enthalten und darf nicht zur Hochrechnung von Spielgeschwindigkeit verwendet werden.

## Technische Folgerungen

Die Konstruktor-/Validierungsarbeit darf nicht proportional zur ganzen Sammlung bei jedem legalen Einzelzug wiederholt werden. Unveränderlicher Katalog und validierte Bindungen können geteilt werden; veränderlicher Kampfzustand, RNG, FIFO, Identitäten und Fähigkeitsverwendungen müssen getrennt bleiben. Vollständige historische Journal-/Log-Kopien und wiederholtes Hashen wachsender Ereignisverzeichnisse sind bei langen defensiven Partien gesondert zu prüfen.

Optimierungen müssen vollständige Zustände, Ereignisreihenfolgen, Quellenidentitäten und vorhandene Legacy-Regressionen erhalten. Eine kürzere Stichprobe oder ein abgebrochener Fall darf nicht stillschweigend als bestandene vollständige Matrix dargestellt werden. Maßgeblich bleiben der finale Simulationsbericht und dessen genaue Anzahl, Quelldigests und Fehlerliste.

## Unterbrochener vollständiger Kandidatenlauf

Der erste vollständige 848-Fälle-Lauf nach der Grundoptimierung wurde auf Anweisung des Engine-Reviews nach 120 berichteten Fällen wegen der langen Kontrollpaarung und wachsender Speicherlast beendet. Zusätzlich wurde während dieses alten Laufs auf Anforderung die Shard-Unterstützung im Testharness ergänzt; sein Quellenwächter hätte den Lauf deshalb ebenfalls verworfen. **Dieser Versuch ist kein bestandener 848-Partien-Test.** Die genaue Unterbrechung und die unveränderten Teil-Logs stehen in `work/production/interrupted-attempt.json` und `simulations-120-before-history-fix-incomplete.log`. Der finale Lauf muss nach der historischen Log-/Probe-Optimierung neu auf unveränderten Quellen stattfinden.
