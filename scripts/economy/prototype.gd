extends Control
## Isolated local economy laboratory. Reward commits finish before presentation starts.
## Existing Alpha card face and shared card back are reused without modifying them.
signal audio_event(event_id: String)
const Manager = preload("res://scripts/economy/economy_manager.gd")
const CardView = preload("res://scripts/alpha/card_view.gd")
const CardBack = preload("res://scripts/card_back.gd")
const T = preload("res://scripts/ui_tokens.gd")
const Style = preload("res://scripts/alpha/style.gd")
var economy
var save_path := "user://orafold_economy_sandbox_v2.json"
var actions: Dictionary = {}
var reduced_motion := false
var message := "Vier Starterdecks sind kostenlos. Alle Laborwerte sind vorläufig."
var selected_card := ""
var selection_rarity := "rare"
var modal: Control
var reveal_cards: Array = []
var revealed: Dictionary = {}
var reveal_views: Array = []
var body: VBoxContainer
var scroll: ScrollContainer
var last_width := -1
var reveal_transaction := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if economy == null: economy = Manager.new(save_path)
	var palette = Theme.new()
	palette.default_font = T.FONT
	palette.default_font_size = 16
	palette.set_color("font_color", "Label", T.TEXT)
	palette.set_color("font_color", "Button", T.TEXT)
	palette.set_color("font_disabled_color", "Button", T.MUTED)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		palette.set_stylebox(state_name, "Button", T.panel(T.GOLD if state_name == "focus" else T.METAL, T.SURFACE_RAISED if state_name in ["hover", "pressed"] else T.SURFACE))
	theme = palette
	resized.connect(_on_resize)
	render()

func _on_resize() -> void:
	if is_inside_tree() and abs(int(size.x) - last_width) > 10:
		render()
		if not reveal_cards.is_empty(): show_reveal()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), T.INK)
	for i in range(6):
		draw_line(Vector2(size.x * .8 + i * 46, 0), Vector2(size.x * .2 + i * 46, size.y), Color(T.GOLD, .025), 1)

func _tx(prefix: String) -> String:
	return prefix + ":" + Crypto.new().generate_random_bytes(16).hex_encode()

func _box(parent: Node, gap: int = 12) -> VBoxContainer:
	var result = VBoxContainer.new()
	result.add_theme_constant_override("separation", gap)
	parent.add_child(result)
	return result

func _row(parent: Node) -> HBoxContainer:
	var result = HBoxContainer.new()
	result.add_theme_constant_override("separation", 12)
	parent.add_child(result)
	return result

func _label(value: String, parent: Node, fs: int = 16, tint: Color = T.TEXT) -> Label:
	var result = Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", fs)
	result.add_theme_color_override("font_color", tint)
	parent.add_child(result)
	return result

