# Auditnachweise

Alle Dateien beziehen sich auf die beiden fixierten Commits im [Audit](../LEGACY_PARITY_AUDIT.md). Keine Produktionsdatei wurde für diese Prüfung geändert.

- `legacy_export.json`: tatsächlicher Export von `E.CARDS`, START, Presets und acht isolierten Angriffsvektoren; Herkunftscommit und Engine-SHA-256 enthalten.
- `export_legacy.cjs`: reproduziert diesen Export gegen einen lokalen Checkout; 120 Prüfungen (100 Ankunftssmokes, 16 Angriffszustandsprüfungen und vier reine Schadenfälle). Kein semantischer Volltest sämtlicher Fähigkeiten.
- `compare_attack.gd`: stellt die acht isolierten Angriffe im unveränderten Godot-Modell nach. Nicht darstellbare Schutz-/Bereitschaftsfelder ausdrücklich nicht vortäuschen. Erwartet vier passende und vier abweichende Teilfälle; erfolgreiche Assertions bestätigen auch die Lücken.
- `attack-comparison.json`: Ausgabe dieses Godot-Laufs. Numerische `.0`-Schreibweise stammt aus Godots JSON-Parser, keine Änderung der Spielwerte.
- `mechanic_inventory.json`: 70 explizite Auditverträge und Zählgrundlage; Status entspricht der Markdownmatrix. Zählung ist keine Aufwandsschätzung.
- `test_results.json`: Befehle, Exitcodes und Umfang; unter `logs/` liegen ungekürzte Testprotokolle und das neue 1000er-Simulationsergebnis.

`godot-full-suite.log` enthält die neun erfolgreich abgeschlossenen Assertion-Summen (gesamt9547) und den Kontrastbericht. Einzelprotokolle ergänzen Umgebungswarnungen und Laufdetails. Das ist die vorhandene lokale Suite, kein neu behaupteter JS-gegen-Godot-Regelnachweis. Die drei roten JS-Prüfungen bleiben unverändert dokumentiert. Für den Audit wurden keine Browser-/Webexport- oder physischen Gerätetests durchgeführt.

Reproduktionsbefehle, Aussagegrenzen und fehlende externe Datei: Abschnitt7 im Audit. Rohprotokolle können absolute Workspacepfade enthalten; sie enthalten keine Nutzerspielstände oder Zugangsdaten.
