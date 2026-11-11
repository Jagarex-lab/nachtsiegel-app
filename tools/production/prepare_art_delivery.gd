extends SceneTree
## Actual native-size WebP derivatives for on-demand Web delivery. No upscaling.
const SOURCE := "res://data/production/art_sources.json"
const OUTPUT := "res://data/production/art_delivery.json"
const CACHE := "res://work/art-delivery-cache"
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
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	checking = "--check" in args; ensuring = "--ensure-cache" in args
	var sources = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not check(sources is Dictionary and sources.get("entries") is Dictionary and not (checking and ensuring), "valid source/mode required"): finish(); return
	var existing: Dictionary = {}
	if FileAccess.file_exists(OUTPUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
		if parsed is Dictionary: existing = parsed.get("entries", {})
	var ids: Array = sources.entries.keys(); ids.sort()
	var entries: Dictionary = {}
	if not checking: DirAccess.make_dir_recursive_absolute(CACHE)
	for id in ids:
		var source: Dictionary = sources.entries[id]
		var path := "res://assets/cards/originals/" + str(id) + ".png"
		if not check(source.get("asset_path") == path and not str(id).contains("..") and not str(id).contains("/"), "safe matching native source: " + str(id)): continue
		if not check(FileAccess.get_sha256(path) == source.get("sha256"), "original provenance hash: " + str(id)): continue
		var old: Dictionary = existing.get(id, {})
		if ensuring and old.get("source_sha256") == source.sha256 and old.get("source_asset_path") == path and old.get("width") == source.original_width and old.get("height") == source.original_height and old.get("web_sha256") is String:
			var cached := CACHE.path_join(str(old.web_sha256) + ".webp")
			if FileAccess.file_exists(cached) and FileAccess.get_sha256(cached) == old.web_sha256 and FileAccess.get_file_as_bytes(cached).size() == old.get("bytes") and old.get("relative_url") == "art/full/" + str(old.web_sha256) + ".webp":
				entries[id] = old; continue
		var image := Image.new()
		if not check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not image.is_empty(), "actual original pixels: " + str(id)): continue
		if not check(image.get_width() == int(source.original_width) and image.get_height() == int(source.original_height) and image.get_width() >= 1024 and image.get_height() >= 768, "native full dimensions preserved: " + str(id)): continue
		var bytes := image.save_webp_to_buffer(true, 0.9)
		if not check(not bytes.is_empty(), "actual native-size WebP encoded: " + str(id)): continue
		var sha := digest(bytes)
		var entry := {"source_asset_path": path, "source_sha256": source.sha256, "web_sha256": sha, "relative_url": "art/full/" + sha + ".webp", "width": image.get_width(), "height": image.get_height(), "bytes": bytes.size()}
		entries[id] = entry
		if ensuring and not check(old == JSON.parse_string(JSON.stringify(entry)), "committed delivery metadata must match original encoding: " + str(id)): continue
		if not checking:
			var file := FileAccess.open(CACHE.path_join(sha + ".webp"), FileAccess.WRITE)
			if check(file != null, "immutable delivery-cache file writable: " + str(id)): file.store_buffer(bytes); file.close()
	var result := {"schema_version": 1, "profile": "orafold-web-art-v1", "codec": "webp", "quality": 0.9, "individual_original_count_added": 0, "full_asset_count": entries.size(), "entries": entries}
	var serialized := JSON.stringify(result, "  ", true) + "\n"
	if checking:
		check(FileAccess.file_exists(OUTPUT) and FileAccess.get_file_as_string(OUTPUT) == serialized, "delivery manifest current and reproducible")
	elif ensuring:
		# JSON parsing uses floats for all numbers; compare actual values rather
		# than introducing .0 spelling changes into the immutable metadata.
		check(FileAccess.file_exists(OUTPUT) and JSON.parse_string(FileAccess.get_file_as_string(OUTPUT)) == JSON.parse_string(serialized), "delivery manifest values current and cache complete")
	else:
		var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
		if check(file != null, "delivery manifest writable"): file.store_string(serialized); file.close()
	finish()
func finish() -> void:
	print("PRODUCTION ART DELIVERY DATA: %d assertions, %d failures; actual native-size derivatives %s" % [assertions, failures, "verified" if checking or ensuring else "generated"])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
