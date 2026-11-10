extends RefCounted
const Legacy=preload("res://scripts/legacy/battle_engine.gd")
const Alpha=preload("res://scripts/alpha/model.gd")
const LegacyCatalog=preload("res://scripts/legacy/catalog.gd")
const AlphaCatalog=preload("res://scripts/alpha/catalog.gd")
const PROFILE="user://orafold_alpha_profile_v1.json"
var model
var mode := "alpha"
var setup: Dictionary={}
var commands: Array=[]
var profile: Dictionary={"version":1,"decks":{},"wins":0,"reduced_motion":false,"last_seed":8802026,"faction":"houses","difficulty":2}
var legacy_text: Dictionary
func _init() -> void:
	legacy_text=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/display_de.json")).cards
	if FileAccess.file_exists(PROFILE):
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(PROFILE))==OK:
			var loaded=parser.data
			if loaded is Dictionary and loaded.get("version")==1 and loaded.get("decks") is Dictionary:
				if loaded.get("faction") in ["houses","stillwatch","morph","ninth"]:profile.faction=loaded.faction
				if loaded.get("difficulty") in [1,2,5]:profile.difficulty=int(loaded.difficulty)
				if loaded.get("reduced_motion") is bool:profile.reduced_motion=loaded.reduced_motion
				if loaded.get("wins") is float or loaded.get("wins") is int:profile.wins=maxi(0,int(loaded.wins))
				if loaded.get("last_seed") is float or loaded.get("last_seed") is int:profile.last_seed=int(loaded.last_seed)
				for key in loaded.decks:
					var value=loaded.decks[key]
					if not key is String or not value is Dictionary or not value.get("cards") is Array or not value.get("mode") in ["alpha","legacy"]:continue
					var validation=AlphaCatalog.new().validate(value.cards) if value.mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(value.cards)
					if validation.ok:profile.decks[key]=value.duplicate(true)

func card(id: String) -> Dictionary:
	var c: Dictionary=model.catalog.card(id) if model!=null else AlphaCatalog.new().card(id)
	if mode=="legacy" and legacy_text.has(id):c.name=legacy_text[id].name;c.description=legacy_text[id].description
	return c
func start_match(rule_mode: String, deck: Array, seed_value: int, difficulty: int=2, enemy_deck: Array=[], convergence: bool=true) -> bool:
	if not rule_mode in ["alpha","legacy"]:return false
	mode=rule_mode
	var candidate=Alpha.new() if mode=="alpha" else Legacy.new()
	var ok := false
	if mode=="alpha":
		candidate.convergence_enabled=convergence
		if enemy_deck.is_empty():enemy_deck=candidate.catalog.deck("stillwatch")
		ok=candidate.start_alpha(deck,enemy_deck,seed_value,difficulty)
	else:ok=candidate.start_match(deck,seed_value,difficulty)
	if not ok:return false
	model=candidate;commands=[]
	setup={"mode":mode,"deck":deck.duplicate(),"enemy_deck":enemy_deck.duplicate(),"seed":seed_value,"difficulty":difficulty,"convergence":convergence}
	profile.last_seed=seed_value;return true
func command(name: String, args: Array) -> Dictionary:
	var before=model.snapshot();var offset: int=model.events.size()
	var reply: Dictionary=model.execute(name,args)
	if reply.ok:
		commands.append({"name":name,"args":args.duplicate(true),"before":digest(before),"after":digest(model.snapshot()),"first_event":offset,"last_event":model.events.size()-1})
		if before.winner==null and model.state.winner!=null:
			if model.state.winner=="hero":profile.wins=int(profile.wins)+1
			save_profile()
	return reply
static func digest(value: Dictionary) -> String:return JSON.stringify(value,"",true).sha256_text()
func audit() -> Dictionary:
	return {"format":"ORAFOLD-LOCAL-REPLAY","version":1,"setup":setup.duplicate(true),"commands":commands.duplicate(true),"final":digest(model.snapshot()),"winner":model.state.winner}
static func replay(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("format")!="ORAFOLD-LOCAL-REPLAY" or data.get("version")!=1 or not data.get("setup") is Dictionary or not data.get("commands") is Array:return {"ok":false,"error":"Unbekanntes Replayformat."}
	var s=load("res://scripts/alpha/session.gd").new()
	var config: Dictionary=data.setup
	for key in ["mode","deck","enemy_deck","seed","difficulty","convergence"]:
		if not config.has(key):return {"ok":false,"error":"Fehlende Startparameter."}
	if not config.mode in ["legacy","alpha"] or not config.deck is Array or not config.enemy_deck is Array:return {"ok":false,"error":"Ungültiges Replay."}
	if not s.start_match(config.mode,config.deck,int(config.seed),int(config.difficulty),config.enemy_deck,bool(config.convergence)):return {"ok":false,"error":"Ungültiges Startdeck."}
	for i in data.commands.size():
		var c=data.commands[i]
		if not c is Dictionary or not c.get("name") is String or not c.get("args") is Array or c.get("before")!=digest(s.model.snapshot()):return {"ok":false,"error":"Ausgangszustand abweichend.","step":i}
		if not s.model.execute(c.name,c.args).ok or c.get("after")!=digest(s.model.snapshot()):return {"ok":false,"error":"Befehl oder Folgezustand abweichend.","step":i}
	return {"ok":data.get("final")==digest(s.model.snapshot()),"state":s.model.snapshot(),"steps":data.commands.size(),"events":s.model.events}
func save_deck(key: String, ids: Array, rule_mode: String) -> Dictionary:
	var result: Dictionary=AlphaCatalog.new().validate(ids) if rule_mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(ids)
	if not result.ok:return result
	var slot=key.get_slice(":",key.get_slice_count(":")-1)
	if rule_mode=="alpha" and slot in AlphaCatalog.new().deck_ids() and result.faction not in [slot,"neutral"]:return {"ok":false,"message":"Deck passt nicht zur gewählten Macht."}
	profile.decks[key]={"mode":rule_mode,"cards":ids.duplicate()}
	if not save_profile():return {"ok":false,"message":"Speichern fehlgeschlagen."}
	return {"ok":true,"message":"Deck gespeichert."}
func save_profile() -> bool:
	var path=ProjectSettings.globalize_path(PROFILE)
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(profile));file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK
func export_replay() -> bool:
	var text=JSON.stringify(audit(),"  ")
	var file=FileAccess.open("user://orafold_last_replay.json",FileAccess.WRITE)
	if file==null:return false
	file.store_string(text);file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{const u=URL.createObjectURL(new Blob(["+JSON.stringify(text)+"],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='orafold-replay.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)})()")
	return true