func _button(id: String, value: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var result = Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(0, 50)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.disabled = disabled
	# Rendering replaces controls; defer callbacks until the originating signal ends.
	result.pressed.connect(callback, CONNECT_DEFERRED)
	parent.add_child(result)
	actions[id] = result
	return result

func _panel(parent: Node, edge: Color = T.METAL) -> VBoxContainer:
	var frame = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = T.panel(edge, T.SURFACE)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	return _box(frame)

func render() -> void:
	last_width = int(size.x)
	if is_instance_valid(scroll): scroll.free()
	actions.clear()
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12 if size.x < 600 else 28)
	scroll.add_child(margin)
	body = _box(margin, 18)
	_label("ORAFOLD", body, 32, T.GOLD).add_theme_font_override("font", T.DISPLAY)
	_label("DAS SAMMLUNGSARCHIV", body, 13, T.PLAYER)
	_label("LOKALES TESTLABOR · VORLÄUFIG · KEINE KÄUFE", body, 12, T.WARNING)
	_label("550 Modellkarten · nicht im Hauptspiel verwendbar", body, 13, T.SECONDARY)
	var wallet = economy.state.get("wallet", {})
	var progression = economy.state.get("progression", {})
	var balances = _row(body)
	for balance in [["GOLD", str(wallet.get("gold", 0)), T.GOLD], ["ESSENZ", str(wallet.get("crafting", 0)), T.PLAYER], ["LEVEL", str(progression.get("level", 1)), T.TEXT]]:
		var cell = _panel(balances, balance[2])
		_label(balance[0], cell, 12, T.SECONDARY)
		_label(balance[1], cell, 25, balance[2])
	var progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	var level = int(progression.get("level", 1))
	var curve = economy.config.get("progression", {}).get("xp_curve", {})
	var base_xp = int(curve.get("base", 100))
	var step_xp = int(curve.get("per_level", 25))
	var spent = (level - 1) * base_xp + ((level - 1) * (level - 2) / 2) * step_xp
	progress.max_value = base_xp + (level - 1) * step_xp
	progress.value = maxf(0, int(progression.get("xp", 0)) - spent)
	body.add_child(progress)
	_label("%d Erfahrung · Fortschritt wird lokal gespeichert" % int(progression.get("xp", 0)), body, 12, T.SECONDARY)
	var notice = _panel(body, T.PLAYER)
	_label(message if economy.ready else "Wirtschaft gesperrt: " + str(economy.last_error), notice, 14, T.PLAYER if economy.ready else T.DANGER)
	var starter_actions = _box(body) if size.x < 600 else _row(body)
	_button("starters", "Vier Starterdecks sichern", starter_actions, _claim_starters, not economy.ready)
	_button("welcome", "Einmaliges Willkommenspaket", starter_actions, _claim_welcome, not economy.ready)
	var booster = _panel(body, T.GOLD)
	_label("DAS ERSTE SIEGEL", booster, 23, T.GOLD).add_theme_font_override("font", T.DISPLAY)
	_label("Standardbooster · %d Karten · mindestens selten" % int(economy.config.get("booster_rules", {}).get("cards_per_booster", 0)), booster, 15)
	var center = CenterContainer.new()
	booster.add_child(center)
	var pack = Control.new()
	pack.custom_minimum_size = Vector2(142, 188)
	center.add_child(pack)
	var back = CardBack.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pack.add_child(back)
	_label("Ein versiegelter Fund für deine Sammlung", booster, 14, T.SECONDARY)
	var pool = economy.config.get("booster_pools", {}).get("pools", {}).get("standard", {})
	var price = int(pool.get("price_gold", 0))
	var available = int(economy.state.get("boosters", {}).get("standard", 0))
	var pack_actions = _box(booster) if size.x < 600 else _row(booster)
	_button("buy", "Booster · %d Gold" % price, pack_actions, _buy_booster, not economy.ready or int(wallet.get("gold", 0)) < price)
	_button("open", "Öffnen · %d bereit" % available, pack_actions, _open_booster, not economy.ready or available == 0)
	_button("odds", "Wahrscheinlichkeiten & Schutz", booster, _show_odds)
	var motion = CheckButton.new()
	motion.text = "Bewegung reduzieren"
	motion.custom_minimum_size.y = 50
	motion.button_pressed = reduced_motion
	motion.toggled.connect(func(value): reduced_motion = value)
	booster.add_child(motion)
	actions.motion = motion
	_progression_panel()
	_collection_panel()
	_label("Lokale Bestände sind ungesicherte Testdaten. Kein Handel, keine Echtgeldkäufe. Starter- und hergestellte Karten bleiben gebunden; Essenz ist nur für Herstellung bestimmt.", body, 12, T.SECONDARY)
	queue_redraw()

func _handle(result: Dictionary, success_message: String) -> void:
	message = success_message if result.get("ok", false) else "Nicht ausgeführt: " + str(result.get("code", economy.last_error))
	if result.get("ok", false): audio_event.emit("reward.claim")
	render()

func _claim_starters() -> void:
	_handle(economy.grant_starters("starter:v1"), "Vier vollständige Starterdecks wurden als gebundene Kopien gesichert.")

