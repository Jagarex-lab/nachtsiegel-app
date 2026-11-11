extends SceneTree
const ART = preload("res://scripts/production/art_resolver.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const BUILD_METADATA := ["art_sources.json", "art_source_map.json", "art_briefs.json", "authoring.json", "art_previews.json"]
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func run() -> void:
	var native_pack := "--native" in OS.get_cmdline_user_args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_manifest.json"))
	var runtime_catalog = Catalog.new()
	var runtime_cards: Array = runtime_catalog.all_cards()
	var runtime_ids: Dictionary = {}
	for card in runtime_cards: runtime_ids[str(card.id)] = true
	check(runtime_catalog.load_error.is_empty() and runtime_cards.size() == 550 and runtime_ids.size() == 550, "actual packed production catalog has exactly550 valid distinct IDs")
	var originals := {"entries": {}}
	if native_pack:
		# Native retains its independent canonical provenance crosscheck.
		originals = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_sources.json"))
	else:
		# Web consumes the same validated lightweight manifest as the app.
		# No authoring/provenance source file or checkout fallback is required.
		for id in manifest.entries:
			if manifest.entries[id].get("individual_original", false): originals.entries[id] = manifest.entries[id]
		if not OS.has_feature("archive_qa") and not OS.has_feature("legacy_ui_qa"):
			for filename in BUILD_METADATA:
				check(not FileAccess.file_exists("res://data/production/" + filename) and not ResourceLoader.exists("res://data/production/" + filename), "normal Web pack excludes build-only metadata: " + filename)
	var delivery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_delivery.json"))
	var previews: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_preview_delivery.json"))
	var count: int = originals.entries.size()
	check(count == 550 and manifest.entries.size() == 550 and originals.entries.keys().all(func(id): return runtime_ids.has(id)), "all550 individual manifest bindings exactly match actual runtime catalog identities")
	check(manifest.inventory_card_count == 550 and manifest.individual_original_count == count and manifest.compact_preview_count == count, "actual PCK carries matching original/preview inventory")
	check(manifest.final_individual_count == count and manifest.commercially_cleared_count == 0, "actual package distinguishes visual and legal approval")
	check(delivery.entries.size() == count and delivery.profile == "orafold-web-art-v1", "actual full-art delivery inventory matches declared sources")
	check(previews.entries.size() == count and previews.pinned_card_ids.size() == 5 and previews.external_preview_count == count - 5, "actual compact delivery packs five pilots and declares remaining external previews")
	var actual_originals := 0
	var actual_previews := 0
	var compact_texture_bytes := 0
	for id in originals.entries:
		var entry: Dictionary = ART.manifest_entry(id)
		check(entry.asset_path == "res://assets/cards/originals/" + str(id) + ".png", "runtime card identity binds its exact original path: " + str(id))
		check(entry.original_width == delivery.entries[id].width and entry.original_height == delivery.entries[id].height, "runtime original dimensions match actual full delivery binding: " + str(id))
		check(entry.preview_asset_path == previews.entries[id].asset_path and entry.preview_width == previews.entries[id].width and entry.preview_height == previews.entries[id].height, "runtime compact path/dimensions match actual preview binding: " + str(id))
		if native_pack:
			check(entry.sha256 == originals.entries[id].sha256 and entry.original_width == originals.entries[id].original_width and entry.original_height == originals.entries[id].original_height, "native runtime manifest retains canonical source hash/dimensions: " + str(id))
		var original_size := Vector2(entry.original_width, entry.original_height)
		var preview_size := Vector2(entry.preview_width, entry.preview_height)
		var expected_preview: bool = native_pack or id in previews.pinned_card_ids
		var full: Dictionary = ART.resolve({"id": id}, "full", null, false)
		var compact: Dictionary = ART.resolve({"id": id}, "compact", null, false)
		var original_path := str(originals.entries[id].asset_path)
		var full_exists := ResourceLoader.exists(original_path, "Texture2D")
		var preview_exists := ResourceLoader.exists(str(entry.preview_asset_path), "Texture2D")
		if full_exists: actual_originals += 1
		if preview_exists: actual_previews += 1
		check(full_exists == native_pack, "full original present only in native PCK: " + str(id))
		check(preview_exists == expected_preview, "only intended previews are actually packed: " + str(id))
		check(not FileAccess.file_exists(original_path), "raw original PNG bytes are not exposed through source fallback: " + str(id))
		if native_pack or expected_preview:
			check(full.texture is Texture2D and full.texture.get_size() == (original_size if native_pack else preview_size), "actual native/offline inspector pixels preserve source aspect: " + str(id))
			check(compact.texture is Texture2D and compact.texture.get_size() == preview_size, "actual prepared compact pixels preserve source aspect: " + str(id))
			check(not full.texture.get_image().is_empty() and not compact.texture.get_image().is_empty(), "packed image streams actually decode: " + str(id))
			check(full.status == "final" and compact.status == "final" and full.preview_only == not native_pack and full.label == ("" if native_pack else "VORSCHAU") and compact.label.is_empty(), "offline inspector labels true resolution: " + str(id))
			check(compact.texture_asset_path == entry.preview_asset_path, "prepared compact path is retained: " + str(id))
		else:
			check(full.texture == null and compact.texture == null and full.preview_pending and compact.preview_pending, "unfetched external art is explicitly unavailable offline: " + str(id))
			check(full.status == "preview_unavailable" and compact.status == "preview_unavailable", "absent external image is never reported loaded: " + str(id))
		check(not full.commercially_cleared and not compact.commercially_cleared, "actual package does not imply legal clearance: " + str(id))
		check(delivery.entries[id].source_sha256 == entry.sha256 and previews.entries[id].preview_sha256 == entry.preview_sha256, "delivery metadata binds immutable actual source/preview: " + str(id))
	for path in ["res://docs/production/art-evidence/source-references/of-morph-003-before-shaping.png", "res://tools/production/prepare_art_previews.gd", "res://tools/production/prepare_preview_delivery.gd", "res://addons/orafold_art_delivery/plugin.gd", "res://addons/orafold_art_delivery/exporter.gd"]:
		check(not FileAccess.file_exists(path) and not ResourceLoader.exists(path), "build-time/source artifact excluded: " + path)
	check(not FileAccess.file_exists("res://AGENTS.md") and not DirAccess.dir_exists_absolute("res://tests"), "checkout sources are invisible through fallback")
	var audio = root.get_node_or_null("GameAudio")
	check(audio != null, "actual packed project autoloads loaded")
	var service = root.get_node_or_null("ArtDelivery")
	check(service != null and service.metrics().started == 0, "offline PCK inspection starts no hidden HTTP requests")
	check(actual_previews == (count if native_pack else 5) and actual_originals == (count if native_pack else 0), "actual packed image totals satisfy native/Web policy")
	print("PRODUCTION ART EXPORTED: %d assertions, %d failures; %s PCK has %d full textures and %d prepared previews" % [assertions, failures, "native" if native_pack else "Web", actual_originals, actual_previews])
	print(JSON.stringify({"assertions": assertions, "failures": failures, "resource_root": ProjectSettings.globalize_path("res://"), "process_working_directory": OS.get_environment("PWD"), "mode": "native" if native_pack else "web", "actual_originals": actual_originals, "actual_previews": actual_previews, "declared_originals": count, "source_files_visible": FileAccess.file_exists("res://AGENTS.md")}))
	ART.clear_cache()
	if audio != null: audio.request_quit(0 if failures == 0 else 1)
	else: quit(1)
