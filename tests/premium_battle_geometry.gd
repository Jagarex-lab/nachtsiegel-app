extends SceneTree
## Arranged presentation fixtures. These are not counted as played matches.
## --capture records actual Godot frames only when a rendering device is used.
const Shell=preload("res://scripts/alpha/shell.gd")
class PresentationShell extends Shell:
	# Arranged layout states are not replayable games and must not be saved.
	func _checkpoint_duel() -> void:pass
const Session=preload("res://scripts/alpha/session.gd")
var app
var assertions:=0
var failures:=0
var samples: Array=[]
var capture:=false
const OUT="res://work/premium/arena-iteration"
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for frame in 6:await process_frame
func bounded(control: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(.1).encloses(control.get_global_rect()) and control.size.x>=43.9 and control.size.y>=43.9
func complete_state() -> String:
	return Session.digest({"snapshot":app.session.model.snapshot(),"events":app.session.model.events,"commands":app.session.commands,"rng_state":app.session.model.rng.state,"rng_calls":app.session.model.rng.calls,"selected":app.selected,"source_lane":app.source_lane,"action_mode":app.action_mode,"mulligan":app.mulligan_indices,"convergence":app.convergence_lanes})
func active_action(id: String) -> bool:
	return app.actions.has(id) and is_instance_valid(app.actions[id]) and app.actions[id].is_inside_tree() and not app.actions[id].is_queued_for_deletion()
func modal_has_text(value: String) -> bool:
	for label in app.modal.find_children("*","Label",true,false):
		if label.text==value:return true
	return false
func tap_action(id: String) -> void:
	check(active_action(id),"real native touch action exists: "+id)
	if not active_action(id):return
	var control: Control=app.actions[id]
	var parent=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control);await settle()
		parent=parent.get_parent()
	var visible=control.get_global_rect().intersection(root.get_visible_rect())
	parent=control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:visible=visible.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	check(visible.size.x>=43.9 and visible.size.y>=43.9,"actual ancestor-clipped44px touch surface: "+id)
	if visible.size.x<43.9 or visible.size.y<43.9:return
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=visible.get_center();event.pressed=pressed;Input.parse_input_event(event)
		await settle()
func verify_enemy_relic() -> void:
	# Explicitly arranged public relics, not a played match or forged outcome.
	# Same-ID relics distinguish enemy inspection from the existing own activation.
	var card: Dictionary=app.alpha_catalog.card("of-houses-094")
	check(card.kind=="relic" and not str(card.description).is_empty(),"real production relic has inspectable text")
	var previous_hero: Variant=app.session.model.state.hero.relic
	var previous_enemy: Variant=app.session.model.state.enemy.relic
	app.session.model.state.hero.relic={"id":card.id,"uid":9201}
	app.session.model.state.enemy.relic={"id":card.id,"uid":9202}
	app.render();await settle()
	var before=complete_state()
	await tap_action("relic_slot")
	check(active_action("inspect_relic_activate"),"own relic inspection retains its existing activation control")
	await tap_action("modal_close")
	await tap_action("actions")
	check(modal_has_text("Gegnerisches Relikt: "+str(card.name)),"More exposes the actual public enemy relic name")
	await tap_action("enemy_relic_details")
	check(app.inspector_card_id==card.id and is_instance_valid(app.inspector_face) and app.inspector_face.card.id==card.id,"enemy details bind the real public card")
	check(app.inspector_title.text==card.name and app.inspector_rules.text==card.description,"enemy inspector contains full actual name and ability")
	check(modal_has_text("Gegnerisches Relikt · "+str(card.name)),"enemy ownership is explicit in the detail heading")
	check(not active_action("inspect_relic_activate"),"enemy inspection never offers own activation even for the same card ID")
	await tap_action("modal_close")
	check(before==complete_state(),"enemy/own inspection preserves full state, events, RNG, commands and selection")
	app.session.model.state.enemy.relic=null;app.render();await settle()
	before=complete_state()
	await tap_action("actions")
	check(modal_has_text("Gegnerisches Relikt: keines") and not active_action("enemy_relic_details"),"empty enemy relic slot is clear and has no false details action")
	await tap_action("modal_close")
	check(before==complete_state(),"empty-relic information is read-only")
	app.session.model.state.hero.relic=previous_hero;app.session.model.state.enemy.relic=previous_enemy
	app.render();await settle()
