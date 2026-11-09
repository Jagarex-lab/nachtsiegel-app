extends Control
## Bounded, deterministic faction-tinted summoning and spell effects.
const T = preload("res://scripts/ui_tokens.gd")
var reduced_motion := false
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var tint := T.SUCCESS
var spell := false
var elapsed := 0.0
var lifetime := 0.75
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()
func _draw() -> void:
	if reduced_motion:
		draw_arc(destination,40,0,TAU,48,tint,3,true)
		return
	var t = clampf(elapsed/lifetime,0,1)
	var alpha = sin(PI*t)
	var center = destination
	if spell:
		var travel = minf(t/.40,1)
		center = origin.lerp(destination,travel)
		for j in 12:
			var lag = maxf(0,travel-j*.025)
			var p = origin.lerp(destination,lag)
			p.y -= sin(lag*PI)*45
			draw_circle(p,maxf(1,8-j*.5),Color(tint.r,tint.g,tint.b,alpha*(1.0-j/12.0)))
		center.y -= sin(travel*PI)*45
	if not spell or t > .35:
		var radius = 15+70*t
		for ring in [0.72,1.0]: draw_arc(destination,radius*ring,0,TAU,72,Color(tint.r,tint.g,tint.b,alpha*.75),2,true)
		for i in 20:
			var a = TAU*i/20.0+t*.6
			var v = Vector2(cos(a),sin(a))
			var p = destination+v*(radius+float(i%4)*7)
			draw_line(p,p+v*(4+12*t),Color(tint.r,tint.g,tint.b,alpha),2,true)
		for i in range(5,0,-1): draw_circle(destination,6+i*4,Color(tint.r,tint.g,tint.b,alpha*.035))
