extends Node
## Presentation service. GameAudio subclasses this as the sole product mixer.
## No game model, rules, cards or global RNG dependencies.
signal event_played(event_name: String, clip_id: String)
signal settings_changed(settings: Dictionary)
signal settings_save_failed(error: Error)

const MusicController = preload("res://scripts/audio/music_controller.gd")
const POOL_SIZE := 16
const BUS_NAMES := {"master": "ORAFOLD", "music": "ORAFOLD Music", "sfx": "ORAFOLD SFX", "ui": "ORAFOLD UI", "ambience": "ORAFOLD Ambience"}
const DEFAULT_SETTINGS := {"master": 0.8, "music": 0.55, "sfx": 0.75, "ui": 0.75, "ambience": 0.4, "muted": false, "reduced_intensity": false}
const FACTION_ALIASES := {"houses": "zwoelf_haeuser", "stillwatch": "stillwacht", "morph": "vielgestalt", "ninth": "neunte_stunde"}

var catalog_path := "res://data/audio/audio_catalog.json"
var events_path := "res://data/audio/audio_events.json"
var settings_path := "user://orafold_audio_v1.cfg"
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var last_save_error: Error = OK
var _web_storage_status := "native"
var _mirror_write_blocked := false
var music_controller: Node
var unlocked := not OS.has_feature("web")
var _catalog: Dictionary = {}
var _events: Dictionary = {}
var _streams: Dictionary = {}
var _voices: Array[Dictionary] = []
var _last_variant: Dictionary = {}
var _last_event_ms: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _initialized := false
var _suspended := false
var _manual_suspended := false
var _focus_suspended := false
var _app_suspended := false
var _stats := {"accepted": 0, "rejected": 0, "missing_assets": 0, "peak_voices": 0, "stolen_voices": 0}
var _volume_tweens: Dictionary = {}
var _ambience: AudioStreamPlayer
var _pending_ambience := ""
var _ambience_tween: Tween
var _ambience_resume_active := false
var _ambience_resume_position := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		# Godot Web SAMPLE bypasses the engine mixer/bus effects; use the mixer path.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.name = "Voice%d" % index
		add_child(player)
		_voices.append({"player": player, "event": "", "priority": 0, "started": 0, "layer": false})
	music_controller = MusicController.new()
	music_controller.name = "MusicController"
	add_child(music_controller)
	music_controller.set_unlocked(unlocked)
	_ambience = AudioStreamPlayer.new()
	_ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_ambience.name = "Ambience"
	_ambience.bus = BUS_NAMES.ambience
	add_child(_ambience)
	_initialized = true
	load_settings()
	_apply_settings(false)
	configure(catalog_path, events_path)

func _ensure_buses() -> void:
	for channel in BUS_NAMES:
		var bus: String = BUS_NAMES[channel]
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_send(index, "Master" if channel == "master" else BUS_NAMES.master)
	var root_bus := AudioServer.get_bus_index(BUS_NAMES.master)
	if AudioServer.get_bus_effect_count(root_bus) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -3.0
		AudioServer.add_bus_effect(root_bus, limiter)

func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func configure(new_catalog_path: String = "res://data/audio/audio_catalog.json", new_events_path: String = "res://data/audio/audio_events.json") -> bool:
	catalog_path = new_catalog_path
	events_path = new_events_path
	if not _initialized:
		return true
	stop_all(true)
	_catalog = _read_dictionary(catalog_path)
	var document := _read_dictionary(events_path)
	if _catalog.get("version", 0) != 1 or not _catalog.get("clips", null) is Dictionary or document.get("version", 0) != 1 or not document.get("events", null) is Dictionary:
		_catalog = {}
		_events = {}
		music_controller.configure({})
		return false
	_events = document.events
	for clip_id in _catalog.clips:
		var clip: Variant = _catalog.clips[clip_id]
		if not clip is Dictionary:
			continue
		if str(clip.get("bus", "SFX")) in ["Music", "Ambience"]:
			continue
		var stream := _load_clip(str(clip_id))
		if stream != null:
			_streams[clip_id] = stream
	music_controller.configure(_catalog)
	return true

func _load_clip(clip_id: String) -> AudioStream:
	var clips: Variant = _catalog.get("clips", {})
	if not clips is Dictionary:
		return null
	var clip: Variant = clips.get(clip_id, {})
	if not clip is Dictionary or not clip.get("path", "") is String:
		return null
	var path: String = clip.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path, "AudioStream"):
		_stats.missing_assets += 1
		return null
	return load(path) as AudioStream

