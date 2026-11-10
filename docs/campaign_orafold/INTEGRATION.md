# Integrationsanleitung

Stand: 10.11.2026. Eigenständiger Feature-Branch auf `develop`; keine automatische Veröffentlichung und kein Mergeauftrag.

## Prototyp starten

Vom Repository-Verzeichnis:

```sh
godot --path . res://scenes/campaign_orafold/campaign_overview.tscn
```

Im Editor dieselbe Szene öffnen und „Aktuelle Szene ausführen“. Der normale Produktionsstart in `project.godot` bleibt unverändert. Die Übersicht bietet zwei Kapitel; Kapitel 2 wird erst nach Abschluss von Kapitel 1 verfügbar. Die erste Entscheidung wirkt auf spätere Zeilen, das Übungsduell verwendet vorhandene Alpha-Deckprofile, Niederlage führt zur wiederholbaren Begegnung, Sieg zum Kapitelabschluss. Charakterwissen und Fortschritt lassen sich über erneuten Start prüfen. Wiederholung setzt die ursprünglichen Entscheidungen und Belohnungen nicht zurück.

## Minimaler Host

```gdscript
const Campaign = preload("res://scripts/campaign_orafold/campaign_manager.gd")
var campaign = Campaign.new()

func _ready():
    campaign.changed.connect(_render_campaign)
    if not campaign.load_campaign():
        # Translate or map campaign.last_error in the host UI.
        return
    # Explicitly open a selected unlocked chapter; don't silently reset a run.
```

`chapters()` liefert kopierte Definitionen einschließlich `unlocked` und `completed`. `current_scene()` und `available_choices()` sind ebenfalls Kopien. Sichtbare Dialogzeilen: `dialogue.lines(scene, state.data)`, Text: `dialogue.text(text_id)`. Die Oberfläche ist für das Anzeigen und schrittweise Lesen zuständig; `advance()` bestätigt den Abschluss einer Szene. `choose(id)` wertet Bedingungen erneut aus und speichert Konsequenzen vor dem Szenenwechsel.

Weitere öffentliche Methoden:

| Methode | Ergebnis |
|---|---|
| `start_chapter(id, replay=false)` | Start oder Resume; `bool` |
| `replay_chapter(id)` | Isolierte Wiederholung eines abgeschlossenen erlaubten Kapitels |
| `request_battle()` | Begegnungsdefinition plus `token`, oder leeres Dictionary bei Fehler |
| `resolve_battle(token, "victory"/"defeat")` | Tokenprüfende Ergebnisübernahme und gespeicherte Rückkehrszene |
| `character(id)` | Charakter mit nur freigegebenem Spielerwissen |
| `set_setting(key,value)` | Validierte und gespeicherte Einstellung |
| `acknowledge_reward(id,key)` | Dauerhafte Bestätigung eines ausstehenden externen Grants |

Fehlermeldungen sind stabile technische Codes in `last_error`, keine langen fest eingebauten Dialogtexte. Validatorergebnisse stehen in `validation.errors` und `validation.warnings`. `State.last_error` unterscheidet Backupwiederherstellung, ungültige Daten, Dateifehler und künftige Versionen.

## Kampfanschluss

Der Prototyp verwendet ausschließlich den neuen eigenen `battle_adapter.gd` mit dem vorhandenen Alpha-Modell. Keine Session wird erzeugt, die nebenbei das Alpha-Profil schreiben könnte. `begin(encounter, token)` startet vorkonfigurierte bestehende Deckprofile; `command(name,args)` delegiert legale Enginekommandos. Die fünf Pfade, Ressourcen, Regeln und Kartendaten sind unverändert. `completed(token,outcome)` führt zurück zu `campaign.resolve_battle()`.

Für den späteren Arenaanschluss:

1. Host erzeugt `request_battle()` und hält das persistierte Token.
2. Host mappt geprüfte `deck_profile`, `enemy_profile`, `ai_profile`, Seed und unterstützte Startsituation auf die bestehende Spielsession.
3. Host verbindet ausschließlich bestätigte Engineergebnisse mit `resolve_battle()`. Ein aufgegebener oder unentschiedener Prototypkampf gilt als Niederlage; spätere Produktsemantik ist ausdrücklich festzulegen.
4. Zurück zur Kampagnenansicht wechseln, nachdem der Ergebnis-Save erfolgreich ist.
5. Bei Neustart dieselbe pending Anfrage verwenden. Das Kampagnenmodul startet vom sicheren Punkt vor dem Kampf; Midbattle-Replay oder Sessionpersistenz bleibt Aufgabe des vorhandenen Spielsystems.

