extends Control
const T=preload("res://scripts/ui_tokens.gd")
const Session=preload("res://scripts/alpha/session.gd")
const AlphaCatalog=preload("res://scripts/alpha/catalog.gd")
const LegacyCatalog=preload("res://scripts/legacy/catalog.gd")
const CardView=preload("res://scripts/alpha/card_view.gd")
var session=Session.new()
var page := "lobby"
var mode := "alpha"
var faction := "houses"
var difficulty := 2
var selected := -1
var source_lane := -1
var action_mode := ""
var convergence_lanes: Array=[]
var mulligan_indices: Array=[]
var deck: Array=[]
var collection_mode := "alpha"
var filter_text := ""
var filter_type := "all"
var filter_cost := "all"
var filter_rarity := "all"
var filter_power := "all"
var message := "Lokale Testversion · keine Echtgeldfunktionen"
var layout: Control
var density := 1.0
var compact := false
var outer_margin: MarginContainer
var qa_enabled := false
var feedback
var body: VBoxContainer
var modal: Control
var actions: Dictionary={}
var hand_views: Array=[]
var board_views: Dictionary={}
var status: Label
var pulse := 0.0
var render_pending := false
var render_version := 0
var modal_version := 0
var save_key := "houses"
const COLORS={"houses":Color("c4aae9"),"stillwatch":Color("8cd5e8"),"morph":Color("add895"),"ninth":Color("eac17b"),"neutral":Color("b9c4d5"),"ash":Color("eac17b"),"tide":Color("8cd5e8"),"thorn":Color("add895"),"veil":Color("c4aae9")}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme=Theme.new();theme.default_font=T.FONT;theme.default_font_size=14
	theme.set_color("font_color","Label",T.TEXT);theme.set_color("font_color","Button",T.TEXT)
	for state in ["normal","hover","pressed","focus","disabled"]:theme.set_stylebox(state,"Button",T.panel(T.GOLD if state in ["hover","focus"] else T.METAL,T.SURFACE_RAISED))
	theme.set_stylebox("panel","PopupMenu",T.panel());theme.set_constant("v_separation","PopupMenu",30);self.theme=theme
	var bg=TextureRect.new();bg.texture=preload("res://assets/art/arena_painted.png");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.modulate=Color(.24,.30,.40,1);add_child(bg)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,8)
	layout=Control.new();add_child(layout);layout.add_child(margin);outer_margin=margin;body=VBoxContainer.new();body.add_theme_constant_override("separation",4);margin.add_child(body)
	resized.connect(func():if is_node_ready():call_deferred("render"))
	DisplayServer.window_set_title("ORAFOLD · Alpha 0.1 · Testbuild")
	if OS.has_feature("web"):
		density=maxf(1,float(JavaScriptBridge.eval("window.devicePixelRatio||1")));qa_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
		JavaScriptBridge.eval("document.title='ORAFOLD · Alpha 0.1';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD Alpha 0.1')")
	feedback=preload("res://scripts/alpha/feedback.gd").new();feedback.z_index=100;add_child(feedback)
	render()
func _process(delta: float) -> void:
	pulse=maxf(0,pulse-delta);queue_redraw()
	if qa_enabled:publish_qa()
func _draw() -> void:
	if page!="battle":return
	var w=size.x;var h=size.y
	for i in 5:
		var x=w*(.08+.84*(i+.5)/5)
		draw_line(Vector2(w/2,h*.15),Vector2(x,h*.72),Color(.25,.65,.82,.16),2,true)
		draw_circle(Vector2(x,h*.48),8,Color(.6,.8,.9,.22))
	if pulse>0 and not session.profile.reduced_motion:draw_rect(Rect2(Vector2.ZERO,size),Color(.4,.8,1,pulse*.15),false,5)
func _clear() -> void:
	for child in body.get_children():body.remove_child(child);child.queue_free()
	var retained: Dictionary={}
	if is_instance_valid(modal):
		for key in actions:
			if is_instance_valid(actions[key]) and modal.is_ancestor_of(actions[key]):retained[key]=actions[key]
	actions=retained;hand_views.clear();board_views.clear()
func row(parent: Node=null) -> HBoxContainer:
	if parent==null:parent=body
	var box=HBoxContainer.new();box.add_theme_constant_override("separation",5);parent.add_child(box);return box
