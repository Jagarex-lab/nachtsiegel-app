extends RefCounted
## Shared, resolution-independent material grammar for full and compact cards.
## Geometry never escapes the supplied rounded contour. No shader, particles,
## texture allocation or rules lookup is required by a card frame.
const CONCEPTS := ["reliquary", "prismatic", "folded"]
const CHOSEN := "folded"
const COLORS := {"houses":Color("B9824A"),"stillwatch":Color("58A9CF"),"morph":Color("5B9E68"),"ninth":Color("9867BE"),"neutral":Color("8B98A5")}
const RANKS := {"common":0,"rare":1,"epic":2,"legendary":3}
const INK := Color("0b1019")

static func pigment(power: String) -> Color:
	return COLORS.get(power, COLORS.neutral)

static func box(canvas: CanvasItem, rect: Rect2, fill: Color, edge: Color, border: float, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color=fill;style.border_color=edge
	style.set_border_width_all(maxi(0,roundi(border)))
	style.set_corner_radius_all(maxi(0,roundi(radius)))
	style.anti_aliasing=true;style.anti_aliasing_size=1.0
	canvas.draw_style_box(style,rect)

static func point(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position+Vector2(rect.size.x*x,rect.size.y*y)

static func polygon(canvas: CanvasItem, rect: Rect2, coords: Array, fill: Color) -> void:
	var points := PackedVector2Array()
	for coordinate in coords:points.append(point(rect,coordinate.x,coordinate.y))
	canvas.draw_colored_polygon(points,fill)

static func seam(canvas: CanvasItem, rect: Rect2, coords: Array, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for coordinate in coords:points.append(point(rect,coordinate.x,coordinate.y))
	canvas.draw_polyline(points,color,width,true)

static func base(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, concept: String=CHOSEN) -> void:
	var tint:=pigment(power)
	var rank:=int(RANKS.get(rarity,0))
	var scale_value:=minf(rect.size.x/740.0,rect.size.y/1040.0)
	# Every concept/rank has precisely the same opaque outer alpha silhouette.
	box(canvas,rect,INK,tint.darkened(.42),maxf(1,3*scale_value),34*scale_value)
	# A filled metal/glass rail is 3/4/5/6px at a 90px hand size. The outer
	# contour is invariant; rarity changes interior architecture and depth.
	var rail:=float([25,34,43,52][rank])*scale_value
	var material:=tint.darkened(.28 if concept=="reliquary" else .52 if concept=="prismatic" else .37)
	box(canvas,rect.grow(-maxf(.8,4*scale_value)),material,tint.lightened(.38),maxf(1,2*scale_value),30*scale_value)
	box(canvas,rect.grow(-maxf(2,rail)),INK,tint.darkened(.63),maxf(1,3*scale_value),maxf(2,29*scale_value-rail*.35))
	# Broad light-facing and shadow-facing bevels, from one upper-left source.
	polygon(canvas,rect,[Vector2(.048,.018),Vector2(.946,.018),Vector2(.915,.034),Vector2(.065,.034)],tint.lightened(.55))
	polygon(canvas,rect,[Vector2(.018,.065),Vector2(.034,.048),Vector2(.034,.93),Vector2(.018,.945)],tint.lightened(.12))
	polygon(canvas,rect,[Vector2(.982,.065),Vector2(.966,.08),Vector2(.966,.934),Vector2(.982,.945)],tint.darkened(.68))
	polygon(canvas,rect,[Vector2(.063,.982),Vector2(.941,.982),Vector2(.921,.966),Vector2(.078,.966)],tint.darkened(.65))
	if rank>=1:
		box(canvas,rect.grow(-maxf(2,rail-6*scale_value)),Color.TRANSPARENT,tint.lightened(.5),maxf(1,2*scale_value),maxf(2,26*scale_value-rail*.25))

static func overlay(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, concept: String=CHOSEN, shimmer: float=0.0) -> void:
	var tint:=pigment(power)
	var rank:=int(RANKS.get(rarity,0))
	var scale_value:=minf(rect.size.x/740.0,rect.size.y/1040.0)
	var stroke:=maxf(1,2.3*scale_value)
	# Filled side rails are drawn again after artwork. This reserves the
	# intended 3/4/5/6px material depth even for a full-bleed compact image.
	var rail:=float([25,34,43,52][rank])*scale_value
	var rail_color:=tint.darkened(.23 if concept=="reliquary" else .45 if concept=="prismatic" else .34)
	canvas.draw_rect(Rect2(rect.position.x+maxf(1,4*scale_value),rect.position.y+rect.size.y*.08,maxf(1,rail-maxf(1,4*scale_value)),rect.size.y*.84),rail_color)
	canvas.draw_rect(Rect2(rect.end.x-rail,rect.position.y+rect.size.y*.08,maxf(1,rail-maxf(1,4*scale_value)),rect.size.y*.84),rail_color.darkened(.2))
	canvas.draw_line(Vector2(rect.position.x+rail-1,rect.position.y+rect.size.y*.09),Vector2(rect.position.x+rail-1,rect.position.y+rect.size.y*.91),tint.lightened(.5),maxf(1,2*scale_value),true)
	canvas.draw_line(Vector2(rect.end.x-rail,rect.position.y+rect.size.y*.09),Vector2(rect.end.x-rail,rect.position.y+rect.size.y*.91),tint.darkened(.68),maxf(1,3*scale_value),true)
	# Material and architecture differ, rather than merely recolouring one edge.
	match concept:
		"reliquary":_reliquary(canvas,rect,tint,rank,stroke)
		"prismatic":_prismatic(canvas,rect,tint,rank,stroke)
		_:_folded(canvas,rect,tint,rank,stroke)
	_power_marks(canvas,rect,power,tint,stroke)
	if rank>=2:
		# Epic crystals fill the side rails, never the illustration/text aperture.
		for x in [.025,.975]:
			var sign_value:=1.0 if x<.5 else -1.0
			for y in [.22,.27,.32]:
				polygon(canvas,rect,[Vector2(x,y-.026),Vector2(x+sign_value*.014,y),Vector2(x,y+.026),Vector2(x-sign_value*.009,y)],tint.lightened(.08))
				seam(canvas,rect,[Vector2(x,y-.023),Vector2(x,y+.023)],tint.lightened(.62),stroke)
	if rank==3:
		# Interlocking armour is confined to the outer rails. Even legendary
		# corners never cover the energy medallion, name or combat footer.
		for mirrored in [false,true]:
			var x:=.075 if not mirrored else .925
			var sign_value:=1.0 if not mirrored else -1.0
			polygon(canvas,rect,[Vector2(x-sign_value*.035,.024),Vector2(x+sign_value*.22,.024),Vector2(x+sign_value*.16,.038),Vector2(x,.038),Vector2(x-sign_value*.035,.075)],tint.lightened(.13))
			seam(canvas,rect,[Vector2(x-sign_value*.027,.065),Vector2(x,.019),Vector2(x+sign_value*.21,.019)],tint.lightened(.7),stroke)
			polygon(canvas,rect,[Vector2(x-sign_value*.025,.991),Vector2(x+sign_value*.22,.991),Vector2(x+sign_value*.16,.984),Vector2(x,.984),Vector2(x-sign_value*.025,.984)],tint.lightened(.1))
			seam(canvas,rect,[Vector2(x-sign_value*.025,.987),Vector2(x,.987),Vector2(x+sign_value*.21,.987)],tint.lightened(.58),stroke)
		# A short, optional glint is confined to already opaque material rails.
		if shimmer>0:
			seam(canvas,rect,[Vector2(.048,.10),Vector2(.048,.36)],Color(tint.lightened(.8),shimmer*.7),stroke*1.4)
			seam(canvas,rect,[Vector2(.953,.67),Vector2(.953,.9)],Color(tint.lightened(.8),shimmer*.5),stroke)

static func _reliquary(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int, stroke: float) -> void:
	# Architectural metal: broad shoulders, machined ribs, inset enamel.
	for x in [.02,.93]:
		polygon(canvas,rect,[Vector2(x,.10),Vector2(x+.05,.10),Vector2(x+.05,.90),Vector2(x,.90)],tint.darkened(.23))
		seam(canvas,rect,[Vector2(x+.012,.13),Vector2(x+.012,.87)],tint.lightened(.58),stroke)
	for y in [.065,.91]:
		polygon(canvas,rect,[Vector2(.025,y),Vector2(.20,y),Vector2(.235,y+.045),Vector2(.025,y+.045)],tint.darkened(.2))
		polygon(canvas,rect,[Vector2(.975,y),Vector2(.80,y),Vector2(.765,y+.045),Vector2(.975,y+.045)],tint.darkened(.2))
	for layer in rank+1:
		var offset:=float(layer)*.006
		seam(canvas,rect,[Vector2(.039+offset,.14),Vector2(.039+offset,.43)],tint.lightened(.12+layer*.13),stroke)
		seam(canvas,rect,[Vector2(.961-offset,.58),Vector2(.961-offset,.86)],tint.lightened(.1+layer*.12),stroke)
	if rank>=1:
		for x in [.07,.93]:
			for y in [.11,.89]:canvas.draw_circle(point(rect,x,y),maxf(1.2,rect.size.x*.008),tint.lightened(.6))

static func _prismatic(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int, stroke: float) -> void:
	# Glass: long translucent facets and sharp, split specular edges.
	for y in [.10,.25,.40,.55,.70,.85]:
		polygon(canvas,rect,[Vector2(.02,y),Vector2(.072,y+.025),Vector2(.02,y+.12)],tint.lightened(.18))
		polygon(canvas,rect,[Vector2(.98,y+.12),Vector2(.928,y+.095),Vector2(.98,y)],tint.darkened(.04))
		seam(canvas,rect,[Vector2(.021,y),Vector2(.067,y+.025),Vector2(.021,y+.11)],tint.lightened(.6),stroke)
	polygon(canvas,rect,[Vector2(.026,.11),Vector2(.065,.075),Vector2(.065,.45),Vector2(.026,.55)],tint.lightened(.2))
	polygon(canvas,rect,[Vector2(.974,.89),Vector2(.935,.925),Vector2(.935,.55),Vector2(.974,.45)],tint.darkened(.14))
	for layer in rank+1:
		var offset:=float(layer)*.012
		seam(canvas,rect,[Vector2(.08+offset,.036),Vector2(.29+offset,.036),Vector2(.32+offset,.06)],tint.lightened(.42),stroke)
		seam(canvas,rect,[Vector2(.92-offset,.964),Vector2(.71-offset,.964),Vector2(.68-offset,.94)],tint.lightened(.34),stroke)
	if rank>=1:
		polygon(canvas,rect,[Vector2(.952,.12),Vector2(.925,.17),Vector2(.952,.25),Vector2(.972,.19)],tint.lightened(.36))
		polygon(canvas,rect,[Vector2(.048,.88),Vector2(.075,.83),Vector2(.048,.75),Vector2(.028,.81)],tint.lightened(.36))

static func _folded(canvas: CanvasItem, rect: Rect2, tint: Color, rank: int, stroke: float) -> void:
	# Selected architecture: asymmetric folded-metal rails, a long diagonal
	# hinge, dark undersides and illuminated faces with generous art aperture.
	polygon(canvas,rect,[Vector2(.018,.12),Vector2(.072,.068),Vector2(.072,.43),Vector2(.018,.49)],tint.darkened(.05))
	polygon(canvas,rect,[Vector2(.982,.87),Vector2(.928,.932),Vector2(.928,.58),Vector2(.982,.51)],tint.darkened(.15))
	seam(canvas,rect,[Vector2(.069,.074),Vector2(.069,.43),Vector2(.023,.486)],tint.lightened(.58),stroke)
	seam(canvas,rect,[Vector2(.931,.581),Vector2(.931,.925),Vector2(.85,.956)],tint.lightened(.3),stroke)
	for layer in rank+1:
		var offset:=float(layer)*.007
		seam(canvas,rect,[Vector2(.1+offset,.032+offset),Vector2(.34+offset,.032+offset),Vector2(.375+offset,.056+offset)],tint.lightened(.18+layer*.13),stroke)
		seam(canvas,rect,[Vector2(.9-offset,.968-offset),Vector2(.66-offset,.968-offset),Vector2(.625-offset,.944-offset)],tint.lightened(.14+layer*.13),stroke)
	if rank>=1:
		polygon(canvas,rect,[Vector2(.03,.53),Vector2(.055,.485),Vector2(.055,.59)],tint.lightened(.38))
		polygon(canvas,rect,[Vector2(.97,.47),Vector2(.945,.515),Vector2(.945,.41)],tint.lightened(.38))

static func _power_marks(canvas: CanvasItem, rect: Rect2, power: String, tint: Color, stroke: float) -> void:
	# Recognisable silhouettes/materials supplement colour. Confined to rails.
	for y in [.62,.68,.74]:
		match power:
			"houses":
				seam(canvas,rect,[Vector2(.024,y+.022),Vector2(.024,y),Vector2(.046,y),Vector2(.046,y+.014)],tint.lightened(.22),stroke)
			"stillwatch":
				polygon(canvas,rect,[Vector2(.024,y),Vector2(.045,y+.015),Vector2(.024,y+.03)],tint.lightened(.36))
			"morph":
				polygon(canvas,rect,[Vector2(.025,y),Vector2(.049,y+.012),Vector2(.038,y+.035),Vector2(.025,y+.022)],tint.lightened(.25))
			"ninth":
				seam(canvas,rect,[Vector2(.024,y),Vector2(.044,y+.015),Vector2(.024,y+.03)],tint.lightened(.35),stroke)
			_:
				canvas.draw_circle(point(rect,.032,y+.015),maxf(.8,rect.size.x*.005),tint.lightened(.4))

static func sigil(canvas: CanvasItem, center: Vector2, radius: float, power: String, tint: Color) -> void:
	# Vector symbols have no dependency on platform fallback glyph coverage.
	var width:=maxf(1,radius*.12)
	match power:
		"houses":
			for offset in [-.52,0.0,.52]:canvas.draw_line(center+Vector2(offset*radius,-radius*.64),center+Vector2(offset*radius,radius*.64),tint,width,true)
			canvas.draw_line(center+Vector2(-radius*.82,-radius*.7),center+Vector2(radius*.82,-radius*.7),tint,width,true)
			canvas.draw_line(center+Vector2(-radius*.82,radius*.7),center+Vector2(radius*.82,radius*.7),tint,width,true)
		"stillwatch":
			canvas.draw_polyline(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius*.72,0),center+Vector2(0,radius),center+Vector2(-radius*.72,0),center+Vector2(0,-radius)]),tint,width,true)
			canvas.draw_line(center+Vector2(0,-radius*.6),center+Vector2(0,radius*.6),tint,width,true)
		"morph":
			for side in [-1,1]:
				canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,radius*.8),center+Vector2(side*radius*.85,-radius*.2),center+Vector2(side*radius*.5,-radius*.75),center+Vector2(0,-radius*.25)]),tint)
			canvas.draw_line(center+Vector2(0,radius*.8),center+Vector2(0,-radius*.75),tint.lightened(.25),width,true)
		"ninth":
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-radius*.7,-radius*.8),center+Vector2(radius*.7,-radius*.8),center+Vector2(-radius*.55,radius*.8),center+Vector2(radius*.55,radius*.8)]),tint,width,true)
			canvas.draw_arc(center,radius,PI*.05,PI*.65,10,tint,width,true)
		_:
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-radius*.8,-radius*.55),center+Vector2(radius*.8,-radius*.55),center+Vector2(radius*.8,radius*.55),center+Vector2(-radius*.8,radius*.55),center+Vector2(-radius*.8,-radius*.55)]),tint,width,true)
			canvas.draw_line(center+Vector2(-radius*.4,0),center+Vector2(radius*.4,0),tint,width,true)

