extends SceneTree
## Technical image conditioning only: original illustrations remain unchanged.
## Reproducible 512px previews avoid full original decode/resample on compact UI.
const MAX_EDGE := 512
const SOURCE := "res://data/production/art_sources.json"
const OUTPUT := "res://data/production/art_previews.json"
var assertions := 0
var failures := 0
var checking := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> bool:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
	return ok

func digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(bytes); return context.finish().hex_encode()

func prepare_import(path: String) -> void:
	var settings = ConfigFile.new()
	var sidecar := path + ".import"
	var exists := settings.load(sidecar) == OK
	if not checking:
		var imported := "res://.godot/imported/" + path.get_file() + "-" + path.md5_text() + ".ctex"
		if not exists:
			settings.set_value("remap", "importer", "texture")
			settings.set_value("remap", "type", "CompressedTexture2D")
			settings.set_value("remap", "path", imported)
			settings.set_value("remap", "metadata", {"vram_texture": false})
			settings.set_value("deps", "source_file", path)
			settings.set_value("deps", "dest_files", PackedStringArray([imported]))
		settings.set_value("params", "compress/mode", 1)
		settings.set_value("params", "compress/lossy_quality", 0.9)
		settings.set_value("params", "mipmaps/generate", true)
		settings.set_value("params", "process/size_limit", 0)
		check(settings.save(sidecar) == OK, "preview runtime import profile saved: " + path)
	else:
		check(exists and settings.get_value("params", "compress/mode", -1) == 1 and is_equal_approx(float(settings.get_value("params", "compress/lossy_quality", 0)), 0.9) and bool(settings.get_value("params", "mipmaps/generate", false)) and settings.get_value("params", "process/size_limit", -1) == 0, "committed preview uses native-size quality90 mipmapped import: " + path)

func run() -> void:
	checking = "--check" in OS.get_cmdline_user_args()
	var source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not check(source is Dictionary and source.get("entries") is Dictionary, "real source illustration inventory required"):
		finish(); return
	var ids: Array = source.entries.keys(); ids.sort()
	var entries: Dictionary = {}
	var id_pattern = RegEx.create_from_string("^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$")
	var card_dir = DirAccess.open("res://assets/cards")
	if not check(card_dir != null and not card_dir.is_link("originals") and not card_dir.is_link("previews"), "illustration/preview directories cannot be symlink escapes"):
		finish(); return
	if not checking: DirAccess.make_dir_recursive_absolute("res://assets/cards/previews")
	var original_dir = DirAccess.open("res://assets/cards/originals")
	var preview_dir = DirAccess.open("res://assets/cards/previews")
	for id in ids:
		if not check(id_pattern.search(str(id)) != null, "safe card ID for preview: " + str(id)): continue
		var expected_source := "res://assets/cards/originals/" + str(id) + ".png"
		var source_entry: Dictionary = source.entries[id]
		if not check(source_entry.get("asset_path", "") == expected_source and not original_dir.is_link(str(id) + ".png"), "matching safe source path: " + str(id)): continue
		if not check(FileAccess.get_sha256(expected_source) == source_entry.get("sha256", ""), "source bytes match original provenance: " + str(id)): continue
		var image = Image.new()
		if not check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(expected_source)) == OK and not image.is_empty(), "actual source image decoded: " + str(id)): continue
		var original_width := image.get_width(); var original_height := image.get_height()
		if not check(original_width == int(source_entry.get("original_width", 0)) and original_height == int(source_entry.get("original_height", 0)), "original dimensions remain bound to native source: " + str(id)): continue
		var ratio := minf(1.0, float(MAX_EDGE) / float(maxi(original_width, original_height)))
		var width := maxi(1, roundi(original_width * ratio)); var height := maxi(1, roundi(original_height * ratio))
		image.clear_mipmaps()
		if image.get_width() != width or image.get_height() != height: image.resize(width, height, Image.INTERPOLATE_LANCZOS)
		var png := image.save_png_to_buffer()
		if not check(not png.is_empty(), "actual preview pixels encoded: " + str(id)): continue
		var preview_path := "res://assets/cards/previews/" + str(id) + ".png"
		if not check(preview_dir != null and not preview_dir.is_link(str(id) + ".png"), "safe preview destination: " + str(id)): continue
		var sha := digest(png)
		entries[id] = {"asset_path": preview_path, "source_asset_path": expected_source, "source_sha256": source_entry.sha256, "source_width": original_width, "source_height": original_height, "width": width, "height": height, "sha256": sha, "transform": "Godot Image.resize Lanczos; downsample only; no creative changes", "profile": "compact-512-v1"}
		if checking:
			check(FileAccess.file_exists(preview_path) and FileAccess.get_sha256(preview_path) == sha, "committed preview exactly matches fresh original downsample: " + str(id))
		else:
			var file = FileAccess.open(preview_path, FileAccess.WRITE)
			if check(file != null, "preview file writable: " + str(id)): file.store_buffer(png); file.close()
		prepare_import(preview_path)
	var result := {"schema_version": 1, "profile": "compact-512-v1", "maximum_edge": MAX_EDGE, "generator": "Godot4.6.3 Image.resize Lanczos", "individual_original_count_added": 0, "preview_count": entries.size(), "entries": entries}
	var text := JSON.stringify(result, "  ", true) + "\n"
	if checking:
		check(FileAccess.file_exists(OUTPUT) and FileAccess.get_file_as_string(OUTPUT) == text, "preview manifest is reproducible and current")
	else:
		var manifest = FileAccess.open(OUTPUT, FileAccess.WRITE)
		if check(manifest != null, "preview manifest writable"): manifest.store_string(text); manifest.close()
	finish()

func finish() -> void:
	print("PRODUCTION ART PREVIEWS: %d assertions, %d failures; native originals unchanged, actual 512px derivatives %s" % [assertions, failures, "verified" if checking else "generated"])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
