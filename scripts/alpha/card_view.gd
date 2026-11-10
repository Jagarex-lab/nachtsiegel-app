extends Button
const T=preload("res://scripts/ui_tokens.gd")
const S=preload("res://scripts/alpha/style.gd")
const ATLAS=preload("res://assets/art/atlas.png")
var card: Dictionary={}
var unit: Dictionary={}
var selected := false
var target := false
var invalid_target := false
var color=Color("79ddd4")
var lane := -1
var origin := false
var combat_ready := false
var convergence := false
var broken_convergence := false
var library := false
var owner_label := ""
func _ready() -> void:
	for key in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _ink(value: String, at: Vector2, fs: int, tint: Color, width: float) -> void:
	draw_string(S.font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,tint)
func illustration(aperture: Rect2, tint: Color=Color.WHITE) -> void:
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
			# Browser-height view: full-width stats and a separate name area.
			# Two-line names must never intersect the values below them.
			illustration(Rect2(size.x-40,5,35,maxf(18,size.y-25)))
			title_paragraph(size.x-54,11).draw(get_canvas_item(),Vector2(8,4),T.TEXT)
			draw_rect(Rect2(5,size.y-19,size.x-10,15),T.SURFACE)
			var marks=("✓" if combat_ready else "Z" if int(unit.get("stun",0))>0 else "…")+(" U" if origin else "")+(" K" if convergence else " K×" if broken_convergence else "")
			if int(unit.get("ward",0))>0:marks+=" S%d" % int(unit.ward)
			_ink("%s %d ANG %d LP %s" % [owner_label,unit.atk,unit.hp,marks],Vector2(7,size.y-7),11,T.TEXT,size.x-14)
		elif not unit.is_empty():
			# Board units are portraits + a readable nameplate, not compressed full cards.
			var art_width=minf(66,size.x*.35)
			illustration(Rect2(5,5,art_width,size.y-10))
			var x=art_width+10;var width=size.x-x-7
			title_paragraph(width).draw(get_canvas_item(),Vector2(x,4),T.TEXT)
			_ink("%d ANG  %d LP" % [unit.atk,unit.hp],Vector2(x,size.y-23),12,T.TEXT,width)
			var marks=owner_label+" "+("✓" if combat_ready else "Z" if int(unit.get("stun",0))>0 else "…")+(" U" if origin else "")+(" K" if convergence else " K×" if broken_convergence else "")
			if int(unit.get("ward",0))>0:marks+=" S%d" % int(unit.ward)
			_ink(marks,Vector2(x,size.y-7),10,T.GOLD,width)
		else:
			illustration(Rect2(5,5,size.x-10,size.y-10),Color(.8,.85,.9))
			draw_rect(Rect2(5,5,size.x-10,32),Color(.025,.04,.065,.94))
			title_paragraph(size.x-16).draw(get_canvas_item(),Vector2(8,5),T.TEXT)
			var bottom=60 if library else 20
			draw_rect(Rect2(5,size.y-bottom-4,size.x-10,bottom),T.SURFACE)
			var stats="%d ANG   %d LP" % [card.get("atk",0),card.get("hp",0)] if card.kind=="creature" else S.KINDS.get(card.kind,card.kind)
			_ink(stats,Vector2(8,size.y-10),13,T.TEXT,size.x-45)
			draw_circle(Vector2(size.x-16,size.y-15),13,T.INK)
			_ink(str(int(card.cost)),Vector2(size.x-21,size.y-10),15,T.ENERGY,24)
			if library:
				var caption=TextParagraph.new();caption.width=size.x-16;caption.add_string(S.caption(card),S.font,11);caption.draw(get_canvas_item(),Vector2(8,size.y-59),color)
		if card.get("rarity")=="legendary":draw_colored_polygon(PackedVector2Array([Vector2(0,size.y*.4),Vector2(3,size.y*.4-5),Vector2(6,size.y*.4),Vector2(3,size.y*.4+5)]),T.GOLD)
		elif card.get("rarity")=="rare":
			for offset in [-4,4]:draw_circle(Vector2(3,size.y*.4+offset),2,color)
		elif card.get("rarity")=="epic":draw_line(Vector2(3,16),Vector2(3,size.y-16),color,3)
	if target:draw_rect(rect.grow(-3),T.SUCCESS,false,2)
	if invalid_target:
		draw_line(Vector2(size.x-12,7),Vector2(size.x-5,14),T.DANGER,2,true);draw_line(Vector2(size.x-5,7),Vector2(size.x-12,14),T.DANGER,2,true)
	if has_focus():draw_rect(rect.grow(-1),T.FOCUS,false,1)
func title_paragraph(width: float, maximum_size: int=12) -> TextParagraph:
	var paragraph: TextParagraph
	for fs in [12,11,10]:
		if fs>maximum_size:continue
		paragraph=TextParagraph.new();paragraph.width=maxf(24,width)
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		paragraph.add_string(str(card.get("name",card.get("id",""))),S.font,fs)
		if paragraph.get_line_count()<=2:break
	return paragraph
