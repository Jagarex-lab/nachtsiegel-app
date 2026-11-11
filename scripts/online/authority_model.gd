extends "res://scripts/card_system/production_model.gd"
## Two human controllers over the production kernel. Only opening/controller
## boundaries differ; cards, combat, costs, FIFO and RNG stay in Production.
var human_opening: Dictionary = {}

func _init(probe_from: RefCounted = null) -> void:
	super(probe_from)
	if probe_from != null:
		human_opening=probe_from.human_opening.duplicate(true)
		rng=Random.new(probe_from.rng.state);rng.calls=probe_from.rng.calls

func start_alpha(deck: Array, opponent_deck: Array, seed_value: int, difficulty: int = 2) -> bool:
	if not super.start_alpha(deck, opponent_deck, seed_value, difficulty):return false
	human_opening = {"mulligan":{"hero":false,"enemy":false},"origin":{"hero":false,"enemy":false}}
	return true

func snapshot() -> Dictionary:
	var value = super.snapshot()
	value["human_opening"] = human_opening.duplicate(true)
	value["rng_checkpoint"] = {"state":rng.state,"calls":rng.calls}
	return value

func _automatic_draw_side(_side: String) -> bool:return false
func ai_turn(_side: String) -> void:pass

func end_turn(side: String) -> bool:
	if state.stage != "battle" or not state.error.is_empty():return false
	return advance_turn(side)

func execute(command: String, args: Array) -> Dictionary:
	if not command in ["mulligan","origin","secondOrigin","secondCard","openingDone","concede"]:
		return super.execute(command,args)
	if args.is_empty() or not args[0] is String or not _valid_side(args[0]) or state.winner != null:
		return {"ok":false,"reason":"invalid_actor"}
	var side: String = args[0]
	var ok = false
	match command:
		"mulligan":
			if args.size()!=2 or not args[1] is Array or state.stage!="mulligan" or human_opening.mulligan[side] or args[1].size()>5:return {"ok":false,"reason":"invalid_mulligan"}
			var seen = {}
			for index in args[1]:
				if not _integer(index) or index<0 or index>=state[side].hand.size() or seen.has(int(index)):return {"ok":false,"reason":"invalid_mulligan"}
				seen[int(index)]=true
			_exchange(side,args[1]);human_opening.mulligan[side]=true
			if human_opening.mulligan.hero and human_opening.mulligan.enemy:
				state.coin="hero" if rng.next_float()<.5 else "enemy"
				state.active=state.coin;state.stage="origins"
			_trace("human_mulligan",side);ok=true
		"origin":
			if args.size()!=2 or state.stage!="origins" or human_opening.origin[side] or not _integer(args[1]) or args[1]<0 or args[1]>4:return {"ok":false,"reason":"invalid_origin"}
			state.origins[side]=int(args[1]);human_opening.origin[side]=true
			if human_opening.origin.hero and human_opening.origin.enemy:state.stage="second"
			_trace("human_origin",side);ok=true
		"secondOrigin", "secondCard", "openingDone":
			if state.stage!="second" or side==state.coin:return {"ok":false,"reason":"second_player_only"}
			if command=="openingDone":
				if args.size()!=1:return {"ok":false,"reason":"invalid_arguments"}
				state.stage="battle";state.round=1;begin_turn(state.active);ok=true
			elif command=="secondOrigin":
				if args.size()!=2 or state.second_path or not _integer(args[1]) or args[1]<0 or args[1]>4:return {"ok":false,"reason":"invalid_second_origin"}
				state.origins[side]=int(args[1]);state.second_path=true;_trace("second_origin",side);ok=true
			else:
				if args.size()!=2 or state.second_card or not _integer(args[1]) or args[1]<0 or args[1]>=state[side].hand.size():return {"ok":false,"reason":"invalid_second_card"}
				_exchange(side,[int(args[1])]);state.second_card=true;_trace("second_card",side);ok=true
		"concede":
			if args.size()!=1:return {"ok":false,"reason":"invalid_arguments"}
			state.winner=_other(side);_trace("concede",side);ok=true
	return {"ok":ok,"reason":"" if ok else "invalid_action"}
