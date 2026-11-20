extends SceneTree
## Preview contract only: data and selected production renderer stay unchanged.
const Frames=preload("res://scripts/design_study/fractal_fold_frames.gd")
const Face=preload("res://scripts/design_study/fractal_fold_card.gd")
const Study=preload("res://scripts/design_study/fractal_fold_study.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const Capture=preload("res://tools/design_study/render_fractal_fold.gd")
const Art=preload("res://scripts/production/art_resolver.gd")
var assertions:=0
var failures:=0

func _initialize() -> void:call_deferred("run")

func check(condition: bool, message: String) -> void:
	assertions+=1
	if not condition:failures+=1;push_error("FRACTAL GEOMETRY: "+message)

func run() -> void:
	var source_hash:=FileAccess.get_sha256("res://data/production/cards.json")
	var catalog:=Catalog.new();var fingerprint:=catalog.fingerprint()
	check(catalog.all_cards().size()==550,"actual active catalog remains550")
	check(Frames.REFERENCE.CHOSEN=="folded","production frame selection unchanged")
	# Pure evidence-validator fixtures are not counted as rendered illustrations.
	var entry:=Art.manifest_entry("of-houses-001")
	var full_report: Dictionary={"status":"final","pending":false,"profile":"full","preview_only":false,"asset":entry.asset_path,"texture_asset":entry.asset_path,"pixels":[int(entry.original_width),int(entry.original_height)]}
	check(Capture.art_evidence_valid(full_report,entry,"full"),"accept coherent original evidence shape")
	var fallback: Dictionary=full_report.duplicate(true);fallback.preview_only=true;fallback.texture_asset=entry.preview_asset_path;fallback.pixels=[int(entry.preview_width),int(entry.preview_height)]
	check(not Capture.art_evidence_valid(fallback,entry,"full"),"reject final-labelled compact fallback as full original")
	var wrong_path: Dictionary=full_report.duplicate(true);wrong_path.texture_asset=entry.preview_asset_path
	check(not Capture.art_evidence_valid(wrong_path,entry,"full"),"reject wrong bound original texture path")
	var wrong_size: Dictionary=full_report.duplicate(true);wrong_size.pixels=[512,384]
	check(not Capture.art_evidence_valid(wrong_size,entry,"full"),"reject reduced original dimensions")
	var compact: Dictionary=full_report.duplicate(true);compact.profile="compact";compact.texture_asset=entry.preview_asset_path;compact.pixels=[int(entry.preview_width),int(entry.preview_height)]
	check(Capture.art_evidence_valid(compact,entry,"compact"),"accept coherent compact derivative evidence shape")
	compact.texture_asset="res://assets/wrong.webp"
	check(not Capture.art_evidence_valid(compact,entry,"compact"),"reject wrong bound compact derivative")
	var outer:=Rect2(8,8,740,1040)
	var contour:=Frames.outline(outer)
	check(contour.size()==8,"one angular cut-corner contour")
	for point in contour:check(point.x>=8 and point.x<=748 and point.y>=8 and point.y<=1048,"contour stays inside master")
	for architecture in Frames.ARCHITECTURES:
		for power in Study.POWERS:
			var original: Dictionary=catalog.cards[Study.SAMPLES[power]]
			var original_bytes:=JSON.stringify(original,"",true)
			var previous_depth:=0
			for rank in 4:
				var rarity: String=Study.RARITIES[rank]
				var copy: Dictionary=original.duplicate(true);copy.rarity=rarity
				var face:=Face.new();face.architecture=architecture;face.card=copy
				var geometry:=Frames.geometry_report(outer,rarity,architecture)
				check(geometry.approval=="pending_owner","no approved selection")
				check(geometry.outline==contour,"all proposals/powers/rarities share one outside contour")
				check(geometry.depth_layers>previous_depth,"rarity increases actual bounded fold layers")
				previous_depth=geometry.depth_layers
				check(geometry.legendary_hinges==(2 if rank==3 else 0),"large legendary architecture only at highest rank")
				check(not geometry.uses_shaders and not geometry.idle_animation,"bounded static mobile proposal")
				check(face.art_aperture()==Rect2(74,152,608,500),"identical illustration crop across proposed rarities")
				for key in original:
					if key!="rarity":check(JSON.stringify(copy[key],"",true)==JSON.stringify(original[key],"",true),"only comparison rarity changes: "+str(key))
				check(copy.id==original.id and copy.art==original.art,"identity and original art remain same")
				face.free()
			check(JSON.stringify(catalog.cards[Study.SAMPLES[power]],"",true)==original_bytes,"source card not mutated")
	check(FileAccess.get_sha256("res://data/production/cards.json")==source_hash,"no active source write")
	check(Catalog.new().fingerprint()==fingerprint,"no mechanics change")
	print("FRACTAL FOLD GEOMETRY: ",assertions," assertions, ",failures," failures;60 controlled proposedfaces, approval pending")
	var audio=root.get_node_or_null("GameAudio")
	if audio!=null:audio.request_quit(0 if failures==0 else 1)
	else:quit(0 if failures==0 else 1)
