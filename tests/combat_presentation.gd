extends SceneTree
const Model=preload("res://scripts/battle_model.gd")
const Bot=preload("res://tests/auto_player.gd")
const Store=preload("res://scripts/progress_store.gd")
var failures=0
var assertions=0
var arena
var metrics: Array=[]
func check(value: bool, title: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",title)
func _initialize() -> void:call_deferred("run")
func settle() -> void:await process_frame;await process_frame
func idle() -> void:
	var deadline=Time.get_ticks_msec()+12000
	while arena.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not arena.busy,"Presentation terminates within bounded deadline")
func play_duel(reduced: bool, low: bool, passing: bool=false) -> void:
	arena=load("res://scenes/arena.tscn").instantiate();arena.low_effects=low;root.add_child(arena);arena._set_reduced_motion(reduced,false);arena.onboarding_step=3;await settle()
	var started=Time.get_ticks_usec();var frames=0;var frame_times: Array=[];var peak_nodes=0;var peak_memory=0
	for turn in 22:
		if arena.finished:break
		if not passing:
			for move in 8:
				var choice=Bot.choice(arena.battle)
				if choice.index<0 or choice.score<0:break
				arena._select_card(choice.index);await settle();arena._choose_lane(choice.lane);await settle()
		var old_round=arena.round_number;print("DUEL ",root.size," reduced ",reduced," round ",old_round);arena._end_turn()
		for repeat in 12:arena._end_turn();arena._choose_lane(0);arena._select_card(0)
		check(arena.busy,"Rapid inputs stay locked")
		var deadline=Time.get_ticks_msec()+12000;var last=Time.get_ticks_usec()
		while arena.busy and Time.get_ticks_msec()<deadline:
			await process_frame
			var now=Time.get_ticks_usec();frame_times.append((now-last)/1000.0);last=now;frames+=1
			peak_nodes=maxi(peak_nodes,get_node_count());peak_memory=maxi(peak_memory,int(Performance.get_monitor(Performance.MEMORY_STATIC)))
		if arena.busy:printerr("DIAGNOSTIC: viewport ",root.size," phase ",arena.phase," fps ",Engine.get_frames_per_second()," last snapshot ",arena.visual_state.keys())
		check(not arena.busy,"Animated turn finishes")
		check(arena.round_number==old_round+1 or arena.finished,"Rapid input never resolves two turns")
		check(arena.visual_state.is_empty(),"No stale visual snapshot after phase sequence")
		var journal=arena.presentation_trace
		check(not journal.is_empty() and journal[0].kind=="player_attack","Player strikes before any enemy action")
		check(journal[-1].after==arena.battle.snapshot(),"Last immutable visual snapshot equals authoritative result")
		check(arena.presenter.canvas.jobs.size()<=16,"FX pool bounded")
	check(arena.finished,"Complete presented duel reaches an actual result")
	check(arena.battle.result.begins_with("NIEDERLAGE") if passing else arena.battle.result.begins_with("SIEG"),"Expected legal duel outcome")
	await settle();check(arena.modal_kind=="result","Result transition is reachable")
	frame_times.sort()
	metrics.append({"reduced_motion":reduced,"low_effects":low,"passing":passing,"viewport":[root.size.x,root.size.y],"rendered_frames":frames,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"p50_frame_ms":frame_times[frame_times.size()/2] if not frame_times.is_empty() else 0,"p95_frame_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"peak_nodes":peak_nodes,"peak_static_bytes":peak_memory,"peak_fx":arena.presenter.canvas.peak_active,"peak_tweens":arena.presenter.peak_tweens,"result":arena.battle.result})
	arena.queue_free();await settle()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/combat")
	# Pure journal tests cover every AI profile and outcome without scene timing.
	for profile in ["standard","easy","defensive","tactical","challenging"]:
		for seed_value in 10:
			var m=Model.new();m.start(8802026+seed_value,profile)
			for turn in 18:
				if m.finished:break
				m.resolve_turn()
				check(m.presentation[0].kind=="player_attack","Journal starts with original player phase")
				check(m.presentation[-1].after==m.snapshot(),"Journal closes on authoritative state")
	# No late enemy spawn/attack may follow an immediate player victory.
	var m=Model.new();m.start();m.foe_hp=1;m.allies[0]=m.CARD_POOL[0].duplicate(true);m.resolve_turn()
	check(m.presentation.size()==2 and m.presentation[-1].kind=="result","Lethal player strike suppresses enemy phase")
	for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=dimensions;await settle()
		await play_duel(dimensions.x==915,dimensions.x==844)
	root.size=Vector2i(844,390);await settle();await play_duel(false,false);await play_duel(false,false,true)
	# Stress pooled family effects, then change movement mode while work is active.
	arena=load("res://scenes/arena.tscn").instantiate();root.add_child(arena);await settle()
	for i in 500:arena.presenter.effect(["ASH","TIDE","THORN","VEIL"][i%4],"impact",Vector2(600,300),Vector2(600,300))
	check(arena.presenter.canvas.jobs.size()==16,"500 simultaneous requests cannot grow FX nodes")
	var face=arena.hero_medallions[0];var target=face.position
	arena.presenter.animate(face,"position",target+Vector2(0,10),.8);arena._set_reduced_motion(true,false)
	check(arena.presenter.tweens.is_empty(),"Reduced movement cancels in-flight transforms")
	arena.allies[0]=arena.CARD_POOL[0].duplicate(true);arena._end_turn();root.size=Vector2i(915,412);await idle()
	check(arena.round_number==2,"Viewport resize during combat preserves resolution")
	await create_timer(.8).timeout;check(arena.presenter.canvas.jobs.is_empty(),"Expired effects are retired")
	arena.queue_free();await settle()
	# Real audio configuration and native touch targets, persistence and mute isolation.
	var app=load("res://scenes/front_end.tscn").instantiate();app.store=Store.new("user://qa_combat_settings.json");root.add_child(app);app.show_page("av");await settle()
	var audio=root.get_node("GameAudio")
	for bus in ["Music","SFX","UI"]:
		var slider=app.audio_sliders[bus];var rect=slider.get_global_rect()
		check(rect.size.y>=44,"Audio slider has 44px touch area")
		slider.value=0
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"Independent mute "+bus)
		slider.value=.55
		check(is_equal_approx(audio.volumes[bus],.55),"Independent gain "+bus)
	var loaded=Store.new(app.store.path)
	check(is_equal_approx(float(loaded.data.settings.audio.SFX),.55),"Audio settings persist")
	check(audio.voices.size()==10 and audio.get_child_count()==11,"Audio voice/node budget remains fixed")
	for i in 100:audio.cue("hit")
	check(audio.history.size()<=64 and audio.voices.size()==10,"Audio burst cannot allocate unbounded players")
	app.queue_free();await create_timer(.5).timeout
	var file=FileAccess.open("res://work/combat/performance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"environment":"Linux Xvfb / llvmpipe, Dummy audio; software renderer, NOT physical mobile hardware","duels":metrics},"  "))
	print("COMBAT PRESENTATION: %d assertions, %d failures; complete duels, event order, rapid input, resize, bounded FX/audio and persisted mixer" % [assertions,failures])
	finish_test(1 if failures else 0)

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
