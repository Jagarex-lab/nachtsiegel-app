# ORAFOLD – Audioereignisse

`data/audio/audio_events.json` ist der ausführbare Ereigniskatalog;
`data/audio/audio_catalog.json` ordnet Clip-IDs echten Dateien und
Musikkontexte ihren Streams zu. Dieser Text beschreibt die Integrationssemantik.
Audio wird erst nach einer bereits bestätigten Aktion oder einem bereits
aufgelösten Präsentationsereignis ausgelöst. Ein `false`-Ergebnis ist nur eine
Audioauslassung und darf weder Zug noch Animation oder Regelauflösung blockieren.

## Gemeinsamer Vertrag

```gdscript
var audio := get_node_or_null("/root/AudioManager")
if audio != null:
    audio.play_event("creature.attack", {
        "faction": "stillwacht",
        "intensity": 0.6,
        "rarity": "rare"
    })
```

| Kontext | Bedeutung |
| --- | --- |
| `faction` | Bereits bekannte Macht des auslösenden Objekts. Kanonisch: `zwoelf_haeuser`, `stillwacht`, `vielgestalt`, `neunte_stunde`, `neutral`. Adapterübersetzungen: `houses`, `stillwatch`, `morph`, `ninth`. Neutral erhält keine fünfte Signatur. |
| `intensity` | Bereits vom Präsentationssystem ausgewählte, auf 0–1 begrenzte Klangintensität. Keine Schadensberechnung oder Schwellenlogik im Audiomodul. Ohne Wert gilt eine moderate Vorgabe. |
| `rarity` | `common`, `rare`, `epic`, `legendary`. Verändert Schichtendichte, nicht Spielregeln. Seltene Karten werden nicht pauschal lauter. |

Nicht jedes Ereignis verwendet alle Schichten. Rasche UI-/Hoveraktionen bleiben
kurz und sparsam. Katalogeinträge bestimmen Varianten, Bus, Mindestabstand,
Stimmengrenze, Priorität, Grundpegel und moderate Tonhöhenvariation.
Priorität wird als Metadatum erfasst; bei vollem Pool werden neue Stimmen verworfen, ohne laufende Klangenden abzuschneiden. Die Variantenwahl besitzt ihren eigenen Zufallsgenerator und verändert keinen
Spiel-/Replay-Zufallszustand. Priorität ist eine Audioangabe, keine Regelaussage.

## Ereignisfamilien und Triggerzeitpunkt

| Familie | Ereignisse / Integrationsbedeutung |
| --- | --- |
| Oberfläche | `ui.hover`, `ui.select`, `ui.confirm`, `ui.cancel`, `ui.error` nur als UI-Feedback; keine Vermutung über erlaubte Spielzüge. |
| Karteninteraktion | `card.draw`, `card.hover`, `card.select`, `card.enlarge`, `card.move`, `card.return`, `card.play`, `card.discard`, `card.destroy`, `card.shuffle`. Ziehen erst nach bestätigtem Karteneingang, Return beim tatsächlichen Zurücklegen. |
| Kartentyp | `card.play.creature`, `card.play.impulse`, `card.play.relic` erhalten eigene Manifestations-/Eingriffs-/Gewichtssignaturen. Typ wird aus vorhandenen Daten übergeben; keine Änderung von Kosten oder Kartentexten. |
| Wesen | `creature.summon`, `creature.attack`, `creature.hit`, `creature.defeated`; `creature.attack.prepare` und `creature.return` für Vorbereitung und Wiederkehr. Angriff beim tatsächlichen Präsentationsbeginn, Treffer beim aufgelösten Treffer, Tod genau einmal pro bestätigter Instanz. |
| Schutz | `shield.gain`, `shield.absorb`, `block.activate`. Schildgewinn und Verbrauch unterscheiden; nicht aus einem gemeinsamen sinkenden Gesamtwert erraten. |
| Kampf | `hero.damage`, `creature.hit.strong`, `combat.heal`, `combat.buff`, `combat.debuff`, `combat.path_change`, `combat.time`, `combat.reaction`, `combat.interrupt` besitzen getrennte Einträge. Besonders starke Treffer dürfen nur aus vorhandener Regel-/Präsentationsinformation markiert werden. Der Katalog führt keine neue kritische Treffermechanik ein. |
| Resonanz | `resonance.gain`, `resonance.spend`, `resonance.low`, `resonance.medium`, `resonance.high`, `resonance.unleash`. Gewinn, Verbrauch, bereits ausgewählte Klangstufe und bestätigte Entfesselung bleiben getrennt. Keine dauernde Resonanzschleife. |
| Relikte | `card.play.relic`, `relic.activate`, `relic.passive`, `relic.spend`, `relic.replace`, `relic.destroy` unterscheiden Ausspielen, Aktivierung, passives Auslösen, Resonanzverbrauch, Ersetzen und Zerstören. Eine zukünftige individuelle legendäre Signatur verlangt eine nachvollziehbare Clip-ID, keine erfundene Kartenzuordnung. |
| Konvergenz | `convergence.prepare`, `convergence.complete`, `convergence.interrupt`. Nur bestätigte Vorbereitung, Vollendung oder Unterbrechung, keine spekulative Siegesprognose. |
| Ergebnis | `battle.victory`, `battle.defeat`. Ergebnis aus bestehendem Matchsystem; keine Ermittlung durch Audio. |

