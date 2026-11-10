extends "res://scripts/progress_store.gd"
## Reuses the existing atomic file/backup transport, in a separate sandbox slot.
## No gameplay progress or Alpha profile is loaded or modified here.
var fail_writes := false
func defaults() -> Dictionary:
	return {}
func load_progress() -> void:
	pass
func read_slot(backup := false) -> Variant:
	if OS.has_feature("web"):
		var envelope: Variant = _web_envelope()
		return envelope.get("backup" if backup else "primary") if envelope is Dictionary else null
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
		return {"primary": null, "backup": envelope.backup} if envelope.get("backup") is Dictionary else invalid
	if envelope.has("backup") and not envelope.backup is Dictionary: envelope.erase("backup")
	return envelope
static func web_envelope_for_save(current: Dictionary, previous: Dictionary) -> Dictionary:
	var envelope := {"primary": current}
	if previous.get("primary") is Dictionary: envelope["backup"] = previous.primary
	return envelope
static func web_write_script(storage_key: String, envelope: Dictionary) -> String:
	var key := JSON.stringify(storage_key)
	var payload := JSON.stringify(JSON.stringify(envelope))
	return "(()=>{try{localStorage.setItem(" + key + "," + payload + ");return true}catch(e){return false}})()"
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
		var success: Variant = JavaScriptBridge.eval(web_write_script(_web_key(), envelope))
		if success != true:
			last_error = "Browser storage unavailable; transaction not committed"
			return false
		last_error = ""
		return true
	return super.save()
