extends Control
## Developer-only proposal viewer. No menu, rules, catalog or profile integration.
const Face = preload("res://scripts/design_study/fractal_fold_card.gd")
const Compact = preload("res://scripts/design_study/fractal_fold_compact.gd")
const Materials = preload("res://scripts/design_study/fractal_fold_frames.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
const S = preload("res://scripts/alpha/style.gd")
const POWERS := ["houses","stillwatch","morph","ninth","neutral"]
const RARITIES := ["common","rare","epic","legendary"]
const SAMPLES := {"houses":"of-houses-001","stillwatch":"of-stillwatch-001","morph":"of-morph-001","ninth":"of-ninth-001","neutral":"of-neutral-001"}
const POWER_NAMES := {"houses":"Zwölf Häuser","stillwatch":"Stillwacht","morph":"Vielgestalt","ninth":"Neunte Stunde","neutral":"Neutral / Referenz"}
var interactive := true
var architecture := "hinge"
var view_mode := "matrix"
var faces: Array = []
var compact_faces: Array = []
var root_canvas: Control
var selected_cards: Array = []
var catalog_fingerprint := ""

func _ready() -> void:
	var catalog := Catalog.new()
	assert(catalog.load_error.is_empty())
	catalog_fingerprint=catalog.fingerprint()
	for power in POWERS:
		var original: Dictionary=catalog.cards[SAMPLES[power]]
		assert(original.faction==power and original.kind=="creature")
		selected_cards.append(original.duplicate(true))
	if interactive:
		DisplayServer.window_set_title("ORAFOLD / Rahmenstudie / Freigabe ausstehend")
		resized.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	if selected_cards.is_empty(): return
	for child in get_children():
		remove_child(child);child.queue_free()
	faces.clear();compact_faces.clear()
	var background := ColorRect.new();background.color=Color("080d15");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	root_canvas=Control.new()
	var actual_width:=maxf(480,size.x)
	if interactive:
		var scroll:=ScrollContainer.new();scroll.position=Vector2(0,62);scroll.size=Vector2(size.x,maxf(100,size.y-62));scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
		root_canvas.custom_minimum_size=Vector2(actual_width,1900 if view_mode=="matrix" else 1050)
		scroll.add_child(root_canvas)
		for index in 4:
			var key: String=["reference","hinge","lattice","crystalline"][index]
			var button:=Button.new();button.text=["Produktion","A / Scharnier","B / Archiv","C / Kristall"][index];button.position=Vector2(12+index*(size.x-24)/4,10);button.size=Vector2((size.x-36)/4,44);button.add_theme_font_override("font",S.font);button.add_theme_font_size_override("font_size",14);add_child(button)
			button.pressed.connect(func():architecture=key;_rebuild())
	else:
		add_child(root_canvas);root_canvas.size=size
	if view_mode=="types": _types_sheet()
	elif view_mode=="phone": _phone_sheet()
	elif view_mode=="mini": _mini_sheet()
	else: _matrix_sheet(actual_width)

func caption(value: String, at: Vector2, width: float, font_size := 16, color := Color("cbd4e2")) -> void:
	var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",S.font);label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.text=value;root_canvas.add_child(label);label.position=at;label.size=Vector2(width,64)

func sample(power_index: int, rarity_index: int) -> Dictionary:
	var result: Dictionary=selected_cards[power_index].duplicate(true)
	# Explicit renderer-only comparison. This clone is never registered as a card.
	result.rarity=RARITIES[rarity_index]
	return result

func add_face(data: Dictionary, at: Vector2, dimensions: Vector2) -> void:
	var face:=Face.new();face.architecture=architecture;face.card=data;face.reduced_motion=true;face.position=at;face.size=dimensions;root_canvas.add_child(face);faces.append(face)

func add_compact(data: Dictionary, at: Vector2, dimensions: Vector2) -> void:
	var face:=Compact.new();face.architecture=architecture;face.card=data;face.display_role="hand";face.color=Materials.REFERENCE.pigment(str(data.faction));face.reduced_motion=true;face.position=at;face.size=dimensions;root_canvas.add_child(face);compact_faces.append(face)

func _matrix_sheet(width: float) -> void:
	caption("ORAFOLD / "+Materials.LABELS[architecture],Vector2(20,8),width-40,26,Color("f4e9d7"))
	caption("ENTWURF · Freigabe ausstehend · je Reihe identische echte Karte und Illustration",Vector2(20,44),width-40,15)
	caption("Nur die visuelle Seltenheit wird variiert. Kosten, Name, Werte, Text und aktive Kartendaten unverändert.",Vector2(20,67),width-40,13)
	var label_width:=150.0
	var column_width:=(width-label_width-32)/4
	var face_width:=minf(226,column_width-14)
	var face_height:=face_width*88.0/63.0
	for rank in 4: caption(S.RARITIES[RARITIES[rank]],Vector2(label_width+rank*column_width,100),column_width,16,Color("f0e5ce"))
	for power_index in POWERS.size():
		var y:=138+power_index*(face_height+32)
		var data: Dictionary=selected_cards[power_index]
		caption(POWER_NAMES[POWERS[power_index]],Vector2(20,y+4),label_width-26,17,Materials.REFERENCE.pigment(POWERS[power_index]).lightened(.35))
		caption(str(data.name)+"\n"+str(data.id),Vector2(20,y+48),label_width-25,12)
		for rank in 4:add_face(sample(power_index,rank),Vector2(label_width+rank*column_width,y),Vector2(face_width,face_height))
	caption("63:88 · gleiche Außenkontur je Vorschlag · keine globale Umstellung · Originalbild und Rahmen getrennt",Vector2(20,138+5*(face_height+32)),width-40,13)

func _mini_sheet() -> void:
	caption("ORAFOLD / "+Materials.LABELS[architecture]+" / reale kleine Darstellung",Vector2(20,10),size.x-40,24,Color("f4e9d7"))
	caption("84 × 117⅓ px · identisches Motiv je Reihe · Vorschau, keine neuen spielbaren Seltenheitsversionen",Vector2(20,46),size.x-40,14)
	for rank in 4:caption(S.RARITIES[RARITIES[rank]],Vector2(174+rank*182,86),172,15)
	for power_index in 5:
		var y:=122+power_index*164
		caption(POWER_NAMES[POWERS[power_index]],Vector2(20,y+24),145,16,Materials.REFERENCE.pigment(POWERS[power_index]).lightened(.4))
		for rank in 4:add_compact(sample(power_index,rank),Vector2(182+rank*182,y),Vector2(84,84*88.0/63.0))
	caption("Kosten, Name und Kampfwerte kommen aus der echten kompakten Godot-Karte. Kein Hover und kein Gesamtkartenbild.",Vector2(20,950),size.x-40,13)

func _phone_sheet() -> void:
	caption("Rahmenvorschau · keine Designfreigabe",Vector2(16,8),size.x-32,17,Color("f4e9d7"))
	caption(Materials.LABELS[architecture],Vector2(16,32),size.x-32,13)
	var card_height:=minf(size.y-72,340)
	var card_width:=card_height*63.0/88.0
	add_face(sample(0,3),Vector2(20,58),Vector2(card_width,card_height))
	var x:=card_width+48
	for rank in 4:
		var at:=Vector2(x+(rank%2)*128,73+floori(float(rank)/2)*151)
		add_compact(sample(0,rank),at,Vector2(84,84*88.0/63.0))
		caption(S.RARITIES[RARITIES[rank]],at+Vector2(0,122),124,12)
	# Keep the explanation inside the actual phone frame instead of inheriting a
	# Label's single-line minimum width beyond the right screen edge.
	var help_x := x+264
	caption("Echte Vollkarte und 84px-Handkarten.\n\nNur Rahmenvergleich; keine Inspektionsabnahme.",Vector2(help_x,81),maxf(90,size.x-help_x-16),13)

func _types_sheet() -> void:
	caption("ORAFOLD / "+Materials.LABELS[architecture]+" / drei Kartentypen",Vector2(20,10),size.x-40,24,Color("f4e9d7"))
	caption("Reale Kartentexte und Werte. Nur die visuelle Seltenheit ist hier für alle drei Beispiele legendär.",Vector2(20,46),size.x-40,14)
	var catalog:=Catalog.new()
	var kinds: Array=["creature","event","relic"]
	for index in 3:
		var matches:=catalog.all_cards().filter(func(value):return value.faction=="houses" and value.kind==kinds[index])
		assert(not matches.is_empty())
		var data: Dictionary=matches[0].duplicate(true);data.rarity="legendary"
		var at:=Vector2(24+index*340,90)
		add_face(data,at,Vector2(236,236*88.0/63.0))
		add_compact(data,at+Vector2(70,374),Vector2(84,84*88.0/63.0))
		caption(S.KINDS[kinds[index]]+" · "+str(data.id),at+Vector2(0,336),310,14)
	caption("Nur Wesen zeigen Angriff/Leben. Impulse und Relikte erhalten keine erfundenen Kampfwerte. Die produktive Rückseite bleibt unverändert.",Vector2(24,610),size.x-48,14)

func reports() -> Array:
	var result: Array=[]
	for face in faces:result.append(face.study_report())
	for face in compact_faces:result.append(face.study_report())
	return result
