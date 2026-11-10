extends RefCounted
## Deterministic public-information policy. Every action uses the model's legal API.
## Difficulty changes evaluation only: no extra cards, resources or hidden information.
const MAX_ACTIONS := 64
var decisions: Array = []
var turn_observations: Array = []
var record_decisions := false
var action_limit_reached := 0

func take_turn(model: RefCounted, side: String) -> void:
	if model.state.get("winner") != null or model.state.get("active") != side: return
	var p: Dictionary = model.state[side]
	if model.state.get("stage") != "battle" or not model.state.get("error", "").is_empty(): return
	if p.phase == "draw":
		while p.hand.size() + mini(int(p.pendingDraw), p.deck.size()) > 6:
			var weakest := _burn_index(model, side)
			if weakest < 0 or not _act(model, side, "burn", [side, weakest]): return
		if not _act(model, side, "finish_draw", [side]): return
	if model.state.winner != null or not model.state.error.is_empty(): return
	if record_decisions:
		turn_observations.append({"side":side,"round":model.state.round,"turn":p.turns,"energy":p.energy,"resonance":p.resonance,"hand":p.hand.size(),"hp":p.hp,"ward":p.ward,"block":p.block})
	for step in MAX_ACTIONS:
		if model.state.winner != null or not model.state.error.is_empty(): return
		if p.pendingTarget != null:
			var target := _strike_target(model, side, int(p.pendingTarget.power))
			if target < 0 or not _act(model, side, "choose_strike_target", [side, target]): return
			continue
		if p.pendingShift != null:
			var shift := _shift_choice(model, side)
			if shift.is_empty(): _act(model, side, "skip_shift", [side])
			else: _act(model, side, "move_creature", [side, shift.from, shift.to])
			continue
		var best := choose_play(model, side)
		if best.is_empty() or float(best.score) <= 0.0: break
		if not _act(model, side, "play", [side, best.index, best.lane]):
			# Legal choices are not speculative mutations. A failed advertised action
			# is an engine contract failure and is recorded, not silently counted.
			model.state.error = "KI: als legal gemeldete Karte konnte nicht gespielt werden."
			return
		if step == MAX_ACTIONS - 1: action_limit_reached += 1
	if model.state.winner != null or not model.state.error.is_empty(): return
	_try_relic(model, side)
	if model.state.winner != null or not model.state.error.is_empty(): return
	_try_burst(model, side)
	if model.state.winner != null or not model.state.error.is_empty(): return
	if int(model.state.level) >= 2:
		_try_tactic(model, side)
		_try_recover(model, side)
		# Recovery may produce a newly affordable card; resolve it through the
		# same policy on the next bounded pass rather than duplicating play rules.
		for _step in 6:
			if model.state.winner != null or not model.state.error.is_empty(): return
			if p.pendingTarget != null:
				var target := _strike_target(model, side, int(p.pendingTarget.power))
				if target >= 0: _act(model, side, "choose_strike_target", [side, target])
				continue
			if p.pendingShift != null:
				var shift := _shift_choice(model, side)
				if shift.is_empty(): _act(model, side, "skip_shift", [side])
				else: _act(model, side, "move_creature", [side, shift.from, shift.to])
				continue
			var best := choose_play(model, side)
			if best.is_empty() or float(best.score) <= 0.0: break
			if not _act(model, side, "play", [side, best.index, best.lane]): break
		_try_fortify(model, side)
	if model.state.winner != null or not model.state.error.is_empty(): return
	# Relic/tactic/fortify reactions can themselves summon a native target-choice
	# creature. Finish that real pending choice before ending the turn, on every
	# difficulty, even when the ordinary play pass has already ended.
	for _pending in 8:
		if model.state.winner != null or not model.state.error.is_empty(): return
		if p.pendingTarget != null:
			var target := _strike_target(model, side, int(p.pendingTarget.power))
			if target < 0 or not _act(model,side,"choose_strike_target",[side,target]):
				model.state.error="KI: offene Zielwahl ohne ausführbares Ziel."
				return
		elif p.pendingShift != null:
			var shift := _shift_choice(model,side)
			if shift.is_empty(): _act(model,side,"skip_shift",[side])
			else: _act(model,side,"move_creature",[side,shift.from,shift.to])
		else: break
	if p.pendingTarget != null or p.pendingShift != null:
		model.state.error="KI: Zielwahl überschritt die technische Aktionsgrenze."
		return
	var lanes: Array = []
	for lane in 5:
		if model.controlled(side, lane): lanes.append(lane)
	if lanes.size() >= 3 and bool(model.state.convergence_enabled) and int(floor(float(model.state.round - 1) / 2.0)) >= 5:
		if _act(model, side, "declare_convergence", [side, lanes.slice(0, 3)]): return
	_act(model, side, "end_turn", [side])

