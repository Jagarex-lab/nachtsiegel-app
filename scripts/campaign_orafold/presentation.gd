extends Control
## Isolated narrative shell. Never changes the productive arena or its save files.
const Manager = preload("res://scripts/campaign_orafold/campaign_manager.gd")
const BattleAdapter = preload("res://scripts/campaign_orafold/battle_adapter.gd")
const BattleView = preload("res://scripts/campaign_orafold/battle_view.gd")
const BODY_FONT = preload("res://assets/fonts/Body.ttf")
const TITLE_FONT = preload("res://assets/fonts/Cinzel.ttf")
const INK = Color("ecedf5")
const MUTED = Color("b3bfd0")
const COPPER = Color("e1b288")
const BLUE = Color("a9dfef")
const JADE = Color("91d6bc")
const AMETHYST = Color("c5b7ef")

var manager
var screen := "overview"
var body: ScrollContainer
var main: VBoxContainer
var frame: MarginContainer
var header: VBoxContainer
var footer: Label
var backdrop: TextureRect
var line_index := 0
var active_text: RichTextLabel
var next_button: Button
var active_scene_id := ""
var reveal_count := 0.0
var battle_adapter
var battle_view
var compact := false
var _last_compact := false
var _rendering := false
var _web_poll := 0.0
var _qa_enabled := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("web"):
		_qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
		_sync_web_viewport()
		JavaScriptBridge.eval("document.title='ORAFOLD · Campaign Prototype';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD narrative campaign prototype')")
	manager = Manager.new()
	manager.load_campaign()
	manager.changed.connect(_manager_changed)
	_build_shell()
	get_viewport().size_changed.connect(_viewport_changed)
	open_overview()

func _build_shell() -> void:
	var shell_theme = Theme.new()
	shell_theme.default_font = BODY_FONT
	shell_theme.default_font_size = 18
	shell_theme.set_color("font_color", "Label", INK)
	shell_theme.set_color("font_color", "Button", INK)
	shell_theme.set_stylebox("normal", "Button", _box(Color("162135"), Color("475775"), 8, 12))
	shell_theme.set_stylebox("hover", "Button", _box(Color("22324a"), BLUE, 8, 12))
	shell_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BLUE, 8, 2))
	theme = shell_theme
	var base = ColorRect.new()
	base.color = Color("080d18")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color(1, 1, 1, 0.5)
	add_child(backdrop)
	_set_background("res://assets/campaign_orafold/fold_background.svg")
	frame = MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	frame.add_child(layout)
	header = VBoxContainer.new()
	layout.add_child(header)
	body = ScrollContainer.new()
	body.name = "NarrativeScroll"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.follow_focus = true
	body.scroll_deadzone = 8
	layout.add_child(body)
	main = VBoxContainer.new()
	main.name = "NarrativeContent"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 18)
	body.add_child(main)
	footer = _label("", 12, MUTED)
	layout.add_child(footer)
	_viewport_changed()

func _viewport_changed() -> void:
	compact = get_viewport_rect().size.x < 720
	var margin = 12 if get_viewport_rect().size.y < 500 else (16 if compact else 36)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, margin)
	if compact != _last_compact:
		_last_compact = compact
		if main != null:
			_render()

func _t(id: String) -> String:
	return manager.dialogue.text(id)

func _scale() -> float:
	return float(manager.state.data.settings.get("text_scale", 1.0))