func text(value: String, parent: Node=null, fs: int=14) -> Label:
	if parent==null:parent=body
	var label=Label.new();label.text=value;label.add_theme_font_size_override("font_size",fs);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func button(id: String, caption: String, callback: Callable, parent: Node=null, disabled_value: bool=false) -> Button:
	if parent==null:parent=body
	var b=Button.new();b.text=caption;b.custom_minimum_size=Vector2(44,44);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.disabled=disabled_value;b.pressed.connect(callback);parent.add_child(b);actions[id]=b;return b
func dropdown(id: String, items: Array, current: String, callback: Callable, parent: Node) -> Button:
	var index=maxi(0,items.find(current))
	var labels={"all":"Alle","creature":"Kreatur","event":"Ereignis","relic":"Relikt","common":"Gewöhnlich","rare":"Selten","epic":"Episch","legendary":"Legendär","houses":"Häuser","stillwatch":"Stillwacht","morph":"Vielgestalt","ninth":"9. Stunde","neutral":"Neutral"}
	var role={"difficulty":"KI","filter_type":"Typ","filter_cost":"Kosten","filter_rarity":"Seltenheit","filter_power":"Macht"}.get(id,"")
	var b=button(id,role+": "+str(labels.get(current,current))+" ↻",func():callback.call(str(items[(index+1)%items.size()])),parent)
	b.tooltip_text="Antippen: nächste Auswahl"
	return b
func scroll(parent: Node=null) -> VBoxContainer:
	if parent==null:parent=body
	var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.scroll_deadzone=8;parent.add_child(sc)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(box);return box
func render() -> void:
	if render_pending:return
	render_pending=true
	call_deferred("_render_now")
func _render_now() -> void:
	render_pending=false;render_version+=1
	if not is_instance_valid(body):return
	_layout()
	_clear()
	if page=="lobby":lobby()
	elif page=="builder":builder()
	elif page=="battle":
		if layout.size.y<296:
			text("Mehr Platz für das Spielfeld benötigt",body,20)
			text("Bitte Tastatur schließen, Browserleisten einklappen oder ins Querformat drehen. Die Partie bleibt erhalten.")
			button("small_menu","Zum Menü",confirm_menu)
		else:battle()
	queue_redraw()
func lobby() -> void:
	var top=row();text("ORAFOLD  /  ALPHA 0.1",top,24);button("archive","Prototyp-Archiv",func():get_tree().root.set_meta("alpha_archive",true);get_tree().change_scene_to_file("res://scenes/front_end.tscn"),top)
	text("Zwei getrennte Regelwerke. Vollständige lokale Partie gegen KI. Keine Onlinekonten, keine Käufe.")
	var options=row()
	button("mode_alpha",("● " if mode=="alpha" else "○ ")+"ORAFOLD",func():mode="alpha";faction="houses";render(),options)
	button("mode_legacy",("● " if mode=="legacy" else "○ ")+"LEGACY",func():mode="legacy";faction="start";render(),options)
	dropdown("difficulty",["Normal","Einfach","Taktisch"],"Einfach" if difficulty==1 else "Taktisch" if difficulty==5 else "Normal",func(v):difficulty={"Normal":2,"Einfach":1,"Taktisch":5}[v],options)
	var box=scroll()
	if mode=="alpha":
		text("30 Leben · 30 Karten · 5 Starthandkarten · Ursprung · Konvergenz",box,16)
		for power in ["houses","stillwatch","morph","ninth"]:
			var line=row(box);var label=AlphaCatalog.new().source.powers[power]
			var b=button("faction_"+power,("● " if faction==power else "○ ")+label,func():faction=power;render(),line);b.modulate=COLORS[power]
			text({"houses":"Erinnerung / Rückkehr / Opfer","stillwatch":"Schutz / Stasis / Aufschub","morph":"Anpassung / Schwarm / Positionsspiel","ninth":"Kausalität / Umleitung / Echos"}[power],line)
	else:
		text("Originalregelwerk · 100 Karten / 16 Fähigkeiten · 20–25 Karten · Original-KI",box,16)
		for id in LegacyCatalog.new().deck_ids():button("faction_"+id,("● " if faction==id else "○ ")+id.to_upper(),func():faction=id;render(),box)
	text(message,box,12)
	var bottom=row()
	button("start","PARTIE STARTEN",start_battle,bottom)
	button("builder","DECKS / SAMMLUNG",func():collection_mode=mode;save_key=faction;deck=current_deck();filter_power="all";filter_type="all";filter_cost="all";filter_rarity="all";filter_text="";page="builder";render(),bottom)
	button("motion","Bewegung: "+("reduziert" if session.profile.reduced_motion else "normal"),func():session.profile.reduced_motion=not session.profile.reduced_motion;session.save_profile();render(),bottom)
	button("last_replay","LETZTES REPLAY",load_last_replay,bottom,not FileAccess.file_exists("user://orafold_last_replay.json"))
	text("Arbeitsnamen. Illustrationen sind wiederverwendete Platzhalter. Nicht veröffentlicht.",body,12)
