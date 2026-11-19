extends RefCounted
## APPROVAL-PENDING study only. Never used by the production renderer selector.
## All proposals share one angular contour and upper-left material lighting.
const REFERENCE = preload("res://scripts/premium/card_frames.gd")
const ARCHITECTURES := ["hinge", "lattice", "crystalline"]
const LABELS := {"reference":"Produktion / Folded", "hinge":"A / Gebrochene Scharniere", "lattice":"B / Verschachtelte Archive", "crystalline":"C / Kristalline Raumfalten"}
const RANKS := {"common":0,"rare":1,"epic":2,"legendary":3}
const INK := Color("090f18")

static func outline(rect: Rect2, inset := 0.0) -> PackedVector2Array:
	var area := rect.grow(-inset)
	var cut := minf(area.size.x / 740.0, area.size.y / 1040.0) * 16.0
	return PackedVector2Array([Vector2(area.position.x+cut,area.position.y), Vector2(area.end.x-cut,area.position.y), Vector2(area.end.x,area.position.y+cut), Vector2(area.end.x,area.end.y-cut), Vector2(area.end.x-cut,area.end.y), Vector2(area.position.x+cut,area.end.y), Vector2(area.position.x,area.end.y-cut), Vector2(area.position.x,area.position.y+cut)])

