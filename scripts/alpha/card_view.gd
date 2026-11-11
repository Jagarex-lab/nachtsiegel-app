extends Button
const T=preload("res://scripts/ui_tokens.gd")
const S=preload("res://scripts/alpha/style.gd")
const ATLAS=preload("res://assets/art/atlas.png")
const ART=preload("res://scripts/production/art_resolver.gd")
var card: Dictionary={}
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
func illustration(aperture: Rect2, tint: Color=Color.WHITE) -> void:
	var resolved=ART.resolve(card)
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
		draw_line(Vector2(8,4),Vector2(size.x-10,4),Color(edge,.7),1,true)
		if not unit.is_empty() and size.y<72:
			# The narrow battlefield has a name/stat area and a separate status
			# column. Shield and readiness can never disappear behind a long name.
			var status_width=37.0;var name_width=size.x-status_width-14
			illustration(Rect2(size.x-status_width-2,5,status_width-3,maxf(18,size.y-10)),Color(.5,.55,.65))
			title_paragraph(name_width,11,maxf(14,size.y-23)).draw(get_canvas_item(),Vector2(8,4),T.TEXT)
			draw_rect(Rect2(5,size.y-19,size.x-status_width-8,15),T.SURFACE)
			_ink("%d ANG %d LP" % [current_attack(),unit.hp],Vector2(7,size.y-7),11,T.TEXT,name_width)
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
			title_paragraph(size.x-20,12,name_height-4).draw(get_canvas_item(),Vector2(10,7),T.TEXT)
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
			_ink("%d ANG  %d LP" % [current_attack(),unit.hp],Vector2(x,size.y-24),12,T.TEXT,width)
			var marks=board_status()
			_ink("S%d B%d · %s" % [marks.shield,marks.block,marks.ready_short],Vector2(x,size.y-8),10,T.ENERGY,width)
			if not marks.extra_short.is_empty():
				draw_rect(Rect2(6,size.y-21,art_width-2,15),Color(.015,.025,.04,.94))
				_ink(marks.extra_short,Vector2(8,size.y-9),10,T.GOLD,art_width-6)
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
	if target:draw_rect(rect.grow(-3),T.SUCCESS,false,2)
	if invalid_target:
		draw_line(Vector2(size.x-12,7),Vector2(size.x-5,14),T.DANGER,2,true);draw_line(Vector2(size.x-5,7),Vector2(size.x-12,14),T.DANGER,2,true)
	if has_focus():draw_rect(rect.grow(-1),T.FOCUS,false,1)
func large_board_portrait() -> bool:
	return not unit.is_empty() and size.y>=160 and size.x>=170
func tall_board_labels() -> Dictionary:
	var marks=board_status()
	var result={"combat_text":"%d ANG  %d LP" % [current_attack(),unit.get("hp",0)],"status":"Schild %d · Block %d · %s" % [marks.shield,marks.block,marks.ready_short],"value_font":15,"status_font":11}
	for fs in [15,14,13,12]:
		result.value_font=fs
		if S.font.get_string_size(result.combat_text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=size.x-20:break
	for fs in [11,10,9]:
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
func title_paragraph(width: float, maximum_size: int=12, available_height: float=-1) -> TextParagraph:
	maximum_size=mini(maximum_size,title_maximum_size)
	if title_available_height>=0:available_height=minf(available_height,title_available_height) if available_height>=0 else title_available_height
	var paragraph: TextParagraph
	for fs in [12,11,10,9,8]:
		if fs>maximum_size:continue
		paragraph=TextParagraph.new();paragraph.width=maxf(24,width)
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		paragraph.add_string(str(card.get("name",card.get("id",""))),S.font,fs)
		if paragraph.get_line_count()<=2 and (available_height<0 or paragraph.get_size().y<=available_height):break
	return paragraph
