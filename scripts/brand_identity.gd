extends RefCounted
## Release name is independent of the creative preview. No automatic rename.
const DATA = preload("res://data/brand/identity.json")

static func definition() -> Dictionary:
	# Return a copy: preview tools must not mutate the release identity.
	return DATA.data.duplicate(true)

static func display_name() -> String:
	var data = DATA.data
	var approved = data.get("approved_product_name")
	if approved is String and not approved.strip_edges().is_empty() and data.get("approval_reference") is String and not str(data.approval_reference).strip_edges().is_empty():
		return approved
	return str(data.legacy_product_name)

static func preview_name(locale: String = "de") -> String:
	return str(DATA.data.preview.get(locale,DATA.data.preview.de))

static func apply_window_title() -> void:
	DisplayServer.window_set_title(display_name())
	if OS.has_feature("web"):
		var name_json = JSON.stringify(display_name())
		JavaScriptBridge.eval("document.title="+name_json+";document.getElementById('canvas').setAttribute('aria-label',"+name_json+"+' Fantasy-Kartenduell')",true)
