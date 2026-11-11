@tool
extends EditorExportPlugin
## Packaging policy reads only delivery data; no card/rule source is changed.
const MANIFEST := "res://data/production/art_preview_delivery.json"
var _pinned: Dictionary = {}
func _get_name() -> String: return "ORAFOLD pinned Web previews"
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_pinned.clear()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	if parsed is Dictionary and parsed.get("profile") == "orafold-web-preview-v1" and parsed.get("pinned_card_ids") is Array:
		for id in parsed.pinned_card_ids: _pinned["res://assets/cards/previews/" + str(id) + ".png"] = true
func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	if path.begins_with("res://addons/orafold_art_delivery/"):
		skip(); return
	if features.has("web") and path.begins_with("res://assets/cards/previews/") and not _pinned.has(path): skip()
