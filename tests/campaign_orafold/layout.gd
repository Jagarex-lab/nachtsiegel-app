extends SceneTree
const Overview = preload("res://scenes/campaign_orafold/campaign_overview.tscn")
const Manager = preload("res://scripts/campaign_orafold/campaign_manager.gd")
var assertions := 0
var failures := 0
var metrics: Array = []
var ui
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in 6: await process_frame
func _run() -> void:
	root.min_size = Vector2i.ZERO
	ui = Overview.instantiate()
	root.add_child(ui)
	await settle()
	var path := "user://campaign_layout_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	ui.manager = Manager.new("res://data/campaign_orafold/prototype.json", path)
	check(ui.manager.load_campaign(), "UI fixture campaign loads")
	ui.manager.changed.connect(ui._manager_changed)
	check(ui.manager.start_chapter("cp01"), "UI narrative starts")
	check(ui.manager.set_setting("text_speed", 0), "No timing-dependent reveal in geometry tests")
	for viewport_size in [Vector2i(360,800), Vector2i(390,844), Vector2i(844,390), Vector2i(1280,720)]:
		root.size = viewport_size
		await settle()
		for language in ["de", "en"]:
			for text_scale in [1.0, 1.3]:
				ui.manager.set_setting("locale", language)
				ui.manager.set_setting("text_scale", text_scale)
				for view in ["overview", "dialogue", "history", "characters", "settings"]:
					ui.call("open_" + view)
					await settle()
					var label := "%dx%d %s %.2f %s" % [viewport_size.x, viewport_size.y, language, text_scale, view]
					_geometry(label, viewport_size)
					metrics.append({"viewport":[viewport_size.x,viewport_size.y],"locale":language,"text_scale":text_scale,"view":view,"content_height":ui.main.size.y,"scroll_height":ui.body.size.y,"header_height":ui.header.size.y})
	# Choice text and paragraph wrapping after line advancement; read scenes can be skipped.
	ui.manager.set_setting("locale", "de")
	ui.manager.set_setting("text_scale", 1.3)
	root.size = Vector2i(360,800)
	ui.open_dialogue()
	await settle()
	check(ui.active_text != null and ui.active_text.visible_characters == ui.active_text.get_total_character_count(), "Instant/reduced-motion dialogue is complete")
	var first: int = ui.line_index
	ui.advance_dialogue(); await settle()
	check(ui.line_index == first + 1, "Keyboard-equivalent dialogue advancement")
	ui.advance_dialogue(); ui.advance_dialogue(); await settle()
	check(ui.manager.current_scene().id == "first_question", "Presentation reaches decision scene")
	ui.advance_dialogue(); await settle()
	_geometry("360x800 enlarged decision", Vector2i(360,800))
	check(ui.manager.available_choices().size() == 2, "Presentation decision choices available")
	ui.manager.choose("preserve"); ui.manager.advance()
	ui.open_dialogue(); await settle()
	_geometry("360x800 encounter entry", Vector2i(360,800))
	ui.open_history(); await settle()
	check(ui.manager.dialogue.history().size() >= 5, "History contains prior scene text")
	check(ui.main.size.y > ui.body.size.y, "Long dialogue history scrolls vertically")
	ui.body.scroll_vertical = 100000; await settle()
	check(ui.body.scroll_vertical > 0, "History can reach content below fold")
	var writer := FileAccess.open("res://work/campaign_orafold/layout-results.json", FileAccess.WRITE)
	writer.store_string(JSON.stringify(metrics, "  ")); writer.close()
	ui.queue_free(); await settle()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("ORAFOLD LAYOUT: %d assertions, %d failures; 80 viewport/locale/scale/view combinations plus decisions and scrolling" % [assertions, failures])
	quit(1 if failures else 0)
func _geometry(label: String, viewport_size: Vector2i) -> void:
	check(ui.size.distance_to(Vector2(viewport_size)) < 2, label + " uses real viewport")
	check(ui.body.size.x > 0 and ui.body.size.y >= 90, label + " usable scroll region")
	check(ui.main.size.x <= ui.body.size.x + 1, label + " no horizontal narrative overflow")
	check(ui.footer.get_global_rect().end.y <= viewport_size.y + 1, label + " save status inside viewport")
	var buttons: Array = []
	_collect_buttons(ui, buttons)
	check(buttons.size() >= 4, label + " navigation available")
	for button in buttons:
		if not button.is_visible_in_tree(): continue
		check(button.size.y >= 48 and button.size.x >= 48, label + " touch target >=48 " + button.text)
		check(button.focus_mode != Control.FOCUS_NONE, label + " keyboard focus " + button.text)
		check(button.get_global_rect().position.x >= -1 and button.get_global_rect().end.x <= viewport_size.x + 1, label + " button fits width " + button.text)
	var labels: Array = []
	_collect_text(ui.main, labels)
	for text in labels:
		if text is Label:
			check(text.get_line_count() > 0 and text.size.y + 1 >= text.get_minimum_size().y, label + " label height supports wrapping")
		elif text is RichTextLabel:
			check(text.fit_content and not text.scroll_active, label + " rich text expands into outer scroll")
func _collect_buttons(node: Node, found: Array) -> void:
	if node is BaseButton: found.append(node)
	for child in node.get_children(): _collect_buttons(child, found)
func _collect_text(node: Node, found: Array) -> void:
	if node is Label or node is RichTextLabel: found.append(node)
	for child in node.get_children(): _collect_text(child, found)
