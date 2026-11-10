extends SceneTree
## Tests the reusable settings UI using the real manager and isolated persistence.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var manager = load("res://scripts/audio/audio_manager.gd").new()
	manager.settings_path = "user://orafold_audio_preview_test.cfg"
	DirAccess.remove_absolute(manager.settings_path)
	root.add_child(manager)
	var panel = load("res://scripts/audio/audio_settings_panel.gd").new()
	panel.bind_manager(manager)
	root.add_child(panel)
	_check(panel.sliders.size() == 4, "four volume controls")
	for channel in ["master", "music", "sfx", "ambience"]:
		_check(is_equal_approx(panel.sliders[channel].value, manager.settings[channel]), channel + " loaded into slider")
		panel.sliders[channel].value = 0.23
		_check(is_equal_approx(manager.settings[channel], 0.23), channel + " slider updates real settings")
		_check(panel.value_labels[channel].text == "23 %", channel + " percentage label")
	panel.mute_toggle.button_pressed = true
	panel.reduced_toggle.button_pressed = true
	_check(manager.settings.muted, "mute updates manager")
	_check(manager.settings.reduced_intensity, "reduced intensity updates manager")
	var saved := ConfigFile.new()
	_check(saved.load(manager.settings_path) == OK, "settings persisted by panel")
	_check(saved.get_value("audio", "muted", false), "persisted mute")
	_check(saved.get_value("audio", "reduced_intensity", false), "persisted reduced intensity")
	manager.set_volume("music", 0.61, false)
	_check(is_equal_approx(panel.sliders.music.value, 0.61), "panel observes external settings change")
	manager.set_muted(false, false)
	_check(not panel.mute_toggle.button_pressed, "panel observes external mute change")
	manager.settings_path = "user://orafold_preview_missing_directory/settings.cfg"
	panel.sliders.music.value = 0.32
	_check(panel.persistence_note.text.contains("nicht möglich"), "panel reports actual persistence failure")
	manager.settings_path = "user://orafold_audio_preview_test.cfg"
	panel.sliders.music.value = 0.33
	_check(not panel.persistence_note.text.contains("nicht möglich"), "panel reports persistence recovery")
	panel.queue_free()
	manager.stop_all(true)
	manager.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://orafold_audio_preview_test.cfg")
	var preview = load("res://assets/audio/audio_preview.tscn").instantiate()
	root.add_child(preview)
	_check(preview.events.item_count > 20, "audition exposes real event catalog")
	_check(preview.music.item_count >= 9, "audition exposes music catalog")
	_check(preview.ambience.item_count >= 1, "audition exposes ambience catalog")
	_check(preview.factions.item_count == 5, "four powers plus neutral option")
	_check(preview.rarities.item_count == 4, "four rarity options")
	var legacy := root.get_node_or_null("GameAudio")
	_check(legacy == null or not legacy.is_processing_input(), "preview isolates legacy gesture handler")
	preview.manager.stop_all(true)
	preview.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("AUDIO PREVIEW: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
