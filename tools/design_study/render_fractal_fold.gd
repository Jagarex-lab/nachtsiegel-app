extends SceneTree
## Real Godot captures only. Output is explicit; no source catalog writes.
const Study = preload("res://scripts/design_study/fractal_fold_study.gd")
const Face = preload("res://scripts/design_study/fractal_fold_card.gd")
const Materials = preload("res://scripts/design_study/fractal_fold_frames.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const Art = preload("res://scripts/production/art_resolver.gd")
var output := "res://work/fractal-fold-study"
var records: Array=[]
var assertions := 0
var failures := 0
var capture_count := 0
var selected_architectures: Array=["reference","hinge","lattice","crystalline"]
var selected_modes: Array=["matrix","mini","phone","types"]

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	assertions+=1
	if not condition:failures+=1;push_error("FRACTAL STUDY: "+message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--architecture="):selected_architectures=[arg.trim_prefix("--architecture=")]
		elif arg.begins_with("--mode="):selected_modes=[arg.trim_prefix("--mode=")]
		else:check(false,"unknown study option")
	check(selected_architectures.all(func(value):return value in ["reference","hinge","lattice","crystalline"]),"known preview architecture")
	check(selected_modes.all(func(value):return value in ["matrix","mini","phone","types","contour"]),"known capture mode")
	if "contour" in selected_modes:check(selected_architectures.any(func(value):return value!="reference"),"reference does not implement proposed angular-contour verification")
	if failures>0:finish();return
	DirAccess.make_dir_recursive_absolute(output)
	var baseline_catalog:=FileAccess.get_sha256("res://data/production/cards.json")
	var baseline_frames:=FileAccess.get_sha256("res://scripts/premium/card_frames.gd")
	var baseline_face:=FileAccess.get_sha256("res://scripts/card_system/card_face.gd")
	var baseline_view:=FileAccess.get_sha256("res://scripts/alpha/card_view.gd")
	var baseline_manifest:=FileAccess.get_sha256("res://data/production/art_manifest.json")
	var study_hashes: Dictionary={}
	for path in ["scripts/design_study/fractal_fold_frames.gd","scripts/design_study/fractal_fold_card.gd","scripts/design_study/fractal_fold_compact.gd","scripts/design_study/fractal_fold_study.gd","tools/design_study/render_fractal_fold.gd"]:study_hashes[path]=FileAccess.get_sha256("res://"+path)
	var catalog:=Catalog.new();var fingerprint:=catalog.fingerprint()
	for architecture in selected_architectures:
		for mode in selected_modes:
			if mode=="contour":
				if architecture!="reference":await contours(str(architecture),catalog)
			else:await capture(str(architecture),str(mode))
	check(FileAccess.get_sha256("res://data/production/cards.json")==baseline_catalog,"active catalog bytes unchanged")
	check(Catalog.new().fingerprint()==fingerprint,"active mechanics fingerprint unchanged")
	check(FileAccess.get_sha256("res://scripts/premium/card_frames.gd")==baseline_frames,"production material/default selector unchanged")
	check(FileAccess.get_sha256("res://scripts/card_system/card_face.gd")==baseline_face,"production canonical face unchanged")
	check(FileAccess.get_sha256("res://scripts/alpha/card_view.gd")==baseline_view,"production compact view unchanged")
	check(FileAccess.get_sha256("res://data/production/art_manifest.json")==baseline_manifest,"original illustration mapping unchanged")
	for path in study_hashes:check(FileAccess.get_sha256("res://"+str(path))==study_hashes[path],"executed study source unchanged during capture")
	var proof={"approval":"pending_owner","selected_proposal":null,"production_default":Materials.REFERENCE.CHOSEN,"source_catalog_sha256":baseline_catalog,"source_mechanics_fingerprint":fingerprint,"source_frames_sha256":baseline_frames,"source_face_sha256":baseline_face,"source_card_view_sha256":baseline_view,"source_art_manifest_sha256":baseline_manifest,"study_source_sha256":study_hashes,"godot":Engine.get_version_info().string,"physical_device":false,"renderer_scope":"native Godot framebuffers; no physical iPhone/Android or battery benchmark","captures":records,"assertions":assertions,"failures":failures,"capture_count":capture_count}
	var file:=FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(proof,"  "));file.close()
	else:check(false,"comparison proof writable")
	finish()

static func art_evidence_valid(art: Dictionary, entry: Dictionary, profile: String) -> bool:
	if profile not in ["full","compact"] or entry.is_empty():return false
	if art.get("status")!="final" or art.get("pending",true) or art.get("profile")!=profile:return false
	if entry.get("status")!="final" or entry.get("production_review")!="approved" or not entry.get("individual_original",false):return false
	var pixels: Array=art.get("pixels",[])
	if pixels.size()!=2 or art.get("asset","")!=entry.get("asset_path",""):return false
	if profile=="full":
		return not art.get("preview_only",true) and art.get("texture_asset","")==entry.get("asset_path","") and pixels==[int(entry.get("original_width",0)),int(entry.get("original_height",0))] and pixels[0]>0 and pixels[1]>0
	return art.get("texture_asset","")==entry.get("preview_asset_path","") and not str(art.get("texture_asset","")).is_empty() and pixels==[int(entry.get("preview_width",0)),int(entry.get("preview_height",0))] and pixels[0]>0 and pixels[1]>0

func contours(architecture: String, catalog) -> void:
	var expected_corner_hash:=""
	for power in Study.POWERS:
		var row_hashes: Array=[]
		for rarity in Study.RARITIES:
			var viewport:=SubViewport.new();viewport.size=Vector2i(756,1056);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
			var face:=Face.new();face.architecture=architecture;face.card=catalog.cards[Study.SAMPLES[power]].duplicate(true);face.card.rarity=rarity;face.size=Vector2(756,1056);viewport.add_child(face)
			for frame in 4:await process_frame
			await RenderingServer.frame_post_draw
			var art: Dictionary=face.art_report()
			check(art_evidence_valid(art,Art.manifest_entry(str(face.card.id)),"full"),"contour case uses actual bound full original, no preview fallback")
			var image:=viewport.get_texture().get_image()
			var used:=image.get_used_rect()
			check(Rect2i(8,8,740,1040).encloses(used),"actual pixels stay inside outer card rectangle")
			var bits:=PackedByteArray()
			var contour:=Materials.outline(Rect2(8,8,740,1040))
			for corner in [Vector2i(0,0),Vector2i(724,0),Vector2i(0,1024),Vector2i(724,1024)]:
				var corner_position: Vector2i=Vector2i(corner)
				for x in 32:
					for y in 32:
						var p: Vector2i=corner_position+Vector2i(x,y)
						var visible: bool=image.get_pixel(p.x,p.y).a>.1
						var centre: Vector2=Vector2(p)+Vector2(.5,.5)
						var inside: bool=Geometry2D.is_point_in_polygon(centre,contour)
						var on_edge:=false
						for edge in contour.size():
							if centre.distance_to(Geometry2D.get_closest_point_to_segment(centre,contour[edge],contour[(edge+1)%contour.size()]))<.76:
								on_edge=true
								break
						# Raster coverage on a mathematical edge is backend-dependent.
						# Full-pixel overhang outside OUTER remains strictly forbidden.
						if not on_edge:check(visible==inside,"actual angular-corner alpha matches contour away from subpixel edge")
						bits.append(1 if visible else 0)
			var alpha_hash:=HashingContext.new();alpha_hash.start(HashingContext.HASH_SHA256);alpha_hash.update(bits);var corner_hash:=alpha_hash.finish().hex_encode()
			if expected_corner_hash.is_empty():expected_corner_hash=corner_hash
			check(corner_hash==expected_corner_hash,"same actual angular alpha for every power/rarity")
			# Only frame material: excludes the illustration, title, rules and rarity word.
			var rail:=image.get_region(Rect2i(8,164,58,350))
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(rail.get_data());var rail_hash:=hash.finish().hex_encode();row_hashes.append(rail_hash)
			records.append({"architecture":architecture,"mode":"contour","card_id":face.card.id,"power":power,"rarity":rarity,"art_report":art,"alpha_corner_sha256":corner_hash,"frame_only_rail_sha256":rail_hash,"actual_used_rect":[used.position.x,used.position.y,used.size.x,used.size.y],"real_card_draws":1,"approval":"pending_owner"})
			root.remove_child(viewport);viewport.queue_free();await process_frame
		check(row_hashes.size()==4,"four actual rarity frame samples")
		var distinct: Dictionary={}
		for value in row_hashes:distinct[value]=true
		check(distinct.size()==4,"rarity changes real frame pixels, not only text or footer symbol")

func capture(architecture: String, mode: String) -> void:
	var dimensions:=Vector2i(1200,1940) if mode=="matrix" else Vector2i(980,1000) if mode=="mini" else Vector2i(1040,680) if mode=="types" else Vector2i(844,390)
	# Offscreen rendering avoids window-manager clipping of a tall comparison.
	var viewport:=SubViewport.new();viewport.size=dimensions;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var scene:=Study.new();scene.interactive=false;scene.architecture=architecture;scene.view_mode=mode;scene.size=Vector2(dimensions);viewport.add_child(scene)
	for index in 8:await process_frame
	await RenderingServer.frame_post_draw
	var reports:=scene.reports()
	var expected_count:=20 if mode in ["matrix","mini"] else 6 if mode=="types" else 5
	check(reports.size()==expected_count,"expected real card render count "+architecture+"/"+mode)
	for report in reports:
		var art: Dictionary=report.get("art_report",report)
		var profile:="full" if report.has("art_report") else "compact"
		check(art_evidence_valid(art,Art.manifest_entry(str(art.get("card_id",""))),profile),"actual bound original/full or actual compact derivative identity/dimensions; no fallback: "+str(art.get("card_id","")))
		check(report.get("title_fits",true),"complete title fits")
		check(report.get("rules_fit",true),"complete rules fit")
	if mode in ["matrix","mini"]:
		for power_index in 5:
			var expected: String=Study.SAMPLES[Study.POWERS[power_index]]
			var assets: Array=[]
			for rank in 4:
				var report: Dictionary=reports[power_index*4+rank]
				check(report.card_id==expected,"same actual card throughout rarity row")
				check(report.rarity==Study.RARITIES[rank],"controlled visual rarity order")
				var art: Dictionary=report.get("art_report",report)
				assets.append(art.asset)
			check(assets.all(func(value):return value==assets[0]),"same original illustration throughout rarity row")
	var image:=viewport.get_texture().get_image()
	check(image.get_width()==dimensions.x and image.get_height()==dimensions.y,"requested framebuffer dimensions")
	var filename:=architecture+"-"+mode+".png"
	var saved:=image.save_png(output.path_join(filename))
	check(saved==OK,"actual screenshot saved "+filename)
	if saved==OK:capture_count+=1
	records.append({"architecture":architecture,"mode":mode,"file":filename,"sha256":FileAccess.get_sha256(output.path_join(filename)),"pixels":[image.get_width(),image.get_height()],"real_card_draws":reports.size(),"cards":reports})
	root.remove_child(viewport);viewport.queue_free();await process_frame

func finish() -> void:
	print("FRACTAL FOLD STUDY: ",assertions," assertions, ",failures," failures, ",capture_count," actual native captures; approval pending, no selected proposal")
	var audio=root.get_node_or_null("GameAudio")
	if audio!=null:audio.request_quit(0 if failures==0 else 1)
	else:quit(0 if failures==0 else 1)
