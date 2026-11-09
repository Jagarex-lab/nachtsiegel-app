extends Control
## No particles, textures, shaders or per-event nodes; work bounded independently of input rate.
const COLORS={"ASH":Color("ffb46b"),"TIDE":Color("8ddfe6"),"THORN":Color("add48d"),"VEIL":Color("c4b3f2"),"SPELL":Color("ffb46b")}
const MAX_EFFECTS=16
var reduced_motion := false
var low_effects := false
var jobs: Array=[]
var peak_active := 0
var emitted := 0
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func emit_effect(family: String, kind: String, origin: Vector2, destination: Vector2, duration: float) -> void:
	if jobs.size()>=MAX_EFFECTS:jobs.pop_front()
	jobs.append({"family":family,"kind":kind,"from":origin,"to":destination,"age":0.0,"life":maxf(.1,duration)})
	emitted+=1;peak_active=maxi(peak_active,jobs.size());set_process(true);queue_redraw()
func _process(delta: float) -> void:
	for job in jobs:job.age+=delta
	jobs=jobs.filter(func(job):return job.age<job.life)
	queue_redraw()
	if jobs.is_empty():set_process(false)
func _draw() -> void:
	for job in jobs:
		var t=clampf(job.age/job.life,0,1);var color: Color=COLORS.get(job.family,COLORS.VEIL)
		color.a=sin(PI*t)*.8
		var center: Vector2=job.to
		if job.kind in ["attack","spell","play"]:
			var travel=minf(1,t/.58)
			if reduced_motion:draw_line(job.from,job.to,Color(color,.5),2,true)
			else:
				center=job.from.lerp(job.to,travel)
				var trail=job.from.lerp(job.to,maxf(0,travel-.18))
				draw_line(trail,center,color,4,true)
				draw_circle(center,5,color)
		if reduced_motion:
			draw_arc(job.to,37,0,TAU,20,color,3,true);continue
		var n=6 if low_effects else 16
		var radius=18+42*t
		if job.family in ["ASH","SPELL"]:
			# Embers rise and cool; three angular tongues, not a generic recoloured ring.
			for i in n:
				var a=TAU*i/n;var p=center+Vector2(cos(a)*radius,sin(a)*radius*.42-35*t)
				draw_line(p,p+Vector2(3,-9)*(1-t),color,2,true)
		elif job.family=="TIDE":
			# Offset elliptical wave fronts and bright refraction slits.
			for ring in 2:
				var pts=PackedVector2Array()
				for i in n+1:
					var a=TAU*i/n;pts.append(center+Vector2(cos(a)*radius,sin(a)*radius*.44+ring*8))
				draw_polyline(pts,color,2,true)
		elif job.family=="THORN":
			for branch in 3:
				var pts=PackedVector2Array()
				for i in n:
					var f=float(i)/(n-1);pts.append(center+Vector2((branch-1)*18+sin(f*5+t*3+branch)*10,-f*radius))
				draw_polyline(pts,color,2,true)
				var tip=pts[-1];draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(10,5),tip+Vector2(4,13)]),color)
		else:
			# Broken lunar crescents, drifting inward rather than sparks moving outward.
			for crescent in 3:
				var r=radius*(1-.18*crescent)
				draw_arc(center+Vector2(crescent*5,0),r,.3+t*.4,PI*1.45+t*.4,n,color,2,true)
