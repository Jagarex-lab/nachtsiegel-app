extends Control
## Presentation only. Every economic command commits before its result is shown.
signal back_requested
const T = preload("res://scripts/ui_tokens.gd")
const Style = preload("res://scripts/alpha/style.gd")
var economy
var actions: Dictionary = {}
var message := "Vier vollständige Starterdecks sind kostenlos und bleiben geschützt."
var query := ""
var selected_card := ""
var last_result: Array = []
var _snapshot: Dictionary = {}
var _scroll: ScrollContainer
var _body: VBoxContainer
var _choices: OptionButton
var _details: Label
var _craft_button: Button
var _ids: Array = []
var _narrow := false

func configure(service) -> void:
	economy = service
	if is_inside_tree(): render()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var palette := Theme.new()
	palette.default_font = T.FONT
	palette.default_font_size = 16
	for control in ["Label", "Button", "OptionButton", "LineEdit"]:
		palette.set_color("font_color", control, T.TEXT)
		palette.set_color("font_disabled_color", control, T.MUTED)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		for control in ["Button", "OptionButton", "LineEdit"]:
			palette.set_stylebox(state_name, control, T.panel(T.FOCUS if state_name == "focus" else T.METAL, T.SURFACE_RAISED if state_name in ["hover", "pressed"] else T.SURFACE))
	theme = palette
	resized.connect(_resize)
	render()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), T.INK)
	for i in range(5):
		draw_line(Vector2(size.x * .65 + i * 60, 0), Vector2(size.x * .1 + i * 60, size.y), Color(T.GOLD, .035), 1)

func _resize() -> void:
	if is_inside_tree() and _narrow != (size.x < 640): render()
	queue_redraw()

