extends RefCounted
## Independent local save. Never reads or writes the Alpha or Arvess profiles.
const FORMAT := "ORAFOLD-CAMPAIGN"
const VERSION := 2
const DEFAULT_PATH := "user://orafold_campaign_v2.json"
const WEB_KEY := "orafold.campaign.v2"
var path: String
var data: Dictionary = defaults()
var last_error := ""
var recovered := false
var read_only := false

func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	load_progress()

static func defaults() -> Dictionary:
	return {"format":FORMAT,"schema_version":VERSION,"content_version":1,"revision":0,"campaign_id":"","unlocked_chapters":[],"completed_chapters":[],"seen_scenes":[],"decisions":{},"flags":{},"character_info":[],"relationships":{},"encounters":{},"active":{},"checkpoint":{},"reward_ledger":{},"history":[],"settings":{"locale":"de","text_speed":35.0,"reduced_motion":false,"text_scale":1.0},"sequence":0}

static func _strings(value: Variant) -> bool:
	if not value is Array: return false
	for item in value:
		if not item is String: return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value))

static func _active_shape(active: Variant) -> bool:
	if not active is Dictionary: return false
	if active.is_empty(): return true
	for key in ["campaign_id","chapter_id","scene_id"]:
		if not active.get(key) is String or active[key].is_empty(): return false
	if not active.get("battle") is Dictionary or not active.get("replay") is bool or not active.get("run_choices") is Dictionary: return false
	for key in active.run_choices:
		if not key is String or not active.run_choices[key] is String: return false
	for key in ["entered_scenes","completed_scenes"]:
		if not _strings(active.get(key)): return false
	var battle: Dictionary = active.battle
	if not battle.is_empty():
		if not battle.get("token") is String or battle.token.is_empty() or not battle.get("encounter_id") is String or battle.encounter_id.is_empty(): return false
	if not active.get("replay_baseline") is Dictionary: return false
	if active.replay:
		var baseline := defaults()
		for key in ["flags","decisions","relationships","character_info","unlocked_chapters"]:
			if not active.replay_baseline.has(key): return false
			baseline[key] = active.replay_baseline[key]
		if not valid(baseline): return false
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("format") != FORMAT or value.get("schema_version") != VERSION: return false
	for key in ["unlocked_chapters","completed_chapters","seen_scenes","character_info"]:
		if not _strings(value.get(key)): return false
	for key in ["decisions","flags","relationships","encounters","active","checkpoint","reward_ledger","settings"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("history") is Array or value.history.size() > 1024: return false
	for key in ["revision","sequence","content_version"]:
		if not _integer(value.get(key)): return false
	if not value.get("campaign_id") is String: return false
	for key in value.flags:
		if not key is String or not (value.flags[key] is String or value.flags[key] is bool or value.flags[key] is int or value.flags[key] is float): return false
		if (value.flags[key] is int or value.flags[key] is float) and not is_finite(float(value.flags[key])): return false
	for key in value.decisions:
		if not key is String or not value.decisions[key] is String: return false
	for key in value.relationships:
		if not key is String or not (value.relationships[key] is int or value.relationships[key] is float) or not is_finite(float(value.relationships[key])): return false
	for key in value.encounters:
		var stats = value.encounters[key]
		if not key is String or not stats is Dictionary: return false
		for field in ["attempts","victories","defeats"]:
			if not _integer(stats.get(field)): return false
		if not stats.get("last_token", "") is String or stats.get("last_outcome", "victory") not in ["victory","defeat"]: return false
	for entry in value.history:
		if not entry is Dictionary or not entry.get("scene_id") is String or not entry.get("text_id") is String or not entry.get("speaker_id", "") is String: return false
	for key in value.reward_ledger:
		var grant = value.reward_ledger[key]
		if not key is String or not grant is Dictionary or not grant.get("key") is String or grant.get("state") not in ["pending","delivered"]: return false
		if grant.get("type") not in ["character_info","chapter","external"] or not grant.get("target") is String or not grant.get("payload") is Dictionary: return false
	var settings: Dictionary = value.settings
	if settings.get("locale") not in ["de","en"] or not settings.get("reduced_motion") is bool: return false
	for key in ["text_speed","text_scale"]:
		if not settings.get(key) is float and not settings.get(key) is int: return false
		if not is_finite(float(settings[key])): return false
	if float(settings.text_speed)<0 or float(settings.text_speed)>100 or float(settings.text_scale)<0.8 or float(settings.text_scale)>2.0: return false
	if not _active_shape(value.active) or not _active_shape(value.checkpoint): return false
	return true

static func migrate(value: Variant) -> Variant:
	if not value is Dictionary or value.get("format") != FORMAT: return null
	var candidate: Dictionary = value.duplicate(true)
	if candidate.get("schema_version") == 1:
		candidate["schema_version"] = VERSION
		candidate["seen_scenes"] = candidate.get("visited_scenes", [])
		candidate.erase("visited_scenes")
		# Additive migration applies only to this namespace, never to legacy saves.
		for key in defaults():
			if not candidate.has(key): candidate[key] = defaults()[key]
		for cursor in ["active","checkpoint"]:
			if candidate[cursor] is Dictionary and not candidate[cursor].is_empty():
				for key in {"battle":{},"replay":false,"run_choices":{},"replay_baseline":{},"entered_scenes":[],"completed_scenes":[]}:
					if not candidate[cursor].has(key): candidate[cursor][key] = {"battle":{},"replay":false,"run_choices":{},"replay_baseline":{},"entered_scenes":[],"completed_scenes":[]}[key]
	return candidate if valid(candidate) else null

static func _future(value: Variant) -> bool:
	return value is Dictionary and value.get("format") == FORMAT and _integer(value.get("schema_version")) and int(value.schema_version) > VERSION

static func _read(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK: return null
	return parser.data

func load_progress() -> bool:
	last_error = ""
	recovered = false
	read_only = false
	var raw: Variant = _read(path)
	if _future(raw):
		read_only = true
		last_error = "save.future_version"
		return false
	var candidate: Variant = migrate(raw)
	if OS.has_feature("web") and path == DEFAULT_PATH:
		var mirror: Variant = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('"+WEB_KEY+"')||''}catch(e){return ''}})()")
		if mirror is String and not mirror.is_empty():
			var parser := JSON.new()
			if parser.parse(mirror) == OK:
				if _future(parser.data):
					read_only = true
					last_error = "save.future_version"
					return false
				var from_web: Variant = migrate(parser.data)
				if from_web is Dictionary and (candidate == null or int(from_web.revision) >= int(candidate.revision)): candidate = from_web
	if candidate == null:
		var backup: Variant = _read(path+".bak")
		if _future(backup):
			read_only = true
			last_error = "save.future_version"
			return false
		candidate = migrate(backup)
		if candidate != null:
			recovered = true
			last_error = "save.recovered_backup"
	if candidate == null:
		data = defaults()
		if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
			last_error = "save.invalid_data"
			# Keep corrupt evidence until a deliberate new campaign operation saves.
		return false
	data = candidate.duplicate(true)
	return true