func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)

func _reject() -> bool:
	_stats.rejected += 1
	return false

func play_event(event_name: String, context: Dictionary = {}) -> bool:
	if not _initialized or _suspended or not unlocked or bool(settings.muted):
		return _reject()
	var definition: Variant = _events.get(event_name, {})
	if not definition is Dictionary or definition.is_empty():
		return _reject()
	var variants: Variant = definition.get("variants", [])
	if not variants is Array or variants.is_empty():
		return _reject()
	var now := Time.get_ticks_msec()
	var cooldown := int(_number(definition.get("cooldown_ms", 0), 0.0, 0.0, 60000.0))
	if now - int(_last_event_ms.get(event_name, -60001)) < cooldown:
		return _reject()
	var active := 0
	for voice in _voices:
		if voice.player.playing and voice.event == event_name and not voice.layer:
			active += 1
	if active >= int(_number(definition.get("max_voices", 3), 3.0, 1.0, POOL_SIZE)):
		return _reject()
	# Filter missing assets before choosing so a broken variant never silences valid peers.
	var available: Array[String] = []
	for item in variants:
		if item is String and _streams.has(item) and not available.has(item):
			available.append(item)
	if available.is_empty():
		return _reject()
	if available.size() > 1:
		available.erase(str(_last_variant.get(event_name, "")))
	var clip_id := available[_rng.randi_range(0, available.size() - 1)]
	var priority := int(_number(definition.get("priority", 1), 1.0, 0.0, 100.0))
	var intensity := _number(context.get("intensity", 0.6), 0.6, 0.0, 1.0)
	var gain := _number(definition.get("gain_db", 0.0), 0.0, -40.0, 0.0)
	# Dynamics are presentation-only and bounded to 6 dB. No inferred damage thresholds.
	gain += lerpf(-6.0, 0.0, intensity)
	if bool(settings.reduced_intensity):
		gain -= 5.0
		intensity = minf(intensity, 0.45)
	var pitch_min := _number(definition.get("pitch_min", 1.0), 1.0, 0.8, 1.2)
	var pitch_max := _number(definition.get("pitch_max", 1.0), 1.0, pitch_min, 1.2)
	if not _play_clip(clip_id, event_name, priority, gain, _rng.randf_range(pitch_min, pitch_max), false, str(definition.get("bus", "SFX"))):
		return _reject()
	_last_variant[event_name] = clip_id
	_last_event_ms[event_name] = now
	_stats.accepted += 1
	# Optional identity layers never displace a primary event or exceed the pool.
	var faction := str(context.get("faction", "neutral"))
	faction = str(FACTION_ALIASES.get(faction, faction))
	var layers: Variant = definition.get("faction_layers", {})
	if layers is Dictionary and layers.get(faction, null) is String:
		_play_clip(layers[faction], event_name, priority, gain - 3.0, 1.0, true)
	if not bool(settings.reduced_intensity):
		var rarity_layers: Variant = definition.get("rarity_layers", {})
		var rarity := str(context.get("rarity", "common"))
		if rarity_layers is Dictionary and rarity_layers.get(rarity, null) is String:
			_play_clip(rarity_layers[rarity], event_name, priority, gain - 5.0, 1.0, true)
	_stats.peak_voices = maxi(int(_stats.peak_voices), _active_voice_count())
	event_played.emit(event_name, clip_id)
	return true

func _play_clip(clip_id: String, event_name: String, priority: int, gain: float, pitch: float, layer: bool, bus: String = "SFX") -> bool:
	if not _streams.has(clip_id):
		return false
	if layer and _active_voice_count() >= POOL_SIZE - 4:
		return false
	var selected: Dictionary = {}
	for voice in _voices:
		if not voice.player.playing:
			selected = voice
			break
	# Drop overflow rather than cutting active waveform tails. Priority is recorded
	# for telemetry/possible future queue policy; there is no unbounded event queue.
	if selected.is_empty():
		return false
	var clip: Dictionary = _catalog.clips[clip_id]
	var player: AudioStreamPlayer = selected.player
	player.stream = _streams[clip_id]
	player.bus = BUS_NAMES.ui if bus == "UI" else BUS_NAMES.sfx
	player.volume_db = gain - 9.0 + _number(clip.get("gain_db", 0.0), 0.0, -40.0, 0.0)
	player.pitch_scale = pitch
	selected.event = event_name
	selected.priority = priority
	selected.started = Time.get_ticks_msec()
	selected.layer = layer
	player.play()
	return true

