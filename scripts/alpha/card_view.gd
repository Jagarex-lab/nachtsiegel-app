extends Button
const T=preload("res://scripts/ui_tokens.gd")
const S=preload("res://scripts/alpha/style.gd")
const ATLAS=preload("res://assets/art/atlas.png")
const ART=preload("res://scripts/production/art_resolver.gd")
var card: Dictionary={}
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
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _ink(value: String, at: Vector2, fs: int, tint: Color, width: float) -> void:
	draw_string(S.font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,tint)
func _process(_delta: float) -> void:
	var visible_now: bool = not card.is_empty() and ART.visible_owner(self)
	if _delivery_card_id != str(card.get("id", "")) or _delivery_profile != art_profile or not visible_now:
		ART.release_owner(self); _delivery_card_id = ""; _delivery_profile = ""
	if visible_now:
		if not _delivery_visible or _delivery_card_id.is_empty(): _illustration_binding = ""
		if ART.binding_key(card, art_profile) != _illustration_binding: queue_redraw()
	_delivery_visible = visible_now
func _exit_tree() -> void: ART.release_owner(self)
func art_report() -> Dictionary:
	# Observe the actual bound pixels; never resolve/load/request through QA.
	var texture: Texture2D = _illustration_data.get("texture")
	return {"card_id": str(card.get("id", "")), "visible": ART.visible_owner(self), "status": str(_illustration_data.get("status", "unbound")), "pixels": [texture.get_width(), texture.get_height()] if texture != null else [], "pending": bool(_illustration_data.get("preview_pending", true)), "profile": str(_illustration_data.get("profile", art_profile)), "delivery_state": str(_illustration_data.get("delivery_state", "unbound"))}
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
func _draw() -> void:
	var rect=Rect2(Vector2(2,2),size-Vector2(4,4))
	var edge=T.GOLD if selected or convergence else T.SUCCESS if target else color
	if card.is_empty():
		var center=size/2.0;var radius=minf(size.y*.29,24)
		draw_circle(center,radius+3,Color(.02,.04,.07,.8))
		draw_arc(center,radius,0,TAU,40,edge if target else Color(edge,.45),2,true)
		_ink(str(lane+1),center+Vector2(-4,4),15,T.TEXT,30)
		_ink(owner_label+" · FREI",Vector2(size.x/2-24,size.y-4),10,T.SECONDARY,65)
		if origin:_ink("U",Vector2(size.x/2-radius-12,16),12,T.GOLD,20)
	else:
		draw_style_box(T.panel(edge,Color(.025,.04,.065,.88)),rect)
		if not unit.is_empty() and size.y<72:
			# The narrow battlefield has a name/stat area and a separate status
			# column. Shield and readiness can never disappear behind a long name.
			var status_width=37.0;var name_width=size.x-status_width-14
			illustration(Rect2(size.x-status_width-2,5,status_width-3,maxf(18,size.y-10)),Color(.5,.55,.65))
			title_paragraph(name_width,11,maxf(14,size.y-23),8).draw(get_canvas_item(),Vector2(8,4),T.TEXT)
			draw_rect(Rect2(5,size.y-19,size.x-status_width-8,15),T.SURFACE)
			var combat=compact_combat_labels(name_width-(21 if lane>=0 else 0),11)
			_ink(combat.text,Vector2(28 if lane>=0 else 7,size.y-7),combat.font_size,T.TEXT,combat.available_width)
			if lane>=0:_path_badge(Rect2(7,size.y-18,16,14),edge)
			var marks=board_status()
			draw_rect(Rect2(size.x-status_width-3,5,status_width,size.y-10),Color(.015,.025,.04,.92))
			var ready_caption=marks.ready_short+(" U" if origin else "")+(" K" if convergence else " ×" if broken_convergence else "")
			_ink(ready_caption,Vector2(size.x-status_width,15),8 if ready_caption.length()>5 else 10,T.SUCCESS if combat_ready else T.WARNING,status_width-3)
			var shield_caption="S%d B%d" % [marks.shield,marks.block]
			var shield_font=10
			while shield_font>8 and S.font.get_string_size(shield_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,shield_font).x>status_width-3:shield_font-=1
			_ink(shield_caption,Vector2(size.x-status_width,28),shield_font,T.ENERGY,status_width-3)
			if size.y>=48:_ink(marks.extra_short,Vector2(size.x-status_width,size.y-8),10,T.GOLD,status_width-3)
		elif not unit.is_empty() and large_board_portrait():
			# Tall desktop/tablet slots need an actual portrait surface. A fixed
			# 66px side strip wasted most of a 300px-wide battlefield creature.
			illustration(Rect2(5,5,size.x-10,size.y-10))
			var name_height=36.0
			draw_rect(Rect2(5,5,size.x-10,name_height),Color(.015,.025,.045,.96))
			title_paragraph(board_title_width(),12,name_height-4).draw(get_canvas_item(),Vector2(10,7),T.TEXT)
			if lane>=0:_path_badge(Rect2(size.x-28,9,19,20),edge)
			var info_y=size.y-52
			draw_colored_polygon(PackedVector2Array([Vector2(5,info_y+6),Vector2(size.x-5,info_y-7),Vector2(size.x-5,size.y-5),Vector2(5,size.y-5)]),T.SURFACE)
			draw_line(Vector2(5,info_y+6),Vector2(size.x-5,info_y-7),Color(edge,.85),2,true)
			var labels=tall_board_labels()
			_ink(labels.combat_text,Vector2(10,size.y-27),labels.value_font,T.TEXT,size.x-20)
			var marks=board_status()
			_ink(labels.status,Vector2(10,size.y-10),labels.status_font,T.ENERGY,size.x-20)
			if not marks.extra_short.is_empty():
				var badge_width=minf(size.x-20,maxf(34,S.font.get_string_size(marks.extra_short,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+12))
				draw_style_box(T.panel(edge,T.SURFACE),Rect2(9,45,badge_width,22))
				_ink(marks.extra_short,Vector2(15,60),11,T.GOLD,badge_width-10)
		elif not unit.is_empty():
			# Portrait, complete compact nameplate and permanent combat values.
			var art_width=minf(66,size.x*.35)
			illustration(Rect2(5,5,art_width,size.y-10))
			var x=art_width+10;var width=size.x-x-7
			title_paragraph(width,12,maxf(20,size.y-47)).draw(get_canvas_item(),Vector2(x,4),T.TEXT)
			var combat=compact_combat_labels(width)
			_ink(combat.text,Vector2(x,size.y-24),combat.font_size,T.TEXT,combat.available_width)
			var marks=board_status()
			var labels=compact_board_labels()
			draw_rect(Rect2(5,size.y-21,size.x-10,17),T.SURFACE)
			_ink(labels.status,Vector2(8,size.y-8),labels.font_size,T.ENERGY,labels.available_width)
			if lane>=0:_path_badge(Rect2(8,7,18,17),edge)
			var ready_x=29.0 if lane>=0 else 8.0
			draw_rect(Rect2(ready_x-1,7,art_width+5-ready_x,17),Color(.015,.025,.04,.96))
			_ink(marks.ready_short,Vector2(ready_x,19),10,T.SUCCESS if combat_ready else T.WARNING,art_width+4-ready_x)
			if not marks.extra_short.is_empty():
				draw_rect(Rect2(6,size.y-39,art_width-2,16),Color(.015,.025,.04,.94))
				_ink(marks.extra_short,Vector2(8,size.y-27),10,T.GOLD,art_width-6)
		else:
			illustration(Rect2(5,5,size.x-10,size.y-10),Color(.8,.85,.9))
			draw_rect(Rect2(5,5,size.x-10,32),Color(.025,.04,.065,.94))
			title_paragraph(size.x-16).draw(get_canvas_item(),Vector2(8,5),T.TEXT)
			var bottom=60 if library else 20
			draw_rect(Rect2(5,size.y-bottom-4,size.x-10,bottom),T.SURFACE)
			var stats=stat_layout(size.x-45)
			_ink(stats.text,Vector2(8,size.y-10),stats.font_size,T.TEXT,stats.available_width)
			draw_circle(Vector2(size.x-16,size.y-15),13,T.INK)
			_ink(str(int(card.cost)),Vector2(size.x-21,size.y-10),15,T.ENERGY,24)
			if library:
				var caption=TextParagraph.new();caption.width=size.x-16;caption.add_string(S.caption(card),S.font,11);caption.draw(get_canvas_item(),Vector2(8,size.y-59),color)
		if card.get("rarity")=="legendary":draw_colored_polygon(PackedVector2Array([Vector2(3,size.y*.4),Vector2(6,size.y*.4-5),Vector2(9,size.y*.4),Vector2(6,size.y*.4+5)]),T.GOLD)
		elif card.get("rarity")=="rare":
			for offset in [-4,4]:draw_circle(Vector2(3,size.y*.4+offset),2,color)
		elif card.get("rarity")=="epic":draw_line(Vector2(3,16),Vector2(3,size.y-16),color,3)
		_material_frame(edge)
	if target:draw_rect(rect.grow(-3),T.SUCCESS,false,2)
	if invalid_target:
		draw_line(Vector2(size.x-12,7),Vector2(size.x-5,14),T.DANGER,2,true);draw_line(Vector2(size.x-5,7),Vector2(size.x-12,14),T.DANGER,2,true)
	if has_focus():draw_rect(rect.grow(-1),T.FOCUS,false,1)
func _material_frame(edge: Color) -> void:
	# All bevel ink stays inside the existing frame; hit areas and layout do not
	# change. State/focus outlines are drawn afterwards and remain dominant.
	var light=T.STONE_LIGHT.lerp(T.BRONZE,.35).lerp(edge,.2)
	draw_line(Vector2(5,4),Vector2(size.x-5,4),Color(light,.9),1,true)
	draw_line(Vector2(4,5),Vector2(4,size.y-5),Color(light,.7),1,true)
	draw_line(Vector2(5,size.y-5),Vector2(size.x-5,size.y-5),Color(T.INK,.9),1,true)
	draw_line(Vector2(size.x-5,5),Vector2(size.x-5,size.y-5),Color(T.INK,.9),1,true)
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
