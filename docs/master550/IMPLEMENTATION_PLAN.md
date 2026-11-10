# ORAFOLD – 550-Karten-Entwicklungsplan

Auftrag vom 10.11.2026. Die aktuelle Freigabe erlaubt getestete Merges und ausdrücklich manuell ausgelöste Web-Releases. Schutzregeln und Release-Guard bleiben verbindlich. Kein Automatismus veröffentlicht Branchänderungen.

## Ausgangspunkt

Develop f1d24ba enthielt Alpha0.1 mit55 Alpha-Karten, vier30er-Startern und separatem100er-Legacy-Katalog. PR9 ist auf d8053e9 vollständig geprüft und jetzt regulär als5d37cd9 integriert. Der tatsächliche develop-Commit erhält erneut vollständige Web-QA vor dem manuellen Pages-Release. Das ist der erste spielbare Mobile-Meilenstein, nicht der Abschluss des550-Karten-Auftrags.

## Pakete und Abhängigkeiten

| Paket | Umsetzung | Abnahme |
|---|---|---|
| M0 | Getestete Mobile-UI integrieren/veröffentlichen | develop-QA grün, manueller Release, Live-SHA/Ressourcen und vollständige Browserpartie verifiziert |
| M1 | Gesamtaudit, Regelkonflikte, verbindliches V2-Datenschema,12 gleichwertige Wesensarten, Glossar | Reale Abdeckung belegt; ungültige Daten/Parameter/Text werden abgewiesen; keine erfundenen550 Einträge |
| M2 | Gemeinsame parametrisierte Effekte/Trigger in bestehendem Kernel konsolidieren |12 Kategorien/16 Trigger, deterministische Queue, Zielinvalidierung, Ressourcen-/Schleifenschutz und Ereignisprotokoll; kein zweiter Kampfkernel |
| M3 | Ressourcenmodelle und Wertebudgets vergleichen | reproduzierbare gepaarte Simulationen, Energie1–10 erreichbar geprüft, Änderungen begründet; Legacy-Profil unverändert |
| M4 | Kuratierte Kartenpakete und Archetypen, insgesamt110 je Zugehörigkeit | jede Karte valide, eindeutig und tatsächlich im Kernel spielbar; Text/Effekte synchron; Decks mit Gegenstrategien |
| M5 | Split-/Diagonalrahmen63:88, einheitliche Rückseite, Assetpipeline | Außenkontur identisch, Information sichtbar, Rarität innerhalb der Kontur, Rechte/Herkunft dokumentiert |
| M6 | Spielfeld-Mulligan, Drag-and-drop plus Tap, Reliktplatz, Animationen/Mobile | sichere gültige/ungültige Drops, Zustandserhalt bei Rotation; tatsächliche gerenderte Vergleiche |
| M7 | Deckbuilder-Speziesfilter, Sortierung, zehn Strategietestdecks | echte30er-Decks, Kopien-/Machtvalidierung, Speicherung/Migration |
| M8 | Strategie-KI, Simulationsmetriken und iterative Balance | Startseiten/Matchups, Nutzungs-/Energie-/Resonanzdaten, extreme Ketten; keine unbelegte Balancebehauptung |
| M9 | Gesamtabnahme und getesteter Web-Release | alle550 realen Karten, sämtliche Abnahmekriterien und keine bekannten kritischen Fehler; Live-Browserprüfung |

M1→M2→M3→M4 sind fachliche Abhängigkeiten. M5/M6 können nach festgelegtem Datenvertrag parallel entstehen. Bestehende Spielbarkeit bleibt währenddessen erhalten. Nicht abgeschlossene Pakete werden als offen geführt und nicht als fertige Webfunktionen ausgegeben.

## Verbindliche Konstanten

Fünf Kampfpfade und beide Siege bleiben erhalten. Ein Angreifer mit leerem direkt gegenüberliegendem Feld trifft den Helden; Block vor Schild gemäß bestehender Regeln. Drei Haupttypen werden eindeutig auf stabile technische IDs abgebildet: creature=Wesen, event=Impuls, relic=Relikt. Der bisherige event-Identifikator ist kein zusätzlicher vierter Typ. Bestehende gespeicherte Karten-IDs werden nicht umbenannt. Legacy-Referenz34b3062 und Regressionen bleiben erhalten.

## Noch nicht nachgewiesen

550 eigenständige fertige Karten, zwölf Arten-Synergien, sämtliche16 Trigger, neue Ressourcenbalance und individuelle550 Illustrationen sind zum Auftragsbeginn nicht vorhanden. Die bislang vorhandenen55 sind kein Ersatz für diesen Umfang. Echte iPhone-/Android-Tests werden nur mit tatsächlichem Gerät als solche bezeichnet.
