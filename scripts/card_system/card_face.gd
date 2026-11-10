extends Control
## Canonical full card. Compact battle/hand views remain separate representations.
## All drawing is in a 756 x 1056 master and stays inside one rounded contour.
const S = preload("res://scripts/alpha/style.gd")
const T = preload("res://scripts/ui_tokens.gd")
const ATLAS = preload("res://assets/art/atlas.png")
const ART = preload("res://scripts/production/art_resolver.gd")
const MASTER_SIZE = Vector2(756,1056)
const OUTER = Rect2(8,8,740,1040)
const ART_RECT = Rect2(42,152,672,500)
const INFORMATION_LIFT = 60
const POWERS = {
	"houses": {"name":"Zwölf Häuser","color":Color("c58c64"),"symbol":"Ⅻ"},
	"stillwatch": {"name":"Stillwacht","color":Color("9bd2e8"),"symbol":"◇"},
	"morph": {"name":"Vielgestalt","color":Color("65c49e"),"symbol":"❧"},
	"ninth": {"name":"Neunte Stunde","color":Color("b99ce2"),"symbol":"Ⅸ"},
	"neutral": {"name":"Neutral","color":Color("a9bac9"),"symbol":"○"}
}
const KINDS = {"creature":"Wesen","event":"Impuls","relic":"Relikt"}
const SPECIES = {"human":"Menschen","beast":"Bestien","spirit":"Geister","construct":"Konstrukte","plant":"Pflanzen","amalgam":"Amalgame","morphid":"Morphiden","paradox":"Paradoxe","revenant":"Wiedergänger","elemental":"Elementare","devourer":"Zehrer","mechanoid":"Mechanoide"}
const INK = Color("10151f")
const RULES = Color("161d29")
const TEXT = Color("f3ede2")
const SECONDARY = Color("c5ccd7")
var card: Dictionary = {}:
	set(value):
		card=value
		queue_redraw()
var face_down := false:
	set(value):
		face_down=value
		queue_redraw()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

func face_rect() -> Rect2:
	var scale_value=minf(size.x/MASTER_SIZE.x,size.y/MASTER_SIZE.y)
	return Rect2((size-MASTER_SIZE*scale_value)/2,MASTER_SIZE*scale_value)

func normalized() -> Dictionary:
	# In Alpha v1 `power` is a NUMBER: it is not the v2 faction identifier.
	var power_id=str(card.get("faction",card.get("power","neutral")))
	if not POWERS.has(power_id):power_id="neutral"
	var species_names: Array[String]=[]
	for species_id in card.get("species",[]):
		if SPECIES.has(str(species_id)):species_names.append(SPECIES[str(species_id)])
	var resolved=ART.resolve(card)
	var illustration: Texture2D=resolved.texture
	var art_status: String=resolved.status
	var art_label: String=resolved.label
	return {"id":str(card.get("id","")),"name":str(card.get("name","")),"power":power_id,"kind":str(card.get("kind","creature")),"rarity":str(card.get("rarity","common")),"cost":int(card.get("energy_cost",card.get("cost",0))),"resonance":int(card.get("resonance_cost",0)),"attack":int(card.get("attack",card.get("atk",0))),"health":int(card.get("health",card.get("hp",0))),"species":" · ".join(species_names),"text":str(card.get("text_de",card.get("description",""))),"art_status":art_status,"art_label":art_label,"illustration":illustration}

func paragraph(value: String, width: float, height: float, maximum: int, minimum: int) -> TextParagraph:
	var result: TextParagraph
	for font_size in range(maximum,minimum-1,-1):
		result=TextParagraph.new()
		result.width=width
		result.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		result.add_string(value,S.font,font_size)
		if result.get_size().y<=height:break
	return result

