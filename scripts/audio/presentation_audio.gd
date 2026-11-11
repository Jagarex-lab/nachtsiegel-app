extends RefCounted
## Read-only adapter over already committed, ordered presentation snapshots.
## Each seq is consumed once. Delta sounds use adjacent snapshots, never again
## on the enclosing attack/effect row. No thresholds, rule calls or model writes.
var last_seq := -1
var last_state: Dictionary = {}
var music_result := ""

func reset() -> void:
	last_seq = -1
	last_state = {}
	music_result = ""

func _context(event: Dictionary, catalog) -> Dictionary:
	var id := str(event.get("card_id", ""))
	if id.is_empty() and event.get("pendingDeath") is Dictionary:
		id = str(event.pendingDeath.get("card", ""))
	# A post-resolution lane can already contain a replacement creature.
	# Without an explicit card identity, do not invent an attack faction.
	if id.is_empty() and str(event.get("order","")) in ["houses","stillwatch","morph","ninth","neutral"]:
		return {"faction":str(event.order),"rarity":"common","intensity":0.6}
	var card: Dictionary = catalog.card(id) if catalog != null and not id.is_empty() else {}
	return {"faction":str(card.get("faction",card.get("order","neutral"))), "rarity":str(card.get("rarity","common")), "intensity":0.6}

func collect(events: Array, previous: Dictionary, catalog = null) -> Array:
	var sounds: Array = []
	if last_state.is_empty(): last_state = previous
	for event in events:
		if not event is Dictionary or int(event.get("seq",-1)) <= last_seq: continue
		last_seq = int(event.seq)
		var now: Dictionary = event.get("state",{})
		if now.is_empty(): continue
		var kind := str(event.get("kind",""))
		var context := _context(event, catalog)
		# The production attack log differs from archived unit_hit/hero_hit logs.
		var semantic: String = {"attack":"creature.attack", "unit_hit":"creature.attack", "hero_hit":"creature.attack", "summon":"creature.summon", "death":"creature.defeated", "recall":"creature.return", "shift":"combat.path_change", "tactical_move":"combat.path_change", "generic_move":"combat.path_change", "generic_return":"card.return", "recover":"card.return", "burn":"card.discard", "generic_discard":"card.discard", "recycle":"card.shuffle", "relic_installed":"card.play.relic", "relic_activated":"relic.activate", "event":"card.play.impulse", "impulse_armed":"card.play.impulse", "impulse_triggered":"combat.reaction", "reaction":"combat.reaction", "burst":"resonance.unleash", "convergence_declared":"convergence.prepare", "convergence_win":"convergence.complete", "convergence_failed":"convergence.interrupt"}.get(kind, "")
		if not semantic.is_empty(): sounds.append({"event":semantic,"context":context})
		for side in ["hero","enemy"]:
			if not now.has(side) or not last_state.has(side): continue
			var old: Dictionary = last_state[side]
			var current: Dictionary = now[side]
			# A hand increment plus consumed deck cards confirms draw, not recovery.
			if current.hand.size() > old.hand.size() and current.deck.size() < old.deck.size():
				sounds.append({"event":"card.draw","context":{}})
			if int(current.hp) < int(old.hp): sounds.append({"event":"hero.damage","context":{}})
			elif int(current.hp) > int(old.hp): sounds.append({"event":"combat.heal","context":{}})
			if int(current.ward) > int(old.ward): sounds.append({"event":"shield.gain","context":{}})
			if int(current.block) > int(old.block): sounds.append({"event":"block.activate","context":{}})
			var resonance := int(current.resonance) - int(old.resonance)
			if resonance != 0: sounds.append({"event":"resonance.gain" if resonance > 0 else "resonance.spend","context":{}})
			for lane in 5:
				var before_unit: Variant = old.lanes[lane]
				var after_unit: Variant = current.lanes[lane]
				if not before_unit is Dictionary or not after_unit is Dictionary: continue
				if before_unit.get("uid",before_unit.id) != after_unit.get("uid",after_unit.id): continue
				if int(after_unit.hp) < int(before_unit.hp): sounds.append({"event":"creature.hit","context":context})
				elif int(after_unit.hp) > int(before_unit.hp): sounds.append({"event":"combat.heal","context":context})
				if int(after_unit.get("ward",0)) > int(before_unit.get("ward",0)): sounds.append({"event":"shield.gain","context":context})
				if int(after_unit.get("block",0)) > int(before_unit.get("block",0)): sounds.append({"event":"block.activate","context":context})
				if int(after_unit.get("stun",0)) > int(before_unit.get("stun",0)): sounds.append({"event":"combat.time","context":context})
		# Shield/block losses can be expiry; no absorption cue is guessed from them.
		last_state = now
	return sounds