func save() -> bool:
	if read_only:
		last_error = "save.future_version"
		return false
	if not valid(data):
		last_error = "save.invalid_data"
		return false
	var next: Dictionary = data.duplicate(true)
	next.revision = int(next.revision)+1
	var writer := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer == null:
		last_error = "save.write_failed"
		return false
	writer.store_string(JSON.stringify(next,"  "))
	writer.flush()
	var write_error := writer.get_error()
	writer.close()
	if write_error != OK:
		last_error = "save.write_failed"
		return false
	# Never rotate a corrupt primary over a known-good backup.
	if migrate(_read(path)) != null:
		if DirAccess.copy_absolute(path,path+".bak") != OK:
			last_error = "save.backup_failed"
			return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		last_error = "save.replace_failed"
		return false
	data = next
	last_error = ""
	if OS.has_feature("web") and path == DEFAULT_PATH:
		var quoted := JSON.stringify(JSON.stringify(next))
		var mirrored: Variant = JavaScriptBridge.eval("(()=>{try{localStorage.setItem('"+WEB_KEY+"',"+quoted+");return true}catch(e){return false}})()")
		# IDBFS write remains valid; surface mirror failure instead of claiming a rollback.
		# The Web bridge may return JS booleans as numeric 0/1 Variants.
		if not bool(mirrored): last_error = "save.browser_mirror_unavailable"
	return true
