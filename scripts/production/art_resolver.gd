extends RefCounted
## Illustration-only asset lookup. No rules, card frames or rendered text are assets.
## A bounded LRU retains only visible/recent originals; missing art remains labelled.
const MANIFEST_PATH := "res://data/production/art_manifest.json"
const MAX_CACHE_BYTES := 32 * 1024 * 1024
const MAX_CACHE_ENTRIES := 48
const COMPACT_MAX_EDGE := 512
const MAX_SOURCE_PIXELS := 4096 * 4096
static var _manifest: Dictionary = {}
static var _manifest_loaded := false
static var _inventory_counts: Dictionary = {}
static var _cache: Dictionary = {}
static var _lru: Array[String] = []
static var _cache_bytes := 0
static var _loads := 0
static var _hits := 0
static var _generation := 0
static var _thumbnail_builds := 0
static var _delivery_versions: Dictionary = {}

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
		_inventory_counts = {"individual": int(parsed.get("individual_original_count", 0)), "final": int(parsed.get("final_individual_count", 0)), "missing": int(parsed.get("missing_individual_count", 550))}

static func inventory_counts() -> Dictionary:
	_load_manifest()
	return _inventory_counts.duplicate()

static func manifest_entry(card_id: String) -> Dictionary:
	_load_manifest()
	return _manifest.get(card_id, {}).duplicate(true)

static func binding_key(card: Dictionary, profile := "full") -> String:
	var art: Dictionary = card.get("art", {}) if card.get("art", {}) is Dictionary else {}
	return JSON.stringify([card.get("id", ""), card.get("schema_version", 1), art.get("status", "shared_concept"), art.get("asset_id", ""), art.get("path", ""), profile, _generation, _delivery_versions.get(profile + "|" + str(card.get("id", "")), 0)])

static func delivery_changed(card_id: String, profile := "full") -> void:
	var key := profile + "|" + card_id
	_delivery_versions[key] = int(_delivery_versions.get(key, 0)) + 1

static func _delivery_node():
	var tree = Engine.get_main_loop()
	return tree.root.get_node_or_null("ArtDelivery") if tree is SceneTree else null

static func has_full_texture(card_id: String) -> bool:
	var path := str(manifest_entry(card_id).get("asset_path", ""))
	return not path.is_empty() and _cache.has(path + "|full")

static func has_preview_texture(card_id: String) -> bool:
	var path := str(manifest_entry(card_id).get("preview_asset_path", ""))
	return not path.is_empty() and _cache.has(path + "|compact")

static func visible_owner(owner: Node) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree(): return false
	var cursor: Node = owner
	while cursor != null:
		if cursor.is_queued_for_deletion(): return false
		cursor = cursor.get_parent()
	if owner is CanvasItem and not owner.is_visible_in_tree(): return false
	if owner is Control:
		var visible: Rect2 = owner.get_global_rect().intersection(owner.get_viewport().get_visible_rect())
		cursor = owner.get_parent()
		while cursor != null:
			if cursor is Control and cursor.clip_contents: visible = visible.intersection(cursor.get_global_rect())
			cursor = cursor.get_parent()
		return visible.has_area()
	return true

static func release_owner(owner: Node) -> void:
	var service = _delivery_node()
	if service != null: service.release_owner(owner)

static func _cached_texture(cache_key: String) -> Texture2D:
	if not _cache.has(cache_key): return null
	_hits += 1
	_lru.erase(cache_key); _lru.append(cache_key)
	return _cache[cache_key].texture

static func store_delivered_full(card_id: String, texture: Texture2D) -> bool:
	var entry := manifest_entry(card_id)
	var path := str(entry.get("asset_path", ""))
	if not safe_asset_path(path) or texture == null or texture.get_width() != int(entry.get("original_width", 0)) or texture.get_height() != int(entry.get("original_height", 0)): return false
	return _retain(path + "|full", texture, "full", card_id)

static func store_delivered_preview(card_id: String, texture: Texture2D) -> bool:
	var entry := manifest_entry(card_id)
	var path := str(entry.get("preview_asset_path", ""))
	if not safe_asset_path(path) or texture == null or texture.get_width() != int(entry.get("preview_width", 0)) or texture.get_height() != int(entry.get("preview_height", 0)): return false
	return _retain(path + "|compact", texture, "compact", card_id)

static func _retain(cache_key: String, texture: Texture2D, profile: String, card_id := "") -> bool:
	var estimate := int(ceil(float(texture.get_width() * texture.get_height() * 4) * 4.0 / 3.0))
	if estimate > MAX_CACHE_BYTES: return false
	if _cache.has(cache_key):
		_cache_bytes -= int(_cache[cache_key].bytes); _cache.erase(cache_key); _lru.erase(cache_key)
	while not _lru.is_empty() and (_cache.size() >= MAX_CACHE_ENTRIES or _cache_bytes + estimate > MAX_CACHE_BYTES):
		var oldest := ""
		var service = _delivery_node()
		for candidate in _lru:
			var item: Dictionary = _cache[candidate]
			if service != null and service.texture_visible(str(item.get("card_id", "")), str(item.profile)): continue
			oldest = candidate; break
		# Inspector art takes priority over retained compact entries. A visible
		# compact Control can retain its own texture reference; the shared cache
		# must not reject a valid full image merely because all thumbnails are
		# visible. This is a cache bound, not a total scene/GPU memory claim.
		if oldest.is_empty() and profile == "full":
			for candidate in _lru:
				if _cache[candidate].profile == "compact": oldest = candidate; break
		if oldest.is_empty(): return false
		_lru.erase(oldest); _cache_bytes -= int(_cache[oldest].bytes); _cache.erase(oldest)
	_cache[cache_key] = {"texture": texture, "bytes": estimate, "profile": profile, "card_id": card_id}
	_lru.append(cache_key); _cache_bytes += estimate; _loads += 1
	return true

