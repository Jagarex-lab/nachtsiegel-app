# ORAFOLD · Audio-QA

Prüfdatum: 2026-11-10. Basis: `develop` bei
`17121e40a49838f479d1655d88d354ed836ad20e`. Godot 4.6.3, Linux.
Die Ergebnisse gelten für das isolierte Audiopaket, nicht für eine bereits
aktivierte Produktintegration.

## Automatisiert geprüft

| Prüfung | Ergebnis | Nachweis |
| --- | --- | --- |
| AudioManager/Router/Musik | 389 Assertions, 0 Fehler | [runtime.log](evidence/runtime.log), [Messwerte](evidence/runtime-results.json) |
| Klangstudio/Einstellungen | 28 Assertions, 0 Fehler | [preview.log](evidence/preview.log) |
| Dekodierung und Assetkatalog | 3.117 Prüfungen, 0 Fehler; alle 163 Dateien | [Assetbericht](evidence/asset-results.json) |
| Bestehende Alpha-Regeln | 1.704 Assertions, 0 Fehler; 64 vollständige KI-Simulationen | [alpha-rules.log](evidence/alpha-rules.log) |
| Bestehende Replay-Prüfung | 173 Assertions, 0 Fehler | [alpha-replay.log](evidence/alpha-replay.log) |
| Bestehende Node-Daten-/Kartenverträge | 43 Tests bestanden | [base-node.log](evidence/base-node.log) |
| Bestehender Release-Schutz | 8 Tests bestanden | [release-safety.log](evidence/release-safety.log) |

`bash tests/audio/run.sh` importiert das Projekt, führt Laufzeit/Vorschau mit
dem Dummy-Treiber aus und dekodiert alle Assets mit FFmpeg. Godot-Fehler oder
Ressourcenlecks in den Laufzeit-/Vorschaulogs lassen den Runner fehlschlagen.
Editor-Debug-/LSP-Server konnten in der Sandbox keine lokalen TCP-Sockets
öffnen; der Import wurde trotzdem abgeschlossen. Das ist kein Nachweis für
einen Audiofehler. Ein erster bestehender Regeltestlauf benötigte das vom
üblichen Wrapper angelegte Verzeichnis `work/alpha/`; nach dessen Anlage
bestanden die unveränderten Tests. Node-Unterprozesse waren zunächst durch
die Sandbox gesperrt (`EPERM`); die Wiederholung außerhalb dieser Sperre
bestand. Keine Produktions- oder Testlogik wurde dafür geändert.

Die Tests prüfen insbesondere sämtliche Ereignisse und Musikdateien,
Fraktions-/Seltenheitslayer, direkte Variantenwiederholung, Cooldowns,
Mehrfachauslösung, feste Poolgrenzen, ungültige Namen/Dateien/Kataloge,
NaN-/Infinity-Eingaben, Lautstärke/Mute/reduzierte Intensität,
Speicherung/Version/Fehleranzeige, gleitende Buspegel, Musik-Crossfades und
rasche Kontextwechsel sowie Ambience und manuelle/Fokus-/App-Pausierung.
Eine fehlende Audiodatei liefert einen Audiostatus zurück und löst keinen
Modellbefehl aus. Das Modul importiert keine Gameplaymodelle.

Die Assetprüfung kontrolliert Dateiverweise und Herkunftshashes, tatsächliche
Dekodierung, Spitzenpegel, Clipping, Ränder, relative Loopnaht, Dauer, Kanäle,
Samplerate und Größenbudget. Kontinuierliche Loops dürfen am periodischen
Schnitt einen von null verschiedenen Pegel haben; entscheidend sind die
relative Naht und der Startfade. Dies ersetzt keinen Hörtest.

## Export- und Browsernachweise

