extends SceneTree
## Authoring-only design mockups; never registered with a playable card catalog.
## Reads ignored authoring images directly; no import or export inclusion needed.
const Face = preload("res://scripts/card_system/card_face.gd")

class PreviewFace:
	extends "res://scripts/card_system/card_face.gd"
	# This override exists only in this authoring tool. The production Face and
	# its resource validation/fallback behavior remain completely unchanged.
	var preview_texture: Texture2D
	var preview_source_path := ""

	func normalized() -> Dictionary:
		var data := super.normalized()
		var artwork = card.get("art", {})
		if artwork is Dictionary and artwork.get("status") == "concept" and preview_texture != null:
			data.illustration = preview_texture
			data.art_status = "concept"
			data.art_label = "KONZEPTILLUSTRATION"
			data.preview_source_path = preview_source_path
		return data

const OUTPUT = "res://work/production/previews/"
const MOCK_TEXT = "BILDVORSCHLAG – keine Spieldefinition. Werte sind Platzhalter."
const POWERS = {
	"Zwölf Häuser": "houses", "Stillwacht": "stillwatch", "Vielgestalt": "morph",
	"Neunte Stunde": "ninth", "Neutral": "neutral"
}
const KINDS = {"Wesen": "creature", "Impuls": "event", "Relikt": "relic"}
const RARITIES = {"Gewöhnlich": "common", "Selten": "rare", "Episch": "epic", "Legendär": "legendary"}
const SPECIES = {
	"Menschen": "human", "Bestien": "beast", "Geister": "spirit", "Konstrukte": "construct",
	"Pflanzen": "plant", "Amalgame": "amalgam", "Morphiden": "morphid", "Paradoxe": "paradox",
	"Wiedergänger": "revenant", "Elementare": "elemental", "Zehrer": "devourer", "Mechanoide": "mechanoid"
}
var assertions := 0
var failures := 0
var viewport: SubViewport
var face

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
	return condition

func read_json(resource_path: String):
	if not check(FileAccess.file_exists(resource_path), "input exists: " + resource_path):
		return null
	var parser := JSON.new()
	if not check(parser.parse(FileAccess.get_file_as_string(resource_path)) == OK, "valid JSON: " + resource_path):
		return null
	return parser.data

func capture() -> Image:
	face.queue_redraw()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func alpha_mask(image: Image) -> PackedByteArray:
	var rgba: Image = image.duplicate()
	rgba.convert(Image.FORMAT_RGBA8)
	var pixels := rgba.get_data()
	var mask := PackedByteArray()
	mask.resize(image.get_width() * image.get_height())
	for index in mask.size():
		mask[index] = pixels[index * 4 + 3]
	return mask

func save_image(image: Image, filename: String) -> void:
	check(image.save_png(OUTPUT + filename) == OK, "saved preview: " + filename)

func finish() -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()
		await process_frame
	print("PRODUCTION ART PREVIEW: %d assertions, %d failures; design mockups only, no gameplay definitions" % [assertions, failures])
	var audio = root.get_node_or_null("GameAudio")
	if audio != null:
		audio.request_quit(0 if failures == 0 else 1)
	else:
		quit(0 if failures == 0 else 1)

