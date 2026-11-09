extends Node3D
## NACHTSIEGEL: original landscape reliquary arena.
## Original 2.5D visual prototype with local combat; NOT a verified port of the legacy rules.
const T = preload("res://scripts/ui_tokens.gd")
const Brand = preload("res://scripts/brand_identity.gd")
const LANES := 5
const MAX_HP := 35
const CARD_POOL = preload("res://data/card_definitions.gd").POOL
var battle = preload("res://scripts/battle_model.gd").new()
var rng: RandomNumberGenerator:
	get: return battle.rng
	set(value): battle.rng = value
var deck: Array:
	get: return battle.deck
	set(value): battle.deck = value
var hand: Array:
	get: return battle.hand
	set(value): battle.hand = value
var allies: Array:
	get: return battle.allies
	set(value): battle.allies = value
var foes: Array:
	get: return battle.foes
	set(value): battle.foes = value
var player_hp: int:
	get: return battle.player_hp
	set(value): battle.player_hp = value
var foe_hp: int:
	get: return battle.foe_hp
	set(value): battle.foe_hp = value
var energy: int:
	get: return battle.energy
	set(value): battle.energy = value
var round_number: int:
	get: return battle.round_number
	set(value): battle.round_number = value
var summons: int:
	get: return battle.summons
	set(value): battle.summons = value
var selected: int:
	get: return battle.selected
	set(value): battle.selected = value
var finished: bool:
	get: return battle.finished
	set(value): battle.finished = value
var streak: int:
	get: return battle.streak
	set(value): battle.streak = value
var ui_layer: CanvasLayer
var root_ui: Control
var status_label: Label
var message_label: Label
var hand_row: Control
var lane_buttons: Array[Button] = []
var hero_player: Label
var hero_enemy: Label
var energy_label: Label
var round_label: Label
var end_button: Button
var landscape_panel: ColorRect
var card_buttons: Array[Button] = []

func _ready() -> void:
	Brand.apply_window_title()
	battle.start(battle_seed,battle_profile)
	_load_preferences()
	_build_ui()
	_refresh()
	call_deferred("_introduce")

func _introduce() -> void:
	if onboarding_step == 0: _announce("1 · Wähle eine Handkarte")
	else: message_label.visible = false

func _label(value: String, font_size: int) -> Label:
	var item = Label.new()
	item.text = value
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.clip_text = true
	item.add_theme_font_override("font",BODY_FONT)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",T.TEXT)
	var label_style = T.panel(T.METAL,Color(T.SURFACE,.96))
	label_style.set_border_width_all(0)
	item.add_theme_stylebox_override("normal",label_style)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.set_meta("base_font",font_size)
	item.set_meta("min_css",12.0)
	labels.append(item)
	return item

func _gold_panel(_base: Color, rim: Color = T.METAL) -> StyleBoxFlat:
	return T.panel(rim)

