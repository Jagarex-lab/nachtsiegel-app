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
const Store=preload("res://scripts/production/profile_store.gd")
const ProductionCatalog=preload("res://scripts/production/catalog.gd")
const PRODUCTION_PROFILE := "production-550-v1"
const ARCHIVE_PROFILE := "alpha-55-v1"
var profile: Dictionary=Store.defaults()
var profile_issues: Array=[]
var legacy_text: Dictionary
var production_catalog
var store=Store.new(PROFILE)
func _init() -> void:
	legacy_text=JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy/display_de.json")).cards
	var loaded=store.load_profile()
	profile=loaded.profile;profile_issues=loaded.issues

func active_catalog():
	if production_catalog==null:production_catalog=ProductionCatalog.new()
	return production_catalog

func card(id: String) -> Dictionary:
	var c: Dictionary=model.catalog.card(id) if model!=null else active_catalog().card(id)
	if mode=="legacy" and legacy_text.has(id):c.name=legacy_text[id].name;c.description=legacy_text[id].description
	return c
func start_match(rule_mode: String, deck: Array, seed_value: int, difficulty: int=2, enemy_deck: Array=[], convergence: bool=true, rules_profile: String=PRODUCTION_PROFILE) -> bool:
	if not rule_mode in ["alpha","legacy"] or difficulty<1 or difficulty>5:return false
	if rule_mode=="alpha" and (not rules_profile in [PRODUCTION_PROFILE,ARCHIVE_PROFILE] or rules_profile==PRODUCTION_PROFILE and not difficulty in [1,2,5]):return false
	var candidate
	if rule_mode=="legacy":candidate=Legacy.new();rules_profile="legacy-34b3062"
	elif rules_profile==ARCHIVE_PROFILE:candidate=Alpha.new()
	else:candidate=load("res://scripts/card_system/production_model.gd").new()
	var ok := false
	if rule_mode=="alpha":
		candidate.convergence_enabled=convergence
		if enemy_deck.is_empty():enemy_deck=candidate.catalog.deck("stillwatch")
		ok=candidate.start_alpha(deck,enemy_deck,seed_value,difficulty)
	else:ok=candidate.start_match(deck,seed_value,difficulty)
	if not ok:return false
	mode=rule_mode;model=candidate;commands=[]
	setup={"mode":mode,"deck":deck.duplicate(),"enemy_deck":enemy_deck.duplicate(),"seed":seed_value,"difficulty":difficulty,"convergence":convergence,"rules_profile":rules_profile,"catalog_sha256":candidate.catalog.fingerprint() if rules_profile==PRODUCTION_PROFILE else "archived"}
	profile.last_seed=seed_value;return true
func command(name: String, args: Array) -> Dictionary:
	var before=model.snapshot();var offset: int=model.events.size()
	var reply: Dictionary=model.execute(name,args)
	if reply.ok or reply.get("accepted",false):
		commands.append({"name":name,"args":args.duplicate(true),"before":digest(before),"after":digest(model.snapshot()),"first_event":offset,"last_event":model.events.size()-1,"event_sha256":event_digest(model.events.slice(offset)),"result_ok":bool(reply.ok),"accepted":true})
		if before.winner==null and model.state.winner!=null:
			if model.state.winner=="hero":profile.wins=mini(2147483647,int(profile.wins)+1)
			save_profile()
	return reply
static func digest(value: Dictionary) -> String:return JSON.stringify(value,"",true).sha256_text()
static func event_digest(value: Array) -> String:
	# JSON has one number type. Godot's parser reads 0 as 0.0; this must not
	# turn the same ordered summon event into a different replay. Normalize only
	# event transport encoding, keeping the historical v1 state digest untouched.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true).sha256_text()
static func _hash(value: Variant) -> bool:return value is String and value.length()==64 and value.is_valid_hex_number(false)
func audit() -> Dictionary:
	return {"format":"ORAFOLD-LOCAL-REPLAY","version":2,"setup":setup.duplicate(true),"commands":commands.duplicate(true),"final":digest(model.snapshot()),"winner":model.state.winner,"event_sha256":event_digest(model.events)}