func current_deck() -> Array:
	var key=mode+":"+faction
	if session.profile.decks.has(key) and session.profile.decks[key] is Dictionary:
		var candidate: Dictionary=session.profile.decks[key]
		var ids: Variant=candidate.get("cards")
		var validation=AlphaCatalog.new().validate(ids) if mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(ids)
		if validation.ok:return ids.duplicate()
	return AlphaCatalog.new().deck(faction) if mode=="alpha" else LegacyCatalog.new().deck(faction)
func start_battle() -> void:
	var seed_value=int(session.profile.last_seed)+1
	var enemy=AlphaCatalog.new().deck(["houses","stillwatch","morph","ninth"][(seed_value%4)]) if mode=="alpha" else []
	if not session.start_match(mode,current_deck(),seed_value,difficulty,enemy):message="Ungültiges Deck.";render();return
	page="battle";selected=-1;source_lane=-1;action_mode="";convergence_lanes=[];mulligan_indices=[];message="Seed %d · %s" % [seed_value,mode];render()
func act(command: String, args: Array) -> void:
	var event_offset: int=session.model.events.size()
	var before=session.model.snapshot()
	var reply=session.command(command,args)
	var names={"play":"Karte ausgespielt.","endTurn":"Angriffe und KI-Zug abgeschlossen.","finishDraw":"Nachziehphase abgeschlossen.","burn":"Karte abgelegt. Bestätige anschließend das Nachziehen.","mulligan":"Austausch abgeschlossen.","origin":"Ursprünge aufgedeckt.","openingDone":"Der Kampf beginnt.","secondOrigin":"Zweiter Ursprung gewählt.","secondCard":"Handkarte ausgetauscht.","converge":"Konvergenz am Zugende geprüft.","activateRelic":"Relikt aktiviert.","burst":"Entfesselung ausgeführt.","recover":"Karte zurückgeholt.","tacticalMove":"Kreatur verschoben.","fortify":"Pfadwacht ausgeführt.","moveCreature":"Positionswechsel abgeschlossen.","skipShift":"Positionswechsel übersprungen.","chooseStrikeTarget":"Ankunftsschlag ausgeführt."}
	message=names.get(command,"Aktion ausgeführt.") if reply.ok else "Bedingungen fehlen: Energie, Resonanz, gültiges Ziel oder eine noch offene Auswahl prüfen."
	if reply.ok:
		selected=-1;source_lane=-1;action_mode="";pulse=.5
		call_deferred("_feedback_events",session.model.events.slice(event_offset),before)
	render()
	if session.model.state.winner!=null:result_dialog()
