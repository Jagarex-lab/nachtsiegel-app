extends Button
const T=preload("res://scripts/ui_tokens.gd")
const S=preload("res://scripts/alpha/style.gd")
const ATLAS=preload("res://assets/art/atlas.png")
const ART=preload("res://scripts/production/art_resolver.gd")
const Frames=preload("res://scripts/premium/card_frames.gd")
var card: Dictionary={}
# Roles are presentation contracts, never alternate card definitions/rules.
var display_role := "auto"
var frame_concept := Frames.CHOSEN
var reduced_motion := true
# The controller supplies validated availability; this renderer never calls
# rule/model methods and an unaffordable card remains touch-inspectable.
var availability_shown := false
var playable := false
var unavailable_reason := ""
var _glint_remaining := 0.0
var _glint_card := ""
var _illustration_binding := ""
var _illustration_data: Dictionary = {}
var art_profile := "compact"
var _delivery_card_id := ""
var _delivery_profile := ""
var _delivery_visible := false
var unit: Dictionary={}
var selected := false
var target := false
var invalid_target := false
var color=Color("79ddd4")
var lane := -1
var origin := false
var combat_ready := false
var attack_penalty := 0
var convergence := false
var broken_convergence := false
var library := false
var owner_label := ""
# Optional view-only constraints for browser-toolbar hand heights.
var title_maximum_size := 12
var title_available_height := -1.0
func _ready() -> void:
	for key in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	clip_contents=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _ink(value: String, at: Vector2, fs: int, tint: Color, width: float) -> void:
	draw_string(S.font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,tint)
func _process(delta: float) -> void:
	var visible_now: bool = not card.is_empty() and ART.visible_owner(self)
	if _delivery_card_id != str(card.get("id", "")) or _delivery_profile != art_profile or not visible_now:
		ART.release_owner(self); _delivery_card_id = ""; _delivery_profile = ""
	if visible_now:
		if not _delivery_visible or _delivery_card_id.is_empty(): _illustration_binding = ""
		if ART.binding_key(card, art_profile) != _illustration_binding: queue_redraw()
	_delivery_visible = visible_now
	if visible_now and _glint_card != str(card.get("id","")):
		_glint_card=str(card.get("id",""));_glint_remaining=.65 if not reduced_motion and card.get("rarity")=="legendary" else 0.0
	if _glint_remaining>0:
		_glint_remaining=maxf(0,_glint_remaining-delta) if visible_now and not reduced_motion else 0.0
		queue_redraw()
func _exit_tree() -> void: ART.release_owner(self)
func art_report() -> Dictionary:
	# Observe the actual bound pixels; never resolve/load/request through QA.
	var texture: Texture2D = _illustration_data.get("texture")
	var geometry:=layout_report()
	return {"card_id": str(card.get("id", "")), "visible": ART.visible_owner(self), "status": str(_illustration_data.get("status", "unbound")), "pixels": [texture.get_width(), texture.get_height()] if texture != null else [], "pending": bool(_illustration_data.get("preview_pending", true)), "profile": str(_illustration_data.get("profile", art_profile)), "delivery_state": str(_illustration_data.get("delivery_state", "unbound")), "coordinate_space":"local", "title_fits":geometry.title_fits,"title_font_size":geometry.title_font_size,"availability_shown":availability_shown,"playable":playable,"unavailable_reason":unavailable_reason, "display_role":effective_role(), "frame_concept":frame_concept,"rarity":str(card.get("rarity","common")),"illustration_rect":_rect_array(geometry.art),"frame_rect":_rect_array(geometry.outer),"visible_art_fraction":geometry.art_fraction}
