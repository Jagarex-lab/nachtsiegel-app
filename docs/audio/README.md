# ORAFOLD · Audiopaket

Dieses Paket ist eigenständig nutzbar. Die produktive Alpha-Shell verwendet es
noch nicht. Kampf-, Effekt-, Trigger- und Ressourcen-Engine, Karten und zentrale
UI-Dateien bleiben unverändert. Kein Merge und kein produktiver Release.

## Anhören und einstellen

Nach einem Godot-Import mit Godot 4.6.3:

```sh
godot --editor --path . --import --quit
godot --path . assets/audio/audio_preview.tscn
```

Das Klangstudio bietet Ereignisse, Macht-/Seltenheitsschichten, Musik und vier
persistente Lautstärkeregler, Mute und reduzierte Intensität. Die Vorschau stoppt
den alten `GameAudio`-Autoload ausschließlich in dieser separaten Szene.
Die spätere Produktintegration muss einen einzigen Audioeigentümer festlegen.

## Lieferumfang

| Paket | Umsetzung | Produktintegration |
| --- | --- | --- |
| A · Audit/Architektur | Zentraler Manager, eigene Busse, 52 datengetriebene Ereignisse | Autoloadwechsel vorbereitet |
| B · Grundlagen | Karten, UI, Angriff/Treffer, Schutz, Block, Heilung | Präsentationshooks offen |
| C · Mächte/Resonanz | Vier Machtakzente, Resonanzstufen, Relikte, Seltenheiten | Bestätigte Metadaten/Schwellen vom Aufrufer erforderlich |
| D · Musik | Neun echte Stücke, Crossfades, ein Ambience-Loop | Szenen-/Musikkontexte offen |
| E · Einstellungen/Performance | Wiederverwendbare Settings-UI, Persistenz, fester Pool, Lebenszyklus-API | Zentrale UI und Profilübernahme offen |
| F · QA/Integration | Isolierte Tests, Export-/Browserfixture, Schnittstellendokumentation | Hörabnahme und physische Geräteprüfungen offen |

153 SFX-Dateien enthalten 146 Ereignisvarianten, vier Machtakzente und drei
Seltenheitsakzente. Neun Musikdateien enthalten sieben Loops und zwei
Ergebnis-Stinger. Hinzu kommt eine Ambience-Datei. Alle 163 Dateien sind echte,
lokal synthetisierte WAV-/Vorbis-Dateien (7.914.598 Bytes). Kein externer
Audioinhalt, kein Webdienst zur Laufzeit. Eine konkrete legendäre Karte erhält
erst nach späterer Zuordnung eine individuelle Signatur.

## Entwickeln und prüfen

```sh
# Python 3, NumPy, FFmpeg und Godot erforderlich
bash tests/audio/run.sh
# Nur Assets dekodieren und messen
python3 tests/audio/validate_assets.py --report work/audio/asset-results.json
# Nur bei bewusster Assetneuproduktion; verändert Dateien/Kataloge
python3 scripts/audio/generate_audio.py
```

- [Audit](AUDIO-AUDIT.md): Bestand, aktive Branches/PRs, Risiken.
- [Ereignisse](AUDIO-EVENTS.md): IDs und Aufrufvertrag.
- [Integration](AUDIO-INTEGRATION.md): kleiner separater Aktivierungsschritt.
- [Klangstil](AUDIO-STYLE-GUIDE.md): Mächte, Musik, Materialien und Mixbudget.
- [Assets und Rechte](AUDIO-LICENSES.md): Generator, Herkunft, per-Datei-Hashes.
- [QA](AUDIO-QA.md): tatsächliche Nachweise und offene Abnahmen.

Audioverfügbarkeit darf niemals die Gültigkeit oder Ausführung eines Spielzugs
bestimmen. `play_event()` liefert ausschließlich einen Audiostatus. Keine
Schwellen, Regeln, Schadensberechnungen oder Kartenwerte gehören in dieses Modul.
