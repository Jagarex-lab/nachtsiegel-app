extends "res://scripts/card_system/card_face.gd"
## The actual enlarged collectible card. Only its printed rules area scrolls.
## Illustration, pigment, frame concept, contour and card identity use FullCardFace.
## This presentation never reads or calls a battle model.
var title_label: Label
var cost_label: Label
var identity_label: Label
var species_label: Label
var rules_label: Label
var rules_scroll: ScrollContainer
var rules_body: VBoxContainer
var attack_label: Label
var health_label: Label
var rarity_label: Label
var art_status_label: Label
var _labels: Dictionary={}
var _shown_signature := ""
var _fitting := false

func _ready() -> void:
	super._ready()
	mouse_filter=Control.MOUSE_FILTER_STOP
	title_label=_make_label("Title",HORIZONTAL_ALIGNMENT_LEFT)
	cost_label=_make_label("Energy",HORIZONTAL_ALIGNMENT_CENTER)
	identity_label=_make_label("Identity",HORIZONTAL_ALIGNMENT_LEFT)
	species_label=_make_label("Species",HORIZONTAL_ALIGNMENT_LEFT)
	attack_label=_make_label("Attack",HORIZONTAL_ALIGNMENT_LEFT)
	health_label=_make_label("Health",HORIZONTAL_ALIGNMENT_RIGHT)
	rarity_label=_make_label("Rarity",HORIZONTAL_ALIGNMENT_CENTER)
	art_status_label=_make_label("ArtDelivery",HORIZONTAL_ALIGNMENT_LEFT)
	art_status_label.add_theme_stylebox_override("normal",T.panel(Color.TRANSPARENT,Color(.035,.055,.08,.94)))
	for value in [attack_label,health_label]:value.autowrap_mode=TextServer.AUTOWRAP_OFF
	rules_scroll=ScrollContainer.new();rules_scroll.name="PrintedRules"
	rules_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	rules_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	rules_scroll.scroll_deadzone=8;rules_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(rules_scroll)
	rules_body=VBoxContainer.new();rules_body.add_theme_constant_override("separation",4)
	rules_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rules_scroll.add_child(rules_body)
	remove_child(species_label);rules_body.add_child(species_label)
	rules_label=Label.new();rules_label.name="Rules"
	rules_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rules_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rules_label.mouse_filter=Control.MOUSE_FILTER_PASS
	rules_label.add_theme_font_override("font",S.font)
	rules_label.add_theme_color_override("font_color",TEXT)
	rules_body.add_child(rules_label)
	resized.connect(_fit_print)
	_refresh_print()
	_fit_print()

func _process(delta: float) -> void:
	super._process(delta)
	var signature=JSON.stringify(card)
	if signature!=_shown_signature:_refresh_print();_fit_print()
	# The inherited delivery caption was positioned under the old header.
	# Keep loading/offline/provenance truthful in this reflowed card as well.
	art_status_label.text=str(_illustration_data.get("label",""))
	art_status_label.visible=not art_status_label.text.is_empty()

func _make_label(node_name: String, alignment: HorizontalAlignment) -> Label:
	var node=Label.new();node.name=node_name;node.horizontal_alignment=alignment
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font",S.font)
	node.add_theme_color_override("font_color",TEXT)
	add_child(node);_labels[node_name]=node
	return node

func _refresh_print() -> void:
	if not is_instance_valid(title_label):return
	_shown_signature=JSON.stringify(card)
	var data=normalized()
	title_label.text=data.name;cost_label.text=str(data.cost)
	identity_label.text=POWERS[data.power].name+" · "+KINDS.get(data.kind,data.kind)
	species_label.text=data.species if data.kind=="creature" else ("+ %d Resonanz" % data.resonance if data.resonance>0 else "")
	species_label.visible=not species_label.text.is_empty()
	# Exact source text: no dropped limits, targets, magnitudes or trigger clauses.
	rules_label.text=data.text
	attack_label.text="%d Angriff" % data.attack if data.kind=="creature" else ""
	health_label.text="%d Leben" % data.health if data.kind=="creature" else ""
	rarity_label.text=S.RARITIES.get(data.rarity,data.rarity)
	identity_label.add_theme_color_override("font_color",Frames.pigment(data.power).lightened(.4))
	cost_label.add_theme_color_override("font_color",T.ENERGY)
	rules_scroll.scroll_vertical=0

