extends Node
## Original licensed project cues; bounded voices and three independently persisted buses.
const CUES={"ui":"res://assets/audio/ui.wav","draw":"res://assets/audio/draw.wav","attack":"res://assets/audio/attack.wav","hit":"res://assets/audio/hit.wav","ASH":"res://assets/audio/ASH.wav","TIDE":"res://assets/audio/TIDE.wav","THORN":"res://assets/audio/THORN.wav","VEIL":"res://assets/audio/VEIL.wav","turn":"res://assets/audio/turn.wav","win":"res://assets/audio/win.wav","lose":"res://assets/audio/lose.wav"}
var streams: Dictionary={}
var volumes={"Music":.35,"SFX":.65,"UI":.5}
var voices: Array=[]
var music: AudioStreamPlayer
var unlocked := false
var history: Array=[]
var last_ui_ms := -1000
var quitting := false
var last_preview_ms := -1000
func _ready() -> void:
	if Engine.is_editor_hint():return
	for name in CUES:streams[name]=load(CUES[name])
	for name in volumes:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	for i in 10:
		var player=AudioStreamPlayer.new();player.bus="UI" if i>=8 else "SFX";player.volume_db=-8 if i>=8 else -10;add_child(player);voices.append(player)
	music=AudioStreamPlayer.new();music.bus="Music";music.volume_db=-6;music.stream=load("res://assets/audio/atmosphere.ogg");music.stream.loop=true;add_child(music)
	apply(volumes)
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(request_quit)
func apply(values: Dictionary) -> void:
	for name in volumes:
		volumes[name]=clampf(float(values.get(name,volumes[name])),0,1)
		var index=AudioServer.get_bus_index(name)
		AudioServer.set_bus_mute(index,volumes[name]<=.001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.001,volumes[name])))
func _input(event: InputEvent) -> void:
	if not quitting and not unlocked and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		unlocked=true;music.play()
func cue(name: String) -> void:
	if quitting or not streams.has(name):return
	if name=="ui" and Time.get_ticks_msec()-last_ui_ms<55:return
	if name=="ui":last_ui_ms=Time.get_ticks_msec()
	var group=voices.slice(8,10) if name=="ui" else voices.slice(0,8)
	var player: AudioStreamPlayer=group[0]
	for candidate in group:
		if not candidate.playing:player=candidate;break
	player.stop();player.stream=streams[name];player.play()
	history.append(name)
	if history.size()>64:history.pop_front()
func stop_all() -> void:
	for player in voices:
		player.stop();player.stream=null
	if is_instance_valid(music):music.stop();music.stream=null
	streams.clear()

func request_quit(code: int=0) -> void:
	if quitting:return
	quitting=true;stop_all()
	# Give the mixer one real update before engine teardown releases cached streams.
	await get_tree().create_timer(.10).timeout
	get_tree().quit(code)
func _exit_tree() -> void:stop_all()

func preview(bus: String) -> void:
	if Time.get_ticks_msec()-last_preview_ms<180:return
	last_preview_ms=Time.get_ticks_msec()
	if bus=="SFX":cue("hit")
	elif bus=="UI":cue("ui")
