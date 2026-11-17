extends SceneTree
## Uses all actual catalog names, not shortened synthetic title fixtures.
const View=preload("res://scripts/alpha/card_view.gd")
const Frames=preload("res://scripts/premium/card_frames.gd")
const T=preload("res://scripts/ui_tokens.gd")
var assertions:=0
var failures:=0
var overflow: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		if failures<=20:printerr("FAIL: ",message)
func run() -> void:
	var cards: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/cards.json")).cards
	var view=View.new()
	var checked: Dictionary={}
	for card in cards:
		view.card=card;view.unit={};view.display_role="hand"
		for dimensions in [Vector2(90,126),Vector2(84,117),Vector2(72,100)]:
			view.size=dimensions
			var report=view.layout_report()
			check(report.title_fits,"complete actual hand name fits: "+card.id+" "+str(dimensions))
			if not report.title_fits:overflow.append({"id":card.id,"size":[dimensions.x,dimensions.y],"title_height":report.title_actual.y,"available":report.title.size.y})
			check(report.outer.encloses(report.art) and report.outer.encloses(report.title) and report.outer.encloses(report.stats),"hand information stays in contour: "+card.id)
			check(report.art_fraction>(.16 if dimensions.x<84 else .25),"visible art remains substantial after opaque plates: "+card.id)
			check(report.has_combat_values==(card.kind=="creature"),"only creatures have combat values: "+card.id)
			check(report.title_font_size>=9 if dimensions.x<84 else report.title_font_size>=10,"measured hand font floor: "+card.id)
		view.display_role="library"
		for dimensions in [Vector2(180,176),Vector2(240,140)]:
			view.size=dimensions
			var report=view.layout_report()
			check(is_equal_approx(report.outer.size.x/report.outer.size.y,63.0/88.0),"library card keeps its canonical portrait aspect inside a wider touch tile: "+card.id)
			check(Rect2(Vector2.ZERO,view.size).encloses(report.outer) and report.outer.encloses(report.art),"library fit and illustration stay inside unchanged touch control: "+card.id)
			check(report.title_fits,"complete library name fits its actual portrait aperture: "+card.id)
		checked[card.faction+"/"+card.rarity]=true
		if card.kind=="creature":
			view.unit={"atk":7,"hp":3,"ward":25,"block":2,"stun":2,"summoned":false};view.display_role="board";view.combat_ready=false;view.attack_penalty=2
			for dimensions in [Vector2(144,80),Vector2(144,60)]:
				view.size=dimensions
				var report=view.layout_report()
				check(report.outer.encloses(report.art) and report.outer.encloses(report.stats),"board image/status stay bounded: "+card.id)
				check(report.title.size.y==0 and report.title_actual==Vector2.ZERO,"small battlefield uses illustration and inspectable full name instead of a text plate: "+card.id)
				check(report.art_fraction>.25,"small actual unit keeps useful image after readiness and combat plates: "+card.id)
				check(report.status_values.shield==25 and report.status_values.block==2 and report.status_values.ready_short=="Z2" and view.current_attack()==5,"current stats stay distinct: "+card.id)
	view.card=cards[0];view.unit={};view.display_role="hand";view.size=Vector2(90,126)
	view.availability_shown=true;view.playable=false;view.unavailable_reason="Nicht genug Energie"
	var unavailable:=view.art_report()
	check(unavailable.availability_shown and not unavailable.playable and unavailable.unavailable_reason=="Nicht genug Energie","availability is an explicit controller-supplied readonly observation")
	view.playable=true;view.unavailable_reason=""
	var available:=view.art_report()
	check(available.playable and available.title_fits==view.layout_report().title_fits and available.title_font_size==view.layout_report().title_font_size,"browser gets the same actual title measurement and legal-play cue as drawing")
	check(cards.size()==550 and checked.size()==20,"actual five powers x four rarities covered")
	check(Frames.CONCEPTS.size()==3 and Frames.CHOSEN in Frames.CONCEPTS,"three available genuinely rendered concepts and explicit selected architecture")
	for power in Frames.COLORS:
		check(Frames.pigment(power)==S.POWER_COLORS[power],"shared power pigment is identical in full and compact cards: "+power)
	check(T.contrast(T.TEXT,Color("101722"))>=4.5 and T.contrast(T.ENERGY,Color("090f18"))>=4.5,"opaque name and stat ink have AA contrast")
	DirAccess.make_dir_recursive_absolute("res://work/premium-mobile/cards")
	var file=FileAccess.open("res://work/premium-mobile/cards/layout-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"actual_cards":cards.size(),"power_rarity_pairs":checked.size(),"overflow":overflow,"scope":"measured actual role geometry and names; rendered material comparison is a separate graphical test"},"  "));file.close()
	view.free()
	print("PREMIUM CARD FRAMES: ",assertions," assertions, ",failures," failures; all550 actual hand names at3 mobile sizes/library fits at2 sizes,357 actual unit status contracts,20 power/rarity pairs")
	root.get_node("GameAudio").request_quit(1 if failures else 0)
const S=preload("res://scripts/alpha/style.gd")