func run() -> void:
	if not check(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK, "preview output directory available"):
		await finish()
		return
	var manifest = read_json("res://data/production/art-assets.json")
	var concepts = read_json("res://data/lore/card-concepts.json")
	if not check(manifest is Dictionary and manifest.get("entries") is Array and concepts is Array, "manifest and concepts have expected containers"):
		await finish()
		return
	var concept_by_id: Dictionary = {}
	for concept in concepts:
		concept_by_id[str(concept.id)] = concept
	var brief_by_id: Dictionary = {}
	for source in ["houses", "stillwatch", "morph", "ninth", "neutral"]:
		var briefs = read_json("res://data/production/art-briefs/%s.json" % source)
		if not check(briefs is Array, "brief file is an array: " + source):
			await finish()
			return
		for brief in briefs:
			brief_by_id[str(brief.card_id)] = brief
	var entries: Array = manifest.entries
	if not check(entries.size() > 0 and entries.size() <= 10, "bounded nonempty pilot preview batch"):
		await finish()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(756, 1056)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	face = PreviewFace.new()
	face.size = Vector2(756, 1056)
	viewport.add_child(face)
	var sheet := Image.create(entries.size() * 378, 528, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1018"))
	var reference_mask := PackedByteArray()
	var reference_back := PackedByteArray()
	var rendered: Array = []
	var seen: Dictionary = {}
	for entry in entries:
		var card_id := str(entry.get("card_id", ""))
		if not check(not seen.has(card_id) and concept_by_id.has(card_id) and brief_by_id.has(card_id), "unique pilot has concept and brief: " + card_id):
			continue
		seen[card_id] = true
		var concept: Dictionary = concept_by_id[card_id]
		var brief: Dictionary = brief_by_id[card_id]
		var asset_path := str(entry.get("asset_path", ""))
		if not check(asset_path == "assets/production/illustrations/%s.png" % card_id, "pilot resource uses expected individual path: " + card_id):
			continue
		var resource_path := "res://" + asset_path
		if not check(FileAccess.file_exists(resource_path), "raw individual illustration exists: " + card_id):
			continue
		var source_image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
		if not check(source_image != null and not source_image.is_empty(), "raw image decodes without importing authoring assets: " + card_id):
			continue
		face.preview_texture = ImageTexture.create_from_image(source_image)
		face.preview_source_path = resource_path
		var species_ids: Array[String] = []
		for species_name in concept.get("species", []):
			if check(SPECIES.has(str(species_name)), "official species mapping: " + str(species_name)):
				species_ids.append(SPECIES[str(species_name)])
		# Only a transient renderer input. Costs and stats deliberately have no
		# mechanical meaning and are visibly identified as placeholders on-card.
		var mock := {
			"schema_version": 2, "id": card_id, "name": str(brief.proposed_name),
			"power": POWERS.get(str(concept.affiliation), "neutral"),
			"kind": KINDS.get(str(concept.card_type), "creature"),
			"rarity": RARITIES.get(str(concept.rarity), "common"),
			"species": species_ids, "energy_cost": 0, "attack": 0, "health": 1,
			"text_de": MOCK_TEXT,
			# Deliberately not a res:// asset ID: production loading must not be
			# involved. PreviewFace supplies the directly decoded ImageTexture.
			"art": {"status": "concept", "asset_id": "authoring-preview:" + card_id}
		}
		face.face_down = false
		face.card = mock
		var normalized: Dictionary = face.normalized()
		var layout: Dictionary = face.layout_report()
		if not check(normalized.illustration is Texture2D and not layout.art_is_shared, "actual individual image loaded, no atlas: " + card_id):
			continue
		check(normalized.art_status == "concept" and normalized.art_label == "KONZEPTILLUSTRATION", "honest concept caption: " + card_id)
		check(normalized.get("preview_source_path") == resource_path and normalized.illustration == face.preview_texture, "preview binds exactly assigned raw asset: " + card_id)
		check(layout.title_fits and layout.rules_fit, "name and mock disclaimer fit: " + card_id)
		check(layout.master_size == Vector2(756, 1056) and layout.face == Rect2(0, 0, 756, 1056), "unchanged native card geometry: " + card_id)
		check(Face.OUTER.encloses(layout.art) and Face.OUTER.encloses(layout.rules) and Face.OUTER.encloses(layout.title), "semantic panels remain inside shared contour: " + card_id)
		var image := await capture()
		check(image.get_size() == Vector2i(756, 1056), "actual native render dimensions: " + card_id)
		var mask := alpha_mask(image)
		if reference_mask.is_empty():
			reference_mask = mask
		check(mask == reference_mask, "same front silhouette: " + card_id)
		check(image.get_pixel(0, 0).a == 0 and image.get_pixel(755, 1055).a == 0, "transparent outside card contour: " + card_id)
		save_image(image, card_id + "-design-mock.png")
		var actual_art := image.get_region(Rect2i(70, 210, 590, 270)).get_data()
		var fallback := mock.duplicate(true)
		fallback.art = {"status": "shared_concept", "asset_id": "shared:orafold-atlas"}
		face.card = fallback
		var fallback_image := await capture()
		check(actual_art != fallback_image.get_region(Rect2i(70, 210, 590, 270)).get_data(), "actual art pixels differ from atlas fallback: " + card_id)
		face.card = mock
		face.face_down = true
		var back := await capture()
		var back_bytes := back.get_data()
		if reference_back.is_empty():
			reference_back = back_bytes
			save_image(back, "shared-back.png")
		check(back_bytes == reference_back, "identical card back for every pilot: " + card_id)
		check(alpha_mask(back) == reference_mask, "back and front have identical contour: " + card_id)
		var thumb: Image = image.duplicate()
		thumb.resize(378, 528, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumb, Rect2i(0, 0, 378, 528), Vector2i(rendered.size() * 378, 0))
		rendered.append({"card_id": card_id, "proposed_name": brief.proposed_name, "asset_path": resource_path, "art_status": "concept", "lore_status": "VORSCHLAG", "file": card_id + "-design-mock.png"})
	check(rendered.size() == entries.size(), "every manifest pilot rendered successfully")
	save_image(sheet, "contact-sheet.png")
	var report_file := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	if check(report_file != null, "preview report writable"):
		var report := {"scope": "authoring_design_mockups_only", "warning_de": MOCK_TEXT, "playable_definitions_created": 0, "active_catalog_changes": 0, "native_size": [756, 1056], "entries": rendered, "assertions": assertions, "failures": failures}
		report_file.store_string(JSON.stringify(report, "  ") + "\n")
		report_file.close()
	await finish()
