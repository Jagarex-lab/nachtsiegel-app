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
	var center=control.get_global_rect().get_center()
	var event=InputEventScreenTouch.new();event.index=0;event.position=center;event.pressed=true;Input.parse_input_event(event);await settle()
	event=InputEventScreenTouch.new();event.index=0;event.position=center;event.pressed=false;Input.parse_input_event(event);await settle()
func snapshot(tag: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/alpha/"+tag+".png")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=Shell.new();root.add_child(app);await settle()
	for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=dimensions;await settle();app.page="lobby";app.render();await settle()
		check(app.actions.start.get_global_rect().size.y>=44,"start touch")
		await snapshot("lobby-%dx%d" % [dimensions.x,dimensions.y])
		await tap(app.actions.start)
		check(app.page=="battle" and app.session.model.state.stage=="mulligan","actual touch starts Alpha")
		await tap(app.actions.mulligan_done);check(app.session.model.state.stage=="origins","actual mulligan confirm")
		await tap(app.actions.origin_2)
		if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
		check(app.session.model.state.stage=="battle","opening completes")
		if app.session.model.state.hero.phase=="draw":await tap(app.actions.end)
		for key in ["end","actions","inspect","convergence","menu","log"]:
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
				var enemy_target: bool=c.effect in ["bolt","stasis","delay","redirect","displace"]
				await tap(app.board_views[("enemy" if enemy_target else "hero")+str(targets[0])])
				check(app.session.model.snapshot()!=before,"touch card play changes authoritative state");break
		await tap(app.actions.log);check(is_instance_valid(app.modal),"combat log opens")
		await snapshot("log-%dx%d" % [dimensions.x,dimensions.y]);await tap(app.actions.modal_close)
		app.session.model.state.winner="hero";app.result_dialog();await settle()
		await tap(app.actions.result_restart);check(app.session.model.state.winner==null,"restart actual button")
		app.close_modal();app.page="lobby";app.render();await settle()
		await tap(app.actions.builder);check(app.page=="builder","deckbuilder actual touch")
		if dimensions==Vector2i(844,390):
			await tap(app.actions["remove_oa-neutral-c01"]);check(app.deck.size()==29,"actual builder removal")
			await tap(app.actions.save_deck);check(not app.message.contains("gespeichert"),"UI rejects 29-card save")
			await tap(app.actions["add_oa-neutral-c02"]);check(app.deck.size()==30 and app.deck.has("oa-neutral-c02"),"actual builder adds replacement")
		await tap(app.actions.save_deck);check(app.message.contains("gespeichert"),"valid deck saved UI")
		if dimensions==Vector2i(844,390):
			var reloaded=preload("res://scripts/alpha/session.gd").new()
			check(reloaded.profile.decks["alpha:houses"].cards.has("oa-neutral-c02"),"edited deck persisted across new session")
			await tap(app.actions.reset_deck);await tap(app.actions.save_deck)
		await snapshot("builder-%dx%d" % [dimensions.x,dimensions.y])
		await tap(app.actions.builder_back)
	app.close_modal();app.queue_free();await settle();await create_timer(.5).timeout
	print("ALPHA UI: %d assertions, %d failures; five landscape sizes including browser-height viewport, real touch, opening, cards, log, restart, saved deck" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