func layout_report() -> Dictionary:
	var data=normalized()
	var title_box=Rect2(126,49,478,87)
	var rules_top=(747 if data.kind=="creature" else 760 if data.resonance>0 else 722)-INFORMATION_LIFT
	var rules_box=Rect2(61,rules_top,634,932-rules_top)
	var title=paragraph(data.name,title_box.size.x,title_box.size.y,34,25)
	var rules=paragraph(data.text,rules_box.size.x,rules_box.size.y,30,24)
	return {"master_size":MASTER_SIZE,"outer":OUTER,"outer_radius":34,"art":ART_RECT,"title":title_box,"rules":rules_box,"title_actual":title.get_size(),"rules_actual":rules.get_size(),"title_fits":title.get_size().y<=title_box.size.y,"rules_fit":rules.get_size().y<=rules_box.size.y,"has_combat_values":data.kind=="creature","art_is_shared":data.illustration==null,"species":data.species,"face":face_rect()}

func rounded_box(rect: Rect2, fill: Color, edge: Color, width: int, radius: int) -> void:
	var box=StyleBoxFlat.new()
	box.bg_color=fill;box.border_color=edge
	box.set_border_width_all(width);box.set_corner_radius_all(radius)
	box.anti_aliasing=true;box.anti_aliasing_size=1
	draw_style_box(box,rect)

