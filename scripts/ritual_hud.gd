extends Control
var energy := 3
var round_number := 1
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var dark = PackedVector2Array([Vector2(1360,116),Vector2(1584,116),Vector2(1578,652),Vector2(1364,652)])
	draw_colored_polygon(dark,Color(.035,.065,.075,.78))
	var c = Vector2(1475,193)
	for r in range(9,0,-1): draw_circle(c,41+r*2,Color(.2,.65,.68,.015))
	draw_circle(c,43,Color("#040e17"))
	draw_arc(c,43,0,TAU,72,Color("#b0a17f"),3,true)
	draw_arc(c,37,0,TAU,72,Color("#345a64"),3,true)
	draw_arc(c,34,PI*1.13,PI*1.83,32,Color("#b4e1dc"),1,true)
	for i in 10:
		var a = PI*.15+PI*.7*float(i)/9.0
		var p = c+Vector2(cos(a),sin(a))*73
		var color = Color("#73c3ca") if i < energy else Color("#283c42")
		var gem = PackedVector2Array([p+Vector2(0,-7),p+Vector2(5,0),p+Vector2(0,7),p+Vector2(-5,0),p+Vector2(0,-7)])
		draw_colored_polygon(gem,color)
		draw_line(p+Vector2(0,-6),p+Vector2(-4,0),color.lightened(.2),1,true)
