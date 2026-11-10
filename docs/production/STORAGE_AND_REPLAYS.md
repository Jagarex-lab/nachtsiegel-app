# ORAFOLD – Spielstände und reproduzierbare Partien

Stand: 10. November 2026. Implementierung: `scripts/production/profile_store.gd`, `scripts/alpha/session.gd` und `scripts/production/catalog.gd`. Prüfungen: `tests/production_storage.gd`; ausführbarer Einstieg `tools/test_production_storage.sh`.

## Implementierter Speichervertrag

Profilversion **2** verwendet die getrennte Datei `user://orafold_profile_v2.json`. Der historische Dateiname `user://orafold_alpha_profile_v1.json` bleibt ausschließlich als lesbare Importquelle erhalten. Gespeichert werden lokale Decklisten, Siege, Seed, Macht, Schwierigkeit und reduzierte Bewegung. Es gibt keine serverseitige Sammlung, Eigentumsprüfung, Währung oder Echtgeldfunktion.

- Version-1-Profile werden mit unveränderten stabilen Karten-IDs und unveränderter Deckreihenfolge geprüft und auf Version 2 übertragen. Laden allein überschreibt die Quelldatei nicht.
- Nur wenn weder neue Hauptdatei noch neue Sicherung existieren, wird die alte Datei beziehungsweise ihre `.bak` gelesen. Auch ein unterstütztes vorläufiges Version-2-Profil im alten Dateinamen kann importiert werden. Eigene Storepfade erhalten keine automatische globale Importquelle; ein optionaler zweiter Konstruktorparameter muss sie ausdrücklich nennen.
- Der erste ausdrückliche neue Save legt die exakt beim Import gelesenen Bytes unter `orafold_profile_v2.json.bak` ab. Die alte Hauptdatei und alte Sicherung bleiben unverändert. Die Importbytes werden beim Lesen eingefroren: Schreibt ein alter Client zwischen Import und Save seine alte Datei neu, verändert dies weder den bereits importierten Stand noch dessen Sicherungsnachweis.
- Sobald die neue Hauptdatei oder ihre Sicherung vorhanden ist, erhält diese neue Namenswelt Vorrang. Änderungen eines alten Clients an seinem alten Dateinamen werden nicht erneut importiert. Eine fehlende neue Hauptdatei wird zunächst aus der neuen Sicherung rekonstruiert, nicht aus einem inzwischen möglicherweise überschriebenen Altprofil.
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

### Unabhängige Web-Sicherung gegen alte Tabs

Die native Dateitrennung allein genügt im Web nicht: Die alte Emscripten-IDBFS-Synchronisation gleicht ihren gesamten alten Dateibaum mit IndexedDB ab und kann neuere Dateien löschen oder auf einen älteren lokalen Stand zurücksetzen. Das betrifft auch einen neuen Dateinamen.

Deshalb verwendet der normale Web-Store zusätzlich die unabhängigen synchronen `localStorage`-Schlüssel **`orafold.profile.v2`** und **`orafold.profile.v2.bak`**. Der alte Client verwendet diese Schlüssel nicht. Eine gültige unabhängige Hauptkopie hat beim Laden Vorrang vor der Dateisicherung, auch wenn diese noch vorhanden, aber veraltet ist. Danach folgen eine gültige unabhängige Sicherung und erst dann FileAccess/Altimport. Ein unbekannter neuerer Primärstand bleibt schreibgeschützt; er wird nicht durch eine ältere Dateisicherung ersetzt.

Ein Web-Save validiert zunächst die Profildaten, liest die beiden unabhängigen Schlüssel und schreibt synchron deren Sicherung und neue Hauptkopie. Ändern sich die Schlüssel zwischen Snapshot und Transaktionsaufruf, schlägt dieser Versuch ohne Überschreiben fehl. Scheitert die Hauptkopie wegen Quota/Berechtigungen, wird die vorherige unabhängige Sicherung wiederhergestellt; es werden keine FileAccess-Dateien verändert. Falls der Browser selbst diesen Rollback verweigert, meldet das Backend einen gesonderten Fehler und niemals einen erfolgreichen Save. Die bisherige Primärkopie bleibt bei einem fehlgeschlagenen atomaren `setItem` erhalten.

