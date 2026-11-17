# ORAFOLD Web-App, Vollbild und Wiederaufnahme

Status: implementiert; lokale Vertrags- und Headless-Tests bestanden. Die integrierte Browser-/Webexport-Abnahme ist zusätzlich erforderlich. Kein Merge, keine Veröffentlichung und keine Änderung der GitHub-Freigabesperre gehören zu diesem Paket.

## Tatsächliches Verhalten

Der Alpha-Exporter ergänzt nach `build-info.json` mit `tools/premium/stage_pwa.py` ein relatives Manifest (`id`, `start_url`, `scope`: `./`), `display: standalone`, 192-/512-Pixel-App-Icons, ein 180-Pixel-Apple-Touch-Icon und einen an den vollständigen Quellcommit gebundenen Service Worker. Es gibt absichtlich keinen `orientation`-Lock: Menüs und Deckbuilder bleiben im Hochformat bedienbar. Alle URLs funktionieren unter `/nachtsiegel-app/` und auf einem isolierten Testserver.

Die Icons werden reproduzierbar mit Python-Standardbibliothek erzeugt. Das geometrische Motiv leitet sich aus dem bereits vorhandenen Projektzeichen `assets/icon.svg` ab; es verwendet keine neuen fremden Bildquellen. Sie sind App-Symbole und keine Kartenillustrationen. Die geometrische Erzeugung ist in `stage_pwa.py` nachvollziehbar.

Der Service Worker speichert ausschließlich drei kleine Branding-Bilder. HTML, Build-Metadaten, Godot-JavaScript, WebAssembly, PCK und Kartenillustrationen werden **nicht** durch diesen Worker zwischengespeichert. Navigationen und `build-info.json` innerhalb seines eigenen URL-Bereichs werden ausdrücklich mit `cache: 'no-store'` geladen. Dadurch soll ein später ersetzter Pages-Build keinen alten HTML-Einstieg aus dem HTTP-Cache verwenden, dessen frühere commitgebundene WASM-/PCK-Dateien bereits entfernt wurden. Die tatsächliche integrierte Versionswechselprüfung bleibt zusätzlich erforderlich.

Normale Requests für commitgebundene Godot-Dateien und Illustrationen behalten ihre vorhandene Browser-/HTTP-Auslieferung; der Worker fängt sie nicht ab und legt sie nicht im Cache Storage ab. Es gibt keinen Rückfall auf eine alte offlinegespeicherte Spielversion. Ein Netzwerkfehler lehnt die jeweilige Navigation oder Metadatenanfrage ab und löst weder einen erzwungenen Reload noch eine Nachricht oder eine Zustandsänderung in einer bereits laufenden Partie aus. Fremde Origins, benachbarte URL-Bereiche und Nicht-GET-Requests bleiben unberührt.

Damit entsteht weder ein unbeschränkter 550-Bilder-Offlinecache noch ein vom Worker zusammengemischter alter/neuer Engine-Export. Er löscht ausschließlich eigene alte `orafold-brand-*`-Caches. Spielstände und andere Caches bleiben unangetastet. **Für den Spielstart und für Illustrationen ist weiterhin Internet erforderlich.** Eine installierbare Web-App ist keine Zusage vollständiger Offline-Spielbarkeit.

Die bestehenden `ORAFOLD_VIEWPORT_BEGIN/END`-Safari-Korrekturen bleiben bytegleich gegenüber Develop `10782185cf41f2013607ba47da0bbfcb737e89e2`. Die neue App-API entscheidet nicht über die Orientierung, ruft keinen Orientation-Lock auf und dreht keinen Canvas.

## Bedienung

Unter Einstellungen stehen „Vollbild“ und „Installation / App-Modus“. Auf unterstützten Desktop-/Android-Browsern ruft die Schaltfläche die Fullscreen API aus der unmittelbaren Benutzergeste auf. Ablehnung wird erklärt; das Spiel bleibt bedienbar. „Vollbild beenden“ beziehungsweise die Browsersteuerung beendet diesen Modus.