func _active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.player.playing:
			count += 1
	return count

func set_music(context: String, fade_seconds: float = 1.5) -> bool:
	return _initialized and music_controller.request_music(context, fade_seconds)

func set_ambience(clip_id: String, fade_seconds: float = 0.75) -> bool:
	if not _initialized:
		return false
	var clips: Variant = _catalog.get("clips", {})
	if not clips is Dictionary:
		return false
	var clip: Variant = clips.get(clip_id, {})
	if not clip is Dictionary or str(clip.get("bus", "")) != "Ambience":
		return false
	var stream := _load_clip(clip_id)
	if stream == null:
		return false
	if not unlocked or _suspended:
		_pending_ambience = clip_id
		return true
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		stream.loop = bool(clip.get("loop", true))
	var fade := _number(fade_seconds, 0.75, 0.02, 8.0)
	var gain := _number(clip.get("gain_db", -12.0), -12.0, -40.0, 0.0)
	if is_instance_valid(_ambience_tween) and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	if _ambience.playing:
		_ambience_tween.tween_property(_ambience, "volume_db", -80.0, fade * 0.5)
	_ambience_tween.tween_callback(_begin_ambience.bind(stream))
	_ambience_tween.tween_property(_ambience, "volume_db", gain, fade * 0.5)
	return true

func _begin_ambience(stream: AudioStream) -> void:
	_ambience.stop()
	_ambience.stream = stream
	_ambience.volume_db = -80.0
	_ambience.stream_paused = false
	_ambience.play()

func set_volume(channel: String, value: Variant, persist: bool = true) -> bool:
	channel = channel.to_lower()
	if channel not in ["master", "music", "sfx", "ui", "ambience"] or not (value is float or value is int) or not is_finite(float(value)):
		return false
	settings[channel] = clampf(float(value), 0.0, 1.0)
	_apply_settings(true)
	if persist:
		save_settings()
	settings_changed.emit(settings.duplicate())
	return true

func set_muted(value: bool, persist: bool = true) -> void:
	settings.muted = value
	_apply_settings(false)
	if persist:
		save_settings()
	settings_changed.emit(settings.duplicate())

func set_reduced_intensity(value: bool, persist: bool = true) -> void:
	settings.reduced_intensity = value
	if persist:
		save_settings()
	settings_changed.emit(settings.duplicate())

func _set_bus_gain(gain: float, bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.0001)))

func _mute_bus(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, true)

func _apply_settings(smooth: bool) -> void:
	if not _initialized:
		return
	for channel in ["master", "music", "sfx", "ui", "ambience"]:
		var bus: String = BUS_NAMES[channel]
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var target := float(settings[channel])
		if _volume_tweens.has(channel):
			_volume_tweens[channel].kill()
			_volume_tweens.erase(channel)
		var explicit_mute: bool = channel == "master" and bool(settings.muted)
		if target > 0.0 or explicit_mute:
			AudioServer.set_bus_mute(index, explicit_mute)
		if smooth and not _suspended:
			var tween := create_tween()
			tween.tween_method(_set_bus_gain.bind(bus), db_to_linear(AudioServer.get_bus_volume_db(index)), target, 0.12)
			if target <= 0.0:
				tween.tween_callback(_mute_bus.bind(bus))
			_volume_tweens[channel] = tween
		else:
			_set_bus_gain(target, bus)
			AudioServer.set_bus_mute(index, explicit_mute or target <= 0.0)

func _browser_settings_key() -> String:
	# Independent of the gameplay save and isolated for custom settings_path tests.
	return "orafold.audio.v1:" + settings_path.sha256_text()