func battle() -> void:
	var m=session.model;var s: Dictionary=m.state
	var top=row();button("menu","Menü",confirm_menu,top);text("ORAFOLD  /  "+("Runde %d" % (floori(float(s.round-1)/2)+1) if mode=="alpha" else "Legacy · Zug%d" % int(s.round)),top,16);button("log","Protokoll",show_log,top);button("restart","Neu",func():show_modal("Neue Partie?",func(box):button("confirm_restart","Neu starten",func():close_modal();start_battle(),box)),top)
	if mode=="alpha" and s.stage!="battle":opening();return
	var stats=row()
	_portrait(stats,7,24 if compact else 32)
	text("DU  ♥%d  ◇%d  Block%d   ⚡%d  Resonanz%d" % [s.hero.hp,s.hero.ward,s.hero.block,s.hero.energy,s.hero.resonance],stats,13)
	_portrait(stats,8,24 if compact else 32)
	text("KI  ♥%d  ◇%d  Block%d   ⚡%d  Resonanz%d" % [s.enemy.hp,s.enemy.ward,s.enemy.block,s.enemy.energy,s.enemy.resonance],stats,13)
	var board=VBoxContainer.new();board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.add_theme_constant_override("separation",4);body.add_child(board)
	for side in ["enemy","hero"]:
		var line=row(board);line.size_flags_vertical=Control.SIZE_EXPAND_FILL
		for lane in 5:
			var u: Variant=s[side].lanes[lane];var view=CardView.new();view.lane=lane;view.color=T.FOE if side=="enemy" else T.PLAYER
			if u!=null:view.card=session.card(u.id);view.unit=u
			if mode=="alpha" and s.origins[side]==lane:view.color=T.GOLD
			view.custom_minimum_size=Vector2(44,44 if compact else 50);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
			view.selected=convergence_lanes.has(lane) and side=="hero" or source_lane==lane and side=="hero"
			view.target=target_allowed(side,lane);view.tooltip_text=("Ursprung · " if mode=="alpha" and s.origins[side]==lane else "")+(str(view.card.get("description","Freier Pfad")))
			if mode=="alpha" and s[side].convergence!=null and s[side].convergence.lanes.has(lane):view.selected=true;view.color=T.WARNING
			view.pressed.connect(func():field_click(side,lane));line.add_child(view);board_views[side+str(lane)]=view
	var hand=row();hand.custom_minimum_size.y=56 if compact else 90
	for index in s.hero.hand.size():
		var view=CardView.new();view.card=session.card(s.hero.hand[index]);view.color=COLORS.get(view.card.get("faction",view.card.order),T.PLAYER);view.selected=selected==index
		view.custom_minimum_size=Vector2(44,56 if compact else 90);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
		view.pressed.connect(func():_hand_click(index))
		view.tooltip_text=view.card.description;hand.add_child(view);hand_views.append(view)
	var bar=row()
	var overflow: bool=s.hero.phase=="draw" and s.hero.hand.size()+mini(int(s.hero.pendingDraw),s.hero.deck.size())>6
	button("end","Verbrennen" if overflow else "Nachziehen" if s.hero.phase=="draw" else "Zug beenden",func():act("burn",["hero",selected]) if overflow else act("finishDraw",["hero"]) if s.hero.phase=="draw" else act("endTurn",["hero"]),bar,s.winner!=null or s.active!="hero" or overflow and selected<0)
	button("actions","Aktionen",show_actions,bar,s.winner!=null)
	button("inspect","Karte",func():if selected>=0:inspect(session.card(s.hero.hand[selected])),bar,selected<0)
	if mode=="alpha":button("convergence","Konvergenz" if action_mode!="converge" else "Erklären (%d/3)" % convergence_lanes.size(),convergence_action,bar,s.winner!=null or s.active!="hero" or int(s.round)<11)
	if s.hero.pendingShift!=null:button("skip","Überspringen",func():act("skipShift",["hero"]),bar)
	status=text(("FEHLER: "+s.error) if mode=="alpha" and not s.error.is_empty() else "SIEG / NIEDERLAGE – neue Partie im Menü" if s.winner!=null else phase_message(),body,12)
	status.max_lines_visible=1 if compact else 2
func phase_message() -> String:
	var p: Dictionary=session.model.state.hero
	if p.pendingTarget!=null:return "Ankunftsschlag: tippe eine gegnerische Kreatur an."
	if p.phase=="draw":return "Nachziehen: bei Handüberlauf zuerst eine Karte auswählen und verbrennen. Sonst Nachziehen bestätigen."
	if p.pendingShift!=null:return "Positionswechsel: tippe einen Nachbarn der Quelle, dann ein freies eigenes Feld an."
	if action_mode=="converge":return "Wähle drei kampffähige unbestrittene Pfade, dann Erklären."
	return message
func target_allowed(side: String, lane: int) -> bool:
	var m=session.model;var p: Dictionary=m.state.hero
	if p.pendingTarget!=null:return side=="enemy" and m.state.enemy.lanes[lane]!=null
	if p.pendingShift!=null:return side=="hero" and (p.lanes[lane]!=null if source_lane<0 else p.lanes[lane]==null)
	if action_mode=="converge":return side=="hero" and m.controlled("hero",lane)
	if selected<0:return false
	var c=session.card(p.hand[selected]);var enemy_target: bool=mode=="alpha" and c.effect in ["bolt","stasis","delay","redirect","displace"]
	return (side=="enemy" if enemy_target else side=="hero") and m.play_support("hero",selected,lane).is_empty()
func field_click(side: String, lane: int) -> void:
	var m=session.model;var p: Dictionary=m.state.hero
	if m.state.winner!=null:return
	if p.pendingTarget!=null:
		if side=="enemy":act("chooseStrikeTarget",["hero",lane])
		return
	if p.pendingShift!=null:
		if side!="hero":return
		if source_lane<0:source_lane=lane;render()
		else:act("moveCreature",["hero",source_lane,lane])
		return
	if action_mode=="converge":
		if side=="hero" and m.controlled("hero",lane):
			if convergence_lanes.has(lane):convergence_lanes.erase(lane)
			elif convergence_lanes.size()<3:convergence_lanes.append(lane)
			render()
		return
	if action_mode=="move":
		if side!="hero":return
		if source_lane<0:source_lane=lane;message="Nun freien Nachbarpfad wählen.";render()
		else:act("tacticalMove",["hero",source_lane,lane])
		return
	if action_mode=="fortify":
		if side=="hero":act("fortify",["hero",lane])
		return
	if selected>=0:
		if target_allowed(side,lane):act("play",["hero",selected,lane])
		else:message="Ungültiges Ziel. Karte oder Aktion prüfen.";render()
	elif m.state[side].lanes[lane]!=null:inspect(session.card(m.state[side].lanes[lane].id))
