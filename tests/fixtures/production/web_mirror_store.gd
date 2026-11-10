extends "res://scripts/production/profile_store.gd"
## Native backend-integration fixture only. Actual JavaScript transaction
## failure paths are executed separately by production_storage_mirror.test.cjs.
var memory: Dictionary={"primary":null,"backup":null}
var reject_reads := false
var reject_writes := false
func _init(profile_path: String=CURRENT_PROFILE, import_path: String="") -> void:super._init(profile_path,import_path)
func _web_backend_enabled() -> bool:return true
func _mirror_io(request: Dictionary) -> Dictionary:
	if request.operation=="read":
		return {"ok":false,"error":"storage_unavailable"} if reject_reads else {"ok":true,"primary":memory.primary,"backup":memory.backup}
	if reject_writes:return {"ok":false,"error":"storage_full"}
	if request.expected_primary!=memory.primary or request.expected_backup!=memory.backup:return {"ok":false,"error":"storage_changed"}
	if request.backup_value is String:memory.backup=request.backup_value
	memory.primary=request.value
	return {"ok":true}
