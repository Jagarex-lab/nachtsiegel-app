extends SceneTree
## Real Canvas input, including a slow frame longer than the existing debounce.
const Shell=preload("res://scripts/alpha/shell.gd")
const Session=preload("res://scripts/alpha/session.gd")
class PrimaryShell extends Shell:
	func _checkpoint_duel() -> void:pass
var app
var assertions := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func settle() -> void:
	for frame in 8:await process_frame
func touch_at(point: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(control: Control) -> void:
	touch_at(control.get_global_rect().get_center());await settle()
func run() -> void:
	root.size=Vector2i(844,390)
	app=PrimaryShell.new();root.add_child(app);await settle()
	app.start_battle();await settle()
	await tap(app.actions.mulligan_done);await tap(app.actions.origin_2)
	if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
	check(app.session.model.state.stage=="battle" and app.session.model.state.hero.phase=="draw","real opening leaves a legal draw confirmation")
	await create_timer(.22).timeout;await settle()
	var initial_count=app.session.commands.size()
	var point=app.actions.end.get_global_rect().get_center()
	var batch_frame=Engine.get_process_frames()
	touch_at(point)
	check(app.session.commands.size()==initial_count+1 and app.session.model.state.hero.phase=="main","first actual primary tap confirms draw once")
	var after_first=Session.digest(app.session.model.snapshot())
	var event_hash=Session.event_digest(app.session.model.events)
	var message_after_first: String=app.message
	# Deliberately occupy the same input/process frame beyond the 180ms wall
	# gate. This is a deterministic slow-render reproduction, not a game wait.
	OS.delay_msec(220)
	check(Engine.get_process_frames()==batch_frame,"slow duplicate stays in the original input frame")
	touch_at(point)
	check(app.session.commands.size()==initial_count+1,"slow queued duplicate cannot finish draw and end turn")
	check(Session.digest(app.session.model.snapshot())==after_first and Session.event_digest(app.session.model.events)==event_hash,"duplicate leaves the full model, RNG and events unchanged")
	check(app.message==message_after_first,"ignored duplicate cannot replace successful feedback with an error")
	await settle();await create_timer(.22).timeout;await settle()
	check(not app.actions.end.disabled,"a later intentional primary tap is available")
	await tap(app.actions.end)
	check(app.session.commands.size()==initial_count+2,"later actual tap still ends a legal turn")
	check(Session.replay(app.session.audit()).ok,"guarded real input journal deterministically replays")
	var before_illegal=Session.digest(app.session.model.snapshot())
	var invalid=app.session.command("play",["hero",-1,0])
	check(not invalid.ok and Session.digest(app.session.model.snapshot())==before_illegal,"illegal action still leaves authoritative state unchanged")
	app.start_battle();await settle()
	check(app.last_primary_frame==-1 and app.last_primary_ms==-1000,"new duel resets presentation input guards")
	await tap(app.actions.mulligan_done)
	check(app.session.model.state.stage=="origins","new duel opening remains immediately touchable")
	await tap(app.actions.origin_2)
	if app.session.model.state.stage=="second":await tap(app.actions.opening_done)
	if app.session.model.state.hero.phase=="draw":await tap(app.actions.end)
	await create_timer(.22).timeout;await settle()
	# Explicit presentation fixture, not a played match or replay certificate:
	# the core's existing optional-choice gate is covered by production tests.
	app.session.model.state.hero.pendingShift={"origin":2}
	app.render();await settle()
	check(app.actions.has("skip") and not app.actions.end.disabled,"optional shift uses the same enabled primary surface")
	var shift_before=app.session.commands.size()
	touch_at(app.actions.end.get_global_rect().get_center())
	check(app.session.commands.size()==shift_before+1 and app.session.model.state.hero.pendingShift==null,"actual primary touch skips the optional choice once")
	var shift_state=Session.digest(app.session.model.snapshot())
	var shift_frame=Engine.get_process_frames()
	OS.delay_msec(220)
	app.act("endTurn",["hero"])
	check(Engine.get_process_frames()==shift_frame and app.session.commands.size()==shift_before+1,"same-frame primary context change cannot also end the turn")
	check(Session.digest(app.session.model.snapshot())==shift_state,"ignored stale optional-choice action preserves full state")
	app.queue_free();await settle()
	print("PREMIUM PRIMARY INPUT: %d assertions, %d failures" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
