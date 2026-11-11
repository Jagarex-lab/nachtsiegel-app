extends SceneTree
## Actual touch input against the production Alpha shell; no model-state fixtures.
const Shell=preload("res://scripts/alpha/shell.gd")
class PresentationShell extends Shell:
	# Arranged layout states are not replayable games and must not be saved.
	func _checkpoint_duel() -> void:pass
const Session=preload("res://scripts/alpha/session.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const FullFace=preload("res://scripts/card_system/card_face.gd")
var app
var assertions := 0
var failures := 0
var saw_first := false
var saw_second := false
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for frame in 5:await process_frame
func tap(control: Control) -> void:
	var at=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed;Input.parse_input_event(event);await settle()
func bounded(control: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()) and control.size.x>=44 and control.size.y>=44
func full_face_in(node: Node) -> Control:
	if node.get_script()==FullFace:return node
	for child in node.get_children():
		var face=full_face_in(child)
		if face!=null:return face
	return null
func paths(label: String) -> void:
	check(app.board_views.size()==10,label+": five actual paired paths")
	for side in ["hero","enemy"]:
		for lane in 5:
			var view=app.board_views[side+str(lane)]
			check(view.lane==lane and view.unit.is_empty() and bounded(view),label+": real empty lane, touch bounds")
			if side=="hero":check(is_equal_approx(view.get_global_rect().position.x,app.board_views["enemy"+str(lane)].get_global_rect().position.x),label+": opposing paths aligned")
func shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://work/master550/opening")
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/master550/opening/"+name+".png")
func drag_press(index: int, mouse: bool=false) -> Vector2:
	var at=app.hand_views[index].get_global_rect().get_center()
	if mouse:
		var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(event)
	else:
		var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=true;Input.parse_input_event(event)
	await settle();return at
func drag_move(at: Vector2, mouse: bool=false) -> void:
	if mouse:
		var event=InputEventMouseMotion.new();event.position=at;event.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(event)
	else:
		var event=InputEventScreenDrag.new();event.position=at;event.index=0;Input.parse_input_event(event)
	await settle()
func drag_release(at: Vector2, mouse: bool=false, canceled: bool=false) -> void:
	if mouse:
		var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;Input.parse_input_event(event)
	else:
		var event=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=false;event.canceled=canceled;Input.parse_input_event(event)
	await settle()
func drag_case(kind: String) -> Dictionary:
	# Search rule-valid sessions through public commands, never edit model state.
	for seed_value in range(1,40):
		var candidate=Session.new()
		candidate.start_match("alpha",Catalog.new().deck("houses"),seed_value,1,Catalog.new().deck("stillwatch"))
		candidate.command("mulligan",[[]]);candidate.command("origin",[2])
		if candidate.model.state.stage=="second":candidate.command("openingDone",[])
		for turn in 4:
			var s: Dictionary=candidate.model.state;var p: Dictionary=s.hero
			if s.winner!=null:break
			if p.phase=="draw":
				while p.hand.size()+mini(int(p.pendingDraw),p.deck.size())>6:candidate.command("burn",["hero",p.hand.size()-1])
				candidate.command("finishDraw",["hero"])
			for index in p.hand.size():
				if candidate.card(p.hand[index]).kind==kind and not candidate.model.legal_targets("hero",index).is_empty():return {"session":candidate,"index":index}
			candidate.command("endTurn",["hero"])
	return {}
func drag_checks() -> void:
	root.size=Vector2i(844,390);app.close_modal()
	for kind in ["creature","event","relic"]:
		var setup=drag_case(kind);check(not setup.is_empty(),"rule-valid drag case exists: "+kind)
		if setup.is_empty():continue
		app.session=setup.session;app.mode="alpha";app.page="battle";app.selected=-1;app.action_mode="";app.render();await settle()
		var index=int(setup.index);var before=Session.digest(app.session.model.snapshot());var count=app.session.commands.size()
		var from=await drag_press(index);await drag_move(from+Vector2(5,0))
		check(not app.hand_drag.active,"subthreshold motion retains a normal tap")
		await drag_release(from+Vector2(5,0));check(app.selected==index and app.session.commands.size()==count,"tap alternative selects without playing")
		app.cancel_selection();await settle()
		from=await drag_press(index);await drag_move(Vector2(4,4))
		check(app.hand_drag.active and is_instance_valid(app.drag_ghost),"drag lifts card and displays presentation ghost")
		await drag_release(Vector2(4,4))
		check(app.hand_drag.is_empty() and not is_instance_valid(app.drag_ghost) and Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==count,"invalid drop returns card without any state mutation")
		from=await drag_press(index);await drag_move(from+Vector2(0,-45))
		root.size=Vector2i(390,844);await settle()
		check(app.hand_drag.is_empty() and Session.digest(app.session.model.snapshot())==before,"rotation cancels the active gesture and preserves state")
		await drag_release(Vector2(4,4));root.size=Vector2i(844,390);await settle()
		from=await drag_press(index);await drag_move(from+Vector2(0,-45))
		root.size=Vector2i(390,844) # Release before waiting for deferred UI reconstruction.
		await drag_release(from+Vector2(0,-45))
		check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==count,"rotation/release race cannot issue a play command")
		root.size=Vector2i(844,390);await settle()
		from=await drag_press(index);await drag_move(from+Vector2(0,-45));await drag_release(from+Vector2(0,-45),false,true)
		check(Session.digest(app.session.model.snapshot())==before and app.session.commands.size()==count,"canceled touch cannot play a card")
		var card=app.session.card(app.session.model.state.hero.hand[index]);var lane=app.session.model.legal_targets("hero",index)[0]
		var side=app.card_target_side(card)
		from=await drag_press(index,kind=="event");await drag_move(from+Vector2(0,-45),kind=="event")
		check(bool(app.hand_drag.get("active",false)),"valid drop has an active owned gesture: "+kind)
		var target=app.actions.relic_slot if kind=="relic" else app.board_views[side+str(lane)]
		check(bounded(target),"actual drop target has a usable touch area")
		if kind=="relic":check(app.hand_drag.targets.size()==1 and app.hand_drag.targets.has("relic_slot"),"relic drag targets its separate slot only: "+str(app.hand_drag.targets))
		await drag_move(target.get_global_rect().get_center(),kind=="event");await drag_release(target.get_global_rect().get_center(),kind=="event")
		check(app.session.commands.size()==count+1 and app.session.commands[-1].name=="play" and app.session.commands[-1].args==["hero",index,lane if kind!="relic" else 0],"valid touch/mouse drop performs exactly one original play command: "+kind)
		if kind=="relic":check(app.session.model.state.hero.relic.id==card.id,"relic installed outside the five paths")
		check(Session.replay(app.session.audit()).ok,"drag gameplay and setup replay identically: "+kind)
