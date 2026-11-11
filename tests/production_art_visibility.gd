extends SceneTree
## Actual CardView lifecycle: an early offscreen draw must not permanently
## suppress registration when layout later makes a hand/board Control visible.
const ART = preload("res://scripts/production/art_resolver.gd")
const DELIVERY = preload("res://scripts/production/art_delivery.gd")
const CARD = preload("res://scripts/alpha/card_view.gd")
const CATALOG = preload("res://scripts/production/catalog.gd")
class EarlyLayoutCard:
	extends "res://scripts/alpha/card_view.gd"
	var early_draw := false
	var early_refused := false
	func _draw() -> void:
		if not early_draw:
			early_draw = true
			# Reproduce an actual draw before the container has its final geometry.
			var final_position := position
			position = Vector2(900,0)
			super._draw()
			early_refused = not ART.visible_owner(self) and not get_tree().root.get_node("ArtDelivery").preview_visible(str(card.id))
			position = final_position
		else: super._draw()
var assertions := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", label)
func frames(count := 3) -> void:
	for frame in count: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var old = root.get_node("ArtDelivery"); root.remove_child(old); old.free()
	ART.clear_cache()
	var service = DELIVERY.new("http://127.0.0.1:9/"); service.name = "ArtDelivery"; root.add_child(service)
	var catalog = CATALOG.new()
	var id := "of-houses-020"
	check(catalog.cards.has(id) and service.external_preview(id), "actual external-preview production card and delivery entries")
	var viewport := SubViewport.new(); viewport.size = Vector2i(640,360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var view = EarlyLayoutCard.new(); view.card = catalog.cards[id]; view.size = Vector2(140,180); view.position = Vector2(10,10); viewport.add_child(view)
	await RenderingServer.frame_post_draw
	check(not view._illustration_binding.is_empty() and view._delivery_card_id == id, "real first draw occurs before final visible geometry")
	check(view.early_draw and view.early_refused, "early offscreen request is correctly refused before registration")
	view.position = Vector2(10,10)
	await frames()
	check(ART.visible_owner(view) and service.preview_visible(id), "becoming visible retries CardView owner registration after refused first draw")
	check(view._illustration_data.get("texture") is Texture2D, "visible CardView actually retains decoded native preview pixels")
	var before: Dictionary = ART.stats().duplicate(true)
	var report: Dictionary = view.art_report()
	check(report.card_id == id and report.visible and report.status == "final" and not report.pending and report.pixels == [512,384] and report.profile == "compact", "read-only report observes actually bound final compact pixels")
	check(ART.stats() == before, "read-only art report does not resolve or touch cache")
	await frames(15)
	check(ART.stats().loads == before.loads and ART.stats().hits == before.hits, "steady visible binding causes no resolver/redraw storm")
	view.position = Vector2(900,0); await frames()
	check(not service.preview_visible(id), "leaving visible viewport releases owner")
	view.position = Vector2(10,10); await frames()
	check(service.preview_visible(id), "return after rotation/layout exclusion registers again")
	view.queue_free(); await process_frame
	var replacement = CARD.new(); replacement.card = catalog.cards[id]; replacement.size = Vector2(140,180); replacement.position = Vector2(900,0); viewport.add_child(replacement)
	await frames(); replacement.position = Vector2(10,10); viewport.size = Vector2i(360,640); await frames()
	check(service.preview_visible(id) and replacement._illustration_data.get("texture") is Texture2D, "replacement Control after rotation reacquires actual art binding")
	check(service.metrics().started == 0, "native lifecycle check uses local pixels and starts no hidden HTTP request")
	viewport.queue_free(); await process_frame; service.free(); ART.clear_cache()
	print("PRODUCTION ART VISIBILITY: %d assertions, %d failures; real initially refused CardView draw, visible retry, replacement and rotation" % [assertions,failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