func _box(color: Color = Color("111a2a"), border: Color = Color("3d4b63"), radius: int = 12, padding: int = 20) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(text_value: String, font_size: int = 18, color: Color = INK, title: bool = false) -> Label:
	var result = Label.new()
	result.text = text_value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font", TITLE_FONT if title else BODY_FONT)
	result.add_theme_font_size_override("font_size", int(font_size * _scale()))
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _button(text_value: String, action: Callable, primary: bool = false, qa_id: String = "") -> Button:
	var result = Button.new()
	result.text = text_value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = maxf(52.0, 44.0 * _scale())
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_override("font", BODY_FONT)
	result.add_theme_font_size_override("font_size", int(17 * _scale()))
	result.add_theme_color_override("font_color", Color("101521") if primary else INK)
	result.add_theme_color_override("font_hover_color", Color("101521") if primary else INK)
	result.add_theme_color_override("font_pressed_color", Color("101521") if primary else INK)
	result.add_theme_stylebox_override("normal", _box(COPPER if primary else Color("162135"), COPPER if primary else Color("475775"), 8, 14))
	result.add_theme_stylebox_override("hover", _box(Color("f0c7a5") if primary else Color("22324a"), BLUE, 8, 14))
	result.add_theme_stylebox_override("pressed", _box(Color("bd967b") if primary else Color("2b3a50"), COPPER, 8, 14))
	result.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), BLUE, 8, 2))
	result.pressed.connect(action)
	if not qa_id.is_empty(): result.set_meta("qa_id", qa_id)
	return result

func _panel(parent: Node, border: Color = Color("3d4b63")) -> VBoxContainer:
	var panel = PanelContainer.new()
	# Decorative panels must let touch drags reach the ancestor scroll view.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color(0.055, 0.08, 0.13, 0.96), border, 12, 18 if compact else 26))
	parent.add_child(panel)
	var result = VBoxContainer.new()
	result.add_theme_constant_override("separation", 14)
	panel.add_child(result)
	return result

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _header() -> void:
	_clear(header)
	var brand_row = HBoxContainer.new()
	header.add_child(brand_row)
	brand_row.add_child(_label("ORAFOLD", 26 if compact else 32, INK, true))
	var badge = _label(_t("ui.prototype"), 11, COPPER)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.custom_minimum_size.x = 120 if compact else 200
	brand_row.add_child(badge)
	var navigation = HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 8)
	header.add_child(navigation)
	for entry in [["ui.overview", open_overview], ["ui.history", open_history], ["ui.characters", open_characters], ["ui.settings", open_settings]]:
		var button = _button(_t(entry[0]), entry[1])
		button.custom_minimum_size.x = 132 if not compact else maxf(100, (get_viewport_rect().size.x - 40) / 2.0)
		button.add_theme_font_size_override("font_size", int(14 * _scale()))
		navigation.add_child(button)
	var line = HSeparator.new()
	line.modulate = Color("52617a")
	header.add_child(line)

func _manager_changed() -> void:
	if not _rendering:
		_render()

func _render() -> void:
	if main == null or manager == null:
		return
	_rendering = true
	active_text = null
	next_button = null
	battle_view = null
	_clear(main)
	_header()
	match screen:
		"dialogue": _render_dialogue()
		"characters": _render_characters()
		"history": _render_history()
		"settings": _render_settings()
		"battle": _render_battle()
		_: _render_overview()
	footer.text = _t("ui.saved") if manager.last_error.is_empty() else _t("ui.save_error") + " · " + str(manager.last_error)
	footer.add_theme_color_override("font_color", MUTED if manager.last_error.is_empty() else Color("ffb6b6"))
	_rendering = false

func _set_background(path: String) -> void:
	if backdrop == null or path.is_empty() or not ResourceLoader.exists(path):
		return
	backdrop.texture = load(path)

func _page_title(kicker: String, title: String, summary: String = "") -> void:
	main.add_child(_label(kicker.to_upper(), 12, COPPER))
	main.add_child(_label(title, 29 if compact or get_viewport_rect().size.y < 500 else 43, INK, true))
	if not summary.is_empty():
		main.add_child(_label(summary, 18, MUTED))

func open_overview() -> void:
	screen = "overview"
	_render()
	body.scroll_vertical = 0

func open_dialogue() -> void:
	screen = "dialogue"
	_render()
	body.scroll_vertical = 0

func open_history() -> void:
	screen = "history"
	_render()
	body.scroll_vertical = 0

func open_characters() -> void:
	screen = "characters"
	_render()
	body.scroll_vertical = 0

