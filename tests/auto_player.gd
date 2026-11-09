extends RefCounted
## Test strategy issues only legal model commands; never edits health or result flags.
static func finish(model) -> bool:
	for turn in 70:
		if model.finished:return model.result.begins_with("SIEG")
		for move in 8:
			var action=choice(model)
			var chosen=int(action.index);var lane=int(action.lane);var score=float(action.score)
			if chosen<0 or score<0:break
			model.selected=chosen
			if not model.play(lane).ok:break
		model.resolve_turn()
	return false

static func choice(model) -> Dictionary:
	var chosen=-1;var lane=-1;var score=-1000.0
	for i in model.hand.size():
		var card: Dictionary=model.CARD_POOL[model.hand[i]]
		if card.cost>model.energy:continue
		for x in 5:
			var value=-999.0
			if card.kind=="unit" and model.summons<2 and model.allies[x]==null:
				value=card.attack*2+card.hp*2
				if model.foes[x]==null:value+=12
				elif card.attack>=model.foes[x].hp:value+=8
			elif card.kind=="spell" and model.foes[x]!=null:value=80 if model.foes[x].hp<=3 else 15
			if value>score:score=value;chosen=i;lane=x
	return {"index":chosen,"lane":lane,"score":score}
