extends SceneTree
## Ten actual authored starter-card illustration renders, not generated placeholders.
const FACE = preload("res://scripts/card_system/card_face.gd")
const ART = preload("res://scripts/production/art_resolver.gd")
const IDS = ["of-houses-020", "of-houses-094", "of-stillwatch-043", "of-stillwatch-055", "of-morph-003", "of-morph-082", "of-ninth-019", "of-ninth-095", "of-neutral-049", "of-neutral-083"]
var assertions := 0
var failures := 0
var viewport: SubViewport
var face

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)

func capture() -> Image:
	face.queue_redraw()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json"))
	var cards: Dictionary = {}
	for card in data.cards: cards[card.id] = card
	DirAccess.make_dir_recursive_absolute("res://work/production-art/batch2")
	DirAccess.make_dir_recursive_absolute("res://docs/production/screenshots")
	viewport = SubViewport.new(); viewport.size = Vector2i(756, 1056)
	viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	face = FACE.new(); face.size = Vector2(756, 1056); viewport.add_child(face)
	var sheet = Image.create(1890, 1056, false, Image.FORMAT_RGBA8)
	var back_hash := 0
	var actual_images: Dictionary = {}
	for index in IDS.size():
		var id: String = IDS[index]
		face.face_down = false; face.card = cards[id]
		var normalized = face.normalized()
		check(normalized.illustration is Texture2D and normalized.illustration.get_size() == Vector2(1448, 1086), "actual native source in card master " + id)
		check(normalized.art_status == "final" and normalized.art_label.is_empty(), "visually approved master contains no concept badge " + id)
		check(ART.resolve(cards[id]).individual, "individual provenance binding in actual card " + id)
		check(not ART.resolve(cards[id]).commercially_cleared, "visual delivery never implies legal clearance " + id)
		check(face.layout_report().title_fits and face.layout_report().rules_fit, "complete actual card title and rules fit " + id)
		check(face.layout_report().has_combat_values == (cards[id].kind == "creature"), "Wesen/Impuls/Relikt slots remain correct " + id)
		var image = await capture()
		check(image.get_size() == Vector2i(756, 1056) and image.get_pixel(0, 0).a == 0 and image.get_pixel(755, 1055).a == 0, "invariant master dimensions and outer contour " + id)
		var digest = hash(image.get_data())
		check(not actual_images.has(digest), "different real card master pixels " + id)
		actual_images[digest] = true
		image.save_png("res://work/production-art/batch2/" + id + ".png")
		image.resize(378, 528, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(0, 0, 378, 528), Vector2i((index % 5) * 378, (index / 5) * 528))
		face.face_down = true
		var back = await capture()
		if index == 0: back_hash = hash(back.get_data())
		check(hash(back.get_data()) == back_hash, "back leaks no identity or art selection " + id)
	sheet.save_png("res://docs/production/screenshots/art-batch2-masters.png")
	viewport.queue_free(); await process_frame
	ART.clear_cache()
	print("PRODUCTION ART BATCH2: %d assertions, %d failures; ten real individual starter-card master renders across five identities and all three types" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