func _local(master_rect: Rect2) -> Rect2:
	var fitted=face_rect();var factor=fitted.size.x/MASTER_SIZE.x
	return Rect2(fitted.position+master_rect.position*factor,master_rect.size*factor)

func _place(node: Control, rect: Rect2) -> void:
	node.position=rect.position;node.size=rect.size

func _fit_print() -> void:
	if _fitting or not is_instance_valid(rules_scroll) or size.x<=0 or size.y<=0:return
	_fitting=true
	var header=_local(Rect2(126,40,478,160))
	var title_font=clampi(roundi(size.y/23.0),13,24)
	for candidate in range(title_font,12,-1):
		var paragraph=TextParagraph.new();paragraph.width=header.size.x
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		paragraph.add_string(title_label.text,S.font,candidate)
		title_font=candidate
		if paragraph.get_size().y<=header.size.y:break
	title_label.add_theme_font_size_override("font_size",title_font)
	_place(title_label,header)
	cost_label.add_theme_font_size_override("font_size",clampi(roundi(size.y/20.0),15,28))
	_place(cost_label,_local(Rect2(43,40,78,160)))
	var small_font=clampi(roundi(size.y/30.0),12,17)
	identity_label.add_theme_font_size_override("font_size",small_font)
	var identity_rect=_local(Rect2(61,557,634,62))
	var identity_lines=TextParagraph.new();identity_lines.width=identity_rect.size.x
	identity_lines.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	identity_lines.add_string(identity_label.text,S.font,small_font)
	identity_rect.size.y=maxf(identity_rect.size.y,identity_lines.get_size().y)
	_place(identity_label,identity_rect)
	art_status_label.add_theme_font_size_override("font_size",12)
	_place(art_status_label,_local(Rect2(55,208,646,80)))
	species_label.add_theme_font_size_override("font_size",small_font)
	var stat_font=clampi(roundi(size.y/23.0),14,23)
	var rarity_height=maxf(14,S.font.get_height(small_font))
	var stat_height=maxf(18,S.font.get_height(stat_font))
	var rarity_top=face_rect().end.y-maxf(4,size.y*.016)-rarity_height
	var stat_top=rarity_top-stat_height-2
	var printed=_local(Rect2(61,626,634,306))
	printed.position.y=maxf(printed.position.y,identity_rect.end.y+3)
	printed.size.y=minf(printed.size.y,maxf(18,stat_top-4-printed.position.y))
	_place(rules_scroll,printed)
	var body_font=clampi(roundi(size.y/29.0),13,18)
	rules_label.add_theme_font_size_override("font_size",body_font)
	rules_label.add_theme_constant_override("line_spacing",2)
	# Reserve the themed scrollbar so line wrapping is stable while dragging.
	var gutter=rules_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	rules_body.custom_minimum_size.x=maxf(44,printed.size.x-gutter)
	for node in [attack_label,health_label]:node.add_theme_font_size_override("font_size",stat_font)
	var attack_rect=_local(Rect2(48,941,260,70));var health_rect=_local(Rect2(448,941,260,70))
	attack_rect.position.y=stat_top;health_rect.position.y=stat_top
	attack_rect.size.y=stat_height;health_rect.size.y=stat_height
	_place(attack_label,attack_rect);_place(health_label,health_rect)
	if card.get("kind","creature")=="creature":
		var attack=int(card.get("attack",card.get("atk",0)));var health=int(card.get("health",card.get("hp",0)))
		attack_label.text="%d Angriff" % attack;health_label.text="%d Leben" % health
		# At an unusually short browser height, abbreviate captions rather
		# than wrapping combat values over the rarity or outside the card.
		if S.font.get_string_size(attack_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,stat_font).x>attack_rect.size.x:attack_label.text="ATK %d" % attack
		if S.font.get_string_size(health_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,stat_font).x>health_rect.size.x:health_label.text="LP %d" % health
	rarity_label.add_theme_font_size_override("font_size",small_font)
	var rarity_rect=_local(Rect2(193,993,370,46));rarity_rect.position.y=rarity_top;rarity_rect.size.y=rarity_height
	_place(rarity_label,rarity_rect)
	_fitting=false
	queue_redraw()