func _claim_welcome() -> void:
	_handle(economy.claim_reward("welcome:v1", "onboarding"), "Willkommenspaket gesichert. Wiederholtes Tippen vergibt es nur einmal.")

func _buy_booster() -> void:
	_handle(economy.buy_booster(_tx("buy")), "Standardbooster liegt bereit.")

func _progression_panel() -> void:
	var panel = _panel(body, T.PLAYER)
	_label("DEIN FORTSCHRITT", panel, 23, T.PLAYER).add_theme_font_override("font", T.DISPLAY)
	_label("Unabhängiges Testereignis: Diese Schaltfläche meldet eine abgeschlossene Modellpartie. Sie ist kein Kampf und wird später durch einen geprüften Ereignisadapter ersetzt.", panel, 13, T.SECONDARY)
	_button("test_match", "Testpartie abschließen", panel, _test_match, not economy.ready)
	var quests = economy.state.get("quests", {})
	var day = int(Time.get_unix_time_from_system() / 86400)
	for id in economy.config.get("quests", {}).get("definitions", {}):
		var definition: Dictionary = economy.config.quests.definitions[id]
		var period = day if definition.period == "daily" else int(day / 7)
		var entry: Dictionary = quests.get(str(id) + ":" + str(period), {})
		var count = int(entry.get("count", 0))
		var completed = entry.get("claimed", false)
		var title: String = {"daily_play": "Täglich: Partien", "daily_variety": "Optional: Karten spielen", "weekly_play": "Wöchentlich: Partien"}.get(id, id)
		_label("%s · %d/%d%s" % [title, mini(count, int(definition.target)), int(definition.target), " · Belohnung gesichert" if completed else ""], panel, 14, T.PLAYER if completed else T.SECONDARY)

func _test_match() -> void:
	var source = _tx("lab-match")
	var day = int(Time.get_unix_time_from_system() / 86400)
	_handle(economy.record_activity(_tx("activity"), {"type": "match_completed", "day": day, "source_id": source, "amount": 1}), "Testpartie gespeichert. Erfahrung, Goldgrenzen und Aufgabenfortschritt wurden ausgewertet.")

func _open_booster() -> void:
	# State and all rewards are committed by the manager before visual controls exist.
	reveal_transaction = _tx("open")
	var result: Dictionary = economy.open_booster(reveal_transaction)
	if not result.get("ok", false): _handle(result, ""); return
	reveal_cards = result.get("cards", []).duplicate(true)
	revealed.clear()
	message = "Boosterinhalt ist gespeichert. Du kannst die Enthüllung jederzeit schließen."
	render()
	audio_event.emit("booster.open")
	show_reveal()

