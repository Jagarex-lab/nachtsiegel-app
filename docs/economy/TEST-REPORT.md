# Testnachweise und verbleibende Grenzen

Stand: 10. November 2026, Godot 4.6.3, Python 3, Node/Playwright und Chromium unter Linux. Alle Tests betreffen den isolierten lokalen Prototyp. Kein Merge oder Release wurde ausgeführt.

## Ausgeführt

| Prüfung | Ergebnis | Reproduktion |
|---|---|---|
| Konfiguration und Katalog | 66 Assertions, 0 Fehler | `bash tools/economy/test.sh` |
| Transaktionskern und Persistenz | 469 Assertions, 0 Fehler | dieselbe Testsuite |
| Mobile Controls und tatsächliche InputEventScreenTouch-Zustellung | 101 Assertions, 0 Fehler, headless und mit nativem Renderer | `godot --path . --audio-driver Dummy --script tests/economy_ui.gd` |
| Simulationsmodell | 16 Python-Tests bestanden | `python3 -m unittest discover -s tests -p economy_simulation_test.py -v` |
| Tatsächliche Web-Speicherausdrücke | Chromium-Test bestanden | `node --test tests/economy_web_storage.test.cjs` |
| Bestehende Alpha-Datentests | 4 Tests bestanden | `node --test tests/alpha_data.test.cjs` |
| Bestehende Alpha-Regeln | 1704 Assertions, 0 Fehler; 64 vollständige KI-Partien | `godot --headless --path . --script tests/alpha_rules.gd` |
| Bestehende Alpha-Replays | 173 Assertions, 0 Fehler; vier vollständige native Replays | `godot --headless --path . --script tests/alpha_replay.gd` |
| Wirtschaftssimulation | 3000 Profil-/Szenarioläufe, 1000 Sensitivitätsläufe, 400 gepaarte Läufe, 100000 Booster | `python3 tools/economy/simulate_progression.py` |

Logs liegen unter `work/economy/`; die CI lädt diesen Ordner als Artefakt hoch. Die Simulationsparameter, Seeds, Hashes, Tabellen und Diagramme sind unter `docs/economy/results/` eingecheckt. Für die bestehenden Alpha-Regeltests zuvor `mkdir -p work/alpha` ausführen; sie schreiben dort ihre Simulationsdatei.

## Geprüfte Fehlerpfade

Der Kern prüft negative und gebrochene Bestände, deaktiviertes Premium, unbekannte Karten, fehlende oder manipulierte Journalfelder, doppelte Request-IDs mit gleichen/anderen Daten, doppelte Belohnungs- und Ereignisquellen mit neuen Request-IDs, Tageslimits, Zeitrücklauf, ungültige Aktivitätsmengen, Kopienlimits, gebundene/gesperrte/reservierte Karten, Craftingkosten, Duplikatumwandlung, Migrationen und unbekannte Versionen. Eingespritzte Schreibfehler dürfen weder RNG/Pity noch Besitz oder Ergebnisse veröffentlichen. Primär-/Backupbeschädigung führt zu geprüfter Wiederherstellung oder zu einem gesperrten Slot statt stiller Neuvergabe.

Konfigurationstests behandeln fehlende Seltenheiten/Karten, fehlerhafte Wahrscheinlichkeitsmasse, unbekannte Seltenheiten, ungültige Typen und Rewardreferenzen, nicht erreichbare Fortschrittskurven und ressourcengewinnende Herstellungszyklen. Der Python-Lader lehnt doppelte JSON-Schlüssel und NaN/Infinity ab.

Im Chromium-Test erzeugt Godot selbst die JavaScript-Ausdrücke, die der Webadapter tatsächlich verwendet. Diese werden in einem echten Browser mit LocalStorage ausgeführt: Reload erhält Balance und Vergabenachweis, Backup folgt der vorigen Buchung, Quota-/Zugriffsfehler verändern nichts. Vorhandene leere/ungültige Daten werden von einem erstmalig fehlenden Slot unterschieden; der Godot-Decoder wird zusätzlich direkt getestet.

Die Oberfläche wird bei 320×700, 360×800, 390×844 und 1280×900 geprüft. Touchziele sind mindestens 48 Pixel hoch; keine horizontale Seitenüberbreite. Enthüllen, Überspringen, Abbrechen und erneutes Anzeigen verändern den gespeicherten Zustand nicht. Nach Laden wird dasselbe Transaktionsergebnis zurückgeliefert. Manuelle Verwertung verlangt einen gesonderten bestätigten Schritt. Testpartien demonstrieren Aufgaben und XP ausdrücklich als Laborereignisse.

## Visuelle Nachweise

- [Archiv im Hochformat](results/economy-portrait.png)
- [Booster im Hochformat](results/booster-portrait.png)
- [Booster auf Desktop](results/booster-desktop.png)
- [Archiv auf Desktop](results/economy-desktop.png)

Die nativen Screenshots wurden mit Mesa/llvmpipe auf einem Xorg-Dummy-Display erzeugt und visuell geprüft. Die Umgebung meldet eine nicht verfügbare VSync-Umschaltung; der Testlauf endet erfolgreich. Das ist kein physischer Android-/iPhone-Test.

## Korrigierte Befunde und nicht ausgeführte Prüfungen

Während der unabhängigen Prüfung wurden ausgelassene Katalogvalidierung, fehlende Craftingbindung, nicht berücksichtigte Deckreservierungen, ein ungültiges Journalfeld und wiederholbare Ereignisquellen korrigiert. Nach Einführung gebundener Herstellungskopien scheiterte zunächst ein veralteter UI-Test, der deren Verwertung erwartete; der abschließende Test prüft stattdessen Schutz gebundener und bestätigte Verwertung tatsächlich verdienter ungebundener Kopien. Ein Shutdownrest nach touchaktivierter Audiowiedergabe wurde durch den bestehenden Audio-Shutdownvertrag im Test korrigiert, ohne den AudioManager zu verändern.

Ein erster zusätzlicher Alpha-Regellauf scheiterte am noch nicht angelegten `work/alpha`-Ausgabeordner; nach Anlegen des vorhandenen Testvoraussetzungsordners bestanden Regeln und Replays unverändert.

Nicht nachgewiesen: vollständiger Godot-Webexport samt Tabclose/IDBFS, WebKit, physische Mobilgeräte, Android/iOS-Export, Produktivserver, Mehrgeräte-/Mehrfensterkonkurrenz, finale550-Karten-Deckstärke oder tatsächliche Erlöse. Lokale Bestände bleiben manipulierbar. Ein gültig geformter, gemeinsam mit den Hashes editierter Save kann nicht authentifiziert werden. Langfristig wachsende Deduplizierung und Historie können Browserquota erreichen; Fehler werden abgewiesen, eine serverseitige Archivierung ist noch erforderlich.
