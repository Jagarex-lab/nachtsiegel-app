extends Control
## Presentation only: bounded visual jobs, never owns or delays a battle command.
const T=preload("res://scripts/ui_tokens.gd")
var jobs: Array=[]
var reduced := false
var density := 1.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func emit(kind: String, origin: Vector2, target: Vector2, hue: Color, caption: String="") -> void:
	if reduced and caption.is_empty():return
	if jobs.size()>=24:jobs.pop_front()
	jobs.append({"kind":kind,"from":origin,"to":target,"hue":hue,"caption":caption,"age":0.0,"duration":.18 if reduced else .38,"still":reduced})
func _process(delta: float) -> void:
	if jobs.is_empty():return
	for job in jobs:job.age+=delta
	jobs=jobs.filter(func(j):return j.age<j.duration)
	queue_redraw()
func _draw() -> void:
	for j in jobs:
		var t := clampf(j.age/j.duration,0,1)
		var motion := 0.0 if j.still else t
		var c := Color(j.hue,1-t)
		var center: Vector2=j.from.lerp(j.to,minf(1,motion*2))
		if j.kind in ["shield","block","heal"]:
			_defense_mark(str(j.kind),j.to,motion,c)
		elif not j.still and j.kind in ["attack","hero_hit","unit_hit","strike_hit","shift","tactical_move"]:
			draw_line(j.from,center,Color(j.hue,(1-t)*.45),5*density,true)
			draw_line(j.from,center,Color(1,1,1,(1-t)*.7),1.3*density,true)
			draw_circle(center,3*density,c)
		elif j.kind in ["damage","unit_damage"]:
			_impact_mark(j.to,motion,c)
		elif not j.still and j.kind in ["summon","recall","convergence_declared","convergence_win"]:
			_fold_mark(j.to,motion,c)
		elif not j.still:
			draw_circle(j.to,(5+16*motion)*density,Color(j.hue,.18*(1-t)))
			draw_arc(j.to,(6+18*motion)*density,0,TAU,20,c,1.7*density,true)
		if not str(j.caption).is_empty():
			var at: Vector2=j.to+Vector2(-12,-14 if j.still else -14-24*t)*density
			draw_string_outline(T.FONT,at,j.caption,HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*density),4*density,T.INK)
			draw_string(T.FONT,at,j.caption,HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*density),c)

func _defense_mark(kind: String, at: Vector2, progress: float, tint: Color) -> void:
	var radius := (12+progress*11)*density
	if kind=="shield":
		var hex := PackedVector2Array()
		for index in 7:
			var angle := TAU*float(index)/6.0-PI*.5
			hex.append(at+Vector2(cos(angle),sin(angle))*radius)
		draw_colored_polygon(hex.slice(0,6),Color(tint,.09*tint.a))
		draw_polyline(hex,tint,2*density,true)
		draw_arc(at,radius*.65,-PI*.8,PI*.3,16,Color(tint,.55*tint.a),1.3*density,true)
	elif kind=="block":
		var plate := PackedVector2Array([at+Vector2(-radius*.7,-radius*.65),at+Vector2(radius*.7,-radius*.65),at+Vector2(radius*.5,radius*.45),at+Vector2(0,radius),at+Vector2(-radius*.5,radius*.45),at+Vector2(-radius*.7,-radius*.65)])
		draw_colored_polygon(plate.slice(0,5),Color(tint,.12*tint.a))
		draw_polyline(plate,tint,2.5*density,true)
		draw_line(at+Vector2(-radius*.32,-radius*.15),at+Vector2(radius*.32,radius*.25),Color(1,1,1,tint.a),1.5*density,true)
	else:
		draw_circle(at,radius,Color(tint,.07*tint.a))
		draw_line(at+Vector2(-radius*.5,0),at+Vector2(radius*.5,0),tint,3*density,true)
		draw_line(at+Vector2(0,-radius*.5),at+Vector2(0,radius*.5),tint,3*density,true)
		for side in [-1,1]:
			var leaf := PackedVector2Array([at+Vector2(side*radius*.5,-radius*.7),at+Vector2(side*radius*.85,-radius*.35),at+Vector2(side*radius*.4,-radius*.2)])
			draw_colored_polygon(leaf,Color(tint,.5*tint.a))

func _impact_mark(at: Vector2, progress: float, tint: Color) -> void:
	var inner := (3+progress*5)*density
	var outer := (10+progress*19)*density
	for index in 6:
		var angle := TAU*float(index)/6.0
		var direction := Vector2(cos(angle),sin(angle))
		draw_line(at+direction*inner,at+direction*outer,tint,1.8*density,true)

func _fold_mark(at: Vector2, progress: float, tint: Color) -> void:
	var radius := (8+progress*28)*density
	var diamond := PackedVector2Array([at+Vector2(-radius,0),at+Vector2(0,-radius*.48),at+Vector2(radius,0),at+Vector2(0,radius*.48),at+Vector2(-radius,0)])
	draw_polyline(diamond,tint,2*density,true)
	draw_line(at+Vector2(0,-radius*.48),at+Vector2(0,radius*.48),Color(tint,.45*tint.a),1*density,true)
