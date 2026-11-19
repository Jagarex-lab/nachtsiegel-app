extends "res://scripts/alpha/card_view.gd"
## Real compact-card controls, with the same illustration and existing name/stats.
const StudyFrames = preload("res://scripts/design_study/fractal_fold_frames.gd")
var architecture := "hinge"

func layout_report() -> Dictionary:
	var report:=super.layout_report()
	if architecture=="reference":return report
	var outer: Rect2=report.outer
	# Reserve the proposed material band before drawing the illustration; a
	# full-bleed image must not silently paint the new faction joints away.
	var inset:=maxf(3,outer.size.x*.085)
	var art:=outer.grow(-inset)
	var footer_height:=16.0 if size.y<160 else 25.0
	var stats:=Rect2(art.position.x,art.end.y-footer_height,art.size.x,footer_height)
	var title_data:=_face_title(art.size.x-2,42,10,3)
	var title_height:=maxf(24,title_data.paragraph.get_size().y)
	var title:=Rect2(art.position.x+1,stats.position.y-title_height,maxf(24,art.size.x-2),title_height)
	report.art=art;report.stats=stats;report.status=stats;report.title=title
	report.title_actual=title_data.paragraph.get_size();report.title_fits=title_data.fits;report.title_font_size=title_data.font_size
	report.art_fraction=maxf(0,art.size.x*(art.size.y-title_height-footer_height)-2*PI*pow(minf(14,size.x*.135),2))/maxf(1,outer.get_area())
	report.study_architecture=architecture;report.approval="pending_owner"
	return report

func _draw() -> void:
	if architecture=="reference":
		super._draw()
		return
	if size.x<=8 or size.y<=8 or card.is_empty(): return
	var report := layout_report()
	var rect: Rect2 = report.outer
	var power := str(card.get("faction","neutral"))
	var rarity := str(card.get("rarity","common"))
	StudyFrames.base(self,rect,power,rarity,architecture)
	illustration(report.art)
	StudyFrames.overlay(self,rect,power,rarity,architecture)
	# Reuse the actual compact portrait's energy, name, type and combat values.
	_draw_portrait(report)

func study_report() -> Dictionary:
	# These are the metadata belonging to the texture used by illustration(),
	# not a fresh resolver lookup or a desired manifest path.
	var report:=art_report()
	report.asset=str(_illustration_data.get("asset_path",""))
	report.texture_asset=str(_illustration_data.get("texture_asset_path",""))
	report.preview_only=bool(_illustration_data.get("preview_only",false))
	report.approval="pending_owner";report.architecture=architecture;report.sample_only=true
	return report
