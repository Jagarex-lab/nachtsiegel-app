extends Button
## Shared cut-metal hand frame, sculpted creature seal and hero medallion.
const T = preload("res://scripts/ui_tokens.gd")
const DISPLAY = preload("res://assets/fonts/Cinzel.ttf")
const FRAME = preload("res://assets/art/reliquary_frame.png")
const BODY = preload("res://assets/fonts/Body.ttf")
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
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(func(): glow = 1; queue_redraw())
	mouse_exited.connect(func(): glow = 0; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
func contrast_samples() -> Array: return contrast_regions
func _text(value: String, at: Vector2, fs: int, color: Color, serif: bool = false, role: String = "card text") -> void:
	var font = DISPLAY if serif else BODY
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var rect = Rect2(at.x-width/2,at.y-font.get_ascent(fs),width,font.get_height(fs))
	draw_rect(rect.grow(2),T.SURFACE)
	contrast_regions.append(T.sample(rect,color,role))
	if T.ink_visible: draw_string(font,Vector2(at.x-width/2,at.y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)
func _badge(center: Vector2, number: String, role: String, hue: Color, shape: String) -> void:
	var fs = T.font_size(30,view_scale,12)
	var e = maxf(36,fs*1.18)
	var r = Rect2(center-Vector2(e,e)/2,Vector2(e,e))
	var p = PackedVector2Array()
	if shape == "cost":
		for i in 7: p.append(center+Vector2(cos(TAU*i/6),sin(TAU*i/6))*e*.55)
	elif shape == "attack": p = PackedVector2Array([r.position+Vector2(0,6),r.position+Vector2(e,0),r.end-Vector2(0,6),r.position+Vector2(0,e),r.position+Vector2(0,6)])
	else: p = PackedVector2Array([r.position,r.position+Vector2(e,0),r.end-Vector2(0,8),r.position+Vector2(e/2,e+2),r.position+Vector2(0,e-8),r.position])
	draw_colored_polygon(p,T.SURFACE)
	draw_polyline(p,T.INK,8,true)
	if T.ink_visible: draw_polyline(p,hue,2.5,true)
	_text(number,center+Vector2(0,fs*.27),fs,T.TEXT,false,role)
func _portrait(points: PackedVector2Array, bounds: Rect2, modulation: Color = Color.WHITE) -> void:
	if art == null: return
	var uv_points = PackedVector2Array()
	var texture = art.atlas if art is AtlasTexture else art
	for point in points:
		var uv = ((point-bounds.position)/bounds.size).clamp(Vector2.ZERO,Vector2.ONE)
		# Cover the aperture without stretching faces and creatures.
		var aspect = bounds.size.x/bounds.size.y
		if aspect > 1: uv.y = (uv.y-.5)/aspect+.5
		else: uv.x = (uv.x-.5)*aspect+.5
		if art is AtlasTexture: uv = (art.region.position+uv*art.region.size)/art.atlas.get_size()
		uv_points.append(uv)
	draw_polygon(points,PackedColorArray([modulation]),uv_points,texture)
func _circle(at: Vector2, radii: Vector2) -> PackedVector2Array:
	var p = PackedVector2Array()
	for i in 65: p.append(at+Vector2(cos(TAU*i/64),sin(TAU*i/64))*radii)
	return p
func _edge() -> Color:
	if disabled: return T.MUTED
	if target_state == "valid": return T.SUCCESS
	if target_state == "invalid": return T.WARNING
	if active: return T.GOLD
	if glow > 0 or has_focus(): return T.FOCUS
	return T.FOE if enemy else T.PLAYER
func _faction(at: Vector2, radius: float) -> void:
	var sigil = str(data.get("sigil","ASH"))
	var hue = T.SECONDARY
	draw_circle(at,radius+3,T.INK)
	draw_circle(at,radius,T.SURFACE)
	contrast_regions.append(T.sample(Rect2(at-Vector2.ONE*radius*.5,Vector2.ONE*radius),hue,"faction symbol",3))
	if not T.ink_visible: return
	var r = radius*.62
	if sigil == "TIDE":
		for y in [-r,0,r]: draw_line(at+Vector2(-r,y),at+Vector2(r,y),hue,2,true)
	elif sigil == "THORN":
		draw_line(at+Vector2(0,r),at+Vector2(0,-r),hue,2,true)
		draw_line(at,at+Vector2(-r,-r),hue,2,true); draw_line(at,at+Vector2(r,-r),hue,2,true)
	elif sigil == "VEIL":
		for x in [-r*.5,r*.5]: draw_line(at+Vector2(x,-r),at+Vector2(x,r),hue,2,true)
	elif sigil == "SPELL":
		draw_polyline(PackedVector2Array([at+Vector2(3,-r),at+Vector2(-r*.5,0),at+Vector2(r*.5,0),at+Vector2(-3,r)]),hue,2,true)
	else:
		draw_polyline(PackedVector2Array([at+Vector2(-r*.7,r),at+Vector2(-r*.7,-r),at+Vector2(r*.7,-r),at+Vector2(r*.7,r)]),hue,2,true)
func _medallion(hero: bool = false) -> void:
	var c = Vector2(size.x/2,size.y*(.45 if hero else .38))
	var radius = minf(size.x*.43,size.y*(.40 if hero else .38))
	var ring = _circle(c,Vector2.ONE*radius)
	var shadow = _circle(c+T.SHADOW_OFFSET,Vector2.ONE*(radius+7))
	draw_colored_polygon(shadow,Color(0,0,0,.7))
	draw_colored_polygon(ring,T.SURFACE_RAISED)
	_portrait(_circle(c,Vector2.ONE*(radius-7)),Rect2(c-Vector2.ONE*(radius-7),Vector2.ONE*(radius-7)*2))
	draw_polyline(ring,T.INK,12,true)
	if T.ink_visible: draw_polyline(ring,_edge(),3.5,true)
	draw_arc(c,radius+4,PI*1.05,PI*1.75,48,T.BRONZE,3,true)
	draw_arc(c,radius+7,PI*1.12,PI*1.65,48,T.STONE_LIGHT.lightened(.45),1.5,true)
	contrast_regions.append(T.sample(Rect2(c.x+radius-1,c.y-2,2,4),_edge(),"hero boundary" if hero else "creature boundary",3))
	if not hero:
		if ghost_display: return
		_badge(Vector2(size.x*.23,size.y*.86),str(data.get("attack",0)),"attack",T.GOLD,"attack")
		_badge(Vector2(size.x*.77,size.y*.86),str(data.get("hp",0)),"health",T.DANGER,"health")
		_faction(Vector2(size.x*.5,size.y*.86),13)
func _draw() -> void:
	contrast_regions.clear()
	if size.x < 20: return
	tooltip_text = str(data.get("name",""))+" · Antippen: Details"
	if heroic: _medallion(true); return
	if compact: _medallion(); _status(Vector2(size.x*.79,25)); return
	var w = size.x
	var h = size.y
	var outline = PackedVector2Array([Vector2(12,3),Vector2(w-12,3),Vector2(w-3,12),Vector2(w-3,h-12),Vector2(w-12,h-3),Vector2(12,h-3),Vector2(3,h-12),Vector2(3,12),Vector2(12,3)])
	var shadow = PackedVector2Array()
	for p in outline: shadow.append(p+T.SHADOW_OFFSET)
	draw_colored_polygon(shadow,Color(0,0,0,.78))
	draw_colored_polygon(outline,T.SURFACE_RAISED)
	var aperture = PackedVector2Array([Vector2(11,13),Vector2(w-11,13),Vector2(w-11,h*.65),Vector2(11,h*.65)])
	_portrait(aperture,Rect2(11,13,w-22,h*.65-13),Color(.57,.6,.64,1) if unaffordable else Color.WHITE)
	draw_texture_rect(FRAME,Rect2(Vector2.ZERO,size),false,Color(.67,.72,.75,.85))
	draw_polyline(outline,T.INK,10,true)
	if T.ink_visible: draw_polyline(outline,_edge(),5 if active else 2.5,true)
	draw_line(Vector2(15,9),Vector2(w-15,9),T.BRONZE,2,true)
	draw_line(Vector2(w-10,15),Vector2(w-10,h-15),T.INK,3,true)
	contrast_regions.append(T.sample(Rect2(2,h*.44,3,5),_edge(),"card boundary",3))
	if ghost_display: return
	var name = str(data.get("name",""))
	var fs = T.font_size(20,view_scale,12)
	while BODY.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x > w-20 and name.length()>3: name = name.left(-2)+"…"
	_text(name,Vector2(w/2,h*.72),fs,T.TEXT,false,"card name (focus available)")
	_badge(Vector2(27,30),str(data.get("cost",0)),"energy cost",T.ENERGY,"cost")
	_badge(Vector2(w*.22,h*.91),str(data.get("attack",0)),"attack or spell damage",T.GOLD,"attack")
	if data.get("kind","unit") == "spell":
		_text("ZAUBER",Vector2(w*.68,h*.94),T.font_size(17,view_scale,11),T.ENERGY,false,"spell type")
	else: _badge(Vector2(w*.78,h*.91),str(data.get("hp",0)),"health",T.DANGER,"health")
	_faction(Vector2(w-27,28),14)
	_status(Vector2(w-26,h*.45))
func _status(at: Vector2) -> void:
	if ghost_display: return
	var mark = "✓" if playable else ("!" if unaffordable else "")
	if active and not unaffordable: mark = "●"
	if target_state == "valid": mark = "✓"
	elif target_state == "invalid": mark = "×"
	if disabled: mark = "–"
	if mark.is_empty(): return
	var fs = T.font_size(24,view_scale,11)
	_text(mark,at+Vector2(0,fs*.3),fs,T.WARNING if unaffordable else (T.GOLD if active else (T.SUCCESS if playable else _edge())),false,"card status")
