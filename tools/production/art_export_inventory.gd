extends SceneTree
const ART = preload("res://scripts/production/art_resolver.gd")
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_manifest.json"))
	var originals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_sources.json"))
	check(manifest.inventory_card_count == 550 and manifest.individual_original_count == 15 and manifest.compact_preview_count == 15, "actual Web PCK contains matching full/compact inventory")
	check(manifest.final_individual_count == 15 and manifest.commercially_cleared_count == 0, "actual package distinguishes visual and legal approval")
	for id in originals.entries:
		var full = ART.resolve({"id": id})
		var compact = ART.resolve({"id": id}, "compact")
		check(full.texture is Texture2D and full.texture.get_size() == Vector2(1448, 1086), "native individual illustration actually loads from Web PCK " + str(id))
		check(compact.texture is Texture2D and compact.texture.get_size() == Vector2(512, 384), "actual prepared preview loads from Web PCK " + str(id))
		check(full.texture != null and compact.texture != null and not full.texture.get_image().is_empty() and not compact.texture.get_image().is_empty(), "full and compact packaged pixel streams actually decode " + str(id))
		check(full.status == "final" and compact.status == "final" and full.label.is_empty() and compact.label.is_empty(), "actual packaged final card has no concept caption " + str(id))
		check(compact.texture_asset_path == "res://assets/cards/previews/" + str(id) + ".png", "actual package uses prepared preview instead of full-source resampling " + str(id))
		check(not full.commercially_cleared and not compact.commercially_cleared, "actual package does not imply legal clearance " + str(id))
	check(not ResourceLoader.exists("res://docs/production/art-evidence/source-references/of-morph-003-before-shaping.png"), "historical image-generation input is excluded from Web PCK")
	check(not FileAccess.file_exists("res://tools/production/prepare_art_previews.gd") and not ResourceLoader.exists("res://tools/production/prepare_art_previews.gd"), "build-time image conditioning is excluded from runtime PCK")
	check(not FileAccess.file_exists("res://AGENTS.md"), "project-source filesystem is not visible through resource fallback")
	check(not DirAccess.dir_exists_absolute("res://tests"), "test sources are not packaged or visible through fallback")
	var audio = root.get_node_or_null("GameAudio")
	check(audio != null, "actual packed project autoloads were loaded")
	print("PRODUCTION ART EXPORTED: %d assertions, %d failures; actual Web PCK has fifteen native originals and fifteen prepared previews" % [assertions, failures])
	print(JSON.stringify({"assertions": assertions, "failures": failures, "resource_root": ProjectSettings.globalize_path("res://"), "process_working_directory": OS.get_environment("PWD"), "actual_originals": originals.entries.size(), "actual_previews": manifest.compact_preview_count, "source_files_visible": FileAccess.file_exists("res://AGENTS.md")}))
	ART.clear_cache()
	if audio != null: audio.request_quit(0 if failures == 0 else 1)
	else: quit(1)