func open_settings() -> void:
	screen = "settings"
	_render()
	body.scroll_vertical = 0

func _render_overview() -> void:
	_set_background("res://assets/campaign_orafold/fold_background.svg")
	var campaigns: Dictionary = manager.content.get("campaigns", {})
	var campaign: Dictionary = campaigns.get(manager.state.data.campaign_id, {})
	_page_title(_t("ui.overview"), _t(str(campaign.get("title_id", "ui.prototype"))), _t(str(campaign.get("summary_id", "ui.prototype"))))
	var chapters: Array = manager.chapters()
	var completed := 0
	for chapter in chapters:
		if chapter.get("completed", false): completed += 1
	var progress_row = _panel(main, Color("44526b"))
	progress_row.add_child(_label(_t("ui.progress") + "  %d / %d" % [completed, chapters.size()], 15, BLUE))
	var progress = ProgressBar.new()
	progress.custom_minimum_size.y = 5
	progress.show_percentage = false
	progress.max_value = max(1, chapters.size())
	progress.value = completed
	progress_row.add_child(progress)
	var current: Dictionary = manager.current_scene()
	if not current.is_empty():
		progress_row.add_child(_button(_t("ui.resume") + "  ·  " + _t(str(current.get("title_id", "ui.scene"))), _resume, true, "resume"))
	var cards: Container = VBoxContainer.new() if compact else HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	main.add_child(cards)
	for index in chapters.size():
		var chapter: Dictionary = chapters[index]
		var card = _panel(cards, COPPER if index == 0 else AMETHYST)
		card.add_child(_label("0%d  /  %s" % [index + 1, _t("ui.chapter").to_upper()], 13, COPPER if index == 0 else AMETHYST))
		card.add_child(_label(_t(str(chapter.get("title_id", "ui.chapter"))), 25, INK, true))
		var summary_key = str(chapter.get("summary_id", chapter.get("description_id", "")))
		if not summary_key.is_empty():
			card.add_child(_label(_t(summary_key), 17, MUTED))
		var status_key = "ui.completed" if chapter.get("completed", false) else ("ui.start" if chapter.get("unlocked", false) else "ui.locked")
		card.add_child(_label(_t(status_key).to_upper(), 12, JADE if chapter.get("completed", false) else MUTED))
		var chapter_id = str(chapter.get("id", ""))
		var replay = bool(chapter.get("completed", false))
		if replay:
			card.add_child(_label(_t("ui.replay_note"), 14, MUTED))
		var action = _button(_t("ui.replay" if replay else "ui.start"), func(): _start_chapter(chapter_id, replay), not replay)
		action.set_meta("qa_id", "chapter_"+chapter_id)
		action.disabled = not bool(chapter.get("unlocked", false))
		card.add_child(action)

func _start_chapter(id: String, replay: bool) -> void:
	if manager.start_chapter(id, replay):
		if battle_adapter != null and battle_adapter.token != manager.state.data.active.get("battle", {}).get("token", ""):
			battle_adapter = null
		active_scene_id = ""
		line_index = 0
		open_dialogue()

func _resume() -> void:
	if not manager.state.data.active.get("battle", {}).is_empty():
		_start_battle()
	else:
		open_dialogue()

