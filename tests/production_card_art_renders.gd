extends SceneTree
## Rendered proof that individual art is separated from all deterministic UI.
const FACE = preload("res://scripts/card_system/card_face.gd")
const ART = preload("res://scripts/production/art_resolver.gd")
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
	var by_id: Dictionary = {}
	for card in data.cards: by_id[card.id] = card
	DirAccess.make_dir_recursive_absolute("res://work/production-art/renders")
	DirAccess.make_dir_recursive_absolute("res://docs/production/screenshots")
	viewport = SubViewport.new(); viewport.size = Vector2i(756, 1056)
	viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	face = FACE.new(); face.size = Vector2(756, 1056); viewport.add_child(face)
	var originals: Dictionary = {}
	var sheet = Image.create(1890, 528, false, Image.FORMAT_RGBA8)
	var index := 0
	for id in ["oa-houses-c01", "oa-stillwatch-c01", "oa-morph-c01", "oa-ninth-c01", "oa-neutral-c02"]:
		var card: Dictionary = by_id[id].duplicate(true)
		originals[id] = JSON.stringify(card)
		face.card = card
		check(face.normalized().illustration is Texture2D, "individual art used by actual master renderer " + id)
		check(face.normalized().art_status == "final" and face.normalized().art_label.is_empty(), "approved visual state appears in actual master " + id)
		var rendered = await capture()
		check(rendered.get_size() == Vector2i(756, 1056), "master pixels stay invariant " + id)
		check(rendered.get_pixel(0, 0).a == 0 and rendered.get_pixel(755, 1055).a == 0, "illustration never exceeds outer card margin " + id)
		rendered.save_png("res://work/production-art/renders/" + id + ".png")
		if id == "oa-neutral-c02": rendered.save_png("res://docs/production/screenshots/card-illustration-after.png")
		var thumb = rendered.duplicate(); thumb.resize(378, 528, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumb, Rect2i(0, 0, 378, 528), Vector2i(index * 378, 0)); index += 1
		check(JSON.stringify(card) == originals[id], "rendering never changes card stats, abilities or source data " + id)
	sheet.save_png("res://docs/production/screenshots/five-individual-concepts.png")
	var old: Dictionary = by_id["oa-neutral-c02"].duplicate(true)
	old.art = {"status": "shared_concept", "asset_id": "res://assets/cards/originals/deliberately-unavailable-before.png"}
	face.card = old
	check(face.normalized().illustration == null, "controlled before view uses original shared-atlas fallback")
	var before = await capture(); before.save_png("res://docs/production/screenshots/card-illustration-before.png")
	face.face_down = true
	var back = await capture(); var fingerprint = hash(back.get_data())
	for id in originals:
		face.card = by_id[id]
		var hidden = await capture()
		check(hash(hidden.get_data()) == fingerprint, "all individual image bindings retain identical information-free back " + id)
	viewport.queue_free(); await process_frame
	ART.clear_cache()
	print("PRODUCTION CARD ART RENDERS: %d assertions, %d failures; 5 real illustrated masters, shared-atlas before/after and identical backs" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
