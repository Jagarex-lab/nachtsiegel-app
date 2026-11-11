extends VBoxContainer
## Accessible, portrait-friendly adapter demonstration; the Alpha engine owns every rule.
signal returned(token: String, outcome: String)
const UI = preload("res://data/campaign_orafold/battle_ui.json")
var adapter
var dialogue
var selected := -1
var exchanges: Array = []
var actions: Dictionary = {}
var message := ""
var confirm_surrender := false
var return_sent := false
var _render_pending := false

func setup(value, language) -> void:
	adapter = value
	dialogue = language
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	render()

func tx(key: String, values: Dictionary = {}) -> String:
	var locale = "de"
	if dialogue != null: locale = str(dialogue.locale)
	var result: String = UI.data.get(locale, UI.data.de).get(key, "[battle:" + key + "]")
	for field in values: result = result.replace("{" + field + "}", str(values[field]))
	return result

func label(value: String, parent: Node = null) -> Label:
	var node = Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else self).add_child(node)
	return node

func button(id: String, caption: String, callback: Callable, parent: Node = null) -> Button:
	var node = Button.new()
	node.text = caption
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(48, 52)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(callback)
	(parent if parent != null else self).add_child(node)
	actions[id] = node
	return node

func act(name: String, args: Array) -> void:
	var reply: Dictionary = adapter.command(name, args)
	message = "" if reply.ok else tx("invalid")
	if reply.ok:
		selected = -1
		exchanges.clear()
	render()

func retry_return() -> void:
	return_sent = false
	render()

func render() -> void:
	if _render_pending: return
	_render_pending = true
	call_deferred("_render_now")

func _render_now() -> void:
	_render_pending = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	actions.clear()
	if adapter == null or adapter.model == null: return
	var s: Dictionary = adapter.snapshot()
	var p: Dictionary = s.hero
	label(tx("title")).add_theme_color_override("font_color", Color("9bdce9"))
	label(tx("note")).add_theme_font_size_override("font_size", 14)
	label(tx("stats", {"hp":p.hp,"ward":p.ward,"energy":p.energy,"res":p.resonance,"enemy":s.enemy.hp,"round":maxi(1, ceili(float(s.round)/2))}))
	if not adapter.outcome.is_empty():
		label(tx(adapter.outcome)).add_theme_font_size_override("font_size", 28)
		button("return", tx("return"), _return_to_story)
		return
	if not s.error.is_empty(): label(tx("error", {"error":s.error}))
	if not message.is_empty(): label(message)
	if s.stage == "mulligan": label(tx("mulligan"))
	elif s.stage == "origins": label(tx("origin"))
	elif s.stage == "second": label(tx("second"))
	elif p.pendingTarget != null: label(tx("pending"))
	elif p.phase == "draw": label(tx("overflow") if _overflow(p) else tx("draw"))
	else: label(tx("main"))
	for lane in 5:
		var panel = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		add_child(panel)
		label(tx("path", {"n":lane+1}), box).add_theme_color_override("font_color", Color("c8b4ed"))
		label(tx("enemy") + ": " + _unit(s.enemy.lanes[lane]), box)
		label(tx("hero") + ": " + _unit(p.lanes[lane]), box)
		if s.stage == "origins":
			button("origin_"+str(lane), tx("path", {"n":lane+1}), func():act("origin",[lane]), box)
		elif s.stage == "second" and not s.second_path:
			button("second_origin_"+str(lane), tx("path", {"n":lane+1}), func():act("secondOrigin",[lane]), box)
		elif s.stage == "battle" and p.pendingTarget != null and s.enemy.lanes[lane] != null:
			button("strike_"+str(lane), tx("strike", {"n":lane+1}), func():act("chooseStrikeTarget",["hero",lane]), box)
		elif s.stage == "battle" and p.pendingShift == null and selected >= 0 and selected < p.hand.size() and adapter.model.legal_targets("hero",selected).has(lane):
			button("play_"+str(lane), tx("target", {"n":lane+1}), func():act("play",["hero",selected,lane]), box)
	label(tx("hand"))
	for index in p.hand.size():
		var card: Dictionary = adapter.card(p.hand[index])
		var caption = ("✓ " if exchanges.has(index) or selected == index else "") + str(card.name) + " · " + tx("cost", {"n":card.cost}) + "\n" + str(card.get("description", ""))
		button("card_"+str(index), caption, func():_select(index))
	if s.stage == "mulligan": button("keep", tx("keep"), func():act("mulligan",[exchanges.duplicate()]))
	elif s.stage == "second":
		if not s.second_card and selected >= 0: button("exchange",tx("exchange"),func():act("secondCard",[selected]))
		button("begin",tx("begin"),func():act("openingDone",[]))
	elif s.stage == "battle":
		if p.pendingShift != null: button("skip",tx("skip"),func():act("skipShift",["hero"]))
		elif p.pendingTarget == null:
			if p.phase == "draw":
				if _overflow(p):
					if selected >= 0: button("burn",tx("burn"),func():act("burn",["hero",selected]))
				else: button("draw",tx("draw"),func():act("finishDraw",["hero"]))
			elif p.phase == "main":
				button("end",tx("end"),func():act("endTurn",["hero"]))
				if p.resonance >= 5 and not p.cycled and p.hand.size() < 6 and not p.discard.is_empty():
					button("recover",tx("recover"),func():act("recover",["hero"]))
				for lane in 5:
					if p.lanes[lane] != null and p.resonance >= 2 and not p.fortifyUsed:
						button("fortify_"+str(lane),tx("fortify",{"n":lane+1}),func():act("fortify",["hero",lane]))
					if p.lanes[lane] != null and p.resonance >= 3 and not p.tacticUsed:
						for target in [lane-1,lane+1]:
							if target >= 0 and target < 5 and p.lanes[target] == null:
								button("move_%d_%d" % [lane,target],tx("move",{"from":lane+1,"to":target+1}),func():act("tacticalMove",["hero",lane,target]))
				if p.relic != null and not p.relic_used and p.energy > 0: button("relic",tx("relic"),func():act("activateRelic",["hero"]))
				var controlled: Array = []
				for lane in 5:
					if adapter.model.controlled("hero",lane): controlled.append(lane)
				if controlled.size() >= 3 and s.round >= 11: button("converge",tx("converge"),func():act("converge",["hero",controlled.slice(0,3)]))
				if p.resonance >= 15 and not p.burstUsed:
					for faction in adapter.model.catalog.deck_ids():
						button("burst_"+faction,tx("burst",{"name":adapter.model.catalog.source.powers.get(faction,faction)}),func():act("burst",["hero",faction]))
	if confirm_surrender:
		button("confirm",tx("confirm"),func():adapter.surrender();render())
		button("cancel",tx("cancel"),func():confirm_surrender=false;render())
	else: button("surrender",tx("surrender"),func():confirm_surrender=true;render())

func _select(index: int) -> void:
	if adapter.snapshot().stage == "mulligan":
		if exchanges.has(index): exchanges.erase(index)
		else: exchanges.append(index)
	else: selected = index
	render()

func _unit(value: Variant) -> String:
	if value == null: return tx("empty")
	return tx("unit", {"name":adapter.card(value.id).name,"atk":value.atk,"hp":value.hp,"ward":value.ward})

func _overflow(player: Dictionary) -> bool:
	return player.hand.size() + mini(int(player.pendingDraw), player.deck.size()) > 6

func _return_to_story() -> void:
	if return_sent or adapter.outcome.is_empty(): return
	return_sent = true
	returned.emit(adapter.token, adapter.outcome)