static func points(rect: Rect2, coordinates: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in coordinates: result.append(rect.position + Vector2(p.x*rect.size.x,p.y*rect.size.y))
	return result

static func plate(canvas: CanvasItem, rect: Rect2, coordinates: Array, color: Color) -> void:
	canvas.draw_colored_polygon(points(rect,coordinates),color)

static func seam(canvas: CanvasItem, rect: Rect2, coordinates: Array, color: Color, width: float) -> void:
	canvas.draw_polyline(points(rect,coordinates),color,width,true)

static func base(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, architecture: String) -> void:
	var tint := REFERENCE.pigment(power)
	var rank := int(RANKS.get(rarity,0))
	var scale_value := minf(rect.size.x/740.0,rect.size.y/1040.0)
	canvas.draw_colored_polygon(outline(rect),INK)
	canvas.draw_colored_polygon(outline(rect,maxf(.7,2*scale_value)),tint.darkened(.48))
	canvas.draw_colored_polygon(outline(rect,maxf(2,7*scale_value)),tint.lightened(.12))
	canvas.draw_colored_polygon(outline(rect,maxf(3,12*scale_value)),tint.darkened(.62))
	canvas.draw_colored_polygon(outline(rect,maxf(4,22*scale_value)),INK)
	# Broad opposing bevels, never a glow outside the card.
	plate(canvas,rect,[Vector2(.028,.008),Vector2(.965,.008),Vector2(.943,.024),Vector2(.048,.024)],tint.lightened(.63))
	plate(canvas,rect,[Vector2(.008,.032),Vector2(.024,.047),Vector2(.024,.948),Vector2(.008,.966)],tint.lightened(.25))
	plate(canvas,rect,[Vector2(.992,.034),Vector2(.976,.052),Vector2(.976,.954),Vector2(.992,.966)],tint.darkened(.76))
	plate(canvas,rect,[Vector2(.032,.992),Vector2(.966,.992),Vector2(.944,.975),Vector2(.052,.975)],tint.darkened(.74))
	# Self-similar inner fold edges communicate rank without replacing power colour.
	for layer in rank+1:
		var gap := .009*float(layer)
		seam(canvas,rect,[Vector2(.055+gap,.030+gap),Vector2(.34+gap,.030+gap),Vector2(.382+gap,.057+gap)],tint.lightened(.32+layer*.12),maxf(.7,1.9*scale_value))
		seam(canvas,rect,[Vector2(.945-gap,.970-gap),Vector2(.66-gap,.970-gap),Vector2(.618-gap,.943-gap)],tint.lightened(.16+layer*.10),maxf(.7,1.9*scale_value))
	# Structure is deliberately stronger than the old tiny footer indicator.
	match architecture:
		"lattice": _lattice(canvas,rect,tint,rank)
		"crystalline": _crystalline(canvas,rect,tint,rank)
		_: _hinge(canvas,rect,tint,rank)
	_power_architecture(canvas,rect,power,tint,rank)

static func overlay(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, architecture: String) -> void:
	var tint := REFERENCE.pigment(power)
	var rank := int(RANKS.get(rarity,0))
	var stroke := maxf(.7,rect.size.x*.0027)
	# These broad overlay silhouettes survive both illustration and compact size.
	# The same unobscured centre is retained; only the frame's side rails expand.
	_architecture_silhouette(canvas,rect,tint,rank,architecture)
	# Fixed aperture shoulders: keep the subject in the centre visible.
	if rank>=1:
		for mirrored in [false,true]:
			var x := .077 if not mirrored else .923
			var sign_value := 1.0 if not mirrored else -1.0
			plate(canvas,rect,[Vector2(x,.167),Vector2(x+sign_value*.062,.167),Vector2(x+sign_value*.033,.200),Vector2(x,.223)],tint.darkened(.05))
			seam(canvas,rect,[Vector2(x,.170),Vector2(x+sign_value*.055,.170),Vector2(x+sign_value*.029,.199)],tint.lightened(.74),stroke)
	if rank>=2:
		for side in [-1.0,1.0]:
			var x := .045 if side<0 else .955
			for index in rank:
				var y := .265+index*.078
				var wide := .019 if architecture!="crystalline" else .027
				plate(canvas,rect,[Vector2(x,y-.025),Vector2(x+wide,y),Vector2(x,y+.044),Vector2(x-wide,y)],tint.darkened(.14))
				plate(canvas,rect,[Vector2(x,y-.025),Vector2(x+wide,y),Vector2(x,y+.014)],tint.lightened(.66))
				seam(canvas,rect,[Vector2(x,y-.022),Vector2(x,y+.037)],tint.lightened(.82),stroke)
	if rank==3:
		# Two large folded aperture hinges distinguish legendary at hand size.
		for mirrored in [false,true]:
			var x := .045 if not mirrored else .955
			var inward := 1.0 if not mirrored else -1.0
			var y := .47 if not mirrored else .24
			plate(canvas,rect,[Vector2(x,y-.054),Vector2(x+inward*.065,y-.030),Vector2(x+inward*.045,y+.020),Vector2(x,y+.056),Vector2(x-inward*.022,y)],tint.darkened(.53))
			plate(canvas,rect,[Vector2(x,y-.054),Vector2(x+inward*.065,y-.030),Vector2(x+inward*.034,y-.004),Vector2(x,y+.015)],tint.lightened(.47))
			seam(canvas,rect,[Vector2(x,y-.049),Vector2(x+inward*.057,y-.028),Vector2(x+inward*.030,y-.003),Vector2(x,y+.019)],tint.lightened(.88),stroke)
		# Bottom rail architecture stays away from the two combat-value diamonds.
		plate(canvas,rect,[Vector2(.29,.970),Vector2(.36,.946),Vector2(.45,.965),Vector2(.5,.949),Vector2(.55,.965),Vector2(.64,.946),Vector2(.71,.970),Vector2(.64,.986),Vector2(.36,.986)],tint.darkened(.18))
		seam(canvas,rect,[Vector2(.30,.970),Vector2(.36,.952),Vector2(.45,.971),Vector2(.5,.955),Vector2(.55,.971),Vector2(.64,.952),Vector2(.70,.970)],tint.lightened(.68),stroke)

static func _architecture_silhouette(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int, architecture: String) -> void:
	var stroke := maxf(.8,rect.size.x*.0030)
	for side in [-1.0,1.0]:
		var inward := -float(side)
		var x := .021 if side<0 else .979
		var top := .153 if side<0 else .201
		match architecture:
			"lattice":
				# B: rectangular interlocked folds with alternating open recesses.
				for layer in rank+2:
					var y := top+layer*.072
					var width := .066+float(layer%2)*.018+rank*.003
					plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*width,y),Vector2(x+inward*width,y+.027),Vector2(x+inward*.031,y+.027),Vector2(x+inward*.031,y+.061),Vector2(x,y+.061)],tint.darkened(.47))
					plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*width,y),Vector2(x+inward*(width-.010),y+.012),Vector2(x+inward*.014,y+.012),Vector2(x+inward*.014,y+.052),Vector2(x,y+.061)],tint.lightened(.37))
					seam(canvas,rect,[Vector2(x+inward*.007,y+.005),Vector2(x+inward*(width-.005),y+.005),Vector2(x+inward*(width-.005),y+.023)],tint.lightened(.83),stroke)
					if rank>=2:
						seam(canvas,rect,[Vector2(x+inward*.040,y+.036),Vector2(x+inward*(width+.007),y+.036),Vector2(x+inward*(width+.007),y+.057)],tint.lightened(.62),stroke)
			"crystalline":
				# C: long unequal prisms, deliberately unlike B's square recesses.
				var width := .066+rank*.011
				var length := .225+rank*.028
				plate(canvas,rect,[Vector2(x,top),Vector2(x+inward*width,top+.041),Vector2(x+inward*(width*.61),top+length),Vector2(x,top+length+.051)],tint.darkened(.56))
				plate(canvas,rect,[Vector2(x,top),Vector2(x+inward*width,top+.041),Vector2(x+inward*(width*.36),top+length*.65)],tint.lightened(.62))
				plate(canvas,rect,[Vector2(x+inward*width,top+.041),Vector2(x+inward*(width*.61),top+length),Vector2(x+inward*(width*.36),top+length*.65)],tint.darkened(.06))
				seam(canvas,rect,[Vector2(x+inward*.004,top+.006),Vector2(x+inward*(width-.006),top+.044),Vector2(x+inward*(width*.57),top+length-.010)],tint.lightened(.90),stroke)
				for layer in rank:
					var y := top+.105+layer*.063
					var leaf := .043+layer*.011
					plate(canvas,rect,[Vector2(x+inward*.022,y),Vector2(x+inward*(width+leaf),y+.021),Vector2(x+inward*(width*.70),y+.060)],tint.darkened(.33))
					plate(canvas,rect,[Vector2(x+inward*.022,y),Vector2(x+inward*(width+leaf),y+.021),Vector2(x+inward*(width*.72),y+.027)],tint.lightened(.71))
			_:
				# A: two continuous broad planes and one recessed joint; quiet centre.
				var width := .064+rank*.012
				var length := .224+rank*.024
				plate(canvas,rect,[Vector2(x,top+.019),Vector2(x+inward*width,top),Vector2(x+inward*width,top+length),Vector2(x+inward*.025,top+length+.049),Vector2(x,top+length+.035)],tint.darkened(.55))
				plate(canvas,rect,[Vector2(x,top+.019),Vector2(x+inward*width,top),Vector2(x+inward*(width-.015),top+.020),Vector2(x+inward*.020,top+.036),Vector2(x+inward*.020,top+length+.025),Vector2(x,top+length+.035)],tint.lightened(.43))
				seam(canvas,rect,[Vector2(x+inward*(width-.007),top+.020),Vector2(x+inward*(width-.007),top+length-.004),Vector2(x+inward*.028,top+length+.039)],tint.lightened(.78),stroke)
				if rank>=1:
					var y := top+length*.56
					plate(canvas,rect,[Vector2(x+inward*.009,y),Vector2(x+inward*(width+.021),y-.027),Vector2(x+inward*(width+.021),y+.006),Vector2(x+inward*.009,y+.034)],tint.darkened(.69))
					seam(canvas,rect,[Vector2(x+inward*.012,y+.002),Vector2(x+inward*(width+.017),y-.023)],tint.lightened(.82),stroke*1.5)