func illustration(aperture: Rect2, tint: Color=Color.WHITE) -> void:
	var binding := ART.binding_key(card, art_profile)
	if binding != _illustration_binding:
		_illustration_data = ART.resolve(card, art_profile, self); _illustration_binding = binding
		_delivery_card_id = str(card.get("id", "")); _delivery_profile = art_profile
		# Drawing can precede final container geometry. A refused offscreen
		# request is not registration; retry once when the real view is visible.
		_delivery_visible = ART.visible_owner(self)
	var resolved = _illustration_data
	if resolved.get("preview_pending", false):
		draw_rect(aperture, Color(.045,.06,.075))
		if aperture.size.x >= 64 and aperture.size.y >= 40:
			_ink("Bild lädt …" if resolved.delivery_state == "loading" else "Bild offline", aperture.position + Vector2(7,aperture.size.y*.5), 10, T.SECONDARY, aperture.size.x-14)
		return
	if resolved.texture!=null:
		var texture: Texture2D=resolved.texture
		var original=Vector2(texture.get_size());var aperture_ratio=aperture.size.x/aperture.size.y
		var crop=Rect2(Vector2.ZERO,original)
		if original.x/original.y>aperture_ratio:
			crop.size.x=original.y*aperture_ratio;crop.position.x=(original.x-crop.size.x)*.5
		else:
			crop.size.y=original.x/aperture_ratio;crop.position.y=(original.y-crop.size.y)*.38
		draw_texture_rect_region(texture,aperture,crop,tint);return
	var cell=ATLAS.get_size()/3.0;var index=absi(str(card.id).hash())%7
	var source=Rect2(Vector2(index%3,floori(float(index)/3))*cell,cell)
	var aspect=aperture.size.x/aperture.size.y
	if aspect>1:source.position.y+=cell.y*(1-1/aspect)*.38;source.size.y=cell.y/aspect
	else:source.position.x+=cell.x*(1-aspect)/2;source.size.x=cell.x*aspect
	draw_texture_rect_region(ATLAS,aperture,source,tint)
func effective_role() -> String:
	if display_role in ["hand","board","library"]:return display_role
	return "board" if not unit.is_empty() or card.is_empty() else "library" if library else "hand"