func _validate_mirror_settings(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var validated: Dictionary = {}
	for key in DEFAULT_SETTINGS:
		if not value.has(key):
			# Original v1 mirrors used one effects gain for both buses.
			if key == "ui" and value.has("sfx"):
				validated.ui = _number(value.sfx, DEFAULT_SETTINGS.ui, 0.0, 1.0)
				continue
			return {}
		var item: Variant = value[key]
		if DEFAULT_SETTINGS[key] is bool:
			if not item is bool:
				return {}
			validated[key] = item
		else:
			if not (item is float or item is int) or not is_finite(float(item)) or float(item) < 0.0 or float(item) > 1.0:
				return {}
			validated[key] = float(item)
	return validated

func _read_browser_mirror() -> Dictionary:
	# Both interpolated values are JSON string literals, never executable input.
	var script := "(function(){try{return JSON.stringify({ok:true,value:localStorage.getItem(%s)});}catch(error){return JSON.stringify({ok:false});}})()" % JSON.stringify(_browser_settings_key())
	var reply: Variant = JavaScriptBridge.eval(script, true)
	if not reply is String:
		return {"status": "unavailable"}
	var envelope: Variant = JSON.parse_string(reply)
	if not envelope is Dictionary or envelope.get("ok", false) != true:
		return {"status": "unavailable"}
	return _decode_mirror(envelope.get("value", null))

func _decode_mirror(raw: Variant) -> Dictionary:
	if raw == null:
		return {"status": "missing"}
	if not raw is String:
		return {"status": "invalid"}
	var parser := JSON.new()
	if parser.parse(raw) != OK or not parser.data is Dictionary:
		return {"status": "invalid"}
	var document: Dictionary = parser.data
	var version: Variant = document.get("version", null)
	if not (version is int or version is float) or float(version) != 1.0:
		return {"status": "invalid"}
	var validated := _validate_mirror_settings(document.get("settings", null))
	if validated.is_empty():
		return {"status": "invalid"}
	return {"status": "valid", "settings": validated}

func _write_browser_mirror() -> Error:
	var existing := _read_browser_mirror()
	if existing.status == "invalid":
		_mirror_write_blocked = true
		_web_storage_status = "invalid"
		return ERR_INVALID_DATA
	if _mirror_write_blocked:
		# Do not silently downgrade future schemas or replace corrupt evidence.
		_web_storage_status = "invalid"
		return ERR_INVALID_DATA
	var document := {"version": 1, "settings": settings.duplicate()}
	var script := "(function(){try{localStorage.setItem(%s,%s);return 'ok';}catch(error){return 'failed';}})()" % [JSON.stringify(_browser_settings_key()), JSON.stringify(JSON.stringify(document))]
	var outcome: Variant = JavaScriptBridge.eval(script, true)
	if not outcome is String or outcome != "ok":
		_web_storage_status = "unavailable"
		return ERR_UNAVAILABLE
	_web_storage_status = "saved"
	return OK

func save_settings() -> Error:
	# Preserve unknown native versions and invalid/future browser mirrors intact.
	var existing := ConfigFile.new()
	if FileAccess.file_exists(settings_path):
		var existing_error := existing.load(settings_path)
		if existing_error != OK or existing.get_value("audio", "version", 0) != 1:
			last_save_error = ERR_INVALID_DATA
			settings_save_failed.emit(last_save_error)
			return last_save_error
	if OS.has_feature("web") and (_mirror_write_blocked or _read_browser_mirror().status == "invalid"):
		last_save_error = ERR_INVALID_DATA
		settings_save_failed.emit(last_save_error)
		return last_save_error
	var config := ConfigFile.new()
	config.set_value("audio", "version", 1)
	for key in DEFAULT_SETTINGS:
		config.set_value("audio", key, settings[key])
	last_save_error = config.save(settings_path)
	if OS.has_feature("web"):
		# IDBFS flush is asynchronous; this same-origin mirror survives immediate reload.
		var mirror_error := _write_browser_mirror()
		if last_save_error == OK:
			last_save_error = mirror_error
	if last_save_error != OK:
		settings_save_failed.emit(last_save_error)
	return last_save_error

func load_settings() -> Error:
	var config := ConfigFile.new()
	var result := config.load(settings_path)
	settings = DEFAULT_SETTINGS.duplicate()
	if result == OK:
		if config.get_value("audio", "version", 0) != 1:
			result = ERR_INVALID_DATA
		else:
			for key in DEFAULT_SETTINGS:
				var value: Variant = config.get_value("audio", key, DEFAULT_SETTINGS[key])
				if DEFAULT_SETTINGS[key] is bool:
					settings[key] = value if value is bool else DEFAULT_SETTINGS[key]
				else:
					settings[key] = _number(value, DEFAULT_SETTINGS[key], 0.0, 1.0)
	# v1 ConfigFiles also predate the independent UI channel.
	if result == OK and not config.has_section_key("audio", "ui"):
		settings.ui = settings.sfx
	if OS.has_feature("web"):
		var mirror := _read_browser_mirror()
		_web_storage_status = mirror.status
		_mirror_write_blocked = mirror.status == "invalid"
		if mirror.status == "valid":
			settings = mirror.settings
			result = OK
		elif mirror.status == "invalid":
			result = ERR_INVALID_DATA
	last_save_error = OK if result == ERR_FILE_NOT_FOUND else result
	_apply_settings(false)
	settings_changed.emit(settings.duplicate())
	return result

func migrate_legacy_settings(legacy: Dictionary, persist: bool = true) -> void:
	# Explicit opt-in migration only. Caller keeps ownership of its old save schema.
	settings.music = _number(legacy.get("Music", settings.music), settings.music, 0.0, 1.0)
	settings.sfx = _number(legacy.get("SFX", settings.sfx), settings.sfx, 0.0, 1.0)
	settings.ui = _number(legacy.get("UI", settings.ui), settings.ui, 0.0, 1.0)
	_apply_settings(false)
	if persist:
		save_settings()
	settings_changed.emit(settings.duplicate())

func unlock_audio() -> void:
	if not _initialized:
		return
	unlocked = true
	music_controller.set_unlocked(true)
	if not _pending_ambience.is_empty() and not _suspended:
		var pending := _pending_ambience
		_pending_ambience = ""
		set_ambience(pending)

func _input(event: InputEvent) -> void:
	if not unlocked and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)):
		unlock_audio()

