extends Button
## Sculpted illustrated reliquary. Artwork remains explicitly marked as concept art.
const DISPLAY = preload("res://assets/fonts/Cinzel.ttf")
const BODY = preload("res://assets/fonts/Body.ttf")
const FRAME = preload("res://assets/art/reliquary_frame.png")
const HERO_FRAME = preload("res://assets/art/hero_medallion.png")
var data: Dictionary = {}
var active := false
var enemy := false
var compact := false
var heroic := false
var unaffordable := false
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
	var position_text = Vector2(at.x-width/2, at.y)
	draw_string(font,position_text+Vector2(1,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,0.95))
	draw_string(font,position_text,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _portrait(points: PackedVector2Array, bounds: Rect2, modulation: Color = Color.WHITE) -> void:
	if art == null: return
	var uvs = PackedVector2Array()
	var texture: Texture2D = art
	for point in points:
		var uv = ((point-bounds.position)/bounds.size).clamp(Vector2.ZERO,Vector2.ONE)
		if art is AtlasTexture:
			uv = (art.region.position+uv*art.region.size)/art.atlas.get_size()
		uvs.append(uv)
	if art is AtlasTexture: texture = art.atlas
	draw_polygon(points,PackedColorArray([modulation]),uvs,texture)

func _hero() -> void:
	var w = size.x
	var h = size.y
	var center = Vector2(w*.5,h*.43)
	var radii = Vector2(w*.34,h*.29)
	draw_texture_rect(HERO_FRAME,Rect2(4,7,w,h),false,Color(0,0,0,.8))
	var points = PackedVector2Array()
	for i in 72: points.append(center+Vector2(cos(TAU*i/72.0),sin(TAU*i/72.0))*radii)
	_portrait(points,Rect2(center-radii,radii*2))
	draw_texture_rect(HERO_FRAME,Rect2(Vector2.ZERO,size),false)
	var name_size = 14
	var name = str(data.get("name",""))
	while DISPLAY.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > w*.74 and name_size > 9: name_size -= 1
	_text(name,Vector2(w/2,h*.755),name_size,Color("#f0d8ae"),true)
	_text("KONZEPT",Vector2(w/2,h*.66),7,Color("#d6d5c4"))

func _draw() -> void:
	if size.x < 20 or size.y < 20: return
	if heroic:
		_hero()
		return
	var w = size.x
	var h = size.y
	var accent = Color(str(data.get("tint","#86bbb4")))
	if active or glow > 0:
		for i in range(7,0,-1):
			draw_texture_rect(FRAME,Rect2(-i,-i,w+i*2,h+i*2),false,Color(accent.r,accent.g,accent.b,0.12))
	draw_texture_rect(FRAME,Rect2(5,8,w,h),false,Color(0,0,0,0.85))
	var aperture = PackedVector2Array([Vector2(.08,.14),Vector2(.20,.08),Vector2(.40,.06),Vector2(.50,.09),Vector2(.60,.06),Vector2(.80,.09),Vector2(.92,.14),Vector2(.91,.68),Vector2(.86,.72),Vector2(.14,.72),Vector2(.09,.68)])
	for i in aperture.size(): aperture[i] *= size
	_portrait(aperture,Rect2(w*.08,h*.08,w*.84,h*.64),Color(.65,.65,.65,1) if unaffordable else Color.WHITE)
	draw_texture_rect(FRAME,Rect2(Vector2.ZERO,size),false,Color(.74,.74,.78,1) if unaffordable else Color.WHITE)
	var name = str(data.get("name",""))
	var name_size = int((16 if compact else 15)*w/156.0)
	while DISPLAY.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > w*.79 and name_size > int(10*w/156.0): name_size -= 1
	_text(name,Vector2(w*.5,h*.80),name_size,Color("#f7e8c8"),true)
	_text("KONZEPT",Vector2(w*.5,h*.855),int((7 if compact else 8)*w/156.0),Color("#d6c8ad"))
	_text(str(data.get("cost",0)),Vector2(w*.12,h*.163),int(24*w/156.0),Color("#e5f7ff"),true)
	if data.get("kind","unit") == "spell":
		_text(str(data.get("attack",0)),Vector2(w*.17,h*.945),int(23*w/156.0),Color("#ffe0a2"),true)
		_text("ZAUBER",Vector2(w*.70,h*.94),int(10*w/156.0),Color("#e5d4b2"))
	else:
		_text(str(data.get("attack",0)),Vector2(w*.17,h*.945),int(23*w/156.0),Color("#ffe0a2"),true)
		_text(str(data.get("hp",0)),Vector2(w*.84,h*.945),int(23*w/156.0),Color("#ddf7d4"),true)
	if active:
		draw_line(Vector2(w*.26,h*.875),Vector2(w*.74,h*.875),accent.lightened(.3),2,true)
	if disabled:
		draw_texture_rect(FRAME,Rect2(Vector2.ZERO,size),false,Color(.02,.04,.06,.4))
