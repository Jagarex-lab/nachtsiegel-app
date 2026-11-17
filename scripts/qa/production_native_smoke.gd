extends Node
## QA-only exported entry scene: official native templates cannot execute --script.
## It uses the same packed catalog, model and policy; normal Linux QA keeps the game menu.
const Catalog=preload("res://scripts/production/catalog.gd")
const Model=preload("res://scripts/card_system/production_model.gd")
const Shell=preload("res://scripts/alpha/shell.gd")
var assertions:=0
var failures:=0
var last_touch_rect := Rect2()
func _ready() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func tap_control(control: Control) -> bool:
	# Self-contained because exported native QA intentionally excludes tests/.
	# Exercise the same original pointer ownership as a real player; emitting
	# Button.pressed cannot represent a touch or establish a scroll intent.
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			for _frame in 6:await get_tree().process_frame
		ancestor=ancestor.get_parent()
	var visible=control.get_global_rect().intersection(get_viewport().get_visible_rect())
	ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents:visible=visible.intersection(ancestor.get_global_rect())
		ancestor=ancestor.get_parent()
	last_touch_rect=visible
	if visible.size.x<43.9 or visible.size.y<43.9:return false
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=visible.get_center();event.pressed=pressed;Input.parse_input_event(event)
		for _frame in 6:await get_tree().process_frame
	return true
func run() -> void:
	check(OS.has_feature("native_smoke_qa") and OS.has_feature("debug"),"explicit native debug QA feature")
	var audio=get_tree().root.get_node("GameAudio")
	var original_audio_settings: Dictionary=audio.settings.duplicate()
	var original_audio_path: String=audio.settings_path
	audio.settings=audio.DEFAULT_SETTINGS.duplicate();audio._apply_settings(false)
	audio.settings_path="user://qa_native_audio_integration.cfg"
	DirAccess.remove_absolute(audio.settings_path)
	check(audio.snapshot().events==52 and audio.snapshot().cached_streams==153,"actual native pack includes52audio events and153effect streams")
	check(audio.snapshot().pool_size==16 and audio.get_child_count()==18,"actual native single mixer has bounded16effect voices and streaming children")
	check(FileAccess.file_exists("res://data/audio/asset_manifest.json") and FileAccess.file_exists("res://assets/audio/ORAFOLD-LICENSES.md"),"audio provenance and redistribution notice packaged")
	check(audio.play_event("card.draw"),"actual native packaged draw stream plays")
	check(audio.set_music("menu",0.02) and audio.set_ambience("ambience.rift",0.02),"native packaged streaming music and ambience start")
	for _frame in 3:await get_tree().process_frame
	await get_tree().create_timer(0.10).timeout
	check(audio.snapshot().music.playing==1 and audio._ambience.playing,"actual native streaming transports active before shutdown exercise")
	check(audio.set_volume("ui",0.27),"native independent UI gain accepted")
	var saved_audio=ConfigFile.new()
	check(saved_audio.load(audio.settings_path)==OK and is_equal_approx(float(saved_audio.get_value("audio","ui",-1)),0.27),"native executable persists actual audio ConfigFile")
	audio.set_muted(true,false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("ORAFOLD")),"native mute reaches actual output root")
	audio.set_muted(false,false);audio.set_suspended(true)
	check(audio.snapshot().suspended and audio.snapshot().active_voices==0,"native suspend discards transient voices")
	audio.set_suspended(false);check(not audio.snapshot().suspended,"native resume clears explicit pause")
	audio.settings_path="user://missing_native_audio_parent/settings.cfg"
	check(audio.save_settings()!=OK and audio.snapshot().last_save_error!=OK,"native persistence failure is observable")
	DirAccess.remove_absolute("user://qa_native_audio_integration.cfg")
	audio.settings_path=original_audio_path;audio.settings=original_audio_settings;audio._apply_settings(false)
	var catalog=Catalog.new()
	check(catalog.load_error.is_empty() and catalog.all_cards().size()==550,"all550 definitions actually included in export")
	for power in catalog.deck_ids():check(catalog.validate(catalog.deck(power)).ok,"exported starter "+power)
	check(FileAccess.file_exists("res://data/production/art_manifest.json"),"actual art manifest in exported resources")
	check(FileAccess.file_exists("res://assets/fonts/Cinzel-OFL.txt") and FileAccess.file_exists("res://assets/fonts/LICENSE"),"font redistribution licenses packaged")
	var model=Model.new()
	check(model.start_alpha(catalog.deck("morph"),catalog.deck("stillwatch"),777,2),"exported runtime starts real duel")
	check(model.mulligan([]),"exported mulligan")
	check(model.choose_origin(2),"exported origin")
	if model.state.stage=="second":check(model.finish_opening(),"exported second player opening")
	for _turn in 500:
		if model.state.winner!=null or not model.state.error.is_empty():break
		model.ai_turn("hero")
	check(model.state.winner!=null and model.state.error.is_empty(),"complete exported real AI duel without forced winner")
	# Headless native display servers start at64x64 despite the project's
	# desktop window override. Configure the declared QA profile before input;
	# geometry still has to provide a genuinely visible44px target.
	get_tree().root.size=Vector2i(1280,720)
	for _frame in 3:await get_tree().process_frame
	var menu=Shell.new()
	add_child(menu)
	for _frame in 3:await get_tree().process_frame
	var main_menu_verified: bool=menu.page=="lobby" and menu.actions.size()>=4
	var main_menu_input: Array=[]
	check(main_menu_verified,"actual exported Alpha Shell starts in the main lobby")
	for action in {"start":"decks","collection":"collection","builder":"builder","settings":"settings"}:
		var control: Variant=menu.actions.get(action)
		var usable: bool=control is BaseButton and not control.disabled and not control.pressed.get_connections().is_empty()
		if usable:
			usable=await tap_control(control)
			var destination: String={"start":"decks","collection":"collection","builder":"builder","settings":"settings"}[action]
			var deadline=Time.get_ticks_msec()+5000
			while usable and menu.page!=destination and Time.get_ticks_msec()<deadline:await get_tree().process_frame
			usable=usable and menu.page==destination
		main_menu_input.append({"action":action,"input":"original InputEventScreenTouch press/release","touch_rect":[last_touch_rect.position.x,last_touch_rect.position.y,last_touch_rect.size.x,last_touch_rect.size.y],"page":menu.page,"ok":usable})
		check(usable,"actual exported main menu action opens its page: "+action)
		main_menu_verified=main_menu_verified and usable
		menu.page="lobby";menu.render()
		for _frame in 2:await get_tree().process_frame
	menu.queue_free()
	for _frame in 2:await get_tree().process_frame
	print(JSON.stringify({"suite":"production_native_exported","assertions":assertions,"failures":failures,"winner":model.state.winner,"round":model.state.round,"catalog_fingerprint":catalog.fingerprint(),"main_menu_verified":main_menu_verified,"viewport":[get_tree().root.size.x,get_tree().root.size.y],"main_menu_input":main_menu_input}))
	get_tree().root.get_node("GameAudio").request_quit(1 if failures else 0)