func _rect_array(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func _face_title(width: float, height: float, maximum: int, lines: int=3) -> Dictionary:
	var paragraph: TextParagraph
	var chosen:=maximum
	var minimum:=9 if size.x<84 else 10
	for fs in range(maximum,minimum-1,-1):
		paragraph=TextParagraph.new();paragraph.width=maxf(24,floorf(width))
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		paragraph.add_string(str(card.get("name",card.get("id",""))),S.font,fs);chosen=fs
		if paragraph.get_size().y<=height and paragraph.get_line_count()<=lines:break
	# Two long words can otherwise each create an orphan tail (four lines).
	# A measured grapheme fallback fits the complete name into the same plate.
	if paragraph.get_size().y>height or paragraph.get_line_count()>lines:
		paragraph=TextParagraph.new();paragraph.width=maxf(24,floorf(width))
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_GRAPHEME_BOUND
		paragraph.add_string(str(card.get("name",card.get("id",""))),S.font,chosen)
	return {"paragraph":paragraph,"font_size":chosen,"fits":paragraph.get_size().y<=height and paragraph.get_line_count()<=lines}
func layout_report() -> Dictionary:
	var outer:=Rect2(Vector2(2,2),(size-Vector2(4,4)).max(Vector2.ZERO))
	var role:=effective_role()
	if role=="library":
		# Existing collection tiles may have a wide touch surface. Fit the
		# canonical portrait inside it instead of stretching card architecture.
		var fitted:=Vector2(minf(outer.size.x,outer.size.y*63.0/88.0),minf(outer.size.y,outer.size.x*88.0/63.0))
		outer=Rect2(outer.get_center()-fitted/2,fitted)
	var rank:=int(Frames.RANKS.get(card.get("rarity","common"),0))
	var material_scale:=minf(outer.size.x/740.0,outer.size.y/1040.0)
	var inset:=maxf(3,float([25,34,43,52][rank])*material_scale)
	var art:=outer.grow(-inset)
	var board:=role=="board"
	var footer_height:=16.0 if size.y<160 else 25.0
	var title_height:=42.0 if not board else 28.0 if size.y>=120 else 0.0
	var title:=Rect2(art.position+Vector2(4,2),Vector2(maxf(24,art.size.x-8),title_height))
	var stats:=Rect2(art.position.x,art.end.y-footer_height,art.size.x,footer_height)
	if not board:
		title.position=Vector2(art.position.x+1,stats.position.y-title_height)
		title.size.x=maxf(24,art.size.x-2)
	else:title.size.x-=22 if lane>=0 else 0
	var maximum:=12 if size.x>=150 else 11 if size.x>=105 else 10
	var title_data:=_face_title(title.size.x,title.size.y,maximum,2 if board else 3)
	if board and title_height==0:
		title_data.fits=true
	if not board:
		title.size.y=maxf(24,title_data.paragraph.get_size().y)
		title.position.y=stats.position.y-title.size.y
		title_height=title.size.y
	# Visible illustration is measured after opaque name/stat plates. Cost and
	# faction medallions are also subtracted for a conservative browser contract.
	var exposed:=maxf(0,art.size.y-title_height-footer_height)
	var frame_rank:=int(Frames.RANKS.get(card.get("rarity","common"),0))
	var material_width:=maxf(float([25,34,43,52][frame_rank])*material_scale,outer.size.x*.072)
	var visible_width:=maxf(0,art.size.x-2*maxf(0,material_width-inset))
	var visible_area:=visible_width*exposed
	if not board:visible_area=maxf(0,visible_area-2*PI*pow(minf(14,size.x*.135),2)-Frames.collectible_occlusion(outer,str(card.get("rarity","common"))))
	elif not unit.is_empty():visible_area=maxf(0,visible_area-visible_width*15) # readiness/modifier band
	return {"role":role,"outer":outer,"art":art,"title":title,"stats":stats,"status":stats,"title_actual":title_data.paragraph.get_size() if title_height>0 else Vector2.ZERO,"title_fits":title_data.fits,"title_font_size":title_data.font_size,"art_fraction":visible_area/maxf(1,outer.get_area()),"frame_concept":frame_concept,"has_combat_values":card.get("kind")=="creature","status_values":board_status() if board else {}}
func _draw() -> void:
	if size.x<=8 or size.y<=8:return
	var report:=layout_report()
	var rect: Rect2=report.outer
	var edge=T.GOLD if selected or convergence else T.SUCCESS if target else color
	if card.is_empty():
		# A free lane is a low raised docking plane, not a giant debug circle.
		Frames.box(self,rect,Color(.025,.045,.06,.38),Color(edge,.42 if target else .18),1,7)
		var center:=size/2.0
		var half:=minf(12,size.y*.18)
		draw_polyline(PackedVector2Array([center+Vector2(-half,0),center+Vector2(0,-half*.5),center+Vector2(half,0),center+Vector2(0,half*.5),center+Vector2(-half,0)]),Color(edge,.8 if target else .28),1.4,true)
		if lane>=0:_ink(str(lane+1),center+Vector2(-3,4),11,T.TEXT if target else T.MUTED,18)
		if origin:_ink("U",Vector2(7,15),11,T.GOLD,16)
	else:
		var power:=str(card.get("faction","neutral"))
		var rarity:=str(card.get("rarity","common"))
		Frames.base(self,rect,power,rarity,frame_concept)
		illustration(report.art)
		Frames.overlay(self,rect,power,rarity,frame_concept,sin(_glint_remaining/.65*PI) if _glint_remaining>0 else 0.0)
		if effective_role()!="board":Frames.collectible_arch(self,rect,power,rarity,frame_concept)
		# Information is always painted above ornament: rarity may never hide
		# the name, energy cost, shield/block, current attack or current life.
		if effective_role()=="board":_draw_board(report)
		else:_draw_portrait(report)
	# Interaction always dominates material, inside the same hit contour.
	if selected or convergence:Frames.box(self,rect.grow(-1),Color.TRANSPARENT,T.GOLD,2,5)
	if target:Frames.box(self,rect.grow(-1),Color.TRANSPARENT,T.SUCCESS,2,5)
	if invalid_target:
		draw_line(Vector2(size.x-12,7),Vector2(size.x-5,14),T.DANGER,2,true);draw_line(Vector2(size.x-5,7),Vector2(size.x-12,14),T.DANGER,2,true)
	if has_focus():Frames.box(self,rect.grow(-1),Color.TRANSPARENT,T.FOCUS,1,5)
func _draw_portrait(report: Dictionary) -> void:
	var art: Rect2=report.art
	var name_box: Rect2=report.title
	var stats: Rect2=report.stats
	var power:=str(card.get("faction","neutral"))
	var pigment:=Frames.pigment(power)
	# The diagonal plate is deliberately below the image, so a small hand card
	# is immediately recognisable as an illustrated collectible rather than a
	# horizontal text button. Full rules live in the undistorted inspector.
	draw_colored_polygon(PackedVector2Array([Vector2(art.position.x,name_box.position.y+3),Vector2(art.end.x,name_box.position.y-5),art.end,Vector2(art.position.x,art.end.y)]),Color("101722"))
	draw_line(Vector2(art.position.x,name_box.position.y+3),Vector2(art.end.x,name_box.position.y-5),pigment.lightened(.35),1.3,true)
	var title:=_face_title(name_box.size.x,name_box.size.y,int(report.title_font_size))
	title.paragraph.draw(get_canvas_item(),name_box.position,T.TEXT)
	draw_rect(stats,Color("090f18"))
	var radius:=minf(14,size.x*.135)
	var cost_center:=art.position+Vector2(radius+1,radius+1)
	var cost_fill:=pigment.darkened(.68) if not availability_shown or playable else Color("18202b")
	draw_circle(cost_center,radius+1,cost_fill)
	draw_arc(cost_center,radius,0,TAU,24,T.ENERGY if availability_shown and playable else T.MUTED if availability_shown else pigment.lightened(.6),1.5,true)
	if availability_shown and playable:draw_arc(cost_center,radius-3,0,TAU,24,T.SUCCESS,1.2,true)
	_center_text(str(int(card.get("energy_cost",card.get("cost",0)))),cost_center,15 if size.x>=84 else 13,T.MUTED if availability_shown and not playable else T.ENERGY,radius*1.8)
	if availability_shown and not playable:
		var lock:=cost_center+Vector2(radius*.63,radius*.61)
		draw_rect(Rect2(lock-Vector2(2,0),Vector2(5,4)),T.MUTED)
		draw_arc(lock+Vector2(.5,0),2,PI,TAU,8,T.MUTED,1,true)
	var sigil_center:=Vector2(art.end.x-radius-1,cost_center.y)
	draw_colored_polygon(PackedVector2Array([sigil_center+Vector2(0,-radius),sigil_center+Vector2(radius,0),sigil_center+Vector2(0,radius),sigil_center+Vector2(-radius,0)]),pigment.darkened(.72))
	Frames.sigil(self,sigil_center,radius*.62,power,pigment.lightened(.6))
	var fs:=13 if size.x>=84 else 11
	if card.get("kind")=="creature":
		_center_text(str(int(card.get("attack",card.get("atk",0)))),Vector2(stats.position.x+11,stats.get_center().y),fs,T.WARNING,19)
		_center_text(str(int(card.get("health",card.get("hp",0)))),Vector2(stats.end.x-11,stats.get_center().y),fs,T.FOE,19)
		var center:=stats.get_center();_rarity_seal(center,maxf(3,stats.size.y*.19),pigment)
	else:
		_center_text(S.KINDS.get(card.get("kind",""),""),stats.get_center(),10,T.TEXT,stats.size.x-14)
		_rarity_seal(Vector2(stats.end.x-6,stats.get_center().y),2.5,pigment)
func _draw_board(report: Dictionary) -> void:
	var title_box: Rect2=report.title
	var stats: Rect2=report.stats
	var art: Rect2=report.art
	var power:=str(card.get("faction","neutral"))
	var pigment:=Frames.pigment(power)
	if title_box.size.y>0:
		draw_rect(Rect2(art.position,Vector2(art.size.x,title_box.size.y+3)),Color(.025,.035,.055,.94))
		var title:=_face_title(title_box.size.x,title_box.size.y,int(report.title_font_size),2)
		title.paragraph.draw(get_canvas_item(),title_box.position,T.TEXT)
	if lane>=0:_path_badge(Rect2(art.end.x-19,art.position.y+2,18,17),pigment)
	draw_colored_polygon(PackedVector2Array([Vector2(art.position.x,stats.position.y+2),Vector2(art.end.x,stats.position.y-3),art.end,Vector2(art.position.x,art.end.y)]),Color("0a111b"))
	draw_line(Vector2(art.position.x,stats.position.y+2),Vector2(art.end.x,stats.position.y-3),pigment.lightened(.25),1,true)
	var marks:=board_status()
	var fs:=14 if size.y>=120 else 12
	_center_text(str(current_attack()),Vector2(stats.position.x+10,stats.get_center().y),fs,T.WARNING,18)
	_center_text(str(int(unit.get("hp",card.get("hp",0)))),Vector2(stats.end.x-10,stats.get_center().y),fs,T.FOE,18)
	var status_text:="S%d B%d" % [marks.shield,marks.block]
	_center_text(status_text,stats.get_center(),10 if size.x>=110 else 9,T.ENERGY,maxf(25,stats.size.x-43))
	# Ready/stasis/new and relevant modifiers remain visible over the image.
	var readiness:=str(marks.ready_short)
	var ready_width:=maxf(19,S.font.get_string_size(readiness,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+8)
	Frames.box(self,Rect2(art.position.x+2,title_box.end.y+4,ready_width,15),Color("09141c"),T.SUCCESS if combat_ready else T.WARNING,1,3)
	_center_text(readiness,Vector2(art.position.x+2+ready_width/2,title_box.end.y+11.5),10,T.SUCCESS if combat_ready else T.WARNING,ready_width-4)
	if not str(marks.extra_short).is_empty():
		var extra:=str(marks.extra_short)
		var available:=art.size.x-ready_width-9
		var box_width:=minf(available,S.font.get_string_size(extra,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+8)
		if box_width>12:
			draw_rect(Rect2(art.end.x-box_width-2,title_box.end.y+4,box_width,15),Color("09141c"))
			_center_text(extra,Vector2(art.end.x-box_width/2-2,title_box.end.y+11.5),10,T.GOLD,box_width-4)
func _center_text(value: String, center: Vector2, font_size: int, tint: Color, width: float) -> void:
	var ink:=S.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	_ink(value,center+Vector2(-minf(ink.x,width)/2,(S.font.get_ascent(font_size)-S.font.get_descent(font_size))/2),font_size,tint,width)
func _rarity_seal(center: Vector2, radius: float, tint: Color) -> void:
	var rank:=int(Frames.RANKS.get(card.get("rarity","common"),0))
	if rank==0:draw_circle(center,radius,tint.lightened(.35));return
	for offset in rank:
		var x:=center.x+(float(offset)-float(rank-1)/2)*radius*2.8
		var point:=Vector2(x,center.y)
		draw_colored_polygon(PackedVector2Array([point+Vector2(0,-radius),point+Vector2(radius,0),point+Vector2(0,radius),point+Vector2(-radius,0)]),tint.lightened(.4))
func _path_badge(at: Rect2, edge: Color) -> void:
	var frame=T.panel(Color(edge,.75),T.INK)
	frame.set_border_width_all(1);frame.set_corner_radius_all(3)
	draw_style_box(frame,at)
	var fs=11 if at.size.y>=17 else 10
	var label=str(lane+1)
	var ink=S.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	_ink(label,Vector2(at.position.x+(at.size.x-ink)/2,at.position.y+(at.size.y-S.font.get_height(fs))/2+S.font.get_ascent(fs)),fs,T.TEXT,at.size.x-4)
func large_board_portrait() -> bool:
	return not unit.is_empty() and size.y>=160 and size.x>=170
func board_title_width() -> float:
	return size.x-(48 if lane>=0 else 20)
func compact_combat_labels(width: float, maximum_size: int=12) -> Dictionary:
	var caption="%d ANG %d LP" % [current_attack(),unit.get("hp",0)]
	var fs=maximum_size
	while fs>10 and S.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width:fs-=1
	return {"text":caption,"font_size":fs,"available_width":width,"fits":S.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=width}
func compact_board_labels() -> Dictionary:
	var marks=board_status()
	var caption="Schild %d · Block %d" % [marks.shield,marks.block]
	var width=size.x-16;var fs=11
	if S.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width:fs=10
	return {"status":caption,"font_size":fs,"available_width":width,"fits":S.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=width}
func tall_board_labels() -> Dictionary:
	var marks=board_status()
	var result={"combat_text":"%d ANG  %d LP" % [current_attack(),unit.get("hp",0)],"status":"Schild %d · Block %d · %s" % [marks.shield,marks.block,marks.ready_short],"value_font":15,"status_font":11}
	for fs in [15,14,13,12]:
		result.value_font=fs
		if S.font.get_string_size(result.combat_text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=size.x-20:break
	for fs in [11,10]:
		result.status_font=fs
		if S.font.get_string_size(result.status,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=size.x-20:break
	return result
func stat_layout(available_width: float) -> Dictionary:
	# Measure the same glyphs/font used for drawing. Values must end before the
	# energy circle, including in a six-card hand inside mobile safe areas.
	var caption="%d ANG %d LP" % [card.get("atk",0),card.get("hp",0)] if card.get("kind")=="creature" else S.KINDS.get(card.get("kind",""),card.get("kind",""))
	var font_size := 13
	var width := 0.0
	for candidate in [13,12,11,10]:
		font_size=candidate;width=S.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,candidate).x
		if width<=maxf(0,available_width):break
	return {"text":caption,"font_size":font_size,"ink_width":width,"available_width":maxf(0,available_width),"fits":width<=maxf(0,available_width)}
func current_attack() -> int:
	return maxi(0,int(unit.get("atk",card.get("atk",0)))-attack_penalty)
func board_status() -> Dictionary:
	# Production creatures may own temporary block as well as persistent shield.
	# Archived units default to zero block; no rules are changed by this view.
	var stun=int(unit.get("stun",0))
	var ready="✓" if combat_ready else "Z%d" % stun if stun>0 else "NEU" if bool(unit.get("summoned",false)) else "—"
	var extra: Array=[]
	if origin:extra.append("U")
	if convergence:extra.append("K")
	elif broken_convergence:extra.append("K×")
	var attack_delta=current_attack()-int(card.get("atk",0))
	if attack_delta!=0:extra.append(("+" if attack_delta>0 else "")+str(attack_delta))
	if int(unit.get("extra_attacks",0))>0:extra.append("×"+str(1+int(unit.extra_attacks)))
	return {"shield":maxi(0,int(unit.get("ward",0))),"block":maxi(0,int(unit.get("block",0))),"stun":stun,"ready":combat_ready,"ready_short":ready,"extra_short":" ".join(extra)}
func title_paragraph(width: float, maximum_size: int=12, available_height: float=-1, minimum_size: int=10) -> TextParagraph:
	return title_layout(width,maximum_size,available_height,minimum_size).paragraph
func title_layout(width: float, maximum_size: int=12, available_height: float=-1, minimum_size: int=10) -> Dictionary:
	maximum_size=mini(maximum_size,title_maximum_size)
	if title_available_height>=0:available_height=minf(available_height,title_available_height) if available_height>=0 else title_available_height
	var name=str(card.get("name",card.get("id","")))
	var result: Dictionary={}
	var word_breaks=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	for breaks in [word_breaks,TextServer.BREAK_MANDATORY|TextServer.BREAK_GRAPHEME_BOUND]:
		var largest_fit: Dictionary={}
		for fs in [12,11,10,9,8]:
			if fs>maximum_size or fs<minimum_size:continue
			var paragraph=TextParagraph.new()
			# Text shaping rounds line extents to pixels; rounding the budget down
			# prevents a 77px glyph run from entering a 76.6px neighbouring strip.
			paragraph.width=maxf(24,width if minimum_size<10 else floorf(width))
			paragraph.break_flags=breaks;paragraph.add_string(name,S.font,fs)
			var fits=paragraph.get_line_count()<=2 and (available_height<0 or paragraph.get_size().y<=available_height)
			var split_word=false
			for line in paragraph.get_line_count():
				if minimum_size>=10 and paragraph.get_line_size(line).x>width:fits=false
				if line==paragraph.get_line_count()-1:continue
				var cut=paragraph.get_line_range(line).y
				if cut>0 and cut<name.length() and not name.substr(cut-1,1) in [" ","-","/","\n"] and not name.substr(cut,1) in [" ","\n"]:split_word=true
			result={"paragraph":paragraph,"font_size":fs,"fits":fits,"split_word":split_word}
			if not fits:continue
			if largest_fit.is_empty():largest_fit=result
			# Keep the <72px tier's original budget. Else prefer complete words at
			# 11/10px. Grapheme wrapping is a final two-line fallback when word
			# wrapping would need three lines even at the 10px minimum.
			if minimum_size<10 or not split_word:return result
		if not largest_fit.is_empty():return largest_fit
	return result
