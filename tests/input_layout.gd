extends SceneTree
var arena
var assertions := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
func mouse(control: Control) -> void:
	var point = control.get_global_rect().get_center()
	var down = InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up = InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	await settle()
func touch(control: Control) -> void:
	var point = control.get_global_rect().get_center()
	var event = InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await create_timer(0.4).timeout
	for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(844,390),Vector2i(915,412),Vector2i(1024,768)]:
		print("SIZE ",dimensions)
		root.size = dimensions
		await settle()
		arena.finished = false
		arena.busy = false
		arena.hand = [0,1,2,3,4,5]
		arena.allies = [null,null,null,null,null]
		arena.energy = 10
		arena.summons = 0
		arena.selected = -1
		arena._refresh()
		await settle()
		check(not arena.landscape_panel.visible,"Landscape gate %s" % dimensions)
		var viewport = Rect2(Vector2.ZERO,Vector2(dimensions))
		for card in arena.card_buttons:
			check(viewport.encloses(card.get_global_rect()),"Hand card unclipped %s" % dimensions)
		for lane in arena.lane_buttons:
			check(viewport.encloses(lane.get_global_rect()),"Path unclipped %s" % dimensions)
			check(lane.get_global_rect().size.x >= 44 and lane.get_global_rect().size.y >= 44,"Path >=44px %s" % dimensions)
		for button in [arena.end_button,arena.detail_button]:
			check(button.get_global_rect().size.y >= 44,"Action >=44px %s" % dimensions)
		await mouse(arena.card_buttons[0])
		check(arena.selected == 0,"GUI pointer selects card %s" % dimensions)
		await mouse(arena.lane_buttons[0])
		check(arena.allies[0] != null and arena.energy == 8,"GUI pointer summons %s" % dimensions)
		await touch(arena.card_buttons[0])
		check(arena.selected == 0,"ScreenTouch selects card %s" % dimensions)
		await touch(arena.lane_buttons[1])
		check(arena.allies[1] != null and arena.energy == 6,"ScreenTouch summons %s" % dimensions)
		# Spells use the actual opponent card GUI as their touch target.
		arena.hand = [6]
		arena.foes[2] = arena.CARD_POOL[1].duplicate(true)
		arena._refresh()
		await settle()
		await touch(arena.card_buttons[0])
		await touch(arena.foe_faces[2])
		check(arena.foes[2] == null and arena.energy == 4,"ScreenTouch casts spell on opponent %s" % dimensions)
		var round_before = arena.round_number
		await touch(arena.end_button)
		await touch(arena.end_button)
		await create_timer(0.5).timeout
		check(arena.round_number == round_before+1 and not arena.busy,"Touch end turn locked against duplicate tap %s" % dimensions)
		arena.hand = [0,1,2,3,4,5]
		arena._refresh()
		await settle()
		# Modals consume input and expose a sufficiently large return target.
		arena.selected = 0
		arena._show_card()
		await settle()
		check(is_instance_valid(arena.modal),"Card inspection opens")
		await touch(arena.modal.get_child(arena.modal.get_child_count()-1))
		check(arena.modal == null,"ScreenTouch closes inspection")
		arena.hand = [0,1,2,3,4,5]
		arena.foes = [arena.CARD_POOL[3].duplicate(true),null,arena.CARD_POOL[4].duplicate(true),null,arena.CARD_POOL[2].duplicate(true)]
		arena._refresh()
		await settle()
		await capture("res://work/landscape-%dx%d.png" % [dimensions.x,dimensions.y])
	root.size = Vector2i(390,844)
	await settle()
	check(arena.landscape_panel.visible,"Portrait blocks battlefield")
	await capture("res://work/portrait-390x844.png")
	root.size = Vector2i(844,390)
	await settle()
	check(not arena.landscape_panel.visible,"Rotation restores play")
	print("INPUT/LAYOUT: %d assertions, %d failures; five landscape sizes; mouse + ScreenTouch" % [assertions,failures])
	quit(1 if failures else 0)
