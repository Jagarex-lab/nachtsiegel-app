extends SceneTree
const T = preload("res://scripts/ui_tokens.gd")
var arena
var assertions := 0
var failures := 0
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: ",message)
func settle() -> void:
	await process_frame
	await process_frame
func walk(node: Node) -> Array:
	var all: Array = [node]
	for child in node.get_children(): all.append_array(walk(child))
	return all
func capture(tag: String) -> void:
	var previous_speed = Engine.time_scale
	Engine.time_scale = 0
	await settle()
	await RenderingServer.frame_post_draw
	var path = "res://work/ux/"+tag
	root.get_texture().get_image().save_png(path+".png")
	var nodes = walk(arena.modal if arena.modal != null else arena.root_ui)
	var samples: Array = []
	# Informational panels must not be hidden by actions; backgrounds/portrait art are intentional layers.
	var panels: Array = []
	var buttons: Array = []
	if arena.modal != null:
		panels = arena.modal.get_children().filter(func(node): return node is Label)
		buttons = arena.modal_actions
	else:
		panels = [arena.round_label,arena.energy_label,arena.energy_gems,arena.phase_label,arena.info_label,arena.status_label]
		buttons = [arena.help_button,arena.detail_button,arena.end_button,arena.restart_button]
	for label in panels:
		if not label.visible or label.text.is_empty(): continue
		for button in buttons:
			if not button.visible: continue
			check(not label.get_global_rect().intersects(button.get_global_rect()),"Panel/action overlap "+tag+" "+label.text.substr(0,15))
	var labels: Array = []
	for node in nodes:
		if not node is Control or not node.is_visible_in_tree(): continue
		var transform = node.get_global_transform()
		if node is Label and not node.text.is_empty():
			labels.append([node,node.text])
			var rect = Rect2(Vector2(8,6),node.size-Vector2(16,12))
			var color: Color = node.get_theme_color("font_color")
			samples.append(serialize(node,rect,color.to_html(false),"label "+node.text.substr(0,24),4.5))
			var fs = node.get_theme_font_size("font_size")
			var actual = fs*transform.get_scale().y
			check(actual >= 11.8,"Readable label "+tag+" "+node.text.substr(0,12))
			var font = node.get_theme_font("font")
			if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
				for line in node.text.split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x <= node.size.x-8,"Unclipped line "+tag+" "+line.substr(0,25))
			check(node.get_line_count()*font.get_height(fs)+3 <= node.size.y+2,"Unclipped lines "+tag+" "+node.text.substr(0,20))
		if node.has_method("contrast_samples"):
			for sample in node.contrast_samples(): samples.append(serialize(node,sample.rect,sample.color,sample.role,sample.threshold))
	var restore: Array = []
	for pair in labels:
		restore.append(pair)
		pair[0].text = ""
	T.ink_visible = false
	for node in nodes:
		if node is CanvasItem: node.queue_redraw()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path+"-background.png")
	T.ink_visible = true
	for pair in restore: pair[0].text = pair[1]
	for node in nodes:
		if node is CanvasItem: node.queue_redraw()
	var file = FileAccess.open(path+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"tag":tag,"samples":samples,"viewport":[root.size.x,root.size.y]},"  "))
	reports.append(tag)
	Engine.time_scale = previous_speed
func serialize(node: Control, rect: Rect2, color: String, role: String, threshold: float) -> Dictionary:
	var points: Array = []
	for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		var p = node.get_global_transform()*corner
		points.append([p.x,p.y])
	return {"polygon":points,"color":color,"role":role,"threshold":threshold}
func reset() -> void:
	for feedback in get_nodes_in_group("damage_feedback"):
		feedback.visible = false
		feedback.queue_free()
	arena._close_modal()
	arena.finished = false
	arena.busy = false
	arena.phase = "play"
	arena.selected = -1
	arena.summons = 0
	arena.energy = 10
	arena.hand = [0,1,2,3,4,5]
	arena.allies = [null,null,null,null,null]
	arena.foes = [null,null,null,null,null]
	arena.onboarding_step = 3
	arena._refresh()
