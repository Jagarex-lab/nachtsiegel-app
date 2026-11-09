extends SceneTree
const Store = preload("res://scripts/progress_store.gd")
const Model = preload("res://scripts/battle_model.gd")
const Campaign = preload("res://scripts/campaign_catalog.gd")
var failures := 0
var assertions := 0
var app
func check(value: bool, text: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",text)
func _initialize() -> void:call_deferred("run")
func settle() -> void:await process_frame;await process_frame
func tap(button: Control) -> void:
	var point=button.get_global_rect().get_center()
	var down=InputEventScreenTouch.new();down.position=point;down.pressed=true;Input.parse_input_event(down);await process_frame
	var up=InputEventScreenTouch.new();up.position=point;up.pressed=false;Input.parse_input_event(up);await settle()
func walk(node: Node) -> Array:
	var nodes: Array=[node]
	for child in node.get_children():nodes.append_array(walk(child))
	return nodes
func serialize(node: Control, rect: Rect2, color: Color, role: String, threshold: float = 4.5) -> Dictionary:
	var points: Array=[]
	for p in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		var at=node.get_global_transform()*p;points.append([at.x,at.y])
	return {"polygon":points,"color":color.to_html(false),"role":role,"threshold":threshold}
func capture(name: String) -> void:
	var speed=Engine.time_scale;Engine.time_scale=0
	await RenderingServer.frame_post_draw
	var png=root.get_texture().get_image()
	png.save_png("res://work/experience/"+name+".png")
	png.save_png("res://work/ux/hub-"+name+".png")
	var scope=app.battle_node.modal if app.current_page=="battle" else app.screen
	var samples: Array=[];var restore: Array=[];var fields: Array=[]
	for node in walk(scope):
		if not node is Control or not node.is_visible_in_tree():continue
		if node is Label and not node.text.is_empty():
			samples.append(serialize(node,Rect2(Vector2(4,3),node.size-Vector2(8,6)),node.get_theme_color("font_color"),"hub label "+node.text.substr(0,24)))
			restore.append([node,node.text]);node.text=""
		elif node is LineEdit:
			samples.append(serialize(node,Rect2(Vector2(12,8),node.size-Vector2(24,16)),node.get_theme_color("font_placeholder_color"),"search placeholder"))
			fields.append([node,node.get_theme_color("font_color"),node.get_theme_color("font_placeholder_color")]);node.add_theme_color_override("font_color",Color.TRANSPARENT);node.add_theme_color_override("font_placeholder_color",Color.TRANSPARENT)
		elif node.has_method("contrast_samples"):
			for sample in node.contrast_samples():samples.append(serialize(node,sample.rect,Color(sample.color),sample.role,sample.threshold))
	preload("res://scripts/ui_tokens.gd").ink_visible=false
	for node in walk(scope):
		if node is CanvasItem:node.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/ux/hub-"+name+"-background.png")
	for pair in restore:pair[0].text=pair[1]
	for pair in fields:pair[0].add_theme_color_override("font_color",pair[1]);pair[0].add_theme_color_override("font_placeholder_color",pair[2])
	preload("res://scripts/ui_tokens.gd").ink_visible=true
	for node in walk(scope):
		if node is CanvasItem:node.queue_redraw()
	var file=FileAccess.open("res://work/ux/hub-"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"tag":"hub-"+name,"samples":samples,"viewport":[root.size.x,root.size.y]},"  "))
	Engine.time_scale=speed
