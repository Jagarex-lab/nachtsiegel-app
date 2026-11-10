extends SceneTree
## Real imported originals, honest missing-state fallback and bounded lazy cache.
const ART = preload("res://scripts/production/art_resolver.gd")
const FACE = preload("res://scripts/card_system/card_face.gd")
var assertions := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("FAIL: ", message)

func run() -> void:
	ART.clear_cache(true)
	check(ART.stats().retained_textures == 0, "manifest/renderer do not eagerly load all 550 illustrations")
	var image_hashes: Dictionary = {}
	for id in ["oa-neutral-c02", "oa-stillwatch-c01", "oa-morph-c01", "oa-houses-c01", "oa-ninth-c01"]:
		var record = ART.manifest_entry(id)
		check(record.individual_original and record.status == "final" and record.production_review == "approved", "individual original has completed visual review state " + id)
		check(not record.commercially_cleared, "no automatic legal clearance " + id)
		var resolved = ART.resolve({"id": id})
		check(resolved.texture is Texture2D, "real imported illustration is loadable " + id)
		if resolved.texture == null: continue
		check(resolved.texture.get_size() == Vector2(1448, 1086), "native dimensions retained; no upscaling " + id)
		check(resolved.status == "final" and resolved.label.is_empty() and resolved.individual, "visually approved individual rendered as final " + id)
		var pixels = resolved.texture.get_image()
		var digest = hash(pixels.get_data())
		check(not image_hashes.has(digest), "different actual motif pixels for " + id)
		image_hashes[digest] = true
		var repeated = ART.resolve({"id": id})
		check(repeated.texture == resolved.texture, "visible repeat retains same texture " + id)
		record.status = "concept"
		check(ART.manifest_entry(id).status == "final", "manifest clients cannot silently mutate review state " + id)
		var spoof = ART.resolve({"id": id, "art": {"status": "final", "asset_id": resolved.asset_path}})
		check(spoof.status == "final" and not spoof.commercially_cleared, "actual approved original remains legally uncleared regardless of card declaration " + id)
	ART._manifest["unapproved-review-probe"] = {"status": "concept", "asset_path": "res://assets/cards/originals/oa-neutral-c02.png", "individual_original": true, "production_review": "pending"}
	var unapproved = ART.resolve({"id": "unapproved-review-probe", "art": {"status": "final", "asset_id": "res://assets/cards/originals/oa-neutral-c02.png"}})
	check(unapproved.status == "concept" and unapproved.label == "KONZEPTILLUSTRATION", "known unapproved individual cannot self-promote to final")
	ART._manifest.erase("unapproved-review-probe")
	var unknown = ART.resolve({"id": "no-such-card"})
	check(unknown.texture == null and unknown.status == "shared_concept" and unknown.label == "GETEILTES KONZEPTBILD", "missing illustration explicitly uses shared fallback")
	var missing = ART.resolve({"schema_version": 2, "id": "no-such-card", "art": {"status": "final", "asset_id": "res://assets/cards/originals/missing.png", "path": "res://assets/art/atlas.png"}})
	check(missing.texture == null and missing.status == "shared_concept", "missing final cannot use non-contract v2 path")
	var unregistered = ART.resolve({"id": "no-such-card", "art": {"status": "final", "asset_id": "res://assets/art/atlas.png"}})
	check(unregistered.texture is Texture2D and unregistered.status == "concept" and not unregistered.individual and not unregistered.commercially_cleared, "unregistered shared atlas cannot self-declare final individual art")
	for path in ["res://scripts/ui_tokens.gd", "user://outside.png", "/etc/passwd", "res://assets/../scripts/ui_tokens.gd", "res://assets/%2e%2e/a.png", "res://assets/\\outside.png", "res://assets//outside.png", "res://assets/x.png:script", "https://example.com/a.png"]:
		check(not ART.safe_asset_path(path), "unsafe/non-image resource rejected: " + path)
		var denied = ART.resolve({"id": "no-such-card", "art": {"status": "concept", "asset_id": path}})
		check(denied.texture == null, "unsafe asset never loads " + path)
	for path in ["res://assets/art/atlas.png", "res://assets/art/arena_painted.png", "res://assets/art/hero_medallion.png", "res://assets/art/reliquary_frame.png", "res://assets/art/premium_slate.png", "res://assets/cards/originals/oa-neutral-c02.png", "res://assets/cards/originals/oa-stillwatch-c01.png", "res://assets/cards/originals/oa-morph-c01.png"]:
		ART.resolve({"id": "cache-probe", "art": {"status": "concept", "asset_id": path}})
		check(ART.stats().retained_textures <= ART.MAX_CACHE_ENTRIES and ART.stats().estimated_retained_bytes <= ART.MAX_CACHE_BYTES, "cache bounded after actual texture " + path)
	check(ART.stats().hits > 0 and ART.stats().loads > 0, "actual lazy loads and cache hits observed")
	var face = FACE.new()
	face.card = {"id": "oa-neutral-c02", "faction": "neutral", "kind": "creature", "name": "Torwache", "cost": 2, "atk": 2, "hp": 4, "species": ["human"]}
	check(face.normalized().illustration is Texture2D and face.normalized().art_label.is_empty(), "canonical full renderer adopts visually approved by-ID art without mutating rules")
	face.free()
	ART.clear_cache()
	check(ART.stats().retained_textures == 0 and ART.stats().estimated_retained_bytes == 0, "explicit memory-pressure release clears retained references")
	print("PRODUCTION ART PIPELINE: %d assertions, %d failures; 5 real individual originals, missing fallback, security paths and bounded lazy cache" % [assertions, failures])
	root.get_node("GameAudio").request_quit(0 if failures == 0 else 1)
