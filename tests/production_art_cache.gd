extends SceneTree
## Render all fifteen delivered originals as compact nodes plus a full inspector.
## Repeated redraws must reuse per-control bindings, not churn the eight/full LRU.
const ART = preload("res://scripts/production/art_resolver.gd")
const CARD = preload("res://scripts/alpha/card_view.gd")
const FACE = preload("res://scripts/card_system/card_face.gd")
var assertions := 0
var failures := 0
var viewport: SubViewport
var controls: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)

func frames(count := 3) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json"))
	var by_id: Dictionary = {}
	for card in data.cards: by_id[card.id] = card
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_sources.json"))
	var ids: Array = source.entries.keys(); ids.sort(); ids = ids.slice(0,24)
	check(ids.size() >= 15 and ids.size() <= 24, "actual bounded current page of15..24 delivered originals exercises simultaneous view")
	ART.clear_cache(true)
	viewport = SubViewport.new(); viewport.size = Vector2i(1280, 900)
	viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var start := Time.get_ticks_usec()
	for index in ids.size():
		var card = CARD.new(); card.card = by_id[ids[index]]
		card.position = Vector2((index % 5) * 158, (index / 5) * 220)
		card.size = Vector2(150, 210); card.library = true
		viewport.add_child(card); controls.append(card)
	var inspector = FACE.new(); inspector.card = by_id[ids[0]]
	inspector.position = Vector2(820, 0); inspector.size = Vector2(440, 615)
	viewport.add_child(inspector); controls.append(inspector)
	await frames()
	var first_draw_usec := Time.get_ticks_usec() - start
	var initial: Dictionary = ART.stats().duplicate(true)
	check(initial.profiles.compact > 0 and initial.profiles.compact <= ids.size() and initial.profiles.full == 1, "bounded shared cache retains inspector and fitting visible previews")
	for control in controls:
		check(control._illustration_data.get("texture") is Texture2D, "all actual visible Controls retain their image even when an LRU entry is evicted")
	check(initial.loads == ids.size()+1 and initial.thumbnail_builds == 0, "each prepared compact preview loads once, no source resampling on first display")
	check(initial.estimated_retained_bytes < ART.MAX_CACHE_BYTES, "actual fifteen compact views plus inspector remain under 32 MiB cache estimate")
	for id in ids:
		var preview = ART.resolve(by_id[id], "compact")
		check(preview.texture is Texture2D and preview.texture.get_size() == Vector2(ART.manifest_entry(id).preview_width, ART.manifest_entry(id).preview_height), "compact preview has explicit appropriate dimensions " + str(id))
		check(preview.texture.get_image().has_mipmaps(), "compact preview has real mip pyramid " + str(id))
	var before: Dictionary = ART.stats().duplicate(true)
	for redraw in 20:
		for control in controls: control.queue_redraw()
		await frames(1)
	var after: Dictionary = ART.stats().duplicate(true)
	check(after.loads == before.loads and after.thumbnail_builds == before.thumbnail_builds, "twenty real redraws do not reload/resample images")
	check(after.hits == before.hits, "per-control binding cache avoids resolver lookup on unchanged redraw")
	var previous_key = ART.binding_key(by_id[ids[0]], "compact")
	ART.clear_cache()
	check(ART.binding_key(by_id[ids[0]], "compact") != previous_key, "explicit cache release invalidates control keys")
	for control in controls: control.queue_redraw()
	await frames()
	check(ART.stats().loads == ids.size()+1, "explicit release rebinds each visible profile exactly once")
	DirAccess.make_dir_recursive_absolute("res://work/production-art")
	var f = FileAccess.open("res://work/production-art/cache-measurement.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"originals": ids.size(), "first_draw_usec": first_draw_usec, "before_redraws": before, "after_redraws": after, "redraws": 20, "renderer_texture_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED), "assertions": assertions, "failures": failures, "scope": "Linux software renderer; no physical iPhone claim; estimates exclude other browser memory"}, "  ")); f.close()
	viewport.queue_free(); await process_frame
	ART.clear_cache()
	print("PRODUCTION ART CACHE: %d assertions, %d failures; %d actual illustrated compact cards and one full inspector, twenty rendered redraws" % [assertions, failures, ids.size()])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