Der tatsächlich exportierte Linuxbuild besteht sieben Smokeprüfungen:
[native-export-test.log](evidence/native-export-test.log). Web und Linux
wurden aus einem separat gestagten Projekt erzeugt, ohne produktive
Projekt-/Exportdateien anzupassen. Der Webexport benötigte im Fixture die
ETC2-Importoption passend zu dessen Mobile-Exportoption; Godot meldete diesen
anfänglichen Konfigurationsfehler ohne erläuternden Text. Finale Exporte:
[Web](evidence/web-export.log), [Linux](evidence/linux-export.log).

| Browserprofil | Ergebnis | Echter Audioausgang nach Geste | Nachweis |
| --- | --- | --- | --- |
| Chromium Desktop | 10 Prüfgruppen bestanden | 44,1 kHz; RMS 0,012707; Peak 0,042145 | [chromium.json](evidence/chromium.json) |
| Chromium Pixel-7-Emulation, CPU 4× gedrosselt | 10 Prüfgruppen bestanden | 44,1 kHz; RMS 0,003888; Peak 0,038010 | [android.json](evidence/android.json) |
| WebKit/iPhone-Emulation | Lokal blockiert vor Browserstart | Kein Signaltest möglich | [webkit.json](evidence/webkit.json) |

Geprüft wurden gesperrte Ereignisse vor Nutzergeste, Freigabe durch echten
Maus-/Touchinput, ungültige Ereignisse, tatsächlicher AudioContext und
messbarer gemischter Ausgang, schnelle Crossfades, Poolburst, Suspend/Resume,
echte Stille bei Mute und Wiederaufnahme, sofortiger Reload mit beiden
Einstellungen, verweigerter Browserspeicher samt Erholung und Erhalt einer
unbekannten zukünftigen Mirrorversion. Die Analyserbeobachtung ersetzt den
Audioausgang nicht; ein zusätzlicher Beobachtungszweig ist stumm geschaltet.
Gemessener Mute-RMS: exakt 0 in beiden Profilen. Vor der Geste darf der
Browser selbst bereits einen laufenden AudioContext bereitstellen; der
Manager bleibt trotzdem gesperrt und produziert kein Signal.

Die Exportprüfung fand und korrigierte zwei echte Probleme: Der Web-Samplepfad
lieferte bei aktiven Playern Stille ([vorheriger Befund](evidence/browser-before-stream.json));
alle Player verwenden nun explizit `PLAYBACK_TYPE_STREAM`, damit Mixbusse,
Lautstärkeautomation und Limiter konsistent greifen. Außerdem war ein letzter
ConfigFile-Wert bei sofortigem Reload noch nicht im asynchronen IDBFS
angekommen. Ein synchroner, streng versionierter localStorage-Mirror in einem
eigenen, nach `settings_path` getrennten Namespace behebt dies. Fehlerhafte oder
zukünftige Mirrors werden nicht überschrieben. Der tatsächliche Webtest fand
auch den JS-Bridge-Bool/Int-Rückgabetypfall; der Bridgevertrag verwendet jetzt
einen explizit geprüften String. Beide finalen Browserläufe haben keine
JavaScript-/Godot-Laufzeitfehler.

WebKit 26.5 wurde mit Playwright 1.62.1 heruntergeladen und sein Start versucht.
Es fehlen `libgtk-4.so.1`, `libgraphene-1.0.so.0`, `libharfbuzz-icu.so.0`,
`libmanette-0.2.so.0`, `libhyphen.so.0` und `libGLESv2.so.2`. Ein lokaler
Paketdownload konnte mangels verfügbarer APT-Paketindizes keine Pakete auflösen.
Kein lokaler WebKit-/Safari-Erfolg wird behauptet. Die eigenständige
`.github/workflows/audio-qa.yml` installiert Browserabhängigkeiten auf einem
frischen Runner und führt alle drei Profile aus; deren finale CI-Ergebnisse
sind gesondert am PR zu prüfen, keine vorweggenommene grüne CI-Abnahme.

Reproduktion mit Godot 4.6.3 und passenden offiziellen Exporttemplates:

