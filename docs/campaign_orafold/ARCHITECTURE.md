# ORAFOLD Kampagnenarchitektur

Stand: 10.11.2026. Technisch implementierter, isolierter Prototyp. Narrative Freigabe: **nein**. Die maßgebliche Weltreferenz bleibt [`../LORE-BIBLE.md`](../LORE-BIBLE.md).

## Grenzen und Aufbau

Der neue Einstieg liegt in `scenes/campaign_orafold/campaign_overview.tscn`. Alle neuen Laufzeitdateien befinden sich in `scripts/campaign_orafold/`; Daten und Platzhaltergrafiken besitzen eigene Verzeichnisse. Es gibt keinen Autoload und keine Änderung an Produktionshauptszene, Kampfregeln, Kartendefinitionen, Alpha-Profil, Arvess-Speicher, AudioManager oder Ökonomie.

| Datei | Verantwortung |
|---|---|
| `campaign_manager.gd` | Laden, Kapitel, Szenen, Bedingungen, Entscheidungen, Konsequenzen, Adapteranforderungen, Wiederholung |
| `campaign_state.gd` | Eigenständiger versionierter lokaler Zustand, Prüfung, Migration, atomarer Dateiaustausch und Backup |
| `dialogue_manager.gd` | Stabile Text-IDs, DE/EN, sichtbare Zeilen, Originalverlauf und Übersetzungsdiagnose |
| `campaign_validator.gd` | Inhaltsschema, Querverweise, Erreichbarkeit, deterministische Schleifen, Lorekennzeichnung, Assets und Sprachen |
| `narrative_event_router.gd` | Optionale `story.*`-Signale ohne Audioabhängigkeit |
| `reward_adapter.gd` | Lokale Wissens-/Kapitelfreischaltung und dauerhafte Outbox für künftige externe Belohnungen |
| `battle_adapter.gd` / `battle_view.gd` | Aufruf des bestehenden Alpha-Modells und eigener Prototyp-Kampfbildschirm |
| `presentation.gd` | Getrennte responsive Kampagnenoberfläche, Verlauf, Codex und Einstellungen |

Die Hierarchie lautet Kampagne → Kapitel → Szene → Ereignisse → Entscheidung/Kampf. Eine Aktion führt höchstens einen Szenenübergang aus. Kein rekursives automatisches Abspielen; ein zulässiger Kampf-Retry kann deshalb keinen ununterbrochenen Dialoglauf blockieren.

## Datendefinitionen

`data/campaign_orafold/prototype.json` enthält `schema_version: 1`, `content_version: 1`, `default_campaign` und nach stabilen IDs indizierte Sammlungen. Ein neuer Inhaltssatz kann über einen anderen Bundlepfad geladen werden; die Kern-Engine benötigt dafür keine Änderung. Kampagnen-IDs und IDs aller Teilsammlungen müssen innerhalb des gewählten Bundles stabil sein.

| Sammlung | Pflicht-/Kernfelder |
|---|---|
| `campaigns` | `id`, `title_id`, `chapters[]`, `status`, `source` |
| `chapters` | `id`, `title_id`, `summary_id`, `scenes[]`, `entry_scene`, `requires[]`, `replayable`, Status/Quelle |
| `scenes` | `id`, `chapter_id`, `title_id`, `background`, `dialogue[]`, Status/Quelle; genau ein Ausgang durch `next_scene`, `decision_id`, `encounter_id` oder `complete_chapter` |
| `decisions` | `id`, `choices[]`, Status/Quelle; Wahl: `id`, `text_id`, `next_scene`, optionale `conditions[]`/`effects[]` |
| `characters` | `id`, `name_id`, `description_id`, `portrait`, `faction`, `knowledge[]`, Status/Quelle; optional `protected`, `role`, `relationships`, `known_events`, `dialogue_voice` |
| `encounters` | `id`, `deck_profile`, `enemy_profile`, `ai_profile`, `seed`, `repeatable`, `on_victory`, `on_defeat`, Status/Quelle |
| `rewards` | `id`, `type`, `target`, optionale `payload`, Status/Quelle |

