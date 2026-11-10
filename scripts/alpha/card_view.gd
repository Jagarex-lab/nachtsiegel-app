extends Button
const T=preload("res://scripts/ui_tokens.gd")
const ATLAS=preload("res://assets/art/atlas.png")
var card: Dictionary={}
var unit: Dictionary={}
var selected := false
var target := false
var color=Color("79ddd4")
var lane := -1
func _ready() -> void:
	for key in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _ink(text_value: String, at: Vector2, fs: int, tint: Color, width: float) -> void:
	draw_string(T.FONT,at,text_value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,tint)
func _draw() -> void:
	var rect=Rect2(Vector2(2,2),size-Vector2(4,4))
	var edge=T.GOLD if selected else T.SUCCESS if target else color
	if card.is_empty():
		var center=size/2.0
		var radius=minf(size.y*.36,size.x*.28)
		draw_circle(center,radius+5,Color(.02,.04,.08,.7))
		draw_arc(center,radius,0,TAU,48,edge if target or selected else Color(edge,.35),2,true)
		draw_arc(center,radius+4,-PI*.8,PI*.2,32,Color(edge,.45),1,true)
		for i in 4:
			var at=center+Vector2(cos(PI*i/2),sin(PI*i/2))*radius
			draw_line(at-Vector2(2,2),at+Vector2(2,2),edge,1,true)
		_ink(str(lane+1),center+Vector2(-4,5),14,T.SECONDARY,30)
		if color==T.GOLD:_ink("URSPRUNG",Vector2(7,size.y-6),12,T.GOLD,size.x-14)
	else:
		draw_style_box(T.panel(edge,Color("101a27")),rect)
		var cell=ATLAS.get_size()/3.0
		var index=absi(str(card.id).hash())%7
		var source=Rect2(Vector2(index%3,floori(float(index)/3))*cell,cell)
		var aperture=Rect2(5,5,size.x-10,maxf(12,size.y-30))
		var aspect=aperture.size.x/aperture.size.y
		if aspect>1:
			source.position.y+=cell.y*(1-1/aspect)*.38;source.size.y=cell.y/aspect
		else:
			source.position.x+=cell.x*(1-aspect)/2;source.size.x=cell.x*aspect
		draw_texture_rect_region(ATLAS,aperture,source,Color(.82,.87,.94))
		draw_rect(Rect2(5,5,size.x-10,20),Color(0.02,.04,.08,.9))
		_ink(str(card.get("name",card.id)),Vector2(9,19),12,T.TEXT,size.x-(48 if size.y<80 else 18))
		draw_rect(Rect2(5,size.y-27,size.x-10,22),T.SURFACE)
		var stats: String=("ANG %d   LP %d" % [unit.get("atk",card.get("atk",0)),unit.get("hp",card.get("hp",0))]) if card.kind=="creature" else str(card.kind).to_upper()
		_ink(stats,Vector2(9,size.y-10),13,T.TEXT,size.x-18)
		if unit.is_empty():
			draw_circle(Vector2(size.x-17,15 if size.y<80 else 35),13,T.INK)
			_ink(str(int(card.cost)),Vector2(size.x-22,20 if size.y<80 else 40),15,T.ENERGY,24)
		else:
			var status=""
			if int(unit.get("ward",0))>0:status+=" ◇"+str(int(unit.ward))
			if int(unit.get("stun",0))>0:status+=" STASIS"
			elif unit.get("summoned",false):status+=" EILE" if card.effect=="haste" else " BEREITET VOR"
			if size.y<80:
				if int(unit.get("stun",0))>0:status="Zzz"
				elif unit.get("summoned",false):status="EILE" if card.effect=="haste" else "NEU"
				else:status="◇"+str(int(unit.ward)) if int(unit.get("ward",0))>0 else ""
				_ink(status,Vector2(size.x-42,17),12,T.GOLD,38)
			else:_ink(status,Vector2(6,37),12,T.GOLD,size.x-12)
	if target:draw_rect(rect.grow(-3),T.SUCCESS,false,2)
