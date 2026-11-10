# ORAFOLD – Spielstände und reproduzierbare Partien

Stand: 10. November 2026. Implementierung: `scripts/production/profile_store.gd`, `scripts/alpha/session.gd` und `scripts/production/catalog.gd`. Prüfungen: `tests/production_storage.gd`; ausführbarer Einstieg `tools/test_production_storage.sh`.

## Implementierter Speichervertrag

Profilversion **2** verwendet weiterhin die bestehende Datei `user://orafold_alpha_profile_v1.json`. Der historische Dateiname bleibt zur Migration erhalten. Gespeichert werden lokale Decklisten, Siege, Seed, Macht, Schwierigkeit und reduzierte Bewegung. Es gibt keine serverseitige Sammlung, Eigentumsprüfung, Währung oder Echtgeldfunktion.

- Version-1-Profile werden mit unveränderten stabilen Karten-IDs und unveränderter Deckreihenfolge geprüft und auf Version 2 übertragen. Laden allein überschreibt die Quelldatei nicht.
- Gültige Decks werden anhand des aktiven Katalogs geprüft. Ungültige, entfernte oder unbekannten Profilen zugehörige Decks bleiben mit Originaldaten und Reparaturgrund unter `quarantined_decks` erhalten. Kein automatischer Zufallsersatz und kein stilles Löschen.
- Fehlerhaft formatierte frühere Quarantänedaten werden selbst als Wiederherstellungsdatensatz bewahrt. Ungültige aktive Deckprofile und eine nicht als Dictionary vorliegende Quarantäne werden beim Speichern zurückgewiesen.
- Eine unbekannte neuere Profil-/Katalogversion sperrt das automatische Schreiben. Dadurch können angezeigte Standardwerte die unbekannte Originaldatei nicht überschreiben.
- Eine beschädigte oder nicht lesbare Hauptdatei kann aus `.bak` wiederhergestellt werden. Der Nutzer erhält einen Hinweis; beschädigte Originalbytes bleiben beim nächsten ausdrücklichen Speichern unter `.corrupt` erhalten. Eine beschädigte Hauptdatei überschreibt keine gültige Sicherung.
- Schreiben erfolgt zunächst in `.tmp`, mit Flush und Leseprüfung, dann Sicherung des bisherigen gültigen Standes und abschließendem Rename. Scheitern temporäres Schreiben, Sicherung oder abschließender Austausch, wird kein Erfolg gemeldet. `Session.save_deck` stellt zusätzlich die vorherige Deckliste im Arbeitsspeicher wieder her.
- Größenlimit vier MiB, begrenzte JSON-Tiefe und endliche Zahlen schützen die lokale Datengrenze. Strings/Boolesche Werte werden nicht als numerische Siege/Seeds interpretiert; mathematisch ganzzahlige JSON-Floats bleiben zulässig.

Eine fehlende oder vollständig beschädigte Datei führt zu Standardwerten und einem Hinweis. Das ist keine Wiederherstellung verlorener Daten. Ein laufender Kampf wird dadurch noch nicht nach einem OS-Prozessabbruch fortgesetzt; Match-Resume ist ein eigener offener Funktionsumfang.

## Produktname und vorhandene native Speicherorte

`project.godot` verwendet nun den Anzeigenamen **ORAFOLD**, setzt aber `config/use_custom_user_dir=true` und `config/custom_user_dir_name="godot/app_userdata/NACHTSIEGEL"`. Unter Linux bleibt dadurch der ursprüngliche Pfad `$XDG_DATA_HOME/godot/app_userdata/NACHTSIEGEL` erhalten. Die Prüfung vergleicht den tatsächlichen `OS.get_user_data_dir()` mit diesem Pfad; eine bloße Aussage über den Konfigurationsstring wäre kein Migrationsnachweis.

Die Dateinamen und die bisherige Pages-URL werden deshalb nicht pauschal umbenannt. Andere native Betriebssysteme und tatsächliche Browser-Upgrades benötigen ihre eigenen Persistenzprüfungen; die Linux-Probe ist kein iOS-Gerätenachweis.

## Replayvertrag

`ORAFOLD-LOCAL-REPLAY` **Version 2** bindet eine Partie an ihr Regelnprofil, den mechanischen Katalogfingerprint, Startdecks, Seed, Schwierigkeit und Konvergenzeinstellung. Für jeden angenommenen Befehl enthält das Replay Vorher-/Nachherzustandshashes, Ereignisgrenzen, geordnete Ereignisprüfsumme und das tatsächliche Annahme-/Ergebniskennzeichen. Ein technisch terminal fehlgeschlagener, bereits angenommener Befehl wird von einer illegalen, unverändert abgewiesenen Aktion unterschieden und protokolliert.

Die Rekonstruktion prüft Eingabeformate und Typen, Regeln-/Katalogbindung, jeden Befehl, Zustände, Ereignisreihenfolge sowie das angegebene Endergebnis. `replay_prefix` rekonstruiert exakt die angeforderte gültige Anzahl Befehle. Unbekannte Versionen, manipulierte Ergebnisse oder ungültige Präfixgrenzen werden zurückgewiesen.

