extends SceneTree
## Real Control layout and touch-input tests. Run headless or with a rendering display.
const Prototype = preload("res://scripts/economy/prototype.gd")
const Manager = preload("res://scripts/economy/economy_manager.gd")
var app
var assertions := 0
var failures := 0
const SAVE := "user://economy-ui-test.json"

func check(value: bool, description: String) -> void:
	assertions += 1
	if not value: failures += 1; printerr("FAIL: ", description)

func settle() -> void:
	for i in range(5): await process_frame

func tap(control: Control) -> void:
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await settle()
	for pressed in [true, false]:
		var event = InputEventScreenTouch.new()
		event.index = 0
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		Input.parse_input_event(event)
		await settle()

func snapshot() -> String:
	return JSON.stringify(app.economy.state, "", true)

func clean_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)

func shot(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	app.scroll.scroll_vertical = 0
	if is_instance_valid(app.modal):
		for child in app.modal.get_children():
			if child is ScrollContainer: child.scroll_vertical = 0
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/economy/results/" + filename + ".png")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	clean_save()
	app = Prototype.new()
	app.save_path = SAVE
	root.add_child(app)
	await settle()
	check(app.economy.ready, "prototype manager ready with fixture catalog")
	for dimensions in [Vector2i(320, 700), Vector2i(360, 800), Vector2i(390, 844), Vector2i(1280, 900)]:
		root.size = dimensions
		await settle()
		for id in ["starters", "welcome", "buy", "open", "odds", "motion", "craft", "test_match"]:
			var control: Control = app.actions[id]
			check(control.size.y >= 48, "touch target >=48: " + id + str(dimensions))
			check(control.get_global_rect().position.x >= 0 and control.get_global_rect().end.x <= root.size.x + 1, "no horizontal overflow: " + id + str(dimensions))
		check(app.scroll.get_h_scroll_bar().max_value <= app.scroll.size.x + 1, "no horizontal page scroll " + str(dimensions))
	root.size = Vector2i(390, 844)
	await settle()
	await tap(app.actions.starters)
	check(app.economy.state.starters_granted, "actual touch grants four starter entitlements")
	var state_before = snapshot()
	await tap(app.actions.starters)
	check(snapshot() == state_before, "repeat starter touch is idempotent")
	await tap(app.actions.welcome)
	check(int(app.economy.state.wallet.gold) > 0 and int(app.economy.state.wallet.crafting) > 0, "welcome gold and crafting visible")
	check(int(app.economy.state.progression.level) > 1, "welcome XP updates displayed level")
	state_before = snapshot()
	await tap(app.actions.welcome)
	check(snapshot() == state_before, "repeat welcome touch is idempotent")
	var before_xp = int(app.economy.state.progression.xp)
	await tap(app.actions.test_match)
	check(int(app.economy.state.progression.xp) > before_xp and int(app.economy.state.activity.matches) == 1, "test activity touch grants progression")
	var day = int(Time.get_unix_time_from_system() / 86400)
	check(app.economy.state.quests.get("daily_play:" + str(day), {}).get("claimed", false), "test activity completes daily task exactly once")
	await shot("economy-portrait")
	await tap(app.actions.odds)
	check(is_instance_valid(app.modal), "probability disclosure opens from touch")
	check(app.actions.modal_close.size.y >= 48, "disclosure close is touchable")
	await tap(app.actions.modal_close)
	app.reduced_motion = true
	await tap(app.actions.open)
	check(app.reveal_cards.size() == 5 and is_instance_valid(app.modal), "persisted booster returns five visual slots")
	state_before = snapshot()
	await tap(app.actions.reveal_0)
	check(app.revealed.has(0), "card reveal responds to actual touch")
	check(snapshot() == state_before, "card reveal never writes economy state")
	await tap(app.actions.skip)
	check(app.revealed.size() == 5, "skip reveals every result")
	check(snapshot() == state_before, "skip never writes economy state")
	await shot("booster-portrait")
	app.close_modal()
	check(snapshot() == state_before, "interrupted animation retains rewards without writes")
	var reloaded = Manager.new(SAVE)
	check(reloaded.ready and reloaded.state == app.economy.state, "reloading during reveal preserves original transaction and results")
	for dimensions in [Vector2i(320, 700), Vector2i(360, 800), Vector2i(1280, 900)]:
		root.size = dimensions
		await settle()
		app.show_reveal()
		await settle()
		for id in ["reveal_0", "skip", "reveal_done"]:
			var control: Control = app.actions[id]
			check(control.size.y >= 48 and control.get_global_rect().position.x >= 0 and control.get_global_rect().end.x <= root.size.x + 1, "reveal controls fit " + id + str(dimensions))
		app.close_modal()
	root.size = Vector2i(1280, 900)
	await settle()
	app.show_reveal()
	app._skip()
	await shot("booster-desktop")
	app.reveal_cards.clear()
	app.close_modal()
	app.render()
	await settle()
	# Creation and destruction use distinct touch actions and an explicit confirmation.
	app.selection_rarity = "rare"
	app.selected_card = ""
	for id in app.economy.catalog:
		if app.economy.catalog[id].rarity == "rare" and int(app.economy.state.collection.get(id, {}).get("count", 0)) == 0:
			app.selected_card = id
			break
	app.render()
	await settle()
	var selected: String = app.selected_card
	var old_count = int(app.economy.state.collection.get(selected, {}).get("count", 0))
	await tap(app.actions.craft)
	check(int(app.economy.state.collection.get(selected, {}).get("count", 0)) == old_count + 1, "craft touch grants exactly one card")
	check(app.actions.salvage.disabled, "crafted bound output cannot be salvaged")
	# Select a genuinely earned unbound booster copy for destruction UX checks.
	selected = ""
	for id in app.economy.state.collection:
		var entry: Dictionary = app.economy.state.collection[id]
		if int(entry.count) > int(entry.bound):
			selected = id
			break
	check(not selected.is_empty(), "booster granted at least one unbound copy")
	if selected.is_empty():
		app.free()
		quit(1)
		return
	app.selected_card = selected
	app.selection_rarity = app.economy.catalog[selected].rarity
	app.render()
	await settle()
	old_count = int(app.economy.state.collection[selected].count)
	state_before = snapshot()
	await tap(app.actions.salvage)
	check(is_instance_valid(app.modal) and snapshot() == state_before, "salvage waits for explicit confirmation")
	await tap(app.actions.cancel_salvage)
	check(snapshot() == state_before, "cancel salvage preserves all resources")
	await tap(app.actions.salvage)
	await tap(app.actions.confirm_salvage)
	check(int(app.economy.state.collection.get(selected, {}).get("count", 0)) == old_count - 1, "confirmed salvage consumes exactly one unbound card")
	for id in app.economy.state.collection:
		var entry: Dictionary = app.economy.state.collection[id]
		if int(entry.bound) > 0 and entry.bound == entry.count:
			app.selected_card = id
			app.selection_rarity = app.economy.catalog[id].rarity
			app.render()
			await settle()
			check(app.actions.salvage.disabled, "bound starter salvage control protected")
			break
	await shot("economy-desktop")
	reloaded = null
	app.free()
	app = null
	clean_save()
	await settle()
	print("ECONOMY UI: %d assertions, %d failures; mobile layouts and real touch input" % [assertions, failures])
	# The existing autoload owns music opened by real touch; let its mixer drain.
	var audio = root.get_node_or_null("GameAudio")
	if audio != null: audio.request_quit(0 if failures == 0 else 1)
	else: quit(0 if failures == 0 else 1)
