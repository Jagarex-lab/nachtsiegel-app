extends "res://scripts/audio/audio_manager.gd"
## Sole product audio owner. Archive API delegates to the same bounded mixer.
const LEGACY_EVENTS := {"ui":"ui.confirm", "draw":"card.draw", "attack":"creature.attack", "hit":"creature.hit", "turn":"ui.confirm", "win":"battle.victory", "lose":"battle.defeat", "ASH":"combat.reaction", "TIDE":"combat.reaction", "THORN":"combat.reaction", "VEIL":"combat.reaction"}
var history: Array = []
var quitting := false
var last_preview_ms := -1000
var volumes: Dictionary:
	get: return {"Music":settings.music, "SFX":settings.sfx, "UI":settings.ui}
var voices: Array:
	get:
		var players: Array = []
		for voice in _voices: players.append(voice.player)
		return players

func _ready() -> void:
	super._ready()
	_migrate_archive_gains()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_quit)

func apply(values: Dictionary) -> void:
	for channel in {"Music":"music", "SFX":"sfx", "UI":"ui"}:
		var value: Variant = values.get(channel)
		if value is float or value is int:
			set_volume({"Music":"music", "SFX":"sfx", "UI":"ui"}[channel], value, false)
	# Archive applies its own already-persisted profile; no second settings writer.
	_apply_settings(false)

func cue(cue_name: String) -> void:
	if quitting or not LEGACY_EVENTS.has(cue_name): return
	if play_event(LEGACY_EVENTS[cue_name]):
		history.append(cue_name)
		if history.size() > 64: history.pop_front()

func preview(bus: String) -> void:
	if Time.get_ticks_msec() - last_preview_ms < 180: return
	last_preview_ms = Time.get_ticks_msec()
	if bus == "SFX": cue("hit")
	elif bus == "UI": cue("ui")

func request_quit(code: int = 0) -> void:
	if quitting: return
	quitting = true
	stop_all(true)
	await get_tree().create_timer(0.10).timeout
	get_tree().quit(code)

func _legacy_audio(document: Variant) -> Dictionary:
	if not document is Dictionary or document.get("schema_version") != 1 or not document.get("settings") is Dictionary: return {}
	var values: Variant = document.settings.get("audio")
	if not values is Dictionary: return {}
	for key in ["Music","SFX","UI"]:
		var value: Variant = values.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0: return {}
	return values.duplicate()

func _migrate_archive_gains() -> void:
	# Read only; never instantiate or rewrite the archived progress store.
	if FileAccess.file_exists(settings_path) or _web_storage_status not in ["native","missing"]: return
	var document: Variant = _read_dictionary("user://progress_v1.json")
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('nachtsiegel.progress.v1')}catch(e){return null}})()",true)
		if raw is String:
			var mirrored: Variant = JSON.parse_string(raw)
			if not _legacy_audio(mirrored).is_empty(): document = mirrored
	var gains := _legacy_audio(document)
	if not gains.is_empty(): migrate_legacy_settings(gains)