# Compact-only architecture is deliberately larger than the master engraving:
# it has to communicate rarity at 84px, rather than turn into a one-pixel line.
# All three concepts share this LOD contract, with their own underlying rails.
static func collectible_occlusion(rect: Rect2, rarity: String) -> float:
	return rect.get_area()*(.037 if rarity=="legendary" else .018 if rarity=="epic" else .004 if rarity=="rare" else 0.0)

static func collectible_arch(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, concept: String=CHOSEN) -> void:
	var tint:=pigment(power)
	var rank:=int(RANKS.get(rarity,0))
	if rank==0:return
	var stroke:=maxf(1,rect.size.x*.012)
	if rank==1:
		polygon(canvas,rect,[Vector2(.43,.027),Vector2(.57,.027),Vector2(.52,.065),Vector2(.48,.065)],tint.lightened(.35))
		return
	if rank==2:
		# A visible three-crystal crest plus two aperture-corner crystals.
		for x in [.40,.50,.60]:
			polygon(canvas,rect,[Vector2(x,.045),Vector2(x+.033,.091),Vector2(x,.137),Vector2(x-.033,.091)],tint.darkened(.16))
			polygon(canvas,rect,[Vector2(x,.045),Vector2(x+.033,.091),Vector2(x,.107)],tint.lightened(.62))
			seam(canvas,rect,[Vector2(x,.049),Vector2(x,.131)],tint.lightened(.82),stroke)
		for x in [.075,.925]:
			polygon(canvas,rect,[Vector2(x,.28),Vector2(x+.035,.32),Vector2(x,.36),Vector2(x-.035,.32)],tint.lightened(.28))
		return
	# Legendary: one broad nested fold crown, not a bigger rarity dot. Dark
	# undersides and bright lit planes provide depth without changing pigment.
	var crown:=[Vector2(.25,0.057500),Vector2(.38,0.057500),Vector2(.43,0.087500),Vector2(.50,0.047750),Vector2(.57,0.087500),Vector2(.62,0.057500),Vector2(.75,0.057500),Vector2(.65,0.132500),Vector2(.55,0.117500),Vector2(.50,0.150500),Vector2(.45,0.117500),Vector2(.35,0.132500)]
	polygon(canvas,rect,crown,tint.darkened(.62))
	polygon(canvas,rect,[Vector2(.27,0.057500),Vector2(.38,0.057500),Vector2(.43,0.087500),Vector2(.50,0.047750),Vector2(.50,0.091250),Vector2(.45,0.119750),Vector2(.35,0.132500)],tint.lightened(.43))
	polygon(canvas,rect,[Vector2(.50,0.047750),Vector2(.57,0.087500),Vector2(.62,0.057500),Vector2(.73,0.057500),Vector2(.65,0.132500),Vector2(.55,0.117500),Vector2(.50,0.091250)],tint.darkened(.08))
	seam(canvas,rect,[Vector2(.28,0.062000),Vector2(.38,0.062000),Vector2(.43,0.092000),Vector2(.50,0.053000),Vector2(.57,0.092000),Vector2(.62,0.062000),Vector2(.72,0.062000)],tint.lightened(.82),stroke)
	seam(canvas,rect,[Vector2(.35,0.132500),Vector2(.45,0.117500),Vector2(.50,0.150500),Vector2(.55,0.117500),Vector2(.65,0.132500)],tint.lightened(.35),stroke)
	# Two folded side hinges read as architecture, not tiny gemstone badges.
	for side in [-1,1]:
		var x:=.07 if side<0 else .93
		var inward:=-float(side)
		polygon(canvas,rect,[Vector2(x,0.372000),Vector2(x+inward*.065,0.389500),Vector2(x+inward*.04,0.421000),Vector2(x,0.442000),Vector2(x-inward*.015,0.410500)],tint.darkened(.18))
		seam(canvas,rect,[Vector2(x,0.375500),Vector2(x+inward*.057,0.391600),Vector2(x+inward*.035,0.418900)],tint.lightened(.62),stroke)

static func gallery_arch(canvas: CanvasItem, rect: Rect2, power: String, rarity: String, concept: String=CHOSEN) -> void:
	# The full face reserves the title bar; its collector architecture hangs
	# below that bar into the top illustration shoulders instead of hiding text.
	if int(RANKS.get(rarity,0))<2:return
	var shoulders:=Rect2(rect.position.x,rect.position.y+rect.size.y*.132,rect.size.x,rect.size.y*.58)
	collectible_arch(canvas,shoulders,power,rarity,concept)
