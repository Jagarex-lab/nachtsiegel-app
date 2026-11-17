extends RefCounted
## Local convenience checkpoint, never a trusted reward/account authority.
## Stores a deterministic command journal; no raw model state is imported.
const Session=preload("res://scripts/alpha/session.gd")
const PROFILE="production-550-v1"
const FORMAT="ORAFOLD-ACTIVE-DUEL"
const VERSION=1
const MAX_BYTES=2*1024*1024
const MAX_COMMANDS=4096
const WEB_KEY="orafold.active-duel.v1"
const RETRY_INITIAL_MS=1000
const RETRY_MAX_MS=30000
var path: String
var available := false
var blocked := false
var issue := ""
var _loaded := false
var _expected_primary: Variant=null
var _document: Dictionary={}
var _last_signature := ""
var _attempt_signature := ""
var _retry_not_before := 0
var _retry_delay := RETRY_INITIAL_MS

func _init(save_path: String="user://orafold_active_duel_v1.json") -> void:path=save_path
func _web() -> bool:return OS.has_feature("web") and path=="user://orafold_active_duel_v1.json"
func _read_text() -> Variant:
	if _web():return JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('"+WEB_KEY+"')}catch(_){return null}})()")
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return null
	if file.get_length()>MAX_BYTES:file.close();return "__oversize__"
	var value=file.get_as_text();file.close();return value
func _parse(value: Variant) -> Variant:
	if not value is String or value.to_utf8_buffer().size()>MAX_BYTES:return null
	return JSON.parse_string(value)
func load_checkpoint() -> Dictionary:
	_loaded=true;available=false;blocked=false;issue="";_document={}
	_last_signature="";_attempt_signature="";_retry_not_before=0;_retry_delay=RETRY_INITIAL_MS
	_expected_primary=_read_text()
	if _expected_primary==null:return {"available":false,"issue":""}
	var parsed: Variant=_parse(_expected_primary)
	if parsed is Dictionary and parsed.get("format")==FORMAT and (not _version_one(parsed.get("version")) or parsed.get("catalog_profile")!=PROFILE):
		blocked=true;issue="Eine Partie einer neueren oder anderen Version bleibt unverändert gespeichert."
	elif not _valid_shape(parsed):
		blocked=true;issue="Die gespeicherte Partie ist beschädigt; sie wird nicht geladen oder überschrieben."
	else:
		_document=parsed;available=true
	return {"available":available,"blocked":blocked,"issue":issue}
