extends SceneTree
const Shell=preload("res://scripts/alpha/shell.gd")
const Session=preload("res://scripts/alpha/session.gd")
var app
var assertions:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for i in 6:await process_frame
func retained() -> Dictionary:
	return {"model":app.session.model.snapshot().duplicate(true),"commands":app.session.commands.duplicate(true),"selected":app.selected,"source_lane":app.source_lane,"action_mode":app.action_mode,"convergence_lanes":app.convergence_lanes.duplicate(),"mulligan":app.mulligan_indices.duplicate()}
func labels(node: Node) -> String:
	var result=node.text+"\n" if node is Label else ""
	for child in node.get_children():result+=labels(child)
	return result
func check_target(id: String) -> void:
	check(app.actions.has(id),"primary exists: "+id)
	if app.actions.has(id):
		var control: Control=app.actions[id]
		check(control.size.x>=44 and control.size.y>=44,"primary retains44px target: "+id)
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()),"primary is inside viewport: "+id)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(844,390)
	app=Shell.new();root.add_child(app);await settle()
	app.start_battle();await settle()
	check(app.session.model.state.stage=="mulligan","real production match begins in mulligan")
	app._opening_hand_click(2);await settle()
	check(app.mulligan_indices==[2] and app.selected==2,"real opening selection marks exchange")
	var before=retained()
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(393,852),Vector2i(915,412),Vector2i(844,220),Vector2i(844,247),Vector2i(844,248),Vector2i(844,390)]:
		root.size=dimensions;app.render();await settle()
		check(retained()==before,"complete model/RNG, commands and UI intent survive rebuild "+str(dimensions))
		if dimensions.y>dimensions.x:
			check(app.portrait and app.board_views.is_empty(),"portrait uses rotation guidance")
			check(labels(app.body).contains("FÜNF PFADE BRAUCHEN QUERFORMAT"),"portrait explains actual orientation")
			check_target("rotate_menu")
		elif dimensions.y<248:
			check(not app.portrait and app.board_views.is_empty(),"short landscape stays landscape")
			check(labels(app.body).contains("MEHR PLATZ") and not labels(app.body).contains("Drehe dein Gerät"),"short landscape asks for space instead of another turn")
			check_target("rotate_menu")
		else:check_target("mulligan_done")
	app.act("mulligan",[app.mulligan_indices]);await settle()
	app.act("origin",[2]);await settle()
	if app.session.model.state.stage=="second":app.act("openingDone",[]);await settle()
	check(app.session.model.state.stage=="battle","real commands reach battlefield")
	app.selected=0;app.source_lane=2;app.action_mode="move";app.convergence_lanes=[0,2,4];app.render();await settle()
	before=retained()
	for i in 4:
		root.size=Vector2i(390,844);app.render();await settle()
		check(retained()==before,"battle full state survives portrait pass "+str(i))
		root.size=Vector2i(844,390);app.render();await settle()
		check(retained()==before,"battle full state survives landscape pass "+str(i))
		check(app.board_views.size()==10,"all five paired paths restored")
		for view in app.board_views.values():check(view.size.x>=44 and view.size.y>=44,"path retains44px target")
	app.queue_free();await settle()
	print("ALPHA03 ORIENTATION: %d assertions, %d failures; full production model/RNG/commands, selection, mulligan, repeated UI rebuilds; not browser reload persistence" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