const CardFace = preload("res://scripts/card_face.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const RitualButton = preload("res://scripts/ritual_button.gd")
const SigilSlot = preload("res://scripts/sigil_slot.gd")
const RitualHud = preload("res://scripts/ritual_hud.gd")
const RitualFx = preload("res://scripts/ritual_fx.gd")
const DISPLAY_FONT = preload("res://assets/fonts/Cinzel.ttf")
const BODY_FONT = preload("res://assets/fonts/Body.ttf")
var lane_faces: Array = []
var foe_faces: Array = []
var info_label: Label
var detail_button: Button
var modal: Control
var busy := false
var restart_button: Button
var energy_gems: Label
var hud_art: Control
var hero_medallions: Array = []
var foe_wells: Array = []

var labels: Array[Label] = []
var actions: Array[Button] = []
var phase_label: Label
var help_button: Button
var backdrop: TextureRect
var ambience: Control
var reduced_motion := false
var onboarding_step := 0
var notification_clock := 0.0
var feedback_role := "secondary"
var last_turn_click := -1000
var modal_kind := ""
var modal_actions: Array[Button] = []
var viewport_scale := .8
var ui_scale := .8
var display_ratio := 1.0
var qa_enabled := false
var qa_clock := 0.0
var safe_override := Rect2()
var phase := "play"
var canvas_width := 1600.0
var path_labels: Array[Label] = []
signal completed(victory: bool, reason: String)
signal main_menu_requested
signal retry_requested
signal continue_requested
signal preferences_updated(reduced: bool)
var managed_session := false
var battle_profile := "standard"
var battle_seed := 8802026
var player_portrait_index := 7
var opponent_portrait_index := 8
var player_title := "Siegelhüterin"
var opponent_title := "Aschenkönig"
var result_summary := ""
var layout_concept := "mobile"
var composition: Dictionary = {}
var stage: Control
var deck_back: Control
var deck_label: Label
var brand_label: Label
var owner_labels: Array[Label] = []

func _put(node: Control, rect: Rect2, parent: Node = null) -> void:
	(parent if parent != null else root_ui).add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.set_meta("base_rect",rect)

func _caption(value: String, rect: Rect2, font_size: int = 26, color: Color = T.SECONDARY, serif: bool = false) -> Label:
	var label = _label(value,font_size)
	label.add_theme_font_override("font",DISPLAY_FONT if serif else BODY_FONT)
	label.add_theme_color_override("font_color",color)
	_put(label,rect)
	label.z_index = 6
	return label

func _action(value: String, rect: Rect2, callback: Callable) -> Button:
	var button = RitualButton.new()
	button.caption = value
	button.emphasis = value.begins_with("ZUG") or value.begins_with("NEUES") or value.begins_with("ZIEL")
	button.view_scale = ui_scale
	button.pressed.connect(callback)
	_put(button,rect)
	actions.append(button)
	return button

func _art(index: int) -> AtlasTexture:
	var texture = AtlasTexture.new()
	texture.atlas = preload("res://assets/art/atlas.png")
	var cell = texture.atlas.get_size()/3.0
	texture.region = Rect2(Vector2(index%3,index/3)*cell,cell)
	return texture

func _face(data: Dictionary, rect: Rect2, index: int, small: bool = false) -> Button:
	var face = CardFace.new()
	face.data = data
	face.art = _art(index)
	face.compact = small
	_put(face,rect)
	return face

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	ui_layer.add_child(root_ui)
	root_ui.size = Vector2(1600,900)
	var theme = Theme.new()
	theme.default_font = BODY_FONT
	theme.set_stylebox("panel","TooltipPanel",T.panel(T.BRONZE))
	theme.set_color("font_color","TooltipLabel",T.TEXT)
	root_ui.theme = theme
	backdrop = TextureRect.new()
	backdrop.texture = preload("res://assets/art/arena_painted.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var light = ShaderMaterial.new()
	light.shader = preload("res://assets/shaders/arena_light.gdshader")
	backdrop.material = light
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(backdrop,Rect2(0,0,1600,900))
	brand_label = _caption(Brand.display_name(),Rect2(24,12,390,64),32,T.TEXT,true)
	brand_label.set_meta("min_css",14.0)
	stage = preload("res://scripts/arena_stage.gd").new()
	_put(stage,Rect2(0,0,1600,900))
	deck_back = preload("res://scripts/card_back.gd").new()
	_put(deck_back,Rect2(28,390,118,148))
	deck_label = _caption("21",Rect2(12,542,150,56),26,T.SECONDARY)
	hud_art = RitualHud.new()
	_put(hud_art,Rect2(0,0,1600,900))
	help_button = _action("MENÜ",Rect2(1370,0,210,103),_show_menu)
	for i in LANES:
		var x = 355.0+i*180.0
		var enemy_well = SigilSlot.new()
		enemy_well.enemy = true
		enemy_well.pressed.connect(_board_tap.bind(i,true))
		_put(enemy_well,Rect2(x,145,160,194))
		foe_wells.append(enemy_well)
		var foe = _face({},Rect2(x,145,160,194),0,true)
		foe.enemy = true
		foe.z_index = 5
		foe.visible = false
		foe.pressed.connect(_board_tap.bind(i,true))
		foe_faces.append(foe)
		var target = SigilSlot.new()
		target.pressed.connect(_board_tap.bind(i,false))
		_put(target,Rect2(x-2,397,164,200))
		lane_buttons.append(target)
		var ally = _face({},Rect2(x,399,160,194),0,true)
		ally.z_index = 5
		ally.visible = false
		ally.pressed.connect(_board_tap.bind(i,false))
		lane_faces.append(ally)
		path_labels.append(_caption(["I","II","III","IV","V"][i],Rect2(x+40,99,80,42),28,T.TEXT,true))
	var enemy = _face({"name":opponent_title,"attack":0,"hp":35,"tint":"#b46753"},Rect2(77,151,174,220),opponent_portrait_index,true)
	enemy.heroic = true
	enemy.enemy = true
	enemy.pressed.connect(_show_hero.bind(true))
	var player = _face({"name":player_title,"attack":0,"hp":35,"tint":"#72beb9"},Rect2(77,426,174,220),player_portrait_index,true)
	player.heroic = true
	player.pressed.connect(_show_hero.bind(false))
	hero_medallions = [player,enemy]
	hero_enemy = _caption("35",Rect2(129,318,70,48),32,T.TEXT)
	hero_player = _caption("35",Rect2(129,593,70,48),32,T.TEXT)
	for health in [hero_player,hero_enemy]:
		var health_style = T.panel(T.DANGER)
		health_style.set_corner_radius_all(12)
		health.add_theme_stylebox_override("normal",health_style)
	hero_enemy.set_meta("min_css",15.0)
	hero_player.set_meta("min_css",15.0)
	owner_labels.append(_caption("GEGNER",Rect2(61,107,280,48),26,T.FOE))
	owner_labels.append(_caption("DU",Rect2(61,380,280,48),26,T.PLAYER))
	round_label = _caption("RUNDE 1",Rect2(1370,110,210,48),26,T.TEXT)
	energy_label = _caption("3",Rect2(1426,173,98,64),40,T.ENERGY)
	energy_label.set_meta("min_css",18.0)
	energy_gems = _caption("ENERGIE 3/10",Rect2(1370,278,210,48),26,T.ENERGY)
	phase_label = _caption("DEIN ZUG",Rect2(1370,330,210,48),27,T.PLAYER)
	info_label = _caption("Karte wählen",Rect2(1370,382,210,96),26,T.TEXT)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_button = _action("DETAILS",Rect2(1370,484,210,103),_show_card)
	detail_button.visible = false
	end_button = _action("ZUG BEENDEN",Rect2(1370,597,210,103),_end_turn)
	hand_row = Control.new()
	_put(hand_row,Rect2(318,655,932,235))
	message_label = _caption("",Rect2(345,348,900,44),28,T.SECONDARY)
	message_label.z_index = 7
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = _caption("",Rect2(1370,710,210,96),24,T.SECONDARY)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restart_button = _action("NEUES DUELL",Rect2(1370,790,210,103),_restart)
	restart_button.visible = false
	ambience = Atmosphere.new()
	_put(ambience,Rect2(0,0,1600,900))
	landscape_panel = ColorRect.new()
	landscape_panel.color = T.SURFACE
	landscape_panel.z_index = 200
	_put(landscape_panel,Rect2(0,0,1600,900))
	var orientation = _label(Brand.display_name()+"\n\nBitte das Gerät\nins Querformat drehen",22)
	orientation.set_meta("screen_label",true)
	landscape_panel.add_child(orientation)
	get_viewport().size_changed.connect(_update_orientation)
	_update_orientation()
	_apply_motion()
	if OS.has_feature("web"):
		qa_enabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"))

func _update_orientation() -> void:
	if not is_instance_valid(root_ui): return
	var available = get_viewport().get_visible_rect().size
	display_ratio = _display_density(available)
	var safe = _safe_rect(available)
	viewport_scale = minf(safe.size.x/1600.0,safe.size.y/900.0)
	ui_scale = viewport_scale/display_ratio
	canvas_width = maxf(1600,safe.size.x/viewport_scale)
	var extra_width = canvas_width-1600
	root_ui.size = Vector2(canvas_width,900)
	root_ui.scale = Vector2.ONE*viewport_scale
	root_ui.position = safe.position+(safe.size-Vector2(canvas_width,900)*viewport_scale)/2
	backdrop.size.x = canvas_width
	backdrop.modulate = Color(.50,.55,.62,1)
	composition = preload("res://scripts/arena_composition.gd").compose(canvas_width,ui_scale,layout_concept)
	for i in LANES:
		for pair in [[lane_buttons,composition.ally],[lane_faces,composition.ally],[foe_faces,composition.enemy],[foe_wells,composition.enemy],[path_labels,composition.paths]]:
			var control: Control = pair[0][i]
			var rect: Rect2 = pair[1][i]
			control.position = rect.position; control.size = rect.size
	for pair in [[brand_label,"title"],[help_button,"menu"],[hero_medallions[0],"player_hero"],[hero_medallions[1],"enemy_hero"],[hero_player,"player_hp"],[hero_enemy,"enemy_hp"],[owner_labels[0],"enemy_label"],[owner_labels[1],"player_label"],[round_label,"round"],[phase_label,"phase"],[energy_label,"energy"],[energy_gems,"energy_label"],[detail_button,"details"],[end_button,"end"],[restart_button,"end"],[status_label,"status"],[info_label,"info"],[message_label,"message"],[hand_row,"hand"],[deck_back,"deck"],[deck_label,"deck_count"]]:
		var control: Control = pair[0]
		var rect: Rect2 = composition[pair[1]]
		control.position = rect.position; control.size = rect.size
	stage.size = Vector2(canvas_width,900)
	stage.layout = composition
	stage.concept = layout_concept
	stage.queue_redraw()
	hud_art.position = Vector2.ZERO
	hud_art.size = Vector2(canvas_width,900)
	hud_art.energy_rect = composition.energy
	hud_art.queue_redraw()
	landscape_panel.top_level = true
	landscape_panel.position = Vector2.ZERO
	landscape_panel.size = available
	landscape_panel.get_child(0).size = available
	landscape_panel.visible = available.y > available.x
	root_ui.theme.set_font_size("font_size","TooltipLabel",T.font_size(24,ui_scale,12))
	for label in labels:
		if not is_instance_valid(label) or label.has_meta("screen_label"): continue
		label.add_theme_font_size_override("font_size",T.font_size(int(label.get_meta("base_font")),ui_scale,float(label.get_meta("min_css"))))
	for button in actions:
		if not is_instance_valid(button): continue
		button.view_scale = ui_scale
		button.queue_redraw()
	status_label.text = "Serie %d/2" % streak
	info_label.visible = not message_label.visible and selected >= 0 and not finished
	for item in card_buttons+lane_faces+foe_faces+hero_medallions+lane_buttons+foe_wells:
		item.view_scale = ui_scale
		item.queue_redraw()
	_fan_hand()
	if modal != null: _layout_modal()

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.visible = false
		modal.queue_free()
	modal = null
	modal_kind = ""
	modal_actions.clear()

func _modal_shell() -> Control:
	_close_modal()
	modal = Control.new()
	modal.z_index = 100
	_put(modal,Rect2(0,0,canvas_width,900))
	var shade = Button.new()
	var shade_style = T.panel(Color.TRANSPARENT,Color(0,0,0,.76))
	for state in ["normal","hover","pressed","focus","disabled"]: shade.add_theme_stylebox_override(state,shade_style)
	shade.pressed.connect(_close_modal)
	_put(shade,Rect2(0,0,canvas_width,900),modal)
	var sheet = Panel.new()
	var material = T.panel(T.BRONZE,T.SURFACE)
	material.shadow_color = Color(0,0,0,.7)
	material.shadow_size = 24
	material.shadow_offset = Vector2(0,10)
	material.set_corner_radius_all(12)
	sheet.add_theme_stylebox_override("panel",material)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_put(sheet,Rect2(200,30,1200,864),modal)
	return modal

func _show_help() -> void:
	var panel = _modal_shell()
	modal_kind = "help"
	var text = _label("SO SPIELST DU\n1. Handkarte antippen.\n2. ✓-Ziel: Kreaturen unten, Zauber oben.\n3. Zug beenden. Du greifst zuerst an.\nDann reagiert der Gegner.\nSieg: Gegner auf 0 Leben ODER\n3 freie Pfade zweimal halten.\nMax. 2 Beschwörungen/Runde; 6 Handkarten.\nKarte erneut antippen: Details.\nSechseck: Kosten · Schrägform: Angriff\nSchild: Leben · max. 10 Energie.",30)
	text.set_meta("min_css",14.0)
	_put(text,Rect2(250,80,1100,645),panel)
	_action_in_modal("ZURÜCK",Rect2(570,755,460,110))
	_layout_modal()

func _action_in_modal(value: String, rect: Rect2, callback: Callable = Callable()) -> void:
	var button = _action(value,rect,callback if callback.is_valid() else _close_modal)
	root_ui.remove_child(button)
	modal.add_child(button)
	modal_actions.append(button)

func _show_card() -> void:
	if selected < 0 or selected >= hand.size(): return
	_show_data_card(CARD_POOL[int(hand[selected])],int(hand[selected]),"hand")

var previous_hand_count := 0

func _display_density(available: Vector2) -> float:
	if OS.has_feature("web"):
		var width = float(JavaScriptBridge.eval("document.querySelector('canvas').getBoundingClientRect().width"))
		if width > 0: return maxf(1,available.x/width)
	if OS.has_feature("android") or OS.has_feature("ios"):
		return maxf(1,DisplayServer.screen_get_dpi()/160.0)
	return 1.0

func _safe_rect(available: Vector2) -> Rect2:
	if safe_override.size != Vector2.ZERO: return safe_override
	if OS.has_feature("web"):
		var data = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.nachtsiegelInsets ? window.nachtsiegelInsets() : {})")))
		if data is Dictionary:
			var left = float(data.get("left",0))*display_ratio
			var top = float(data.get("top",0))*display_ratio
			return Rect2(left,top,maxf(1,available.x-left-float(data.get("right",0))*display_ratio),maxf(1,available.y-top-float(data.get("bottom",0))*display_ratio))
	if OS.has_feature("android") or OS.has_feature("ios"):
		var display = DisplayServer.screen_get_size()
		var safe = DisplayServer.get_display_safe_area()
		if safe.size.x > 0 and display.x > 0:
			var ratio = available/Vector2(display)
			return Rect2(Vector2(safe.position)*ratio,Vector2(safe.size)*ratio)
	return Rect2(Vector2.ZERO,available)

func _load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load("user://ux.cfg") == OK:
		reduced_motion = bool(config.get_value("accessibility","reduced_motion",false))
		onboarding_step = 3 if bool(config.get_value("ux","learned",false)) else 0
	elif OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches"))
func _save_preferences() -> void:
	var config = ConfigFile.new()
	config.set_value("accessibility","reduced_motion",reduced_motion)
	config.set_value("ux","learned",onboarding_step >= 3)
	config.save("user://ux.cfg")
func _set_reduced_motion(enabled: bool, persist: bool = true) -> void:
	reduced_motion = enabled
	_apply_motion()
	if persist:
		_save_preferences()
		preferences_updated.emit(reduced_motion)
func _apply_motion() -> void:
	if not is_instance_valid(ambience): return
	ambience.reduced_motion = reduced_motion
	backdrop.material.set_shader_parameter("reduced_motion",reduced_motion)
	for slot in lane_buttons+foe_wells: slot.reduced_motion = reduced_motion
func _toggle_motion() -> void:
	_set_reduced_motion(not reduced_motion)
	_show_menu()
func _show_menu() -> void:
	var panel = _modal_shell()
	modal_kind = "menu"
	if managed_session:
		var heading = _label("DUELLMENÜ",40)
		_put(heading,Rect2(400,64,800,70),panel)
		_action_in_modal("WEITERSPIELEN",Rect2(460,170,680,110))
		_action_in_modal("SPIELHILFE",Rect2(460,305,680,110),_show_help)
		_action_in_modal("BEWEGUNG: REDUZIERT" if reduced_motion else "BEWEGUNG: NORMAL",Rect2(460,440,680,110),_toggle_motion)
		_action_in_modal("HAUPTMENÜ",Rect2(460,742,680,110),_show_leave_confirmation)
		_layout_modal()
		return
	var title = _label("MENÜ · %d Karten" % deck.size(),40)
	title.set_meta("min_css",18.0)
	_put(title,Rect2(400,64,800,70),panel)
	_action_in_modal("SPIELHILFE",Rect2(460,170,680,110),_show_help)
	_action_in_modal("BEWEGUNG: REDUZIERT" if reduced_motion else "BEWEGUNG: NORMAL",Rect2(460,305,680,110),_toggle_motion)
	_action_in_modal("VOLLBILD",Rect2(460,440,680,110),_fullscreen)
	var hint = _label("Vollbild auf dem iPhone: Teilen → Zum Home-Bildschirm.",27)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(hint,Rect2(310,580,980,95),panel)
	_action_in_modal("ZURÜCK",Rect2(460,742,680,110))
	_layout_modal()
func _fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(document.fullscreenElement){document.exitFullscreen()}else if(document.documentElement.requestFullscreen){document.documentElement.requestFullscreen().catch(()=>{})}")
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_close_modal()
func _show_data_card(data: Dictionary, index: int, origin: String) -> void:
	var panel = _modal_shell()
	modal_kind = "card"
	var card = CardFace.new()
	card.data = data
	card.art = _art(index)
	card.view_scale = ui_scale
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(card,Rect2(335,105,360,510),panel)
	var stats = "ANG %d   LEBEN %d" % [data.attack,data.hp] if data.kind == "unit" else "%d Zauberschaden" % data.attack
	var rule = "Eigenes freies Feld.\nMax. 2 / Runde." if data.kind == "unit" else "Kreatur oben treffen.\nKein Held als Ziel."
	var state = "Duell beendet" if origin == "ended" else ("Energie fehlt" if int(data.cost) > energy and origin == "hand" else ("Gegner" if origin == "enemy" else ("Deine Kreatur" if origin == "ally" else "Ausspielbar")))
	var title = _label(str(data.name),34)
	title.set_meta("min_css",16.0)
	_put(title,Rect2(735,100,550,85),panel)
	var kind = _label("%s · %d Energie" % ["KREATUR" if data.kind == "unit" else "ZAUBER",data.cost],30)
	kind.set_meta("min_css",14.0)
	_put(kind,Rect2(735,200,550,70),panel)
	var values = _label(stats,30)
	values.set_meta("min_css",14.0)
	_put(values,Rect2(735,282,550,70),panel)
	var description = _label(rule,30)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.set_meta("min_css",14.0)
	_put(description,Rect2(735,364,550,150),panel)
	var status = _label(state,30)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.set_meta("min_css",14.0)
	status.add_theme_color_override("font_color",T.WARNING if energy < int(data.cost) and origin == "hand" else T.SECONDARY)
	_put(status,Rect2(735,526,550,90),panel)
	var concept = _label("KI-Konzeptillustration",26)
	_put(concept,Rect2(335,640,950,55),panel)
	if origin == "hand":
		_action_in_modal("ABWÄHLEN",Rect2(330,745,410,110),_cancel_selection)
	_action_in_modal("ZIEL WÄHLEN" if origin == "hand" else "ZURÜCK",Rect2(820,745,450,110))
	_layout_modal()
func _show_hero(enemy: bool) -> void:
	var panel = _modal_shell()
	modal_kind = "hero"
	var text = _label("%s\n\n%d von 35 Leben\n\nUnblockierte Kreaturenangriffe treffen den Helden.\nAuf 0 Leben endet das Duell.\n\nKonzeptporträt" % [(opponent_title+" · Gegner") if enemy else (player_title+" · Dein Held"),foe_hp if enemy else player_hp],32)
	text.set_meta("min_css",14.0)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(text,Rect2(300,150,1000,520),panel)
	_action_in_modal("ZURÜCK",Rect2(570,755,460,110))
	_layout_modal()
func _layout_modal() -> void:
	modal.size.x = canvas_width
	modal.get_child(0).size.x = canvas_width
	for child in modal.get_children():
		if child.has_meta("base_rect") and child != modal.get_child(0):
			var base: Rect2 = child.get_meta("base_rect")
			child.position.x = base.position.x+(canvas_width-1600)/2
		if child is Label:
			child.add_theme_font_size_override("font_size",T.font_size(int(child.get_meta("base_font")),ui_scale,float(child.get_meta("min_css"))))
		elif child is CardFace: child.view_scale = ui_scale; child.queue_redraw()
	for button in modal_actions:
		button.view_scale = ui_scale
		button.size.y = maxf(110,ceil(44.0/ui_scale))
		button.queue_redraw()
	if modal_kind == "menu" and modal_actions.size() == 4:
		var height = maxf(110,ceil(44.0/ui_scale))
		for i in 3: modal_actions[i].position.y = 150+i*(height+12)
		modal_actions[3].position.y = 900-height-15
		for child in modal.get_children():
			if child is Label and child.has_meta("base_rect"):
				var base: Rect2 = child.get_meta("base_rect")
				if base.position.y == 580: child.position.y = 150+3*(height+12); child.size.y = 95
func _cancel_selection() -> void:
	selected = -1
	_close_modal()
	_refresh()
	_announce("Auswahl aufgehoben")
func _board_tap(lane: int, enemy: bool) -> void:
	if busy: _announce("Kampf läuft – bitte kurz warten", "warning"); return
	if finished:
		var unit = foes[lane] if enemy else allies[lane]
		if unit != null: _show_data_card(unit,_card_index(unit),"enemy" if enemy else "ally")
		return
	if selected < 0:
		var unit = foes[lane] if enemy else allies[lane]
		if unit != null: _show_data_card(unit,_card_index(unit),"enemy" if enemy else "ally")
		else: _announce("Wähle zuerst eine Handkarte", "warning")
		return
	var data: Dictionary = CARD_POOL[int(hand[selected])]
	if data.kind == "unit" and enemy:
		_announce("Wähle ein eigenes Feld unten", "warning")
		return
	if data.kind == "spell" and not enemy:
		_announce("Zauber: Kreatur oben wählen", "warning")
		return
	_choose_lane(lane)
func _restart() -> void:
	if managed_session: retry_requested.emit()
	else: get_tree().call_deferred("reload_current_scene")
func _show_result(value: String) -> void:
	if not finished: return
	var panel = _modal_shell()
	modal_kind = "result"
	var title = _label("SIEG" if value.begins_with("SIEG") else "NIEDERLAGE",52)
	title.set_meta("min_css",24.0)
	title.add_theme_color_override("font_color",T.SUCCESS if value.begins_with("SIEG") else T.DANGER)
	_put(title,Rect2(400,200,800,100),panel)
	var text = _label(value.get_slice("·",1).strip_edges()+(("\n"+result_summary) if managed_session else ""),32)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(text,Rect2(350,330,900,170),panel)
	if managed_session:
		_action_in_modal("HAUPTMENÜ",Rect2(350,650,420,110),func(): main_menu_requested.emit())
		_action_in_modal("WEITER" if value.begins_with("SIEG") else "NOCHMAL",Rect2(830,650,420,110),func(): continue_requested.emit() if value.begins_with("SIEG") else retry_requested.emit())
	else:
		_action_in_modal("WEITER ANSEHEN",Rect2(350,650,420,110))
		_action_in_modal("NEUES DUELL",Rect2(830,650,420,110),_restart)
	_layout_modal()
func _show_leave_confirmation() -> void:
	var panel = _modal_shell()
	modal_kind = "leave"
	var text = _label("Zum Hauptmenü?\nEin laufendes Duell wird nicht gespeichert.\nDein bisheriger Fortschritt bleibt erhalten.",30)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(text,Rect2(300,220,1000,300),panel)
	_action_in_modal("WEITERSPIELEN",Rect2(330,680,450,110))
	_action_in_modal("VERLASSEN",Rect2(820,680,450,110),func(): main_menu_requested.emit())
	_layout_modal()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if modal != null: _close_modal()
		elif selected >= 0: _cancel_selection()
		else: _show_menu()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if notification_clock > 0:
		notification_clock -= delta
		if notification_clock <= 0 and onboarding_step >= 3 and not busy:
			message_label.visible = false
			info_label.visible = selected >= 0 and not finished
	if qa_enabled:
		qa_clock += delta
		if qa_clock >= .1:
			qa_clock = 0
			_publish_qa()
func _publish_qa() -> void:
	if not OS.has_feature("web") or card_buttons.size() != hand.size(): return
	var result = {"round":round_number,"energy":energy,"finished":finished,"summons":summons,"allies":allies,"enemies":foes,"selected":selected,"busy":busy,"phase":phase,"modal":modal_kind,"reduced_motion":reduced_motion,"onboarding":onboarding_step,"player_hp":player_hp,"foe_hp":foe_hp,"scale":ui_scale,"density":display_ratio,"cards":[],"targets":[],"foes":[],"actions":{},"text_css":{"energy":energy_label.get_theme_font_size("font_size")*ui_scale,"phase":phase_label.get_theme_font_size("font_size")*ui_scale,"focus":info_label.get_theme_font_size("font_size")*ui_scale,"values":T.font_size(30,ui_scale,12)*ui_scale}}
	for i in card_buttons.size():
		var rect = card_buttons[i].get_global_rect()
		var data: Dictionary = CARD_POOL[int(hand[i])]
		result.cards.append({"index":i,"name":data.name,"kind":data.kind,"cost":data.cost,"attack":data.attack,"hp":data.hp,"rect":[rect.position.x/display_ratio,rect.position.y/display_ratio,rect.size.x/display_ratio,rect.size.y/display_ratio]})
	for list in [[lane_buttons,"targets"],[foe_faces,"foes"]]:
		for i in LANES:
			var rect = list[0][i].get_global_rect()
			result[list[1]].append({"index":i,"visible":list[0][i].visible,"rect":[rect.position.x/display_ratio,rect.position.y/display_ratio,rect.size.x/display_ratio,rect.size.y/display_ratio]})
	for pair in [[end_button,"end"],[detail_button,"details"],[help_button,"menu"]]:
		var rect = pair[0].get_global_rect()
		result.actions[pair[1]] = [rect.position.x/display_ratio,rect.position.y/display_ratio,rect.size.x/display_ratio,rect.size.y/display_ratio]
	result.modal_actions = []
	for button in modal_actions:
		var rect = button.get_global_rect()
		result.modal_actions.append({"caption":button.caption,"rect":[rect.position.x/display_ratio,rect.position.y/display_ratio,rect.size.x/display_ratio,rect.size.y/display_ratio]})
	JavaScriptBridge.eval("window.nachtsiegelQA="+JSON.stringify(result),true)

func _draw_card() -> void: battle.draw_card()

func _card_button(index:int) -> Button:
	var data: Dictionary = CARD_POOL[int(hand[index])]
	var button = CardFace.new()
	button.size = Vector2(T.HAND_WIDTH,T.HAND_HEIGHT)
	button.pivot_offset = Vector2(T.HAND_WIDTH/2,T.HAND_HEIGHT)
	button.data = data
	button.art = _art(int(hand[index]))
	button.active = not finished and index == selected
	button.playable = not finished and energy >= int(data.cost) and (data.kind == "spell" or summons < 2)
	button.view_scale = ui_scale
	button.disabled = busy
	button.unaffordable = not finished and energy < int(data["cost"])
	button.pressed.connect(_select_card.bind(index))
	card_buttons.append(button)
	return button

func _refresh() -> void:
	if status_label == null: return
	deck_label.text = str(deck.size())
	hero_player.text = str(player_hp)
	hero_enemy.text = str(foe_hp)
	energy_label.text = str(energy)
	energy_gems.text = "ENERGIE"
	hud_art.energy = energy
	hud_art.queue_redraw()
	round_label.text = "RUNDE %02d" % round_number
	status_label.text = "Serie %d/2" % streak if ui_scale < .33 else "%d/2 Serien\n%d Karten" % [streak,deck.size()]
	phase_label.text = "BEENDET" if finished else ("GEGNER" if phase == "enemy" else ("KAMPF" if busy else "DEIN ZUG"))
	phase_label.add_theme_color_override("font_color",T.WARNING if busy else T.PLAYER)
	if not finished and modal_kind == "result": _close_modal()
	var selection: Dictionary = CARD_POOL[int(hand[selected])] if not finished and selected >= 0 and selected < hand.size() else {}
	for i in LANES:
		for pair in [[allies,lane_faces],[foes,foe_faces]]:
			var unit = pair[0][i]
			var face = pair[1][i]
			face.visible = unit != null
			if unit != null:
				face.data = unit
				face.art = _art(_card_index(unit))
				face.active = false
				face.target_state = "none"
				if not selection.is_empty():
					face.target_state = "valid" if selection.kind == "spell" and pair[1] == foe_faces and energy >= int(selection.cost) else "invalid"
				face.queue_redraw()
		lane_buttons[i].disabled = finished or busy
		lane_faces[i].disabled = busy
		foe_faces[i].disabled = busy
		var legal = not selection.is_empty() and selection.kind == "unit" and allies[i] == null and summons < 2 and energy >= int(selection.cost)
		lane_buttons[i].legal = legal
		lane_buttons[i].choosing = not selection.is_empty()
		foe_wells[i].choosing = not selection.is_empty()
		lane_buttons[i].occupied = allies[i] != null
		lane_buttons[i].queue_redraw()
		foe_wells[i].occupied = foes[i] != null
		foe_wells[i].queue_redraw()
	for child in hand_row.get_children():
		hand_row.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	for i in hand.size(): hand_row.add_child(_card_button(i))
	_fan_hand()
	if hand.size() > previous_hand_count:
		call_deferred("_animate_draw")
	previous_hand_count = hand.size()
	end_button.disabled = busy or finished
	end_button.caption = "DUELL BEENDET" if finished else ("BITTE WARTEN" if busy else "ZUG BEENDEN")
	end_button.queue_redraw()
	restart_button.visible = finished
	status_label.visible = not finished
	restart_button.position = end_button.position
	detail_button.visible = not finished and selected >= 0
	if finished:
		info_label.text = ""
	elif selected >= 0 and selected < hand.size():
		var data: Dictionary = CARD_POOL[int(hand[selected])]
		info_label.text = data.name
	elif not finished:
		info_label.text = "Karte wählen" if onboarding_step < 3 else ""
	_update_orientation()

func _fan_hand() -> void:
	var count = card_buttons.size()
	var card_width = clampf((hand_row.size.x-56)/6,178,220)
	var extra = card_width*(T.SELECT_SCALE-1)+12 if selected >= 0 else 0.0
	var span = count*card_width+extra
	for i in count:
		var card: Control = card_buttons[i]
		card.size.x = card_width
		card.pivot_offset = Vector2(card_width/2,T.HAND_HEIGHT)
		var offset = float(i)-(count-1)*.5
		var spread = (extra/2 if i > selected else -extra/2) if selected >= 0 and i != selected else 0.0
		card.position = Vector2((hand_row.size.x-count*card_width)/2+i*card_width+spread,absf(offset)*2)
		card.rotation_degrees = offset*1.3
		card.scale = Vector2.ONE
		if i == selected:
			card.scale = Vector2.ONE*T.SELECT_SCALE
			card.position.y -= T.SELECT_LIFT
			card.rotation_degrees = 0
		card.z_index = 20 if i == selected else i

func _animate_draw() -> void:
	if reduced_motion or card_buttons.is_empty(): return
	var card: Control = card_buttons.back()
	var target = card.position
	card.position += Vector2(20,-20)
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card,"position",target,T.MOTION_DRAW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _card_index(data: Dictionary) -> int:
	for i in CARD_POOL.size():
		if CARD_POOL[i].name == data.name: return i
	return 0

func _pulse_lane(lane: int, spell: bool, source_point: Vector2 = Vector2(-1,-1)) -> void:
	var face: Control = foe_faces[lane] if spell else lane_faces[lane]
	var effect = RitualFx.new()
	effect.destination = face.position+face.size/2
	effect.origin = Vector2(canvas_width/2,780)
	if selected >= 0 and selected < card_buttons.size():
		var card: Control = card_buttons[selected]
		effect.origin = root_ui.get_global_transform().affine_inverse()*(card.get_global_transform()*(card.size/2))
		effect.tint = Color(str(CARD_POOL[int(hand[selected])].tint))
	if source_point.x >= 0: effect.origin = source_point
	effect.spell = spell
	effect.reduced_motion = reduced_motion
	if reduced_motion: effect.lifetime = .18
	_put(effect,Rect2(Vector2.ZERO,root_ui.size))
	effect.z_index = 4
	if face.visible and not reduced_motion:
		face.pivot_offset = face.size/2
		face.scale = Vector2.ONE*0.86
		face.create_tween().tween_property(face,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _turn_banner() -> void:
	phase = "play"
	phase_label.text = "DEIN ZUG"

func _announce(value: String, role: String = "secondary") -> void:
	if message_label == null: return
	feedback_role = role
	var color = T.SECONDARY
	if role == "warning": color = T.WARNING
	elif role == "success": color = T.SUCCESS
	elif role == "damage": color = T.DANGER
	message_label.text = ("! " if role == "warning" else ("✓ " if role == "success" else ""))+value
	message_label.add_theme_color_override("font_color",color)
	message_label.visible = true
	info_label.visible = false
	notification_clock = 3.0

func _select_card(index: int) -> void:
	if busy or index < 0 or index >= hand.size(): return
	if finished:
		_show_data_card(CARD_POOL[int(hand[index])],int(hand[index]),"ended")
		return
	if selected == index:
		_show_card()
		return
	selected = index
	onboarding_step = maxi(onboarding_step,1)
	var data: Dictionary = CARD_POOL[int(hand[index])]
	if energy < int(data.cost): _announce("Nicht genügend Energie", "warning")
	elif data.kind == "spell": _announce("Zauber: Kreatur oben wählen")
	elif summons >= 2: _announce("Limit: 2 Beschwörungen/Runde", "warning")
	elif onboarding_step < 2: _announce("2 · Wähle einen ✓-Pfad unten")
	else: _announce(data.name+" ausgewählt")
	_refresh.call_deferred()
	call_deferred("_lift_selection")

func _lift_selection() -> void:
	if reduced_motion or selected < 0 or selected >= card_buttons.size(): return
	var card: Control = card_buttons[selected]
	var target = card.position.y
	card.position.y += T.SELECT_LIFT
	card.scale = Vector2.ONE
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card,"position:y",target,T.MOTION_SELECT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card,"scale",Vector2.ONE*T.SELECT_SCALE,T.MOTION_SELECT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _choose_lane(lane: int) -> void:
	if busy: return
	var origin = Vector2(canvas_width/2,780)
	if selected >= 0 and selected < card_buttons.size():
		var card: Control = card_buttons[selected]
		origin = root_ui.get_global_transform().affine_inverse()*(card.get_global_transform()*(card.size/2))
	var outcome = battle.play(lane)
	if not outcome.ok:
		_announce(outcome.reason,"warning")
		return
	_pulse_lane(lane,outcome.spell,origin)
	_announce(outcome.message,"damage" if outcome.spell else "success")
	if onboarding_step < 2:
		onboarding_step = 2
		_announce("3 · Beende deinen Zug","success")
	_refresh.call_deferred()

func _combat_phase(attacker: Array, defender: Array, attacking_player: bool) -> void:
	battle.combat_phase(attacker,defender,attacking_player)

func _lunge(faces: Array, direction: float) -> void:
	if reduced_motion: return
	for face in faces:
		if not face.visible: continue
		var start: Vector2 = face.position
		var tween = face.create_tween()
		tween.tween_property(face,"position",start+Vector2(0,25*direction),T.MOTION_ATTACK/2)
		tween.tween_property(face,"position",start,T.MOTION_ATTACK/2)

func _end_turn() -> void:
	if finished or busy or Time.get_ticks_msec()-last_turn_click < 350: return
	last_turn_click = Time.get_ticks_msec()
	busy = true
	phase = "combat"
	if onboarding_step == 2:
		onboarding_step = 3
		_save_preferences()
	_refresh()
	_announce("Deine Kreaturen greifen an")
	_lunge(lane_faces,-1)
	await get_tree().create_timer(.06 if reduced_motion else .18).timeout
	phase = "enemy"
	phase_label.text = "GEGNER"
	_lunge(foe_faces,1)
	await get_tree().create_timer(.06 if reduced_motion else .22).timeout
	var previous_allies = allies.duplicate(true)
	var previous_foes = foes.duplicate(true)
	var previous_player = player_hp
	var previous_foe = foe_hp
	busy = false
	phase = "play"
	_resolve_turn()
	if not finished: _turn_banner()
	for pair in [[previous_allies,allies,lane_faces],[previous_foes,foes,foe_faces]]:
		for i in LANES:
			if pair[0][i] == null: continue
			if pair[1][i] == null and not reduced_motion:
				var ghost = _face(pair[0][i],Rect2(pair[2][i].position,pair[2][i].size),_card_index(pair[0][i]),true)
				ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ghost.ghost_display = true
				var fade = ghost.create_tween().set_parallel(true)
				fade.tween_property(ghost,"modulate:a",0.0,0.4)
				fade.tween_property(ghost,"position:y",ghost.position.y+28,0.4)
				fade.chain().tween_callback(ghost.queue_free)
			elif pair[1][i] != null and int(pair[1][i].hp) < int(pair[0][i].hp):
				_announce("%d Schaden · Pfad %d" % [int(pair[0][i].hp)-int(pair[1][i].hp),i+1], "damage")
	for pair in [[hero_player,previous_player-player_hp],[hero_enemy,previous_foe-foe_hp]]:
		if pair[1] > 0:
			var damage = _caption("−%d" % pair[1],Rect2(pair[0].position+Vector2(pair[0].size.x/2-82,-54),Vector2(164,48)),32,T.DANGER,true)
			damage.z_index = 8
			damage.add_to_group("damage_feedback")
			var feedback = damage.create_tween()
			if not reduced_motion: feedback.tween_property(damage,"position:y",damage.position.y-24,.65)
			else: feedback.tween_interval(.65)
			feedback.tween_callback(damage.queue_free)

func _resolve_turn() -> void:
	if finished: return
	battle.resolve_turn()
	if not battle.result.is_empty(): _finish(battle.result)
	else:
		_refresh()
		_announce("Runde %d · Dein Zug" % round_number,"success")

func _finish(value:String) -> void:
	finished = true
	phase = "finished"
	battle.result = value
	completed.emit(value.begins_with("SIEG"),value)
	info_label.text = value
	_refresh()
	_announce(value)
	_show_result.call_deferred(value)