func opening() -> void:
	var s: Dictionary=session.model.state
	text("30 Leben · fünf Starthandkarten · Ursprünge werden erst gemeinsam aufgedeckt.",body,14)
	var box=scroll()
	if s.stage=="mulligan":
		text("Einmaliger Mulligan: Wähle beliebige Karten zum Austausch. Ersatz wird vor dem Zurückmischen gezogen.",box,16)
		for i in s.hero.hand.size():
			var c=session.card(s.hero.hand[i]);button("mulligan_"+str(i),("✓ " if mulligan_indices.has(i) else "○ ")+c.name+" · "+str(int(c.cost)),func():_toggle_mulligan(i),box)
		button("mulligan_done","Austausch bestätigen / behalten",func():act("mulligan",[mulligan_indices]),body)
	elif s.stage=="origins":
		text(("Du beginnst." if s.coin=="hero" else "Die KI beginnt; du erhältst Zweite Möglichkeit.")+" Wähle deinen verdeckten Ursprung.",box,16)
		var line=row(box)
		for lane in 5:button("origin_"+str(lane),"PFAD "+str(lane+1),func():act("origin",[lane]),line)
	else:
		text("Ursprünge: DU %d / KI %d. Zweite Möglichkeit: optional einmal Pfad ändern und einmal Karte austauschen." % [s.origins.hero+1,s.origins.enemy+1],box,16)
		var line=row(box)
		for lane in 5:button("second_origin_"+str(lane),str(lane+1),func():act("secondOrigin",[lane]),line,s.second_path)
		for i in s.hero.hand.size():button("second_card_"+str(i),session.card(s.hero.hand[i]).name+" austauschen",func():act("secondCard",[i]),box,s.second_card)
		button("opening_done","Kampf beginnen",func():act("openingDone",[]),body)
func convergence_action() -> void:
	if action_mode!="converge":selected=-1;action_mode="converge";convergence_lanes=[];message="Drei unbestrittene bereite Kreaturen wählen.";render()
	elif convergence_lanes.size()==3:act("converge",["hero",convergence_lanes]);convergence_lanes=[]
	else:message="Es müssen genau drei Pfade sein.";render()
func show_actions() -> void:
	show_modal("RESSOURCEN / SONDERAKTIONEN",func(box):
		button("recover","Rückholung · 5 Resonanz",func():close_modal();act("recover",["hero"]),box)
		button("move","Pfadmanöver · 3 Resonanz",func():close_modal();selected=-1;action_mode="move";source_lane=-1;message="Eigene Kreatur, dann Nachbarpfad wählen.";render(),box)
		button("fortify","Pfadwacht · 2 Resonanz",func():close_modal();selected=-1;action_mode="fortify";message="Eigene Kreatur wählen.";render(),box)
		if mode=="alpha":
			var p: Dictionary=session.model.state.hero
			button("relic","Relikt aktivieren · 1 Energie",func():close_modal();act("activateRelic",["hero"]),box,p.relic==null or p.relic_used)
			text("Aktives Relikt: "+(session.card(p.relic.id).name if p.relic!=null else "keines"),box)
		for order in (["houses","stillwatch","morph","ninth"] if mode=="alpha" else ["ash","tide","thorn","veil"]):
			if mode=="alpha":text(AlphaCatalog.new().source.powers[order]+": "+AlphaCatalog.new().source.identities[order].burst+" n = eigene Kreaturen dieser Macht.",box,13)
			button("burst_"+order,"Entfesseln "+str(AlphaCatalog.new().source.powers.get(order,order.to_upper()))+" · benötigt15, kostet8 Resonanz",func():close_modal();act("burst",["hero",order]),box,int(session.model.state.hero.resonance)<15)
	)
