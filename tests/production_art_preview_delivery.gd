extends SceneTree
## Real compact WebP HTTP, priority and cancellation. Cache stress below is an
## explicitly synthetic texture-allocation fixture, never a playable card.
const ART = preload("res://scripts/production/art_resolver.gd")
const DELIVERY = preload("res://scripts/production/art_delivery.gd")
var assertions := 0
var failures := 0
var base_url := ""
var ids: Array = []
var service: Node
var owners: Array[Node] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", label)
func attach(route: String) -> void:
	for owner in owners:
		if is_instance_valid(owner): owner.free()
	owners.clear()
	var previous = root.get_node_or_null("ArtDelivery")
	if previous != null: root.remove_child(previous); previous.free()
	ART.clear_cache()
	service = DELIVERY.new(base_url + route + "/"); service.name = "ArtDelivery"; root.add_child(service)
	await process_frame
func owner_node() -> Node:
	var value := Node.new(); root.add_child(value); owners.append(value); return value
func settled(completed: int, rejected: int, label: String) -> void:
	var until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until:
		var m: Dictionary = service.metrics()
		if m.completed >= completed and m.rejected >= rejected and m.active.is_empty() and m.queued == 0: break
		await process_frame
	var m: Dictionary = service.metrics()
	check(m.completed == completed and m.rejected == rejected and m.active.is_empty() and m.queued == 0, "actual HTTP settles: " + label)
func failed(route: String, bad_dimensions := false) -> void:
	await attach(route)
	var id: String = ids[0]
	if bad_dimensions: service._previews[id].width += 1
	service.request_preview(id, owner_node())
	await settled(0, 1, "compact " + route)
	check(not ART.has_preview_texture(id) and service.state_for(id, "compact") == "failed", "bad compact body stays outside cache: " + route)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: check(false, "actual loopback URL required"); finish(); return
	base_url = args[0]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_preview_delivery.json"))
	for id in manifest.entries:
		if manifest.entries[id].delivery == "external": ids.append(id)
	ids.sort()
	check(ids.size() >= 2 and manifest.pinned_card_ids.size() == 5, "real external compact derivatives and five pinned starters")
	await attach("ok")
	var id: String = ids[0]
	service.request_preview(id, owner_node())
	await settled(1, 0, "real compact WebP")
	var value: Dictionary = ART.resolve({"id":id}, "compact", null, false)
	var entry: Dictionary = manifest.entries[id]
	check(value.texture is Texture2D and value.texture.get_size() == Vector2(entry.width, entry.height), "actual HTTP compact decodes exact prepared geometry")
	check(value.texture.get_image().has_mipmaps() and value.label.is_empty() and not value.commercially_cleared, "actual compact mipmaps and separate visual/legal status")
	check(service.metrics().started_profiles == {"compact":1,"full":0}, "collection preview does not fetch full original")
	service.request_preview(id, owners[0]); await process_frame
	check(service.metrics().started == 1, "visible redraw reuses verified compact cache")
	for route in ["missing","hash","redirect","oversized"]: await failed(route)
	await failed("dimensions", true)
	await attach("slow")
	var cancelled_owner := owner_node()
	service.request_preview(id, cancelled_owner); await process_frame
	check(service.metrics().active == "compact|" + id, "real preview is active before cancellation")
	service.release_owner(cancelled_owner); cancelled_owner.free()
	for frame in 5: await process_frame
	check(service.metrics().cancelled == 1 and service.metrics().active.is_empty() and service.metrics().queued == 0, "released visible owner cancels real in-flight preview")
	check(service.state_for(id,"compact") == "preview" and not ART.has_preview_texture(id), "cancelled preview neither plays a card nor enters texture cache")
	await attach("slow")
	var retained_owner := owner_node()
	service.request_preview(id, retained_owner); await process_frame
	service.request_preview(str(ids[1]), retained_owner)
	service.request_full(id, retained_owner)
	await settled(3, 0, "full preempts compact and resumes visible previews")
	check(service.metrics().cancelled == 1 and service.metrics().started_profiles.full == 1 and service.metrics().started_profiles.compact == 3, "actual request priority cancels one preview, fetches inspector, then resumes two compact requests")
	check(ART.has_full_texture(id) and ART.has_preview_texture(id) and ART.has_preview_texture(str(ids[1])), "full and both visible previews survive priority handoff")
	await attach("slow")
	var clipping := Control.new(); clipping.size = Vector2(100,100); clipping.clip_contents = true; root.add_child(clipping); owners.append(clipping)
	var clipped := Control.new(); clipped.size = Vector2(44,44); clipped.position = Vector2(200,0); clipping.add_child(clipped)
	await process_frame
	service.request_preview(id, clipped); await process_frame
	check(service.metrics().started == 0 and not ART.visible_owner(clipped), "scroll-clipped Control starts no image request despite visible_in_tree")
	clipped.position = Vector2.ZERO; service.request_preview(id, clipped); await process_frame
	check(service.metrics().started == 1 and ART.visible_owner(clipped), "entering actual clip rectangle admits visible preview request")
	clipped.position = Vector2(200,0)
	for frame in 4: await process_frame
	check(service.metrics().cancelled == 1 and service.metrics().active.is_empty(), "scrolling Control out of clip cancels its real HTTP request")
	# Restore a live ordinary owner for the cache allocation fixture.
	retained_owner = owner_node()
	# Force the worst shared-cache boundary using real texture allocations. This
	# is a cache fixture, not an invented image or card in the production pool.
	ART.clear_cache()
	var preview_image := Image.create(512,384,false,Image.FORMAT_RGBA8); preview_image.fill(Color(0.2,0.3,0.4)); preview_image.generate_mipmaps()
	var preview_texture := ImageTexture.create_from_image(preview_image)
	for n in 24:
		var fixture_id := "cache-fixture-" + str(n)
		service._owners["compact|" + fixture_id] = {retained_owner.get_instance_id(): weakref(retained_owner)}
		check(ART._retain("synthetic-cache-preview-" + str(n), preview_texture, "compact", fixture_id), "visible compact retained at stress boundary " + str(n))
	var full_image := Image.create(1491,1087,false,Image.FORMAT_RGBA8); full_image.fill(Color(0.4,0.3,0.2)); full_image.generate_mipmaps()
	var full_texture := ImageTexture.create_from_image(full_image)
	check(ART._retain("synthetic-cache-full", full_texture, "full", "cache-inspector-fixture"), "full inspector is admitted even when24 retained previews are visible")
	check(ART.stats().estimated_retained_bytes <= ART.MAX_CACHE_BYTES and ART.stats().retained_textures <= ART.MAX_CACHE_ENTRIES and ART.stats().profiles.full == 1, "actual shared cache stays bounded while prioritizing full image")
	finish()
func finish() -> void:
	for owner in owners:
		if is_instance_valid(owner): owner.free()
	owners.clear()
	if is_instance_valid(service): service.free()
	ART.clear_cache()
	print("PRODUCTION PREVIEW HTTP: %d assertions, %d failures; actual compact WebP, corruption/geometry/redirect/limit rejection, owner cancellation, full priority, bounded cache" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
