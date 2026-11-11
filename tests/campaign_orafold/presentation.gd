extends SceneTree
const Overview = preload("res://scenes/campaign_orafold/campaign_overview.tscn")
const Manager = preload("res://scripts/campaign_orafold/campaign_manager.gd")
var assertions := 0
var failures := 0
var ui
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for frame in 4: await process_frame
func _run() -> void:
	root.size = Vector2i(390, 844)
	ui = Overview.instantiate()
	root.add_child(ui)
	await settle()
	var path := "user://campaign_presentation_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	ui.manager = Manager.new("res://data/campaign_orafold/prototype.json", path)
	check(ui.manager.load_campaign(), "Presentation fixture loads")
	ui.manager.changed.connect(ui._manager_changed)
	ui.open_overview()
	check(ui.manager.set_setting("locale", "en"), "English selected")
	await settle()
	check(_header_text().contains(ui.manager.dialogue.text("ui.history", "en")), "Language switch redraws navigation immediately")
	check(not _header_text().contains(ui.manager.dialogue.text("ui.history", "de")), "Navigation does not keep previous locale")
	check(ui.manager.set_setting("locale", "de"), "German selected")
	await settle()
	check(_header_text().contains(ui.manager.dialogue.text("ui.history", "de")), "Reverse language switch redraws immediately")
	# Establish completed campaign state through ordinary narrative and adapter callbacks.
	ui._start_chapter("cp01", false)
	check(ui.manager.advance() and ui.manager.choose("preserve") and ui.manager.advance(), "First run reaches encounter")
	var initial: Dictionary = ui.manager.request_battle()
	check(ui.manager.resolve_battle(initial.token, "victory") and ui.manager.advance(), "Fixture earns chapter replay")
	ui._start_chapter("cp01", true)
	check(ui.manager.advance() and ui.manager.choose("compare") and ui.manager.advance(), "Replay reaches encounter")
	ui._start_battle()
	await settle()
	var abandoned = ui.battle_adapter
	var old_token: String = abandoned.token
	check(ui.screen == "battle" and ui.manager.state.data.active.battle.token == old_token, "Narrative and battle adapter share token")
	ui.open_overview()
	ui._resume()
	await settle()
	check(ui.battle_adapter == abandoned and ui.battle_adapter.token == old_token, "Navigation resumes existing battle instance")
	# Starting another replay discards this unfinished run but keeps campaign baseline.
	ui.open_overview()
	ui._start_chapter("cp01", true)
	check(ui.manager.current_scene().id == "threshold", "Another replay resets narrative cursor")
	check(ui.manager.advance() and ui.manager.choose("preserve") and ui.manager.advance(), "New replay reaches fresh encounter")
	ui._start_battle()
	await settle()
	var new_token: String = ui.manager.state.data.active.battle.token
	check(new_token != old_token, "New run issues fresh durable battle token")
	check(ui.battle_adapter != abandoned and ui.battle_adapter.token == new_token, "New request replaces stale adapter")
	check(ui.battle_view.adapter == ui.battle_adapter, "Visible battle owns current adapter")
	var before: String = JSON.stringify(ui.manager.state.data, "", true)
	ui._battle_returned(new_token, "victory")
	check(JSON.stringify(ui.manager.state.data, "", true) == before, "Matching token without confirmed terminal result cannot forge victory")
	ui._battle_returned(old_token, "victory")
	check(JSON.stringify(ui.manager.state.data, "", true) == before, "Late abandoned battle callback cannot alter new run")
	check(ui.manager.current_scene().id == "practice", "Late callback does not route narrative")
	# Confirm actual surrender through BattleView controls and return to correct story route.
	ui.battle_view.actions.surrender.pressed.emit()
	await settle()
	check(ui.battle_view.actions.has("confirm"), "Surrender needs confirmation")
	ui.battle_view.actions.confirm.pressed.emit()
	await settle()
	check(ui.battle_adapter.outcome == "defeat" and ui.battle_view.actions.has("return"), "Current adapter supplies defeat result")
	ui.battle_view.actions["return"].pressed.emit()
	await settle()
	check(ui.screen == "dialogue" and ui.manager.current_scene().id == "defeat", "Current result returns to defeat narrative")
	check(ui.battle_adapter == null, "Resolved adapter released")
	check(ui.manager.state.data.encounters.first_practice.last_token == new_token, "Only current token recorded")
	check(ui.manager.advance(), "Defeat route allows retry")
	ui._start_battle(); await settle()
	check(ui.battle_adapter != null and ui.battle_adapter.token != new_token, "Retry creates another fresh adapter")
	# Rendering a missing adapter returns to an actionable encounter without recursion.
	ui.battle_adapter = null
	ui.screen = "battle"
	ui._render(); await settle()
	check(ui.screen == "dialogue" and ui.manager.current_scene().id == "practice", "Missing adapter rendering safely returns to encounter")
	ui.manager.content.encounters.first_practice.deck_profile = "invalid_profile"
	ui._start_battle(); await settle()
	check(ui.screen == "dialogue" and ui.battle_adapter == null, "Invalid adapter setup preserves retry without recursive render")
	ui.manager.content.encounters.first_practice.deck_profile = "houses"
	ui._resume(); await settle()
	check(ui.screen == "battle" and ui.battle_adapter != null, "Corrected adapter configuration resumes persisted request")
	# Campaign selection must determine overview title and progress, even with multiple definitions.
	ui.manager.content.campaigns["alternate"] = {"id":"alternate","title_id":"scene.blank.title","summary_id":"chapter.cp02.summary","chapters":["cp02"],"status":"PROTOTYPE","source":"test fixture"}
	check(ui.manager.load_campaign("alternate"), "Second campaign definition loads")
	ui.open_overview(); await settle()
	check(ui.main.get_child(1).text == ui.manager.dialogue.text("scene.blank.title"), "Overview uses selected campaign title")
	var overview_text: Array = []
	_collect_text(ui.main, overview_text)
	check("\n".join(overview_text).contains("0 / 1"), "Overview completion count belongs to selected campaign")
	ui.queue_free(); await settle()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("ORAFOLD PRESENTATION: %d assertions, %d failures; immediate locale redraw, battle navigation, stale tokens and surrender return" % [assertions, failures])
	quit(1 if failures else 0)
func _header_text() -> String:
	var parts: Array = []
	_collect_text(ui.header, parts)
	return "\n".join(parts)
func _collect_text(node: Node, found: Array) -> void:
	if node is Label or node is Button: found.append(node.text)
	for child in node.get_children(): _collect_text(child, found)