static func replay(data: Variant) -> Dictionary:return _reconstruct(data,-1,true)
static func replay_prefix(data: Variant, steps: int) -> Dictionary:return _reconstruct(data,steps,false)
static func _reconstruct(data: Variant, steps: int, verify_final: bool) -> Dictionary:
	if not data is Dictionary or not data.get("format") is String or data.format!="ORAFOLD-LOCAL-REPLAY" or not Store._whole(data.get("version"),1,2) or not int(data.version) in [1,2] or not data.get("setup") is Dictionary or not data.get("commands") is Array:return {"ok":false,"error":"Unbekanntes Replayformat."}
	if not _hash(data.get("final")) or not (data.get("winner")==null or data.get("winner") is String and data.winner in ["hero","enemy","draw"]):return {"ok":false,"error":"Ungültige Replay-Metadaten."}
	if int(data.version)==2 and not _hash(data.get("event_sha256")):return {"ok":false,"error":"Ungültige Ereignisprüfsumme."}
	if data.commands.size()>100000:return {"ok":false,"error":"Replay überschreitet die technische Befehlsgrenze."}
	var s=load("res://scripts/alpha/session.gd").new()
	var config: Dictionary=data.setup
	for key in ["mode","deck","enemy_deck","seed","difficulty","convergence"]:
		if not config.has(key):return {"ok":false,"error":"Fehlende Startparameter."}
	if not config.mode is String or not config.mode in ["legacy","alpha"] or not config.deck is Array or not config.enemy_deck is Array or not config.convergence is bool:return {"ok":false,"error":"Ungültiges Replay."}
	for key in ["seed","difficulty"]:
		var number: Variant=config[key]
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)):return {"ok":false,"error":"Ungültiger Zahlenwert im Replay."}
	if not Store._whole(config.difficulty,1,5):return {"ok":false,"error":"Unbekannter KI-Schwierigkeitsgrad."}
	if int(data.version)==2 and not config.get("rules_profile") is String:return {"ok":false,"error":"Ungültige Regelkennung."}
	var rules_profile: String=ARCHIVE_PROFILE if int(data.version)==1 else config.get("rules_profile","")
	if int(data.version)==1 and config.mode=="legacy":rules_profile="legacy-34b3062"
	if config.mode=="legacy" and rules_profile!="legacy-34b3062":return {"ok":false,"error":"Regelprofil passt nicht zum Legacy-Replay."}
	if config.mode=="alpha" and not rules_profile in [ARCHIVE_PROFILE,PRODUCTION_PROFILE]:return {"ok":false,"error":"Unbekanntes Alpha-Regelprofil."}
	if int(data.version)==2 and rules_profile!=PRODUCTION_PROFILE and (not config.get("catalog_sha256") is String or config.catalog_sha256!="archived"):return {"ok":false,"error":"Ungültige Archivkennung."}
	if rules_profile==PRODUCTION_PROFILE and (not int(config.difficulty) in [1,2,5] or not _hash(config.get("catalog_sha256")) or config.catalog_sha256!=s.active_catalog().fingerprint()):return {"ok":false,"error":"Replay benötigt einen anderen Kartenkatalog; keine stillschweigende Neuinterpretation."}
	if not s.start_match(config.mode,config.deck,int(config.seed),int(config.difficulty),config.enemy_deck,bool(config.convergence),rules_profile):return {"ok":false,"error":"Ungültiges Startdeck oder Regelprofil."}
	if steps < -1 or steps>data.commands.size():return {"ok":false,"error":"Ungültiger Replay-Schritt."}
	var count: int=data.commands.size() if steps<0 else steps
	for i in count:
		var c=data.commands[i]
		if not c is Dictionary or not c.get("name") is String or not c.get("args") is Array or not _hash(c.get("before")) or not _hash(c.get("after")) or c.before!=digest(s.model.snapshot()):return {"ok":false,"error":"Ausgangszustand abweichend.","step":i}
		if int(data.version)==2 and (not c.get("result_ok") is bool or not c.get("accepted") is bool or not c.accepted or not _hash(c.get("event_sha256")) or not Store._whole(c.get("first_event"),0,10000000) or not Store._whole(c.get("last_event"),-1,10000000)):return {"ok":false,"error":"Ungültiger Befehlsnachweis.","step":i}
		var offset: int=s.model.events.size()
		var outcome: Dictionary=s.model.execute(c.name,c.args)
		var committed=bool(outcome.ok) or bool(outcome.get("accepted",false))
		if not committed or (int(data.version)==2 and c.get("result_ok")!=bool(outcome.ok)) or (int(data.version)==1 and not outcome.ok) or c.get("after")!=digest(s.model.snapshot()):return {"ok":false,"error":"Befehl oder Folgezustand abweichend.","step":i}
		if int(data.version)==2 and (c.get("first_event")!=offset or c.get("last_event")!=s.model.events.size()-1 or c.get("event_sha256")!=event_digest(s.model.events.slice(offset))):return {"ok":false,"error":"Ereignisreihenfolge abweichend.","step":i}
	var correct=not verify_final or (data.get("final")==digest(s.model.snapshot()) and data.get("winner")==s.model.state.winner)
	if verify_final and int(data.version)==2:correct=correct and data.get("event_sha256")==event_digest(s.model.events)
	return {"ok":correct,"state":s.model.snapshot(),"steps":count,"events":s.model.events}

func save_deck(key: String, ids: Array, rule_mode: String) -> Dictionary:
	if not rule_mode in ["alpha","legacy"]:return {"ok":false,"message":"Unbekanntes Regelprofil."}
	var result: Dictionary=active_catalog().validate(ids) if rule_mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(ids)
	if not result.ok:return result
	var slot=key.get_slice(":",key.get_slice_count(":")-1)
	if rule_mode=="alpha" and slot in active_catalog().deck_ids() and result.faction not in [slot,"neutral"]:return {"ok":false,"message":"Deck passt nicht zur gewählten Macht."}
	var previous=profile.decks.duplicate(true)
	profile.decks[key]={"mode":rule_mode,"cards":ids.duplicate(),"catalog_profile":PRODUCTION_PROFILE if rule_mode=="alpha" else "legacy-34b3062"}
	if not save_profile():
		profile.decks=previous
		return {"ok":false,"message":"Speichern fehlgeschlagen; bisheriges Deck beibehalten."}
	return {"ok":true,"message":"Deck gespeichert."}
func save_profile() -> bool:return store.save_profile(profile)

func export_replay() -> bool:
	var text=JSON.stringify(audit(),"  ")
	var file=FileAccess.open("user://orafold_last_replay.json",FileAccess.WRITE)
	if file==null:return false
	file.store_string(text);file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{const u=URL.createObjectURL(new Blob(["+JSON.stringify(text)+"],{type:'application/json'}));const a=document.createElement('a');a.href=u;a.download='orafold-replay.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)})()")
	return true