Erst nach erfolgreicher unabhängiger Speicherung wird FileAccess als **sekundäre** Kopie geschrieben. Scheitert nur diese zusätzliche Kopie, bleibt der Save erfolgreich und erzeugt einen Wiederherstellungshinweis: Ein synchron bereits dauerhaft gespeichertes Profil wird nicht nachträglich als fehlgeschlagen ausgegeben. Die Session setzt bei tatsächlich fehlgeschlagenen Deck-/Einstellungs-Saves ihren vorherigen Speicherstand im Arbeitsspeicher zurück.

Das technische Profillimit von vier MiB ist keine Garantie ausreichender Browserquota: Zwei Kopien plus andere Site-Daten können die verfügbare Quota überschreiten. In diesem Fall wird ein ausdrücklicher Speicherfehler zurückgegeben. Es gibt keine stillschweigende Abschaltung der unabhängigen Sicherung zugunsten eines unsicheren FileAccess-only-Erfolgs. Browserdatenlöschung oder privater Speicher ohne Persistenzgarantie bleiben Plattformgrenzen; dies ist keine Cloud-Sicherung und kein allgemeiner Zusammenführungsmechanismus mehrerer gleichzeitig bearbeitender neuer Clients.

Der tatsächliche Browsernachweis muss einen alten Tab **vor** Erstellung des neuen Profils offenhalten, ein neues Produktionsdeck speichern, danach den alten echten Schreibvorgang auslösen und die neue Partie/Deckdaten nach Reload prüfen. Native Backendfixtures und JavaScript-Unitprüfungen ersetzen diesen Nachweis nicht.

Die Transaktion selbst ist zusätzlich über neun Node-Testgruppen mit exakt dem
eingebetteten JavaScript geprüft, einschließlich real ausgeführter Fehlerpfade des
Testbackends. Der nachfolgende native Gesamtlauf erreichte 511 funktionale Prüfungen
und vier vollständige Sessionpartien ohne fachlichen Fehler. Sein strenger Wrapper
schlug dennoch wegen zweier beim Engine-Ende verbliebener Katalog-Skriptressourcen
fehl. Diese Deklarations-/Ladeabhängigkeit wird separat korrigiert; der Lauf wird
bis zum sauberen Wiederholungslauf ausdrücklich nicht als bestandene Gesamtprüfung
gezählt. Eine lokale Exportvorprüfung ersetzt weder diesen Gate noch Browser-QA.

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

Die anschließende fokussierte Prüfung der neuen Dateinamenisolation und Fingerprintregressionen bestand mit **373 Assertions, null Fehlern** und einem sauberen nativen Log. Sie enthält reale Import-/Backupdateien, Altprofil-Versionen 1/2, einen alten Schreiber vor und nach dem neuen Save, tatsächliche neue `of-`-Karten im gespeicherten Deck, byteidentische alte Quellen und Sicherungen, unbekannte Versionen sowie fehlgeschlagene Import-Sicherungen. Dieser fokussierte Lauf meldet die vier vollständigen Produktionspartien ausdrücklich als ausstehend; er wird nicht als neuer Gesamtlauf oder stale-IDBFS-Browsernachweis ausgegeben.

Nach der unabhängigen Web-Sicherung bestand der fokussierte Lauf mit **404 nativen Assertions, null Fehlern**, ohne Scriptfehler oder Leaks. Die zusätzlichen ausdrücklich nativen Backendfixtures prüfen Primär-/Backupvorrang gegenüber veralteten/gelöschten Dateien, Import, unbekannte Versionen, Sessionrollback und sekundäre Dateifehler. Daneben bestanden **neun Node-Testgruppen**, die den **exakten eingebetteten JavaScript-Transaktionscode** in einer isolierten VM ausführen, mit gezielten Quota-/Security-/Rollbackfehlern. Diese Fehler sind injizierte Unitfixtures, keine behaupteten realen Safari-/Quotaergebnisse.

