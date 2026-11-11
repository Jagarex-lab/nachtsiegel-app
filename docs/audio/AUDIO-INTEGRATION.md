# ORAFOLD – Separater Integrationsschritt

> Produktaktivierung und aktueller Integrationsumfang: [PRODUCTION-INTEGRATION.md](PRODUCTION-INTEGRATION.md). Dieser Liefertext dokumentiert den ursprünglichen isolierten Paketstand.

Status dieses Feature-Pakets: Assets und Audioruntime sind isoliert nutzbar.
Die produktive Alpha-Shell, Kampf-/Effekt-Engine, Kartenwerte, zentrale
UI-Szenen, Projektkonfiguration und Exportpresets wurden nicht geändert.
Der nachfolgende kleine Folge-PR kann nach Abstimmung mit den parallelen
UI-/Präsentationsaufträgen aktiviert werden. Kein Merge oder Release ist
hiermit angefordert.

## 1. Einen Audioeigentümer festlegen

`project.godot` lädt aktuell `GameAudio` aus `scripts/game_audio.gd`.
Der alte Autoload startet `atmosphere.ogg` bei der ersten Nutzerinteraktion,
auch wenn die Alpha-Shell selbst keine Audiohooks besitzt. Deshalb nicht
zusätzlich kommentarlos einen zweiten Manager einschalten.

Bei der späteren Integration den alten Autoload durch
`res://scripts/audio/audio_manager.gd` unter dem Namen `AudioManager` ersetzen
und die verbleibenden Archivaufrufe entweder gezielt auf einen dünnen
Kompatibilitätsadapter umstellen oder im Archiv weiterhin exklusiv den alten
Manager einsetzen. Beide Manager dürfen nicht zugleich die Produktmusik
besitzen. Das neue Modul verwendet eigene `ORAFOLD …`-Busse und ändert nicht
die alten globalen `Music`-/`SFX`-/`UI`-Gains. Der eigene Rootbus hat einen
Limiter mit −1 dB Decke; diese Schutzmaßnahme ersetzt keine Hör-/Mischabnahme.
Das feste Budget beträgt 16 Effektstimmen inklusive Schichten, zwei
Musikplayer und einen Umgebungsplayer.

Die gelieferte isolierte Hörvorschau startet mit:

```sh
godot --path . assets/audio/audio_preview.tscn
```

Sie deaktiviert ausschließlich für diese Vorschau den Inputhandler und die
Wiedergabe des alten `GameAudio` und bietet alle Ereignisse, Fraktionen,
Seltenheiten, Intensitäten, Musik und Umgebung sowie das Einstellpanel an.
Das ist noch keine manuelle Hörabnahme.

Ein anderer isolierter Aufrufer benötigt keinen Autoload:

```gdscript
const AudioRuntime = preload("res://scripts/audio/audio_manager.gd")
var audio: Node

func _ready() -> void:
    audio = AudioRuntime.new()
    audio.name = "AudioManager"
    add_child(audio)
    # Erst nach _ready / Kataloginitialisierung auslösen.
    audio.play_event("card.draw")
```

Das funktioniert als eigenständiger QA-Aufbau. Ein normaler Projektstart mit
unverändertem altem Autoload ist noch keine abgeschlossene Produktintegration.

## 2. Exportdaten explizit einschließen

In jedem tatsächlich verwendeten Eintrag von `export_presets.cfg` muss
`data/audio/*.json` zum vorhandenen `include_filter` ergänzt werden.
`all_resources` garantiert die Mitnahme beliebiger JSON-Dateien nicht.
Danach den exportierten Build starten und Katalog/Asset-Ladung prüfen.
Quellprojekt und erfolgreicher Editorimport allein belegen das nicht.

Die Audiodateien bleiben unter `assets/audio/`; kurze WAV-Cues werden
vorbereitet geladen, lange Vorbis-Musik wird gestreamt. Importmetadaten und
Loopkennzeichen gehören zu den gelieferten Assets. Nicht unkontrolliert alle
WAVs neu normalisieren oder auf Loops trimmen.

## 3. Bestätigte Präsentationsereignisse weiterreichen

Der Adapter `scripts/audio/sound_event_router.gd` bietet die schmale Grenze.
Nur bereits aufgelöste Ereignisse mit bekannten Metadaten weiterreichen;
keine Modellmutation, keine Abhängigkeit des Regelmodells vom Audiosystem,
kein `await` in einer Kampfaktion. Der Rückgabewert betrifft ausschließlich
Audioverfügbarkeit.

