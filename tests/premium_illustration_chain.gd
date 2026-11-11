extends SceneTree
## Actual rendered 550-card presentation coverage. This is not a match simulation.
const Catalog = preload("res://scripts/production/catalog.gd")
const CardView = preload("res://scripts/alpha/card_view.gd")
const Face = preload("res://scripts/card_system/card_face.gd")
const ART = preload("res://scripts/production/art_resolver.gd")
const OUTPUT = "res://work/premium-mobile/illustration-chain"
var assertions := 0
var failures := 0
var records: Array = []
var viewport: SubViewport
var hand
var library
var board
var face

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)
func digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func observed(view, id: String, role: String) -> Dictionary:
	var report: Dictionary = view.art_report()
	check(report.card_id == id and report.visible, role + " observes actual visible ID " + id)
	check(report.status == "final" and not report.pending, role + " has actual final pixels " + id)
	check(report.pixels.size() == 2 and report.pixels[0] > 0 and report.pixels[1] > 0, role + " decoded texture " + id)
	return report
func make_view(role: String, dimensions: Vector2, at: Vector2):
	var view = CardView.new()
	view.set("display_role", role)
	view.size = dimensions
	view.position = at
	view.reduced_motion = true
	viewport.add_child(view)
	return view
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(560, 370)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	hand = make_view("hand", Vector2(90, 126), Vector2(8, 8))
	library = make_view("library", Vector2(126, 176), Vector2(110, 8))
	board = make_view("board", Vector2(160, 90), Vector2(8, 210))
	face = Face.new()
	face.position = Vector2(280, 8)
	face.size = Vector2(252, 352)
	viewport.add_child(face)
	var catalog = Catalog.new()
	var cards: Array = catalog.all_cards()
	check(cards.size() == 550, "actual active production catalog, no synthetic records")
	var sheets: Dictionary = {}
	var counts: Dictionary = {}
	var fingerprints: Dictionary = {}
	var creatures := 0
	var source = FileAccess.get_sha256("res://data/production/cards.json")
	for power in ["houses", "stillwatch", "morph", "ninth", "neutral"]:
		sheets[power] = Image.create(990, 1260, false, Image.FORMAT_RGBA8)
		sheets[power].fill(Color.TRANSPARENT)
		counts[power] = 0
	for card in cards:
		hand.card = card
		library.card = card
		library.library = true
		face.card = card
		board.visible = card.kind == "creature"
		if board.visible:
			creatures += 1
			board.card = card
			board.unit = {"id": card.id, "atk": int(card.atk), "hp": int(card.hp), "ward": 2, "block": 1, "stun": 0, "summoned": false}
			board.combat_ready = true
		for view in [hand, library, board, face]: view.queue_redraw()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var row = {"id": card.id, "power": card.faction, "kind": card.kind, "rarity": card.rarity,
			"hand": observed(hand, card.id, "hand"), "library": observed(library, card.id, "library")}
		if board.visible:
			row.board = observed(board, card.id, "battlefield")
			var status: Dictionary = board.board_status()
			check(status.shield == 2 and status.block == 1 and status.ready, "permanent separate battlefield values " + card.id)
		var normalized: Dictionary = face.normalized()
		check(normalized.illustration is Texture2D and normalized.art_status == "final", "actual inspection renderer texture " + card.id)
		var layout: Dictionary = face.layout_report()
		check(layout.title_fits and layout.rules_fit, "complete inspection title and effects " + card.id)
		check(layout.has_combat_values == (card.kind == "creature"), "only Wesen show attack/life " + card.id)
		var rendered: Image = viewport.get_texture().get_image()
		var thumbnail: Image = rendered.get_region(Rect2i(8, 8, 90, 126))
		var fingerprint = digest(thumbnail.get_data())
		check(not fingerprints.has(fingerprint), "individual actual hand render " + card.id)
		fingerprints[fingerprint] = card.id
		row.render_sha256 = fingerprint
		var colors: Dictionary = {}
		for y in range(24, 64, 4):
			for x in range(18, 72, 4):
				colors[thumbnail.get_pixel(x, y).to_rgba32()] = true
		check(colors.size() >= 20, "actual illustration region is not a blank/text-only tile " + card.id)
		row.art_region_sample_colors = colors.size()
		var index: int = counts[card.faction]
		sheets[card.faction].blit_rect(thumbnail, Rect2i(0, 0, 90, 126), Vector2i((index % 11) * 90, int(index / 11) * 126))
		counts[card.faction] += 1
		records.append(row)
		if records.size() % 110 == 0: print("PREMIUM ART CHAIN rendered ", records.size(), "/550")
	for power in sheets:
		check(counts[power] == 110, "all110 actual cards in contact sheet " + power)
		check(sheets[power].save_png(OUTPUT.path_join(power + ".png")) == OK, "actual rendered contact sheet " + power)
	check(creatures == 357, "all357 real battlefield creatures")
	check(FileAccess.get_sha256("res://data/production/cards.json") == source, "presentation never mutates catalog")
	var manifest = {"scope": "Actual native Godot hand/library/inspection550 and battlefield357; arranged presentation, not550 played games or physical-device QA",
		"catalog_sha256": source, "card_view_sha256": FileAccess.get_sha256("res://scripts/alpha/card_view.gd"),
		"card_face_sha256": FileAccess.get_sha256("res://scripts/card_system/card_face.gd"), "godot": Engine.get_version_info().string,
		"assertions": assertions, "failures": failures, "cards": records, "counts": counts, "battlefield_creatures": creatures}
	var file = FileAccess.open(OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	viewport.queue_free()
	for frame in 3: await process_frame
	ART.clear_cache()
	print("PREMIUM ART CHAIN: %d assertions, %d failures;550 actual hand/library/inspection,357 actual battlefield render bindings" % [assertions, failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
