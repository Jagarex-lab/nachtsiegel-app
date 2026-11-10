extends SceneTree
## Real loopback HTTP exercises delivery; private-entry edits inject only a bad
## expected dimension. All success bodies are the committed native-size WebPs.
const ART = preload("res://scripts/production/art_resolver.gd")
const DELIVERY = preload("res://scripts/production/art_delivery.gd")
var assertions := 0
var failures := 0
var base_url := ""
var ids: Array = []
var service: Node

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)

func attach(route: String) -> void:
	var previous = root.get_node_or_null("ArtDelivery")
	if previous != null: root.remove_child(previous); previous.free()
	ART.clear_cache()
	service = DELIVERY.new(base_url + route + "/")
	service.name = "ArtDelivery"; root.add_child(service)
	await process_frame
	check(service.external_enabled(), "actual loopback origin enabled for " + route)

func settled(completed: int, rejected: int, label: String) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var metrics: Dictionary = service.metrics()
		if metrics.completed >= completed and metrics.rejected >= rejected and metrics.active.is_empty() and metrics.queued == 0: break
		await process_frame
	var metrics: Dictionary = service.metrics()
	check(metrics.completed == completed and metrics.rejected == rejected and metrics.active.is_empty() and metrics.queued == 0, "actual HTTP requests settle: " + label)

func failed_route(route: String, alter_dimensions := false) -> void:
	await attach(route)
	var id: String = ids[0]
	if alter_dimensions:
		# Keep actual immutable body, byte length and SHA; only the expected
		# geometry is deliberately false so decode/dimension validation is reached.
		service._entries[id].width = int(service._entries[id].width) + 1
	var first := ART.resolve({"id": id})
	check(first.preview_only and first.texture.get_size() == Vector2(512, 384), "immediate real preview before " + route)
	await settled(0, 1, route)
	var fallback := ART.resolve({"id": id})
	check(fallback.preview_only and fallback.texture.get_size() == Vector2(512, 384), "real preview remains after " + route)
	check(fallback.delivery_state == "failed" and fallback.label == "VORSCHAU · OFFLINE", "honest failed delivery state after " + route)
	check(not ART.has_full_texture(id), "rejected bytes never enter full-art cache: " + route)
	var starts: int = service.metrics().started
	for attempt in 5: service.request_full(id)
	for frame in 3: await process_frame
	check(service.metrics().started == starts, "failed request respects retry cooldown: " + route)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		check(false, "runner must supply actual loopback HTTP base URL"); finish(); return
	base_url = args[0]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/art_delivery.json"))
	ids = manifest.entries.keys(); ids.sort()
	check(ids.size() == 15, "fifteen actual native-size WebP deliveries available")
	await attach("ok")
	for id in ids:
		var compact := ART.resolve({"id": id}, "compact")
		check(compact.texture is Texture2D and compact.texture.get_size() == Vector2(512, 384), "real compact preview without HTTP: " + str(id))
	for frame in 3: await process_frame
	check(service.metrics().started == 0, "compact collection does not start any HTTP request")
	var id: String = ids[0]
	var before_key := ART.binding_key({"id": id})
	var preview := ART.resolve({"id": id})
	check(preview.preview_only and preview.texture.get_size() == Vector2(512, 384), "inspector returns actual 512-pixel preview immediately")
	check(preview.delivery_state == "loading", "inspector visibly starts asynchronous full-art delivery")
	await settled(1, 0, "verified actual WebP success")
	var full := ART.resolve({"id": id})
	check(not full.preview_only and full.delivery_state == "ready" and full.texture.get_size() == Vector2(1448, 1086), "verified actual HTTP body replaces preview with native-size full art")
	check(full.texture.get_image().has_mipmaps(), "delivered full texture has actual mip pyramid")
	check(full.status == "final" and full.label.is_empty() and not full.commercially_cleared, "HTTP success preserves visual approval and absent commercial clearance")
	check(ART.binding_key({"id": id}) != before_key, "delivery invalidates visible inspector binding")
	var successful_starts: int = service.metrics().started
	ART.resolve({"id": id}); service.request_full(id)
	for frame in 3: await process_frame
	check(service.metrics().started == successful_starts, "verified cache prevents duplicate HTTP request")
	await failed_route("missing")
	await failed_route("hash")
	await failed_route("dimensions", true)
	await failed_route("redirect")
	await failed_route("disconnect")
	await failed_route("oversized")
	await attach("slow")
	service.request_full(str(ids[0])); await process_frame
	for index in range(1, ids.size()): service.request_full(str(ids[index]))
	var queued: Dictionary = service.metrics()
	check(queued.started == 1 and not queued.active.is_empty() and queued.queued == DELIVERY.MAX_PENDING, "one actual HTTP request plus bounded four-item pending queue")
	check(service.state_for(str(ids[1])) == "preview", "discarded older pending request returns to honest preview state")
	await settled(5, 0, "bounded queue of actual HTTP bodies")
	check(service.metrics().started == 5, "bounded queue fetched only active and four retained requests")
	check(ART.stats().estimated_retained_bytes <= ART.MAX_CACHE_BYTES and ART.stats().retained_textures <= ART.MAX_CACHE_ENTRIES, "real delivered full art respects shared cache limits")
	var report := {"assertions": assertions, "failures": failures, "http_success": 6, "http_rejection_cases": ["404", "same-length SHA mismatch", "dimension mismatch after verified SHA", "redirect refused", "connection closed without response", "response over 8 MiB"], "queue_limit": DELIVERY.MAX_PENDING, "actual_source_dimensions": [1448, 1086], "scope": "actual loopback HTTP and native runtime; browser proof is separate"}
	DirAccess.make_dir_recursive_absolute("res://work/production-art")
	var file := FileAccess.open("res://work/production-art/delivery-http-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	finish()

func finish() -> void:
	if is_instance_valid(service): root.remove_child(service); service.free()
	ART.clear_cache()
	print("PRODUCTION ART HTTP DELIVERY: %d assertions, %d failures; actual HTTP success, 404, hash/dimension/redirect rejection, bounded queue and compact no-network proof" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