In der aktuellen Alpha-Präsentation ist
`scripts/alpha/shell.gd::_feedback_events()` ein möglicher Integrationsort.
Er verarbeitet geordnete Modellereignisse bereits für visuelle Effekte.
Diese Datei wird hier ausdrücklich nicht geändert.

```gdscript
const Router = preload("res://scripts/audio/sound_event_router.gd")
var audio_router = Router.new(audio_manager)
# Nach erfolgreicher fachlicher Auflösung, ohne await:
audio_router.route("creature.attack", {"faction": "stillwatch", "intensity": 0.6})
``` Folgende Zuordnungen sind
Vorschläge zur Prüfung durch deren Eigentümer, keine neue Engine-ABI:

| Vorhandenes Präsentationssignal | Mögliches Audioereignis | Vorbedingung |
| --- | --- | --- |
| `draw_finished` / `effect_draw` | `card.draw` | Tatsächlich hinzugefügte Karten; nicht beide Ebenen doppelt melden. |
| `summon` | `creature.summon` | Bereits bestätigte Weseninstanz und passende Macht bekannt. |
| `attack` | `creature.attack` | Aufgelöster Angriff, Intensität explizit ausgewählt. |
| `unit_hit` / `strike_hit` | `creature.hit` | Tatsächlich sichtbarer Treffer, Ziel/Wirkung nicht erraten. |
| `hero_hit` | `hero.damage` | Tatsächlicher LP-Schaden; Block/Schild getrennt. |
| `death` | `creature.defeated` | Einmal pro bestätigter Instanz; kein doppeltes Ableiten aus HP-Differenzen. |
| `recall` | `creature.return` | Aufgelöste Rückkehr, nicht bloße Kartenbewegung. |
| `shift` / `tactical_move` | `combat.path_change` | Tatsächlich bestätigter Wechsel. |
| `convergence_declared` | `convergence.prepare` | Gültige bestätigte Erklärung. |
| `convergence_win` | `convergence.complete` | Bereits bestätigtes Ergebnis. |
| `convergence_failed` | `convergence.interrupt` | Nur wenn diese Semantik fachlich bestätigt ist. |

Die aktuelle visuelle Alpha-Auswertung addiert sinkende `ward`- und `block`-
Werte zu einem gemeinsamen Absorptionsbild. Audio darf daraus nicht automatisch
zwei fachlich verschiedene Ereignisse ableiten. Schild und Block benötigen
getrennt bestätigte Ereignisse oder vom Präsentationssystem geprüfte Metadaten.
Auch das vorhandene generische `event` enthält noch keine belastbare
Impuls-/Relikt-Audiozuordnung ohne zusätzlichen Kontext.

UI-Hover, Auswahl und Kartenvergrößerung gehören direkt an die jeweiligen
Präsentationsaktionen. Hohe Wiederholungsraten werden im Katalog begrenzt.
Macht-Aliase: `houses` → `zwoelf_haeuser`, `stillwatch` → `stillwacht`,
`morph` → `vielgestalt`, `ninth` → `neunte_stunde`; `neutral` bleibt neutral.
`common`, `rare`, `epic`, `legendary` sind Audiovarianten. Bestehende Karten
werden dadurch weder erweitert noch umklassifiziert.

Resonanzstufen, kritische/außergewöhnliche Treffer, Bedrohungsniveau und
Musikzustände müssen vom bestehenden fachlich zuständigen System explizit
kommen. Das Audiomodul setzt keine eigenen Schadens-, LP- oder Resonanzschwellen.
Noch fehlende Ereignisse dürfen zunächst unverbunden bleiben.

## 4. Einstellungen und Profildaten

Das neue System speichert `user://orafold_audio_v1.cfg` als versioniertes
ConfigFile (`[audio]`, `version=1`). Das alte
`progress_v1.json` und dessen Web-Mirror bleiben unangetastet. Beim späteren
Produktwechsel alte Werte einmalig und explizit übernehmen, soweit ihre
Bedeutung identisch ist: `Music` → Musik, `SFX` → Effekte; der alte separate
UI-Gain kann nicht ohne Produktentscheidung verlustfrei in den gemeinsamen
Effektregler eingehen. Der neue Gesamtregler, Umgebung, Mute und reduzierte
Intensität erhalten eigene Defaults.

Im Web ergänzt ein synchroner localStorage-Mirror das asynchron persistierte
ConfigFile. Sein eigener Schlüssel beginnt mit `orafold.audio.v1:` und enthält
den SHA-256 des Settingspfads; er berührt keine Gameplay-Speicherwerte.
Nur vollständige, streng typisierte Version-1-Daten werden übernommen.
Unbekannte/ungültige Mirrors bleiben erhalten und blockieren deren Überschreiben;
Speicherfehler werden gemeldet. Dies wurde einschließlich sofortigem Reload
und verweigertem Speicherzugriff im echten Webexport geprüft.