func choose_play(model: RefCounted, side: String) -> Dictionary:
	var best: Dictionary = {}
	var hand: Array = model.state[side].hand
	for index in hand.size():
		var card: Dictionary = model.catalog.card(hand[index])
		for lane in model.legal_targets(side, index):
			var score := card_score(model, side, card, int(lane))
			if best.is_empty() or score > float(best.score): best = {"index":index,"lane":lane,"score":score,"card_id":card.id}
	return best

func card_score(model: RefCounted, side: String, card: Dictionary, lane: int) -> float:
	var p: Dictionary = model.state[side]
	var op: Dictionary = model.state[model._other(side)]
	var difficulty := int(model.state.level)
	var kind := str(card.get("kind", ""))
	var score := -0.12 * float(card.get("cost", 0))
	if kind == "creature":
		var attack := float(card.get("atk", 0))
		var health := float(card.get("hp", 0))
		score += attack * 0.8 + health * 0.48 + 1.0
		if op.lanes[lane] == null:
			score += attack * (0.7 if _card_has(card, ["haste"]) else 0.38)
			if _card_has(card, ["haste"]) and attack >= int(op.hp) + int(op.ward) + int(op.block): score += 500.0
		else:
			var enemy: Dictionary = op.lanes[lane]
			score += minf(attack, float(enemy.hp)) * 0.25
			if difficulty >= 2:
				if attack >= int(enemy.hp) + int(enemy.get("ward",0)): score += 1.8
				if health > int(enemy.atk): score += 1.2
				if int(p.hp) <= 10: score += _unit_threat(model, model._other(side), lane) * 0.9
			if op.convergence != null and op.convergence.lanes.has(lane): score += 40.0
		if not bool(model.state.origin_used[side]) and int(model.state.origins[side]) == lane: score += 0.35
	elif kind == "relic":
		score += 3.2 if p.relic == null else -3.5
		if p.relic != null:
			var current: Dictionary=model.catalog.card(p.relic.id)
			if current.id==card.id:score-=50.0
			elif _blocked_board(model,side):
				var next_growth:=_growth_strength(card)
				var current_growth:=_growth_strength(current)
				if next_growth>current_growth:score+=14.0+float(next_growth-current_growth)
				elif current_growth>0 and next_growth==0:score-=14.0
	elif kind == "event": score += 0.1
	for ability in _abilities(card):
		score += _effect_score(model, side, ability, lane, kind, card)
	# Easy deliberately uses a simpler public-board evaluation, but has identical
	# legality, randomness and starting resources to the other difficulties.
	if difficulty <= 1 and kind == "creature": return maxf(0.1, float(card.get("atk",0)) + float(card.get("hp",0)) * 0.2 + score * 0.25)
	return score

func _abilities(card: Dictionary) -> Array:
	if card.get("abilities") is Array: return card.abilities
	return [{"effect":card.get("effect",""),"target":"", "params":{"amount":card.get("power",0)}}]

func _card_has(card: Dictionary, ids: Array) -> bool:
	for ability in _abilities(card):
		if ability.get("effect") in ids: return true
	return card.get("effect") in ids