func _collection_panel() -> void:
	var panel = _panel(body, T.PLAYER)
	_label("DEIN ARCHIV", panel, 23, T.PLAYER).add_theme_font_override("font", T.DISPLAY)
	var unique = 0
	var copies = 0
	for entry in economy.state.get("collection", {}).values():
		var count = int(entry.get("count", 0))
		if count > 0: unique += 1; copies += count
	_label("%d / %d Kartenarten · %d spielbare Kopien" % [unique, economy.catalog.size(), copies], panel)
	_label("Herstellung ergänzt Booster. Starter- und hergestellte Kopien sind gebunden und lassen sich nicht verwerten.", panel, 13, T.SECONDARY)
	var rarity_selector = OptionButton.new()
	rarity_selector.custom_minimum_size.y = 50
	var rarity_names = ["common", "rare", "epic", "legendary"]
	for rarity in rarity_names: rarity_selector.add_item(Style.RARITIES.get(rarity, rarity))
	rarity_selector.select(maxi(0, rarity_names.find(selection_rarity)))
	rarity_selector.item_selected.connect(func(index): selection_rarity = rarity_names[index]; selected_card = ""; render(), CONNECT_DEFERRED)
	panel.add_child(rarity_selector)
	actions.rarity = rarity_selector
	var choices = OptionButton.new()
	choices.custom_minimum_size.y = 50
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.fit_to_longest_item = false
	var ids: Array = []
	for id in economy.catalog:
		if economy.catalog[id].get("rarity", "common") == selection_rarity: ids.append(id)
	ids.sort()
	if not ids.has(selected_card): selected_card = str(ids[0]) if not ids.is_empty() else ""
	for id in ids:
		var entry = economy.state.get("collection", {}).get(id, {})
		choices.add_item("%s · %d×" % [economy.catalog[id].get("name", id), int(entry.get("count", 0))])
	choices.select(maxi(0, ids.find(selected_card)))
	choices.item_selected.connect(func(index): selected_card = ids[index]; render(), CONNECT_DEFERRED)
	panel.add_child(choices)
	actions.card_selector = choices
	if not selected_card.is_empty():
		var entry = economy.state.get("collection", {}).get(selected_card, {})
		var card = economy.catalog[selected_card]
		var costs = economy.config.get("crafting", {}).get("costs", {})
		var returns = economy.config.get("crafting", {}).get("salvage", {})
		_label("%s · %d vorhanden · %d gebunden" % [card.get("name", selected_card), int(entry.get("count", 0)), int(entry.get("bound", 0))], panel, 14)
		var row = _box(panel) if size.x < 600 else _row(panel)
		_button("craft", "Herstellen · %d Essenz" % int(costs.get(selection_rarity, 0)), row, _craft, not economy.ready)
		_button("salvage", "Verwerten · +%d Essenz" % int(returns.get(selection_rarity, 0)), row, _confirm_salvage, not economy.ready or int(entry.get("count", 0)) <= int(entry.get("bound", 0)))

func _craft() -> void:
	_handle(economy.craft(_tx("craft"), selected_card), "Karte hergestellt und gespeichert.")

func _confirm_salvage() -> void:
	var id = selected_card
	var panel = _modal("Karte wirklich verwerten?")
	_label("Eine ungebundene Kopie von „%s“ wird dauerhaft in Essenz umgewandelt. Prüfe, ob du sie für ein Deck brauchst." % economy.catalog[id].get("name", id), panel)
	_button("confirm_salvage", "Eine Kopie verwerten", panel, func(): close_modal(); _handle(economy.salvage(_tx("salvage"), id, true), "Eine ungebundene Kopie wurde verwertet."))
	_button("cancel_salvage", "Abbrechen · Karte behalten", panel, close_modal)

func _modal(title: String) -> VBoxContainer:
	close_modal()
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, .94)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var scroller = ScrollContainer.new()
	scroller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroller)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16 if size.x < 600 else 48)
	scroller.add_child(margin)
	var panel = _panel(margin, T.GOLD)
	_label(title, panel, 23, T.GOLD)
	_button("modal_close", "Schließen", panel, close_modal)
	return panel

func close_modal() -> void:
	if is_instance_valid(modal): modal.free()
	modal = null
	# No grants, refunds, rerolls or model mutation from close/skip/reveal handlers.

func _show_odds() -> void:
	var panel = _modal("Transparente Boosterregeln")
	var rules = economy.config.get("booster_rules", {})
	for slot in rules.get("slots", []):
		var lines: PackedStringArray = []
		for rarity in ["common", "rare", "epic", "legendary"]:
			lines.append("%s %.2f %%" % [Style.RARITIES[rarity], float(slot.get("rates", {}).get(rarity, 0)) * 100])
		_label("%d Kartenplatz/-plätze:\n%s" % [int(slot.get("count", 0)), " · ".join(lines)], panel, 15)
	var pity = rules.get("pity", {})
	_label("Pechschutz: spätestens Booster %d ohne epischen oder legendären Fund enthält Episch+. Spätestens Booster %d ohne legendären Fund enthält Legendär. Höhere Funde setzen die passenden Zähler zurück." % [int(pity.get("epic", 0)), int(pity.get("legendary", 0))], panel, 15)
	_label("Epische und legendäre Funde bevorzugen Karten unter dem spielbaren Kopienlimit. Sind alle Karten einer Seltenheit vollständig, wird Überbestand in Essenz umgewandelt. Die Werte sind vorläufig und werden simuliert.", panel, 15)
	_label("Modellkatalog: Wirtschaftstestdaten mit allen vier Seltenheiten. Der aktive Alpha-Katalog enthält aktuell keine epischen Karten und wird durch dieses Labor nicht verändert.", panel, 13, T.WARNING)

