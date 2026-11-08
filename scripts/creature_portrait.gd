extends Control
## Painted vector placeholder portraits for board creatures and heroes.
var archetype := "ASH"
var accent := Color("#dba66b")
var enemy := false
var heroic := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var c := Vector2(w*0.5,h*0.48)
	var r := minf(w,h)*0.37
	var dark := Color("#100f1a")
	draw_circle(c,r*1.2,Color(accent,0.13))
	draw_arc(c,r*1.12,0,TAU,48,Color(accent,0.55),3.0)
	draw_arc(c,r*0.94,0,TAU,48,Color(accent,0.22),1.5)
	for i in 12:
		var a := TAU*float(i)/12.0
		var d := Vector2(cos(a),sin(a))
		draw_line(c+d*r*1.02,c+d*r*1.16,Color(accent,0.75),2.0)
	if heroic:
		# Stylized hooded champion silhouette.
		var p := PackedVector2Array([c+Vector2(-r*0.7,r*0.83),c+Vector2(-r*0.65,-r*0.05),c+Vector2(-r*0.3,-r*0.7),c+Vector2(0,-r),c+Vector2(r*0.3,-r*0.7),c+Vector2(r*0.65,-r*0.05),c+Vector2(r*0.7,r*0.83)])
		draw_colored_polygon(p,accent.darkened(0.55))
		draw_circle(c+Vector2(0,-r*0.06),r*0.42,dark)
		draw_line(c+Vector2(-r*0.2,0),c+Vector2(-r*0.04,r*0.03),Color("#f6d19b"),3.0)
		draw_line(c+Vector2(r*0.2,0),c+Vector2(r*0.04,r*0.03),Color("#f6d19b"),3.0)
		draw_line(c+Vector2(-r*0.8,r*0.9),c+Vector2(r*0.8,r*0.9),accent,5.0)
	elif archetype == "THORN" or archetype == "VEIL":
		# Wolf crest: pointed ears, angular muzzle, glowing eyes.
		var p := PackedVector2Array([c+Vector2(-r*0.73,-r*0.8),c+Vector2(-r*0.36,-r*0.35),c+Vector2(0,-r*0.5),c+Vector2(r*0.36,-r*0.35),c+Vector2(r*0.73,-r*0.8),c+Vector2(r*0.58,r*0.28),c+Vector2(0,r*0.92),c+Vector2(-r*0.58,r*0.28)])
		draw_colored_polygon(p,accent.darkened(0.28))
		draw_line(c+Vector2(-r*0.5,-r*0.14),c+Vector2(-r*0.13,r*0.02),Color("#f8e5bb"),4.0)
		draw_line(c+Vector2(r*0.5,-r*0.14),c+Vector2(r*0.13,r*0.02),Color("#f8e5bb"),4.0)
		draw_circle(c+Vector2(0,r*0.43),r*0.1,dark)
	elif archetype == "TIDE":
		draw_circle(c+Vector2(0,-r*0.2),r*0.56,accent.darkened(0.2))
		draw_arc(c+Vector2(0,-r*0.25),r*0.44,PI,TAU,30,Color("#e2faff"),4.0)
		for i in 5:
			var x := (float(i)-2.0)*r*0.22
			draw_line(c+Vector2(x,r*0.1),c+Vector2(x*1.25,r*0.84),accent,4.0)
		draw_circle(c+Vector2(0,-r*0.25),r*0.17,Color("#e2faff"))
	else:
		# Ember knight: shield, helmet and blazing crest.
		var p := PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*0.6,-r*0.28),c+Vector2(r*0.52,r*0.58),c+Vector2(0,r),c+Vector2(-r*0.52,r*0.58),c+Vector2(-r*0.6,-r*0.28)])
		draw_colored_polygon(p,accent.darkened(0.35))
		draw_polyline(p,Color("#ffe1aa"),3.0,true)
		draw_line(c+Vector2(0,-r*0.55),c+Vector2(0,r*0.62),Color("#ffe1aa"),5.0)
		draw_line(c+Vector2(-r*0.28,0),c+Vector2(r*0.28,0),Color("#ffe1aa"),4.0)
