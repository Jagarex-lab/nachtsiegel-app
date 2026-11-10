# ORAFOLD: implementierter lokaler Wirtschaftsprototyp

Stand: 10. November 2026. Alle Zahlen sind **vorläufige, nicht freigegebene Testparameter**. Einstieg: [Audit](ECONOMY-AUDIT.md), [Integration](INTEGRATION.md), [Simulation](SIMULATION-REPORT.md), [Wahrscheinlichkeiten](BOOSTER-RATES.md). Die älteren kleingeschriebenen Dokumente beschreiben den früheren Serverarchitekturentwurf; dieses Dokument beschreibt den ausführbaren Sandboxstand.

## Geltungsbereich

Die Wirtschaft ist ein eigenständiges Godot-4-Modul ohne Kampf-, Ressourcen- oder Triggerabhängigkeit. Die Sammlung im aktiven Deckbuilder bleibt unverändert frei zugänglich. Kein Autoload, keine zentrale Szene, keine Kartenmechanik und kein Produktionsspielstand werden verändert. Ein Adapter liest die vorhandenen Starter und Katalogmetadaten. Weil der aktive Alpha-Katalog keine epischen Karten enthält, verwendet der isolierte Prototyp ausdrücklich einen synthetischen Katalog; diese Karten dürfen niemals als spielbare oder handelbare Produktionskarten importiert werden.

Die 550 Testdefinitionen folgen der vorläufigen Loreverteilung 250 gewöhnlich / 160 selten / 100 episch / 40 legendär. Dies bestätigt weder die endgültigen Karten noch ihre Stärke. Starter werden ohne festgeschriebene Produktions-IDs auf Testkarten abgebildet: vier Decks mit jeweils 30 Karten, insgesamt 41 unterschiedliche Definitionen und 111 physisch benötigte Kopien durch Wiederverwendung neutraler Karten. Bestehende Strategien und Kampfwerte werden nicht neu ausbalanciert.

## Module und Daten

`data/economy/*.json` ist die gemeinsame Parameterquelle für Godot und Python. `config.gd` validiert sie; `catalog_adapter.gd` trennt reale Definitionen und Fixture. `economy_manager.gd` koordiniert Transaktionen. Sammlung, Booster, Crafting, Belohnungen, Level und Aufgaben arbeiten ausschließlich auf einem Transaktionsentwurf. `save_adapter.gd` nutzt den vorhandenen ProgressStore als Dateitransport in einem eigenen Sandboxslot. Die konkrete API und Startbefehle stehen in der Integrationsanleitung.

Der Koordinator kopiert den Zustand, prüft die Operation und alle Invarianten und speichert den vollständigen Entwurf vor der Veröffentlichung des Ergebnisses. Ein Speicherfehler verwirft den Entwurf im Arbeitsspeicher. Transaktions-ID, Anfrage und ursprüngliches Ergebnis bleiben erhalten; gleiche ID mit abweichender Anfrage scheitert. Belohnungsquellen besitzen zusätzlich eigene Einmaligkeitsnachweise. Eine Animation erhält nur das bereits gebuchte Ergebnis. Überspringen, Szenenwechsel und erneutes Enthüllen sind keine Inventaroperationen.

## Währungen und Kreislauf

Gold bezahlt Standardbooster. Herstellungsessenz ist ein geschlossenes Craftingmaterial ohne Kauf-, Tausch- oder Auszahlungsfunktion. Premium ist als deaktivierter Reserveschlüssel vorbereitet; eine weitere aktive Kaufwährung ist für die Alpha nicht erforderlich. Energie und Resonanz bleiben ausschließlich Kampfressourcen. Keine dieser Ressourcen kann in Gold umgetauscht werden.

| Seltenheit | Spielbare Kopien | Herstellung | Verwertung / Überhang |
|---|---:|---:|---:|
| Gewöhnlich | 3 | 40 | 5 |
| Selten | 3 | 100 | 20 |
| Episch | 3 | 400 | 80 |
| Legendär | 1 | 1200 | 240 |