func label(value: String, baseline: Vector2, font_size: int, tint: Color, width: float, alignment: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(S.font,baseline,value,alignment,width,font_size,tint)

func diamond(center: Vector2, radius: Vector2, tint: Color, filled: bool=true) -> void:
	var points=PackedVector2Array([center+Vector2(0,-radius.y),center+Vector2(radius.x,0),center+Vector2(0,radius.y),center+Vector2(-radius.x,0)])
	if filled:draw_colored_polygon(points,tint)
	else:
		points.append(points[0]);draw_polyline(points,tint,2,true)

func _draw() -> void:
	if size.x<=0 or size.y<=0:return
	var bounds=face_rect()
	draw_set_transform(bounds.position,0,Vector2.ONE*(bounds.size.x/MASTER_SIZE.x))
	if face_down:draw_back()
	else:draw_front()
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_illustration(data: Dictionary) -> void:
	if data.illustration!=null:
		var dimensions=data.illustration.get_size()
		var target_ratio=ART_RECT.size.x/ART_RECT.size.y
		var source=Rect2(Vector2.ZERO,dimensions)
		if dimensions.x/dimensions.y>target_ratio:
			source.size.x=dimensions.y*target_ratio;source.position.x=(dimensions.x-source.size.x)/2
		else:
			source.size.y=dimensions.x/target_ratio;source.position.y=(dimensions.y-source.size.y)/2
		draw_texture_rect_region(data.illustration,ART_RECT,source)
	else:
		var cell=ATLAS.get_size()/3.0
		var index=absi(str(data.id).hash())%7
		var source=Rect2(Vector2(index%3,floori(float(index)/3))*cell,cell)
		source.size.y=cell.x/(ART_RECT.size.x/ART_RECT.size.y)
		source.position.y+=(cell.y-source.size.y)*.35
		draw_texture_rect_region(ATLAS,ART_RECT,source)
	# Opaque title/description plates keep text independent of image contrast.
	draw_rect(Rect2(ART_RECT.position,Vector2(ART_RECT.size.x,4)),Color(1,1,1,.16))
	if not data.art_label.is_empty():
		draw_rect(Rect2(53,162,325,30),Color(.035,.055,.08,.92))
		label(data.art_label,Vector2(64,184),18,SECONDARY,310)

func draw_front() -> void:
	var data=normalized()
	var identity=POWERS[data.power]
	var color: Color=identity.color
	var rarity_level=int({"common":0,"rare":1,"epic":2,"legendary":3}.get(data.rarity,0))
	# One invariant rounded outer silhouette; no glow or crystal may project out.
	rounded_box(OUTER,INK,color.darkened(.32),3,34)
	rounded_box(Rect2(21,21,714,1014),color.darkened(.8),color.lightened(.06),3,26)
	rounded_box(Rect2(31,31,694,994),INK,color.darkened(.42),2,20)
	# Bevel lighting has a single upper-left source.
	draw_line(Vector2(56,24),Vector2(697,24),color.lightened(.4),2,true)
	draw_line(Vector2(733,53),Vector2(733,1006),color.darkened(.55),3,true)
	draw_line(Vector2(57,1031),Vector2(697,1031),color.darkened(.65),3,true)
	draw_illustration(data)
	# Asymmetric space-fold split: a raised diagonal, never a rectangular text sticker.
	var information=PackedVector2Array([Vector2(42,656-INFORMATION_LIFT),Vector2(714,570-INFORMATION_LIFT),Vector2(714,966),Vector2(42,966)])
	draw_colored_polygon(information,RULES)
	draw_colored_polygon(PackedVector2Array([Vector2(42,647-INFORMATION_LIFT),Vector2(714,561-INFORMATION_LIFT),Vector2(714,578-INFORMATION_LIFT),Vector2(42,664-INFORMATION_LIFT)]),color.darkened(.4))
	draw_line(Vector2(42,647-INFORMATION_LIFT),Vector2(714,561-INFORMATION_LIFT),color.lightened(.25),3,true)
	draw_line(Vector2(53,668-INFORMATION_LIFT),Vector2(701,585-INFORMATION_LIFT),Color(color,.26),1,true)
	# Rarity affects depth and folded facets, while faction pigment remains dominant.
	for layer in rarity_level:
		var offset=float(layer)*8
		draw_polyline(PackedVector2Array([Vector2(46+offset,824),Vector2(46+offset,699+offset),Vector2(145+offset,686+offset)]),Color(color,.28+float(layer)*.13),2,true)
		draw_polyline(PackedVector2Array([Vector2(710-offset,837),Vector2(710-offset,930-offset),Vector2(607-offset,943-offset)]),Color(color,.3+float(layer)*.1),2,true)
	if rarity_level>=2:
		for point in [Vector2(53,546),Vector2(703,199)]:
			diamond(point,Vector2(8,22),color.darkened(.24))
			draw_line(point+Vector2(0,-22),point+Vector2(0,22),color.lightened(.4),1,true)
	if rarity_level==3:
		draw_colored_polygon(PackedVector2Array([Vector2(626,611-INFORMATION_LIFT),Vector2(704,601-INFORMATION_LIFT),Vector2(704,650-INFORMATION_LIFT),Vector2(682,625-INFORMATION_LIFT)]),Color(color,.25))
		draw_line(Vector2(626,611-INFORMATION_LIFT),Vector2(682,625-INFORMATION_LIFT),color.lightened(.28),2,true)
	# Identical, opaque header positions for all types and rarities.
	rounded_box(Rect2(42,42,672,110),INK,color.darkened(.45),1,12)
	draw_circle(Vector2(82,87),36,color.darkened(.62))
	draw_arc(Vector2(82,87),36,0,TAU,60,color,2,true)
	label(str(data.cost),Vector2(52,101),39,T.ENERGY,60,HORIZONTAL_ALIGNMENT_CENTER)
	var title=paragraph(data.name,478,87,34,25)
	title.draw(get_canvas_item(),Vector2(126,49),TEXT)
	diamond(Vector2(663,87),Vector2(32,41),color.darkened(.65))
	diamond(Vector2(663,87),Vector2(32,41),color,false)
	label(identity.symbol,Vector2(635,99),31,color.lightened(.32),56,HORIZONTAL_ALIGNMENT_CENTER)
	label(KINDS.get(data.kind,data.kind),Vector2(61,692-INFORMATION_LIFT),28,TEXT,193)
	label(identity.name,Vector2(263,692-INFORMATION_LIFT),23,color.lightened(.3),430,HORIZONTAL_ALIGNMENT_RIGHT)
	if data.kind=="creature":
		if not data.species.is_empty():label(data.species,Vector2(61,730-INFORMATION_LIFT),23,SECONDARY,634)
	elif data.resonance>0:
		label("Zusätzlich %d Resonanz" % data.resonance,Vector2(61,730-INFORMATION_LIFT),22,SECONDARY,634)
	var report=layout_report()
	paragraph(data.text,report.rules.size.x,report.rules.size.y,30,24).draw(get_canvas_item(),report.rules.position,TEXT)
	if data.kind=="creature":
		stat(Vector2(95,979),str(data.attack),"ANGRIFF",color)
		stat(Vector2(661,979),str(data.health),"LEBEN",color)
	draw_line(Vector2(195,973),Vector2(301,973),color.darkened(.25),1,true)
	draw_line(Vector2(455,973),Vector2(561,973),color.darkened(.25),1,true)
	var symbols=["•","◆","✦","✧"]
	label(symbols[rarity_level],Vector2(346,981),33,color.lightened(.3),64,HORIZONTAL_ALIGNMENT_CENTER)
	label(S.RARITIES.get(data.rarity,data.rarity),Vector2(225,1011),21,SECONDARY,306,HORIZONTAL_ALIGNMENT_CENTER)

func stat(center: Vector2, value: String, caption: String, tint: Color) -> void:
	diamond(center,Vector2(43,42),INK)
	diamond(center,Vector2(43,42),tint,false)
	label(value,center+Vector2(-36,13),39,TEXT,72,HORIZONTAL_ALIGNMENT_CENTER)
	label(caption,center+Vector2(-60,42),15,SECONDARY,120,HORIZONTAL_ALIGNMENT_CENTER)

func draw_back() -> void:
	# This function deliberately never reads `card` or `normalized()`.
	var steel=Color("a8b7c7")
	rounded_box(OUTER,Color("111721"),steel.darkened(.35),3,34)
	rounded_box(Rect2(21,21,714,1014),Color("202b39"),steel.darkened(.15),3,26)
	rounded_box(Rect2(34,34,688,988),Color("111a27"),steel.darkened(.52),2,18)
	var center=MASTER_SIZE/2
	# Mirrored fold seams and five paths. No faction pigment or rarity markers.
	for x_sign in [-1,1]:
		for y_sign in [-1,1]:
			var tip=center+Vector2(302*x_sign,443*y_sign)
			var hinge=center+Vector2(136*x_sign,211*y_sign)
			var side=center+Vector2(302*x_sign,71*y_sign)
			draw_colored_polygon(PackedVector2Array([tip,hinge,side]),Color("283648"))
			draw_polyline(PackedVector2Array([side,hinge,tip]),Color("63778e"),2,true)
	for offset in range(-2,3):
		var x=center.x+float(offset)*46
		draw_line(Vector2(x,308+absi(offset)*21),Vector2(x,748-absi(offset)*21),Color("8c9eb3"),2,true)
	diamond(center,Vector2(179,256),Color("111a27"))
	diamond(center,Vector2(179,256),steel.darkened(.1),false)
	diamond(center,Vector2(152,223),Color("677c95"),false)
	for offset in range(-2,3):
		var x=center.x+float(offset)*34
		draw_line(Vector2(x,415+absi(offset)*15),Vector2(x,641-absi(offset)*15),Color("a8b7c7"),3,true)
	diamond(center,Vector2(72,103),Color("26374d"))
	diamond(center,Vector2(72,103),steel,false)
	draw_polyline(PackedVector2Array([center+Vector2(-37,-48),center+Vector2(27,-9),center+Vector2(-27,9),center+Vector2(37,48)]),Color("d3dfed"),4,true)
	label("ORAFOLD",Vector2(143,231),48,TEXT,470,HORIZONTAL_ALIGNMENT_CENTER)
	label("ORAFOLD",Vector2(143,861),48,TEXT,470,HORIZONTAL_ALIGNMENT_CENTER)