func _box(parent: Node, separation := 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _label(value: String, parent: Node, font_size := 16, color: Color = T.TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _panel(parent: Node, edge: Color = T.METAL) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var decoration := T.panel(edge)
	decoration.set_content_margin_all(18)
	frame.add_theme_stylebox_override("panel", decoration)
	parent.add_child(frame)
	return _box(frame)

func _button(id: String, title: String, parent: Node, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(callback, CONNECT_DEFERRED)
	parent.add_child(button)
	actions[id] = button
	return button

func _title(value: String, parent: Node, color: Color = T.GOLD) -> void:
	_label(value, parent, 23, color).add_theme_font_override("font", T.DISPLAY)

func render() -> void:
	_narrow = size.x < 640
	var previous_scroll := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	if is_instance_valid(_scroll): _scroll.free()
	actions.clear()
	_snapshot = economy.snapshot() if economy != null else {"ready": false, "error": "Fortschritt wird verbunden."}
	if last_result.is_empty(): last_result = _snapshot.get("last_open_result", []).duplicate(true)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12 if _narrow else 28)
	_scroll.add_child(margin)
	_body = _box(margin, 18)
	_button("back", "‹ Zurück", _body, func(): back_requested.emit())
	_label("ORAFOLD", _body, 30, T.GOLD).add_theme_font_override("font", T.DISPLAY)
	_title("Booster & Fortschritt", _body)
	_label("LOKALER TESTMODUS · KEINE ECHTGELDKÄUFE", _body, 13, T.WARNING)
	_label("Bestände und Ergebnisse werden nur auf diesem Gerät gespeichert. Sie sind nicht durch einen Server bestätigt.", _body, 14, T.SECONDARY)
	var ready: bool = bool(_snapshot.get("ready", false))
	_label(message if ready else "Speichern gesperrt: " + str(_snapshot.get("error", "Unbekannter Fehler")), _body, 15, T.PLAYER if ready else T.DANGER)
	_wallet_panel()
	_booster_panel(ready)
	_progress_panel()
	_collection_panel(ready)
	_label("Starter und hergestellte Karten sind gebunden. Überzählige Boosterfunde werden automatisch zu Essenz. Es gibt keinen Handel und keine Kaufverbindung.", _body, 13, T.SECONDARY)
	_scroll.set_deferred("scroll_vertical", previous_scroll)
	queue_redraw()

func _wallet_panel() -> void:
	var wallet: Dictionary = _snapshot.get("wallet", {})
	var progression: Dictionary = _snapshot.get("progression", {})
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for entry in [["GOLD", int(wallet.get("gold", 0)), T.GOLD], ["ESSENZ", int(wallet.get("crafting", 0)), T.PLAYER], ["LEVEL", int(progression.get("level", 1)), T.TEXT]]:
		var cell := _panel(grid, entry[2])
		_label(entry[0], cell, 12, T.SECONDARY)
		_label(str(entry[1]), cell, 28, entry[2])
	_label("%d Erfahrung gesammelt" % int(progression.get("xp", 0)), _body, 14, T.SECONDARY)
	var protected_copies := int(_snapshot.get("legacy_protected_copies", 0))
	if protected_copies > 0: _label("Alpha-Übergang: %d benötigte Kopien deiner bestehenden Decks bleiben geschützt." % protected_copies, _body, 14, T.SUCCESS)

func _booster_panel(ready: bool) -> void:
	var panel := _panel(_body, T.GOLD)
	_title("Das versiegelte Archiv", panel)
	_label("Standardbooster mit echten Karten des 550er-Katalogs.", panel, 15)
	var available := int(_snapshot.get("boosters", {}).get("standard", 0))
	var price := int(_snapshot.get("booster_price_gold", 100))
	_button("buy", "Booster sichern · %d Gold" % price, panel, func(): _handle(economy.buy_pack("standard"), "Booster gespeichert und zum Öffnen bereit."), not ready or int(_snapshot.get("wallet", {}).get("gold", 0)) < price)
	_button("open", "Booster öffnen · %d bereit" % available, panel, func(): _handle(economy.open_pack("standard"), "Dein Fund ist gespeichert. Du kannst diese Ansicht jederzeit verlassen."), not ready or available < 1)
	var pity: Dictionary = _snapshot.get("pity", {}).get("standard", {})
	_label("Pechschutz · %d Booster ohne Episch+ · %d ohne Legendär" % [int(pity.get("epic", 0)), int(pity.get("legendary", 0))], panel, 13, T.SECONDARY)
	var rules: Dictionary = _snapshot.get("booster_rules", {})
	for slot in rules.get("slots", []):
		var rates: PackedStringArray = []
		for rarity in ["common", "rare", "epic", "legendary"]:
			rates.append("%s %.1f %%" % [Style.RARITIES[rarity], float(slot.get("rates", {}).get(rarity, 0)) * 100])
		_label("%d Platz/Plätze: %s" % [int(slot.get("count", 0)), " · ".join(rates)], panel, 12, T.SECONDARY)
	if not rules.is_empty():
		_label("Spätestens nach %d Boostern ohne Episch+ bzw. %d ohne Legendär greift der Pechschutz. Epische und legendäre Funde bevorzugen fehlende Kopien." % [int(rules.get("pity", {}).get("epic", 0)), int(rules.get("pity", {}).get("legendary", 0))], panel, 13, T.SECONDARY)
	if not last_result.is_empty():
		_label("GESICHERTER FUND", panel, 13, T.PLAYER)
		for entry in last_result:
			var card: Dictionary = economy.catalog.get(entry.get("id", ""), {})
			var rarity := str(entry.get("rarity", card.get("rarity", "common")))
			var suffix := " · Überbestand → +%d Essenz" % int(entry.get("converted", 0)) if int(entry.get("converted", 0)) > 0 else " · Duplikat" if entry.get("duplicate", false) else " · Neu"
			_label("%s · %s%s" % [card.get("name", entry.get("id", "")), Style.RARITIES.get(rarity, rarity), suffix], panel, 15, T.GOLD if rarity == "legendary" else T.PLAYER)

func _progress_panel() -> void:
	var panel := _panel(_body, T.PLAYER)
	_title("Dein kostenloser Kartenpfad", panel, T.PLAYER)
	var path: Dictionary = _snapshot.get("protected_path", {})
	var matches := int(path.get("matches", 0))
	var checkpoints: Array = path.get("checkpoints", [10, 20, 30, 40])
	_label("%d abgeschlossene Partien · dauerhafte Meilensteine ohne Zeitlimit" % matches, panel, 15)
	for checkpoint in checkpoints:
		_label("%s %d Partien · %d Essenz" % ["✓" if matches >= int(checkpoint) else "○", int(checkpoint), int(path.get("essence_per_checkpoint", 300))], panel, 14, T.SUCCESS if matches >= int(checkpoint) else T.SECONDARY)
	_label("Mit der Essenz wählst du Karten selbst. Vier legale Starterdecks stehen sofort kostenlos zur Verfügung.", panel, 14, T.SECONDARY)
	_title("Aufgaben", panel, T.PLAYER)
	for quest in _snapshot.get("quests", []):
		_label("%s%s · %d/%d%s" % [quest.get("name", "Aufgabe"), " (optional)" if quest.get("optional", false) else "", mini(int(quest.get("count", 0)), int(quest.get("target", 1))), int(quest.get("target", 1)), " · gesichert" if quest.get("claimed", false) else ""], panel, 14, T.SUCCESS if quest.get("claimed", false) else T.SECONDARY)

func _collection_panel(ready: bool) -> void:
	var panel := _panel(_body, T.PLAYER)
	_title("Deine Sammlung", panel, T.PLAYER)
	var collection: Dictionary = _snapshot.get("collection", {})
	_label("%d / %d Kartenarten" % [int(collection.get("unique", 0)), int(collection.get("catalog_size", 550))], panel, 16)
	_label("Karten gezielt herstellen", panel, 15, T.SECONDARY)
	var search := LineEdit.new()
	search.custom_minimum_size.y = 48
	search.placeholder_text = "Karte nach Namen oder ID suchen …"
	search.text = query
	search.text_changed.connect(func(value: String): query = value; _update_choices())
	panel.add_child(search)
	actions["search"] = search
	_choices = OptionButton.new()
	_choices.custom_minimum_size.y = 48
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.fit_to_longest_item = false
	_choices.item_selected.connect(func(index: int): selected_card = str(_ids[index]); _update_craft())
	panel.add_child(_choices)
	actions["card_selector"] = _choices
	_details = _label("", panel, 14, T.SECONDARY)
	_craft_button = _button("craft", "Herstellen", panel, func(): _handle(economy.craft(selected_card), "Karte hergestellt und gespeichert."), not ready)
	_update_choices()

func _update_choices() -> void:
	_ids.clear()
	_choices.clear()
	if economy != null:
		for id in economy.catalog:
			var card: Dictionary = economy.catalog[id]
			if query.is_empty() or (str(card.get("name", "")) + " " + str(id)).to_lower().contains(query.to_lower()): _ids.append(id)
		_ids.sort_custom(func(a, b): return str(economy.catalog[a].get("name", a)).nocasecmp_to(str(economy.catalog[b].get("name", b))) < 0)
	if not _ids.has(selected_card): selected_card = str(_ids[0]) if not _ids.is_empty() else ""
	for id in _ids:
		_choices.add_item("%s · %d×" % [economy.catalog[id].get("name", id), economy.owned_count(str(id))])
	_choices.disabled = _ids.is_empty()
	if not _ids.is_empty(): _choices.select(_ids.find(selected_card))
	_update_craft()

func _update_craft() -> void:
	if selected_card.is_empty():
		_details.text = "Keine passende Karte gefunden."
		_craft_button.disabled = true
		return
	var card: Dictionary = economy.catalog[selected_card]
	var rarity := str(card.get("rarity", "common"))
	var cost := int(_snapshot.get("crafting_costs", {}).get(rarity, 0))
	var count: int = economy.owned_count(selected_card)
	var cap := 1 if rarity == "legendary" else 3
	_details.text = "%s · %s · %d/%d Kopien\n%s" % [card.get("name", selected_card), Style.RARITIES.get(rarity, rarity), count, cap, card.get("description", "")]
	_craft_button.text = "Herstellen · %d Essenz" % cost
	_craft_button.disabled = not _snapshot.get("ready", false) or count >= cap or int(_snapshot.get("wallet", {}).get("crafting", 0)) < cost

func _handle(result: Dictionary, success_message: String) -> void:
	if result.get("ok", false):
		message = success_message
		last_result = result.get("cards", []).duplicate(true)
	else:
		var code := str(result.get("code", "unknown"))
		var labels := {"save_failed": "Speichern fehlgeschlagen. Der Vorgang wurde nicht gutgeschrieben.", "insufficient_gold": "Nicht genug Gold.", "insufficient_crafting": "Nicht genug Essenz.", "copy_limit": "Das Kopienlimit ist bereits erreicht.", "missing_booster": "Kein Booster bereit."}
		message = labels.get(code, "Nicht ausgeführt: " + code)
	render()
