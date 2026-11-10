extends SceneTree
## Real product owner, controls and resolved production logs. No rule edits.
const Shell=preload("res://scripts/alpha/shell.gd")
const Adapter=preload("res://scripts/audio/presentation_audio.gd")
const Model=preload("res://scripts/card_system/production_model.gd")
var assertions:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func count(sounds: Array,event_name: String) -> int:
	return sounds.filter(func(sound):return sound.event==event_name).size()
func settle() -> void:
	for i in 5:await process_frame
func run() -> void:
	var audio=root.get_node("GameAudio")
	var original_settings: Dictionary=audio.settings.duplicate()
	var original_path: String=audio.settings_path
	audio.settings_path="user://audio_integration_test.cfg"
	DirAccess.remove_absolute(audio.settings_path)
	audio.set_muted(false,false)
	check(audio.snapshot().pool_size==16 and audio.get_child_count()==18,"one owner has16 effects, one2-player music controller and one ambience player")
	check(audio._legacy_audio({"schema_version":99,"settings":{"audio":{"Music":0.1,"SFX":0.2,"UI":0.3}}}).is_empty(),"unknown archived profiles never migrate")
	check(audio._legacy_audio({"schema_version":1,"settings":{"audio":{"Music":0.1,"SFX":0.2,"UI":0.3}}}).UI==0.3,"old independent UI value survives migration")
	audio.apply({"Music":0.3,"SFX":0.4,"UI":0.6})
	check(audio.settings.music==0.3 and audio.settings.sfx==0.4 and audio.settings.ui==0.6,"Archive API changes sole actual mixer")
	var nodes:=audio.get_child_count()
	for i in 1000:audio.cue("hit")
	check(audio.voices.size()==16 and audio.get_child_count()==nodes and audio.history.size()<=64,"Archive stress stays bounded without a second player pool")
	audio.stop_all()
	var app=Shell.new();root.add_child(app);await settle()
	for dimensions in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions;app.page="settings";app.render();await settle()
		check(app.audio_settings.sliders.size()==5,"AlphaSettings exposes master/music/effects/UI/ambience")
		check(app.audio_settings.get_parent().get_parent() is ScrollContainer,"settings panel has a real scroll parent")
		for channel in ["master","music","sfx","ui","ambience"]:
			var slider: HSlider=app.audio_settings.sliders[channel]
			check(slider.get_global_rect().size.y/app.density>=44,"44px target "+channel)
	app.audio_settings.sliders.ui.value=0
	await create_timer(0.2).timeout
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.BUS_NAMES.ui)),"UI zero mutes actual UI bus")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.BUS_NAMES.sfx)),"UI mute keeps effects audible")
	app.audio_settings.sliders.ui.value=0.27
	var saved=ConfigFile.new();check(saved.load(audio.settings_path)==OK and is_equal_approx(saved.get_value("audio","ui"),0.27),"Alpha UI gain persists in actual native ConfigFile")
	app.audio_settings.mute_toggle.button_pressed=true
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("ORAFOLD")),"Alpha mute reaches one root bus")
	app.audio_settings.mute_toggle.button_pressed=false
	app.audio_settings.reduced_toggle.button_pressed=true
	check(audio.settings.reduced_intensity,"Alpha reduced-intensity control changes runtime")
	audio.settings_path="user://missing_audio_integration_dir/settings.cfg";app.audio_settings.sliders.music.value=0.31
	check(app.audio_settings.persistence_note.text.contains("nicht möglich"),"Alpha settings tell actual save failure")
	audio.settings_path="user://audio_integration_test.cfg"
	app.audio_settings.sliders.music.value=0.32
	check(not app.audio_settings.persistence_note.text.contains("nicht möglich"),"Alpha save note recovers")
	app.start_battle();await settle();app.confirm_menu()
	check(audio.snapshot().suspended and app.audio_paused,"real match menu explicitly suspends mixer")
	app.close_modal();check(not audio.snapshot().suspended,"return from actual menu resumes permitted music")
	# Real nested on-damage block watcher plus enclosing attack: one delta sound.
	var model=Model.new();check(model.start_alpha(model.catalog.deck("houses"),model.catalog.deck("stillwatch"),12345),"real550 model initialized")
	model.ai_policy=null;model.state.stage="battle";model.state.active="enemy";model.state.round=11
	for side in ["hero","enemy"]:
		model.state[side].lanes=[null,null,null,null,null];model.state[side].ward=0;model.state[side].block=0
	var victim: Dictionary=model.make_unit("hero",model.catalog.card("of-houses-007"),2);victim.hp=1;victim.summoned=false;model.state.hero.lanes[2]=victim
	var attacker: Dictionary=model.make_unit("enemy",model.catalog.card("oa-neutral-c02"),2);attacker.atk=2;attacker.summoned=false;model.state.enemy.lanes[2]=attacker
	model.events.clear();var before: Dictionary=model.snapshot();model.attack_phase("enemy")
	var adapter=Adapter.new();var immutable:=JSON.stringify([model.snapshot(),model.events])
	var sounds: Array=adapter.collect(model.events,before,model.catalog)
	check(count(sounds,"creature.attack")==1,"resolved attack exactly once despite nested logs")
	check(count(sounds,"creature.defeated")==1,"real fatal instance exactly once")
	check(count(sounds,"block.activate")==1,"nested on-damage block counted once before enclosing attack")
	check(adapter.collect(model.events,before,model.catalog).is_empty(),"repeated delivery ignored by seq, not cooldown")
	check(immutable==JSON.stringify([model.snapshot(),model.events]),"audio adapter leaves model/events byte-identical")
	check(count(sounds,"creature.hit.strong")==0,"no invented damage threshold")
	app.queue_free();await settle()
	audio.stop_all(true);DirAccess.remove_absolute("user://audio_integration_test.cfg")
	audio.settings_path=original_path;audio.settings=original_settings;audio._apply_settings(false)
	print("AUDIO PRODUCT INTEGRATION: %d assertions, %d failures" % [assertions,failures])
	audio.request_quit(1 if failures else 0)