Sprecherzeilen enthalten `speaker_id`, `text_id`, optionale `emotion`, `conditions`, eigene Status-/Quellenangaben. Zeichengrafiken sind optional; fehlende optionale Porträts zeigen einen neutralen Platzhalter. Ein nicht leerer Assetpfad muss vorhanden sein. Eira besitzt absichtlich kein erfundenes Aussehen.

Alle Dialog- und UI-Texte liegen in flachen `locales/de.json` und `locales/en.json`. Bei einer Laufzeitlücke wird Deutsch verwendet, ansonsten `[missing:ID]`; `missing_translations` protokolliert die fehlende Sprach-/ID-Kombination. Der Validator macht fehlende DE/EN-Einträge vor der Freigabe sichtbar.

## Bedingungen und Konsequenzen

Bedingungslisten bedeuten logisches UND. Es gibt weder ausführbaren Storycode noch Ausdrücke aus beliebigen Zeichenketten:

```json
[{"flag":"approach","equals":"preserve"}, {"chapter_completed":"cp01"}]
```

Weitere Bedingung: `{"character_info":"eira_open_questions"}`. Flagwerte sind endliche Zahlen, Bool oder String; ein fehlendes Flag erfüllt keine Gleichheitsbedingung. Unbekannte Bedingungen werden abgelehnt.

Unterstützte Konsequenzen:

```json
[
  {"type":"set_flag","key":"approach","value":"preserve"},
  {"type":"relationship","character_id":"sena","delta":1},
  {"type":"unlock_info","id":"sena_player_note"},
  {"type":"unlock_chapter","id":"cp02"},
  {"type":"reward","id":"sena_note"}
]
```

Eine Entscheidung wird als `decisions[decision_id] = choice_id` gespeichert. Innerhalb eines Kapiteldurchlaufs kann sie keine zweite gegenteilige Konsequenz erzeugen. `on_enter` und `on_complete` werden pro Szene und Durchlauf nur einmal angewendet; Kampf-Retries ermöglichen kein wiederholtes Beziehungssammeln. Die Reihenfolge im Array ist verbindlich. Beziehungen sind auf −100…100 begrenzt und im Prototyp keine Währung.

## Wissen und Lore-Schutz

`knowledge.category` trennt tatsächliches Figurenwissen (`fact`), Glauben (`belief`), Spielerwissen (`player`) und freigegebene Lore (`canon`). Diese epistemische Kategorie erteilt **keine** Anzeigeberechtigung. Standardmäßig ist jeder Eintrag privat und benötigt seine ID in `character_info`. Nur ausdrücklich `visibility: "public"` markierte Einträge ungeschützter Figuren werden ohne Freischaltung angezeigt; Bedingungen gelten zusätzlich. `canon` erfordert Status `KANON`.

`protected: true` setzt jede öffentliche Markierung außer Kraft. Eiras freischaltbarer Eintrag enthält nur bereits dokumentierte offene Fragen. Weder Biografie noch Geheimnisantwort wurden verfasst. Zukünftige autorisierte Enthüllungen können neue Wissens-IDs erhalten; der Validator ersetzt keine redaktionelle Freigabe. Die Clientdaten sind kein Schutz vor manuellem Lesen der ausgelieferten Dateien.

## Zustand, Speichern und Wiederholung

Eigenes Format `ORAFOLD-CAMPAIGN`, Speicherschema 2, Datenversion separat in `content_version`. Standardpfad `user://orafold_campaign_v2.json`; keine Übernahme fremder Spielstände. Gespeichert werden freigeschaltete/abgeschlossene Kapitel, gesehene Szenen, Entscheidungs- und Weltflags, Beziehungen, Spielerwissen, Begegnungsstatistik, Belohnungsledger, Originalverlauf, aktive Szene, sicherer Checkpoint, Sequenznummer und Einstellungen.

