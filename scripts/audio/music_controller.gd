extends Node
## Two streaming players; rapid requests coalesce until the current fade completes.
## No gameplay state is inspected here. Music contexts are presentation inputs.

var _clips: Dictionary = {}
var _contexts: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _gains: Array[float] = [0.0, 0.0]
var _starts: Array[float] = [0.0, 0.0]
var _targets: Array[float] = [0.0, 0.0]
var _clip_gains: Array[float] = [0.0, 0.0]
var _elapsed := 0.0
var _duration := 0.0
var _active := -1
var _context := ""
var _pending_context := ""
var _pending_duration := 1.5
var _suspended := false
var _resume_positions: Array[float] = [0.0, 0.0]
var _resume_active: Array[bool] = [false, false]
var _unlocked := true
var _bus := "ORAFOLD Music"

func _ready() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		# Keep Web playback on the engine mixer so buses and fades stay consistent.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.name = "Music%d" % index
		player.bus = _bus
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	set_process(false)

func configure(catalog: Dictionary, bus: String = "ORAFOLD Music") -> void:
	stop_all()
	_clips = catalog.get("clips", {}) if catalog.get("clips", {}) is Dictionary else {}
	_contexts = catalog.get("music", {}) if catalog.get("music", {}) is Dictionary else {}
	_bus = bus
	for player in _players:
		player.bus = _bus

func set_unlocked(value: bool) -> void:
	_unlocked = value
	if _unlocked and not _suspended and not _pending_context.is_empty():
		var pending := _pending_context
		_pending_context = ""
		request_music(pending, _pending_duration)

func request_music(context: String, fade_seconds: float = 1.5) -> bool:
	if _players.size() < 2:
		return false
	if not _contexts.has(context) or not _contexts[context] is String:
		return false
	var clip: Variant = _clips.get(_contexts[context], {})
	if not clip is Dictionary or not clip.get("path", "") is String:
		return false
	var path: String = clip.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path, "AudioStream"):
		return false
	var fade := clampf(fade_seconds, 0.02, 12.0) if is_finite(fade_seconds) else 1.5
	if not _unlocked or _suspended or _duration > 0.0:
		# One pending slot avoids allocations and interrupted/clicking third voices.
		_pending_context = context
		_pending_duration = fade
		return true
	if context == _context and _active >= 0 and _players[_active].playing:
		return true
	var stream := load(path) as AudioStream
	if stream == null:
		return false
	# Duplicate import resources so loop flags do not mutate shared streams.
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		stream.loop = bool(clip.get("loop", true))
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if bool(clip.get("loop", true)) else AudioStreamWAV.LOOP_DISABLED
	var next := 0 if _active != 0 else 1
	var player := _players[next]
	player.stop()
	player.stream = stream
	var gain: Variant = clip.get("gain_db", 0.0)
	_clip_gains[next] = clampf(float(gain), -40.0, 0.0) if (gain is float or gain is int) and is_finite(float(gain)) else 0.0
	_gains[next] = 0.0
	player.volume_db = -80.0
	player.play()
	_starts = _gains.duplicate()
	_targets = [0.0, 0.0]
	_targets[next] = 1.0
	_elapsed = 0.0
	_duration = fade
	_active = next
	_context = context
	set_process(true)
	return true

func _process(delta: float) -> void:
	if _suspended or _duration <= 0.0:
		set_process(false)
		return
	_elapsed = minf(_elapsed + delta, _duration)
	var progress := _elapsed / _duration
	# Smooth endpoints avoid slope discontinuities. No per-frame resource loads.
	var shaped := progress * progress * (3.0 - 2.0 * progress)
	for index in range(2):
		_gains[index] = lerpf(_starts[index], _targets[index], shaped)
		_players[index].volume_db = linear_to_db(maxf(_gains[index], 0.0001)) + _clip_gains[index]
	if _elapsed < _duration:
		return
	_duration = 0.0
	for index in range(2):
		if _targets[index] <= 0.0:
			_players[index].stop()
			_players[index].stream = null
	set_process(false)
	if not _pending_context.is_empty():
		var pending := _pending_context
		_pending_context = ""
		request_music(pending, _pending_duration)

func set_suspended(value: bool) -> void:
	if value == _suspended: return
	_suspended = value
	for index in range(_players.size()):
		var player := _players[index]
		if value:
			_resume_active[index] = player.playing
			_resume_positions[index] = player.get_playback_position() if player.playing else 0.0
		player.stream_paused = value
		if not value and _resume_active[index] and player.stream != null:
			# Web STREAM playback may be dropped by the backend while paused.
			# Restart only a previously active stream, at its captured position.
			if OS.has_feature("web") or not player.playing:
				player.stop()
				player.play(_resume_positions[index])
			_resume_active[index] = false
	set_process(not value and _duration > 0.0)
	if not value and _unlocked and _duration <= 0.0 and not _pending_context.is_empty():
		var pending := _pending_context
		_pending_context = ""
		request_music(pending, _pending_duration)

func stop_all() -> void:
	_resume_active = [false, false]
	_resume_positions = [0.0, 0.0]
	for player in _players:
		player.stop()
		player.stream = null
	_gains = [0.0, 0.0]
	_starts = [0.0, 0.0]
	_targets = [0.0, 0.0]
	_duration = 0.0
	_elapsed = 0.0
	_active = -1
	_context = ""
	_pending_context = ""
	set_process(false)

func snapshot() -> Dictionary:
	var playing := 0
	for player in _players:
		if player.playing:
			playing += 1
	return {"context": _context, "pending_context": _pending_context,
		"transitioning": _duration > 0.0, "players": _players.size(),
		"playing": playing, "gains": _gains.duplicate(), "suspended": _suspended,
		"playback_positions": _players.map(func(player):return player.get_playback_position()),
		"volume_db": _players.map(func(player):return player.volume_db),
		"paused": _players.map(func(player):return player.stream_paused),
		"resume_positions": _resume_positions.duplicate()}

func _exit_tree() -> void:
	stop_all()