Der bereits vorhandene opt-in-Helfer
`audio.migrate_legacy_settings(old_audio_dictionary)` übernimmt nur `Music` und
`SFX`, liest oder verändert aber selbst kein altes Profil. Nur einmal bei einer
bewusst freigegebenen Migration aufrufen.

Die wiederverwendbare `scripts/audio/audio_settings_panel.gd` bindet vier
Regler sowie Mute/reduzierte Intensität an den Manager. Sie ist Bestandteil
der isolierten Vorschau, noch nicht Teil der zentralen Produktoberfläche.
Neue UI-Regler müssen die öffentliche Settings-API des Managers verwenden
und Speicherfehler als reine Einstellungsfehler darstellen. Öffentliche Methoden:
`set_volume("master"|"music"|"sfx"|"ambience", gain)`, `set_muted(bool)`,
`set_reduced_intensity(bool)`, `save_settings()`, `load_settings()`.
`settings_changed` übermittelt eine Kopie der Werte. Die Busse `ORAFOLD UI` und
`ORAFOLD SFX` teilen den Effektregler. `save_settings()` liefert einen Godot-
Fehlercode; `settings_save_failed(error)` meldet Fehler und
`snapshot().last_save_error` den letzten Speicherstatus. Das gelieferte Panel
zeigt fehlgeschlagene Speicherung und anschließende Erholung an. Der
Bool-Rückgabewert von `set_volume()` bestätigt die gültige Regleränderung,
nicht den Speichervorgang. Ein Speicherausfall
blockiert keine Spielaktion. Ein vorhandenes Profil darf bei fehlerhafter
Migration nicht überschrieben werden. Browserlöschung und verweigerte
localStorage-/IDBFS-Zugriffe sind in der Web-QA separat zu prüfen.

## 5. Web-/Mobile-Lebenszyklus und Musik

Die erste echte Nutzerinteraktion entsperrt Browseraudio. Der Produktaufrufer
kann `unlock_audio()` aus dieser Geste aufrufen; vor der Freigabe
werden keine alten Effektbursts nachgeholt. Menü-/Kampfmusik nur mit bereits
bekanntem Kontext anfordern. Bei Fokusverlust/Hintergrund muss Wiedergabe mit `set_suspended(true)`
suspendieren und der Audioprozess ruhen; bei Rückkehr nur erlaubte Musik
wiederaufnehmen. Die Godot-Lebenszyklushooks für Anwendungsfokus und Betriebssystem-Pause
sind implementiert. Der Manager nutzt bewusst `PROCESS_MODE_ALWAYS`, um
Rückkehrereignisse auch während einer pausierten Szene zu behandeln. Ein
alleiniges `get_tree().paused = true` stoppt deshalb dieses Modul nicht: Der
Spiel-Pausepfad muss zusätzlich `audio.set_suspended(true)` aufrufen und beim
Fortsetzen `audio.set_suspended(false)`. Das ist ein verpflichtender
Präsentationshook des späteren Integrationsschritts, keine neue Gameplaylogik.
Diese Hooks ersetzen keine Tests auf Mobile Safari, Android,
Telefonunterbrechungen und Gerätewechsel.

## 6. Abnahme des Folge-PRs

- Neue Audio-Suite, bestehende Daten-/Regel-/Replayregression und vorhandene
  Audio-Archivtests ausführen; keine neuen Regel- oder Modellabhängigkeiten.
- Exportfilter in echtem Web- und Native-Export prüfen; nach direktem Aufruf,
  erster Interaktion und Reload die geladenen Kataloge/Settings nachweisen.
- Keine Doppelmusik und keine doppelten Ereignisse; Menü, Deckbuilder,
  Duell, Konvergenz, Sieg/Niederlage und rasche Kontextwechsel hörprüfen.
- Master/Musik/Effekte/Umgebung, Mute, reduzierte Intensität, Persistenz,
  Fokuswechsel, explizite Spielpause/Resume, Voicebudget und fehlendes Asset prüfen.
- Physische iOS-/Android-Geräte, Latenz, Headset-/Lautsprecherwechsel und
  Anrufunterbrechung getrennt protokollieren. Emulation nicht als Geräteabnahme
  ausgeben.
- Den Feature-PR separat reviewen. Kein automatischer Merge nach `develop`
  und kein produktiver Pages-Release.
