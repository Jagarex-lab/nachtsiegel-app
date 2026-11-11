extends SceneTree
const Catalog=preload("res://scripts/production/catalog.gd")
const Face=preload("res://scripts/card_system/card_face.gd")
const Tokens=preload("res://scripts/ui_tokens.gd")
var container: Control
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/alpha03/visual-qa")
	root.size=Vector2i(1280,720)
	var catalog=Catalog.new()
	var records: Array=[]
	for power in ["houses","stillwatch","morph","ninth","neutral"]:
		container=Control.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(container)
		var bg=ColorRect.new();bg.color=Color("0b111b");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.add_child(bg)
		var title=Label.new();title.text="ORAFOLD · "+str(catalog.source.powers[power])+" · Godot-Kartenprüfung";title.position=Vector2(26,12);title.add_theme_font_override("font",Tokens.DISPLAY);title.add_theme_font_size_override("font_size",28);container.add_child(title)
		var column:=0
		for rarity in ["common","rare","epic","legendary"]:
			var desired={"common":"creature","rare":"event","epic":"relic","legendary":"creature"}[rarity]
			var candidates=catalog.all_cards().filter(func(card):return card.faction==power and card.rarity==rarity)
			assert(not candidates.is_empty())
			var preferred=candidates.filter(func(card):return card.kind==desired)
			var card=preferred[0] if not preferred.is_empty() else candidates[0]
			var face=Face.new();face.card=card;face.position=Vector2(22+column*312,58);face.size=Vector2(300,420);container.add_child(face)
			var caption=Label.new();caption.text=str(rarity)+" · "+str(card.kind)+"\n"+card.id;caption.position=Vector2(24+column*312,490);caption.add_theme_font_override("font",Tokens.FONT);caption.add_theme_font_size_override("font_size",16);container.add_child(caption)
			var report=face.layout_report();assert(report.title_fits and report.rules_fit and not report.art_is_shared)
			records.append({"id":card.id,"power":power,"rarity":rarity,"kind":card.kind,"master":[756,1056],"title_fits":report.title_fits,"rules_fit":report.rules_fit,"source":"res://scripts/card_system/card_face.gd"})
			column+=1
		var note=Label.new();note.text="Tatsächlich gerenderte Karten · native Vorschau · kein physischer Gerätetest\nIllustration und UI-Rahmen getrennt; individuelle Motive, gemeinsame Außenkontur.";note.position=Vector2(26,586);note.add_theme_font_override("font",Tokens.FONT);note.add_theme_font_size_override("font_size",18);container.add_child(note)
		for i in 10:await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image();assert(image.save_png("res://work/alpha03/visual-qa/"+power+".png")==OK)
		container.queue_free();await process_frame
	var source_commit: Array=[]
	assert(OS.execute("git",["rev-parse","HEAD"],source_commit)==0)
	var file=FileAccess.open("res://work/alpha03/visual-qa/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"executed_commit":str(source_commit[0]).strip_edges(),"catalog_sha256":FileAccess.get_sha256("res://data/production/cards.json"),"card_face_sha256":FileAccess.get_sha256("res://scripts/card_system/card_face.gd"),"art_manifest_sha256":FileAccess.get_sha256("res://data/production/art_manifest.json"),"godot":Engine.get_version_info().string,"scope":"20 actual native Godot card faces, five powers x four rarities; not device acceptance","cards":records},"  "));file.close()
	print("VISUAL QA: 20 actual card renders; five powers and four rarities; all title/rules fit")
	root.get_node("GameAudio").request_quit(0)
