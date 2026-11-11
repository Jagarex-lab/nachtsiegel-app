extends Control
## Standalone audio audition; deliberately not mounted in the production shell.
const AUDIO_MANAGER = preload("res://scripts/audio/audio_manager.gd")
const SETTINGS_PANEL = preload("res://scripts/audio/audio_settings_panel.gd")
var manager: Node
var settings_panel: VBoxContainer
var events: OptionButton
var factions: OptionButton
var rarities: OptionButton
var music: OptionButton
var ambience: OptionButton
var status: Label
var intensity: HSlider

func _ready() -> void:
	# Preview only: prevent the legacy autoload's gesture handler from starting its bed.
	var legacy := get_node_or_null("/root/GameAudio")
	if legacy != null:
		legacy.set_process_input(false)
		legacy.stop_all()
	manager = AUDIO_MANAGER.new()
	manager.name = "PreviewAudioManager"
	add_child(manager)
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.075)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	var title := Label.new()
	title.text = "ORAFOLD · Klangstudio"
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var intro := Label.new()
	intro.text = "Ereignisse, Mächte und Musik anhören. Ein Klick oder Tastendruck gibt Audio frei."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	settings_panel = SETTINGS_PANEL.new()
	settings_panel.bind_manager(manager)
	content.add_child(settings_panel)
	content.add_child(HSeparator.new())
	events = _options(content, "Klangereignis", _event_names())
	factions = _options(content, "Macht", ["neutral", "zwoelf_haeuser", "stillwacht", "vielgestalt", "neunte_stunde"])
	_label_options(factions, {"neutral": "Neutral", "zwoelf_haeuser": "Zwölf Häuser", "stillwacht": "Stillwacht", "vielgestalt": "Vielgestalt", "neunte_stunde": "Neunte Stunde"})
	rarities = _options(content, "Seltenheit", ["common", "rare", "epic", "legendary"])
	_label_options(rarities, {"common": "Gewöhnlich", "rare": "Selten", "epic": "Episch", "legendary": "Legendär"})
	var intensity_label := Label.new()
	intensity_label.text = "Klangintensität · reine Hörprobe ohne Spielschwellen"
	content.add_child(intensity_label)
	intensity = HSlider.new()
	intensity.min_value = 0.0
	intensity.max_value = 1.0
	intensity.step = 0.05
	intensity.value = 0.6
	intensity.custom_minimum_size.y = 44
	content.add_child(intensity)
	_button(content, "Klang abspielen", _play_event)
	music = _options(content, "Musik", _music_names())
	_button(content, "Musik wechseln", _play_music)
	ambience = _options(content, "Umgebungsklang", _ambience_names())
	_button(content, "Umgebungsklang starten", _play_ambience)
	_button(content, "Alle Klänge stoppen", _stop_audio)
	status = Label.new()
	status.text = "Bereit zur Hörprobe."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)

func _options(parent: Node, caption: String, items: Array) -> OptionButton:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	for item in items:
		option.add_item(str(item))
	parent.add_child(option)
	return option

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)

func _label_options(option: OptionButton, labels: Dictionary) -> void:
	for index in range(option.item_count):
		var key := option.get_item_text(index)
		option.set_item_metadata(index, key)
		option.set_item_text(index, str(labels.get(key, key)))

func _selected_value(option: OptionButton) -> String:
	var value: Variant = option.get_item_metadata(option.selected)
	return str(value) if value is String else option.get_item_text(option.selected)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _event_names() -> Array:
	var result: Array = _read_json("res://data/audio/audio_events.json").get("events", {}).keys()
	result.sort()
	return result

func _music_names() -> Array:
	var result: Array = _read_json("res://data/audio/audio_catalog.json").get("music", {}).keys()
	result.sort()
	return result

func _ambience_names() -> Array:
	var result: Array = []
	var clips: Dictionary = _read_json("res://data/audio/audio_catalog.json").get("clips", {})
	for clip_id in clips:
		if clips[clip_id].get("bus", "") == "Ambience":
			result.append(clip_id)
	result.sort()
	return result

func _play_event() -> void:
	manager.unlock_audio()
	var event_name := events.get_item_text(events.selected)
	var accepted: bool = manager.play_event(event_name, {
		"faction": _selected_value(factions),
		"rarity": _selected_value(rarities),
		"intensity": intensity.value,
	})
	status.text = "%s · %s" % [event_name, "abgespielt" if accepted else "gerade nicht verfügbar"]

func _play_music() -> void:
	manager.unlock_audio()
	var music_name := music.get_item_text(music.selected)
	var accepted: bool = manager.set_music(music_name, 1.5)
	status.text = "%s · %s" % [music_name, "Musikübergang gestartet" if accepted else "gerade nicht verfügbar"]

func _play_ambience() -> void:
	manager.unlock_audio()
	var clip_id := ambience.get_item_text(ambience.selected)
	var accepted: bool = manager.set_ambience(clip_id)
	status.text = "%s · %s" % [clip_id, "Umgebungsklang gestartet" if accepted else "gerade nicht verfügbar"]

func _stop_audio() -> void:
	manager.stop_all()
	status.text = "Alle Klänge gestoppt."
