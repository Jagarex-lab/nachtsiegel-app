extends RefCounted
## Illustration-only asset lookup. No rules, card frames or rendered text are assets.
## A bounded LRU retains only visible/recent originals; missing art remains labelled.
const MANIFEST_PATH := "res://data/production/art_manifest.json"
const MAX_CACHE_BYTES := 32 * 1024 * 1024
const MAX_CACHE_ENTRIES := 8
const MAX_SOURCE_PIXELS := 4096 * 4096
static var _manifest: Dictionary = {}
static var _manifest_loaded := false
static var _cache: Dictionary = {}
static var _lru: Array[String] = []
static var _cache_bytes := 0
static var _loads := 0
static var _hits := 0

static func safe_asset_path(value: String) -> bool:
	if not value.begins_with("res://assets/"): return false
	var suffix := value.trim_prefix("res://")
	if suffix.contains("..") or suffix.contains("\\") or suffix.contains("%") or suffix.contains(":") or suffix.contains("//") or suffix.to_utf8_buffer().has(0): return false
	return suffix.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]

static func _load_manifest() -> void:
	if _manifest_loaded: return
	_manifest_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary and parsed.get("schema_version") == 1 and parsed.get("entries") is Dictionary:
		_manifest = parsed.entries

static func manifest_entry(card_id: String) -> Dictionary:
	_load_manifest()
	return _manifest.get(card_id, {}).duplicate(true)

static func _texture(path: String) -> Texture2D:
	if not safe_asset_path(path): return null
	if _cache.has(path):
		_hits += 1
		_lru.erase(path); _lru.append(path)
		return _cache[path].texture
	var parent := "res://"
	for part in path.trim_prefix("res://").split("/"):
		var directory := DirAccess.open(parent)
		if directory != null and directory.is_link(part): return null
		parent = parent.path_join(part)
	if not ResourceLoader.exists(path, "Texture2D"): return null
	var value = ResourceLoader.load(path, "Texture2D")
	if not value is Texture2D: return null
	var pixels := int(value.get_width()) * int(value.get_height())
	if pixels <= 0 or pixels > MAX_SOURCE_PIXELS: return null
	# RGBA8 plus mip pyramid is a conservative desktop/mobile staging estimate.
	# Driver-specific GPU formats and external references are not measured here.
	var byte_estimate := int(ceil(float(pixels * 4) * 4.0 / 3.0))
	if byte_estimate > MAX_CACHE_BYTES: return value
	while not _lru.is_empty() and (_cache.size() >= MAX_CACHE_ENTRIES or _cache_bytes + byte_estimate > MAX_CACHE_BYTES):
		var oldest: String = _lru.pop_front()
		_cache_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)
	_cache[path] = {"texture": value, "bytes": byte_estimate}
	_lru.append(path); _cache_bytes += byte_estimate; _loads += 1
	return value

static func resolve(card: Dictionary) -> Dictionary:
	var artwork: Dictionary = card.get("art", {}) if card.get("art", {}) is Dictionary else {}
	var status := str(artwork.get("status", "shared_concept"))
	var path := str(artwork.get("asset_id", ""))
	if not path.begins_with("res://") and int(card.get("schema_version", 1)) < 2:
		path = str(artwork.get("path", ""))
	var entry := manifest_entry(str(card.get("id", "")))
	# Explicit usable artwork wins; a legacy shared-atlas binding can adopt the
	# matching individual illustration without modifying any card definition.
	if not path.begins_with("res://") and entry.get("status", "missing") in ["concept", "final"]:
		path = str(entry.get("asset_path", "")); status = str(entry.status)
		if status == "final" and entry.get("production_review", "pending") != "approved": status = "concept"
	# Final is a reviewed pipeline state, never a claim a card can self-assign.
	if status == "final":
		if path != str(entry.get("asset_path", "")) or entry.get("status", "concept") != "final" or entry.get("production_review", "pending") != "approved" or not bool(entry.get("individual_original", false)): status = "concept"
	var texture: Texture2D = _texture(path) if status in ["concept", "final"] else null
	if texture == null: status = "shared_concept"
	return {
		"texture": texture, "status": status,
		"label": "GETEILTES KONZEPTBILD" if texture == null else "KONZEPTILLUSTRATION" if status != "final" else "",
		"asset_path": path if texture != null else "",
		"individual": texture != null and bool(entry.get("individual_original", false)) and path == str(entry.get("asset_path", "")),
		"commercially_cleared": bool(entry.get("commercially_cleared", false)) if path == str(entry.get("asset_path", "")) else false
	}

static func stats() -> Dictionary:
	return {"retained_textures": _cache.size(), "estimated_retained_bytes": _cache_bytes, "cache_byte_limit": MAX_CACHE_BYTES, "cache_entry_limit": MAX_CACHE_ENTRIES, "loads": _loads, "hits": _hits}

static func clear_cache(reload_manifest := false) -> void:
	_cache.clear(); _lru.clear(); _cache_bytes = 0; _loads = 0; _hits = 0
	if reload_manifest: _manifest.clear(); _manifest_loaded = false