func safe_area_checks() -> void:
	# Explicit layout fixture, not a claimed gameplay position: ten actual units
	# and six actual hand cards reproduce an 844-wide phone minus its side insets.
	app.match_use_starter=true;app.faction="houses";app.start_battle();await settle()
	app.act("mulligan",[[]]);await settle();app.act("origin",[2]);await settle()
	if app.session.model.state.stage=="second":app.act("openingDone",[]);await settle()
	var m=app.session.model;m.state.active="hero";m.state.hero.phase="main";m.state.hero.pendingDraw=0;m.state.hero.energy=8
	for side in ["hero","enemy"]:
		for lane in 5:
			if m.state[side].lanes[lane]!=null:m.state[side].discard.append(m.state[side].lanes[lane].id)
			var at := -1
			for i in m.state[side].deck.size():
				if m.catalog.card(m.state[side].deck[i]).kind=="creature":at=i;break
			check(at>=0,"safe-area fixture uses a real creature")
			if at<0:continue
			var id=m.state[side].deck.pop_at(at);var unit=m.make_unit(side,m.catalog.card(id),lane);unit.summoned=false;m.state[side].lanes[lane]=unit
	while m.state.hero.hand.size()<6:m.state.hero.hand.append(m.state.hero.deck.pop_front())
	app.selected=-1;app.message="LAYOUT-FIXTURE · zehn Wesen / sechs Handkarten"
	var smallest=Vector2(INF,INF)
	for dimensions in [Vector2i(756,299),Vector2i(756,320)]:
		root.size=dimensions;app.render();await settle()
		for view in app.board_views.values():
			check(bounded(view),"safe-area paired-path touch bounds "+str(dimensions))
			var report=view.layout_report()
			check(report.title.size.y==0 or report.title.end.y<=report.stats.position.y,"safe-area board name cannot overlap its permanent current values")
		for view in app.hand_views:
			smallest.x=minf(smallest.x,view.size.x);smallest.y=minf(smallest.y,view.size.y)
			check(bounded(view) and view.layout_report().outer.encloses(view.layout_report().stats),"safe-area portrait values stay in their separate footer; energy has its own top-left socket")
		check(bounded(app.actions.relic_slot) and bounded(app.actions.end),"safe-area relic target and primary action remain visible")
		await shot("compact-fixture-%dx%d" % [dimensions.x,dimensions.y])
	check(smallest.x>44 and smallest.y>=44,"smallest real six-card tile measured")
	for card in Catalog.new().all_cards():
		var view=app.CardView.new();view.card=card;view.display_role="hand";view.size=smallest
		var report=view.layout_report()
		check(report.title_fits,"whole card name fits smallest safe-area portrait name plate: "+card.name)
		check(report.title.end.y<=report.stats.position.y+.1,"no name ink can cover the current values: "+card.id)
		check(report.outer.encloses(report.stats) and report.outer.encloses(report.title),"both readable information areas remain within the common outer frame")
		check(report.has_combat_values==(card.kind=="creature"),"only creatures render attack and life; impulse and relic use a type footer")
		check(is_equal_approx(smallest.x/smallest.y,63.0/88.0),"real canonical portrait aspect survives the minimum measured safe hand tile")
		view.free()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=PresentationShell.new();root.add_child(app);await settle()
	for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720)]:
		root.size=dimensions;app.close_modal();app.match_use_starter=true;app.faction="houses";app.session.profile.last_seed=23;app.start_battle();await settle()
		check(app.session.model.state.stage=="mulligan","real model starts in mulligan")
		paths("mulligan "+str(dimensions))
		check(app.hand_views.size()==5,"five actual starting cards")
		for index in 5:
			check(app.actions["mulligan_"+str(index)]==app.hand_views[index],"mulligan action is the actual hand card")
			check(app.hand_views[index].card.id==app.session.model.state.hero.hand[index] and bounded(app.hand_views[index]),"real hand data and touch bounds")
			check(app.hand_views[index].title_paragraph(app.hand_views[index].size.x-16).get_line_count()<=2,"whole opening card name fits")
		var digest=Session.digest(app.session.model.snapshot());var count=app.session.commands.size()
		await tap(app.actions.mulligan_0);await tap(app.actions.mulligan_1);await tap(app.actions.mulligan_1)
		check(app.mulligan_indices==[0] and app.selected==1,"mark, switch and unmark with real touch")
		check(app.hand_views[0].get_child_count()==1 and app.hand_views[0].get_global_rect().encloses(app.hand_views[0].get_child(0).get_global_rect()),"exchange ribbon stays inside its card")
		check(Session.digest(app.session.model.snapshot())==digest and app.session.commands.size()==count,"marking cards never changes rules or adds commands")
		await tap(app.actions.inspect)
		check(is_instance_valid(app.modal) and bounded(app.actions.modal_close) and app.actions.has("inspect_target"),"full existing inspector available during mulligan")
		check(Session.digest(app.session.model.snapshot())==digest and app.mulligan_indices==[0],"inspection preserves hand and exchange marks")
		if dimensions==Vector2i(844,390):await shot("mulligan-inspection-844x390")
		await tap(app.actions.modal_close)
		root.size=Vector2i(390,844);await settle()
		check(app.board_views.is_empty() and app.actions.has("rotate_menu"),"portrait opening uses rotation guard")
		check(app.mulligan_indices==[0] and app.selected==1 and Session.digest(app.session.model.snapshot())==digest,"portrait guard preserves exact hand, selection and model")
		root.size=dimensions;await settle();paths("restored mulligan")
		check(app.mulligan_indices==[0] and app.selected==1,"landscape restores opening marks")
		if dimensions==Vector2i(844,390):await shot("mulligan-marked-844x390")
		check(bounded(app.actions.mulligan_done) and bounded(app.actions.inspect),"opening primary and details touch bounds")
		await tap(app.actions.mulligan_done)
		check(app.session.model.state.stage=="origins" and app.session.commands.size()==count+1,"confirm issues exactly one real mulligan")
		check(app.session.model.state.hero.hand.size()==5 and app.session.commands[-1].args==[[0]],"only marked card exchanged by original command")
		paths("origin selection")
		for lane in 5:check(app.actions["origin_"+str(lane)]==app.board_views["hero"+str(lane)] and app.board_views["hero"+str(lane)].target,"origin target is an actual friendly path")
		count=app.session.commands.size();await tap(app.board_views.enemy2)
		check(app.session.commands.size()==count,"enemy path cannot select an origin")
		if dimensions==Vector2i(844,390):await shot("origin-844x390")
		await tap(app.actions.origin_2)
		check(app.session.model.state.origins.hero==2,"real battlefield touch chooses original origin rule")
		if app.session.model.state.stage=="second":await finish_second(dimensions)
		else:saw_first=true
		check(app.session.model.state.stage=="battle" and app.actions.has("end"),"opening continues to actual combat")
		check(Session.replay(app.session.audit()).ok,"all actual opening commands replay identically")
	# Cover both coin outcomes without inventing a model fixture.
	for seed_value in range(1,9):
		if saw_first and saw_second:break
		app.session.profile.last_seed=seed_value-1;app.start_battle();await settle()
		await tap(app.actions.mulligan_done);await tap(app.actions.origin_1)
		if app.session.model.state.stage=="second":await finish_second(root.size)
		else:saw_first=true
		check(Session.replay(app.session.audit()).ok,"seeded opening replays both start-player paths")
	check(saw_first and saw_second,"actual seeded first-player and second-player openings covered")
	app.session.profile.reduced_motion=true;app.start_battle();await settle()
	for view in app.hand_views:check(is_equal_approx(view.modulate.a,1.0),"reduced motion shows dealt cards immediately")
	await drag_checks()
	await safe_area_checks()
	root.size=Vector2i(390,844);app.open_cards(true);await settle()
	app.filter_text=Catalog.new().all_cards()[0].name;app.render();await settle()
	await tap(app.actions["card_"+Catalog.new().all_cards()[0].id])
	var face=full_face_in(app.modal)
	check(face!=null and is_equal_approx(face.size.x/face.size.y,63.0/88.0),"portrait inspector uses the canonical full-card aspect")
	check(face!=null and face.layout_report().title_fits and face.layout_report().rules_fit and bounded(app.actions.modal_close),"new full card retains readable text and visible dismissal")
	await shot("full-card-portrait-390x844")
	for dimensions in [Vector2i(1280,720),Vector2i(320,568),Vector2i(390,844)]:
		root.size=dimensions;await settle()
		check(face.get_global_rect().position.x>=0 and face.get_global_rect().end.x<=root.size.x and bounded(app.actions.modal_close),"open full-card inspector resizes without horizontal clipping: "+str(dimensions))
	await tap(app.actions.modal_close)
	app.queue_free();await settle()
	print("MASTER550 OPENING UI: %d assertions, %d failures; real touch, paired paths, four sizes, exchange, inspector, rotation, origins, second possibility, tap and drag, replay" % [assertions,failures])
	root.get_node("GameAudio").request_quit(0 if failures==0 else 1)
