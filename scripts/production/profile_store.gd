extends RefCounted
## Versioned local-only storage. Card ownership and money are not combat inputs.
const VERSION := 2
const MAX_BYTES := 4*1024*1024
const AlphaCatalog=preload("res://scripts/alpha/catalog.gd")
const ProductionCatalog=preload("res://scripts/production/catalog.gd")
const LegacyValidator=preload("res://scripts/legacy/deck_validator.gd")
var path: String
var catalog
var write_blocked := false

func _init(profile_path: String="user://orafold_alpha_profile_v1.json") -> void:path=profile_path

static func defaults() -> Dictionary:
	return {"version":VERSION,"catalog_profile":"production-550-v1","decks":{},"quarantined_decks":{},"wins":0,"reduced_motion":false,"last_seed":8802026,"faction":"houses","difficulty":2}

func _read(candidate: String) -> Variant:
	var file=FileAccess.open(candidate,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES:return null
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK:return null
	return parser.data

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

func _valid_root(value: Variant) -> bool:
	return value is Dictionary and _whole(value.get("version"),1,VERSION) and int(value.version) in [1,VERSION] and value.get("decks") is Dictionary

func _validator(mode: String, ids: Array) -> Dictionary:
	if mode=="legacy":return LegacyValidator.new().validate(ids)
	if catalog==null:catalog=ProductionCatalog.new()
	return catalog.validate(ids)

func load_profile() -> Dictionary:
	var result=defaults();var issues: Array=[];var recovered := false
	var loaded=_read(path)
	if loaded is Dictionary and (loaded.get("version") is int or loaded.get("version") is float) and (float(loaded.version)>VERSION or int(loaded.version)==VERSION and loaded.get("catalog_profile")!="production-550-v1"):
		write_blocked=true
		return {"profile":result,"issues":["Spielstand gehört zu einer neueren oder unbekannten Version; unverändert aufbewahrt."],"recovered":false}
	if not _valid_root(loaded):
		if FileAccess.file_exists(path):issues.append("Lokaler Spielstand beschädigt oder unbekanntes Format.")
		loaded=_read(path+".bak")
		if _valid_root(loaded):recovered=true;issues.append("Die letzte gültige Sicherung wurde geladen.")
		else:return {"profile":result,"issues":issues,"recovered":false}
	if loaded.get("faction") in ["houses","stillwatch","morph","ninth"]:result.faction=loaded.faction
	if _whole(loaded.get("difficulty"),1,5) and int(loaded.difficulty) in [1,2,5]:result.difficulty=int(loaded.difficulty)
	if loaded.get("reduced_motion") is bool:result.reduced_motion=loaded.reduced_motion
	for key in ["wins","last_seed"]:
		var value: Variant=loaded.get(key)
		if (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)):
			result[key]=clampi(int(value),0,2147483647)
	if loaded.get("quarantined_decks") is Dictionary:result.quarantined_decks=loaded.quarantined_decks.duplicate(true)
	elif loaded.has("quarantined_decks"):
		result.quarantined_decks["__invalid_quarantine__"]={"original":loaded.quarantined_decks,"reason":"Beschädigte frühere Wiederherstellungsdaten unverändert aufbewahrt."}
		issues.append("Beschädigte frühere Wiederherstellungsdaten wurden separat aufbewahrt.")
	for key in loaded.decks:
		var value: Variant=loaded.decks[key]
		var valid_shape=key is String and value is Dictionary and value.get("cards") is Array and value.get("mode") in ["alpha","legacy"]
		var known_profile=valid_shape and (int(loaded.version)==1 or value.get("catalog_profile","production-550-v1" if value.mode=="alpha" else "legacy-34b3062") in (["alpha-55-v1","production-550-v1"] if value.mode=="alpha" else ["legacy-34b3062"]))
		var validation=_validator(value.mode,value.cards) if known_profile else {"ok":false,"message":"Ungültiges Deckformat oder unbekannter Katalogstand."}
		if validation.ok:
			result.decks[key]={"mode":value.mode,"cards":value.cards.duplicate(),"catalog_profile":"production-550-v1" if value.mode=="alpha" else "legacy-34b3062"}
		else:
			# Preserve the original IDs for recovery; never silently rewrite a deck.
			result.quarantined_decks[str(key)]={"original":value,"reason":validation.message}
			issues.append("Deck '%s' zur Wiederherstellung aufbewahrt: %s" % [str(key),validation.message])
	return {"profile":result,"issues":issues,"recovered":recovered,"migrated":int(loaded.version)<VERSION}

static func _json_safe(value: Variant, depth: int=0) -> bool:
	if depth>64:return false
	if value is float:return is_finite(value)
	if value is Dictionary:
		for key in value:
			if not key is String or not _json_safe(value[key],depth+1):return false
	elif value is Array:
		for item in value:
			if not _json_safe(item,depth+1):return false
	elif not (value==null or value is int or value is bool or value is String):return false
	return true

func save_profile(profile: Dictionary) -> bool:
	if write_blocked or not _valid_root(profile) or int(profile.version)!=VERSION or not _json_safe(profile):return false
	if not profile.get("quarantined_decks") is Dictionary:return false
	if profile.get("catalog_profile")!="production-550-v1" or not profile.get("faction") in ["houses","stillwatch","morph","ninth"] or not _whole(profile.get("difficulty"),1,5) or not int(profile.difficulty) in [1,2,5] or not profile.get("reduced_motion") is bool:return false
	for key in ["wins","last_seed"]:
		var value: Variant=profile.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>2147483647 or value!=floor(value):return false
	for key in profile.decks:
		var deck: Variant=profile.decks[key]
		if not deck is Dictionary or not deck.get("mode") in ["alpha","legacy"] or not deck.get("cards") is Array:return false
		if not deck.get("catalog_profile") is String or deck.catalog_profile!=("production-550-v1" if deck.mode=="alpha" else "legacy-34b3062") or not _validator(deck.mode,deck.cards).ok:return false
	var serialized=JSON.stringify(profile)
	if serialized.to_utf8_buffer().size()>MAX_BYTES:return false
	var absolute=ProjectSettings.globalize_path(path)
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(serialized);file.flush();var write_error=file.get_error();file.close()
	if write_error!=OK:return false
	if not _valid_root(_read(path+".tmp")):return false
	if FileAccess.file_exists(path):
		var existing=_read(path)
		if _valid_root(existing):
			if DirAccess.dir_exists_absolute(absolute+".bak") or DirAccess.copy_absolute(absolute,absolute+".bak")!=OK:return false
		elif not FileAccess.file_exists(path+".corrupt"):
			if DirAccess.dir_exists_absolute(absolute+".corrupt") or DirAccess.copy_absolute(absolute,absolute+".corrupt")!=OK:return false
	return DirAccess.rename_absolute(absolute+".tmp",absolute)==OK
