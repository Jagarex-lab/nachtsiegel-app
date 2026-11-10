extends SceneTree
## Native rendered geometry tests, not a claim of true-device or full 550-card QA.
const Face=preload("res://scripts/card_system/card_face.gd")
var assertions := 0
var failures := 0
var viewport: SubViewport
var face
var output := "res://work/master550/cards/"

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func capture(dimensions: Vector2i=Vector2i(756,1056)) -> Image:
	viewport.size=dimensions;face.size=dimensions
	face.queue_redraw()
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func alpha_fingerprint(image: Image) -> int:
	var copy=image.duplicate();copy.convert(Image.FORMAT_RGBA8)
	var data=copy.get_data();var mask=PackedByteArray();mask.resize(image.get_width()*image.get_height())
	for index in mask.size():mask[index]=data[index*4+3]
	return hash(mask)

func transparent_margin(image: Image) -> bool:
	for x in image.get_width():
		for y in [0,1,2,image.get_height()-3,image.get_height()-2,image.get_height()-1]:
			if image.get_pixel(x,y).a>0:return false
	for y in image.get_height():
		for x in [0,1,2,image.get_width()-3,image.get_width()-2,image.get_width()-1]:
			if image.get_pixel(x,y).a>0:return false
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.size=Vector2i(756,1056);root.add_child(viewport)
	face=Face.new();face.size=Vector2(756,1056);viewport.add_child(face)
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/alpha/cards.json"))
	var original=source.cards[0].duplicate(true)
	face.card=original
	check(face.normalized().power=="neutral" and face.normalized().cost==1,"Alpha numeric effect power is not mistaken for faction identity")
	check(face.normalized().species.is_empty(),"no invented species on old cards")
	check(face.layout_report().species.is_empty(),"old product face leaves absent species blank instead of presenting technical placeholder text")
	for card in source.cards:
		face.card=card
		var report=face.layout_report()
		check(report.title_fits,"actual Alpha title fits: "+str(card.id))
		check(report.rules_fit,"actual Alpha rules text fits: "+str(card.id))
		check(report.has_combat_values==(card.kind=="creature"),"only Wesen has attack/life slots: "+str(card.id))
		check(Face.OUTER.encloses(report.title) and Face.OUTER.encloses(report.rules) and Face.OUTER.encloses(report.art),"all semantic panels inside contour: "+str(card.id))
	var pilot={"schema_version":2,"id":"visual-schema2","name":"Wächterin der wiedergefalteten Brücke","power":"houses","kind":"creature","rarity":"epic","energy_cost":4,"attack":3,"health":6,"species":["human","construct"],"text_de":"Beim Beschwören: Dieses Wesen erhält 2 Schild.","art":{"status":"shared_concept","asset_id":"shared:orafold-atlas"}}
	face.card=pilot
	check(face.normalized().power=="houses" and face.normalized().cost==4 and face.normalized().attack==3 and face.normalized().health==6,"schema2 stats and power normalized without changing data")
	check(face.normalized().species=="Menschen · Konstrukte","both equally ranked species visible from data")
	var unknown=pilot.duplicate(true);unknown.species=["imaginary"]
	face.card=unknown;check(face.normalized().species.is_empty(),"unknown species is not silently invented by renderer; validator owns rejection")
	face.card=pilot
	var shared_render=await capture()
	var shared_hash=hash(shared_render.get_data())
	var resource_sample=pilot.duplicate(true)
	resource_sample.art={"status":"concept","asset_id":"res://assets/art/arena_painted.png","provenance":"assets/ASSET_MANIFEST.md"}
	face.card=resource_sample
	check(face.normalized().illustration is Texture2D and not face.layout_report().art_is_shared,"V2 asset_id actually resolves an existing texture")
	check(face.normalized().art_status=="concept" and face.normalized().art_label=="KONZEPTILLUSTRATION","resolved concept remains honestly labelled")
	var concept_render=await capture()
	check(hash(concept_render.get_data())!=shared_hash,"resolved V2 texture is actually rendered instead of shared fallback")
	# Synthetic status tests exercise the loader, not art-production approval.
	resource_sample=resource_sample.duplicate(true);resource_sample.art.status="final";face.card=resource_sample
	check(face.normalized().illustration is Texture2D and face.normalized().art_label.is_empty(),"only loaded synthetic final resource suppresses concept caption")
	var final_render=await capture()
	check(hash(final_render.get_data())!=hash(concept_render.get_data()),"actual render reflects final/concept caption state")
	var missing_sample=resource_sample.duplicate(true);missing_sample.art.asset_id="res://assets/art/this-final-image-does-not-exist.png";face.card=missing_sample
	check(face.normalized().illustration==null and face.normalized().art_status=="shared_concept" and face.normalized().art_label=="GETEILTES KONZEPTBILD","missing final resource is never presented as available final art")
	var missing_render=await capture()
	check(hash(missing_render.get_data())==shared_hash,"missing final render is byte-identical to explicitly labelled shared concept")
	check(missing_sample.art.status=="final","renderer does not mutate source data while falling back")
	var wrong_type=resource_sample.duplicate(true);wrong_type.art.asset_id="res://scripts/ui_tokens.gd";face.card=wrong_type
	check(face.normalized().illustration==null and face.normalized().art_status=="shared_concept","existing non-texture resource cannot masquerade as final art")
	var old_path=original.duplicate(true);old_path.art={"status":"concept","path":"res://assets/art/arena_painted.png"};face.card=old_path
	check(face.normalized().illustration is Texture2D,"v1 optional art.path adapter remains compatible")
	missing_sample.art.path="res://assets/art/arena_painted.png";face.card=missing_sample
	check(face.normalized().illustration==null,"v2 cannot bypass asset_id resolution through non-contract path")
	var sheet=Image.create(1130,1264,false,Image.FORMAT_RGBA8)
	var reference_mask=0;var row=0;var rendered=0;var faces_seen: Dictionary={}
	for rarity in ["common","rare","epic","legendary"]:
		var column=0
		for power_id in ["houses","stillwatch","morph","ninth","neutral"]:
			var sample=pilot.duplicate(true);sample.rarity=rarity;sample.power=power_id
			face.card=sample
			var image=await capture()
			check(image.get_size()==Vector2i(756,1056),"actual 756x1056 render: "+power_id+" "+rarity)
			check(transparent_margin(image),"no graphic projects outside contour: "+power_id+" "+rarity)
			var mask=alpha_fingerprint(image)
			if rendered==0:reference_mask=mask
			check(mask==reference_mask,"identical outer alpha silhouette: "+power_id+" "+rarity)
			var face_hash=hash(image.get_data())
			check(not faces_seen.has(face_hash),"faction/rarity has a genuinely different rendered treatment: "+power_id+" "+rarity)
			faces_seen[face_hash]=true
			check(image.get_pixel(100,300).a>.99,"actual illustration and opaque card rendered")
			if power_id=="houses":image.save_png(output+"master-"+rarity+".png")
			image.resize(226,316,Image.INTERPOLATE_LANCZOS);sheet.blit_rect(image,Rect2i(0,0,226,316),Vector2i(column*226,row*316))
			rendered+=1;column+=1
		row+=1
	sheet.save_png(output+"rarity-power-matrix.png")
	for kind in ["creature","event","relic"]:
		var sample=pilot.duplicate(true);sample.kind=kind
		if kind!="creature":sample.resonance_cost=2
		face.card=sample
		var image=await capture();image.save_png(output+"type-"+kind+".png")
		check(face.layout_report().has_combat_values==(kind=="creature"),"type rendering has appropriate combat values: "+kind)
		check(face.layout_report().rules_fit,"type rules fit including optional resonance: "+kind)
		if kind!="creature":check(face.layout_report().rules.position.y>=760,"resonance cost never overlaps rules")
	face.face_down=true
	var back_image=await capture();back_image.save_png(output+"back-master.png")
	var back_hash=hash(back_image.get_data())
	for power_id in Face.POWERS:
		for rarity in ["common","rare","epic","legendary"]:
			face.card={"id":"secret-"+power_id,"power":power_id,"kind":"relic","rarity":rarity,"name":"SECRET","energy_cost":99,"resonance_cost":99}
			var image=await capture()
			check(hash(image.get_data())==back_hash,"back leaks no faction, rarity or face information: "+power_id+" "+rarity)
	check(alpha_fingerprint(back_image)==reference_mask,"front and back share exact outer contour")
	face.face_down=false;face.card=pilot
	for dimensions in [Vector2i(350,489),Vector2i(390,844),Vector2i(844,390)]:
		var image=await capture(dimensions)
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(face.face_rect()),"uniformly fitted portrait master stays inside target: "+str(dimensions))
		check(is_equal_approx(face.face_rect().size.x/face.face_rect().size.y,63.0/88.0),"canonical aspect preserved without stretch: "+str(dimensions))
		image.save_png(output+"fit-%dx%d.png" % [dimensions.x,dimensions.y])
	check(S.font.multichannel_signed_distance_field,"shared UI font uses MSDF")
	check(T.contrast(Face.TEXT,Face.RULES)>=4.5 and T.contrast(Face.SECONDARY,Face.RULES)>=4.5,"opaque information panel text meets WCAG AA 4.5:1")
	viewport.queue_free();await process_frame
	print("MASTER550 CARD VISUAL: %d assertions, %d failures; 20 faction/rarity master renders, 20 identical hidden backs, 55 real text layouts, 3 types and 3 scaled fits" % [assertions,failures])
	root.get_node("GameAudio").request_quit(0 if failures==0 else 1)

const S=preload("res://scripts/alpha/style.gd")
const T=preload("res://scripts/ui_tokens.gd")
