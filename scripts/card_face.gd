extends Button
## Sculpted illustrated reliquary. Artwork remains explicitly marked as concept art.
const T = preload("res://scripts/ui_tokens.gd")
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
var ghost_display := false
var art: Texture2D
var view_scale := .8
var playable := false
var target_state := "none"
var contrast_regions: Array = []

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): glow = 1.0; queue_redraw())
	mouse_exited.connect(func(): glow = 0.0; queue_redraw())
	focus_entered.connect(func(): glow = 1.0; queue_redraw())
	focus_exited.connect(func(): glow = 0.0; queue_redraw())

func contrast_samples() -> Array: return contrast_regions

func _text(value: String, at: Vector2, font_size: int, color: Color, serif: bool = false, role: String = "card text") -> void:
	var font = DISPLAY if serif else BODY
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var rect = Rect2(at.x-width/2,at.y-font.get_ascent(font_size),width,font.get_height(font_size))
	draw_rect(rect.grow(2),T.SURFACE)
	contrast_regions.append(T.sample(rect,color,role))
	if T.ink_visible: draw_string(font,Vector2(at.x-width/2,at.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _badge(center: Vector2, number: String, role: String, color: Color, shape: String) -> void:
	var fs = T.font_size(30,view_scale,12)
	var extent = maxi(38,int(fs*1.18))
	var rect = Rect2(center-Vector2(extent,extent)/2,Vector2(extent,extent))
	var points = PackedVector2Array()
	if shape == "cost":
		for i in 7: points.append(center+Vector2(cos(TAU*i/6.0),sin(TAU*i/6.0))*extent*.53)
	elif shape == "attack":
		points = PackedVector2Array([rect.position+Vector2(0,6),rect.position+Vector2(extent,0),rect.end-Vector2(0,6),rect.position+Vector2(0,extent),rect.position+Vector2(0,6)])
	else:
		points = PackedVector2Array([rect.position,rect.position+Vector2(extent,0),rect.end-Vector2(0,9),rect.position+Vector2(extent/2,extent+3),rect.position+Vector2(0,extent-9),rect.position])
	draw_colored_polygon(points,T.SURFACE)
	draw_polyline(points,T.INK,8,true)
	if T.ink_visible: draw_polyline(points,color,2,true)
	_text(number,center+Vector2(0,fs*.35),fs,T.TEXT,false,role)

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
	if glow > 0 or has_focus(): draw_texture_rect(HERO_FRAME,Rect2(-3,-3,w+6,h+6),false,Color(T.FOCUS,.4))
	draw_texture_rect(HERO_FRAME,Rect2(4,7,w,h),false,Color(0,0,0,.8))
	var points = PackedVector2Array()
	for i in 72: points.append(center+Vector2(cos(TAU*i/72.0),sin(TAU*i/72.0))*radii)
	_portrait(points,Rect2(center-radii,radii*2))
	draw_texture_rect(HERO_FRAME,Rect2(Vector2.ZERO,size),false)
	# Identity text is deliberately in the readable hero inspector, not 5px microtype.

func _draw() -> void:
	contrast_regions.clear()
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
	if ghost_display: return
	var name = str(data.get("name",""))
	var name_size = int(17*w/156.0)
	while DISPLAY.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > w*.80 and name_size > int(11*w/156.0): name_size -= 1
	draw_rect(Rect2(w*.075,h*.69,w*.85,h*.125),T.SURFACE)
	_text(name,Vector2(w*.5,h*.775),name_size,T.TEXT,true,"card name (focus available)")
	_badge(Vector2(w*.13,h*.16),str(data.get("cost",0)),"energy cost",T.ENERGY,"cost")
	_badge(Vector2(w*.18,h*.90),str(data.get("attack",0)),"attack or spell damage",T.GOLD,"attack")
	if data.get("kind","unit") != "spell":
		_badge(Vector2(w*.82,h*.90),str(data.get("hp",0)),"health",T.DANGER,"health")
	else:
		draw_rect(Rect2(w*.43,h*.865,w*.5,h*.1),T.SURFACE)
		_text("ZAUBER",Vector2(w*.68,h*.938),int(14*w/156.0),T.ENERGY,false,"spell type")
	var edge = T.FOE if enemy else T.PLAYER
	if glow > 0 or has_focus(): edge = T.FOCUS
	if active: edge = T.GOLD
	if target_state == "valid": edge = T.SUCCESS
	elif target_state == "invalid": edge = T.WARNING
	var frame = PackedVector2Array([Vector2(12,3),Vector2(w-12,3),Vector2(w-3,12),Vector2(w-3,h-12),Vector2(w-12,h-3),Vector2(12,h-3),Vector2(3,h-12),Vector2(3,12),Vector2(12,3)])
	draw_polyline(frame,T.INK,8,true)
	if T.ink_visible: draw_polyline(frame,edge,2.5 if not active else 6,true)
	contrast_regions.append(T.sample(Rect2(w*.35,1,w*.3,4),edge,"card boundary",3))
	var status_mark = "✓" if playable else ("!" if unaffordable else "")
	if active and not unaffordable: status_mark = "●"
	if target_state == "valid": status_mark = "✓"
	elif target_state == "invalid": status_mark = "×"
	if disabled: status_mark = "–"
	if not status_mark.is_empty():
		var fs = T.font_size(25,view_scale,11)
		var rect = Rect2(w-48,5,43,maxf(43,fs*1.3+4))
		draw_rect(rect,T.SURFACE)
		_text(status_mark,rect.position+Vector2(21.5,fs),fs,T.WARNING if unaffordable else (T.GOLD if active else (T.SUCCESS if playable else edge)),false,"card status")