```sh
python3 tests/audio/build_fixture.py
godot --headless --editor --import --path work/audio/fixture --quit
godot --headless --path work/audio/fixture --export-debug 'Audio Web QA'
godot --headless --path work/audio/fixture --export-debug 'Audio Linux QA'
work/audio/fixture/build/audio-qa.x86_64 --headless --audio-driver Dummy -- --audio-fixture-native
# In einem weiteren Terminal:
python3 -m http.server 8765 --bind 127.0.0.1 --directory work/audio/fixture/build/web
# Playwright 1.62.1 + Browser erforderlich; CHROMIUM_PATH ggf. setzen:
AUDIO_QA_PROFILE=chromium node tests/audio/browser_smoke.mjs
AUDIO_QA_PROFILE=android node tests/audio/browser_smoke.mjs
AUDIO_QA_PROFILE=webkit node tests/audio/browser_smoke.mjs
```

## Performance

Der archivierte Lauf verarbeitet 10.000 Dispatchversuche in **64,14 ms** auf
dem bereitgestellten Linuxhost. Dies ist ein Überlastungs-/Pooltest:
überzählige Aufrufe werden verworfen, es sind nicht 10.000 gleichzeitig
dekodierte Sounds. Maximal 16 Effektstimmen, zwei Musikplayer und ein
Ambienceplayer. Optionale Layer teilen sich das Effektbudget; vier Plätze
bleiben für primäre Ereignisse reserviert. Es entstehen keine neuen Player
pro Ereignis und keine unbeschränkte Warteschlange.

Der vollständige neue Pack belegt **7.914.598 Bytes**: 7.024.972 Bytes SFX,
800.217 Bytes Musik und 89.409 Bytes Ambience. Die Prüfdekodierung aller
Nicht-Musikdateien ergibt 24.276.480 Bytes Float-PCM; dies ist eine
Validator-Messung einschließlich Ambience, keine gemessene Prozess-RSS.
Der Browser-Roundtrip für 200 Burstversuche betrug 83,15 ms auf Desktop und
181,21 ms im 4× gedrosselten Androidprofil. Diese Werte enthalten
Browserautomation und Rendering; sie sind keine Audio-Ausgabelatenz.
Kurze WAVs werden gecacht, lange Vorbis-Dateien nur bei Bedarf geladen und
inkrementell dekodiert. Der Manager hat keine permanente `_process`-Schleife;
der Musikcontroller verarbeitet ausschließlich aktive Übergänge und stoppt
dies bei Suspension. Die Integration muss auch die Spielpause explizit über
`set_suspended()` weiterreichen.

Keine Aussage über akustische End-to-End-Latenz, mobilen Energieverbrauch,
Audio-Thread-CPU oder Speicher auf einem physischen Zielgerät.

## Manuelle Prüfung und Integrationsstatus

Quellcode, Dateiumfang, Ereignisverträge und Prüfprotokolle wurden geprüft.
Eine subjektive Hörabnahme durch Menschen wurde nicht durchgeführt. Die
numerische Klang-/Mixauslegung ist eine erste produzierte Bibliothek, keine
behauptete finale Mastering-Freigabe.

Noch nicht integriert: produktiver Autoload, zentrale Einstellungsoberfläche,
bestätigte Präsentationsereignisse, Szenen-/Musikkontexte und Exportfilter.
[AUDIO-INTEGRATION.md](AUDIO-INTEGRATION.md) beschreibt den kleinen
separaten Folge-PR. Es wurden keine Kampf-/Effekt-/Trigger-/Ressourcen-Dateien,
Regeln, Kartenwerte, zentralen UI-Szenen oder bisherigen Assets verändert.

Offene Geräteabnahme: Mobile Safari auf iPhone/iPad, physische
Android-Browser/native Android-Builds, spätere native iOS-Builds,
Telefonunterbrechung, Headset-/Bluetooth-/Lautsprecherwechsel, schwache
Mobilhardware, wahrgenommene Latenz und längere Ermüdungs-/Mixprüfung.
Emulierte Browserprofile ersetzen diese Prüfungen nicht.
