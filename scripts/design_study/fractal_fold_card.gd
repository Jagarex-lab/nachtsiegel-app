extends "res://scripts/card_system/card_face.gd"
## A preview-only face. Production CardFace and its selected material are untouched.
const StudyFrames = preload("res://scripts/design_study/fractal_fold_frames.gd")
var architecture := "hinge"

func art_aperture() -> Rect2:
	if architecture=="reference": return super.art_aperture()
	# Identical crop in every proposed rarity: the frame is the tested variable.
	return Rect2(74,152,608,500)

func layout_report() -> Dictionary:
	var report := super.layout_report()
	if architecture!="reference":
		report.outer_radius=0
		report.study_architecture=architecture
		report.approval="pending_owner"
	return report

func draw_front() -> void:
	if architecture=="reference":
		super.draw_front()
		return
	var data := normalized()
	var identity: Dictionary = POWERS[data.power]
	var pigment: Color = identity.color
	StudyFrames.base(self,OUTER,data.power,data.rarity,architecture)
	draw_illustration(data)
	# Same diagonal, typography and information positions as the canonical card.
	# No glossary definitions or invented ability text enter this view.
	var information := PackedVector2Array([Vector2(42,656-INFORMATION_LIFT),Vector2(714,570-INFORMATION_LIFT),Vector2(714,966),Vector2(42,966)])
	draw_colored_polygon(information,RULES)
	draw_colored_polygon(PackedVector2Array([Vector2(42,647-INFORMATION_LIFT),Vector2(714,561-INFORMATION_LIFT),Vector2(714,578-INFORMATION_LIFT),Vector2(42,664-INFORMATION_LIFT)]),pigment.darkened(.43))
	draw_line(Vector2(42,647-INFORMATION_LIFT),Vector2(714,561-INFORMATION_LIFT),pigment.lightened(.53),4,true)
	draw_line(Vector2(53,668-INFORMATION_LIFT),Vector2(701,585-INFORMATION_LIFT),Color(pigment,.24),1,true)
	StudyFrames.overlay(self,OUTER,data.power,data.rarity,architecture)
	# Opaque plates and all readable information always paint above ornament.
	rounded_box(Rect2(42,42,672,110),INK,pigment.darkened(.45),1,10)
	draw_circle(Vector2(82,87),36,pigment.darkened(.68))
	draw_arc(Vector2(82,87),36,0,TAU,60,pigment.lightened(.35),2,true)
	label(str(data.cost),Vector2(52,101),39,T.ENERGY,60,HORIZONTAL_ALIGNMENT_CENTER)
	paragraph(data.name,478,87,34,25).draw(get_canvas_item(),Vector2(126,49),TEXT)
	diamond(Vector2(663,87),Vector2(32,41),pigment.darkened(.65))
	diamond(Vector2(663,87),Vector2(32,41),pigment,false)
	Frames.sigil(self,Vector2(663,87),23,data.power,pigment.lightened(.45))
	label(KINDS.get(data.kind,data.kind),Vector2(61,692-INFORMATION_LIFT),28,TEXT,193)
	label(identity.name,Vector2(263,692-INFORMATION_LIFT),23,pigment.lightened(.3),430,HORIZONTAL_ALIGNMENT_RIGHT)
	if data.kind=="creature":
		if not data.species.is_empty(): label(data.species,Vector2(61,730-INFORMATION_LIFT),23,SECONDARY,634)
	elif data.resonance>0:
		label("Zusätzlich %d Resonanz" % data.resonance,Vector2(61,730-INFORMATION_LIFT),22,SECONDARY,634)
	var report := layout_report()
	paragraph(data.text,report.rules.size.x,report.rules.size.y,30,24).draw(get_canvas_item(),report.rules.position,TEXT)
	if data.kind=="creature":
		stat(Vector2(95,979),str(data.attack),"ANGRIFF",pigment)
		stat(Vector2(661,979),str(data.health),"LEBEN",pigment)
	var rank := int(StudyFrames.RANKS.get(data.rarity,0))
	var symbols := ["•","◆","✦","✧"]
	label(symbols[rank],Vector2(346,981),33,pigment.lightened(.5),64,HORIZONTAL_ALIGNMENT_CENTER)
	# The legendary lower fold may never become the rarity word's background.
	draw_rect(Rect2(214,989,328,33),INK)
	label(S.RARITIES.get(data.rarity,data.rarity),Vector2(225,1011),21,SECONDARY,306,HORIZONTAL_ALIGNMENT_CENTER)

func study_report() -> Dictionary:
	var report := layout_report()
	var data := normalized()
	var geometry := StudyFrames.geometry_report(OUTER,data.rarity,architecture)
	return {"architecture":architecture,"approval":"pending_owner","card_id":data.id,"rarity":data.rarity,"power":data.power,"master":[756,1056],"title_fits":report.title_fits,"rules_fit":report.rules_fit,"outer_radius":report.outer_radius,"art":[report.art.position.x,report.art.position.y,report.art.size.x,report.art.size.y],"depth_layers":geometry.depth_layers,"legendary_hinges":geometry.legendary_hinges,"art_report":art_report()}