func _effect_score(model: RefCounted, side: String, ability: Dictionary, lane: int, kind: String, source: Dictionary={}) -> float:
	var p: Dictionary = model.state[side]
	var other: String = model._other(side)
	var op: Dictionary = model.state[other]
	var params: Dictionary = ability.get("params", {})
	var amount := float(params.get("amount", params.get("attack", params.get("count", 1))))
	var effect := str(ability.get("effect", ""))
	var target := str(ability.get("target", ""))
	var enemy: Variant = op.lanes[lane]
	var own: Variant = p.lanes[lane]
	var enemy_lane:=lane
	# Automatic targets are evaluated as automatic targets, rather than pretending
	# a chosen lane can redirect a lowest-health or all-units ability.
	if target in ["enemy_lowest_health", "enemy_all"]:
		enemy = _lowest_unit(op.lanes)
		for candidate_lane in 5:
			if op.lanes[candidate_lane]!=null and is_same(op.lanes[candidate_lane],enemy):enemy_lane=candidate_lane;break
	elif target == "enemy_hero": enemy = null
	if target == "own_lowest_health": own = _lowest_unit(p.lanes)
	var affected := 1.0
	if target in ["own_all", "own_species", "own_neighbors", "enemy_all"]:
		affected = 0.0
		var chosen_lanes: Array = op.lanes if target == "enemy_all" else p.lanes
		for i in 5:
			var u: Variant = chosen_lanes[i]
			if u == null: continue
			if target == "own_species" and not model.catalog.card(u.id).get("species",[]).has(params.get("species")): continue
			if target == "own_neighbors" and abs(i-lane) != 1: continue
			affected += 1.0
		if kind == "creature" and str(ability.get("trigger","")) == "on_summon" and target in ["own_all","own_species"]:
			if target != "own_species" or source.get("species",[]).has(params.get("species")): affected += 1.0
	var score := 0.0
	match effect:
		"damage", "deal_damage", "bolt", "strike", "pierce", "drain", "pulse":
			if target in ["self","own_hero","own_lowest_health","own_all","own_species","own_neighbors"]:
				score = -amount * 0.65
			elif target in ["opposite_enemy_unit","enemy_lowest_health","enemy_all"] and enemy == null:
				score = 0.0
			elif enemy == null:
				score = minf(amount, float(op.hp) + float(op.ward) + float(op.block)) * 0.8
				if amount >= int(op.hp) + int(op.ward) + int(op.block): score += 500.0
			else:
				score = minf(amount, float(enemy.hp) + float(enemy.get("ward",0))) * 0.85
				if amount >= int(enemy.hp) + int(enemy.get("ward",0)): score += 1.5 + float(enemy.atk) * 0.25
				if op.convergence != null and op.convergence.lanes.has(enemy_lane): score += 32.0
		"heal", "heal_target", "mend", "relic_heal":
			var missing := float(p.maxHp - p.hp)
			if target in ["self_unit", "own_unit", "source", "chosen_ally", "own_lowest_health"] and own != null:
				missing = maxf(0.0, float(model.catalog.card(own.id).hp) - float(own.hp))
			score = minf(missing, amount) * (1.0 if p.hp < 12 else 0.45)
			if missing <= 0 and kind == "event": score -= 4.0
		"shield", "grant_shield", "grant_ward", "ward", "relic_ward", "guard", "grant_block", "block":
			var incoming := _incoming(model, other)
			score = minf(amount, incoming + 2.0) * (0.9 if p.hp < 12 else 0.4)
			if target in ["self_unit", "own_unit", "source", "chosen_ally", "own_lowest_health"] and own != null: score += float(own.atk) * 0.18
		"draw", "draw_cards", "relic_draw":
			score = minf(amount, maxf(0.0, 6.0 - float(p.hand.size()) + (1.0 if kind == "event" else 0.0))) * 1.25
			if p.deck.is_empty(): score = -2.0
		"resources", "gain_energy", "gain_resonance", "weave", "harvest", "relic_res":
			if effect=="gain_energy" or params.get("resource", "resonance") == "energy": score = amount * (1.2 if p.hand.size() > 1 else 0.2)
			else: score = minf(amount, maxf(0.0, 15.0 - float(p.resonance))) * 0.45
		"modify_attack", "rally":
			if own != null: score = amount * (1.1 if model.can_fight(side,lane) else 0.55)
			elif kind == "creature": score = amount * 0.6
		"weaken", "weaken_unit", "silence": score = minf(amount, _incoming(model,other)) * 0.55
		"stun", "stun_unit", "stasis":
			if enemy != null:
				score = _unit_threat(model, other, enemy_lane) * 0.7 + amount * 0.25
				if op.convergence != null and op.convergence.lanes.has(enemy_lane): score += 36.0
			else: score = -2.0
		"return", "return_card", "recall":
			score = 5.5 if model._discard_unit(side) >= 0 else -3.0
		"summon", "summon_card": score = 3.5
		"surge":
			if own != null and model.can_fight(side,lane): score = float(own.atk) * (1.1 if enemy == null else 0.75)
			else: score = -3.0
		"move", "move_unit", "shift", "displace":
			if target.begins_with("enemy") or effect == "displace":
				score = _unit_threat(model, other, enemy_lane) * 0.5 if enemy != null else -1.0
				if enemy != null and op.convergence != null and op.convergence.lanes.has(enemy_lane): score += 35.0
			else: score = 1.25
		"delay", "delay_damage":
			score = amount * 0.6
			if enemy != null: score += float(enemy.hp) * 0.15
		"redirect":
			for event in model.state.delayed:
				if event.side == side: score += float(event.get("power",0)) * (0.7 if enemy != null else 1.0); break
		"cascade":
			score = amount * 0.9
			if amount >= int(op.hp) + int(op.ward) + int(op.block): score += 500.0
		"haste": score = float(params.get("amount",1)) * 0.6
		"discard", "discard_card": score = 0.5 if target.begins_with("enemy") else -0.8
		"retaliate": score = amount * 0.3
	if target in ["own_all", "own_species", "own_neighbors", "enemy_all"]: score *= affected
	if ability.get("mode") == "passive": score *= 1.25
	elif ability.get("mode") == "activated": score *= 1.15
	elif str(ability.get("trigger", "on_play")) not in ["on_play", "on_summon"]: score *= 0.8
	return score

