extends SceneTree
## Actual input plus a labelled adversarial GUI signal-order fixture. No game
## state, card data, profile or callback is injected by the browser harness.
const Shell=preload("res://scripts/alpha/shell.gd")
const Touch=preload("res://tests/premium_input_driver.gd")
class UnguardedScrollShell extends Shell:
	# Negative control: the former unconditional scroll-button activation.
	func _dispatch_scroll_press(control_ref: WeakRef, callback: Callable, _press: Dictionary) -> void:
		var control=control_ref.get_ref()
		if control!=null and control.is_inside_tree():callback.call()
var app
var assertions := 0
var failures := 0
var pointer_positions: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func settle() -> void:
	for frame in 6:await process_frame
func touch(at: Vector2, pressed: bool, canceled: bool=false, pointer: int=0) -> void:
	pointer_positions[pointer]=at
	var event=InputEventScreenTouch.new();event.index=pointer;event.position=at;event.pressed=pressed;event.canceled=canceled;Input.parse_input_event(event)
	await settle()
func move(at: Vector2) -> void:
	var event=InputEventScreenDrag.new();event.index=0;event.position=at;event.relative=at-pointer_positions.get(0,at);pointer_positions[0]=at;Input.parse_input_event(event)
	await settle()
func mouse(at: Vector2, pressed: bool) -> void:
	pointer_positions[-2]=at
	var event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.pressed=pressed;Input.parse_input_event(event)
	await settle()
func mouse_move(at: Vector2) -> void:
	var event=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=at-pointer_positions.get(-2,at);event.button_mask=MOUSE_BUTTON_MASK_LEFT;pointer_positions[-2]=at;Input.parse_input_event(event)
	await settle()
func key(code: Key, pressed: bool) -> void:
	var event=InputEventKey.new();event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
	await settle()
func fresh(collection: bool=true) -> Control:
	app.close_modal();app.open_cards(collection)
	if not collection:app.deck=[]
	await settle()
	var id=app.library_visible_ids[0]
	var card: Control=app.actions["card_"+id]
	app.library_scroll.scroll_vertical=0;await settle()
	return card
func unchanged(deck: Array, profile: String, label: String) -> void:
	check(not is_instance_valid(app.modal),label+" opens no inspector")
	check(app.deck==deck and JSON.stringify(app.session.profile,"",true)==profile,label+" never adds a card or changes profile")