func _render_dialogue() -> void:
	var scene: Dictionary = manager.current_scene()
	if scene.is_empty():
		screen = "overview"
		_render_overview()
		return
	var id = str(scene.get("id", ""))
	if active_scene_id != id:
		active_scene_id = id
		line_index = 0
	_set_background(str(scene.get("background", "")))
	_page_title(_t("ui.scene"), _t(str(scene.get("title_id", "ui.scene"))))
	var lines: Array = manager.dialogue.lines(scene, manager.state.data)
	line_index = clampi(line_index, 0, maxi(0, lines.size() - 1))
	var panel = _panel(main, Color("64758d"))
	if not lines.is_empty():
		var line: Dictionary = lines[line_index]
		var speaker: Dictionary = manager.character(str(line.get("speaker_id", "")))
		var identity = HBoxContainer.new()
		identity.add_theme_constant_override("separation", 18)
		panel.add_child(identity)
		var portrait_path = str(speaker.get("portrait", ""))
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var portrait = TextureRect.new()
			portrait.texture = load(portrait_path)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(72, 88) if compact else Vector2(104, 124)
			identity.add_child(portrait)
		var captions = VBoxContainer.new()
		captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(captions)
		captions.add_child(_label(_t(str(speaker.get("name_id", "ui.scene"))), 22, COPPER, true))
		captions.add_child(_label(str(speaker.get("status", scene.get("status", ""))), 12, MUTED))
		captions.add_child(_label("%02d / %02d" % [line_index + 1, lines.size()], 13, BLUE))
		active_text = RichTextLabel.new()
		active_text.name = "DialogueText"
		active_text.bbcode_enabled = false
		active_text.fit_content = true
		active_text.scroll_active = false
		active_text.selection_enabled = true
		active_text.add_theme_font_override("normal_font", BODY_FONT)
		active_text.add_theme_font_size_override("normal_font_size", int(21 * _scale()))
		active_text.add_theme_color_override("default_color", INK)
		active_text.text = _t(str(line.get("text_id", "")))
		panel.add_child(active_text)
		reveal_count = float(active_text.get_total_character_count()) if manager.state.data.settings.get("reduced_motion", false) or float(manager.state.data.settings.get("text_speed", 35)) <= 0 else 0.0
		active_text.visible_characters = int(reveal_count)
	var last_line = lines.is_empty() or line_index >= lines.size() - 1
	if not last_line:
		next_button = _button(_t("ui.next") + "  →", advance_dialogue, true)
		next_button.set_meta("qa_id", "next")
		panel.add_child(next_button)
	else:
		var choices: Array = manager.available_choices()
		if not choices.is_empty():
			panel.add_child(_label(_t("ui.choices"), 13, BLUE))
			for choice in choices:
				var choice_id = str(choice.get("id", ""))
				panel.add_child(_button(_t(str(choice.get("text_id", ""))), func(): _choose(choice_id), false, "choice_"+choice_id))
		elif scene.has("encounter_id"):
			panel.add_child(_button(_t("ui.battle") + "  →", _start_battle, true))
		else:
			next_button = _button(_t("ui.continue") + "  →", advance_dialogue, true)
			next_button.set_meta("qa_id", "next")
			panel.add_child(next_button)
	if manager.state.data.seen_scenes.has(id) and lines.size() > 1 and not last_line:
		panel.add_child(_button(_t("ui.skip_read"), func(): line_index = lines.size() - 1; _render()))

func advance_dialogue() -> void:
	if screen != "dialogue":
		return
	if active_text != null and active_text.visible_characters < active_text.get_total_character_count():
		active_text.visible_characters = active_text.get_total_character_count()
		reveal_count = float(active_text.visible_characters)
		return
	var scene: Dictionary = manager.current_scene()
	var lines: Array = manager.dialogue.lines(scene, manager.state.data)
	if line_index < lines.size() - 1:
		line_index += 1
		manager.events.publish("story.dialogue_advance", {"scene_id": active_scene_id, "line": line_index})
		_render()
		body.scroll_vertical = 0
	elif not scene.has("decision_id") and not scene.has("encounter_id"):
		manager.advance()
		body.scroll_vertical = 0

func _choose(id: String) -> void:
	if manager.choose(id):
		body.scroll_vertical = 0

func _start_battle() -> void:
	var request: Dictionary = manager.request_battle()
	if request.is_empty():
		return
	if battle_adapter != null and battle_adapter.token != str(request.get("token", "")):
		battle_adapter = null
	if battle_adapter == null:
		battle_adapter = BattleAdapter.new()
		if not battle_adapter.begin(request, str(request.get("token", ""))):
			battle_adapter = null
			# Keep the narrative encounter available for a retry; never re-enter rendering.
			screen = "dialogue"
			_render()
			return
	screen = "battle"
	_render()
	body.scroll_vertical = 0