func show_modal(title: String, content: Callable) -> void:
	modal_version+=1
	close_modal()
	if is_instance_valid(feedback):feedback.jobs.clear()
	modal=PanelContainer.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_theme_stylebox_override("panel",T.panel(T.GOLD,Color(.025,.04,.065,.98)));layout.add_child(modal)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",8);margin.add_theme_constant_override("margin_bottom",8);modal.add_child(margin)
	var box=VBoxContainer.new();margin.add_child(box)
	var top=row(box);text(title,top,18);button("modal_close","ZURÜCK",close_modal,top)
	var content_box=scroll(box);content.call(content_box)
func close_modal() -> void:
	modal_version+=1
	if is_instance_valid(modal):modal.hide();modal.queue_free()
	modal=null
func inspect(c: Dictionary) -> void:
	show_modal(str(c.get("name",c.id)),func(box):
		_portrait(box,absi(str(c.id).hash())%7,120)
		text("%s · %s · %s · Energie%d" % [c.get("faction",c.order),c.kind,c.rarity,c.cost],box,16)
		if c.kind=="creature":text("Angriff%d / Leben%d" % [c.atk,c.hp],box,22)
		text(str(c.get("description","")),box,20)
		text("Vollständig implementiert · Illustration: Platzhalter",box,12)
		button("inspect_target","ZIEL WÄHLEN",close_modal,box)
	)
func show_log() -> void:
	show_modal("KAMPFPROTOKOLL / REPLAY",func(box):
		button("export_replay","Replay speichern / herunterladen",func():message="Replay gespeichert." if session.export_replay() else "Speichern fehlgeschlagen.",box)
		button("verify_replay","Replay deterministisch prüfen",func():var result=Session.replay(session.audit());message="Replay identisch." if result.ok else "Replay abweichend.";close_modal();render(),box)
		var names={"hero_hit":"Direkter Heldenangriff","unit_hit":"Kreaturenangriff","attack":"Angriff","death":"Kreaturentod","summon":"Beschwörung","effect":"Fähigkeit","reaction":"Ordensreaktion","begin":"Zugbeginn","recycle":"Kartenkreislauf","fatigue":"Erschöpfung","result":"Spielabschluss","convergence_win":"Konvergenz vollendet","convergence_declared":"Konvergenz angekündigt","convergence_failed":"Konvergenz unterbrochen"}
		for i in session.model.events.size():
			var e: Dictionary=session.model.events[i]
			text("%03d  %s · %s · LP %d:%d · Energie %d:%d" % [i,{"hero":"DU","enemy":"KI","system":"SYSTEM"}.get(e.side,e.side),names.get(e.kind,str(e.kind).replace("_"," ")),e.state.hero.hp,e.state.enemy.hp,e.state.hero.energy,e.state.enemy.energy],box,13)
	)
func result_dialog() -> void:
	var s: Dictionary=session.model.state
	show_modal("SIEG" if s.winner=="hero" else "UNENTSCHIEDEN" if s.winner=="draw" else "NIEDERLAGE",func(box):
		text("Regulärer Spielabschluss. Alle weiteren Kampfaktionen sind gesperrt.",box,20)
		text("Konvergenz" if session.model.events[-1].kind=="convergence_win" else "Helden-/Kontrollentscheidung · siehe Protokoll",box)
		button("result_restart","NEUE PARTIE",func():close_modal();start_battle(),box)
		button("result_menu","ZUM MENÜ",func():close_modal();page="lobby";render(),box)
		button("result_log","PROTOKOLL",show_log,box)
	)
func confirm_menu() -> void:
	show_modal("Partie verlassen?",func(box):
		text("Laufende Partien werden nicht fortgesetzt. Gespeicherte Decks bleiben erhalten.",box)
		button("confirm_menu","Zum Hauptmenü",func():close_modal();page="lobby";render(),box)
	)
