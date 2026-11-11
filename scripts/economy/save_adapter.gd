extends "res://scripts/progress_store.gd"
## Reuses the existing atomic file/backup transport, in a separate sandbox slot.
## No gameplay progress or Alpha profile is loaded or modified here.
var fail_writes := false
var last_good_data: Dictionary = {}
var _expected_primary := ""
var _expected_backup := ""
var _expected_web: Dictionary = {}
func defaults() -> Dictionary:
	return {}
func load_progress() -> void:
	pass
func read_slot(backup := false) -> Variant:
	if OS.has_feature("web"):
		var envelope: Variant = _web_envelope()
		if not backup: _expected_web = envelope.duplicate(true)
		return envelope.get("backup" if backup else "primary") if envelope is Dictionary else null
	if not backup:
		_expected_primary = _raw(path)
		_expected_backup = _raw(path + ".bak")
	return _read(path + (".bak" if backup else ""))
func exists(backup := false) -> bool:
	if OS.has_feature("web"):
		var envelope: Variant = _web_envelope()
		return envelope is Dictionary and envelope.has("backup" if backup else "primary")
	return FileAccess.file_exists(path + (".bak" if backup else ""))
func _web_envelope() -> Variant:
	return decode_web_read(JavaScriptBridge.eval(web_read_script(_web_key())))
func _web_key() -> String:
	return "orafold.economy.sandbox." + path.sha256_text()
static func web_read_script(storage_key: String) -> String:
	# Return structured status: missing is the only condition that permits a new
	# slot. Denied storage and present malformed values must never reset balances.
	var key := JSON.stringify(storage_key)
	return "(()=>{try{const raw=localStorage.getItem(" + key + ");return JSON.stringify(raw===null?{status:'missing'}:{status:'present',raw})}catch(e){return JSON.stringify({status:'error'})}})()"
static func decode_web_read(response: Variant) -> Dictionary:
	var invalid := {"primary": null, "storage_error": true}
	if not response is String: return invalid
	var parser := JSON.new()
	if parser.parse(response) != OK or not parser.data is Dictionary: return invalid
	var wrapper: Dictionary = parser.data
	if wrapper.get("status") == "missing": return {}
	if wrapper.get("status") != "present" or not wrapper.get("raw") is String: return invalid
	if parser.parse(wrapper.raw) != OK or not parser.data is Dictionary: return invalid
	var envelope: Dictionary = parser.data
	if not envelope.has("primary") or not envelope.primary is Dictionary:
		# Retain a structurally valid backup so normal validated recovery can run.
		return envelope if envelope.get("backup") is Dictionary else invalid
	return envelope
static func web_envelope_for_save(current: Dictionary, previous: Dictionary) -> Dictionary:
	var envelope := {"primary": current}
	if previous.get("primary") is Dictionary: envelope["backup"] = previous.primary
	return envelope
static func web_write_script(storage_key: String, envelope: Dictionary) -> String:
	var key := JSON.stringify(storage_key)
	var payload := JSON.stringify(JSON.stringify(envelope))
	return "(()=>{try{localStorage.setItem(" + key + "," + payload + ");return true}catch(e){return false}})()"
static func web_compare_write_script(storage_key: String, envelope: Dictionary, expected: Dictionary) -> String:
	var key := JSON.stringify(storage_key)
	var payload := JSON.stringify(JSON.stringify(envelope))
	var old := JSON.stringify(JSON.stringify(expected))
	# JavaScript executes this comparison and write synchronously in one task.
	# Godot parses JSON numbers as float (1 -> 1.0). Normalize both operands in
	# JavaScript before comparing, so a read-only bridge round trip is not a
	# false stale-writer conflict. Changed balances/receipts still reject.
	return "(()=>{try{const raw=localStorage.getItem(" + key + ");const expected=" + old + ";if(raw===null?expected!=='{}':JSON.stringify(JSON.parse(raw))!==JSON.stringify(JSON.parse(expected)))return false;localStorage.setItem(" + key + "," + payload + ");return true}catch(e){return false}})()"

static func web_write_succeeded(response: Variant) -> bool:
	# Web JavaScriptBridge can transport JS booleans as numeric 1/0. Comparing
	# that Variant directly to a GDScript bool raises a runtime type error.
	# Accept only the exact success representations, never generic truthiness.
	if response is bool: return response
	if response is int or response is float: return float(response) == 1.0
	return false

func _raw(file_path: String) -> String:
	return FileAccess.get_file_as_string(file_path) if FileAccess.file_exists(file_path) else ""

func _native_save() -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	# An atomic directory lock serializes local writers; an interrupted writer
	# leaves the slot blocked for recovery instead of permitting a stale payout.
	if DirAccess.make_dir_absolute(absolute + ".lock") != OK:
		last_error = "Economy save is busy; retry after the other local writer finishes"
		return false
	var success := _native_save_locked(absolute)
	DirAccess.remove_absolute(absolute + ".lock")
	return success

func _native_save_locked(absolute: String) -> bool:
	if _raw(path) != _expected_primary or _raw(path + ".bak") != _expected_backup:
		last_error = "Economy storage changed; reload and retry"
		return false
	var serialized := JSON.stringify(data)
	var writer := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if writer == null:
		last_error = "Economy temporary save could not be opened"
		return false
	writer.store_string(serialized)
	writer.flush()
	var write_error := writer.get_error()
	writer.close()
	if write_error != OK or _raw(path + ".tmp") != serialized:
		last_error = "Economy temporary save could not be verified"
		return false
	if not _expected_primary.is_empty() and not last_good_data.is_empty():
		var parser := JSON.new()
		var parsed: Variant = parser.data if parser.parse(_expected_primary) == OK else null
		if JSON.stringify(parsed, "", true) != JSON.stringify(JSON.parse_string(JSON.stringify(last_good_data)), "", true):
			# Never rotate damaged primary bytes over a known-good backup.
			if not FileAccess.file_exists(path + ".corrupt") and DirAccess.copy_absolute(absolute, absolute + ".corrupt") != OK:
				last_error = "Damaged economy save could not be quarantined"
				return false
		elif DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			last_error = "Economy backup could not be saved"
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		last_error = "Economy atomic save replacement failed"
		return false
	_expected_primary = serialized
	_expected_backup = _raw(path + ".bak")
	last_good_data = data.duplicate(true)
	last_error = ""
	return true
func save() -> bool:
	if fail_writes:
		last_error = "Injected storage failure"
		return false
	if OS.has_feature("web"):
		# One synchronous atomic key includes primary and previous slot. A quota or
		# permission failure leaves both balances and receipts unchanged on disk.
		var old: Variant = _web_envelope()
		if old.get("storage_error", false):
			last_error = "Browser storage unavailable or invalid; transaction not committed"
			return false
		var envelope := web_envelope_for_save(data, old)
		if not last_good_data.is_empty():
			envelope["backup"] = last_good_data.duplicate(true)
			if old.has("primary") and JSON.stringify(old.primary, "", true) != JSON.stringify(JSON.parse_string(JSON.stringify(last_good_data)), "", true): envelope["quarantined_primary"] = old.primary
		if old.has("quarantined_primary") and not envelope.has("quarantined_primary"): envelope["quarantined_primary"] = old.quarantined_primary
		var success: Variant = JavaScriptBridge.eval(web_compare_write_script(_web_key(), envelope, _expected_web))
		if not web_write_succeeded(success):
			last_error = "Browser storage unavailable; transaction not committed"
			return false
		last_error = ""
		_expected_web = envelope.duplicate(true)
		last_good_data = data.duplicate(true)
		return true
	return _native_save()