Der neue Katalogfingerprint berücksichtigt mechanische Kartenfelder, einschließlich Kosten, Werte, Zugehörigkeit, Reihenfolge, Seltenheit/Kopienlimit und Fähigkeitsprogramme. Namen, Kartentext, Bilder und Lore sind redaktionelle Felder; eine neue Illustration soll kein sonst unverändertes Replay sperren. Beide Wesensarten sind gleichwertig: ihre Listenreihenfolge ändert den Fingerprint nicht, eine andere Art hingegen schon. Karten-IDs werden beim Kataloghash sortiert; die Reihenfolge mehrerer Fähigkeiten bleibt bedeutungsvoll.

Diese Bindung ist eine Konsistenzprüfung für lokale Replays, keine digitale Signatur oder Cheatabsicherung eines Onlineservers. Eine echte Regeländerung kann einen älteren Produktionsreplay unspielbar machen; sie wird nicht still unter neuen Fähigkeiten interpretiert. Die getrennten alten Alpha-/Legacyprofile bleiben für unterstützte historische Replays erhalten.

## Tatsächlicher Versions-1-Nachweis

`tests/fixtures/production/alpha_v1_replay.json` wurde mit dem tatsächlichen Session-Quelltext des veröffentlichten Commits **`fde508e85a2866e24653ef25d920a59832d2d653`** erzeugt. Es ist kein nachträglich aus Version 2 zurückbeschriftetes Testobjekt. Es enthält fünf tatsächlich angenommene Befehle: Mulligan, Ursprung, Abschluss der zweiten Möglichkeit, Ziehphase und Zugende einschließlich gegnerischem KI-Zug.

Unveränderter abschließender Zustandsdigest:

```text
5e4cd2a9fa077b8f6cefa44a9800d2faba803206d559bcfd6e51926f1b212667
```

Die neue Session spielt dieses originale Version-1-Replay im archivierten 55-Karten-Regelnprofil ab. Alle Präfixzustände werden gegen echte schrittweise Sessionausführung verglichen. Eine anschließend über diese Session exportierte Version-2-Datei benennt das Archivprofil ausdrücklich. Historische Zustandshashes bleiben unverändert.

## Gefundener Transportfehler und tatsächliche Korrektur

Der erste vollständige neue Produktionsreplay scheiterte bei **Häuser, Befehl 10**, am geordneten Ereignishash. Der Nachherzustand und beide Ereignisgrenzen waren identisch. Ein vollständiger Feldvergleich des betroffenen Präfixes zeigte genau einen Unterschied: `events[44].lane` war beim ursprünglichen `summon` ein Integer `0`, nach JSON-Import ein Float `0.0`.

Godot liest JSON-Zahlen als Floats. Der neue `event_digest` normalisiert daher ausschließlich die JSON-Transportdarstellung, bevor er die vollständige geordnete Folge hasht. Ereignisse, Reihenfolge, Ziele und tatsächliche Werte werden nicht verworfen. Der historische Zustandshash wird nicht umgestellt. Zusätzliche Regressionen verlangen gleiche Ereignishashes für `0`/`0.0`, aber verschiedene Hashes für umgekehrte Ereignisfolge, andere Zielpfade und geänderte echte Bruchwerte. Ein weiteres gefundenes Problem war typstrenge Zahlenmitgliedschaft: JSON-Version `1.0` wurde zuvor nicht als `1` in einer Integerliste erkannt; endliche ganzzahlige Zahlen werden jetzt vor der Mitgliedschaftsprüfung ausdrücklich normalisiert.

## Tatsächlich ausgeführte Prüfungen und Grenzen

Der vollständige lokale Lauf am **10.11.2026, 20:00 UTC**, bestand mit **398 Assertions, null Fehlern**, ohne Scriptfehler oder Ressourcenlecks. Er führte vier vollständige Produktionspartien über die tatsächliche Session bis zum Endzustand aus, eine je Macht, und exportierte/importierte deren JSON-Replays. Vollständige Zustände und geordnete Ereignisinhalte stimmten überein. Hinzu kamen der unveränderte Version-1-Nachweis, Manipulationen, Präfixe, Korruptions-/Sicherungs-/Quarantänefälle und reale Dateisystemfehler mit Rollback. Ein ausdrücklich benanntes Modell-Fehlerinjektionsfixture prüft nur die Protokollierung bereits angenommener technischer Fehler; es ist keine Karte oder zusätzliche Spielmechanik.

Dieser Nachweis bezieht sich auf den damaligen lokalen Arbeitsstand **vor der anschließenden Umstellung auf mechanische statt redaktionelle Katalogfingerprints**. Er ist kein erfolgreicher CI-Nachweis eines danach veränderten oder eingefrorenen Integrationscommits. Die neu ergänzten mechanischen Fingerprintregressionen werden erst mit dem nächsten vollständigen Lauf als bestanden gezählt. Der aktuelle Rohlog liegt unter `work/production-storage/native.log` und kann bei Wiederholung ersetzt werden.

```sh
tools/test_production_storage.sh
# Nur Speicher-/Archivprüfungen während der Entwicklung, ausdrücklich ohne
# als bestanden gezählte Produktionspartien:
PRODUCTION_STORAGE_FOCUSED=1 tools/test_production_storage.sh
```

Der reguläre Wrapper verlangt vier tatsächlich beendete und nachgespielte Produktionspartien; ein gezielt fokussierter Lauf meldet diese Prüfung ausdrücklich als ausstehend. Vor Merge/Release müssen die vollständigen Gates auf dem eingefrorenen tatsächlichen Integrationsstand erneut bestehen. Diese nativen Tests sind weder Browser- noch physische iPhone-/Android-Tests und belegen keine Veröffentlichung.