Schreibablauf: vollständige Prüfung → temporäre Datei → Flush → gültige bisherige Datei als `.bak` → atomare Umbenennung. Ein beschädigtes Primärsave überschreibt kein gültiges Backup. Bei fehlerhafter Primärdatei wird `.bak` geladen und `recovered` gesetzt. Fehlen beide gültigen Dateien, startet ein leerer isolierter Zustand mit Ladefehlerkennung. Ein späteres Speichern kann die ungültige Primärdatei ersetzen; eine ungültige Primärdatei wird dabei nicht über das Backup rotiert. Der Manager speichert auch die Kampagneninitialisierung. `recovered` bleibt nach Backupwiederherstellung abfragbar, während ein erfolgreicher Save die letzte Fehlerkennung löscht. Fehlgeschlagene Manager-Transaktionen stellen den vorherigen In-Memory-Zustand wieder her und senden keine Erfolgsereignisse.

Schema 1 desselben Formats wird additiv migriert: `visited_scenes` wird `seen_scenes`, fehlende neue Felder erhalten dokumentierte Standardwerte. Dies ist keine Migration von Arvess oder Alpha. Höhere unbekannte Schemaversionen in Primärdatei, ausgewähltem Backup oder Webspiegel sperren Schreiben. Eine höhere gespeicherte Inhaltsversion sperrt ebenfalls einen stillen Downgrade. Entfernte Inhaltsreferenzen werden nur auf einen noch gültigen Checkpoint zurückgesetzt, sonst auf die Kapitelübersicht; es gibt keine erfundene Zuordnung alter Story-IDs.

Im Web ergänzt ausschließlich am Standardpfad der eigene Schlüssel `orafold.campaign.v2` den asynchronen Dateispeicher. Der neueste gültige Revisionsstand gewinnt. Ein fehlgeschlagener localStorage-Spiegel wird als Fehlerkennung gemeldet, während der bereits gültige Dateischreibvorgang bestehen bleibt. Dies ist kein Cloudsync und keine atomare Transaktion über zwei Browser-Speicher hinweg.

Kapitelwiederholung bildet einen isolierten Durchlauf. Entscheidungen, Flags, Beziehungen, Informationen und Kapitelfreischaltungen werden beim Verlassen oder Abschluss auf den Originalzustand zurückgesetzt; externe und lokale Belohnungsvergaben sind während der Wiederholung unterdrückt. Gesehene Szenen dürfen zum Überspringen ergänzt werden, alternative Wiederholungsdialoge werden nicht dem Originalrückblick hinzugefügt. Der aktive Wiederholungsstand bleibt beim Neuladen verfügbar. Begegnungsstatistik zählt Versuche, ist aber keine wirtschaftliche Belohnung.

## Adapter und Dauerhaftigkeit

Kampfanforderungen erhalten eine gespeicherte monotone Token-ID. Wiederholte Anfrage vor einem Ergebnis liefert dieselbe ID. Nur ein Ergebnis für das aktive Token und `victory`/`defeat` wird akzeptiert; doppelte oder veraltete Ergebnisse verändern nichts. Der sichere Fortschrittspunkt liegt vor dem Kampf. Ein Neustart rekonstruiert den Kampf mit demselben Seed; der einzelne Kampfbefehlverlauf wird hier nicht gespeichert.

Belohnungen besitzen stabile IDs und Ledgerzustände `pending`/`delivered`. Lokale Wissens-/Kapitelfreischaltungen werden in derselben Save-Transaktion angewendet. Externe Grants werden erst nach erfolgreichem Speichern veröffentlicht. Ein künftiger Verbraucher muss `orafold-campaign:{reward_id}` als Idempotenzschlüssel honorieren und anschließend `acknowledge_reward()` aufrufen. Ein Absturz zwischen externer Zustellung und Bestätigung kann dieselbe Anfrage wiederholen; genau einmalige externe Zustellung erfordert deshalb einen idempotenten Empfänger. Es gibt derzeit keine Karten-IDs, Goldbeträge, Bezahllogik oder produktiven Grant-Anbieter.

## Bekannte Produktgrenzen

Die Architektur und die Beispielvignette bilden eine technische Basis. Redaktionelle Vollständigkeit, vollwertige Hauptkampagne, freigegebene Charakterillustrationen, professionelles Lektorat, Geräteabnahme, Cloudsync und Produktintegration sind eigene spätere Schritte. Das Prüfwerkzeug erkennt Strukturfehler; es beweist weder Textqualität noch den Kanonstatus einer bloßen Behauptung.