func show_reveal() -> void:
	var panel = _modal("DEIN FUND IST GESICHERT")
	_label("Tippe auf eine Karte, um sie zu enthüllen. Auch übersprungene oder geschlossene Funde bleiben in deiner Sammlung.", panel, 14, T.SECONDARY)
	var grid = GridContainer.new()
	grid.columns = 2 if size.x < 600 else 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	reveal_views.clear()
	for index in reveal_cards.size():
		var holder = _box(grid, 6)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var view = Control.new()
		view.custom_minimum_size = Vector2(minf(128, (size.x - 80) / 2.0) if size.x < 600 else 128, 188)
		holder.add_child(view)
		var label = _label("Versiegelt", holder, 12, T.SECONDARY)
		var hit = _button("reveal_" + str(index), "Enthüllen", holder, _reveal.bind(index))
		reveal_views.append({"view": view, "label": label, "button": hit})
		if revealed.has(index): _paint_revealed(index)
		else:
			var back = CardBack.new()
			back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			view.add_child(back)
	_button("skip", "Alle enthüllen · Überspringen", panel, _skip)
	var converted = 0
	for card in reveal_cards: converted += int(card.get("converted", 0))
	_label("%d Kartenplätze · +%d Essenz aus Überbestand" % [reveal_cards.size(), converted], panel, 15, T.PLAYER)
	_button("reveal_done", "Zur Sammlung", panel, func(): reveal_cards.clear(); revealed.clear(); close_modal(); render())

func _reveal(index: int) -> void:
	if revealed.has(index): return
	revealed[index] = true
	_paint_revealed(index)
	var rarity = str(reveal_cards[index].get("rarity", "common"))
	audio_event.emit("booster.legendary_reveal" if rarity == "legendary" else "booster.rare_reveal" if rarity in ["rare", "epic"] else "booster.card_reveal")

func _paint_revealed(index: int) -> void:
	var slot = reveal_views[index]
	for child in slot.view.get_children(): child.free()
	var result: Dictionary = reveal_cards[index]
	var card: Dictionary = economy.catalog.get(result.get("id", ""), {}).duplicate(true)
	# Display-only fallback fields are never passed to battle or persisted as cards.
	for field in {"id": result.get("id", "fixture"), "name": "Modellkarte", "kind": "creature", "cost": 0, "atk": 0, "hp": 0, "faction": "neutral"}:
		if not card.has(field): card[field] = {"id": result.get("id", "fixture"), "name": "Modellkarte", "kind": "creature", "cost": 0, "atk": 0, "hp": 0, "faction": "neutral"}[field]
	card.rarity = result.get("rarity", card.get("rarity", "common"))
	var face = CardView.new()
	face.card = card
	face.library = true
	face.color = Style.color(card)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.view.add_child(face)
	var rarity_color = {"common": T.SECONDARY, "rare": T.ENERGY, "epic": Color("d6b3ff"), "legendary": T.GOLD}.get(card.rarity, T.TEXT)
	slot.label.text = Style.RARITIES.get(card.rarity, card.rarity) + (" · Überbestand +%d" % int(result.get("converted", 0)) if int(result.get("converted", 0)) > 0 else " · Duplikat" if result.get("duplicate", false) else " · Neu")
	slot.label.add_theme_color_override("font_color", rarity_color)
	slot.button.text = "Gesichert"
	slot.button.disabled = true
	if not reduced_motion:
		face.modulate.a = .2
		face.create_tween().tween_property(face, "modulate:a", 1.0, .22)

func _skip() -> void:
	for index in reveal_cards.size():
		revealed[index] = true
		_paint_revealed(index)