Nicht unterstützte Startsituationen, Sonderregeln, Deckprofile und KI-Profile müssen vor dem Start abgefangen werden. Dieser Auftrag definiert keine Ersatzmechanik und keinen 550-Karten-Migrationsplan.

## Belohnungsanschluss

Keine wirtschaftlichen Belohnungen sind aktiv. `character_info` und `chapter` bleiben lokal. Für spätere Karten, Decks, Gold, Kosmetik, Illustrationen oder Erfolge wird ein geprüfter `external`-Grant konfiguriert. Nach Laden darf ein Host die gespeicherte Outbox erneut senden:

```gdscript
campaign.rewards.grant_requested.connect(_request_existing_inventory_grant)
campaign.rewards.publish_pending(campaign.state.data)
```

Der Inventar-/Ökonomiedienst muss den übergebenen Idempotenzschlüssel speichern und doppelte Zustellung verweigern. Erst nach bestätigter Vergabe `campaign.acknowledge_reward(id,key)` aufrufen. Keine produktiven Karten-IDs oder Werte einsetzen, bevor der parallele Katalog-/Ökonomieauftrag diese freigegeben hat.

## Audioanschluss

Optional abonnieren:

```gdscript
campaign.events.narrative_event.connect(_route_existing_story_audio)
```

Namen: `story.scene_start`, `story.dialogue_advance`, `story.choice_selected`, `story.reveal`, `story.chapter_complete`, `story.battle_start`, `story.battle_complete`. Es gibt keinen konkurrierenden AudioManager. Fehlende Teilnehmer oder fehlende Cues blockieren den Verlauf nicht. Die Oberfläche kann `story.dialogue_advance` zusätzlich beim Wechsel einer einzelnen sichtbaren Zeile veröffentlichen. `story.reveal` ist als Schnittstelle vorbereitet; die Daten enthalten keine geheime kanonische Enthüllung.

## Bestehende Spielstände und Daten

`user://progress_v1.json`, `user://orafold_alpha_profile_v1.json`, deren Browser-Keys und alle Altstorydateien bleiben erhalten. Die neue Kampagne verwendet ausschließlich `user://orafold_campaign_v2.json` und `orafold.campaign.v2`. Ein künftig gemeinsames Profil sollte den gesamten geprüften Kampagnenzustand unter eigenem Namensraum übernehmen; keine alten Kapitelnummern auf die neuen IDs mappen. Der Migrationsbericht dokumentiert die weiterhin aktiven Altstoryabhängigkeiten.

Bei mehreren Kampagnen in einem Bundle bleiben Fortschritts-IDs gemeinsam gespeichert; sie müssen eindeutig sein. Es existiert ein aktiver Fortschrittspunkt pro lokalem Profil, keine parallelen Kampagnenslots. Beim Kampagnenwechsel bleibt abgeschlossener Fortschritt erhalten, ein aktiver Wiederholungszustand wird bereinigt. Für getrennte Profile können unterschiedliche Savepfade übergeben werden; der Browsermirror gilt nur für den Standardpfad.

## Export und Integration in zentrale UI

Dieser Branch verändert absichtlich weder Hauptszene noch Exportvorgaben. Der Host muss später einen Menüeintrag zur getrennten Szene hinzufügen. Für eigenständige Web-/Android-/PC-Exportprofile `scenes/campaign_orafold/` aufnehmen und die JSON-Verzeichnisse `data/campaign_orafold/` explizit einschließen; dynamisch per `FileAccess` geladene Daten werden nicht allein durch eine Szene-Abhängigkeit garantiert verpackt. Bestehende zentrale Profile erst zusammen mit deren Eigentümern ändern. Lokale QA-Exporte sind keine Veröffentlichung.

Vor einer Produktfreigabe: eigene Szene im richtigen Safe-Area-/Orientierungsvertrag öffnen, Storyschrift und Skalierung mit den vorhandenen Accessibility-Einstellungen abstimmen, bestätigte Lore einsetzen, Porträts/Bilder freigeben, Speicherintegration testen, Outbox an vorhandenes Inventar anbinden, Audio abonnieren und Exportpaket prüfen. Plattformabnahme auf physischen Android-/iOS-Geräten und produktiver Hostingpfad bleiben separat.
