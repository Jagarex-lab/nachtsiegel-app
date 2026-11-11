extends SceneTree
## Isolated opt-in audio regression suite. Does not instantiate a battle or mutate game rules.
## Run after editor import: godot --headless --audio-driver Dummy --path . --script tests/audio/runtime_suite.gd
const Audio = preload("res://scripts/audio/audio_manager.gd")
const Router = preload("res://scripts/audio/sound_event_router.gd")
var assertions := 0
var failures := 0
var measurements: Dictionary = {}
var _paths: Array[String] = []
var _managers: Array[Node] = []
var _chosen_clip := ""

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL audio: ", label)

func read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func write_json(name: String, data: Variant) -> String:
	var path := "user://orafold_audio_test_" + name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_paths.append(path)
	return path

func fresh():
	var manager = Audio.new()
	manager.settings_path = "user://orafold_audio_test_%d.cfg" % _managers.size()
	_paths.append(manager.settings_path)
	DirAccess.remove_absolute(manager.settings_path)
	_managers.append(manager)
	root.add_child(manager)
	return manager

func wait_realtime(milliseconds: int) -> void:
	var until := Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec() < until:
		await create_timer(0.01).timeout

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog := read_json("res://data/audio/audio_catalog.json")
	var events := read_json("res://data/audio/audio_events.json")
	var manager = fresh()
	await process_frame
	check(manager.configure("res://data/audio/audio_catalog.json", "res://data/audio/audio_events.json"), "production manifests configure")
	var initial: Dictionary = manager.snapshot()
	check(initial.pool_size == 16, "fixed sixteen player pool")
	check(initial.active_voices == 0, "idle pool")
	check(initial.music.players == 2, "exactly two music players")
	var all_players: Array[AudioStreamPlayer] = []
	for child in manager.get_children():
		if child is AudioStreamPlayer:
			all_players.append(child)
		for grandchild in child.get_children():
			if grandchild is AudioStreamPlayer:
				all_players.append(grandchild)
	check(all_players.size() == 19, "nineteen bounded one-shot/music/ambience players")
	for player in all_players:
		check(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "explicit stream backend " + player.name)
	check(not manager.play_event("unknown.event"), "unknown event returns false")
	check(not manager.play_event(""), "empty event returns false")
	check(not manager.set_music("unknown.context"), "unknown music returns false")
	check(manager.snapshot().active_voices == 0, "invalid inputs have no side effects")
	var root_bus := AudioServer.get_bus_index("ORAFOLD")
	check(root_bus > 0, "independent audio root bus")
	check(AudioServer.get_bus_effect_count(root_bus) > 0 and AudioServer.get_bus_effect(root_bus,0) is AudioEffectLimiter, "summed mix has safety limiter")
	for bus in ["ORAFOLD Music","ORAFOLD SFX","ORAFOLD UI","ORAFOLD Ambience"]:
		check(AudioServer.get_bus_index(bus) > 0, "separate bus " + bus)
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == "ORAFOLD", "bus routed to isolated root " + bus)
	# Every declared event must reach an actual AudioStreamPlayer using the shipped pack.
	for name in events.events:
		manager.stop_all()
		check(manager.play_event(name), "real asset event " + name)
		check(manager.snapshot().active_voices > 0, "event allocated voice " + name)
	manager.stop_all()
	check(manager.snapshot().active_voices == 0, "stop releases all voices")
	for faction in ["zwoelf_haeuser","stillwacht","vielgestalt","neunte_stunde","houses","stillwatch","morph","ninth"]:
		manager.stop_all()
		check(manager.play_event("creature.summon", {"faction":faction,"rarity":"legendary"}), "identity event " + faction)
		check(manager.snapshot().active_voices == 3, "base + faction + rarity " + faction)
	for rarity in ["common","rare","epic","legendary"]:
		manager.stop_all()
		manager.play_event("card.play", {"rarity":rarity})
		check(manager.snapshot().active_voices == (1 if rarity == "common" else 2), "rarity layer " + rarity)
	manager.stop_all()
	manager.set_reduced_intensity(true,false)
	manager.play_event("card.play", {"faction":"stillwacht","rarity":"legendary"})
	check(manager.snapshot().active_voices == 2, "reduced intensity removes rarity layer")
	var reduced_gain: float = manager.get_node("Voice0").volume_db
	manager.stop_all()
	manager.set_reduced_intensity(false,false)
	manager.play_event("card.play", {"faction":"stillwacht","rarity":"legendary"})
	check(is_equal_approx(float(manager.get_node("Voice0").volume_db)-reduced_gain,5.0), "reduced intensity lowers primary by five dB")
	manager.set_reduced_intensity(false,false)
	manager.stop_all()
	# Isolate rate limits and pool behaviour with real shipped streams and controlled metadata.
	var draw: Dictionary = events.events["card.draw"].duplicate(true)
	draw["cooldown_ms"] = 0
	draw["max_voices"] = 16
	draw["priority"] = 1
	draw.erase("faction_layers")
	draw.erase("rarity_layers")
	var one := draw.duplicate(true)
	one["max_voices"] = 1
	var cooldown := draw.duplicate(true)
	cooldown["cooldown_ms"] = 200
	var fixture_events := {"version":1,"events":{"test.variants":draw,"test.one":one,"test.cooldown":cooldown}}
	var fixture_path := write_json("events", fixture_events)
	check(manager.configure("res://data/audio/audio_catalog.json",fixture_path), "controlled events configure")
	check(manager.play_event("test.one"), "single voice accepted")
	check(not manager.play_event("test.one"), "event voice cap rejects retrigger")
	manager.stop_all()
	check(manager.play_event("test.cooldown"), "cooldown first accepted")
	check(not manager.play_event("test.cooldown"), "cooldown throttles repeat")
	await wait_realtime(230)
	check(manager.play_event("test.cooldown"), "cooldown expires")
	manager.stop_all()
	var before_players := manager.get_child_count()
	var started := Time.get_ticks_usec()
	for index in range(10000):
		manager.play_event("test.variants", {"faction":"stillwacht","intensity":0.6})
	var dispatch_us := Time.get_ticks_usec()-started
	var saturated: Dictionary = manager.snapshot()
	measurements["burst_10000_dispatch_ms"] = dispatch_us/1000.0
	measurements["pool_size"] = saturated.pool_size
	measurements["peak_voices"] = saturated.peak_voices
	check(saturated.active_voices <= 16 and saturated.peak_voices <= 16, "burst cannot exceed fixed budget")
	check(manager.get_child_count() == before_players, "burst allocates no extra players")
	check(dispatch_us < 5000000, "ten thousand dispatches complete under five seconds on host")
	manager.stop_all()
	# No-repeat checks observe chosen actual stream paths, independently of RNG seed.
	var previous := ""
	manager.event_played.connect(func(_event: String, clip: String): _chosen_clip = clip)
	for index in range(20):
		check(manager.play_event("test.variants"), "variant play accepted")
		var selected := _chosen_clip
		check(not selected.is_empty(), "variant stream attached")
		check(previous.is_empty() or selected != previous, "adjacent variants differ")
		previous = selected
		for child in manager.get_children():
			if child is AudioStreamPlayer:
				child.stop()
	var gains: Array[float] = []
	for intensity in [-100.0,1000.0,NAN]:
		manager.stop_all()
		manager.play_event("test.variants", {"intensity":intensity,"damage":99999})
		gains.append(float(manager.get_node("Voice0").volume_db))
	check(is_equal_approx(gains[1]-gains[0],6.0), "presentation intensity clamps to six dB range")
	check(gains[2] > gains[0] and gains[2] < gains[1], "invalid intensity uses safe default")
	# Sanitize external numeric settings, and verify stable dedicated ConfigFile persistence.
	for channel in ["master","music","sfx","ambience"]:
		check(manager.set_volume(channel,0.37,false), "volume accepted " + channel)
		check(is_equal_approx(float(manager.snapshot().settings[channel]),0.37), "volume applied " + channel)
	check(not manager.set_volume("unknown",0.5,false), "unknown volume channel rejected")
	check(not manager.set_volume("music",NAN,false), "NaN volume rejected")
	check(not manager.set_volume("music",INF,false), "infinite volume rejected")
	manager.set_muted(true,false)
	manager.set_reduced_intensity(true,false)
	check(manager.save_settings() == OK, "dedicated settings saved")
	var persisted_path: String = manager.settings_path
	var clone = fresh()
	clone.settings_path = persisted_path
	check(clone.load_settings() == OK, "settings loaded in new manager")
	var saved: Dictionary = clone.snapshot().settings
	for channel in ["master","music","sfx","ambience"]:
		check(is_equal_approx(float(saved[channel]),0.37), "roundtrip " + channel)
	check(saved.muted and saved.reduced_intensity, "roundtrip flags")
	check(not clone.play_event("card.draw"), "mute suppresses events")
	check(AudioServer.is_bus_mute(root_bus), "global mute reaches root bus")
	var corrupt := ConfigFile.new()
	corrupt.set_value("audio","version",99)
	corrupt.save(clone.settings_path)
	check(clone.load_settings() == ERR_INVALID_DATA, "future settings schema rejected safely")
	check(clone.snapshot().settings == Audio.DEFAULT_SETTINGS, "unknown schema restores defaults")
	var future_text := FileAccess.get_file_as_string(clone.settings_path)
	check(clone.save_settings() == ERR_INVALID_DATA, "future native schema blocks writes")
	check(FileAccess.get_file_as_string(clone.settings_path) == future_text, "future native settings remain intact")
	corrupt.set_value("audio","version",1)
	corrupt.set_value("audio","music","loud")
	corrupt.set_value("audio","muted",123)
	corrupt.save(clone.settings_path)
	check(clone.load_settings() == OK, "typed fallback config loads")
	check(clone.snapshot().settings.music == Audio.DEFAULT_SETTINGS.music and not clone.snapshot().settings.muted, "invalid settings values fall back")
	check(manager.set_volume("sfx",0,false), "zero SFX accepted")
	await wait_realtime(150)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("ORAFOLD SFX")), "zero SFX fully muted")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("ORAFOLD UI")), "zero SFX preserves independent UI gain")
	manager.set_volume("sfx",0.37,false)
	await wait_realtime(150)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("ORAFOLD SFX")), "raising SFX restores bus")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("ORAFOLD SFX"))),0.37), "smooth SFX gain reaches requested value")
	var original_settings_path: String = manager.settings_path
	manager.settings_path = "user://missing_audio_test_directory/settings.cfg"
	check(manager.save_settings() != OK, "unwritable settings destination returns error")
	check(manager.snapshot().last_save_error != OK, "save failure visible in status")
	manager.settings_path = original_settings_path
	check(manager.save_settings() == OK, "save recovers after valid destination restored")
	manager.set_muted(false,false)
	manager.set_reduced_intensity(false,false)
	# Validate the browser mirror schema in native pure helpers; browser tests cover actual localStorage.
	var mirror_settings: Dictionary = Audio.DEFAULT_SETTINGS.duplicate()
	mirror_settings.music = 0.23
	mirror_settings.reduced_intensity = true
	var valid_raw := JSON.stringify({"version":1,"settings":mirror_settings})
	var decoded: Dictionary = manager._decode_mirror(valid_raw)
	check(decoded.status == "valid" and decoded.settings == mirror_settings, "complete mirror roundtrip")
	check(manager._decode_mirror(null).status == "missing", "absent mirror distinguishable from corruption")
	for invalid_raw in ["{", "[]", "null", "42", "true", "\"text\"", 123, false]:
		check(manager._decode_mirror(invalid_raw).status == "invalid", "mirror rejects malformed/root type " + str(invalid_raw))
	for version in [0,2,"1",true,null]:
		var invalid_version := JSON.stringify({"version":version,"settings":mirror_settings})
		check(manager._decode_mirror(invalid_version).status == "invalid", "mirror rejects unsupported version " + str(version))
	check(manager._decode_mirror(JSON.stringify({"version":1})).status == "invalid", "mirror requires settings payload")
	for key in Audio.DEFAULT_SETTINGS:
		var incomplete := mirror_settings.duplicate()
		incomplete.erase(key)
		if key == "ui":
			check(manager._validate_mirror_settings(incomplete).ui == incomplete.sfx, "old v1 mirror inherits original UI/SFX gain")
		else:
			check(manager._validate_mirror_settings(incomplete).is_empty(), "mirror requires field " + key)
	for invalid_number in [NAN,INF,-0.01,1.01,true,"0.5",null]:
		var invalid_settings := mirror_settings.duplicate()
		invalid_settings.music = invalid_number
		check(manager._validate_mirror_settings(invalid_settings).is_empty(), "mirror rejects invalid numeric value " + str(invalid_number))
	for invalid_flag in [0,1,"true",null]:
		var invalid_settings := mirror_settings.duplicate()
		invalid_settings.muted = invalid_flag
		check(manager._validate_mirror_settings(invalid_settings).is_empty(), "mirror requires boolean flag " + str(invalid_flag))
	check(manager._validate_mirror_settings([]).is_empty(), "mirror rejects non-dictionary settings")
	var prior_settings: Dictionary = manager.settings.duplicate()
	manager._decode_mirror("{\"version\":99,\"settings\":{}}")
	check(manager.settings == prior_settings, "invalid mirror decoding does not mutate live settings")
	var prior_key: String = manager._browser_settings_key()
	var prior_path: String = manager.settings_path
	manager.settings_path = prior_path + ".other"
	check(manager._browser_settings_key() != prior_key, "browser mirror namespaced by settings path")
	manager.settings_path = prior_path
	check(manager._browser_settings_key() == prior_key, "browser mirror namespace stable across restarts")
	# Music must stream through bounded players, fade continuously and coalesce rapid changes.
	check(manager.configure("res://data/audio/audio_catalog.json","res://data/audio/audio_events.json"), "restore production events")
	var music_names: Array = catalog.music.keys()
	check(manager.set_music(music_names[0],0.2), "first music accepted")
	var low: Dictionary = manager.snapshot().music
	check(low.transitioning and low.playing == 1, "music fades in")
	await create_timer(0.1).timeout
	var middle: Dictionary = manager.snapshot().music
	check(float(middle.gains[0])+float(middle.gains[1]) > 0.0, "fade gains advance")
	await create_timer(0.15).timeout
	check(not manager.snapshot().music.transitioning, "first fade completes")
	check(manager.set_music(music_names[1],0.15), "crossfade accepted")
	check(manager.snapshot().music.playing == 2, "crossfade uses two players")
	for index in range(2,music_names.size()):
		check(manager.set_music(music_names[index],0.05), "rapid request accepted")
		check(manager.snapshot().music.playing <= 2, "rapid requests remain bounded")
	await create_timer(0.35).timeout
	var final_music: Dictionary = manager.snapshot().music
	check(final_music.context == music_names[-1], "latest queued context wins")
	check(not final_music.transitioning and final_music.playing == 1, "crossfade settles and frees old stream")
	check(manager.set_music(music_names[-1],0.1), "repeated context is idempotent")
	check(not manager.snapshot().music.transitioning, "same context does not restart fade")
	for context in music_names:
		manager.stop_all()
		check(manager.set_music(context,0.02), "direct context starts " + context)
		await wait_realtime(45)
		check(manager.snapshot().music.playing == 1 and not manager.snapshot().music.transitioning, "direct context settles " + context)
		var music_player := manager.music_controller.get_node("Music0") as AudioStreamPlayer
		check(music_player.stream is AudioStreamOggVorbis, "Ogg streaming context " + context)
		check(music_player.stream.loop == bool(catalog.clips[catalog.music[context]].loop), "context loop/stinger flag " + context)
	# A streaming backend can drop paused playback; resume restores the active stream.
	manager.stop_all()
	manager.set_music("menu",0.02)
	await wait_realtime(100)
	var resume_player := manager.music_controller.get_node("Music0") as AudioStreamPlayer
	manager.set_suspended(true)
	resume_player.stop()
	manager.set_suspended(true) # repeated lifecycle guard must retain resume state
	manager.set_suspended(false)
	check(resume_player.playing, "backend-dropped music resumes from captured active transport")
	check(manager.snapshot().music.playing == 1, "resume keeps one settled music voice")
	# Pausing releases short voices and freezes music/fade work until explicit resume.
	manager.play_event("creature.attack")
	manager.set_suspended(true)
	check(manager.snapshot().active_voices == 0, "suspend stops one shots")
	check(not manager.play_event("card.draw"), "suspended events rejected")
	check(not manager.music_controller.is_processing(), "no fade processing in background")
	manager.set_suspended(false)
	check(manager.play_event("card.select"), "events resume")
	manager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	manager.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	manager.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(manager.snapshot().suspended, "application resume preserves remaining focus suspension")
	manager.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not manager.snapshot().suspended, "focus return clears last lifecycle suspension")
	manager.set_suspended(true)
	manager.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	manager.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(manager.snapshot().suspended, "manual suspension survives lifecycle resume")
	manager.set_suspended(false)
	check(not manager.snapshot().suspended, "manual resume releases final guard")
	manager.stop_all(true)
	check(manager.snapshot().music.playing == 0, "stop_all stops music")
	var ambience_ids: Array[String] = []
	for clip_id in catalog.clips:
		if catalog.clips[clip_id].bus == "Ambience":
			ambience_ids.append(clip_id)
	check(not ambience_ids.is_empty(), "real ambience exists")
	check(manager.set_ambience(ambience_ids[0],0.05), "ambience stream accepted")
	check(not manager.set_ambience("unknown"), "unknown ambience rejected")
	await wait_realtime(80)
	check(manager.get_node("Ambience").playing, "ambience starts after fade callback")
	manager.set_suspended(true)
	check(manager.get_node("Ambience").stream_paused, "ambience pauses in background")
	manager.get_node("Ambience").stop()
	manager.set_suspended(false)
	check(manager.get_node("Ambience").playing, "backend-dropped ambience resumes from captured active transport")
	manager.stop_all(true)
	check(manager.get_node("Ambience").stream == null, "ambience resource released")
	manager.set_suspended(true)
	check(manager.set_ambience(ambience_ids[0],0.05), "suspended ambience request queued")
	check(not manager.get_node("Ambience").playing, "queued ambience does not play in background")
	manager.set_suspended(false)
	await wait_realtime(100)
	check(manager.get_node("Ambience").playing, "queued ambience resumes after user returns")
	manager.stop_all(true)
	# Missing files and malformed data are audio errors; no gameplay model is involved.
	var missing_catalog := catalog.duplicate(true)
	missing_catalog.clips["test_missing"] = {"path":"res://assets/audio/absent.wav","bus":"SFX","gain_db":0,"loop":false}
	var missing_events := {"version":1,"events":{"test.missing":{"variants":["test_missing"],"bus":"SFX","cooldown_ms":0,"max_voices":1}}}
	var missing = fresh()
	await process_frame
	missing.configure(write_json("missing_catalog",missing_catalog),write_json("missing_events",missing_events))
	check(not missing.play_event("test.missing"), "absent asset safely returns false")
	check(not missing.configure("user://orafold_audio_no_catalog.json",fixture_path), "absent manifest safely returns false")
	check(not missing.configure(write_json("bad_catalog",[]),fixture_path), "invalid root type rejected")
	var router = Router.new(manager)
	check(not router.route("unknown.event"), "adapter ignores unknown event")
	check(not router.resonance("invented"), "adapter accepts no invented resonance thresholds")
	# Clean isolated test files, nodes and cached references before checking leak-free exit.
	for item in _managers:
		item.stop_all(true)
	await wait_realtime(120)
	for item in _managers:
		item.queue_free()
	_managers.clear()
	await process_frame
	await wait_realtime(120)
	for path in _paths:
		DirAccess.remove_absolute(path)
	var report := {"assertions":assertions,"failures":failures,"measurements":measurements,"platform":OS.get_name(),"godot":Engine.get_version_info().string,"audio_driver":AudioServer.get_driver_name()}
	DirAccess.make_dir_recursive_absolute("res://work/audio")
	var report_file := FileAccess.open("res://work/audio/runtime-results.json",FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report,"  ")+"\n")
		report_file.close()
	print("ORAFOLD_AUDIO_TESTS ",JSON.stringify(report))
	quit(1 if failures else 0)