func save_frame(label: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.save_png(OUT.path_join(label+".png"))==OK,"actual Godot screenshot "+label)
func arrange() -> void:
	var m=app.session.model
	m.state.stage="battle";m.state.active="hero";m.state.round=11;m.state.winner=null
	m.state.origins={"hero":2,"enemy":2}
	var cards: Array=app.alpha_catalog.all_cards()
	for side in ["hero","enemy"]:
		var player: Dictionary=m.state[side]
		player.phase="main";player.pendingTarget=null;player.pendingShift=null;player.pendingDraw=0;player.drawDone=true;player.energy=8;player.resonance=15;player.lanes=[null,null,null,null,null]
		for lane in 5:
			var power=["houses","stillwatch","morph","ninth","neutral"][lane]
			for card in cards:
				if card.kind=="creature" and card.faction==power:
					var unit: Dictionary=m.make_unit(side,card,lane);unit.summoned=false;unit.ward=2;unit["block"]=3
					if lane==3:unit.stun=1
					player.lanes[lane]=unit;break
	m.state.hero.hand=["oa-houses-c01","oa-stillwatch-c01","oa-morph-c01","oa-ninth-c01","oa-houses-e01","oa-houses-r01"]
	app.selected=-1;app.action_mode="";app.source_lane=-1;app.render();await settle()
func verify_cards(label: String) -> void:
	check(app.hand_views.size()==6 and app.board_views.size()==10,"all six cards and ten paths "+label)
	var measurement={"viewport":[root.size.x,root.size.y],"hand":[],"board":[]}
	for view in app.hand_views:
		var report=view.layout_report()
		check(bounded(view),"whole hand portrait is44px and bounded "+label)
		check(is_equal_approx(view.size.x/view.size.y,63.0/88.0),"hand is an actual63:88 card "+label)
		check(report.role=="hand" and report.outer.encloses(report.stats),"renderer uses portrait information zones "+label)
		var index=app.hand_views.find(view);var legal=false
		for lane in 5:
			if app.session.model.play_support("hero",index,lane).is_empty():legal=true;break
		check(view.availability_shown and view.playable==legal and not view.disabled,"actual availability cue follows legal targets while inspection remains touchable")
		if not legal:check(not view.unavailable_reason.is_empty(),"blocked card has a readable reason")
		if root.size.y>=390:check(report.title_fits,"full normal-size card name remains readable "+view.card.id)
		measurement.hand.append({"id":view.card.id,"size":[view.size.x,view.size.y],"exposed_art":report.art_fraction,"name_fits":report.title_fits})
	for key in app.board_views:
		var view=app.board_views[key];var report=view.layout_report()
		check(bounded(view),"all upright lane targets44px and bounded "+key+label)
		check(report.has_combat_values and report.status_values.shield==2 and report.status_values.block==3,"attack/life/shield/block remain distinct "+key)
		check(report.title.size.y==0 or report.title.end.y<=report.stats.position.y+.1,"name cannot cover current values "+key)
		measurement.board.append({"slot":key,"size":[view.size.x,view.size.y],"exposed_art":report.art_fraction})
	for id in ["menu","resources","relic_slot","actions","inspect","end"]:check(bounded(app.actions[id]),"primary real touch control is bounded "+id+label)
	check(not app.actions.has("log") and not app.actions.has("restart"),"secondary log and restart do not consume permanent board space")
	samples.append(measurement)