func finish_second(dimensions: Vector2i) -> void:
	saw_second=true
	var before=Session.digest(app.session.model.snapshot())
	for opening_size in [Vector2i(844,390),Vector2i(915,412),Vector2i(844,320),Vector2i(1280,720)]:
		root.size=opening_size;await settle();paths("second possibility "+str(opening_size))
		check(bounded(app.actions.opening_done) and bounded(app.actions.second_exchange) and bounded(app.actions.inspect),"all second-possibility controls have visible touch bounds")
		if opening_size==Vector2i(844,390):await shot("second-844x390")
	root.size=Vector2i(390,844);await settle()
	check(app.actions.has("rotate_menu") and Session.digest(app.session.model.snapshot())==before,"second possibility also survives portrait guard")
	root.size=dimensions;await settle()
	check(app.actions.second_origin_3==app.board_views.hero3,"second origin stays on real battlefield")
	await tap(app.actions.second_origin_3)
	check(app.session.model.state.second_path and app.session.model.state.origins.hero==3,"optional second origin uses original command")
	for lane in 5:check(app.actions["second_origin_"+str(lane)].disabled,"second origin cannot be changed twice")
	var count=app.session.commands.size();await tap(app.actions.second_card_0)
	check(app.selected==0 and app.session.commands.size()==count,"second card choice requires explicit exchange confirmation")
	check(bounded(app.actions.second_exchange) and not app.actions.second_exchange.disabled,"second card exchange is a bounded enabled action")
	if dimensions==Vector2i(844,390):await shot("second-844x390")
	await tap(app.actions.second_exchange)
	check(app.session.model.state.second_card and app.session.model.state.hero.hand.size()==5 and app.actions.second_exchange.disabled,"single second-card exchange is applied and locked")
	await tap(app.actions.opening_done)
