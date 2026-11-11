extends SceneTree
## Actual selector controls and primary touch events; no model-state fixture.
const Shell=preload("res://scripts/alpha/shell.gd")
var app
var assertions := 0
var failures := 0
func check(value: bool, message: String) -> void:
	assertions+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func settle() -> void:
	for frame in 5:await process_frame
func tap(control: Control) -> void:
	for pressed in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=control.get_global_rect().get_center();event.pressed=pressed;Input.parse_input_event(event);await settle()
func scroll_in(node: Node) -> ScrollContainer:
	if node is ScrollContainer:return node
	for child in node.get_children():
		var found=scroll_in(child)
		if found!=null:return found
	return null
func portraits_in(node: Node) -> Array:
	var result=[]
	if node is TextureRect:result.append(node)
	for child in node.get_children():result.append_array(portraits_in(child))
	return result
func pan() -> void:
	var origin=Vector2(750,275)
	var press=InputEventScreenTouch.new();press.index=0;press.position=origin;press.pressed=true;Input.parse_input_event(press);await settle()
	for step in range(1,7):
		var move=InputEventScreenDrag.new();move.index=0;move.position=origin+Vector2(0,-20*step);move.relative=Vector2(0,-20);Input.parse_input_event(move)
		await create_timer(.04).timeout
	var release=InputEventScreenTouch.new();release.index=0;release.position=origin+Vector2(0,-120);release.pressed=false;Input.parse_input_event(release);await settle()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(915,412)
	app=Shell.new();root.add_child(app);await settle()
	check(app.size.is_equal_approx(Vector2(915,412)),"actual shell at915x412")
	await tap(app.actions.start)
	check(app.page=="decks","real primary touch opens selector")
	await tap(app.actions.choose_houses)
	check(app.faction=="houses","initial power selected through real UI")
	var sc=scroll_in(app.body)
	check(sc!=null,"actual selector scroller")
	if sc==null:
		app.queue_free();await settle();root.get_node("GameAudio").request_quit(1);return
	var grid=sc.get_child(0)
	check(grid is GridContainer and grid.get_child_count()==4,"four actual power panels")
	check(sc.get_v_scroll_bar().max_value>sc.get_v_scroll_bar().page,"viewport has genuine vertical overflow")
	for panel in grid.get_children():check(panel.mouse_filter==Control.MOUSE_FILTER_PASS,"decorative panel lets content touch reach scroller")
	var portraits=portraits_in(grid)
	check(portraits.size()==4,"four actual decorative power portraits")
	for portrait in portraits:check(portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decorative portrait cannot intercept a drag")
	var clipped_target=app.actions.choose_morph
	check(clipped_target.size.y>=44 and clipped_target.get_global_rect().intersection(app._qa_clip_rect(clipped_target)).size.y<44,"readonly QA bounds expose initially clipped second row")
	var power_before=app.faction
	await pan();var default_after=sc.scroll_vertical
	check(default_after>0,"unmodified product selector responds to actual primary touch-pan")
	check(app.faction==power_before,"scrolling does not select another power")
	# Negative UI fixture recreates the former event-intercepting containers.
	# It changes Control filters, never a game state or persisted profile.
	sc.scroll_vertical=0
	for panel in grid.get_children():panel.mouse_filter=Control.MOUSE_FILTER_STOP
	await settle();await pan();var legacy_after=sc.scroll_vertical
	check(legacy_after==0,"former STOP filter reproduces blocked content pan")
	for panel in grid.get_children():panel.mouse_filter=Control.MOUSE_FILTER_PASS
	sc.scroll_vertical=0;await settle();await pan();var restored_after=sc.scroll_vertical
	check(restored_after>0,"restored product filters recover touch scrolling")
	var target=app.actions.choose_morph
	check(target.size.x>=44 and target.size.y>=44 and sc.get_global_rect().encloses(target.get_global_rect()),"second-row control is fully visible with44px hit area")
	check(app._qa_clip_rect(target).encloses(target.get_global_rect()),"readonly QA clip bounds cover the revealed full control")
	await tap(target);check(app.faction=="morph","real touch selects the revealed second-row power")
	var report={"headless":DisplayServer.get_name()=="headless","size":[root.size.x,root.size.y],"default_pass_scroll":default_after,"legacy_stop_fixture_scroll":legacy_after,"restored_pass_scroll":restored_after,"assertions":assertions,"failures":failures,"no_model_state_fixture":true}
	DirAccess.make_dir_recursive_absolute("res://work/production-selector-touch")
	var output=FileAccess.open("res://work/production-selector-touch/results.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	app.queue_free();await settle();app=null
	print("PRODUCTION SELECTOR TOUCH: ",assertions," assertions, ",failures," failures; scroll ",default_after,"/",legacy_after,"/",restored_after)
	root.get_node("GameAudio").request_quit(1 if failures else 0)