static func _hinge(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int) -> void:
	# A: restrained asymmetry, broad hinged planes, negative-space undersides.
	for side in [-1.0,1.0]:
		var x := .017 if side<0 else .983
		var inward := -float(side)
		var y := .180 if side<0 else .315
		var width := .041+rank*.008
		plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*width,y-.041),Vector2(x+inward*width,y+.228),Vector2(x,y+.286)],tint.darkened(.16))
		plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*width,y-.041),Vector2(x+inward*width,y-.022),Vector2(x+inward*.015,y+.019),Vector2(x+inward*.015,y+.265),Vector2(x,y+.286)],tint.lightened(.23))
		seam(canvas,rect,[Vector2(x+inward*width,y-.035),Vector2(x+inward*width,y+.226),Vector2(x+inward*.006,y+.275)],tint.lightened(.70),maxf(.8,rect.size.x*.0028))

static func _lattice(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int) -> void:
	# B: bounded nested branching, not unbounded recursive fractals.
	for side in [-1.0,1.0]:
		var x := .026 if side<0 else .974
		var inward := -float(side)
		for layer in rank+2:
			var y := .170+layer*.085
			var width := .029+float(layer%2)*.016
			plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*width,y-.020),Vector2(x+inward*(width+.015),y+.031),Vector2(x+inward*.016,y+.070),Vector2(x,y+.049)],tint.darkened(.28+layer*.035))
			seam(canvas,rect,[Vector2(x,y+.003),Vector2(x+inward*width,y-.014),Vector2(x+inward*(width+.010),y+.028),Vector2(x+inward*.016,y+.062)],tint.lightened(.35+rank*.10),maxf(.8,rect.size.x*.0025))
			if rank>=2:
				seam(canvas,rect,[Vector2(x+inward*.012,y+.012),Vector2(x+inward*(width-.007),y+.002),Vector2(x+inward*(width+.002),y+.027)],tint.lightened(.64),maxf(.6,rect.size.x*.0015))