func _render_battle() -> void:
	var active_token: String = manager.state.data.active.get("battle", {}).get("token", "")
	if battle_adapter == null or active_token.is_empty() or battle_adapter.token != active_token:
		battle_adapter = null
		screen = "dialogue"
		_render_dialogue()
		return
	_page_title(_t("ui.prototype"), _t("ui.battle"))
	battle_view = BattleView.new()
	main.add_child(battle_view)
	battle_view.setup(battle_adapter, manager.dialogue)
	battle_view.returned.connect(_battle_returned)

func _battle_returned(token: String, outcome: String) -> void:
	if manager.resolve_battle(token, outcome):
		battle_adapter = null
		open_dialogue()

func _render_characters() -> void:
	_page_title("ORAFOLD", _t("ui.characters"))
	for id in manager.content.get("characters", {}):
		var character: Dictionary = manager.character(str(id))
		var panel = _panel(main, AMETHYST if id == "eira" else COPPER)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var portrait_path = str(character.get("portrait", ""))
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var portrait = TextureRect.new()
			portrait.texture = load(portrait_path)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(64, 84)
			row.add_child(portrait)
		var description = VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		description.add_child(_label(_t(str(character.get("name_id", "ui.character_unknown"))), 25, INK, true))
		description.add_child(_label(str(character.get("status", "")), 12, COPPER))
		panel.add_child(_label(_t(str(character.get("description_id", "ui.character_unknown"))), 18, MUTED))
		var knowledge = character.get("knowledge", [])
		if knowledge is Array:
			for fact in knowledge:
				if fact is Dictionary:
					panel.add_child(_label(_t(str(fact.get("text_id", "ui.character_locked"))), 17, BLUE))
		if knowledge is Array and knowledge.is_empty():
			panel.add_child(_label(_t("ui.character_locked"), 15, MUTED))

func _render_history() -> void:
	_page_title("ORAFOLD", _t("ui.history"))
	var history: Array = manager.dialogue.history()
	if history.is_empty():
		main.add_child(_label(_t("ui.no_history"), 18, MUTED))
	for record in history:
		if not record is Dictionary:
			continue
		var panel = _panel(main)
		var scene_id = str(record.get("scene_id", ""))
		var scene: Dictionary = manager.content.get("scenes", {}).get(scene_id, {})
		panel.add_child(_label(_t(str(scene.get("title_id", "ui.scene"))), 18, COPPER, true))
		if record.has("text_id"):
			var speaker: Dictionary = manager.character(str(record.get("speaker_id", "")))
			panel.add_child(_label(_t(str(speaker.get("name_id", "ui.scene"))), 13, BLUE))
			panel.add_child(_label(_t(str(record.text_id)), 18, INK))
		for line in record.get("lines", []):
			if line is Dictionary:
				var speaker: Dictionary = manager.character(str(line.get("speaker_id", "")))
				panel.add_child(_label(_t(str(speaker.get("name_id", "ui.scene"))), 13, BLUE))
				panel.add_child(_label(_t(str(line.get("text_id", ""))), 18))
		if record.has("choice_id"):
			panel.add_child(_label(_t("ui.choices") + " · " + str(record.choice_id), 14, JADE))