Über dem Kopienlimit wird automatisch Essenz statt einer zusätzlichen spielbaren Kopie vergeben. Manuelle Verwertung benötigt eine ausdrückliche Bestätigung; gebundene Starter- und Herstellungskopien, gesperrte Einträge und reservierte Deckkopien sind geschützt. Herstellung ist auf das spielbare Limit begrenzt. Die Kosten liegen auch bei hypothetisch ungebundener Herstellung über den Erlösen; es existiert kein positiver Umwandlungszyklus. Kosmetische Freischaltungen sind separate Identitäten und zählen nicht als zusätzliche Regelkarten. Eine Instanzverwaltung kosmetischer Kartenvarianten ist noch nicht integriert.

## Belohnungen und Fortschritt

Einmaliger Einstieg: vier Starter, 300 Gold, fünf Booster, 1200 Essenz und 100 XP. Das gezielte Herstellen einer gewünschten legendären Karte ist dadurch kostenlos möglich. Level-, Kapitel- und Aufgabenbelohnungen stehen in den Daten. Es gibt keine Loginserie. Die tägliche Basisaufgabe verlangt eine abgeschlossene Partie, keinen Sieg; optionale Vielfalt zählt allgemein gespielte Karten. Siege oder seltene Karten werden für diese Aufgaben nicht benötigt.

Der Normalisierungsadapter liefert eindeutige Ereignisquellen und monotone UTC-Perioden. Der lokale Client kann Ereignisse und Uhrzeit manipulieren; er ist kein Nachweis für echte Spielleistungen. Eine spätere Autorität muss Ergebnisbelege und Tagesbudgets selbst prüfen. Rerolls, Eventkalender, Machtmeisterschaft und umfassende Erfolge bleiben Erweiterungspunkte. Bestehende Kampagnenkapitel werden nicht verändert.

## Fairness und Tragfähigkeit

Vier vollständige Starter sichern den kostenlosen Spieleinstieg. Spieler können fehlende Schlüsselkarten gezielt herstellen, statt ausschließlich auf Zufall zu warten. Bezahlen wird nur als zusätzlicher Boosterzufluss in der Simulation modelliert. Der Client enthält weder Echtgeldpreise noch Kaufoberflächen oder Zahlungsanbieter.

Die Simulation misst Sammlungsbreite, spielbare Kopien, gezielte Upgradeverfügbarkeit, Ressourcenbestände und Abstände zwischen Profilen. Größere Deckauswahl ist kein Beleg gleicher Gewinnchancen. Weil stärkere Fähigkeiten höherer Seltenheit zulässig sein sollen, bleibt ein erheblicher Wettbewerbsvorteil durch beschleunigten Zugriff möglich. Belastbare Aussagen erfordern später vollständige Karten, Matchups, Deckkosten und echte Spieler-/Umsatzdaten. Ohne Preise, Konversion, Bindung, Betriebskosten und Zahlungsdaten ist wirtschaftliche Nachhaltigkeit eine offene Produktfrage, kein Simulationsergebnis.

## Sicherheit und Handel

Alle Bestände tragen `local_untrusted_test_data`. Schema, Grenzen, Historienverkettung und Backups erkennen bestimmte Beschädigungen, authentifizieren aber weder Eigentum noch Guthaben. Ein Angreifer kann lokale Daten und Prüfsummen gemeinsam verändern. Transaktionshistorie und Einmaligkeitsnachweise werden nicht stillschweigend gekürzt; Speicherwachstum muss später durch serverseitige Archivierung gelöst werden.

Gebundene Kopien und Herkunfts-/Quellbelege bereiten Verträge vor. Es werden keine Handelsoperationen und keine sicheren Eigentumsinstanzen implementiert. Ein Marktplatz benötigt neue serverautorisierte Inventare, unveränderliche Definitionen, Instanz-IDs, ACID-Transaktionen, Reservierungen, Betrugsprüfung und Zahlungsbelege. Lokale Sandboxbestände werden dabei verworfen; sie sind kein Startkapital.
