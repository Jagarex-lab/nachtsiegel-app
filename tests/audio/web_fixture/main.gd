extends Control
## Disposable exported-engine fixture, independent of production scenes/autoloads.
const Manager = preload("res://scripts/audio/audio_manager.gd")
var audio: Node
var report := {"ready": false, "last_id": -1, "last_result": false, "native_checks": 0}
var _callback: JavaScriptObject
var _publish_elapsed := 0.0
var status: Label

func _ready() -> void:
	audio = Manager.new()
	audio.settings_path = "user://audio_fixture_settings.cfg"
	add_child(audio)
	var button := Button.new()
	button.text = "ORAFOLD Audio QA – tap to unlock"
	button.position = Vector2(30, 30)
	button.size = Vector2(700, 70)
	button.pressed.connect(audio.unlock_audio)
	add_child(button)
	status = Label.new()
	status.position = Vector2(30, 120)
	status.size = Vector2(800, 450)
	add_child(status)
	if OS.has_feature("web"):
		_callback = JavaScriptBridge.create_callback(_command)
		JavaScriptBridge.get_interface("window").audioQACommand = _callback
	report.ready = true
	audio.set_music("menu", 0.15)
	_publish()
	if "--audio-fixture-native" in OS.get_cmdline_user_args():
		_native_checks.call_deferred()

func _process(delta: float) -> void:
	_publish_elapsed += delta
	if _publish_elapsed >= 0.1:
		_publish_elapsed = 0.0
		_publish()

func _publish() -> void:
	report.snapshot = audio.snapshot()
	status.text = JSON.stringify(report, "  ")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.audioQA=" + JSON.stringify(report) + ";")

func _command(arguments: Array) -> void:
	var command: Variant = JSON.parse_string(str(arguments[0]))
	if not command is Dictionary:
		return
	report.last_id = int(command.get("id", -1))
	report.last_result = false
	match str(command.get("action", "")):
		"event": report.last_result = audio.play_event(str(command.get("event", "card.draw")), command.get("context", {}))
		"music": report.last_result = audio.set_music(str(command.get("context", "duel")), float(command.get("fade", 0.2)))
		"volume": report.last_result = audio.set_volume(str(command.get("channel", "music")), float(command.get("value", 0.37)))
		"mute":
			audio.set_muted(bool(command.get("value", false)))
			report.last_result = true
		"reduced":
			audio.set_reduced_intensity(bool(command.get("value", false)))
			report.last_result = true
		"suspend":
			audio.set_suspended(bool(command.get("value", true)))
			report.last_result = true
		"save": report.last_result = audio.save_settings() == OK
		"burst":
			for index in range(200):
				audio.play_event("creature.attack", {"faction": "stillwacht", "rarity": "legendary"})
			report.last_result = true
	_publish()

func _native_checks() -> void:
	var failures: Array[String] = []
	if not audio.unlocked: failures.append("native locked")
	if not audio.play_event("card.draw"): failures.append("event rejected")
	if audio.play_event("qa.unknown"): failures.append("invalid accepted")
	audio.set_volume("music", 0.37)
	if audio.save_settings() != OK: failures.append("save failed")
	if not audio.set_music("duel", 0.1): failures.append("music rejected")
	# The requested duel fade is queued behind the initial menu fade. A fixed
	# delay equal to both nominal durations can end one process frame too soon.
	# Observe the real terminal state, and still fail a genuinely stuck fade.
	var crossfade_started := Time.get_ticks_msec()
	var crossfade_settled := false
	var music_state: Dictionary = audio.snapshot().music
	while Time.get_ticks_msec() - crossfade_started < 2000:
		music_state = audio.snapshot().music
		if music_state.context == "duel" and music_state.pending_context == "" and not music_state.transitioning and music_state.playing == 1:
			crossfade_settled = true
			break
		await get_tree().process_frame
	if not crossfade_settled:
		failures.append("crossfade timeout after %d ms; actual music state: %s" % [Time.get_ticks_msec() - crossfade_started, JSON.stringify(music_state)])
	audio.set_suspended(true)
	if audio.play_event("card.draw"): failures.append("suspended event accepted")
	audio.set_suspended(false)
	report.native_checks = 7
	report.failures = failures
	_publish()
	print("AUDIO_NATIVE_QA ", JSON.stringify(report))
	audio.stop_all(true)
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
