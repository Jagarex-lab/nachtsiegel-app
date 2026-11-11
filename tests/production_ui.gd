extends SceneTree
## Bounded 550-entry UI fixture, plus permanent unit-status/feedback contracts.
## Fixture records are deliberately not claimed as playable production cards.
const Shell=preload("res://scripts/alpha/shell.gd")
const CardView=preload("res://scripts/alpha/card_view.gd")
const Feedback=preload("res://scripts/alpha/feedback.gd")
const ProductionCatalog=preload("res://scripts/production/catalog.gd")
class FixtureShell extends Shell:
	var fixture_cards: Array=[]
	func library_cards() -> Array:return fixture_cards
var assertions := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func settle() -> void:
	for frame in 5:await process_frame
func tiles(app) -> Array:
	var ids: Array=[]
	for key in app.actions:
		if str(key).begins_with("card_"):ids.append(str(key).trim_prefix("card_"))
	return ids
func bounded(control: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(control.get_global_rect()) and control.size.x>=44 and control.size.y>=44
func paging_checks() -> void:
	for dimensions in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(1280,720)]:
		root.size=dimensions
		var app=FixtureShell.new()
		var original=ProductionCatalog.new().all_cards()[0]
		for index in 550:
			var card: Dictionary=original.duplicate(true);card.id="ui-fixture-%03d" % index;card.name="UI Prüfmotiv %03d" % index
			app.fixture_cards.append(card)
		root.add_child(app);await settle();app.open_cards(true);await settle()
		var page_limit=24 if dimensions.x>=1000 else 12
		check(app.library_total==550,"fixture: actual source total550")
		check(app.library_visible_ids.size()==page_limit and tiles(app)==app.library_visible_ids,"real collection creates only the visible page")
		check(app.actions.library_previous.disabled and not app.actions.library_next.disabled,"page boundaries are explicit disabled controls")
		check(bounded(app.actions.library_previous) and bounded(app.actions.library_next),"paging remains in view with44px touch targets")
		var seen: Array=[]
		var pages=app.library_page_count
		for page_index in pages:
			check(app.library_page==page_index,"real page action increments exactly one page")
			check(tiles(app).size()<=page_limit,"rendered card controls stay bounded")
			check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<700,"550-entry library does not instantiate550card trees")
			for id in tiles(app):
				check(not seen.has(id),"no duplicate/missing page identity");seen.append(id)
			if page_index<pages-1:app.actions.library_next.pressed.emit();await settle()
		check(seen.size()==550 and app.actions.library_next.disabled,"every fixture entry reachable exactly once")
		app.filter_text="UI Prüfmotiv 549";app.render();await settle()
		check(app.library_page==0 and tiles(app)==["ui-fixture-549"],"filtering resets tofirstpage andfinds last entry")
		check(not app.actions.has("library_next") and app.library_total==1,"single-result search hides redundant paging")
		app.actions["detail_ui-fixture-549"].pressed.emit();await settle()
		check(is_instance_valid(app.modal),"last-page card opens actual inspector")
		app.close_modal();app.queue_free();await settle()
		print("PRODUCTION UI fixture pages complete ",dimensions)