func autoplay(model) -> bool: return preload("res://tests/auto_player.gd").finish(model)
func run() -> void:
	for name in ["qa_experience.json","qa_experience.json.bak","qa_experience.json.tmp"]:
		if FileAccess.file_exists("user://"+name):DirAccess.remove_absolute("user://"+name)
	var save=Store.new("user://qa_experience.json")
	check(not save.data.tutorial_completed and save.data.unlocked_chapter==0,"New progress is locked until tutorial")
	check(save.begin_run("campaign",1).is_empty(),"Cannot start a locked chapter")
	save.choose_hero("ash_king");save.set_motion(true)
	var id=save.begin_run("tutorial");check(save.record_result(id,true),"Tutorial completion saved")
	check(not save.record_result(id,true),"Duplicate finish cannot inflate wins")
	var reread=Store.new("user://qa_experience.json")
	check(reread.data.tutorial_completed and reread.data.unlocked_chapter==1 and reread.data.wins==1 and reread.data.selected_hero=="ash_king" and reread.data.settings.reduced_motion,"Progress survives a new store instance")
	for chapter in 5:
		var number=chapter+1;var run=reread.begin_run("campaign",number)
		check(not run.is_empty(),"Chapter unlocked in order")
		check(reread.record_result(run,true),"Chapter victory saved")
		check(reread.data.unlocked_chapter==mini(5,number+1),"Only next encounter unlocks")
	var loss=reread.begin_run("campaign",5);reread.record_result(loss,false)
	check(reread.data.unlocked_chapter==5 and reread.data.chapter_wins.size()==5 and reread.data.defeats==1,"Defeat preserves completed chapters")
	var bad=FileAccess.open("user://qa_experience.json",FileAccess.WRITE);bad.store_string("{broken");bad.close()
	var recovered=Store.new("user://qa_experience.json");check(recovered.data.tutorial_completed,"Corrupted primary recovers backup")
	for chapter in Campaign.chapters():
		var m=Model.new();m.start(int(chapter.seed),str(chapter.ai_profile))
		var won=autoplay(m)
		check(won,"Chapter can be won with existing rules: "+str(chapter.number))
		check(m.round_number<70,"Encounter resolves within test horizon")
	# Isolated clean store for real front-end navigation.
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists("user://qa_front.json"+suffix):DirAccess.remove_absolute("user://qa_front.json"+suffix)
	app=load("res://scenes/front_end.tscn").instantiate();app.store=Store.new("user://qa_front.json");app.store.set_motion(true);root.add_child(app);await settle()
	for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(844,390),Vector2i(915,412)]:
		root.size=dimensions;await settle()
		for page in ["start","home","intro","heroes","campaign","collection","settings","av"]:
			app.show_page(page);await settle();await RenderingServer.frame_post_draw
			for key in app.actions:
				var b=app.actions[key];check(b.get_global_rect().size.x>=44 and b.get_global_rect().size.y>=44,"Front-end touch target "+page+" "+key)
				if str(key).begins_with("card_") and not Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(b.get_global_rect()):
					app.collection_scroll.scroll_vertical=int(b.get_parent().position.y);await settle()
				check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(b.get_global_rect()),"Front-end action reachable in viewport "+page+" "+key)
			for slider in app.audio_sliders.values():
				check(slider.get_global_rect().size.y>=44,"Audio slider touch area")
				check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(slider.get_global_rect()),"Audio slider inside viewport")
			for label in app.labels:
				var font=label.get_theme_font("font");var fs=label.get_theme_font_size("font_size")
				check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(label.get_global_rect()),"Front-end text inside viewport "+page+" "+label.text.substr(0,24))
				check(label.get_line_count()*font.get_height(fs)<=label.size.y+4,"Readable front-end text "+page+" "+label.text.substr(0,28))
			if dimensions.x==844:await capture(page+"-844x390")
	app.show_page("start");await settle();await tap(app.actions.begin);check(app.current_page=="intro","Start opens introduction")
	await tap(app.actions.intro_skip);check(app.current_page=="heroes","Introduction can be skipped")
	await tap(app.actions.hero_ash_king);check(app.store.data.selected_hero=="ash_king","Real touch selects hero")
	await tap(app.actions.start_tutorial);check(app.current_page=="battle" and app.battle_node.managed_session,"Starts guided tutorial duel")
	var game=app.battle_node
	# Real legal commands finish the tutorial; no fabricated health or victory flags.
	var won=autoplay(game.battle);check(won,"Full tutorial is winnable")
	game._finish(game.battle.result);await settle()
	check(app.store.data.tutorial_completed and app.store.data.unlocked_chapter==1,"Actual battle outcome unlocks campaign")
	await capture("tutorial-result")
	await tap(game.modal_actions[0]);check(app.current_page=="home","Result returns to main menu")
	await tap(app.actions.campaign);await tap(app.actions.chapter_1);check(app.current_page=="chapter","Unlocked chapter story opens")
	await tap(app.actions.start_duel);check(app.current_page=="battle" and app.battle_node.battle_profile=="easy","Campaign encounter starts")
	app.battle_node._show_menu();await settle();await tap(app.battle_node.modal_actions[3]);check(app.battle_node.modal_kind=="leave","Leave requires explicit confirmation")
	await tap(app.battle_node.modal_actions[0]);check(app.current_page=="battle" and app.battle_node.modal==null,"Cancel leaving keeps duel")
	app.battle_node._show_leave_confirmation();await settle();await tap(app.battle_node.modal_actions[1]);check(app.current_page=="home","Confirmed leave returns to menu")
	await tap(app.actions.settings);var before=app.store.data.settings.reduced_motion
	await tap(app.actions.motion);check(app.store.data.settings.reduced_motion!=before,"Settings toggle is functional")
	root.go_back_requested.emit();await settle();check(app.current_page=="home","Platform back returns from settings without quitting")
	await tap(app.actions.play);check(app.current_page=="battle" and app.run_mode=="quick","Play starts an ordinary duel after tutorial")
	game=app.battle_node;var quick_win=autoplay(game.battle);game._finish(game.battle.result);await settle()
	check(game.finished,"Ordinary duel reaches a real result")
	await tap(game.modal_actions[0]);check(app.current_page=="home","Ordinary duel result returns home")
	check(app.store.data.wins==(2 if quick_win else 1),"Ordinary duel outcome is persisted")
	await tap(app.actions.collection);check(app.visible_card_ids.size()==7,"Collection initially shows implemented cards only")
	await tap(app.actions.filter);check(app.visible_card_ids.size()==3,"Faction filter actually filters")
	await tap(app.actions.concepts);check(app.visible_card_ids.size()>3,"Concept toggle exposes explicitly separate entries")
	app.search_field.text="Ofenlehrling";app.search_field.text_changed.emit("Ofenlehrling");await settle();check(app.visible_card_ids==["furnace_apprentice"],"Search finds concept card")
	app.search_field.grab_focus();root.size=Vector2i(844,200);await settle()
	check(app.keyboard_layout and app.search_field.has_focus(),"Keyboard resize preserves search focus")
	check(app.search_field.get_global_rect().end.y<=200,"Search above keyboard")
	root.size=Vector2i(844,390);await settle()
	app.set_meta("inspect_id","furnace_apprentice");app.show_page("inspect");await settle();await capture("concept-inspection")
	app.set_meta("inspect_id","ash_watch");app.show_page("inspect");await settle();await capture("implemented-inspection")
	app.show_page("home");await tap(app.actions.campaign);await tap(app.actions.chapter_1)
	for chapter in range(1,6):
		check(app.current_page=="chapter" and app.current_chapter==chapter,"Campaign continuation reaches story %d" % chapter)
		await capture("chapter-"+str(chapter))
		await tap(app.actions.start_duel);game=app.battle_node
		if chapter==1:
			for turn in 60:
				if game.battle.finished:break
				game.battle.resolve_turn()
			check(game.battle.finished and game.battle.result.begins_with("NIEDERLAGE"),"Passing every turn produces a genuine defeat")
			game._finish(game.battle.result);await settle();await capture("campaign-defeat")
			await tap(game.modal_actions[1]);game=app.battle_node
			check(app.current_page=="battle" and not game.finished,"Defeat retry creates a fresh encounter")
		check(autoplay(game.battle),"Real campaign victory %d" % chapter)
		game._finish(game.battle.result);await settle()
		check(app.store.data.chapter_wins.has(chapter),"Campaign victory saved %d" % chapter)
		await tap(game.modal_actions[1])
	check(app.current_page=="campaign","Final chapter returns to chapter overview")
	var path=app.store.path;app.queue_free();await process_frame
	var restarted=load("res://scenes/front_end.tscn").instantiate();restarted.store=Store.new(path);root.add_child(restarted);await settle()
	check(restarted.store.data.tutorial_completed and restarted.store.data.selected_hero=="ash_king","Restart restores tutorial and hero")
	print("EXPERIENCE: %d assertions, %d failures; menu, tutorial, campaign, collection and persisted restart" % [assertions,failures])
	finish_test(1 if failures else 0)

func finish_test(code: int=0) -> void:
	root.get_node("GameAudio").request_quit(code)
