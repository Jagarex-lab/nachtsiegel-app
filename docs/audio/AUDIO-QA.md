# ORAFOLD · Audio-QA

Prüfdatum: 2026-11-10. Basis: `develop` bei
`17121e40a49838f479d1655d88d354ed836ad20e`. Godot 4.6.3, Linux.
Die Ergebnisse gelten für das isolierte Audiopaket, nicht für eine bereits
aktivierte Produktintegration.

## Automatisiert geprüft

| Prüfung | Ergebnis | Nachweis |
| --- | --- | --- |
| AudioManager/Router/Musik | 332 Assertions, 0 Fehler | [runtime.log](evidence/runtime.log), [Messwerte](evidence/runtime-results.json) |
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

## Performance

Der archivierte Lauf verarbeitet 10.000 Dispatchversuche in **61,752 ms** auf
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