Auf iPhone/iPad verweist die Hilfe auf **Safari → Teilen → Zum Home-Bildschirm**, gegebenenfalls **Als Web-App öffnen**. Safari darf die Installation oder den Vollbildmodus einschränken; das Spiel verspricht keinen erzwungenen Webseiten-Vollbildmodus. Ein echtes `beforeinstallprompt`-Angebot auf unterstützten Browsern aktiviert eine ausdrückliche Installationsschaltfläche. Es werden keine gefälschten Installationsdialoge angezeigt.

Browser und installierte Web-App können insbesondere unter iOS getrennte Speicherbereiche besitzen. Deshalb erklärt die Hilfe, eine laufende Partie im selben Browser/App-Modus fortzusetzen. Die Web-App wird über das neue ORAFOLD-App-Symbol gestartet.

## Laufende KI-Partie erhalten

`scripts/premium/duel_checkpoint.gd` speichert ein versioniertes lokales **Replay-Journal**, keinen ungeprüften rohen Modellzustand. Der produktive `Session`-/Kampfcode bleibt unverändert. Nach einer Aktion sowie beim Fokusverlust, App-Hintergrundwechsel und Verlassen der Szene wird ein Checkpoint versucht; ein sparsamer Prozesspoll deckt auch den Spielstart ab. Rotation verändert das laufende Modell nicht.

Nach Reload startet weiterhin das Hauptmenü. Bei vorhandenem Checkpoint erscheint **PARTIE FORTSETZEN**. Die gesamte Befehlsfolge wird gegen das bestehende `Session.replay()` einschließlich Zustand, Katalogfingerprint und Ereignisprüfsumme validiert. Erst anschließend werden die echte Engine und ihr RNG durch dieselben Befehle rekonstruiert. Dadurch bleiben Ziehreihenfolge, Effektketten, Ursprung, Zweite Möglichkeit und Mulligan erhalten. Die Wiederaufnahme vergibt keine Siege oder Belohnungen. Ein beendetes Duell entfernt seinen Checkpoint; normale Belohnungsbelege bleiben Sache der bereits integrierten Services.

Web-Key: `orafold.active-duel.v1`; native Datei: `user://orafold_active_duel_v1.json`. Eine erkannte Änderung durch eine andere Instanz verhindert das Überschreiben des abweichenden Speicherstands. Vor der Replayprüfung und unmittelbar vor Übernahme der rekonstruierten Engine wird erneut geprüft, ob die gespeicherten Bytes noch übereinstimmen. Ein überholter Menüstand kann dadurch keine alte Partie wiederaufnehmen; das aktuelle Live-Modell bleibt bei Konflikt unverändert. Der Profilzähler für zukünftige Match-Seeds wird bei Wiederaufnahme nicht zurückgesetzt, während die Engine ihren ursprünglichen Seed und RNG behält.

Quoten-/Berechtigungsfehler blockieren keine Züge. Nach einem fehlgeschlagenen Checkpoint wird für dasselbe Journal zunächst eine Sekunde und nach wiederholten Fehlschlägen höchstens 30 Sekunden bis zum nächsten Versuch gewartet. Der Poll im Abstand von 0,2 Sekunden serialisiert deshalb nicht ständig die vollständige Partie. Eine neue tatsächlich protokollierte Aktion erlaubt sofort einen neuen Speicherversuch; die Warnung bleibt bis zu einer erfolgreichen Speicherung erhalten. Konflikte mit einer anderen Instanz sperren weitere automatische Schreibversuche und verweisen auf Neuladen. Beschädigte, veränderte, unbekannte oder zukünftige Formate bleiben erhalten und werden ausdrücklich nicht stillschweigend als gültige Partie interpretiert. Sie blockieren automatisches Überschreiben dieses Checkpoints.

Dieser lokale Abgleich erkennt zwischenzeitlich geänderte Bytes. Er ist keine serverautorisierte Transaktion und keine prozessübergreifende Dateisperre. Ein anderer Schreiber unmittelbar nach der letzten Prüfung kann durch lokale Speicherung allein nicht ausgeschlossen werden. Die vorhandenen Belohnungsbelege bleiben idempotent; das lokale Journal ist weiterhin keine Grundlage für vertrauenswürdige Konten oder Echtgeldbestände.

