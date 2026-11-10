extends SceneTree
## Explicit menu-boundary fixtures, not four complete games. Every burst below
## is paid and executed through the real production UI and Session command path.
const Shell=preload("res://scripts/alpha/shell.gd")
const Style=preload("res://scripts/alpha/style.gd")
var assertions:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for frame in 5:await process_frame
func tap(control: Control) -> void:
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control);await settle()
		ancestor=ancestor.get_parent()
	var center=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=center;event.pressed=pressed
		Input.parse_input_event(event);await settle()
func run() -> void:
	root.size=Vector2i(1280,720)
	for power in ["houses","stillwatch","morph","ninth"]:
		var app=Shell.new();root.add_child(app);await settle()
		app.faction=power;app.start_battle();await settle()
		var model=app.session.model
		check(model.catalog.all_cards().size()==550,"actual production catalog for "+power)
		# Arrange only the boundary needed to expose this menu action.
		model.state.stage="battle";model.state.active="hero";model.state.round=11
		var player: Dictionary=model.state.hero
		player.phase="main";player.pendingDraw=0;player.drawDone=true;player.energy=8;player.resonance=15;player.burstUsed=false
		player.pendingTarget=null;player.pendingShift=null;player.lanes=[null,null,null,null,null]
		var unit: Dictionary=model.make_unit("hero",model.catalog.card("oa-"+power+"-c01"),2)
		unit.summoned=false;player.lanes[2]=unit
		app.page="battle";app.render();await settle()
		var before=JSON.stringify(model.snapshot(),"",true)
		await tap(app.actions.actions)
		check(not Style.burst_description(power).is_empty(),"original rules supply a real burst explanation for "+power)
		check(app.actions.has("burst_"+power),"actual production actions menu renders burst for "+power)
		check(JSON.stringify(model.snapshot(),"",true)==before,"opening menu does not mutate rules for "+power)
		if app.actions.has("burst_"+power):
			check(not app.actions["burst_"+power].disabled,"legal burst remains touchable for "+power)
			var count: int=app.session.commands.size()
			await tap(app.actions["burst_"+power])
			check(app.session.commands.size()==count+1 and app.session.commands[-1].name=="burst","actual touch records exactly one burst command for "+power)
			check(player.resonance==7 and player.burstUsed and model.state.error.is_empty(),"unchanged burst pays eight of fifteen resonance and marks use for "+power)
			await tap(app.actions.actions)
			check(app.actions["burst_"+power].disabled,"spent burst disabled for "+power)
		app.close_modal();app.queue_free();app=null;await settle()
	print("PRODUCTION BURST UI: %d assertions, %d failures; four actual menu commands with arranged resource boundaries" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