static func _version_one(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==1.0
func _valid_shape(value: Variant) -> bool:
	if not value is Dictionary or value.get("format")!=FORMAT or not _version_one(value.get("version")) or value.get("catalog_profile")!=PROFILE:return false
	var replay: Variant=value.get("replay")
	return replay is Dictionary and replay.get("commands") is Array and replay.commands.size()<=MAX_COMMANDS and replay.get("setup") is Dictionary and replay.setup.get("rules_profile")==PROFILE and replay.get("winner")==null and value.get("ui") is Dictionary
func _now_ms() -> int:return Time.get_ticks_msec()
func _storage_unchanged() -> bool:
	if _read_text()==_expected_primary:return true
	blocked=true;available=false
	issue="Die gespeicherte Partie wurde durch eine andere Instanz geändert oder ist nicht mehr lesbar. Lade ORAFOLD neu, um den aktuellen Stand zu prüfen."
	return false
func _retry_later(now: int) -> void:
	_retry_not_before=now+_retry_delay
	_retry_delay=mini(RETRY_MAX_MS,_retry_delay*2)
func _write(value: Variant) -> bool:
	if blocked:return false
	if _web():
		var request={"expected":_expected_primary,"value":value}
		var js="(request=>{try{if(localStorage.getItem('"+WEB_KEY+"')!==request.expected)return JSON.stringify({ok:false,reason:'conflict'});if(request.value===null)localStorage.removeItem('"+WEB_KEY+"');else localStorage.setItem('"+WEB_KEY+"',request.value);return JSON.stringify({ok:true})}catch(_){return JSON.stringify({ok:false,reason:'storage'})}})("+JSON.stringify(request)+")"
		var raw: Variant=JavaScriptBridge.eval(js)
		var result: Variant=JSON.parse_string(raw) if raw is String else null
		if not result is Dictionary or result.get("ok")!=true:
			if result is Dictionary and result.get("reason")=="conflict":
				blocked=true;available=false
				issue="Eine andere Spielinstanz hat die gespeicherte Partie geändert. Lade ORAFOLD neu, um den aktuellen Stand zu prüfen."
			else:issue="Partie konnte nicht gespeichert werden. Browser-Speicher oder eine zweite offene Spielinstanz prüfen."
			return false
	else:
		if not _storage_unchanged():return false
		if value==null:
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:return false
		else:
			var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
			if file==null:return false
			file.store_string(value);file.flush();file.close()
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:return false
	_expected_primary=value;return true
func capture(session: RefCounted, ui: Dictionary={}) -> bool:
	if not _loaded:load_checkpoint()
	if blocked or session.model==null or session.mode!="alpha" or session.setup.get("rules_profile")!=PROFILE:return false
	if session.model.state.winner!=null:return clear()
	if not str(session.model.state.get("error","")).is_empty():return false
	# All product mutations pass through Session.command; AI/effect chains settle
	# within that same command. Avoid hashing a full state five times per second.
	var signature=Session.digest(session.setup)+":"+str(session.commands.size())
	if signature==_last_signature:return true
	var now=_now_ms()
	if signature==_attempt_signature and now<_retry_not_before:return false
	if signature!=_attempt_signature:_retry_delay=RETRY_INITIAL_MS
	_attempt_signature=signature
	if session.commands.size()>MAX_COMMANDS:issue="Diese lange Partie überschreitet die lokale Wiederaufnahmegrenze; sie bleibt bis zum Schließen spielbar.";return false
	var document={"format":FORMAT,"version":VERSION,"catalog_profile":PROFILE,"replay":session.audit(),"ui":ui.duplicate(true)}
	var serialized=JSON.stringify(document)
	if serialized.to_utf8_buffer().size()>MAX_BYTES:issue="Die Partie ist für den lokalen Speicher zu groß.";_retry_later(now);return false
	if not _write(serialized):
		if issue.is_empty():issue="Partie konnte nicht gespeichert werden. Prüfe Speicherplatz und Berechtigungen."
		_retry_later(now);return false
	_document=document;available=true;_last_signature=signature;issue="";_retry_not_before=0;_retry_delay=RETRY_INITIAL_MS;return true
func restore_into(session: RefCounted) -> Dictionary:
	if not _loaded:load_checkpoint()
	if blocked or not available:return {"ok":false,"error":issue if not issue.is_empty() else "Keine gespeicherte Partie vorhanden."}
	if not _storage_unchanged():return {"ok":false,"error":issue}
	var replay: Dictionary=_document.replay
	var verified: Dictionary=Session.replay(replay)
	if not verified.get("ok",false):issue="Partie konnte nicht gegen den aktuellen Kartenkatalog verifiziert werden. Die Datei bleibt unverändert.";blocked=true;available=false;return {"ok":false,"error":issue}
	# Rebuild once more to retain the actual engine/RNG, after validating the
	# entire journal. No command() calls: restoring never grants wins/rewards.
	var candidate=Session.new()
	var setup: Dictionary=replay.setup
	if not candidate.start_match(setup.mode,setup.deck,int(setup.seed),int(setup.difficulty),setup.enemy_deck,bool(setup.convergence),setup.rules_profile):return {"ok":false,"error":"Gespeichertes Startdeck ungültig."}
	for entry in replay.commands:candidate.model.execute(entry.name,entry.args)
	if Session.digest(candidate.model.snapshot())!=replay.final or Session.event_digest(candidate.model.events)!=replay.event_sha256:return {"ok":false,"error":"Wiederaufnahme weicht von der geprüften Partie ab."}
	# Replay verification can take time. Another tab may have saved meanwhile;
	# recheck immediately before replacing the caller's live engine/profile.
	if not _storage_unchanged():return {"ok":false,"error":issue}
	session.mode=candidate.mode;session.model=candidate.model;session.setup=candidate.setup;session.commands=replay.commands.duplicate(true)
	# The running engine retains its exact saved seed/RNG; the profile counter
	# only chooses future matches and must never move backwards on resume.
	session.profile.last_seed=maxi(int(session.profile.last_seed),int(setup.seed))
	return {"ok":true,"ui":_document.ui.duplicate(true)}
func clear() -> bool:
	if not _loaded:load_checkpoint()
	if not _write(null):return false
	available=false;_document={};_last_signature="";_attempt_signature="";_retry_not_before=0;_retry_delay=RETRY_INITIAL_MS;issue="";return true