func _lowest_unit(lanes: Array) -> Variant:
	var chosen: Variant = null
	for unit in lanes:
		if unit != null and (chosen == null or int(unit.hp) < int(chosen.hp)): chosen = unit
	return chosen

func _growth_strength(card: Dictionary) -> int:
	if card.get("kind")!="relic":return 0
	var strength:=0
	for ability in card.get("abilities",[]):
		if ability.get("effect")=="modify_attack" and ability.get("trigger")=="on_turn_start":strength=maxi(strength,int(ability.get("params",{}).get("amount",0)))
	return strength

func _blocked_board(model: RefCounted, side: String) -> bool:
	var p: Dictionary=model.state[side]
	var op: Dictionary=model.state[model._other(side)]
	var powerless:=0
	var opposing_protection:=0
	for lane in 5:
		if p.lanes[lane]==null or op.lanes[lane]==null:return false
		if int(p.lanes[lane].atk)<=int(p.weak)+1:powerless+=1
		opposing_protection+=int(op.lanes[lane].get("ward",0))+int(op.lanes[lane].get("block",0))
	return powerless>=3 or opposing_protection>=10

func _unit_threat(model: RefCounted, side: String, lane: int) -> float:
	var u: Variant = model.state[side].lanes[lane]
	if u == null or int(u.stun) > 0: return 0.0
	return maxf(0.0, float(u.atk) - float(model.state[side].weak))

