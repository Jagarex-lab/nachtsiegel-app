extends RefCounted
## Versioned local-only storage. Card ownership and money are not combat inputs.
const VERSION := 2
const MAX_BYTES := 4*1024*1024
const CURRENT_PROFILE := "user://orafold_profile_v2.json"
const LEGACY_PROFILE := "user://orafold_alpha_profile_v1.json"
const WEB_KEY := "orafold.profile.v2"
const WEB_STORAGE_SCRIPT := """(request) => {
  const key = 'orafold.profile.v2', backup = key + '.bak';
  const reply = value => JSON.stringify(value);
  let storage;
  try {
    storage = globalThis.localStorage;
    const before = storage.getItem(key), previousBackup = storage.getItem(backup);
    if (request.operation === 'read') return reply({ok:true, primary:before, backup:previousBackup});
    if (request.operation !== 'write' || typeof request.value !== 'string') return reply({ok:false, error:'invalid_request'});
    if (before !== request.expected_primary || previousBackup !== request.expected_backup) return reply({ok:false, error:'storage_changed'});
    let backupChanged = false;
    try {
      if (typeof request.backup_value === 'string' && request.backup_value !== previousBackup) {
        storage.setItem(backup, request.backup_value);
        backupChanged = true;
      }
      storage.setItem(key, request.value);
      return reply({ok:true});
    } catch (error) {
      if (backupChanged) {
        try {
          if (previousBackup === null) storage.removeItem(backup);
          else storage.setItem(backup, previousBackup);
        } catch (_) { return reply({ok:false, error:'backup_rollback_failed'}); }
      }
      return reply({ok:false, error:error && error.name === 'QuotaExceededError' ? 'storage_full' : 'storage_unavailable'});
    }
  } catch (_) { return reply({ok:false, error:'storage_unavailable'}); }
}"""
const ProductionCatalog=preload("res://scripts/production/catalog.gd")
const LegacyValidator=preload("res://scripts/legacy/deck_validator.gd")
var path: String
var migration_path: String
var catalog
var write_blocked := false
var _import_source := ""
var _import_bytes := PackedByteArray()
var _loaded := false
var _last_good_text := ""
var last_warning := ""

func _init(profile_path: String=CURRENT_PROFILE, import_path: String="") -> void:
	path=profile_path
	# Custom stores/tests never discover an unrelated user's old profile.
	migration_path=LEGACY_PROFILE if import_path.is_empty() and profile_path==CURRENT_PROFILE else import_path

static func defaults() -> Dictionary:
	return {"version":VERSION,"catalog_profile":"production-550-v1","decks":{},"quarantined_decks":{},"wins":0,"reduced_motion":false,"last_seed":8802026,"faction":"houses","difficulty":2}

func _read_file(candidate: String) -> Dictionary:
	var file=FileAccess.open(candidate,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES:return {}
	var bytes=file.get_buffer(file.get_length())
	file.close()
	var parser=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK:return {}
	return {"value":parser.data,"bytes":bytes}

func _read(candidate: String) -> Variant:return _read_file(candidate).get("value")

func _parse_text(text: String) -> Variant:
	if text.to_utf8_buffer().size()>MAX_BYTES:return null
	var parser=JSON.new()
	return parser.data if parser.parse(text)==OK else null

func _web_backend_enabled() -> bool:return OS.has_feature("web") and path==CURRENT_PROFILE

func _mirror_io(request: Dictionary) -> Dictionary:
	var response=JavaScriptBridge.eval("("+WEB_STORAGE_SCRIPT+")("+JSON.stringify(request)+")")
	if not response is String:return {"ok":false,"error":"storage_unavailable"}
	var value: Variant=JSON.parse_string(response)
	return value if value is Dictionary and value.get("ok") is bool else {"ok":false,"error":"storage_unavailable"}

func _load_web_mirror() -> Dictionary:
	var response=_mirror_io({"operation":"read"})
	if not response.ok:return {"found":false,"issues":["Browser-Speicher nicht verfügbar; Speichern benötigt freien lokalen Speicher."]}
	var issues: Array=[]
	for key in ["primary","backup"]:
		var text: Variant=response.get(key)
		if not text is String:continue
		var value: Variant=_parse_text(text)
		if _foreign_profile(value):
			return {"found":false,"blocked":true,"issues":["Browserprofil gehört zu einer neueren oder unbekannten Version; unverändert aufbewahrt."]}
		if _valid_root(value):
			if key=="backup":issues.append("Die letzte gültige Browser-Sicherung wurde geladen.")
			return {"found":true,"captured":{"value":value,"bytes":text.to_utf8_buffer()},"source":"localStorage:"+WEB_KEY+(".bak" if key=="backup" else ""),"recovered":key=="backup","issues":issues}
		issues.append("Browserprofil beschädigt; weitere lokale Sicherungen werden geprüft.")
	return {"found":false,"issues":issues}

func _save_web_mirror(serialized: String) -> bool:
	var response=_mirror_io({"operation":"read"})
	if not response.ok:return false
	var backup_value: Variant=null
	for key in ["primary","backup"]:
		var text: Variant=response.get(key)
		if not text is String:continue
		var value: Variant=_parse_text(text)
		if _foreign_profile(value):write_blocked=true;return false
		if _valid_root(value):backup_value=text;break
	if backup_value==null and not _last_good_text.is_empty():backup_value=_last_good_text
	var result=_mirror_io({"operation":"write","value":serialized,"backup_value":backup_value,"expected_primary":response.get("primary"),"expected_backup":response.get("backup")})
	return result.ok

func _exists(candidate: String) -> bool:
	return FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate))

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