static func _crystalline(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int) -> void:
	# C: long planar facets and split crystal reflections, no full-image shader.
	for side in [-1.0,1.0]:
		var x := .021 if side<0 else .979
		var inward := -float(side)
		for index in rank+2:
			var y := .165+index*.084
			plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*.043,y+.031),Vector2(x+inward*.020,y+.119),Vector2(x,y+.084)],tint.darkened(.16))
			plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*.043,y+.031),Vector2(x+inward*.020,y+.062)],tint.lightened(.37+rank*.08))
			seam(canvas,rect,[Vector2(x+inward*.004,y+.005),Vector2(x+inward*.035,y+.032),Vector2(x+inward*.016,y+.108)],tint.lightened(.78),maxf(.8,rect.size.x*.0025))

static func _power_architecture(canvas: CanvasItem, rect: Rect2, power: String, tint: Color, rank: int) -> void:
	# Shape, material and inscription supplement colour. All live in the rails.
	var stroke := maxf(.8,rect.size.x*.0023)
	# Broad faction joints also survive the compact card's lower name plate.
	# They are structural silhouettes, not merely recoloured tiny footer glyphs.
	for side in [-1.0,1.0]:
		var x:=.026 if side<0 else .974
		var inward:=-float(side)
		var y:=.185 if side<0 else .365
		match power:
			"houses":
				plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*.042,y),Vector2(x+inward*.042,y+.034),Vector2(x+inward*.026,y+.034),Vector2(x+inward*.026,y+.013),Vector2(x,y+.013)],tint.lightened(.48))
				plate(canvas,rect,[Vector2(x,y+.054),Vector2(x+inward*.042,y+.054),Vector2(x+inward*.042,y+.067),Vector2(x+inward*.015,y+.067),Vector2(x+inward*.015,y+.094),Vector2(x,y+.094)],tint.darkened(.10))
				seam(canvas,rect,[Vector2(x+inward*.006,y+.062),Vector2(x+inward*.034,y+.062)],Color("eee0bc"),stroke)
			"stillwatch":
				plate(canvas,rect,[Vector2(x,y+.033),Vector2(x+inward*.021,y-.018),Vector2(x+inward*.047,y+.033),Vector2(x+inward*.026,y+.111)],tint.darkened(.12))
				plate(canvas,rect,[Vector2(x+inward*.021,y-.018),Vector2(x+inward*.047,y+.033),Vector2(x+inward*.021,y+.047)],tint.lightened(.70))
				seam(canvas,rect,[Vector2(x+inward*.021,y-.011),Vector2(x+inward*.021,y+.097)],Color("e1f5ff"),stroke)
			"morph":
				for offset in [0.0,.055]:
					plate(canvas,rect,[Vector2(x,y+offset+.048),Vector2(x+inward*.006,y+offset+.009),Vector2(x+inward*.044,y+offset),Vector2(x+inward*.033,y+offset+.032)],tint.lightened(.40))
					seam(canvas,rect,[Vector2(x+inward*.004,y+offset+.043),Vector2(x+inward*.030,y+offset+.013)],Color("d5b778"),stroke)
			"ninth":
				plate(canvas,rect,[Vector2(x,y+.022),Vector2(x+inward*.031,y),Vector2(x+inward*.049,y+.026),Vector2(x+inward*.015,y+.049)],tint.lightened(.36))
				plate(canvas,rect,[Vector2(x+inward*.006,y+.080),Vector2(x+inward*.037,y+.058),Vector2(x+inward*.049,y+.085),Vector2(x+inward*.018,y+.108)],tint.darkened(.05))
				seam(canvas,rect,[Vector2(x+inward*.006,y+.027),Vector2(x+inward*.037,y+.006),Vector2(x+inward*.037,y+.069),Vector2(x+inward*.010,y+.089)],tint.lightened(.82),stroke)
			_:
				plate(canvas,rect,[Vector2(x,y),Vector2(x+inward*.036,y),Vector2(x+inward*.036,y+.087),Vector2(x,y+.105)],tint.darkened(.10))
				seam(canvas,rect,[Vector2(x+inward*.010,y+.015),Vector2(x+inward*.010,y+.086)],tint.lightened(.47),stroke)
	for index in rank+2:
		var y := .63+index*.052
		match power:
			"houses":
				plate(canvas,rect,[Vector2(.018,y),Vector2(.051,y),Vector2(.051,y+.031),Vector2(.039,y+.031),Vector2(.039,y+.010),Vector2(.018,y+.010)],tint.lightened(.48))
			"stillwatch":
				plate(canvas,rect,[Vector2(.019,y+.015),Vector2(.036,y),Vector2(.053,y+.015),Vector2(.036,y+.035)],tint.lightened(.52))
				seam(canvas,rect,[Vector2(.036,y+.003),Vector2(.036,y+.030)],Color("e1f5ff"),stroke)
			"morph":
				plate(canvas,rect,[Vector2(.020,y+.030),Vector2(.022,y+.005),Vector2(.050,y),Vector2(.045,y+.024)],tint.lightened(.36))
				seam(canvas,rect,[Vector2(.022,y+.029),Vector2(.040,y+.010)],Color("c9af70"),stroke)
			"ninth":
				seam(canvas,rect,[Vector2(.020,y),Vector2(.047,y+.014),Vector2(.025,y+.031),Vector2(.047,y+.031)],tint.lightened(.64),stroke)
				seam(canvas,rect,[Vector2(.026,y+.004),Vector2(.052,y+.018)],Color(tint.lightened(.68),.32),stroke)
			_:
				plate(canvas,rect,[Vector2(.019,y+.006),Vector2(.049,y+.006),Vector2(.049,y+.016),Vector2(.019,y+.016)],tint.lightened(.25))
	# A second, quieter mark on the opposite side is asymmetric by design.
	REFERENCE.sigil(canvas,rect.position+rect.size*Vector2(.963,.73),rect.size.x*.018,power,tint.lightened(.53))

static func geometry_report(rect: Rect2, rarity: String, architecture: String) -> Dictionary:
	var rank := int(RANKS.get(rarity,0))
	return {"approval":"pending_owner","architecture":architecture,"rank":rank,"outer":rect,"outline":outline(rect),"cut_corner_master":16,"depth_layers":rank+1,"bounded_branch_layers":rank+2,"epic_nodes":rank*2 if rank>=2 else 0,"legendary_hinges":2 if rank==3 else 0,"idle_animation":false,"uses_shaders":false}