func _incoming(model: RefCounted, side: String) -> float:
	var amount := 0.0
	for lane in 5:
		var own: Variant = model.state[model._other(side)].lanes[lane]
		if own == null: amount += _unit_threat(model, side, lane)
	return amount

func _burn_index(model: RefCounted, side: String) -> int:
	var p: Dictionary = model.state[side]
	var worst := -1
	var score := INF
	var preserve_growth: int=-1
	var preserve_value: float=-INF
	var has_growth:=p.relic!=null and _growth_strength(model.catalog.card(p.relic.id))>0
	if not has_growth:
		for i in p.hand.size():
			var candidate: Dictionary=model.catalog.card(p.hand[i])
			var strength:=_growth_strength(candidate)
			if strength<=0:continue
			var utility:=float(strength)*3.0-float(candidate.cost)*0.25
			if preserve_growth<0 or utility>preserve_value:preserve_growth=i;preserve_value=utility
	for i in p.hand.size():
		var card: Dictionary = model.catalog.card(p.hand[i])
		var value := -float(card.get("cost",0)) * 0.5
		for lane in 5: value = maxf(value, card_score(model,side,card,lane) - maxf(0.0, float(card.cost) - float(p.energy)) * 0.8)
		if i==preserve_growth:value+=9.0
		if worst < 0 or value < score: worst = i; score = value
	return worst

func _strike_target(model: RefCounted, side: String, amount: int) -> int:
	var op: Dictionary = model.state[model._other(side)]
	var target := -1
	var best := -INF
	for lane in 5:
		var unit: Variant = op.lanes[lane]
		if unit == null: continue
		var score := minf(float(amount),float(unit.hp)) + float(unit.atk) * 0.25
		if amount >= int(unit.hp) + int(unit.get("ward",0)): score += 3.0
		if op.convergence != null and op.convergence.lanes.has(lane): score += 50.0
		if target < 0 or score > best: target = lane; best = score
	return target

func _lane_value(model: RefCounted, side: String, from: int, to: int) -> float:
	var op: Dictionary = model.state[model._other(side)]
	var unit: Variant = model.state[side].lanes[from]
	if unit == null: return -INF
	var score := 0.0
	if op.lanes[to] == null: score += float(unit.atk) * 1.2
	else:
		var enemy: Dictionary = op.lanes[to]
		score += minf(float(unit.atk),float(enemy.hp)) * 0.45
		if int(unit.atk) >= int(enemy.hp) + int(enemy.get("ward",0)): score += 1.0
		if int(unit.hp) <= int(enemy.atk): score -= 1.0
		if op.convergence != null and op.convergence.lanes.has(to): score += 40.0
	return score

func _shift_choice(model: RefCounted, side: String) -> Dictionary:
	var p: Dictionary = model.state[side]
	var best: Dictionary = {}
	var value := 0.0
	for choice in model.shift_choices(side, int(p.pendingShift.origin)):
		var change := _lane_value(model,side,choice.from,choice.to) - _lane_value(model,side,choice.from,choice.from)
		if change > value: best = choice; value = change
	return best

func _try_relic(model: RefCounted, side: String) -> void:
	var p: Dictionary = model.state[side]
	if p.relic == null or bool(p.relic_used): return
	if model.has_method("can_activate_relic"):
		if not model.can_activate_relic(side): return
		var relic: Dictionary = model.catalog.card(p.relic.id)
		if relic.get("effect") == "v2":
			var value := 0.0
			var has_activation := false
			for ability in relic.get("abilities", []):
				if ability.get("mode") != "activated": continue
				has_activation = true
				var activation: Dictionary = ability.get("activation", {})
				var utility := _effect_score(model,side,ability,0,"relic")
				utility -= float(activation.get("energy",0)) * 0.18 + float(activation.get("resonance",0)) * 0.12
				value = maxf(value,utility)
			if has_activation and value <= 0.0: return
		_act(model,side,"activate_relic",[side])
		return
	var card: Dictionary = model.catalog.card(p.relic.id)
	var effect := str(card.get("effect",""))
	if int(p.energy) < 1: return
	if (effect == "relic_heal" and int(p.hp) < int(p.maxHp)) or (effect == "relic_ward" and int(p.ward) < 25) or (effect == "relic_res" and int(p.resonance) < 15) or effect == "relic_draw": _act(model,side,"activate_relic",[side])

