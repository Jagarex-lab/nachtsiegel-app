extends VBoxContainer
## Optional, reusable settings UI. bind_manager() accepts an ORAFOLD AudioManager.
## No autoload, gameplay, legacy save data, or existing scenes are modified.

var manager: Node
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var mute_toggle: CheckBox
var reduced_toggle: CheckBox
var persistence_note: Label
var _syncing := false

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Audioeinstellungen"
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	for channel in ["master", "music", "sfx", "ambience"]:
		_add_volume(channel, {"master": "Gesamtlautstärke", "music": "Musik", "sfx": "Effekte", "ambience": "Umgebung"}[channel])
	mute_toggle = CheckBox.new()
	mute_toggle.text = "Stummschaltung"
	mute_toggle.custom_minimum_size.y = 44
	mute_toggle.toggled.connect(_on_mute)
	add_child(mute_toggle)
	reduced_toggle = CheckBox.new()
	reduced_toggle.text = "Reduzierte Audiointensität"
	reduced_toggle.tooltip_text = "Dezentere Effekte und weniger zusätzliche Klangschichten."
	reduced_toggle.custom_minimum_size.y = 44
	reduced_toggle.toggled.connect(_on_reduced)
	add_child(reduced_toggle)
	persistence_note = Label.new()
	persistence_note.text = "Änderungen werden auf diesem Gerät gespeichert."
	persistence_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(persistence_note)
	sync_settings()

func bind_manager(audio_manager: Node) -> void:
	if is_instance_valid(manager) and manager.has_signal("settings_changed") and manager.settings_changed.is_connected(_on_settings_changed):
		manager.settings_changed.disconnect(_on_settings_changed)
	if is_instance_valid(manager) and manager.has_signal("settings_save_failed") and manager.settings_save_failed.is_connected(_on_save_failed):
		manager.settings_save_failed.disconnect(_on_save_failed)
	manager = audio_manager
	if is_instance_valid(manager) and manager.has_signal("settings_changed"):
		manager.settings_changed.connect(_on_settings_changed)
	if is_instance_valid(manager) and manager.has_signal("settings_save_failed"):
		manager.settings_save_failed.connect(_on_save_failed)
	if is_node_ready():
		sync_settings()

func _on_settings_changed(_settings: Dictionary) -> void:
	sync_settings()

func _on_save_failed(_error: Error) -> void:
	sync_settings()

func _add_volume(channel: String, label_text: String) -> void:
	var row := VBoxContainer.new()
	var caption := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_child(label)
	var value := Label.new()
	value.custom_minimum_size.x = 56
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_child(value)
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.y = 44
	slider.focus_mode = Control.FOCUS_ALL
	slider.tooltip_text = label_text + " · Pfeiltasten zur Anpassung"
	slider.value_changed.connect(_on_volume.bind(channel))
	row.add_child(slider)
	add_child(row)
	sliders[channel] = slider
	value_labels[channel] = value

func sync_settings() -> void:
	if not is_node_ready():
		return
	_syncing = true
	var state: Dictionary = manager.snapshot() if is_instance_valid(manager) else {}
	var settings: Dictionary = state.get("settings", {})
	var volumes: Dictionary = settings.get("volumes", settings)
	for channel in sliders:
		var value: float = float(volumes.get(channel, {"master": 0.8, "music": 0.45, "sfx": 0.7, "ambience": 0.35}[channel]))
		sliders[channel].value = value
		value_labels[channel].text = "%d %%" % roundi(value * 100.0)
	mute_toggle.button_pressed = bool(settings.get("muted", false))
	reduced_toggle.button_pressed = bool(settings.get("reduced_intensity", false))
	persistence_note.text = "Änderungen werden auf diesem Gerät gespeichert." if state.get("last_save_error", OK) == OK else "Änderung aktiv. Speichern auf diesem Gerät ist derzeit nicht möglich."
	_syncing = false

func _on_volume(value: float, channel: String) -> void:
	value_labels[channel].text = "%d %%" % roundi(value * 100.0)
	if not _syncing and is_instance_valid(manager):
		manager.set_volume(channel, value)

func _on_mute(value: bool) -> void:
	if not _syncing and is_instance_valid(manager):
		manager.set_muted(value)

func _on_reduced(value: bool) -> void:
	if not _syncing and is_instance_valid(manager):
		manager.set_reduced_intensity(value)