func builder() -> void:
	var top=row();text("SAMMLUNG / DECKBAU · %d Karten" % deck.size(),top,20);button("builder_back","Menü",func():page="lobby";render(),top)
	var filters=row()
	var search=LineEdit.new();search.placeholder_text="Karte suchen";search.text=filter_text;search.custom_minimum_size=Vector2(100,44);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
	search.text_submitted.connect(func(v):filter_text=v;render());actions.search=search
	button("search_apply","Suchen",func():filter_text=search.text;render(),filters)
	dropdown("filter_type",["all","creature","event","relic"],filter_type,func(v):filter_type=v;render(),filters)
	dropdown("filter_cost",["all","1","2","3","4","5","6"],filter_cost,func(v):filter_cost=v;render(),filters)
	dropdown("filter_rarity",["all","common","rare","epic","legendary"],filter_rarity,func(v):filter_rarity=v;render(),filters)
	var powers: Array=["all","neutral","houses","stillwatch","morph","ninth"] if collection_mode=="alpha" else ["all","ash","tide","thorn","veil"]
	dropdown("filter_power",powers,filter_power,func(v):filter_power=v;render(),filters)
	var cat=AlphaCatalog.new() if collection_mode=="alpha" else LegacyCatalog.new()
	var box=scroll()
	for raw in cat.all_cards():
		var c: Dictionary=raw.duplicate()
		if collection_mode=="legacy":c.name=session.legacy_text[c.id].name;c.description=session.legacy_text[c.id].description
		if not filter_text.is_empty() and not (str(c.name)+str(c.description)).to_lower().contains(filter_text.to_lower()):continue
		if filter_type!="all" and c.kind!=filter_type:continue
		if filter_cost!="all" and int(c.cost)!=int(filter_cost):continue
		if filter_rarity!="all" and c.rarity!=filter_rarity:continue
		if filter_power!="all" and c.get("faction",c.order)!=filter_power:continue
		var line=row(box);line.custom_minimum_size.y=50
		button("card_"+c.id,"%s · %d Energie · %s" % [c.name,c.cost,"%d Angriff / %d Leben" % [c.atk,c.hp] if c.kind=="creature" else "Ereignis" if c.kind=="event" else "Relikt"],func():inspect(c),line)
		button("remove_"+c.id,"−",func():_remove_card(c.id),line,not deck.has(c.id)).size_flags_horizontal=Control.SIZE_SHRINK_END
		text(str(deck.count(c.id)),line,16).size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		button("add_"+c.id,"+",func():deck.append(c.id);render(),line,deck.count(c.id)>=(1 if c.rarity=="legendary" else 3)).size_flags_horizontal=Control.SIZE_SHRINK_END
	var bottom=row()
	button("save_deck","DECK SPEICHERN",func():var result=session.save_deck(collection_mode+":"+faction,deck,collection_mode);message=result.get("message","");render(),bottom)
	button("load_deck","GESPEICHERTES LADEN",func():mode=collection_mode;deck=current_deck();message="Deck geladen.";render(),bottom)
	button("reset_deck","STARTER LADEN",func():deck=cat.deck(faction);message="Starter geladen.";render(),bottom)
	button("clear_deck","LEEREN",func():deck=[];render(),bottom)
	text(message,body,12)