func card_ink_checks() -> void:
	print("PRODUCTION UI measuring actual550compactnames")
	var cards: Array=ProductionCatalog.new().all_cards()
	check(cards.size()==550,"actualproduction catalog has550records for compacttextchecks")
	for card in cards:
		var view=CardView.new();view.card=card;view.size=Vector2(114,66)
		var title=view.title_paragraph(98)
		check(title.get_line_count()<=2 and title.get_size().y<=32,"actualcardnamefits compacthand: "+card.id)
		check(view.title_layout(98).font_size>=10,"normal compact names never fall below10px: "+card.id)
		for line in title.get_line_count():check(title.get_line_size(line).x<=98,"actualcardnameink stays insidehand: "+card.id)
		var stats=view.stat_layout(69)
		check(stats.fits and 8+stats.ink_width<=85,"actualvalues/type endbeforecost: "+card.id)
		if card.kind=="creature":
			var board_title=view.title_paragraph(86,11,21,8)
			check(board_title.get_line_count()<=2 and board_title.get_size().y<=21,"actualcreaturename fits44px battlefieldnamezone: "+card.id)
		view.free()
	var compact_view=CardView.new();compact_view.card=ProductionCatalog.new().card("oa-stillwatch-c01")
	compact_view.size=Vector2(159,86)
	var name_width=compact_view.size.x-minf(66,compact_view.size.x*.35)-17
	var compact_title=compact_view.title_layout(name_width,12,compact_view.size.y-47)
	check(compact_view.card.name=="Glaskonservator" and compact_title.fits and not compact_title.split_word,"actual mobile Glaskonservator avoids a detached word tail")
	if preload("res://scripts/alpha/style.gd").font.get_string_size(compact_view.card.name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=name_width:
		check(compact_title.font_size>=11,"complete mobile name retains11px wherever it fits")
	compact_view.free()
func status_checks() -> void:
	var view=CardView.new();view.card={"id":"ui-status","name":"Statusprobe","kind":"creature","atk":4,"hp":5,"cost":3}
	view.unit={"id":"ui-status","atk":6,"hp":3,"ward":2,"block":1,"stun":0,"summoned":false,"extra_attacks":1}
	view.combat_ready=true;view.attack_penalty=3;view.origin=true;view.convergence=true
	check(view.current_attack()==3,"visible attack includes current player weakening")
	var status=view.board_status()
	check(status.shield==2 and status.block==1 and status.ready and status.ready_short=="✓","unitshield and attackreadiness stay distinct")
	check(status.extra_short.contains("-1") and status.extra_short.contains("×2") and status.extra_short.contains("U") and status.extra_short.contains("K"),"buff/debuff, extraattack, origin/convergence metadata visible")
	view.size=Vector2(144,80)
	for values in [[0,0],[25,25],[999,999]]:
		view.unit.ward=values[0];view.unit.block=values[1]
		var labels=view.compact_board_labels()
		check(labels.status=="Schild %d · Block %d" % [values[0],values[1]] and labels.fits and labels.font_size>=10,"normal compact shield/block have complete labels and legible numeric ink "+str(values))
	var combat=view.compact_combat_labels(72,11)
	check(combat.fits and combat.font_size>=10 and combat.text.contains("3 ANG") and combat.text.contains("3 LP"),"short-tier combat values still fit beside occupied path badge")
	view.unit.stun=2;view.combat_ready=false
	check(view.board_status().ready_short=="Z2","stasis shows actual remainingduration")
	view.unit.stun=0;view.unit.summoned=true
	check(view.board_status().ready_short=="NEU","summoningdelay uses explicitlabel")
	view.attack_penalty=50;check(view.current_attack()==0,"attackdisplay clamps atzero like actualcombat")
	view.free()
	var feedback=Feedback.new();root.add_child(feedback)
	for index in 200:feedback.emit("shield",Vector2(20,20),Vector2(20,20),Color.CYAN,"S +1")
	check(feedback.jobs.size()==24,"highvolume feedback has a fixed24joblimit")
	feedback.jobs.clear();feedback.reduced=true
	feedback.emit("attack",Vector2.ZERO,Vector2.ONE,Color.WHITE)
	check(feedback.jobs.is_empty(),"reducedmotion suppresses decoration")
	feedback.emit("damage",Vector2.ZERO,Vector2.ONE,Color.WHITE,"−2 LP")
	check(feedback.jobs.size()==1 and feedback.jobs[0].still,"reducedmotion retains static informationalfeedback")
	await create_timer(.25).timeout
	check(feedback.jobs.is_empty(),"short static feedback expires withoutretainingnodes")
	feedback.queue_free();await settle()
func run() -> void:
	await paging_checks();card_ink_checks();await status_checks()
	print("PRODUCTION UI: %d assertions, %d failures;550-entry layoutfixture, boundedpagination, all550actualcompactnames/values,currentattack/status,reducedmotion feedback" % [assertions,failures])
	root.get_node("GameAudio").request_quit(1 if failures else 0)