Die vollständigen exakten Namen und Dateiverweise stehen im maschinenlesbaren
Katalog. Neue Ereignisse erfordern dort einen Eintrag mit existierenden Varianten;
Aufrufer können deshalb vor ihrer Integration isoliert getestet werden.

## Resonanzstufen ohne neue Gameplay-Schwellen

Die Stufe `low`, `medium` oder `high` wird explizit übergeben oder direkt als
entsprechendes Ereignis ausgelöst. Das Audiomodul vergleicht keinen Resonanzwert
mit selbst gesetzten Grenzwerten. Bis zur finalen Engine-Anbindung darf ein
Integrationsaufrufer ausschließlich bereits freigegebene Stufen benutzen.
`resonance.gain` und `resonance.spend` funktionieren auch ohne Stufenauswahl.
Ein Regelsystem kann Entfesselung melden; der Klang aktiviert sie niemals selbst.

## Musik als Präsentationskontext

`menu`, `collection`, `deckbuilder`, `duel`, `tense`, `convergence` und
`campaign` sind eigene Musikloops; `victory` und `defeat` sind eigene
Musikstinger. Diese neun Kontexte stehen im Katalog.
`AudioManager.set_music(context, fade_seconds)` fordert einen Kontext an und
blendet die beiden festen Musikplayer weich über. Während einer Überblendung
wird nur der zuletzt angeforderte Folgekontext vorgemerkt und anschließend
überblendet; dadurch wächst keine Wiedergabewarteschlange. Die Klangfläche
`ambience.rift` wird separat mit `set_ambience("ambience.rift")` angefordert. Der Aufrufer bestimmt, wann ein Kontext zutrifft.
Weder niedrige Lebenspunkte noch Konvergenzbedingungen werden im Controller
berechnet. Sieg-/Niederlage-Effekt und Musik sollten im Produkt bewusst
orchestriert werden, damit Stinger nicht doppelt laufen.

## Fehler- und Budgetvertrag

Unbekannte Namen, nicht verfügbare Assets, ungültiger Kontext, Cooldown,
Stimmenlimit und noch gesperrtes Browseraudio führen kontrolliert zur Auslassung.
Keine Warteschlange speichert alte Klicks zum späteren Nachholen.
Bei Pooldruck werden weitere Stimmen ausgelassen; Prioritätsmetadaten führen aktuell nicht zur Verdrängung laufender Stimmen.
Alle Schichten zählen zum gemeinsamen festen Poolbudget von 16 Stimmen;
optionale Schichten dürfen die letzten vier freien Primärplätze nicht belegen. Settings-,
Speicher- und Audiofehler werden außerhalb der Gameplayauflösung behandelt.
Weitere Schritte: [AUDIO-INTEGRATION.md](AUDIO-INTEGRATION.md).

## Adapter und Diagnose

```gdscript
const Router = preload("res://scripts/audio/sound_event_router.gd")
var router = Router.new(audio)
router.route("creature.summon", {"faction": "houses", "rarity": "rare"})
router.resonance("medium") # Stufe bereits extern bestätigt.
router.music("duel", 1.5)
```

Der Router hält den Manager schwach referenziert und liefert nach dessen
Entfernung kontrolliert `false`. `legacy_cue()` übersetzt nur ausdrücklich
aufgeführte neutrale Alt-Cues; alte Sigillen werden nicht als neue Mächte
interpretiert. `snapshot()` liefert Poolbelegung, Spitzenbelegung, Cachegröße,
angenommene/ausgelassene Ereignisse, fehlende Assets, Settings und Musikzustand.
`last_save_error` ist separat sichtbar; `settings_save_failed(error)` meldet
Speicherausfälle. Diese Diagnose schreibt keine Gameplayhistorie.

Produktionsumfang dieses Pakets: 52 Ereignisse, 146 echte Effektvarianten
sowie vier Macht- und drei Seltenheitsschichten, insgesamt 153 Effektdateien.
Hinzu kommen neun Musikdateien und eine Umgebungsdatei. Die 163 Clips und
ihre SHA256-/Format-/Dauerangaben sind in `data/audio/asset_manifest.json`
erfasst; Dateiexistenz bedeutet noch keine subjektive Hörfreigabe.