func run() -> void:
	root.size=Vector2i(390,844)
	app=UnguardedScrollShell.new() if OS.get_cmdline_user_args().has("--unguarded") else Shell.new()
	root.add_child(app);await settle()
	for collection in [true,false]:
		var mode="collection" if collection else "builder"
		var card=await fresh(collection)
		var deck: Array=app.deck.duplicate();var profile=JSON.stringify(app.session.profile,"",true)
		var point=card.get_global_rect().get_center()
		await touch(point,true);await touch(point,false,true)
		unchanged(deck,profile,mode+" canceled ordinary tap")
		card=await fresh(collection);deck=app.deck.duplicate();profile=JSON.stringify(app.session.profile,"",true)
		point=card.get_global_rect().get_center()+Vector2(0,70)
		var before_scroll=app.library_scroll.scroll_vertical
		await touch(point,true)
		for step in range(1,7):await move(point+Vector2(0,-160.0*step/6))
		await touch(point+Vector2(0,-160),false)
		check(app.library_scroll.scroll_vertical>before_scroll,mode+" actual160px touch pan scrolls the real library")
		unchanged(deck,profile,mode+" actual tall-card pan")
		card=await fresh(collection);deck=app.deck.duplicate();profile=JSON.stringify(app.session.profile,"",true)
		point=card.get_global_rect().get_center()+Vector2(0,70);before_scroll=app.library_scroll.scroll_vertical
		await mouse(point,true)
		for step in range(1,7):await mouse_move(point+Vector2(0,-160.0*step/6))
		await mouse(point+Vector2(0,-160),false)
		check(app.library_scroll.scroll_vertical>before_scroll,mode+" actual160px mouse pan scrolls the real library")
		unchanged(deck,profile,mode+" actual mouse pan")
		card=await fresh(collection);deck=app.deck.duplicate();profile=JSON.stringify(app.session.profile,"",true)
		# Recreate held-pointer GUI rearming after content enters the pointer.
		# This is an explicit event-order fixture, not a claimed native flick.
		point=card.get_global_rect().get_center()
		await touch(point,true);await move(point+Vector2(0,-30))
		card.button_down.emit();card.pressed.emit()
		await touch(point+Vector2(0,-30),false)
		unchanged(deck,profile,mode+" held-pointer GUI event-order fixture")
		card=await fresh(collection);deck=app.deck.duplicate();profile=JSON.stringify(app.session.profile,"",true)
		point=card.get_global_rect().get_center()
		await touch(point,true)
		# A scrollbar/kinetic offset change is independently sufficient even
		# without any original move event in this controlled UI fixture.
		app.library_scroll.scroll_vertical+=20
		card.pressed.emit()
		await touch(point,false)
		unchanged(deck,profile,mode+" scroll-offset event-order fixture")
		card=await fresh(collection);point=card.get_global_rect().get_center();var id=card.card.id
		await touch(point,true);await move(point+Vector2(3,0));await touch(point+Vector2(3,0),false)
		check(app.inspector_card_id==id if collection else app.deck.count(id)==1,mode+" genuine slightly-wobbled tap works immediately")
		card=await fresh(collection);point=card.get_global_rect().get_center();id=card.card.id
		await mouse(point,true);await mouse(point,false)
		check(app.inspector_card_id==id if collection else app.deck.count(id)==1,mode+" genuine desktop mouse click remains available")
		for code in [KEY_SPACE,KEY_ENTER]:
			card=await fresh(collection);id=card.card.id;card.grab_focus();await settle()
			await key(code,true);await key(code,false)
			check(app.inspector_card_id==id if collection else app.deck.count(id)==1,mode+" genuine keyboard Space/Enter remains available")
		card=await fresh(collection);deck=app.deck.duplicate();profile=JSON.stringify(app.session.profile,"",true);point=card.get_global_rect().get_center()
		await touch(point,true);await move(point+Vector2(0,-30));await touch(point,true,false,1);await touch(point,false,false,1);await touch(point+Vector2(0,-30),false)
		unchanged(deck,profile,mode+" second touch cannot rearm a scroll")
	# Verify the same guard on ordinary settings buttons inside a scroller.
	app.close_modal();app.page="settings";app.render();await settle()
	var target_power="morph" if app.faction!="morph" else "houses"
	var power=app.actions["faction_"+target_power]
	var parent=power.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(power);await settle()
		parent=parent.get_parent()
	var old_power: String=app.faction;var at=power.get_global_rect().get_center()
	await touch(at,true);await move(at+Vector2(0,-30));power.button_down.emit();power.pressed.emit();await touch(at+Vector2(0,-30),false)
	check(app.faction==old_power,"settings swipe cannot activate a power button")
	await Touch.tap(self,app.actions["faction_"+target_power])
	check(app.faction==target_power,"fresh settings touch still changes the selected power")
	# Explicit unchanged-view callback fixture, so render/modal invalidation
	# cannot accidentally hide duplicate activation of a consumed intent.
	var settings_scroll: ScrollContainer
	parent=app.actions.motion.get_parent()
	while parent!=null:
		if parent is ScrollContainer:settings_scroll=parent;break
		parent=parent.get_parent()
	var observed={"calls":0}
	var probe=app.button("scroll_input_probe","Eingabe-Fixture",func():observed.calls+=1,settings_scroll.get_child(0))
	await settle();await Touch.tap(self,probe)
	check(observed.calls==1,"unchanged-view pointer callback activates once")
	probe.pressed.emit();await settle()
	check(observed.calls==1,"duplicate GUI release cannot reuse a consumed pointer")
	await Touch.tap(self,probe)
	check(observed.calls==2,"fresh pointer tap immediately rearms unchanged-view callback")
	probe.grab_focus();await key(KEY_SPACE,true);await key(KEY_SPACE,false)
	check(observed.calls==3,"fresh focused keyboard intent activates unchanged-view callback")
	probe.pressed.emit();await settle()
	check(observed.calls==3,"duplicate GUI release cannot reuse a consumed keyboard intent")
	await key(KEY_ENTER,true)
	await touch(Vector2(1,1),true);await move(Vector2(1,31));probe.grab_focus()
	check(probe.has_focus(),"stale keyboard fixture keeps focus to exercise intent validation")
	probe.pressed.emit();await settle();await touch(Vector2(1,31),false);await key(KEY_ENTER,false)
	check(observed.calls==3,"a new pointer gesture invalidates an unconsumed keyboard stamp")
	await key(KEY_SPACE,true);await key(KEY_SPACE,false)
	check(observed.calls==4,"next genuine keyboard intent works without a cooldown")
	app.close_modal();app.queue_free();await settle()
	print("PREMIUM SCROLL INPUT: %d assertions, %d failures; actual touch/cancel/pan/keyboard plus labelled GUI rearm/offset fixtures; no debounce or gameplay changes" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