Grenzen: höchstens 4.096 Journalbefehle und 2 MiB pro Checkpoint. Eine darüber hinausgehende Partie bleibt aktuell spielbar; die lokale Wiederaufnahme ist dann ausdrücklich eingeschränkt. Ein lokaler Checkpoint ist keine serverautorisierte Grundlage für Echtgeld oder kompetitive Wertungen. Lokale Daten können vom Gerätebesitzer manipuliert oder gelöscht werden. Der Schutz ersetzt keine serverseitige Autorität.

## Nachweise und reproduzierbare Befehle

```sh
node --test tools/premium/test_pwa.cjs
node --test tools/premium/test_worker.cjs
python3 -m unittest discover -s tools/premium -p 'test_stage_pwa.py' -v
godot --headless --path . --audio-driver Dummy --script tools/premium/test_duel_checkpoint.gd
```

- Node: **7/7** Gruppen bestanden. Fullscreen ein/aus, Ablehnung, fehlende iOS-API, iPadOS-/Standalone-Erkennung, einzelnes echtes Browserangebot als Vertragsfixture, sichere Worker-Aktivierung und unveränderter Safari-Viewportblock.
- Worker-Vertrag: **7/7** Node-Gruppen bestanden. Tatsächliche Request-Weitergabe mit `no-store` für Navigation und Metadaten, unveränderte Lieferung von WASM/PCK/JS/Bildern, Scope-/Methodengrenzen, begrenzter Brandingcache und Netzwerkfehler ohne Eingriff in laufende Clients. Diese VM-Tests ersetzen keine echte Browser-/PWA-Geräteprüfung.
- Python: **3/3** Tests bestanden. Manifest/relative Scope, alle drei echten PNG-Abmessungen, Commitbindung, begrenzte Cacheinhalte, reproduzierbare Icons und ungültige Commit-Ablehnung.
- Godot 4.6.3 Headless: **46 Assertions, 0 Fehler**. Öffnungszustand, Mulligan/Ursprung, Speichern/Laden, vollständiger Zustand, RNG-Zustand und Aufrufzahl, geordnete Ereignisse, erneut verifizierbares Replay, keine zusätzlichen Siege, veraltete Schreiber, korrupte/veränderte/zukünftige Daten, Löschen und Shell-Parsing. Die unabhängige Nachprüfung ergänzt Konflikte vor und nach der Replayprüfung, unveränderte Live-Session bei Konflikten, monotone zukünftige Match-Seeds, wiederholte Schreibfehler mit deterministischer Uhr, sofortigen Versuch nach neuer Aktion und erfolgreiche Speichererholung.
- Ein erster Testlauf schlug wegen eines im Test fälschlich angenommenen `rng.snapshot()`-Hilfsaufrufs fehl; der Test prüft jetzt die tatsächlich vorhandenen Felder `state` und `calls`. Ein zweiter Lauf deckte eine rohe JSON-Integer-/Float-Gleichheit im Test auf; die stärkere Prüfung validiert das gesamte wieder exportierte Journal mit `Session.replay()`. Diese beiden Testfehler wurden behoben, ohne Produktionsregeln oder Replay-Validierung zu ändern.

Das sind keine physischen iPhone-/Android-Installations- oder Gerätetests. Tatsächliches OS-Installieren, App-Switching, Safari-Home-Indicator sowie Geräte-Leistung bleiben der integrierten Browserprüfung und danach der physischen Geräteabnahme vorbehalten.

## Öffentliche Test-API (nur Darstellung)

`window.orafoldApp.state()` liefert `version`, `standalone`, `ios`, `fullscreen`, `fullscreenSupported`, `installAvailable`, `status`. Die Schreiboperationen `toggleFullscreen()` und `install()` betreffen ausschließlich Browserdarstellung/Installation und ändern keine Spielregeln. Bestehende read-only Godot-QA-Daten behalten ihre Bedeutung.

QA-Schaltflächen: `app_fullscreen`, `app_install`, gegebenenfalls `app_install_confirm`; im Hauptmenü `resume_duel`. Es gibt keine neuen Spielzustands-Mutationshooks für Browser-QA.