func set_suspended(value: bool) -> void:
	_manual_suspended = value
	_update_suspension()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focus_suspended = true
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focus_suspended = false
		NOTIFICATION_APPLICATION_PAUSED:
			_app_suspended = true
		NOTIFICATION_APPLICATION_RESUMED:
			_app_suspended = false
		_:
			return
	_update_suspension()

func _update_suspension() -> void:
	if not _initialized:
		return
	var was_suspended := _suspended
	_suspended = _manual_suspended or _focus_suspended or _app_suspended
	if _suspended:
		# Transient effects are intentionally discarded rather than replayed on resume.
		for voice in _voices:
			voice.player.stop()
		_apply_settings(false)
	music_controller.set_suspended(_suspended)
	if _suspended and not was_suspended:
		_ambience_resume_active = _ambience.playing
		_ambience_resume_position = _ambience.get_playback_position() if _ambience.playing else 0.0
	_ambience.stream_paused = _suspended
	if not _suspended and was_suspended and _ambience_resume_active and _ambience.stream != null:
		if OS.has_feature("web") or not _ambience.playing:
			_ambience.stop()
			_ambience.play(_ambience_resume_position)
		_ambience_resume_active = false
	if is_instance_valid(_ambience_tween) and _ambience_tween.is_valid():
		if _suspended:
			_ambience_tween.pause()
		else:
			_ambience_tween.play()
	if not _suspended and unlocked and not _pending_ambience.is_empty():
		var pending := _pending_ambience
		_pending_ambience = ""
		set_ambience(pending)

func stop_ambience() -> void:
	_ambience_resume_active = false
	if is_instance_valid(_ambience_tween) and _ambience_tween.is_valid(): _ambience_tween.kill()
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	_pending_ambience = ""

func stop_all(clear_cache: bool = false) -> void:
	_ambience_resume_active = false
	if is_instance_valid(_ambience_tween) and _ambience_tween.is_valid():
		_ambience_tween.kill()
	for voice in _voices:
		voice.player.stop()
		voice.player.stream = null
	if is_instance_valid(music_controller):
		music_controller.stop_all()
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	_pending_ambience = ""
	_last_event_ms.clear()
	if clear_cache:
		_last_variant.clear()
		_streams.clear()

func snapshot() -> Dictionary:
	var result := _stats.duplicate()
	result.pool_size = _voices.size()
	result.active_voices = _active_voice_count()
	result.cached_streams = _streams.size()
	result.settings = settings.duplicate()
	result.music = music_controller.snapshot() if is_instance_valid(music_controller) else {}
	result.suspended = _suspended
	result.suspension_reasons = {"manual":_manual_suspended,"focus":_focus_suspended,"application":_app_suspended}
	result.unlocked = unlocked
	result.events = _events.size()
	result.buses = {}
	for channel in BUS_NAMES:
		var index := AudioServer.get_bus_index(BUS_NAMES[channel])
		if index >= 0:
			result.buses[channel] = {"volume_db":AudioServer.get_bus_volume_db(index),"muted":AudioServer.is_bus_mute(index),"peak_db":AudioServer.get_bus_peak_volume_left_db(index,0)}
	result.last_save_error = last_save_error
	result.web_storage_status = _web_storage_status
	return result

func _exit_tree() -> void:
	stop_all(true)
	for tween in _volume_tweens.values():
		tween.kill()
	_volume_tweens.clear()