func run() -> void:
	var source = load("res://scripts/arena.gd")
	if source == null or not source.can_instantiate():
		printerr("FAIL: Arena cannot instantiate")
		quit(1)
		return
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await settle()
	arena._set_reduced_motion(true,false)
	for role in T.palette():
		if role in ["surface","raised","ink"]: continue
		check(T.contrast(T.palette()[role],T.SURFACE) >= 4.5,"Palette AA "+role)
	for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(844,390),Vector2i(915,412)]:
		root.size = dimensions
		await settle()
		reset()
		var suffix = "-%dx%d" % [dimensions.x,dimensions.y]
		arena.onboarding_step = 0
		arena.hand = [0,1,2,6]
		arena._refresh()
		arena._introduce()
		await capture("start"+suffix)
		arena._select_card(0)
		await settle()
		check(arena.card_buttons[0].active,"Selected distinct from playable")
		check(arena.lane_buttons.all(func(slot): return slot.legal),"All own free paths valid")
		check(arena.foe_wells.all(func(slot): return slot.choosing and not slot.legal),"Enemy fields invalid for units")
		await capture("selected-valid"+suffix)
		var energy_before = arena.energy
		arena._board_tap(0,true)
		check(arena.energy == energy_before and arena.feedback_role == "warning","Invalid ownership leaves state intact")
		await capture("invalid"+suffix)
		arena._show_card()
		check(arena.modal.z_index > 20,"Modal above every hand card")
		await capture("inspection"+suffix)
		arena._close_modal()
		reset()
		for i in 5:
			arena.allies[i] = arena.CARD_POOL[i].duplicate(true)
			arena.foes[i] = arena.CARD_POOL[(i+1)%6].duplicate(true)
		arena._refresh()
		await capture("full-board-six-hand"+suffix)
		if dimensions.x == 1280:
			arena.end_button.hover = true
			arena.end_button.queue_redraw()
			await capture("hover-1280x720")
			arena.end_button.hover = false
			arena.end_button.queue_redraw()
		arena.hand = [6]
		arena._refresh()
		arena._select_card(0)
		await settle()
		check(arena.foe_faces.all(func(face): return face.target_state == "valid"),"Spell enemy targets valid")
		check(arena.lane_faces.all(func(face): return face.target_state == "invalid"),"Spell own units invalid")
		await capture("spell-targets"+suffix)
		arena._show_card()
		await capture("spell-inspection"+suffix)
		arena._close_modal()
		arena.energy = 0
		arena._refresh()
		arena._board_tap(0,true)
		check(arena.feedback_role == "warning","Insufficient energy explained")
		await capture("unaffordable"+suffix)
		arena._show_menu()
		await capture("menu-reduced-motion"+suffix)
		arena._show_help()
		await capture("help"+suffix)
		arena._show_hero(false)
		await capture("hero-inspection"+suffix)
		arena._close_modal()
		arena._finish("SIEG · Der gegnerische Held fällt!")
		await settle()
		check(arena.end_button.disabled and arena.end_button.caption == "DUELL BEENDET","Victory disables completed turn action")
		await capture("victory"+suffix)
		arena._close_modal()
		arena.finished = false
		arena._finish("NIEDERLAGE · Dein Held ist gefallen.")
		await settle()
		check(arena.end_button.disabled and arena.end_button.caption == "DUELL BEENDET","Defeat disables completed turn action")
		await capture("defeat"+suffix)
	reset()
	root.size = Vector2i(844,390)
	await settle()
	arena.allies[0] = arena.CARD_POOL[0].duplicate(true)
	arena.foes[0] = arena.CARD_POOL[1].duplicate(true)
	arena._set_reduced_motion(false,false)
	arena._refresh()
	arena._end_turn()
	check(arena.busy,"Combat locks critical actions")
	await capture("combat-844x390")
	await create_timer(.6).timeout
	arena._set_reduced_motion(true,false)
	reset()
	root.size = Vector2i(844,320)
	await settle()
	arena.safe_override = Rect2(44,0,756,299)
	arena._update_orientation()
	await settle()
	var safe = arena.safe_override
	for control in [arena.help_button,arena.detail_button,arena.end_button]+arena.card_buttons+arena.lane_buttons:
		check(safe.encloses(control.get_global_rect()),"Safe-area bounds "+str(control.name))
		check(control.get_global_rect().size.x >= 44 and control.get_global_rect().size.y >= 44,"44px with browser bars and insets")
	arena._select_card(0)
	await settle()
	await capture("safe-area-844x320")
	arena._show_card()
	await capture("safe-area-inspection-844x320")
	arena._show_menu()
	await capture("safe-area-menu-844x320")
	arena._show_help()
	await capture("safe-area-help-844x320")
	arena._close_modal()
	arena.safe_override = Rect2(44,0,756,279)
	root.size = Vector2i(844,300)
	await settle()
	reset()
	arena._select_card(0)
	await settle()
	await capture("safe-area-844x300")
	arena._show_card()
	await capture("safe-area-inspection-844x300")
	arena._show_menu()
	await capture("safe-area-menu-844x300")
	arena._show_help()
	await capture("safe-area-help-844x300")
	arena._close_modal()
	arena.finished = false
	arena._finish("SIEG · Der gegnerische Held fällt!")
	await settle()
	var restart = arena.modal_actions.back()
	var point = restart.get_global_rect().get_center()
	var down = InputEventScreenTouch.new()
	down.position = point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up = InputEventScreenTouch.new()
	up.position = point
	up.pressed = false
	Input.parse_input_event(up)
	await create_timer(.4).timeout
	arena = current_scene
	check(arena != null and arena.round_number == 1 and arena.energy == 3,"Touch restarts finished duel")
	check(arena.player_hp == 35 and arena.foe_hp == 35 and arena.hand.size() == 4,"Fresh duel resets gameplay exactly")
	print("UX AUDIT: %d assertions, %d failures; %d paired rendered states" % [assertions,failures,reports.size()])
	quit(1 if failures else 0)