func art_aperture() -> Rect2:
	var rank=int(Frames.RANKS.get(card.get("rarity","common"),0))
	var inset=maxf(42,8+float([25,34,43,52][rank]))
	return Rect2(inset,202,MASTER_SIZE.x-inset*2,300)

func draw_front() -> void:
	var data=normalized();var tint=Frames.pigment(data.power)
	Frames.base(self,OUTER,data.power,data.rarity,frame_concept)
	draw_illustration(data)
	if data.art_label.is_empty():Frames.gallery_arch(self,OUTER,data.power,data.rarity,frame_concept)
	# The same diagonal grammar is reflowed for a readable printed rules area.
	draw_colored_polygon(PackedVector2Array([Vector2(42,550),Vector2(714,475),Vector2(714,966),Vector2(42,966)]),RULES)
	draw_colored_polygon(PackedVector2Array([Vector2(42,541),Vector2(714,466),Vector2(714,484),Vector2(42,559)]),tint.darkened(.4))
	draw_line(Vector2(42,541),Vector2(714,466),tint.lightened(.25),3,true)
	Frames.overlay(self,OUTER,data.power,data.rarity,frame_concept,sin(_glint_remaining/.65*PI) if _glint_remaining>0 else 0.0)
	rounded_box(Rect2(42,40,672,160),INK,tint.darkened(.45),1,12)
	draw_circle(Vector2(82,120),37,tint.darkened(.62))
	draw_arc(Vector2(82,120),37,0,TAU,60,tint,2,true)
	diamond(Vector2(663,120),Vector2(32,42),tint.darkened(.65))
	Frames.sigil(self,Vector2(663,120),23,data.power,tint.lightened(.45))

func inspection_report() -> Dictionary:
	if not is_instance_valid(rules_label):return {}
	var art=art_report();var scroll_bar=rules_scroll.get_v_scroll_bar()
	return {"id":str(card.get("id","")),"title":title_label.text,"rules":rules_label.text,"rules_font_size":rules_label.get_theme_font_size("font_size"),"rules_rect":rules_scroll.get_global_rect(),"rules_content_rect":rules_label.get_global_rect(),"rules_visible_rect":rules_label.get_global_rect().intersection(rules_scroll.get_global_rect()),"card_rect":get_global_rect(),"card_aspect":size.x/size.y,"art":art,"rules_scroll":{"offset":rules_scroll.scroll_vertical,"content_height":scroll_bar.max_value,"viewport_height":scroll_bar.page,"can_scroll":scroll_bar.max_value>scroll_bar.page+1},"keyword_definitions_in_card":false,"title_rect":title_label.get_global_rect(),"stats_rects":{"attack":attack_label.get_global_rect(),"health":health_label.get_global_rect(),"rarity":rarity_label.get_global_rect()},"combat_text":{"attack":attack_label.text,"health":health_label.text},"art_caption":art_status_label.text if art_status_label.visible else ""}

func layout_report() -> Dictionary:
	if not is_instance_valid(title_label):return super.layout_report()
	var header=_local(Rect2(126,40,478,160));var printed=rules_scroll.get_rect()
	return {"master_size":MASTER_SIZE,"outer":OUTER,"art":art_aperture(),"title":header,"rules":printed,"title_actual":title_label.get_minimum_size(),"rules_actual":rules_label.get_minimum_size(),"title_fits":title_label.get_minimum_size().y<=header.size.y+1,"rules_fit":Rect2(Vector2.ZERO,size).encloses(printed),"has_combat_values":card.get("kind","creature")=="creature","face":face_rect(),"frame_concept":frame_concept,"rules_scrolls_inside_card":true,"rules_font_size":rules_label.get_theme_font_size("font_size")}
