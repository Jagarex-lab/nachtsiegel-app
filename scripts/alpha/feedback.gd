extends Control
## Presentation only: bounded visual jobs, never owns or delays a battle command.
const T=preload("res://scripts/ui_tokens.gd")
var jobs: Array=[]
var reduced := false
var density := 1.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func emit(kind: String, origin: Vector2, target: Vector2, hue: Color, caption: String="") -> void:
	if reduced:return
	if jobs.size()>=24:jobs.pop_front()
	jobs.append({"kind":kind,"from":origin,"to":target,"hue":hue,"caption":caption,"age":0.0,"duration":.45})
func _process(delta: float) -> void:
	for job in jobs:job.age+=delta
	jobs=jobs.filter(func(j):return j.age<j.duration)
	if not jobs.is_empty():queue_redraw()
	else:queue_redraw()
func _draw() -> void:
	for j in jobs:
		var t=clampf(j.age/j.duration,0,1);var c=Color(j.hue,1-t);var center: Vector2=j.from.lerp(j.to,minf(1,t*2))
		if j.kind in ["attack","hero_hit","unit_hit","strike_hit","shift","tactical_move"]:
			draw_line(j.from,center,Color(j.hue,(1-t)*.7),3*density,true)
			draw_circle(center,4*density,c)
		elif j.kind in ["summon","recall","convergence_declared","convergence_win"]:
			draw_arc(j.to,(8+28*t)*density,0,TAU,32,c,3*density,true)
		else:
			draw_circle(j.to,(5+16*t)*density,Color(j.hue,.25*(1-t)))
			draw_arc(j.to,(6+18*t)*density,0,TAU,24,c,2*density,true)
		if not str(j.caption).is_empty():
			var at: Vector2=j.to+Vector2(-12,-14-24*t)*density
			draw_string_outline(T.FONT,at,j.caption,HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*density),4*density,T.INK)
			draw_string(T.FONT,at,j.caption,HORIZONTAL_ALIGNMENT_LEFT,-1,int(15*density),c)