func publish_qa() -> void:
	var state={"page":page,"mode":mode,"actions":{},"hand":[],"board":{},"modal":is_instance_valid(modal),"message":message,"profile_wins":session.profile.wins,"deck_size":deck.size(),"selected":selected,"action_mode":action_mode,"render_version":render_version,"modal_version":modal_version}
	for key in actions:
		var b=actions[key]
		if is_instance_valid(b) and b.is_visible_in_tree():
			var r=b.get_global_rect();state.actions[key]={"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density],"disabled":b.disabled if b is BaseButton else false}
	for b in hand_views:
		var r=b.get_global_rect();state.hand.append({"id":b.card.id,"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]})
	for key in board_views:
		var r=board_views[key].get_global_rect();state.board[key]=[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]
	if session.model!=null:state.battle=session.model.snapshot();state.command_count=session.commands.size()
	JavaScriptBridge.eval("window.orafoldQA="+JSON.stringify(state))

func _hand_click(index: int) -> void:
	if index<0 or index>=session.model.state.hero.hand.size():return
	var c=session.card(session.model.state.hero.hand[index])
	if selected==index:inspect(c)
	else:selected=index;source_lane=-1;message=c.description;render()
func _toggle_mulligan(index: int) -> void:
	if mulligan_indices.has(index):mulligan_indices.erase(index)
	else:mulligan_indices.append(index)
	render()
func _remove_card(id: String) -> void:
	var i=deck.find(id)
	if i>=0:deck.remove_at(i)
	render()

func _portrait(parent: Node, index: int, height: int=32) -> void:
	var tex=AtlasTexture.new();tex.atlas=preload("res://assets/art/atlas.png")
	var cell=tex.atlas.get_size()/3.0;tex.region=Rect2(Vector2(index%3,floori(float(index)/3))*cell,cell)
	var image=TextureRect.new();image.texture=tex;image.custom_minimum_size=Vector2(height,height);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;parent.add_child(image)

func load_last_replay() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("user://orafold_last_replay.json"))
	var result=Session.replay(data)
	if not result.ok:message="Replay ungültig oder beschädigt.";render();return
	replay_step(data,0)
func replay_step(data: Dictionary, step: int) -> void:
	var prefix=data.duplicate(true);prefix.commands=data.commands.slice(0,step)
	prefix.final=data.commands[step-1].after if step>0 else data.commands[0].before if not data.commands.is_empty() else data.final
	var replay=Session.replay(prefix)
	if not replay.ok:message="Replayprüfung abgebrochen.";return
	show_modal("REPLAY · %d / %d" % [step,data.commands.size()],func(box):
		var nav=row(box)
		button("replay_previous","Vorheriger Befehl",func():replay_step(data,step-1),nav,step==0)
		button("replay_next","Nächster Befehl",func():replay_step(data,step+1),nav,step==data.commands.size())
		text("Startzustand" if step==0 else str(data.commands[step-1].name)+" "+str(data.commands[step-1].args),box,20)
		text("Prüfsumme korrekt · %d rekonstruierte Auslösungen" % replay.events.size(),box)
		for side in ["enemy","hero"]:
			text(side.to_upper()+"  LP%d  Schild%d  Block%d  Energie%d" % [replay.state[side].hp,replay.state[side].ward,replay.state[side].block,replay.state[side].energy],box,16)
			var line=row(box)
			for lane in 5:
				var u: Variant=replay.state[side].lanes[lane]
				text(str(lane+1)+" · "+(str(u.id)+"  %d/%d" % [u.atk,u.hp] if u!=null else "frei"),line,12)
	)

func _layout() -> void:
	var insets: Dictionary={}
	if OS.has_feature("web"):
		var value=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.nachtsiegelInsets?window.nachtsiegelInsets():{})")))
		if value is Dictionary:insets=value
	var left=float(insets.get("left",0));var right=float(insets.get("right",0));var top=float(insets.get("top",0));var bottom=float(insets.get("bottom",0))
	layout.position=Vector2(left,top)*density;layout.scale=Vector2.ONE*density
	layout.size=Vector2(maxf(320,size.x/density-left-right),maxf(160,size.y/density-top-bottom))
	compact=layout.size.y<380
	for side in ["left","right","top","bottom"]:outer_margin.add_theme_constant_override("margin_"+side,4 if compact else 8)
	body.add_theme_constant_override("separation",2 if compact else 4)

func _feedback_events(events: Array, previous: Dictionary) -> void:
	if not is_instance_valid(feedback) or is_instance_valid(modal):return
	feedback.reduced=bool(session.profile.reduced_motion);feedback.density=density
	for e in events:
		var side: String=e.side if e.side in ["hero","enemy"] else "hero"
		var target_side: String=session.model._other(side) if e.kind in ["attack","hero_hit","unit_hit","strike_hit"] else side
		var lane: int=int(e.get("lane",e.get("to",0)))
		if e.get("pendingDeath") is Dictionary:lane=int(e.pendingDeath.get("lane",0))
		var target=Vector2(size.x*(.28 if target_side=="hero" else .78),70*density)
		if board_views.has(target_side+str(lane)) and e.kind!="hero_hit" and not e.get("hero_target",false):target=board_views[target_side+str(lane)].get_global_rect().get_center()
		var origin=Vector2(size.x*.5,size.y-70*density)
		if board_views.has(side+str(int(e.get("from",lane)))):origin=board_views[side+str(int(e.get("from",lane)))].get_global_rect().get_center()
		if e.kind in ["attack","hero_hit","unit_hit","strike_hit","summon","death","recall","shift","draw_finished","effect_draw","convergence_declared","convergence_win","event","tactical_move"]:
			if e.kind in ["draw_finished","effect_draw"]:target=Vector2(size.x*.5,size.y-80*density)
			feedback.emit(e.kind,origin,target,T.FOE if side=="enemy" else T.PLAYER,"×" if e.kind=="death" else "")
		for who in ["hero","enemy"]:
			var hp_loss=maxi(0,int(previous[who].hp)-int(e.state[who].hp))
			var absorb=maxi(0,int(previous[who].ward)-int(e.state[who].ward))+maxi(0,int(previous[who].block)-int(e.state[who].block))
			var point=Vector2(size.x*(.28 if who=="hero" else .78),70*density)
			var healed=maxi(0,int(e.state[who].hp)-int(previous[who].hp))
			if healed>0:feedback.emit("heal",point,point,T.SUCCESS,"+"+str(healed))
			if hp_loss>0:feedback.emit("damage",point,point,T.DANGER,"−"+str(hp_loss))
			if absorb>0:feedback.emit("absorb",point,point,T.ENERGY,"◇"+str(absorb))
		previous=e.state
