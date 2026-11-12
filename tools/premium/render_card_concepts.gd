extends SceneTree
## Native Godot comparison: exactly the same 20 real cards in all three concepts.
const Face=preload("res://scripts/card_system/card_face.gd")
const View=preload("res://scripts/alpha/card_view.gd")
const Frames=preload("res://scripts/premium/card_frames.gd")
const Catalog=preload("res://scripts/production/catalog.gd")
const S=preload("res://scripts/alpha/style.gd")
var output:="res://work/premium-mobile/cards/"
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func caption(parent: Control,value: String,at: Vector2,font_size: int=13) -> void:
	var label:=Label.new();label.text=value;label.position=at;label.add_theme_font_override("font",S.font);label.add_theme_font_size_override("font_size",font_size);parent.add_child(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,900)
	var catalog=Catalog.new()
	if "--closeup-only" in OS.get_cmdline_user_args():
		await rarity_closeup(catalog.all_cards()[0])
		root.get_node("GameAudio").request_quit(0);return
	var selected: Array=[]
	for power in ["houses","stillwatch","morph","ninth","neutral"]:
		for rarity in ["common","rare","epic","legendary"]:
			var desired={"common":"creature","rare":"event","epic":"relic","legendary":"creature"}[rarity]
			var cards=catalog.all_cards().filter(func(card):return card.faction==power and card.rarity==rarity)
			var preferred=cards.filter(func(card):return card.kind==desired)
			selected.append(preferred[0] if not preferred.is_empty() else cards[0])
	for concept in Frames.CONCEPTS:
		var scene:=Control.new();root.add_child(scene);scene.size=Vector2(1280,900)
		var background:=ColorRect.new();background.color=Color("080e17");background.size=scene.size;scene.add_child(background)
		caption(scene,"ORAFOLD / "+str(concept).to_upper()+" / tatsächliches Godot-Rendering",Vector2(20,8),23)
		caption(scene,"Identische 20 Karten · gleiche Kontur 63:88 · Illustration getrennt vom Material · keine Gerätemessung",Vector2(20,38),14)
		for index in 4:
			var face=Face.new();face.card=selected[index];face.frame_concept=concept;face.position=Vector2(24+index*314,68);face.size=Vector2(236,330);scene.add_child(face)
			caption(scene,S.RARITIES[selected[index].rarity]+" · "+S.KINDS[selected[index].kind],Vector2(24+index*314,402),14)
			caption(scene,selected[index].id,Vector2(24+index*314,424),12)
		for index in selected.size():
			var card: Dictionary=selected[index]
			var pos:=Vector2(22+(index%10)*126,464+floori(float(index)/10)*209)
			var view=View.new();view.card=card;view.color=S.color(card);view.display_role="hand";view.frame_concept=concept;view.position=pos;view.size=Vector2(90,126);scene.add_child(view)
			caption(scene,card.faction+"\n"+card.rarity,pos+Vector2(0,132),12)
			var report=view.layout_report()
			records.append({"concept":concept,"id":card.id,"power":card.faction,"rarity":card.rarity,"title_fits":report.title_fits,"art_fraction":report.art_fraction,"hand":[90,126]})
		for frame in 5:await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+concept+".png")==OK)
		scene.queue_free();await process_frame
	var file=FileAccess.open(output+"comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"godot":Engine.get_version_info().string,"catalog_sha256":FileAccess.get_sha256("res://data/production/cards.json"),"frames_sha256":FileAccess.get_sha256("res://scripts/premium/card_frames.gd"),"card_face_sha256":FileAccess.get_sha256("res://scripts/card_system/card_face.gd"),"card_view_sha256":FileAccess.get_sha256("res://scripts/alpha/card_view.gd"),"chosen":Frames.CHOSEN,"cards":records,"scope":"60 actual native frame renders plus 12 canonical faces; no physical mobile-device test"},"  "));file.close()
	await rarity_closeup(selected[0])
	print("PREMIUM CARD CONCEPTS: 3 actual Godot concepts, 20 identical real cards each, 90x126 hand and 236x330 canonical faces")
	root.get_node("GameAudio").request_quit(0)

func rarity_closeup(template: Dictionary) -> void:
	root.size=Vector2i(1000,690)
	var scene:=Control.new();scene.size=Vector2(1000,690);root.add_child(scene)
	var background:=ColorRect.new();background.color=Color("080e17");background.size=scene.size;scene.add_child(background)
	caption(scene,"Seltenheitsarchitektur / identisches Motiv und gleiche Werte",Vector2(22,10),24)
	caption(scene,"Reine Rahmenstudie: Seltenheit nur in dieser Ansicht variiert; Originalkartendaten unverändert.",Vector2(22,44),16)
	var index:=0
	for rarity in ["common","rare","epic","legendary"]:
		var sample:=template.duplicate(true);sample.rarity=rarity
		var view=View.new();view.card=sample;view.display_role="hand";view.position=Vector2(35+index*244,92);view.size=Vector2(84,117);scene.add_child(view)
		caption(scene,S.RARITIES[rarity]+" · 84×117",view.position+Vector2(0,123),15)
		var enlarged=View.new();enlarged.card=sample;enlarged.display_role="hand";enlarged.position=Vector2(35+index*244,275);enlarged.size=Vector2(84,117);enlarged.scale=Vector2(2.5,2.5);scene.add_child(enlarged)
		index+=1
	caption(scene,"Unten: identisches Kartenlayout bei 2,5× Godot-Zeichenskalierung; oben tatsächliche kleine Darstellung.",Vector2(22,606),16)
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"rarity-closeup.png")==OK)
	scene.queue_free();await process_frame
