extends SceneTree
const ART = preload("res://scripts/production/art_resolver.gd")
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func run() -> void:
	var native_pack := "--native" in OS.get_cmdline_user_args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_manifest.json"))
	var originals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_sources.json"))
	var delivery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_delivery.json"))
	check(manifest.inventory_card_count == 550 and manifest.individual_original_count == 15 and manifest.compact_preview_count == 15, "actual PCK contains matching declared illustration/preview inventory")
	check(manifest.final_individual_count == 15 and manifest.commercially_cleared_count == 0, "actual package distinguishes visual and legal approval")
	check(delivery.entries.size() == 15 and delivery.profile == "orafold-web-art-v1", "actual PCK carries fifteen content-addressed full-art delivery bindings")
	var actual_originals := 0
	var actual_previews := 0
	for id in originals.entries:
		var full = ART.resolve({"id": id})
		var compact = ART.resolve({"id": id}, "compact")
		var original_path := str(originals.entries[id].asset_path)
		var full_exists := ResourceLoader.exists(original_path, "Texture2D")
		if full_exists: actual_originals += 1
		if compact.texture != null: actual_previews += 1
		check(full_exists == native_pack, "full original is present only in native PCK: " + str(id))
		check(not FileAccess.file_exists(original_path), "original PNG source bytes are not exposed through resource fallback: " + str(id))
		check(full.texture is Texture2D and full.texture.get_size() == (Vector2(1448, 1086) if native_pack else Vector2(512, 384)), "actual packed inspector decodes the expected native/preview pixels " + str(id))
		check(compact.texture is Texture2D and compact.texture.get_size() == Vector2(512, 384), "actual prepared preview loads from Web PCK " + str(id))
		check(full.texture != null and compact.texture != null and not full.texture.get_image().is_empty() and not compact.texture.get_image().is_empty(), "full and compact packaged pixel streams actually decode " + str(id))
		check(full.status == "final" and compact.status == "final" and full.preview_only == not native_pack and full.label == ("" if native_pack else "VORSCHAU") and compact.label.is_empty(), "actual package honestly labels preview-only offline inspection " + str(id))
		check(compact.texture_asset_path == "res://assets/cards/previews/" + str(id) + ".png", "actual package uses prepared preview instead of full-source resampling " + str(id))
		check(not full.commercially_cleared and not compact.commercially_cleared, "actual package does not imply legal clearance " + str(id))
		check(delivery.entries[id].source_sha256 == ART.manifest_entry(id).sha256, "actual delivery entry matches immutable original provenance " + str(id))
	check(not ResourceLoader.exists("res://docs/production/art-evidence/source-references/of-morph-003-before-shaping.png"), "historical image-generation input is excluded from Web PCK")
	check(not FileAccess.file_exists("res://tools/production/prepare_art_previews.gd") and not ResourceLoader.exists("res://tools/production/prepare_art_previews.gd"), "build-time image conditioning is excluded from runtime PCK")
	check(not FileAccess.file_exists("res://AGENTS.md"), "project-source filesystem is not visible through resource fallback")
	check(not DirAccess.dir_exists_absolute("res://tests"), "test sources are not packaged or visible through fallback")
	var audio = root.get_node_or_null("GameAudio")
	check(audio != null, "actual packed project autoloads were loaded")
	var service = root.get_node_or_null("ArtDelivery")
	check(service != null and service.metrics().started == 0, "offline native inspection of PCK starts no hidden HTTP requests")
	print("PRODUCTION ART EXPORTED: %d assertions, %d failures; %s PCK has %d full textures and %d prepared previews" % [assertions, failures, "native" if native_pack else "Web", actual_originals, actual_previews])
	print(JSON.stringify({"assertions": assertions, "failures": failures, "resource_root": ProjectSettings.globalize_path("res://"), "process_working_directory": OS.get_environment("PWD"), "mode": "native" if native_pack else "web", "actual_originals": actual_originals, "actual_previews": actual_previews, "source_files_visible": FileAccess.file_exists("res://AGENTS.md")}))
	ART.clear_cache()
	if audio != null: audio.request_quit(0 if failures == 0 else 1)
	else: quit(1)
