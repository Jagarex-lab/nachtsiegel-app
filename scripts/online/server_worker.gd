extends SceneTree
## Private, headless NDJSON boundary. stdout response is prefixed so Godot's
## startup banner never becomes protocol data. No client ever receives state.
const Session = preload("res://scripts/online/authority_session.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const COMMANDS = ["mulligan","origin","secondOrigin","secondCard","openingDone","play","finishDraw","burn","endTurn","chooseStrikeTarget","moveCreature","skipShift","recover","burst","tacticalMove","fortify","activateRelic","converge"]
var catalog = Catalog.new()

func _initialize() -> void:
	if "--persistent" in OS.get_cmdline_user_args():
		_persistent_loop();quit();return
	var raw := ""
	# The default Godot stdin chunk is 1024 bytes. Durable journals exceed it;
	# consume the complete one-request pipe to EOF before parsing.
	while true:
		var chunk=OS.read_string_from_stdin(65536)
		if chunk.is_empty():break
		raw+=chunk
		if raw.length()>8*1024*1024:
			print("ORAFOLD_RESULT "+JSON.stringify({"ok":false,"error":"STATE_TOO_LARGE"}));quit();return
		if raw.ends_with("\n"):
			var request: Variant=JSON.parse_string(raw)
			var result: Dictionary=_request(request) if request is Dictionary else {"ok":false,"error":"INVALID_JSON"}
			print("ORAFOLD_RESULT "+JSON.stringify(result))
			raw=""
			if not "--persistent" in OS.get_cmdline_user_args():break
	quit()

func _persistent_loop() -> void:
	# Godot's positive stdin buffer size blocks until the requested byte count.
	# Short base64 lines keep its default line reader bounded without inserting
	# newlines inside JSON strings. The bridge alone uses this private framing.
	var encoded := ""
	while true:
		var line=OS.read_string_from_stdin().strip_edges()
		if line.is_empty():return
		if line=="ORAFOLD_END":
			var request: Variant=JSON.parse_string(Marshalls.base64_to_utf8(encoded));encoded=""
			var result: Dictionary=_request(request) if request is Dictionary else {"ok":false,"error":"INVALID_JSON"}
			print("ORAFOLD_RESULT "+JSON.stringify(result))
		else:
			encoded+=line
			if encoded.length()>12*1024*1024:return

func _selection(value: Variant) -> Dictionary:
	if value==null:value={"starter_id":"houses"}
	if not value is Dictionary:return {"ok":false,"error":"INVALID_DECK"}
	var cards: Array=[]
	var selection: Dictionary={}
	if value.size()==1 and value.get("starter_id") is String and value.starter_id in catalog.deck_ids():
		cards=catalog.deck(value.starter_id);selection={"starter_id":value.starter_id}
	elif value.size()==1 and value.get("cards") is Array:
		cards=value.cards.duplicate();selection={"cards":cards}
	else:return {"ok":false,"error":"INVALID_DECK"}
	var valid=catalog.validate(cards)
	return {"ok":true,"selection":selection,"cards":cards} if valid.ok else {"ok":false,"error":"INVALID_DECK","message":valid.get("message","")}

func _request(request: Dictionary) -> Dictionary:
	var version=Engine.get_version_info()
	if version.major!=4 or version.minor!=6 or version.patch!=3:return {"ok":false,"error":"ENGINE_VERSION_MISMATCH"}
	if catalog.all_cards().size()!=550:return {"ok":false,"error":"CATALOG_VERSION_MISMATCH"}
	match request.get("op",""):
		"catalog":
			var starters: Array=[]
			for id in catalog.deck_ids():starters.append({"id":id,"name":catalog.source.powers.get(id,id),"cards":catalog.deck(id)})
			return {"ok":true,"catalog":{"profile":Catalog.PROFILE_ID,"fingerprint":catalog.fingerprint(),"card_count":catalog.all_cards().size(),"deck_size":30,"hero_hp":30,"starters":starters}}
		"validate_deck":return _selection(request.get("selection"))
		"create":
			if not request.get("players") is Array or request.players.size()!=2 or not request.players[0] is String or not request.players[1] is String or request.players[0]==request.players[1]:return {"ok":false,"error":"INVALID_PLAYERS"}
			var selections: Array=request.get("loadouts",[null,null])
			if selections.size()!=2:return {"ok":false,"error":"INVALID_DECK"}
			var decks: Array=[];var loadouts: Array=[]
			for value in selections:
				var selected=_selection(value)
				if not selected.ok:return selected
				decks.append(selected.cards);loadouts.append(selected.selection)
			var seed_value: int=int(str(request.get("seed",0)).sha256_text().substr(0,8).hex_to_int())
			var session=Session.new()
			if not session.start_duel(decks,seed_value):return {"ok":false,"error":"START_FAILED"}
			return _response(session,request.players,seed_value,loadouts,[])
		"apply", "verify":
			var restored=_restore(request.get("state"))
			if not restored.ok:return restored
			var session=restored.session
			var persisted: Dictionary=request.state
			if request.op=="verify":return _response(session,persisted.players,int(persisted.seed),persisted.loadouts,[])
			var player: Variant=request.get("player")
			if not player is String or not player in persisted.players:return {"ok":false,"error":"FORBIDDEN"}
			var action: Variant=request.get("action")
			if not action is Dictionary:return {"ok":false,"error":"INVALID_ACTION"}
			var name: String="";var args: Array=[]
			if action.size()==1 and action.get("type")=="concede":name="concede"
			elif action.size()==3 and action.get("type")=="command" and action.get("name") is String and action.name in COMMANDS and action.get("args") is Array:
				name=action.name;args=action.args.duplicate(true)
			else:return {"ok":false,"error":"INVALID_ACTION"}
			if args.size()>5 or JSON.stringify(args).length()>1024:return {"ok":false,"error":"INVALID_ARGUMENTS"}
			args.push_front("hero" if persisted.players[0]==player else "enemy")
			var offset: int=session.model.events.size()
			var reply: Dictionary=session.command(name,args)
			if not reply.ok and not reply.get("accepted",false):return {"ok":false,"error":"ILLEGAL_COMMAND","reason":reply.get("reason","")}
			var events: Array=[]
			for event in session.model.events.slice(offset):events.append({"type":str(event.get("kind","rule")),"player_id":persisted.players[0] if event.get("side")=="hero" else persisted.players[1] if event.get("side")=="enemy" else ""})
			return _response(session,persisted.players,int(persisted.seed),persisted.loadouts,events)
	return {"ok":false,"error":"UNSUPPORTED_OPERATION"}

func _restore(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("profile")!=Catalog.PROFILE_ID or value.get("catalog_sha256")!=catalog.fingerprint() or not value.get("commands") is Array or value.commands.size()>20000 or not value.get("players") is Array or value.players.size()!=2 or not value.get("loadouts") is Array or value.loadouts.size()!=2:return {"ok":false,"error":"INVALID_SERVER_STATE"}
	var decks: Array=[]
	for selection in value.loadouts:
		var selected=_selection(selection)
		if not selected.ok:return selected
		decks.append(selected.cards)
	var session=Session.new()
	if not session.start_duel(decks,int(value.seed)):return {"ok":false,"error":"START_FAILED"}
	for expected in value.commands:
		if not expected is Dictionary or not expected.get("name") is String or not expected.get("args") is Array or not expected.name in COMMANDS+["concede"]:return {"ok":false,"error":"INVALID_JOURNAL"}
		var reply=session.command(expected.name,expected.args)
		if not reply.ok and not reply.get("accepted",false):return {"ok":false,"error":"REPLAY_COMMAND_REJECTED"}
		if Session.event_digest([session.commands.back()])!=Session.event_digest([expected]):return {"ok":false,"error":"REPLAY_DIVERGED"}
	if Session.digest(session.model.snapshot())!=value.get("final") or Session.event_digest(session.model.events)!=value.get("event_sha256"):return {"ok":false,"error":"REPLAY_DIVERGED"}
	return {"ok":true,"session":session}

func _response(session, players: Array, seed_value: int, loadouts: Array, events: Array) -> Dictionary:
	var model=session.model
	var winner: Variant=model.state.winner
	var result: Variant=null if winner==null else {"winner_id":null if winner=="draw" else players[0] if winner=="hero" else players[1],"reason":"concede" if not session.commands.is_empty() and session.commands.back().name=="concede" else "duel"}
	var views: Dictionary={players[0]:_view(model,"hero",players),players[1]:_view(model,"enemy",players)}
	var turn: Variant=null if result!=null else players[0] if model.state.active=="hero" else players[1]
	if model.state.stage in ["mulligan","origins"]:
		var stage_key="mulligan" if model.state.stage=="mulligan" else "origin"
		turn=players[0] if not model.human_opening[stage_key].hero else players[1]
	elif model.state.stage=="second":turn=players[1] if model.state.coin=="hero" else players[0]
	var state={"version":1,"profile":Catalog.PROFILE_ID,"catalog_sha256":catalog.fingerprint(),"players":players,"seed":seed_value,"loadouts":loadouts,"commands":session.commands,"final":Session.digest(model.snapshot()),"event_sha256":Session.event_digest(model.events),"rng":{"state":model.rng.state,"calls":model.rng.calls},"views":views,"result":result,"turn_player_id":turn}
	return {"ok":true,"state":state,"views":views,"events":events,"result":result,"turn_player_id":turn}

func _public_player(model,side: String, own: bool) -> Dictionary:
	var source: Dictionary=model.snapshot()[side]
	var value: Dictionary={}
	for key in ["phase","pendingDraw","hp","maxHp","ward","block","resonance","energy","turns","pendingTarget","pendingShift","weak","fatigue","burstUsed","cycled","seals","cycles","tacticUsed","fortifyUsed","lanes","relic","relic_used","convergence","deckCount","handCount","discard"]:
		value[key]=source[key]
	if own:value["hand"]=source.hand
	return value

func _view(model,side: String, players: Array) -> Dictionary:
	var other: String=model._other(side)
	var index=0 if side=="hero" else 1
	var state: Dictionary=model.state
	var revealed=state.stage in ["second","battle"]
	return {"rules_profile":Catalog.PROFILE_ID,"stage":state.stage,"active_player_id":players[0] if state.active=="hero" else players[1],"coin_player_id":null if state.coin==null else players[0] if state.coin=="hero" else players[1],"winner_player_id":null if state.winner==null or state.winner=="draw" else players[0] if state.winner=="hero" else players[1],"finished":state.winner!=null,"round":state.round,"self":_public_player(model,side,true),"opponent":_public_player(model,other,false),"origins":{"self":state.origins[side],"opponent":state.origins[other] if revealed else -1},"opening":{"mulligan_done":model.human_opening.mulligan[side],"opponent_mulligan_done":model.human_opening.mulligan[other],"origin_done":model.human_opening.origin[side],"opponent_origin_done":model.human_opening.origin[other],"second_player_id":null if state.coin==null else players[1] if state.coin=="hero" else players[0],"second_path":state.second_path,"second_card":state.second_card},"legal_actions":_legal_actions(model,side)}

func _legal_actions(model, side: String) -> Array:
	var state: Dictionary=model.state
	var result: Array=[]
	if state.winner!=null:return result
	if state.stage=="mulligan":
		if not model.human_opening.mulligan[side]:
			for mask in 1<<state[side].hand.size():
				var indices: Array=[]
				for i in state[side].hand.size():
					if mask & (1<<i):indices.append(i)
				result.append({"name":"mulligan","args":[indices]})
		return result
	if state.stage=="origins":
		if not model.human_opening.origin[side]:
			for lane in 5:result.append({"name":"origin","args":[lane]})
		return result
	if state.stage=="second":
		if side!=state.coin:
			result.append({"name":"openingDone","args":[]})
			if not state.second_path:
				for lane in 5:result.append({"name":"secondOrigin","args":[lane]})
			if not state.second_card:
				for i in state[side].hand.size():result.append({"name":"secondCard","args":[i]})
		return result
	if state.active!=side:return result
	var candidates: Array=[]
	var player: Dictionary=state[side]
	if player.phase=="draw":
		candidates.append({"name":"finishDraw","args":[]})
		for i in player.hand.size():candidates.append({"name":"burn","args":[i]})
	elif player.pendingTarget!=null:
		for lane in 5:candidates.append({"name":"chooseStrikeTarget","args":[lane]})
	elif player.pendingShift!=null:
		candidates.append({"name":"skipShift","args":[]})
		for from in 5:
			for to in 5:candidates.append({"name":"moveCreature","args":[from,to]})
	else:
		for i in player.hand.size():
			for lane in model.legal_targets(side,i):result.append({"name":"play","args":[i,lane]})
		for name in ["endTurn","recover","activateRelic"]:candidates.append({"name":name,"args":[]})
		for faction in catalog.deck_ids():candidates.append({"name":"burst","args":[faction]})
		for lane in 5:
			candidates.append({"name":"fortify","args":[lane]})
			for to in 5:candidates.append({"name":"tacticalMove","args":[lane,to]})
		for a in 3:
			for b in range(a+1,4):
				for c in range(b+1,5):candidates.append({"name":"converge","args":[[a,b,c]]})
	for candidate in candidates:
		var probe=model._validation_probe()
		var args: Array=candidate.args.duplicate(true);args.push_front(side)
		var reply: Dictionary=probe.execute(candidate.name,args)
		if reply.ok or reply.get("accepted",false):result.append(candidate)
	return result