Die erneute vollständige Prüfung am **10.11.2026, 22:16 UTC**, bestand mit **511 nativen Assertions, null Fehlern und vier tatsächlich beendeten und vollständig nachgespielten Produktionspartien**. Der unveränderte strikte Wrapper akzeptierte den Lauf einschließlich sauberem Engineabschluss ohne Scriptfehler, ObjectDB-Leaks oder noch verwendete Ressourcen. Der fokussierte Lauf mit 404 Assertions und die neun JavaScript-Testgruppen bestanden unmittelbar zuvor ebenfalls. Alle mechanischen Fingerprintregressionen sind damit im vollständigen lokalen Nachweis enthalten. Die Testdatei lädt die tatsächlichen Katalogklassen zur Laufzeit über die von Session zuerst verankerte Vererbungshierarchie; damit entfallen zwei durch doppelte direkte Basis-/Unterklassen-Preloads verursachte Godot-4.6.3-Scriptreste, ohne Assertions oder Runtimeklassen zu entfernen. Dieser Nachweis gilt für den lokalen Arbeitsstand mit dieser Testkorrektur, nicht für einen später veränderten Integrationscommit. Reale Browsernachweise dieses neuesten Stands bleiben gesondert erforderlich.

```sh
tools/test_production_storage.sh
# Nur Speicher-/Archivprüfungen während der Entwicklung, ausdrücklich ohne
# als bestanden gezählte Produktionspartien:
PRODUCTION_STORAGE_FOCUSED=1 tools/test_production_storage.sh
```

Der reguläre Wrapper verlangt vier tatsächlich beendete und nachgespielte Produktionspartien; ein gezielt fokussierter Lauf meldet diese Prüfung ausdrücklich als ausstehend. Vor Merge/Release müssen die vollständigen Gates auf dem eingefrorenen tatsächlichen Integrationsstand erneut bestehen. Diese nativen Tests sind weder Browser- noch physische iPhone-/Android-Tests und belegen keine Veröffentlichung.

## Tatsächlicher Browsernachweis der Migration

Am **10.11.2026, 23:03 UTC**, bestand der lokale Produktionskandidat **`22581ee194704d03078007564eee7eab4abbc737`** die tatsächliche Migration in **Chromium 158.0.8127.18 und WebKit 27.2** unter Playwright 1.65.0: **354 Assertions, null Console-/Pagefehler**. Der Rohbericht liegt unter `work/production-web-qa-22581ee/migration-results.json`; der geprüfte Harness hat SHA-256 `c1aaf7e90df738e60d1354f67c760e52ef5a144d188a09a303ccea7df3d566d6`.

Die Altlaufzeit war das unverändert aufbewahrte Artefakt **`2b8ea627853b29ac80a5fca2f1c7a00253f92666`**. Der Quellenvergleich von Runtime, Daten, Assets, Projekt und Exportpresets gegen das veröffentlichte `fde508e` war leer; das tatsächlich verwendete Artefakt bleibt dennoch ausdrücklich mit seiner eigenen `2b8ea627`-Kennung benannt. Beide Engines bearbeiteten und speicherten ein Deck über die echte alte Oberfläche, wechselten unter derselben lokalen Origin ohne Zustandsinjektion zum Kandidaten und bestätigten stabile Karten-IDs/Reihenfolge, Einstellungen, unveränderte alte Quelldatei und byteidentische Importsicherung.

Ein schon **vor der v2-Existenz gestarteter alter Tab** schrieb anschließend sein vollständiges altes Dateisystem zurück. Der Bericht bestätigt in beiden Engines, dass dadurch die sekundäre v2-IDBFS-Datei tatsächlich fehlte (`present=false`). Die unabhängige v2-Primärsicherung behielt trotzdem das echte Deck mit **`of-houses-001`** und seine Einstellungen; nach Neuladen wurde damit eine tatsächliche neue Partie begonnen. Reale separate Speicherfüllung mit **5.241.341 Zeichen** erreichte außerdem die Browserquota; das nächste Zeichen wurde abgewiesen, und der fehlgeschlagene neue Decksave erhielt Primärsicherung, Backup und In-Memory-Slots. Dies ist ein lokaler automatisierter Browsernachweis dieses Kandidaten, kein physischer iPhone-/Android-Test und kein Nachweis einer Veröffentlichung oder eines später veränderten Releasecommits.