func _try_burst(model: RefCounted, side: String) -> void:
	var p: Dictionary = model.state[side]
	if int(p.resonance) < 15 or bool(p.burstUsed): return
	var candidates: Array = []
	for faction in model.catalog.deck_ids():
		var count := 0
		for unit in p.lanes:
			if unit != null and model.catalog.card(unit.id).order == faction: count += 1
		if count == 0: continue
		var score := float(count)
		match faction:
			"ninth": score += 4.0 + count * 3.0
			"morph": score += count * 2.0 + _incoming(model,model._other(side)) * 0.4
			"houses": score += minf(float(p.maxHp-p.hp), float(3+count))
			"stillwatch": score += minf(float(25-int(p.ward)),float(6+2*count)) * 0.4
		candidates.append({"faction":faction,"score":score})
	candidates.sort_custom(func(a,b): return float(a.score) > float(b.score))
	for candidate in candidates:
		if _act(model,side,"burst",[side,candidate.faction]): return

func _try_tactic(model: RefCounted, side: String) -> void:
	var p: Dictionary = model.state[side]
	if p.pendingTarget != null or p.pendingShift != null or bool(p.tacticUsed) or int(p.resonance) < 3: return
	var best: Dictionary = {}
	var value := 1.5
	for from in 5:
		if p.lanes[from] == null: continue
		for to in [from-1,from+1]:
			if to < 0 or to > 4 or p.lanes[to] != null: continue
			var change := _lane_value(model,side,from,to) - _lane_value(model,side,from,from)
			if change > value: best = {"from":from,"to":to}; value = change
	if not best.is_empty(): _act(model,side,"tactical_move",[side,best.from,best.to])

func _try_recover(model: RefCounted, side: String) -> void:
	var p: Dictionary = model.state[side]
	if p.pendingTarget != null or p.pendingShift != null or bool(p.cycled) or int(p.resonance) < 5 or p.hand.size() > 2 or p.discard.is_empty(): return
	if int(p.energy) < 1: return
	_act(model,side,"recover",[side])

func _try_fortify(model: RefCounted, side: String) -> void:
	var p: Dictionary = model.state[side]
	if p.pendingTarget != null or p.pendingShift != null or bool(p.fortifyUsed) or int(p.resonance) < 2: return
	if _incoming(model,model._other(side)) < 1.0 and int(p.hp) > 12: return
	var lane := -1
	var value := -INF
	for i in 5:
		var u: Variant = p.lanes[i]
		if u == null: continue
		var score := float(u.atk) * 0.3 + maxf(0.0,float(model.catalog.card(u.id).hp) - float(u.hp))
		if p.convergence != null and p.convergence.lanes.has(i): score += 5.0
		if lane < 0 or score > value: lane = i; value = score
	if lane >= 0: _act(model,side,"fortify",[side,lane])

func _act(model: RefCounted, side: String, method: String, args: Array) -> bool:
	var p: Dictionary = model.state[side]
	var before := {"energy":p.energy,"resonance":p.resonance,"hp":p.hp,"hand":p.hand.size(),"round":model.state.round}
	var card_id := ""
	if method == "play" and args.size() == 3 and int(args[1]) < p.hand.size(): card_id = str(p.hand[int(args[1])])
	var result: bool = bool(model.callv(method,args))
	if record_decisions:
		decisions.append({"side":side,"method":method,"args":args.duplicate(),"ok":result,"card_id":card_id,"before":before,"after":{"energy":p.energy,"resonance":p.resonance,"hp":p.hp,"hand":p.hand.size(),"round":model.state.round}})
	return result