func _render_settings() -> void:
	_page_title("ORAFOLD", _t("ui.settings"))
	var panel = _panel(main)
	panel.add_child(_label(_t("ui.language"), 18, BLUE))
	var languages = HBoxContainer.new()
	languages.add_theme_constant_override("separation", 12)
	panel.add_child(languages)
	for pair in [["de", "Deutsch"], ["en", "English"]]:
		var locale_id = str(pair[0])
		languages.add_child(_button(pair[1], func(): manager.set_setting("locale", locale_id), manager.state.data.settings.get("locale", "de") == locale_id))
	var motion = CheckButton.new()
	motion.text = _t("ui.reduce_motion")
	motion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motion.custom_minimum_size.y = 56
	motion.button_pressed = bool(manager.state.data.settings.get("reduced_motion", false))
	motion.add_theme_font_override("font", BODY_FONT)
	motion.add_theme_font_size_override("font_size", int(17 * _scale()))
	motion.toggled.connect(func(value: bool): manager.set_setting("reduced_motion", value))
	panel.add_child(motion)
	panel.add_child(_label(_t("ui.text_speed"), 18, BLUE))
	var speeds = HFlowContainer.new()
	speeds.add_theme_constant_override("h_separation", 12)
	panel.add_child(speeds)
	for speed in [0, 25, 50]:
		var selected_speed = speed
		var speed_text = _t("ui.instant") if speed == 0 else _t("ui.slow" if speed == 25 else "ui.fast")
		speeds.add_child(_button(speed_text, func(): manager.set_setting("text_speed", selected_speed), float(manager.state.data.settings.get("text_speed", 35)) == speed))
	panel.add_child(_label(_t("ui.text_scale"), 18, BLUE))
	var scales = HFlowContainer.new()
	scales.add_theme_constant_override("h_separation", 12)
	panel.add_child(scales)
	for scale_value in [1.0, 1.15, 1.3]:
		var selected_scale = scale_value
		scales.add_child(_button(str(int(scale_value * 100)) + " %", func(): manager.set_setting("text_scale", selected_scale), is_equal_approx(_scale(), scale_value)))
	if not manager.current_scene().is_empty():
		panel.add_child(_button(_t("ui.resume"), _resume, true))

func _process(delta: float) -> void:
	if OS.has_feature("web"):
		_web_poll += delta
		if _web_poll >= 0.15:
			_web_poll = 0.0
			_sync_web_viewport()
			if _qa_enabled: _publish_qa()
	if is_instance_valid(active_text) and active_text.visible_characters < active_text.get_total_character_count():
		var speed = float(manager.state.data.settings.get("text_speed", 35))
		reveal_count += delta * speed
		active_text.visible_characters = int(reveal_count)

func _sync_web_viewport() -> void:
	# The canvas backing store uses device pixels. Narrative layout uses CSS
	# pixels, so high-DPI portrait screens retain readable type and touch targets.
	var raw = JavaScriptBridge.eval("JSON.stringify({width:innerWidth,height:innerHeight})")
	if not raw is String: return
	var dimensions = JSON.parse_string(raw)
	if not dimensions is Dictionary: return
	var logical := Vector2i(maxi(1,int(dimensions.get("width",1280))),maxi(1,int(dimensions.get("height",720))))
	var window := get_window()
	if window.content_scale_size != logical:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_size = logical

func _publish_qa() -> void:
	# Read-only diagnostics: JavaScript receives coordinates, never callbacks or
	# commands that could change campaign state or manufacture a battle result.
	var controls: Dictionary = {}
	_qa_controls(self, controls)
	var campaign: Dictionary = manager.content.get("campaigns",{}).get(manager.state.data.campaign_id,{})
	var payload = {"screen":screen,"title":_t(campaign.get("title_id","ui.prototype")),"scene_id":manager.state.data.active.get("scene_id",""),"flags":manager.state.data.flags,"actions":controls,"save_error":manager.last_error,"validation_errors":manager.validation.get("errors",[]),"logical_viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y],"compact":compact}
	JavaScriptBridge.eval("window.orafoldCampaignQA="+JSON.stringify(payload))

func _qa_controls(node: Node, output: Dictionary) -> void:
	if node is Button and node.has_meta("qa_id") and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		output[str(node.get_meta("qa_id"))] = {"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"disabled":node.disabled}
	for child in node.get_children(): _qa_controls(child,output)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and screen == "dialogue":
			advance_dialogue()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and screen != "overview":
			open_overview()
			get_viewport().set_input_as_handled()