static func _texture(path: String, profile: String, card_id := "") -> Texture2D:
	if not safe_asset_path(path): return null
	if profile not in ["full", "compact"]: return null
	var cache_key := path + "|" + profile
	if _cache.has(cache_key):
		_hits += 1
		_lru.erase(cache_key); _lru.append(cache_key)
		return _cache[cache_key].texture
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
	if profile == "compact" and maxi(value.get_width(), value.get_height()) > COMPACT_MAX_EDGE:
		# This runtime preview never replaces or enlarges the original. Compact
		# controls need a much smaller GPU texture than the full card inspector.
		var image: Image = value.get_image()
		if image == null or image.is_empty(): return null
		var ratio := float(COMPACT_MAX_EDGE) / float(maxi(image.get_width(), image.get_height()))
		var width := maxi(1, roundi(float(image.get_width()) * ratio))
		var height := maxi(1, roundi(float(image.get_height()) * ratio))
		image.clear_mipmaps(); image.resize(width, height, Image.INTERPOLATE_LANCZOS)
		if image.generate_mipmaps() != OK: return null
		value = ImageTexture.create_from_image(image)
		pixels = width * height; _thumbnail_builds += 1
	# Driver-specific GPU formats and references held by Controls are not
	# measured here. The shared retained cache has one bound for both profiles.
	_retain(cache_key, value, profile, card_id)
	return value

static func resolve(card: Dictionary, profile := "full", owner: Node = null, request_network := true) -> Dictionary:
	var artwork: Dictionary = card.get("art", {}) if card.get("art", {}) is Dictionary else {}
	var status := str(artwork.get("status", "shared_concept"))
	var path := str(artwork.get("asset_id", ""))
	var card_id := str(card.get("id", ""))
	if not path.begins_with("res://") and int(card.get("schema_version", 1)) < 2: path = str(artwork.get("path", ""))
	var entry := manifest_entry(card_id)
	if not path.begins_with("res://") and entry.get("status", "missing") in ["concept", "final"]:
		path = str(entry.get("asset_path", "")); status = str(entry.status)
		if status == "final" and entry.get("production_review", "pending") != "approved": status = "concept"
	if status == "final":
		if path != str(entry.get("asset_path", "")) or entry.get("status", "concept") != "final" or entry.get("production_review", "pending") != "approved" or not bool(entry.get("individual_original", false)): status = "concept"
	var individual: bool = path == str(entry.get("asset_path", "")) and bool(entry.get("individual_original", false))
	var preview_path := str(entry.get("preview_asset_path", "")) if individual else ""
	var texture_path := preview_path if profile == "compact" and not preview_path.is_empty() else path
	var service = _delivery_node()
	var external_full: bool = profile == "full" and service != null and service.external_enabled() and individual
	if external_full and request_network and owner != null: service.request_full(card_id, owner)
	var texture: Texture2D = null
	if status in ["concept", "final"]:
		texture = _cached_texture(path + "|full") if external_full else _texture(texture_path, profile, card_id)
	var preview_only := false
	var preview_pending := false
	var delivery_state := "ready" if texture != null else "preview"
	if profile == "full" and texture == null and individual:
		if service != null:
			if request_network: service.request_full(card_id, owner)
			delivery_state = service.state_for(card_id)
		if not preview_path.is_empty():
			texture_path = preview_path; texture = _texture(preview_path, "compact", card_id)
			preview_only = texture != null
		preview_pending = texture == null
	elif profile == "compact" and individual and not preview_path.is_empty():
		if service != null and service.external_preview(card_id):
			if request_network and owner != null: service.request_preview(card_id, owner)
			delivery_state = "ready" if texture != null else service.state_for(card_id, "compact")
		preview_pending = texture == null
	var caption := "GETEILTES KONZEPTBILD" if texture == null else "KONZEPTILLUSTRATION" if status != "final" else ""
	if preview_only: caption = "VORSCHAU · BILD LÄDT" if delivery_state == "loading" else "VORSCHAU · OFFLINE" if delivery_state == "failed" else "VORSCHAU"
	if preview_pending:
		status = "preview_loading" if delivery_state == "loading" else "preview_unavailable"
		caption = "BILD LÄDT" if delivery_state == "loading" else "BILD NICHT VERFÜGBAR"
	elif texture == null: status = "shared_concept"
	return {"texture": texture, "status": status, "label": caption, "preview_only": preview_only, "preview_pending": preview_pending, "delivery_state": delivery_state, "asset_path": path if texture != null else "", "texture_asset_path": texture_path if texture != null else "", "profile": profile, "individual": texture != null and individual, "commercially_cleared": bool(entry.get("commercially_cleared", false)) if individual else false}

static func stats() -> Dictionary:
	var profiles := {"full": 0, "compact": 0}
	for entry in _cache.values(): profiles[entry.profile] += 1
	return {"retained_textures": _cache.size(), "estimated_retained_bytes": _cache_bytes, "cache_byte_limit": MAX_CACHE_BYTES, "cache_entry_limit": MAX_CACHE_ENTRIES, "loads": _loads, "hits": _hits, "thumbnail_builds": _thumbnail_builds, "profiles": profiles}

static func clear_cache(reload_manifest := false) -> void:
	_cache.clear(); _lru.clear(); _cache_bytes = 0; _loads = 0; _hits = 0
	_generation += 1; _thumbnail_builds = 0
	_delivery_versions.clear()
	if reload_manifest: _manifest.clear(); _inventory_counts.clear(); _manifest_loaded = false
