extends SceneTree
## Actual input and rule-valid sessions. No arranged hand, field or fake win.
const Shell=preload("res://scripts/alpha/shell.gd")
const Session=preload("res://scripts/alpha/session.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
class DiagnosticShell extends Shell:
	func _drag_press(at: Vector2,pointer: int) -> void:
		if OS.get_cmdline_user_args().has("--trace"):print("POINTER DOWN ",pointer," epoch=",hand_tap_epoch," armed=",hand_press_epoch," owned=",not hand_drag.is_empty())
		super._drag_press(at,pointer)
		if OS.get_cmdline_user_args().has("--trace"):print("POINTER DOWN AFTER armed=",hand_press_epoch," owned=",not hand_drag.is_empty())
	func _drag_release(at: Vector2,pointer: int,canceled: bool=false) -> void:
		if OS.get_cmdline_user_args().has("--trace"):print("POINTER UP ",pointer," canceled=",canceled," epoch=",hand_tap_epoch," armed=",hand_press_epoch," owned=",not hand_drag.is_empty())
		super._drag_release(at,pointer,canceled)
	func _bind_press(control: BaseButton,callback: Callable) -> void:
		super._bind_press(control,callback)
		if control is CardView:
			control.button_down.connect(func():
				if OS.get_cmdline_user_args().has("--trace"):print("BUTTON DOWN role=",control.get("display_role")," epoch=",hand_tap_epoch," armed=",hand_press_epoch)
			)
	func _hand_click(index: int) -> void:
		if OS.get_cmdline_user_args().has("--trace"):print("HAND TAP BEFORE ",index," selected=",selected," epoch=",hand_tap_epoch," modal=",is_instance_valid(modal))
		super._hand_click(index)
		if OS.get_cmdline_user_args().has("--trace"):print("HAND TAP AFTER selected=",selected," epoch=",hand_tap_epoch," modal=",is_instance_valid(modal))
var app
var assertions:=0
var failures:=0
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:
		failures+=1;printerr("FAIL: ",label)
		if OS.get_cmdline_user_args().has("--trace"):print("FAIL STATE ",JSON.stringify({"selected":app.selected,"epoch":app.hand_tap_epoch,"modal":is_instance_valid(app.modal),"drag":app.hand_drag,"message":app.message}))
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for frame in 6:await process_frame
func touch(at: Vector2,pressed: bool,canceled: bool=false,pointer: int=0) -> void:
	var event=InputEventScreenTouch.new();event.position=at;event.index=pointer;event.pressed=pressed;event.canceled=canceled;Input.parse_input_event(event);await settle()
func key(code: Key,pressed: bool) -> void:
	var event=InputEventKey.new();event.keycode=code;event.pressed=pressed;Input.parse_input_event(event);await settle()
func move(at: Vector2) -> void:
	var event=InputEventScreenDrag.new();event.position=at;event.index=0;Input.parse_input_event(event);await settle()
func unchanged() -> String:
	return Session.digest({"state":app.session.model.snapshot(),"events":app.session.model.events,"commands":app.session.commands,"rng":app.session.model.rng.state,"rng_calls":app.session.model.rng.calls})
func legal_case(kind: String) -> Dictionary:
	for seed_value in range(1,40):
		var candidate=Session.new()
		candidate.start_match("alpha",Catalog.new().deck("houses"),seed_value,1,Catalog.new().deck("stillwatch"))
		candidate.command("mulligan",[[]]);candidate.command("origin",[2])
		if candidate.model.state.stage=="second":candidate.command("openingDone",[])
		for turn in 4:
			var s: Dictionary=candidate.model.state;var player: Dictionary=s.hero
			if s.winner!=null:break
			if player.phase=="draw":
				while player.hand.size()+mini(int(player.pendingDraw),player.deck.size())>6:candidate.command("burn",["hero",player.hand.size()-1])
				candidate.command("finishDraw",["hero"])
			for index in player.hand.size():
				if candidate.card(player.hand[index]).kind==kind and not candidate.model.legal_targets("hero",index).is_empty():return {"session":candidate,"index":index}
			candidate.command("endTurn",["hero"])
	return {}
func run() -> void:
	root.size=Vector2i(844,390);app=DiagnosticShell.new();root.add_child(app);await settle()
	app.start_battle();await settle()
	var opening=unchanged();var opening_card=app.hand_views[0].get_global_rect().get_center()
	await touch(opening_card,true);await touch(opening_card,false,true)
	check(app.mulligan_indices.is_empty() and app.selected==-1 and opening==unchanged(),"canceled opening tap neither marks a card nor changes the real mulligan")
	for kind in ["creature","event","relic"]:
		var setup=legal_case(kind);check(not setup.is_empty(),"actual legal "+kind+" case exists")
		if setup.is_empty():continue
		app.close_modal();app.session=setup.session;app.page="battle";app.selected=-1;app.action_mode="";app.render();await settle()
		var index=int(setup.index);var before=unchanged()
		for cycle in 3:
			# Both the canceled release and invalid drop stay inside the taller
			# portrait. This exposed the synthetic mouse-release regression.
			var start=app.hand_views[index].get_global_rect().get_center()
			await touch(start,true);await move(start+Vector2(0,-30))
			check(bool(app.hand_drag.get("active",false)),"owned portrait drag begins "+kind)
			await touch(start+Vector2(0,-30),false,true)
			check(app.hand_drag.is_empty() and not is_instance_valid(app.modal),"canceled portrait drag never becomes an inspector tap "+kind)
			check(before==unchanged(),"canceled drag preserves full state/events/RNG/commands "+kind)
			start=app.hand_views[index].get_global_rect().get_center()
			await touch(start,true);await move(start+Vector2(0,-30));await touch(start,false)
			check(app.hand_drag.is_empty() and not is_instance_valid(app.modal) and before==unchanged(),"invalid in-hand drop cancels without synthetic tap "+kind)
			start=app.hand_views[index].get_global_rect().get_center()
			await touch(start,true);await touch(start,false)
			check(app.selected==index and not is_instance_valid(app.modal) and before==unchanged(),"next genuine tap works immediately without a cooldown "+kind)
			app.cancel_selection();await settle()
			start=app.hand_views[index].get_global_rect().get_center()
			await touch(start,true);await move(start+Vector2(0,-30))
			root.size=Vector2i(390,844);await touch(start+Vector2(0,-30),false)
			root.size=Vector2i(844,390);app.render();await settle()
			check(app.hand_drag.is_empty() and app.selected==-1 and not is_instance_valid(app.modal) and before==unchanged(),"rotation/release race leaves no latent hand tap "+kind)
			start=app.hand_views[index].get_global_rect().get_center()
			await touch(start,true);await touch(start,false,true)
			check(app.selected==-1 and not is_instance_valid(app.modal) and before==unchanged(),"ordinary canceled tap cannot become a card action "+kind)
		for code in [KEY_SPACE,KEY_ENTER]:
			app.hand_views[index].grab_focus();await key(code,true);await key(code,false)
			check(app.selected==index and not is_instance_valid(app.modal) and before==unchanged(),"genuine keyboard Space/Enter still selects without a cooldown "+kind)
			app.cancel_selection();await settle()
		var source=app.hand_views[index].get_global_rect().get_center()
		await touch(source,true);await move(source+Vector2(0,-30))
		var armed=app.hand_press_epoch
		var other=app.hand_views[(index+1)%app.hand_views.size()].get_global_rect().get_center()
		await touch(other,true,false,1);await touch(other,false,false,1)
		check(app.hand_press_epoch==armed and int(app.hand_drag.get("pointer",-1))==0,"second touch cannot rearm the owned gesture "+kind)
		await touch(source+Vector2(0,-30),false,true)
		check(app.selected==-1 and not is_instance_valid(app.modal) and before==unchanged(),"multiple fingers cannot turn a canceled drag into a tap "+kind)
		# One adversarial input packet: the ordinary canceled release's GUI
		# signal arrives before raw canceled=true, then a genuine tap follows
		# before any process_frame/deferred dispatch or presentation rebuild.
		source=app.hand_views[index].get_global_rect().get_center()
		await touch(source,true)
		for item in [{"pressed":false,"canceled":true},{"pressed":true,"canceled":false},{"pressed":false,"canceled":false}]:
			var packet=InputEventScreenTouch.new();packet.position=source;packet.index=0;packet.pressed=item.pressed;packet.canceled=item.canceled;Input.parse_input_event(packet)
		await settle()
		check(app.selected==index and not is_instance_valid(app.modal) and before==unchanged(),"same-frame cancel+newDown+newUp permits only the genuine tap "+kind)
		app.cancel_selection();await settle()
		# Finish through the real model; the guard cannot block genuine play.
		var lane=int(app.session.model.legal_targets("hero",index)[0]);var card=app.session.card(app.session.model.state.hero.hand[index]);var side=app.card_target_side(card)
		var start=app.hand_views[index].get_global_rect().get_center();var count=app.session.commands.size()
		await touch(start,true);await move(start+Vector2(0,-30))
		check(bool(app.hand_drag.get("active",false)),"valid drag still owns its pointer after cancel sequences "+kind)
		var target=app.actions.relic_slot if kind=="relic" else app.board_views[side+str(lane)]
		await move(target.get_global_rect().get_center());await touch(target.get_global_rect().get_center(),false)
		check(app.session.commands.size()==count+1 and app.session.commands[-1].name=="play","valid drop issues exactly one original play command "+kind)
		check(not is_instance_valid(app.modal) and Session.replay(app.session.audit()).ok,"drop opens no inspector and complete replay remains identical "+kind)
	var final_case=legal_case("creature")
	check(not final_case.is_empty(),"rule-valid action phase for deferred-command race exists")
	if not final_case.is_empty():
		app.session=final_case.session;app.selected=-1;app.action_mode="";app.last_primary_ms=-1000;app.render();await settle()
		var at=app.hand_views[int(final_case.index)].get_global_rect().get_center()
		await touch(at,true)
		var release=InputEventScreenTouch.new();release.position=at;release.index=0;release.pressed=false;Input.parse_input_event(release)
		var count=app.session.commands.size()
		app.act("endTurn",["hero"]) # Same input packet, before deferred hand tap.
		await settle()
		check(app.session.commands.size()==count+1 and app.selected==-1 and not is_instance_valid(app.modal),"a model command before dispatch invalidates the old hand callback")
		check(Session.replay(app.session.audit()).ok,"same-frame command race preserves actual deterministic replay")
	app.close_modal();app.queue_free();await settle()
	print("PREMIUM DRAG CANCEL: %d assertions, %d failures;45 cancel/invalid/tap/rotation cases,opening cancel,6 keyboard activations,3 multi-touch/3 same-packet races,3 real card plays and1 command-generation race with deterministic replay; no time-window suppression" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
