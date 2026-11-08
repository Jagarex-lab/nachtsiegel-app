extends Button
## Original beveled reliquary frame; illustrations are labelled concept placeholders.
const DISPLAY = preload("res://assets/fonts/Display.ttf")
const BODY = preload("res://assets/fonts/Body.ttf")
var data: Dictionary = {}
var active := false
var enemy := false
var compact := false
var heroic := false
var glow := 0.0
var art: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): glow = 1.0; queue_redraw())
	mouse_exited.connect(func(): glow = 0.0; queue_redraw())
	focus_entered.connect(func(): glow = 1.0; queue_redraw())
	focus_exited.connect(func(): glow = 0.0; queue_redraw())

func _text(value: String, at: Vector2, font_size: int, color: Color, serif: bool = false) -> void:
	var font = DISPLAY if serif else BODY
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(at.x-width/2, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _shape(rect: Rect2, cut: float, fill: Color, edge: Color, width: float = 1.0) -> void:
	var p = rect.position
	var s = rect.size
	var points = PackedVector2Array([p+Vector2(cut,0),p+Vector2(s.x-cut,0),p+Vector2(s.x,cut),p+s-Vector2(0,cut),p+s-Vector2(cut,0),p+Vector2(cut,s.y),p+Vector2(0,s.y-cut),p+Vector2(0,cut),p+Vector2(cut,0)])
	draw_colored_polygon(points,fill)
	draw_polyline(points,edge,width,true)

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w < 20 or h < 20: return
	var tint = Color(str(data.get("tint", "#6c9a9d")))
	var gold = Color("#af8e59")
	if active or glow > 0: gold = Color("#f8dc9d")
	if active:
		for i in range(7,0,-1):
			_shape(Rect2(-i,-i,w+i*2,h+i*2),14,Color(0.3,0.9,0.85,0.018),Color(0.4,0.95,0.9,0.12),1)
	_shape(Rect2(3,7,w,h),13,Color(0,0,0,0.65),Color(0,0,0,0))
	_shape(Rect2(0,0,w,h),12,Color("#121b22"),gold,2.5)
	_shape(Rect2(5,5,w-10,h-10),9,Color("#2a3032"),Color("#65543c"),1)
	var art_bottom = h-54 if not compact else h-42
	if art:
		draw_texture_rect(art,Rect2(9,9,w-18,art_bottom-9),false)
	else:
		draw_rect(Rect2(9,9,w-18,art_bottom-9),tint.darkened(0.7))
	# Shadowed nameplate and raised lower metalwork.
	draw_rect(Rect2(8,art_bottom-4,w-16,h-art_bottom-4),Color("#111c24"))
	draw_line(Vector2(9,art_bottom-3),Vector2(w-9,art_bottom-3),gold,1)
	var name_size = 15 if not compact else 14
	var name = str(data.get("name",""))
	while DISPLAY.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > w-18 and name_size > 10:
		name_size -= 1
	_text(name,Vector2(w/2,art_bottom+17),name_size,Color("#f1e7cd"),true)
	_text("KONZEPT",Vector2(w/2,art_bottom-8),8,Color("#d5d9cf"))
	if heroic:
		_text("HELD · KONZEPT",Vector2(w/2,h-10),9,Color("#b8c8bd"))
	elif data.get("kind", "unit") == "spell":
		_text("%d  ZAUBERSCHADEN" % int(data.get("attack",0)),Vector2(w/2,h-11),10,Color("#edc991"))
	else:
		_text("ANG",Vector2(36,h-10),8,Color("#c8ba9b"))
		_text("LP",Vector2(w-33,h-10),8,Color("#c8ba9b"))
		_text(str(data.get("attack",0)),Vector2(16,h-10),19,Color("#f0cf87"))
		_text(str(data.get("hp",0)),Vector2(w-13,h-10),19,Color("#b2e1d9"))
	if not compact:
		var gem = PackedVector2Array([Vector2(19,-7),Vector2(36,10),Vector2(19,32),Vector2(2,10),Vector2(19,-7)])
		draw_colored_polygon(gem,Color("#133b50"))
		draw_polyline(gem,Color("#c4d8d4"),1.5,true)
		_text(str(data.get("cost",0)),Vector2(19,20),22,Color("#e0faff"),true)
	for side in [-1,1]:
		var x = w/2+side*(w/2-3)
		var curve = PackedVector2Array([Vector2(x,27),Vector2(x-side*6,33),Vector2(x-side*5,50),Vector2(x-side*1,60)])
		draw_polyline(curve,gold,1,true)
		draw_line(Vector2(x,38),Vector2(x-side*10,43),gold,1,true)
		draw_line(Vector2(x-side*3,48),Vector2(x-side*9,54),gold,1,true)
	var diamond = PackedVector2Array([Vector2(w/2,1),Vector2(w/2+6,5),Vector2(w/2,9),Vector2(w/2-6,5)])
	draw_colored_polygon(diamond,tint.lightened(0.2))
	for x in [10.0,w-10]:
		for y in [10.0,h-10]:
			draw_circle(Vector2(x,y),2,Color("#ddbd7d"))
	if disabled:
		draw_rect(Rect2(7,7,w-14,h-14),Color(0.02,0.04,0.06,0.38))