func _valid_root(value: Variant) -> bool:
	return value is Dictionary and _whole(value.get("version"),1,VERSION) and int(value.version) in [1,VERSION] and value.get("decks") is Dictionary

func _validator(mode: String, ids: Array) -> Dictionary:
	if mode=="legacy":return LegacyValidator.new().validate(ids)
	if catalog==null:catalog=ProductionCatalog.new()
	return catalog.validate(ids)

func _foreign_profile(value: Variant) -> bool:
	if not value is Dictionary:return false
	var version: Variant=value.get("version")
	if not (version is int or version is float) or not is_finite(float(version)):return false
	if float(version)>VERSION:return true
	return _whole(version,VERSION,VERSION) and (not value.get("catalog_profile") is String or value.catalog_profile!="production-550-v1")

func load_profile() -> Dictionary:
	_loaded=true
	write_blocked=false
	_import_source="";_import_bytes=PackedByteArray()
	_last_good_text="";last_warning=""
	var result=defaults();var issues: Array=[];var recovered := false
	var source_path=path
	var captured: Dictionary={}
	var mirror_found := false
	if _web_backend_enabled():
		var mirror=_load_web_mirror()
		issues.append_array(mirror.issues)
		if mirror.get("blocked",false):
			write_blocked=true
			return {"profile":result,"issues":issues,"recovered":false}
		if mirror.found:
			mirror_found=true;captured=mirror.captured;source_path=mirror.source;recovered=mirror.recovered
	# A current-namespace backup outranks stale data from an old cached client,
	# even when the current main file was removed or a rename was interrupted.
	var importing=not mirror_found and not migration_path.is_empty() and not _exists(path) and not _exists(path+".bak")
	if not mirror_found:
		if importing:source_path=migration_path
		captured=_read_file(source_path)
	var loaded: Variant=captured.get("value")
	if _foreign_profile(loaded):
		write_blocked=true
		return {"profile":result,"issues":["Spielstand gehört zu einer neueren oder unbekannten Version; unverändert aufbewahrt."],"recovered":false}
	if not _valid_root(loaded):
		if _exists(source_path):issues.append("Lokaler Spielstand beschädigt oder unbekanntes Format.")
		source_path+=".bak"
		captured=_read_file(source_path)
		loaded=captured.get("value")
		if _foreign_profile(loaded):
			write_blocked=true
			return {"profile":result,"issues":["Sicherung gehört zu einer neueren oder unbekannten Version; unverändert aufbewahrt."],"recovered":false}
		if _valid_root(loaded):recovered=true;issues.append("Die letzte gültige Sicherung wurde geladen.")
		else:
			if _exists(source_path):issues.append("Auch die vorhandene Sicherung ist beschädigt oder unbekannt.")
			return {"profile":result,"issues":issues,"recovered":false}
	if importing:
		# Preserve the exact bytes that were actually parsed, not a later write by
		# an old open tab between import and the first explicit current save.
		_import_source=source_path
		_import_bytes=captured.bytes.duplicate()
		issues.append("Älterer Spielstand wurde lesend übernommen; das alte Profil bleibt unverändert.")
	_last_good_text=captured.bytes.get_string_from_utf8()
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
	return {"profile":result,"issues":issues,"recovered":recovered,"migrated":importing or int(loaded.version)<VERSION,"imported":importing,"migration_source":source_path if importing else ""}

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
	if not _loaded and not migration_path.is_empty():load_profile()
	last_warning=""
	if not _web_backend_enabled() and _foreign_profile(_read(path)):write_blocked=true
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
	if _web_backend_enabled():
		# The independent synchronous mirror is authoritative. An old cached tab
		# can replace/delete the entire IDBFS mount, including unknown filenames.
		if not _save_web_mirror(serialized):return false
		_last_good_text=serialized
		if not _save_file_serialized(serialized):last_warning="Browserprofil gespeichert; die zusätzliche Dateisicherung ist derzeit nicht verfügbar."
		return true
	if not _save_file_serialized(serialized):return false
	_last_good_text=serialized
	return true

func _save_file_serialized(serialized: String) -> bool:
	# A foreign secondary file is preserved even when the authoritative Web
	# profile already committed successfully.
	if _foreign_profile(_read(path)):return false
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
	elif not _import_bytes.is_empty():
		if not _save_import_backup():return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:return false
	_import_source="";_import_bytes=PackedByteArray()
	return true

func _save_import_backup() -> bool:
	var target=path+".bak"
	var temporary=target+".import.tmp"
	var absolute=ProjectSettings.globalize_path(target)
	if DirAccess.dir_exists_absolute(absolute):return false
	var writer=FileAccess.open(temporary,FileAccess.WRITE)
	if writer==null:return false
	writer.store_buffer(_import_bytes);writer.flush()
	var write_error=writer.get_error();writer.close()
	if write_error!=OK:return false
	if FileAccess.get_file_as_bytes(temporary)!=_import_bytes or not _valid_root(_read(temporary)):return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),absolute)==OK
