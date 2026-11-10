extends SceneTree
## Data-only low-resolution delivery: five packed pilots and real external
## 512-edge WebPs. Originals and prepared PNG pixels are never modified.
const SOURCE := "res://data/production/art_previews.json"
const CONFIG := "res://data/production/art_delivery_config.json"
const OUTPUT := "res://data/production/art_preview_delivery.json"
const CACHE := "res://work/art-preview-delivery-cache"
var assertions := 0
var failures := 0
var checking := false
var ensuring := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
	return ok
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	checking = "--check" in args; ensuring = "--ensure-cache" in args
	var source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not check(source is Dictionary and source.get("entries") is Dictionary and config is Dictionary and config.get("schema_version") == 1 and config.get("pinned_preview_ids") is Array and not (checking and ensuring), "valid source/config/mode required"): finish(); return
	var pinned: Array = config.pinned_preview_ids
	var unique: Dictionary = {}
	for id in pinned: unique[str(id)] = true
	if not check(pinned.size() == 5 and pinned.all(func(id): return id is String and source.entries.has(id)) and pinned.size() == unique.size(), "five unique existing pilot previews required"): finish(); return
	var existing: Dictionary = {}
	if FileAccess.file_exists(OUTPUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
		if parsed is Dictionary and parsed.get("entries") is Dictionary: existing = parsed.entries
	var ids: Array = source.entries.keys(); ids.sort()
	var entries: Dictionary = {}
	var external_count := 0
	if not checking: DirAccess.make_dir_recursive_absolute(CACHE)
	for id in ids:
		var preview: Dictionary = source.entries[id]
		var path := "res://assets/cards/previews/" + str(id) + ".png"
		if not check(preview.get("asset_path") == path and not str(id).contains("..") and not str(id).contains("/") and not str(id).contains("\\"), "safe prepared preview path: " + str(id)): continue
		if not check(FileAccess.get_sha256(path) == preview.get("sha256"), "prepared PNG bytes match preview provenance: " + str(id)): continue
		var entry := {"asset_path": path, "source_sha256": preview.source_sha256, "preview_sha256": preview.sha256, "width": int(preview.width), "height": int(preview.height), "delivery": "packed" if id in pinned else "external"}
		if id in pinned:
			entries[id] = entry; continue
		external_count += 1
		var old: Dictionary = existing.get(id, {})
		if ensuring and old.get("asset_path") == path and old.get("source_sha256") == preview.source_sha256 and old.get("preview_sha256") == preview.sha256 and old.get("width") == preview.width and old.get("height") == preview.height and old.get("delivery") == "external" and old.get("web_sha256") is String:
			var cached := CACHE.path_join(str(old.web_sha256) + ".webp")
			if FileAccess.file_exists(cached) and FileAccess.get_sha256(cached) == old.web_sha256 and FileAccess.get_file_as_bytes(cached).size() == old.get("bytes") and old.get("relative_url") == "art/preview/" + str(old.web_sha256) + ".webp":
				entries[id] = old; continue
		var image := Image.new()
		if not check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not image.is_empty(), "actual prepared pixels decode: " + str(id)): continue
		if not check(image.get_width() == int(preview.width) and image.get_height() == int(preview.height) and maxi(image.get_width(), image.get_height()) == 512, "exact prepared dimensions, no resizing: " + str(id)): continue
		var bytes := image.save_webp_to_buffer(true, 0.9)
		if not check(not bytes.is_empty() and bytes.size() <= 1024 * 1024, "actual compact WebP within one MiB bound: " + str(id)): continue
		var sha := digest(bytes)
		entry.merge({"web_sha256": sha, "relative_url": "art/preview/" + sha + ".webp", "bytes": bytes.size()})
		entries[id] = entry
		if ensuring and not check(old == JSON.parse_string(JSON.stringify(entry)), "committed preview delivery metadata matches actual encoding: " + str(id)): continue
		if not checking:
			var file := FileAccess.open(CACHE.path_join(sha + ".webp"), FileAccess.WRITE)
			if check(file != null, "encoded preview cache writable: " + str(id)): file.store_buffer(bytes); file.close()
	var result := {"schema_version": 1, "profile": "orafold-web-preview-v1", "resource_kind": "compact_preview", "maximum_edge": 512, "external_codec": "webp", "external_lossless": true, "individual_original_count_added": 0, "pinned_card_ids": pinned, "preview_count": entries.size(), "external_preview_count": external_count, "entries": entries}
	var serialized := JSON.stringify(result, "  ", true) + "\n"
	if checking:
		check(FileAccess.file_exists(OUTPUT) and FileAccess.get_file_as_string(OUTPUT) == serialized, "data-only preview manifest current and reproducible")
	elif ensuring:
		check(FileAccess.file_exists(OUTPUT) and JSON.parse_string(FileAccess.get_file_as_string(OUTPUT)) == JSON.parse_string(serialized), "preview delivery values current and cache complete")
	else:
		var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
		if check(file != null, "preview delivery manifest writable"): file.store_string(serialized); file.close()
	finish()
func finish() -> void:
	print("PRODUCTION PREVIEW DELIVERY DATA: %d assertions, %d failures; actual compact derivatives %s" % [assertions, failures, "verified" if checking or ensuring else "generated"])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
