extends SceneTree
const Shell=preload("res://scripts/alpha/shell.gd")
var app
var assertions := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	await process_frame;await process_frame;await process_frame
func tap(control: Control) -> void:
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control);await settle()
		ancestor=ancestor.get_parent()
	var center=control.get_global_rect().get_center()
	var event=InputEventScreenTouch.new();event.index=0;event.position=center;event.pressed=true;Input.parse_input_event(event);await settle()
	event=InputEventScreenTouch.new();event.index=0;event.position=center;event.pressed=false;Input.parse_input_event(event);await settle()
func locate_card(id: String) -> void:
	app.filter_text=app.alpha_catalog.card(id).name;app.render();await settle()
	check(app.actions.has("card_"+id),"exactcard remains discoverable through normal namesearch")
func snapshot(tag: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/alpha/"+tag+".png")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(str(ProjectSettings.get_setting_with_override("application/run/main_scene")).ends_with("alpha_shell.tscn"),"ORAFOLD is the regular main scene")
	app=Shell.new();root.add_child(app);await settle()
	for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=dimensions;await settle();app.page="lobby";app.render();await settle()
		for id in ["start","builder","collection","settings"]:
			check(app.actions.has(id),"functional main menu "+id)
			var rect=app.actions[id].get_global_rect()
			check(rect.size.x>=44 and rect.size.y>=44,"main menu touch size "+id)
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(rect),"main menu within viewport "+id)
		for id in ["archive","mode_legacy","mode_alpha"]:check(not app.actions.has(id),"no public compatibility navigation "+id)
		await tap(app.actions.collection);check(app.page=="collection" and not app.actions.has("save_deck") and not app.actions.has("add_oa-neutral-c01"),"read-only functional collection")
		await locate_card("oa-neutral-c01");await tap(app.actions["card_oa-neutral-c01"]);check(is_instance_valid(app.modal),"collection actual card detail");await tap(app.actions.modal_close)
		await tap(app.actions.builder_back)
		await tap(app.actions.settings)
		var powers=["houses","stillwatch","morph","ninth","houses"]
		var power=powers[[Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720),Vector2i(1600,900)].find(dimensions)]
		await tap(app.actions["faction_"+power]);check(preload("res://scripts/alpha/session.gd").new().profile.faction==power,"deck selection persisted")
		await tap(app.actions.motion);var reduced=app.session.profile.reduced_motion
		check(preload("res://scripts/alpha/session.gd").new().profile.reduced_motion==reduced,"motion setting persisted")
		await tap(app.actions.settings_back)
		check(app.actions.start.get_global_rect().size.y>=44,"start touch")
		await snapshot("lobby-%dx%d" % [dimensions.x,dimensions.y])
		await tap(app.actions.start)
		check(app.page=="decks","visible deck selection before battle")
		for power_id in ["houses","stillwatch","morph","ninth"]:check(app.actions.has("choose_"+power_id) and app.actions.has("preview_"+power_id),"all four actual starter sources")
		await tap(app.actions.deck_play)
		check(app.page=="battle" and app.session.model.state.stage=="mulligan","actual touch starts Alpha")
		await tap(app.actions.mulligan_done);check(app.session.model.state.stage=="origins","actual mulligan confirm")
		await tap(app.actions.origin_2)
		if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
		check(app.session.model.state.stage=="battle","opening completes")
		if app.session.model.state.hero.phase=="draw":await tap(app.actions.end)
		for key in ["end","actions","inspect","menu"]:
			var b=app.actions[key];var r=b.get_global_rect()
			check(r.size.y>=44 and r.size.x>=44,"touch target "+key+str(dimensions))
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(r),"action in viewport "+key+str(dimensions))
		for key in app.board_views:
			var r=app.board_views[key].get_global_rect();check(r.size.y>=44 and r.size.x>=44,"lane touch size")
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(r),"board visible "+key)
		for b in app.hand_views:check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(b.get_global_rect()),"all hand values inside viewport")
		await snapshot("battle-%dx%d" % [dimensions.x,dimensions.y])
		var p=app.session.model.state.hero
		var before=app.session.model.snapshot()
		for index in p.hand.size():
			var targets=app.session.model.legal_targets("hero",index)
			if not targets.is_empty():
				var c=app.session.card(p.hand[index]);await tap(app.hand_views[index])
				if c.kind=="relic":await tap(app.actions.relic_slot)
				else:await tap(app.board_views[app.card_target_side(c)+str(targets[0])])
				check(app.session.model.snapshot()!=before,"touch card play changes authoritative state");break
		await tap(app.actions.actions);check(app.actions.has("log") and app.actions.has("restart"),"secondary log and restart remain reachable through More")
		await tap(app.actions.log);check(is_instance_valid(app.modal),"combat log opens")
		await snapshot("log-%dx%d" % [dimensions.x,dimensions.y]);await tap(app.actions.modal_close)
		app.session.model.state.winner="hero";app.result_dialog();await settle()
		await tap(app.actions.result_restart);check(app.session.model.state.winner==null,"restart actual button")
		app.close_modal();app.page="lobby";app.render();await settle()
		await tap(app.actions.builder);check(app.page=="builder","deckbuilder actual touch")
		var expected_saved: Array=app.deck.duplicate()
		if dimensions==Vector2i(844,390):
			var removed: String=expected_saved[0]
			await tap(app.actions.deck_tab)
			await tap(app.actions["remove_"+removed]);expected_saved.erase(removed)
			check(app.deck==expected_saved and app.deck.size()==29,"actual builder removes the first copy and preserves exact remaining order")
			check(app.actions.save_deck.disabled,"UI prevents invalid 29-card save")
			await tap(app.actions.library_tab)
			var replacement: String=""
			for card in app.alpha_catalog.all_cards():
				if card.kind=="creature" and card.faction=="neutral" and card.rarity=="common" and card.id!=removed and expected_saved.count(card.id)<3:
					replacement=card.id;break
			check(not replacement.is_empty(),"actual active pool supplies a legal distinct replacement")
			await locate_card(replacement);await tap(app.actions["add_"+replacement]);expected_saved.append(replacement)
			check(app.deck==expected_saved and app.deck.size()==30,"actual builder appends the selected replacement in exact order")
		await tap(app.actions.save_deck);check(app.message.contains("gespeichert"),"valid deck saved UI")
		if dimensions==Vector2i(844,390):
			var reloaded=preload("res://scripts/alpha/session.gd").new()
			check(reloaded.profile.decks["alpha:houses"].cards==expected_saved,"exact edited deck persisted across new session")
			await tap(app.actions.reset_deck);await tap(app.actions.save_deck)
		await snapshot("builder-%dx%d" % [dimensions.x,dimensions.y])
		await tap(app.actions.builder_back)
	app.close_modal();app.queue_free();await settle();await create_timer(.5).timeout
	print("ALPHA UI: %d assertions, %d failures; five landscape sizes including browser-height viewport, real touch, opening, cards, log, restart, saved deck" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