func run() -> void:
	capture=OS.get_cmdline_user_args().has("--capture")
	DirAccess.make_dir_recursive_absolute(OUT)
	app=PresentationShell.new();root.add_child(app);await settle();app.start_battle();await settle()
	for dimensions in [Vector2i(844,390),Vector2i(852,393),Vector2i(932,430),Vector2i(1024,768),Vector2i(1600,900),Vector2i(756,299),Vector2i(756,248)]:
		root.size=dimensions;await settle()
		await arrange();verify_cards(str(dimensions))
		var before=Session.digest(app.session.model.snapshot());var commands=app.session.commands.size()
		app._hand_click(0);await settle()
		check(app.selected==0 and bounded(app.hand_views[0]),"tap selects and lifts a complete bounded portrait")
		if dimensions.y>=299:check(app.hand_views[0].size.x>app.hand_views[1].size.x,"selected card actually enlarges, not just changes its border")
		else:check(app.hand_views[0].size.y>=100,"emergency browser-bar height preserves a100px readable portrait instead of decorative enlargement")
		await save_frame("battle-%dx%d" % [dimensions.x,dimensions.y])
		app.inspect(app.session.card(app.session.model.state.hero.hand[0]));await settle()
		check(is_instance_valid(app.inspector_face) and is_equal_approx(app.inspector_face.size.x/app.inspector_face.size.y,63.0/88.0),"every landscape inspector uses undistorted full card")
		check(bounded(app.actions.modal_close),"details always have a reachable safe return")
		if dimensions.y>=390:await save_frame("inspection-%dx%d" % [dimensions.x,dimensions.y])
		app.close_modal();await settle()
		app.show_actions();await settle()
		for id in ["log","restart"]:check(app.actions.has(id) and bounded(app.actions[id]),"secondary "+id+" is reachable through More")
		app.close_modal();await settle()
		check(before==Session.digest(app.session.model.snapshot()) and commands==app.session.commands.size(),"selection, inspector and secondary sheets never change rules or RNG")
		await verify_enemy_relic()
		if dimensions==Vector2i(844,390):
			var retained=complete_state()
			for variant in ["flat","spatial","three_d","spatial"]:
				check(app.select_presentation_variant(variant),"actual comparison view is supported: "+variant)
				await settle();await settle()
				check(complete_state()==retained,"complete state/events/RNG/calls/commands/UI intent survive mode change: "+variant)
				var used: Array=[]
				for view in app.board_views.values():
					check(bounded(view),"real comparison hit surface is upright44px: "+variant)
					for previous in used:check(not view.get_global_rect().intersects(previous),"projected path touch targets do not overlap: "+variant)
					used.append(view.get_global_rect())
				if variant=="three_d":
					check(is_instance_valid(app.battle_stage.camera) and app.battle_stage.metrics().mesh_count>=26,"3D mode has a real camera/table/paths/pedestals/card meshes")
					check(app.battle_stage.metrics().card_face_subviewports==10,"all ten3D card faces use the actual Godot renderer")
					check(app.arena_projection_active,"normal phone viewport can use exact projected3D hit rectangles without a safety fallback")
				app.inspect(app.session.card(app.session.model.state.hero.hand[0]));await settle()
				check(is_equal_approx(app.inspector_face.size.x/app.inspector_face.size.y,63.0/88.0),"inspection remains flat63:88 in "+variant)
				app.close_modal();await settle()
				check(complete_state()==retained,"inspection in alternate arena preserves complete rules and selection: "+variant)
		# Deliberately arranged pending-choice boundary: a previously selected
		# hand card must not produce a fourth overflowing tool button.
		app.session.model.state.hero.pendingShift={"origin":0};app.selected=0;app.render();await settle()
		var waiting=Session.digest(app.session.model.snapshot())
		check(app.actions.skip==app.actions.end and bounded(app.actions.skip),"pending shift uses one clear primary skip action")
		for id in ["inspect","actions","cancel_selection"]:check(bounded(app.actions[id]),"pending shift tool remains inside dock: "+id)
		app._hand_click(1);await settle()
		check(is_instance_valid(app.modal) and app.selected==0,"a hand tap inspects without replacing an outstanding target choice")
		app.close_modal();await settle()
		check(waiting==Session.digest(app.session.model.snapshot()) and commands==app.session.commands.size(),"pending-choice presentation never changes rules or RNG")
	var file=FileAccess.open(OUT.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"scope":"arranged presentation fixtures, not played matches or physical mobile devices","shell_sha256":FileAccess.get_sha256("res://scripts/alpha/shell.gd"),"samples":samples},"  "));file.close()
	app.queue_free();await settle()
	print("PREMIUM BATTLE GEOMETRY: %d assertions, %d failures;7 real Shell viewports,6 hand cards,10 units,selection,full inspector,More,unchanged model/RNG" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
