extends Control
const S=preload("res://scripts/alpha/style.gd")
const T=preload("res://scripts/ui_tokens.gd")
const Session=preload("res://scripts/alpha/session.gd")
const AlphaCatalog=preload("res://scripts/alpha/catalog.gd")
const LegacyCatalog=preload("res://scripts/legacy/catalog.gd")
const CardView=preload("res://scripts/alpha/card_view.gd")
const FullCardFace=preload("res://scripts/card_system/card_face.gd")
const LibraryFilter=preload("res://scripts/card_system/library_filter.gd")
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
var opening_hand_signature := ""
var hand_drag: Dictionary={}
var drag_ghost: Control
var deck: Array=[]
var collection_mode := "alpha"
var collection_only := false
var filter_text := ""
var filter_type := "all"
var filter_cost := "all"
var filter_rarity := "all"
var filter_power := "all"
var filter_species := "all"
var filter_sort := "cost_asc"
var message := "Lokale Testversion · keine Echtgeldfunktionen"
var layout: Control
var density := 1.0
var compact := false
var portrait := false
var deck_tab := "library"
var match_use_starter := false
var deck_filter_box: Control
var menu_return := "lobby"
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
var qa_elapsed := 0.0
var viewport_poll := 0.0
var viewport_version := -1
var first_frame := true
var render_pending := false
var last_primary_ms := -1000
var primary_ref: WeakRef
var rotation_block_until := 0
var render_version := 0
var modal_version := 0
var save_key := "houses"
var restore_search_focus := false
var search_caret := 0
const LEGACY_COLORS={"houses":Color("c4aae9"),"stillwatch":Color("8cd5e8"),"morph":Color("add895"),"ninth":Color("eac17b"),"neutral":Color("b9c4d5"),"ash":Color("eac17b"),"tide":Color("8cd5e8"),"thorn":Color("add895"),"veil":Color("c4aae9")}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme=Theme.new();theme.default_font=S.font;theme.default_font_size=14
	theme.set_color("font_color","Label",T.TEXT);theme.set_color("font_color","Button",T.TEXT);theme.set_color("font_disabled_color","Button",T.MUTED)
	for state in ["normal","hover","pressed","focus","disabled"]:theme.set_stylebox(state,"Button",T.panel(T.GOLD if state in ["hover","focus"] else T.METAL,T.SURFACE_RAISED))
	theme.set_stylebox("panel","PopupMenu",T.panel());theme.set_constant("v_separation","PopupMenu",30);self.theme=theme
	var bg=TextureRect.new();bg.texture=preload("res://assets/art/arena_painted.png");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.modulate=Color(.24,.30,.40,1);add_child(bg)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,8)
	layout=Control.new();add_child(layout);layout.add_child(margin);outer_margin=margin;body=VBoxContainer.new();body.add_theme_constant_override("separation",4);margin.add_child(body)
	resized.connect(func():if is_node_ready():call_deferred("render"))
	DisplayServer.window_set_title("ORAFOLD · Alpha 0.2 · Testbuild")
	if OS.has_feature("web"):
		density=maxf(1,float(JavaScriptBridge.eval("window.devicePixelRatio||1")));qa_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
		JavaScriptBridge.eval("document.title='ORAFOLD · Alpha 0.2';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD Alpha 0.2')")
	faction=session.profile.faction;difficulty=int(session.profile.difficulty)
	if OS.has_feature("legacy_ui_qa"):mode="legacy";faction="start"
	feedback=preload("res://scripts/alpha/feedback.gd").new();feedback.z_index=100;add_child(feedback)
	render()
func _process(delta: float) -> void:
	_update_primary_readiness()
	if not hand_drag.is_empty() and Time.get_ticks_msec()-int(hand_drag.updated)>8000:_cancel_hand_drag(true)
	if first_frame:
		first_frame=false
		# Godot applies the project window title after the initial main scene's ready.
		DisplayServer.window_set_title("ORAFOLD · Alpha 0.2")
		if OS.has_feature("web"):JavaScriptBridge.eval("document.title='ORAFOLD · Alpha 0.2';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD Alpha 0.2')")
	if OS.has_feature("web"):
		viewport_poll+=delta
		if viewport_poll>=.2:
			viewport_poll=0
			var version=int(JavaScriptBridge.eval("window.orafoldViewportVersion||0"))
			if version!=viewport_version:
				viewport_version=version;render()
	pulse=maxf(0,pulse-delta)
	# Keep a canvas frame available to browser compositors and capture tools.
	queue_redraw()
	if qa_enabled:
		qa_elapsed+=delta
		if qa_elapsed>=.1:
			qa_elapsed=0;publish_qa()
func _draw() -> void:
	if page!="battle":return
	var w=size.x;var h=size.y
	for i in 5:
		var x=w*(.08+.84*(i+.5)/5)
		draw_line(Vector2(w/2,h*.15),Vector2(x,h*.72),Color(.25,.65,.82,.16),2,true)
		draw_circle(Vector2(x,h*.48),8,Color(.6,.8,.9,.22))
	if pulse>0 and not session.profile.reduced_motion:draw_rect(Rect2(Vector2.ZERO,size),Color(.4,.8,1,pulse*.15),false,5)
func _clear() -> void:
	_cancel_hand_drag()
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
	var labels={"all":"Alle","creature":"Wesen","event":"Impuls","relic":"Relikt","common":"Gewöhnlich","rare":"Selten","epic":"Episch","legendary":"Legendär","houses":"Zwölf Häuser","stillwatch":"Stillwacht","morph":"Vielgestalt","ninth":"Neunte Stunde","neutral":"Neutral","cost_asc":"Energie aufsteigend","cost_desc":"Energie absteigend","name_asc":"Name A–Z"}
	labels.merge(LibraryFilter.species_labels())
	var role={"difficulty":"KI","filter_type":"Typ","filter_cost":"Kosten","filter_rarity":"Seltenheit","filter_power":"Macht","filter_species":"Wesensart","filter_sort":"Sortierung"}.get(id,"Auswahl")
	return button(id,role+": "+str(labels.get(current,current))+" ▾",func():
		show_modal(role+" auswählen",func(box):
			for value in items:
				button("option_"+id+"_"+str(value),("✓ " if current==value else "")+str(labels.get(value,value)),func():callback.call(str(value));close_modal();render(),box)
		),parent)
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
	restore_search_focus=actions.has("search") and is_instance_valid(actions.search) and actions.search.has_focus()
	if restore_search_focus:search_caret=actions.search.caret_column
	_clear()
	if is_instance_valid(modal):modal.visible=not (page=="battle" and portrait)
	if page=="lobby":lobby()
	elif page=="decks":deck_selection()
	elif page in ["builder","collection"]:builder()
	elif page=="settings":settings_page()
	elif page=="battle":
		if portrait or layout.size.y<296:rotation_page()
		else:battle()
	queue_redraw()
func lobby() -> void:
	var center=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(center)
	var panel=VBoxContainer.new();panel.custom_minimum_size.x=minf(layout.size.x-24,440);panel.add_theme_constant_override("separation",10 if portrait else 4);center.add_child(panel)
	text("O R A F O L D",panel,32 if portrait else 26).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("ALPHA 0.2  ·  FÜNF PFADE",panel,13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("Dein Deck · "+AlphaCatalog.new().source.powers.get(faction,"Testprofil"),panel,16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var play=button("start","SPIELEN  →",choose_match,panel)
	play.custom_minimum_size.y=58 if portrait else 48
	play.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
	button("builder","DECKBUILDER",func():open_cards(false),panel)
	button("collection","SAMMLUNG",func():open_cards(true),panel)
	button("settings","EINSTELLUNGEN",func():page="settings";render(),panel)
	text("30 Karten · 30 Leben · gegen KI",panel,13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("Illustrationen: Platzhalter · Fortschritt auf diesem Gerät",body,12)
func open_cards(read_only: bool) -> void:
	collection_mode=mode;collection_only=read_only;save_key=faction;deck=current_deck()
	filter_power="all";filter_type="all";filter_cost="all";filter_rarity="all";filter_species="all";filter_sort="cost_asc";filter_text=""
	page="collection" if read_only else "builder";render()
func save_preferences() -> void:
	if mode=="alpha":session.profile.faction=faction
	session.profile.difficulty=difficulty;session.save_profile()
func settings_page() -> void:
	var top=row();text("EINSTELLUNGEN",top,22);button("settings_back","Hauptmenü",func():page="lobby";render(),top)
	var box=scroll()
	text("Starterdeck / gespeichertes Deck",box,18)
	if mode=="alpha":
		var power_row: HBoxContainer
		var power_index=0
		for power in AlphaCatalog.new().deck_ids():
			if power_index%2==0:power_row=row(box)
			power_index+=1
			var b=button("faction_"+power,("● " if faction==power else "○ ")+AlphaCatalog.new().source.powers[power],func():faction=power;save_preferences();render(),power_row)
			b.modulate=S.POWER_COLORS[power]
	var options=row(box)
	dropdown("difficulty",["Normal","Einfach","Taktisch"],"Einfach" if difficulty==1 else "Taktisch" if difficulty==5 else "Normal",func(v):difficulty={"Normal":2,"Einfach":1,"Taktisch":5}[v];save_preferences();render(),options)
	button("motion","Bewegung: "+("reduziert" if session.profile.reduced_motion else "normal"),func():session.profile.reduced_motion=not session.profile.reduced_motion;save_preferences();render(),options)
	if FileAccess.file_exists("user://orafold_last_replay.json"):button("last_replay","LETZTES REPLAY ÖFFNEN",load_last_replay,box)
	text("Deckwahl, Schwierigkeit und Bewegung werden lokal gespeichert. Keine Konten oder Käufe.",box,14)
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
	if not session.start_match(mode,AlphaCatalog.new().deck(faction) if mode=="alpha" and match_use_starter else current_deck(),seed_value,difficulty,enemy):message="Ungültiges Deck.";render();return
	last_primary_ms=-1000
	page="battle";selected=-1;source_lane=-1;action_mode="";convergence_lanes=[];mulligan_indices=[];opening_hand_signature="";message="Wähle deine Starthand. Danach legst du den Ursprung fest.";render()
func _update_primary_readiness() -> void:
	if primary_ref==null:return
	var primary=primary_ref.get_ref()
	if primary==null:return
	# SceneTreeTimer can consume the previous slow frame's delta immediately.
	# Readiness and command rejection must use the same monotonic clock.
	primary.disabled=bool(primary.get_meta("rule_blocked",true)) or Time.get_ticks_msec()-last_primary_ms<180
func act(command: String, args: Array) -> void:
	var primary_command=command in ["endTurn","finishDraw","burn","converge"]
	if primary_command and Time.get_ticks_msec()-last_primary_ms<180:return
	var event_offset: int=session.model.events.size()
	var before=session.model.snapshot()
	var reply=session.command(command,args)
	if primary_command:last_primary_ms=Time.get_ticks_msec()
	var names={"play":"Karte ausgespielt.","endTurn":"Angriffe und KI-Zug abgeschlossen.","finishDraw":"Nachziehphase abgeschlossen.","burn":"Karte abgelegt. Bestätige anschließend das Nachziehen.","mulligan":"Austausch abgeschlossen.","origin":"Ursprünge aufgedeckt.","openingDone":"Der Kampf beginnt.","secondOrigin":"Zweiter Ursprung gewählt.","secondCard":"Handkarte ausgetauscht.","converge":"Konvergenz am Zugende geprüft.","activateRelic":"Relikt aktiviert.","burst":"Entfesselung ausgeführt.","recover":"Karte zurückgeholt.","tacticalMove":"Kreatur verschoben.","fortify":"Pfadwacht ausgeführt.","moveCreature":"Positionswechsel abgeschlossen.","skipShift":"Positionswechsel übersprungen.","chooseStrikeTarget":"Ankunftsschlag ausgeführt."}
	message=names.get(command,"Aktion ausgeführt.") if reply.ok else "Bedingungen fehlen: Energie, Resonanz, gültiges Ziel oder eine noch offene Auswahl prüfen."
	if reply.ok:
		selected=-1;source_lane=-1;action_mode="";pulse=.5
		call_deferred("_feedback_events",session.model.events.slice(event_offset),before)
	render()
	if session.model.state.winner!=null:result_dialog()
func battle() -> void:
	var m=session.model;var s: Dictionary=m.state
	var top=row()
	button("menu","Menü",confirm_menu,top).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var center=VBoxContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.add_theme_constant_override("separation",1);top.add_child(center)
	text(battle_heading(s),center,14)
	if mode=="alpha" and s.stage!="battle":
		text("DU %d LP  ·  KI %d LP  ·  FÜNF PFADE" % [s.hero.hp,s.enemy.hp],center,13)
		button("log","Protokoll",show_log,top).size_flags_horizontal=Control.SIZE_SHRINK_END
		opening();return
	var stats=row(center)
	text("DU %d LP · Schild %d · Block %d" % [s.hero.hp,s.hero.ward,s.hero.block],stats,13)
	var res=text("Energie %d / Resonanz %d" % [s.hero.energy,s.hero.resonance],stats,13);res.add_theme_color_override("font_color",T.ENERGY)
	text("KI %d LP · Schild %d · Block %d" % [s.enemy.hp,s.enemy.ward,s.enemy.block],stats,13)
	if mode=="alpha":_relic_slot(top)
	button("log","Protokoll",show_log,top).size_flags_horizontal=Control.SIZE_SHRINK_END
	button("restart","Neu",func():show_modal("Neue Partie?",func(box):button("confirm_restart","Neu starten",func():close_modal();start_battle(),box)),top).size_flags_horizontal=Control.SIZE_SHRINK_END
	_battle_board()
	var hand=row();hand.custom_minimum_size.y=66 if compact else 80
	for index in s.hero.hand.size():
		var view=CardView.new();view.card=session.card(s.hero.hand[index]);view.color=S.color(view.card);view.selected=selected==index
		view.custom_minimum_size=Vector2(44,66 if compact else 80);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
		view.size_flags_stretch_ratio=1.4 if selected==index else 1.0
		view.pressed.connect(func():_hand_click(index));hand.add_child(view);hand_views.append(view)
	var bar=row()
	var overflow: bool=s.hero.phase=="draw" and s.hero.hand.size()+mini(int(s.hero.pendingDraw),s.hero.deck.size())>6
	var picking=selected>=0 and s.hero.phase=="main"
	var caption="KONVERGENZ ERKLÄREN %d/3" % convergence_lanes.size() if action_mode=="converge" else "ZIEL FÜR ANKUNFT WÄHLEN" if s.hero.pendingTarget!=null else "POSITION WÄHLEN" if s.hero.pendingShift!=null else "GÜLTIGES ZIEL ANTIPPEN" if picking else "KARTE VERBRENNEN" if overflow else "KARTEN NACHZIEHEN" if s.hero.phase=="draw" else "ZUG BEENDEN  →"
	var blocked=s.winner!=null or s.active!="hero" or overflow and selected<0 or s.hero.pendingTarget!=null or s.hero.pendingShift!=null or picking or action_mode=="converge" and convergence_lanes.size()!=3
	var primary=button("end",caption,func():convergence_action() if action_mode=="converge" else act("burn",["hero",selected]) if overflow else act("finishDraw",["hero"]) if s.hero.phase=="draw" else act("endTurn",["hero"]),bar,blocked)
	primary.set_meta("rule_blocked",blocked)
	primary_ref=weakref(primary)
	_update_primary_readiness()
	primary.size_flags_stretch_ratio=3;primary.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
	button("actions","Mehr / Ressourcen",show_actions,bar,s.winner!=null).size_flags_horizontal=Control.SIZE_SHRINK_END
	button("inspect","Details",func():if selected>=0:inspect(session.card(s.hero.hand[selected])),bar,selected<0).size_flags_horizontal=Control.SIZE_SHRINK_END
	if selected>=0 or not action_mode.is_empty():button("cancel_selection","Abbrechen",cancel_selection,bar).size_flags_horizontal=Control.SIZE_SHRINK_END
	if action_mode=="converge":actions.convergence=primary
	if s.hero.pendingShift!=null:button("skip","Überspringen",func():act("skipShift",["hero"]),bar).size_flags_horizontal=Control.SIZE_SHRINK_END
	status=text(phase_message(),body,12);status.max_lines_visible=1
func _battle_board(preparing: bool=false) -> void:
	# The opening and combat share these exact lane controls and state data.
	var m=session.model;var s: Dictionary=m.state
	var board=VBoxContainer.new();board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.add_theme_constant_override("separation",3);body.add_child(board)
	for side in ["enemy","hero"]:
		var line=row(board);line.size_flags_vertical=Control.SIZE_EXPAND_FILL
		for lane in 5:
			var u: Variant=s[side].lanes[lane];var view=CardView.new();view.lane=lane;view.owner_label="KI" if side=="enemy" else "DU";view.color=T.FOE if side=="enemy" else T.PLAYER
			if u!=null:view.card=session.card(u.id);view.unit=u;view.combat_ready=m.can_fight(side,lane) if mode=="alpha" else int(u.stun)==0 and (not u.summoned or view.card.effect=="haste")
			view.origin=mode=="alpha" and s.origins[side]==lane
			view.custom_minimum_size=Vector2(44,44);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
			view.selected=convergence_lanes.has(lane) and side=="hero" or source_lane==lane and side=="hero"
			if preparing:
				view.target=side=="hero" and (s.stage=="origins" or s.stage=="second" and not s.second_path)
				view.disabled=not view.target
				view.tooltip_text="Ursprung auf Pfad %d wählen" % (lane+1) if view.target else "Dein Pfad %d" % (lane+1) if side=="hero" else "Gegnerischer Pfad %d" % (lane+1)
				if side=="hero" and s.stage in ["origins","second"]:actions[("origin_" if s.stage=="origins" else "second_origin_")+str(lane)]=view
				view.pressed.connect(func():_opening_lane_click(side,lane))
			else:
				view.target=target_allowed(side,lane);view.invalid_target=selected>=0 and not view.target and s.hero.phase=="main"
				if mode=="alpha" and s[side].convergence!=null and s[side].convergence.lanes.has(lane):view.convergence=not s[side].convergence.broken;view.broken_convergence=bool(s[side].convergence.broken)
				view.pressed.connect(func():field_click(side,lane))
			line.add_child(view);board_views[side+str(lane)]=view
func _relic_slot(parent: Node) -> void:
	var p: Dictionary=session.model.state.hero
	var chosen=selected>=0 and selected<p.hand.size() and session.card(p.hand[selected]).kind=="relic"
	var allowed=chosen and session.model.play_support("hero",selected,0).is_empty()
	var slot=button("relic_slot","RELIKT\n"+("ERSETZEN" if p.relic!=null else "AUSLEGEN") if chosen else "RELIKT\n"+("AKTIV" if p.relic!=null else "FREI"),func():
		if chosen and allowed:act("play",["hero",selected,0])
		elif p.relic!=null:inspect(session.card(p.relic.id))
	,parent,not allowed and p.relic==null)
	slot.size_flags_horizontal=Control.SIZE_SHRINK_END;slot.custom_minimum_size.x=88
	slot.tooltip_text="Ein Relikt aktiv. Ein neues Relikt ersetzt das vorige; das vorige wird abgelegt."+("\n"+session.card(p.relic.id).name if p.relic!=null else "")
	if allowed:slot.add_theme_stylebox_override("normal",T.panel(T.SUCCESS,T.SURFACE_RAISED))
func phase_message() -> String:
	var p: Dictionary=session.model.state.hero
	if p.pendingTarget!=null:return "Ankunftsschlag: tippe eine gegnerische Kreatur an."
	if p.phase=="draw":return "Nachziehen: bei Handüberlauf zuerst eine Karte auswählen und verbrennen. Sonst Nachziehen bestätigen."
	if p.pendingShift!=null:return "Positionswechsel: tippe einen Nachbarn der Quelle, dann ein freies eigenes Feld an."
	if action_mode=="converge":return "Wähle drei kampffähige unbestrittene Pfade, dann Erklären."
	if mode=="alpha" and session.model.state.enemy.convergence!=null and selected<0:return "KI-Konvergenz unterbrochen." if session.model.state.enemy.convergence.broken else "KI-Konvergenz: einen markierten Pfad bestreiten oder eine gebundene Kreatur ausschalten."
	return message
func target_allowed(side: String, lane: int) -> bool:
	var m=session.model;var p: Dictionary=m.state.hero
	if m.state.winner!=null or m.state.active!="hero":return false
	if p.pendingTarget!=null:return side=="enemy" and m.state.enemy.lanes[lane]!=null
	if p.pendingShift!=null:
		if side!="hero":return false
		for choice in m.shift_choices("hero",int(p.pendingShift.origin)):
			if source_lane<0 and choice.from==lane or source_lane==choice.from and choice.to==lane:return true
		return false
	if action_mode=="move":
		if side!="hero":return false
		if source_lane>=0:return p.lanes[lane]==null and abs(source_lane-lane)==1
		for neighbor in [lane-1,lane+1]:
			if p.lanes[lane]!=null and neighbor>=0 and neighbor<5 and p.lanes[neighbor]==null:return true
		return false
	if action_mode=="fortify":return side=="hero" and p.lanes[lane]!=null
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
		if side!="hero" or not target_allowed(side,lane):message="Wähle einen markierten Nachbarn oder ein gültiges freies Feld.";render();return
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
	elif m.state[side].lanes[lane]!=null:inspect(session.card(m.state[side].lanes[lane].id),m.state[side].lanes[lane])
func opening() -> void:
	var s: Dictionary=session.model.state
	var instructions={"mulligan":"1 / 3 · Tippe Karten zum Tauschen an. Details zeigt den vollständigen Kartentext.","origins":"2 / 3 · "+("Du beginnst. " if s.coin=="hero" else "Die KI beginnt. ")+"Wähle deinen Ursprung auf einem leuchtenden eigenen Pfad.","second":"3 / 3 · Zweite Möglichkeit: optional einmal Ursprung ändern und einmal eine Handkarte tauschen."}
	text(instructions.get(s.stage,"Vorbereitung"),body,13)
	_battle_board(true)
	var hand=row();hand.custom_minimum_size.y=80 if compact else 112
	var signature=JSON.stringify(s.hero.hand)
	var animate=signature!=opening_hand_signature and not session.profile.reduced_motion
	opening_hand_signature=signature
	for index in s.hero.hand.size():
		var view=CardView.new();view.card=session.card(s.hero.hand[index]);view.color=S.color(view.card)
		view.selected=mulligan_indices.has(index) if s.stage=="mulligan" else selected==index
		view.custom_minimum_size=Vector2(44,80 if compact else 112);view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;view.size_flags_vertical=Control.SIZE_EXPAND_FILL
		view.tooltip_text=view.card.name+"\n"+str(view.card.get("description",""))
		view.pressed.connect(func():_opening_hand_click(index));hand.add_child(view);hand_views.append(view)
		if s.stage=="mulligan":
			actions["mulligan_"+str(index)]=view
			if mulligan_indices.has(index):
				var ribbon=PanelContainer.new();ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE;ribbon.add_theme_stylebox_override("panel",T.panel(T.GOLD,T.SURFACE));view.add_child(ribbon)
				ribbon.anchor_left=.04;ribbon.anchor_right=.96;ribbon.anchor_top=.42;ribbon.anchor_bottom=.68
				var mark=Label.new();mark.text="↻ TAUSCHEN";mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mark.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;mark.add_theme_font_size_override("font_size",12);mark.add_theme_color_override("font_color",T.GOLD);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;ribbon.add_child(mark)
		elif s.stage=="second":actions["second_card_"+str(index)]=view
		if animate:
			view.modulate.a=.35
			var deal=view.create_tween();deal.tween_property(view,"modulate:a",1.0,.16).set_delay(index*.025)
	var bar=row()
	if s.stage=="mulligan":
		var primary=button("mulligan_done","%d KARTE(N) TAUSCHEN  →" % mulligan_indices.size() if not mulligan_indices.is_empty() else "HAND BEHALTEN  →",func():act("mulligan",[mulligan_indices]),bar)
		primary.size_flags_stretch_ratio=3;primary.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
	elif s.stage=="origins":
		text("URSPRUNG: Eigener Pfad 1–5 · erste eigene Beschwörung dort erhält 1 Schild.",bar,13)
	else:
		var primary=button("opening_done","KAMPF BEGINNEN  →",func():act("openingDone",[]),bar)
		primary.size_flags_stretch_ratio=2;primary.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
		button("second_exchange","KARTE TAUSCHEN" if not s.second_card else "KARTE GETAUSCHT ✓",func():act("secondCard",[selected]),bar,s.second_card or selected<0)
	button("inspect","KARTENDETAILS",func():if selected>=0:inspect(session.card(s.hero.hand[selected])),bar,selected<0).size_flags_horizontal=Control.SIZE_SHRINK_END
func _opening_lane_click(side: String, lane: int) -> void:
	var s: Dictionary=session.model.state
	if side!="hero":return
	if s.stage=="origins":act("origin",[lane])
	elif s.stage=="second" and not s.second_path:act("secondOrigin",[lane])
func _opening_hand_click(index: int) -> void:
	var s: Dictionary=session.model.state
	if index<0 or index>=s.hero.hand.size():return
	selected=index
	if s.stage=="mulligan":_toggle_mulligan(index)
	else:render()
func convergence_action() -> void:
	if action_mode!="converge":selected=-1;action_mode="converge";convergence_lanes=[];message="Drei unbestrittene bereite Kreaturen wählen.";render()
	elif convergence_lanes.size()==3:act("converge",["hero",convergence_lanes]);convergence_lanes=[]
	else:message="Es müssen genau drei Pfade sein.";render()
func show_actions() -> void:
	var p: Dictionary=session.model.state.hero
	var usable: bool=session.model.state.active=="hero" and session.model.state.winner==null and p.phase=="main"
	var pending: bool=p.pendingTarget!=null or p.pendingShift!=null
	var friends=0
	var moves=false
	for lane in 5:
		if p.lanes[lane]==null:continue
		friends+=1
		for to in [lane-1,lane+1]:
			if to>=0 and to<5 and p.lanes[to]==null:moves=true
	show_modal("RESSOURCEN / SONDERAKTIONEN",func(box):
		text("Energie %d · Resonanz %d/15" % [p.energy,p.resonance],box,22)
		button("resource_help","Energie, Resonanz und Schlüsselwörter erklärt",resource_help,box)
		if mode=="alpha":button("convergence","Konvergenz · drei unbestrittene bereite Pfade",func():close_modal();convergence_action(),box,not usable or pending or int(session.model.state.round)<11)
		button("recover",res_caption("Rückholung",5),func():close_modal();act("recover",["hero"]),box,not usable or p.cycled or p.resonance<5 or p.hand.size()>=6 or p.discard.is_empty())
		button("move",res_caption("Pfadmanöver",3),func():close_modal();selected=-1;action_mode="move";source_lane=-1;message="Eigene Kreatur, dann freien Nachbarpfad wählen.";render(),box,not usable or pending or p.tacticUsed or p.resonance<3 or not moves)
		button("fortify",res_caption("Pfadwacht",2),func():close_modal();selected=-1;action_mode="fortify";message="Markierte eigene Kreatur wählen.";render(),box,not usable or pending or p.fortifyUsed or p.resonance<2 or friends==0)
		if mode=="alpha":
			button("relic","Relikt aktivieren · 1 Energie",func():close_modal();act("activateRelic",["hero"]),box,not usable or pending or p.relic==null or p.relic_used or p.energy<1)
			text("Aktives Relikt: "+(session.card(p.relic.id).name if p.relic!=null else "keines"),box)
		for order in ([faction] if mode=="alpha" else ["ash","tide","thorn","veil"]):
			var matching=0
			for u in p.lanes:
				if u!=null and session.card(u.id).order==order:matching+=1
			if mode=="alpha":text(AlphaCatalog.new().source.identities[order].burst+" n = eigene Kreaturen dieser Macht.",box,14)
			button("burst_"+order,str(AlphaCatalog.new().source.powers.get(order,order.to_upper()))+" entfesseln\n15 benötigt · verbraucht 8 Resonanz",func():close_modal();act("burst",["hero",order]),box,not usable or int(p.resonance)<15 or p.burstUsed or matching==0)
	)
func res_caption(title: String, cost: int) -> String:
	var have=int(session.model.state.hero.resonance)
	return "%s · %d Resonanz%s" % [title,cost," (fehlen %d)" % (cost-have) if have<cost else ""]
func resource_help() -> void:
	show_modal("ENERGIE & RESONANZ",func(box):
		var help=S.RESOURCE_HELP
		if mode=="legacy":help=help.replace("Alpha: Zu Beginn deines eigenen Zuges wird sie auf 1, 2, … bis 8 erneuert; Rest verfällt am Zugende.","Legacy: 2 Basisenergie, je +1 bei 5/10/15 Resonanz; weitere Start-/KI-Boni gemäß Originalregeln.")
		text(help,box,16);text(S.KEYWORDS,box,15)
	)
func show_modal(title: String, content: Callable) -> void:
	_cancel_hand_drag(true)
	modal_version+=1
	close_modal()
	if is_instance_valid(feedback):feedback.jobs.clear()
	modal=PanelContainer.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_theme_stylebox_override("panel",T.panel(T.GOLD,Color(.025,.04,.065,.98)));layout.add_child(modal)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",8);margin.add_theme_constant_override("margin_bottom",8);modal.add_child(margin)
	var box=VBoxContainer.new();margin.add_child(box)
	var top=row(box);text(title,top,18);button("modal_close","ZURÜCK",close_modal,top).size_flags_horizontal=Control.SIZE_SHRINK_END
	var content_box=scroll(box);content.call(content_box)
func close_modal() -> void:
	modal_version+=1
	if is_instance_valid(modal):modal.hide();modal.queue_free()
	modal=null
func inspect(c: Dictionary, current: Dictionary={}) -> void:
	show_modal(str(c.get("name",c.id)),func(box):
		if portrait or layout.size.y>=560:
			# This wrapper has no horizontal minimum derived from the card. An open
			# inspector can therefore shrink after rotation rather than clipping it.
			var center=Control.new();center.mouse_filter=Control.MOUSE_FILTER_IGNORE;center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(center)
			var full_card=FullCardFace.new();full_card.card=c;center.add_child(full_card)
			var resize_face=func():
				var width=minf(374,maxf(160,center.size.x));var height=width*88.0/63.0
				full_card.size=Vector2(width,height);full_card.position=Vector2((center.size.x-width)/2,0);center.custom_minimum_size.y=height
			center.resized.connect(resize_face);resize_face.call()
		else:
			var center=CenterContainer.new();box.add_child(center)
			var portrait_card=CardView.new();portrait_card.card=c;portrait_card.color=S.color(c);portrait_card.library=true;portrait_card.custom_minimum_size=Vector2(240,140);center.add_child(portrait_card)
		text(str(c.name),box,24)
		text("%s · %s · %s · %s" % [AlphaCatalog.new().source.powers.get(c.get("faction","neutral"),c.get("order","")),S.KINDS.get(c.kind,c.kind),S.RARITIES.get(c.rarity,c.rarity),"Energie %d" % c.cost],box,16)
		if c.kind=="creature":text("Angriff %d  /  Leben %d" % [current.get("atk",c.atk),current.get("hp",c.hp)],box,22)
		if not current.is_empty():text("Schild %d · Stasis %d" % [current.get("ward",0),current.get("stun",0)],box,16)
		text(str(c.get("description","")),box,18)
		text("SCHLÜSSELWÖRTER",box,14);text(S.card_keywords(c),box,14)
		text("Illustration: geteiltes Konzeptbild",box,12)
		if c.kind=="event" and c.effect=="redirect":text("Benötigt einen eigenen verzögerten Treffer. Mit dem aktuellen Kartenpool in einem legalen Neunte-Stunde-Deck nicht vorbereitbar.",box,14).add_theme_color_override("font_color",T.WARNING)
		button("inspect_target","ZUR ZIELWAHL" if page=="battle" else "SCHLIESSEN",close_modal,box)
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
	var small_builder=layout.size.y<600
	var top=row();text("SAMMLUNG" if collection_only else "DECKWERKSTATT",top,22);button("builder_back","Menü",func():page="lobby";render(),top).size_flags_horizontal=Control.SIZE_SHRINK_END
	if not collection_only and not small_builder and collection_mode=="alpha":
		var powers: HBoxContainer
		var index=0
		for power in AlphaCatalog.new().deck_ids():
			if index%2==0 or not portrait:powers=row() if index==0 or portrait else powers
			index+=1
			button("builder_power_"+power,S.SYMBOLS[power]+" "+AlphaCatalog.new().source.powers[power]+(" ●" if faction==power else ""),func():faction=power;save_preferences();deck=current_deck();filter_power="all";render(),powers)
		text(AlphaCatalog.new().source.powers.get(faction,faction)+" · %d / 30 Karten" % deck.size(),body,18)
	var search_row=row()
	var search=LineEdit.new();search.placeholder_text="Name, Fähigkeit oder Wesensart suchen";search.text=filter_text;search.custom_minimum_size=Vector2(80,44);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search_row.add_child(search)
	search.add_theme_font_size_override("font_size",16)
	search.text_changed.connect(func(v):filter_text=v)
	search.text_submitted.connect(func(v):filter_text=v;search.release_focus();render());actions.search=search
	if restore_search_focus:search.call_deferred("grab_focus");search.set_deferred("caret_column",search_caret)
	button("search_apply","Suchen",func():filter_text=search.text;render(),search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
	button("filters","Filter",show_filters,search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
	if small_builder and not collection_only and collection_mode=="alpha":button("builder_power",AlphaCatalog.new().source.powers[faction],show_power_picker,top if layout.size.x<700 else search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
	var desktop=layout.size.x>=1000
	if not collection_only and not desktop:
		var tabs=top if small_builder and layout.size.x>=700 else row();button("library_tab","BIBLIOTHEK",func():deck_tab="library";render(),tabs);button("deck_tab","DECKLISTE · %d/%d" % [deck.size(),30 if collection_mode=="alpha" else 25],func():deck_tab="deck";render(),tabs)
	var region=row();region.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if collection_only or desktop or deck_tab=="library":library_panel(region,desktop)
	if not collection_only and (desktop or deck_tab=="deck"):deck_panel(region)
	if not collection_only:
		var valid=deck_check()
		text(("Deck gültig · eine Macht + neutrale Karten" if collection_mode=="alpha" else "Legacy-Deck gültig · 20–25 Kreaturen") if valid.ok else valid.message,body,13).add_theme_color_override("font_color",T.SUCCESS if valid.ok else T.WARNING)
		var footer=row()
		button("save_deck","SPEICHERN",save_current_deck,footer,not valid.ok)
		button("load_deck","Laden",func():deck=current_deck();message="Gespeichertes Deck geladen.";render(),footer)
		var starter_catalog=AlphaCatalog.new() if collection_mode=="alpha" else LegacyCatalog.new()
		button("reset_deck","Starter kopieren",func():deck=starter_catalog.deck(faction);message="Starter als bearbeitbare Vorlage kopiert.";render(),footer)
		if collection_mode=="alpha":button("strategy_templates","Testdecks",show_test_decks,body if layout.size.x<700 else footer)
		if not small_builder:text(message,body,12)
func show_test_decks() -> void:
	var templates: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/card_system/test_decks.json"))
	var cat=AlphaCatalog.new()
	show_modal("STRATEGIEVORLAGEN",func(box):
		text("Zehn spielbare Testdecks aus dem aktuellen Kartenpool. Lade eine Vorlage und speichere sie, um sie für eine Partie auszuwählen. Die vier Starter bleiben erhalten.",box,16)
		for entry in templates.decks:
			text(str(entry.name_de)+" · "+str(cat.source.powers[entry.power])+" · 30 Karten",box,19)
			text(str(entry.description_de),box,14)
			if not str(entry.get("limitations_de","")).is_empty():text(str(entry.limitations_de),box,12)
			var valid: Dictionary=cat.validate(entry.cards)
			button("template_"+str(entry.id),"ALS VORLAGE LADEN",func():
				faction=entry.power;deck=entry.cards.duplicate();save_preferences();deck_tab="deck";filter_power="all";filter_species="all"
				message=str(entry.name_de)+" geladen. Speichern, um dieses Deck zu spielen.";close_modal();render()
			,box,not valid.ok)
	)
func library_cards() -> Array:
	var cards: Array=[]
	var cat=AlphaCatalog.new() if collection_mode=="alpha" else LegacyCatalog.new()
	for raw in cat.all_cards():
		var c: Dictionary=raw.duplicate(true)
		if collection_mode=="legacy":c.name=session.legacy_text[c.id].name;c.description=session.legacy_text[c.id].description
		if not collection_only and collection_mode=="alpha" and c.faction not in [faction,"neutral"]:continue
		cards.append(c)
	return cards
func library_query() -> Dictionary:
	return LibraryFilter.select(library_cards(),{"query":filter_text,"kind":filter_type,"cost":filter_cost,"rarity":filter_rarity,"power":filter_power,"species":filter_species,"sort":filter_sort})
func library_panel(parent: Node, desktop: bool) -> void:
	var pane=VBoxContainer.new();pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pane.size_flags_stretch_ratio=1.6;parent.add_child(pane)
	var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.scroll_deadzone=10;pane.add_child(sc)
	var grid=GridContainer.new();grid.columns=3 if desktop else 2 if layout.size.x<700 else 4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",10);sc.add_child(grid)
	var query=library_query()
	if not query.ok:
		text("Filter konnte nicht angewendet werden: "+str(query.error),pane);return
	for c: Dictionary in query.cards:
		var tile=VBoxContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(tile)
		var v=CardView.new();v.card=c;v.library=true;v.color=S.color(c);v.custom_minimum_size=Vector2(0,176);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_child(v);actions["card_"+c.id]=v
		v.pressed.connect(func():inspect(c) if collection_only or not can_add(c) else add_card(c))
		var controls=row(tile)
		button("detail_"+c.id,"Details",func():inspect(c),controls)
		if not collection_only:button("add_"+c.id,"+  %d/%d" % [deck.count(c.id),1 if c.rarity=="legendary" else 3],func():add_card(c),controls,not can_add(c))
	if grid.get_child_count()==0:text("Keine Karten für diese Filter. Suche oder Filter ändern.",pane)
func deck_panel(parent: Node) -> void:
	var pane=VBoxContainer.new();pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(pane)
	text("DEINE KARTEN · %d/%d" % [deck.size(),30 if collection_mode=="alpha" else 25],pane,16)
	var curve=row(pane);var counts=[];counts.resize(9);counts.fill(0)
	var cat=AlphaCatalog.new() if collection_mode=="alpha" else LegacyCatalog.new()
	for id in deck:counts[mini(8,int(cat.card(id).cost))]+=1
	for cost in 9:
		var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;curve.add_child(column)
		var bar=ProgressBar.new();bar.custom_minimum_size=Vector2(8,25);bar.show_percentage=false;bar.max_value=maxi(1,counts.max());bar.value=counts[cost];column.add_child(bar)
		text("%d:%d" % [cost,counts[cost]],column,10).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var box=scroll(pane)
	for raw in cat.all_cards():
		var c: Dictionary=raw.duplicate()
		if collection_mode=="legacy":c.name=session.legacy_text[c.id].name;c.description=session.legacy_text[c.id].description
		if not deck.has(c.id):continue
		var line=row(box)
		button("deck_detail_"+c.id,"%d× %s\n%d Energie" % [deck.count(c.id),c.name,c.cost],func():inspect(c),line)
		button("remove_"+c.id,"−",func():_remove_card(c.id),line).size_flags_horizontal=Control.SIZE_SHRINK_END
	button("clear_deck","Deck leeren …",func():show_modal("Deck wirklich leeren?",func(box):button("confirm_clear","Leeren",func():deck=[];close_modal();render(),box)),pane)
func can_add(c: Dictionary) -> bool:
	return deck.size()<(30 if collection_mode=="alpha" else 25) and deck.count(c.id)<(1 if c.rarity=="legendary" else 3) and (collection_mode=="legacy" or c.faction in [faction,"neutral"])
func add_card(c: Dictionary) -> void:
	if can_add(c):deck.append(c.id);message="Hinzugefügt: "+c.name;render()
	else:message="Deck voll oder Kopien-/Machtgrenze erreicht.";render()
func deck_check() -> Dictionary:
	var result=AlphaCatalog.new().validate(deck) if collection_mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(deck)
	if result.ok and collection_mode=="alpha" and result.faction!=faction:return {"ok":false,"message":"Mindestens eine Karte der gewählten Macht erforderlich."}
	return result
func save_current_deck() -> void:
	var valid=deck_check()
	if not valid.ok:message=valid.message;render();return
	var result=session.save_deck(collection_mode+":"+faction,deck,collection_mode);message=result.get("message","");render()
func publish_qa() -> void:
	var state={"page":page,"mode":mode,"actions":{},"hand":[],"board":{},"modal":is_instance_valid(modal),"message":message,"profile_wins":session.profile.wins,"deck_size":deck.size(),"selected":selected,"action_mode":action_mode,"render_version":render_version,"modal_version":modal_version,"portrait":portrait,"density":density,"layout_size":[layout.size.x,layout.size.y],"deck_ids":deck.duplicate(),"power":faction,"deck_tab":deck_tab,"search_text":filter_text,"font_msdf":S.font.multichannel_signed_distance_field}
	state.opening_marks=mulligan_indices.duplicate();state.drag={"active":bool(hand_drag.get("active",false)),"targets":hand_drag.get("targets",{}).keys()}
	for key in actions:
		var b=actions[key]
		if is_instance_valid(b) and b.is_visible_in_tree():
			var r=b.get_global_rect();state.actions[key]={"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density],"disabled":b.disabled if b is BaseButton else false}
	for b in hand_views:
		var r=b.get_global_rect();state.hand.append({"id":b.card.id,"name":b.card.name,"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]})
	for key in board_views:
		var r=board_views[key].get_global_rect();state.board[key]=[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]
	if session.model!=null:state.battle=session.model.snapshot();state.command_count=session.commands.size()
	JavaScriptBridge.eval("window.orafoldQA="+JSON.stringify(state))

func _hand_click(index: int) -> void:
	if index<0 or index>=session.model.state.hero.hand.size():return
	var c=session.card(session.model.state.hero.hand[index])
	if selected==index:inspect(c)
	else:selected=index;source_lane=-1;action_mode="";message=c.name+" · leuchtendes Ziel wählen. Nochmals tippen: Details.";render()
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
	var image=TextureRect.new();image.texture=tex;image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;image.custom_minimum_size=Vector2(height,height);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;parent.add_child(image)

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
	var visible_height=INF
	var visible_top=0.0
	if OS.has_feature("web"):
		var value=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.nachtsiegelInsets?window.nachtsiegelInsets():{})")))
		if value is Dictionary:insets=value
	if OS.has_feature("web"):
		var ratio=JavaScriptBridge.eval("(()=>{const c=document.querySelector('canvas');return c.width/Math.max(1,c.getBoundingClientRect().width)})()")
		if ratio!=null:density=maxf(.5,float(ratio))
		visible_height=float(JavaScriptBridge.eval("window.visualViewport?window.visualViewport.height:window.innerHeight"))
		visible_top=maxf(0,float(JavaScriptBridge.eval("window.visualViewport?window.visualViewport.offsetTop:0")))
	var left=float(insets.get("left",0));var right=float(insets.get("right",0));var top=float(insets.get("top",0));var bottom=float(insets.get("bottom",0))
	layout.position=Vector2(left,top+visible_top)*density;layout.scale=Vector2.ONE*density
	layout.size=Vector2(maxf(320,size.x/density-left-right),maxf(160,minf(size.y/density-visible_top,visible_height)-top-bottom))
	# A keyboard reduces usable height, not device orientation.
	var next_portrait=size.y>size.x
	if OS.has_feature("web") and page=="battle" and next_portrait!=portrait:rotation_block_until=Time.get_ticks_msec()+180
	portrait=next_portrait
	compact=layout.size.y<380
	for side in ["left","right","top","bottom"]:outer_margin.add_theme_constant_override("margin_"+side,4 if compact else 8)
	body.add_theme_constant_override("separation",2 if compact or page=="battle" else 4)

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

func choose_match() -> void:
	if mode=="legacy":start_battle();return
	match_use_starter=true;page="decks";render()
func select_power(power: String, starter: bool) -> void:
	faction=power;match_use_starter=starter;save_preferences();render()
func deck_selection() -> void:
	var top=row();text("WÄHLE DEIN DECK",top,22);button("decks_back","Menü",func():page="lobby";render(),top).size_flags_horizontal=Control.SIZE_SHRINK_END
	text("Vier Mächte. Ein eigenes Spielgefühl. Je 30 Karten.",body,14)
	var sc=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.scroll_deadzone=10;body.add_child(sc)
	var grid=GridContainer.new();grid.columns=1 if portrait else 2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",10);sc.add_child(grid)
	var cat=AlphaCatalog.new()
	for power in cat.deck_ids():
		var frame=PanelContainer.new();frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;frame.add_theme_stylebox_override("panel",T.panel(S.POWER_COLORS[power],Color("15212d")));grid.add_child(frame)
		var box=VBoxContainer.new();frame.add_child(box)
		var heading=row(box);_portrait(heading,{"houses":4,"stillwatch":5,"morph":1,"ninth":3}[power],48)
		text(S.SYMBOLS[power]+"  "+cat.source.powers[power],heading,22).add_theme_color_override("font_color",S.POWER_COLORS[power])
		text(S.STYLES[power]+"\n"+S.DIFFICULTY[power],box,14)
		var choices=row(box)
		button("preview_"+power,"Eigenes ansehen" if faction==power and not match_use_starter else "Starter ansehen",func():preview_deck(power,not(faction==power and not match_use_starter)),choices)
		button("choose_"+power,("✓ " if faction==power and match_use_starter else "")+"Starter",func():select_power(power,true),choices)
		if session.profile.decks.has("alpha:"+power):button("custom_"+power,"Eigenes",func():select_power(power,false),choices)
	text(("STARTER · " if match_use_starter else "EIGENES DECK · ")+cat.source.powers[faction],body,16)
	var candidate=cat.deck(faction) if match_use_starter else current_deck()
	var valid=cat.validate(candidate)
	var allowed=valid.ok and valid.faction==faction
	if not allowed:text("Eine Macht plus neutrale Karten erforderlich. Bitte Deck in der Werkstatt korrigieren.",body,14)
	var play=button("deck_play","PARTIE STARTEN  →",start_battle,body,not allowed)
	play.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
func preview_deck(power: String, starter: bool) -> void:
	var cat=AlphaCatalog.new();var ids=cat.deck(power)
	if not starter and session.profile.decks.has("alpha:"+power):ids=session.profile.decks["alpha:"+power].cards.duplicate()
	show_modal(("Starter · " if starter else "Eigenes Deck · ")+cat.source.powers[power]+" · 30 Karten",func(box):
		text(S.STYLES[power]+" · "+S.DIFFICULTY[power],box,18)
		var seen: Array=[]
		for id in ids:
			if seen.has(id):continue
			seen.append(id);var c=cat.card(id)
			button("preview_card_"+id,"%d× %s · %d Energie" % [ids.count(id),c.name,c.cost],func():inspect(c),box)
		button("preview_select","DIESES DECK WÄHLEN",func():close_modal();select_power(power,starter),box)
	)
func rotation_page() -> void:
	var center=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(center)
	var box=VBoxContainer.new();box.custom_minimum_size.x=minf(330,layout.size.x-24);box.add_theme_constant_override("separation",16);center.add_child(box)
	text("↻",box,64).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("FÜNF PFADE BRAUCHEN QUERFORMAT",box,24).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("Drehe dein Gerät (Desktop: Fenster breiter ziehen). Karten, Auswahl und Spielzustand bleiben erhalten. Bei Bedarf die iPhone-Drehsperre im Kontrollzentrum ausschalten.",box,16)
	text("Menüs und Deckwerkstatt sind für Hochformat gestaltet.",box,14)
	button("rotate_menu","Sicher zum Menü",confirm_menu,box)
func cancel_selection() -> void:
	selected=-1;source_lane=-1;action_mode="";convergence_lanes=[];message="Auswahl aufgehoben.";render()

func show_filters() -> void:
	var choices=LibraryFilter.choice_options(library_cards())
	show_modal("KARTENFILTER",func(box):
		dropdown("filter_type",["all"]+choices.kind,filter_type,func(v):filter_type=v;close_modal();render(),box)
		var costs: Array=["all"]
		for value in choices.cost:costs.append(str(value))
		dropdown("filter_cost",costs,filter_cost,func(v):filter_cost=v;close_modal();render(),box)
		dropdown("filter_rarity",["all"]+choices.rarity,filter_rarity,func(v):filter_rarity=v;close_modal();render(),box)
		dropdown("filter_power",["all"]+choices.power,filter_power,func(v):filter_power=v;close_modal();render(),box)
		if choices.species.is_empty():
			var no_species=button("filter_species","Wesensart: noch keine zugewiesen",func():pass,box,true)
			no_species.tooltip_text="Für diese Karten wurden noch keine Wesensarten zugewiesen. Es werden keine Arten aus Namen oder Bildern erfunden."
		else:dropdown("filter_species",["all"]+choices.species,filter_species,func(v):filter_species=v;close_modal();render(),box)
		dropdown("filter_sort",choices.sort,filter_sort,func(v):filter_sort=v;close_modal();render(),box)
		button("reset_filters","Alle Filter zurücksetzen",func():filter_text="";filter_type="all";filter_cost="all";filter_rarity="all";filter_power="all";filter_species="all";filter_sort="cost_asc";close_modal();render(),box)
	)
func show_power_picker() -> void:
	show_modal("MACHT DER DECKVORLAGE",func(box):
		for power in AlphaCatalog.new().deck_ids():button("builder_power_"+power,AlphaCatalog.new().source.powers[power],func():faction=power;save_preferences();deck=current_deck();filter_power="all";close_modal();render(),box)
	)

func _web_drag_cancel_version() -> int:
	if not OS.has_feature("web"):return 0
	return int(JavaScriptBridge.eval("window.orafoldTouchCancelVersion||0"))
func _drag_press(at: Vector2, pointer: int) -> void:
	if not hand_drag.is_empty():
		if pointer!=int(hand_drag.pointer):get_viewport().set_input_as_handled()
		return
	if page!="battle" or mode!="alpha" or portrait or is_instance_valid(modal) or session.model==null:return
	var s: Dictionary=session.model.state;var p: Dictionary=s.hero
	if s.stage!="battle" or s.winner!=null or s.active!="hero" or p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or not action_mode.is_empty():return
	for index in hand_views.size():
		if hand_views[index].get_global_rect().has_point(at):
			hand_drag={"index":index,"id":str(p.hand[index]),"pointer":pointer,"start":at,"viewport":get_viewport_rect().size,"web_cancel":_web_drag_cancel_version(),"active":false,"previous":selected,"updated":Time.get_ticks_msec(),"targets":{}}
			return
func _drag_move(at: Vector2, pointer: int) -> void:
	if hand_drag.is_empty() or pointer!=int(hand_drag.pointer):return
	if hand_drag.viewport!=get_viewport_rect().size:
		_cancel_hand_drag(true);get_viewport().set_input_as_handled();return
	hand_drag.updated=Time.get_ticks_msec()
	if not hand_drag.active:
		if at.distance_to(hand_drag.start)<12*density:return
		var p: Dictionary=session.model.state.hero;var index=int(hand_drag.index)
		if index>=p.hand.size() or p.hand[index]!=hand_drag.id:_cancel_hand_drag();return
		hand_drag.active=true;hand_drag.digest=Session.digest(session.model.snapshot());selected=index;source_lane=-1
		var card=session.card(hand_drag.id)
		for key in board_views:
			var view=board_views[key]
			var legal=card.kind!="relic" and target_allowed("hero" if str(key).begins_with("hero") else "enemy",int(view.lane))
			if legal:hand_drag.targets[key]=true
			view.target=legal;view.invalid_target=not legal;view.queue_redraw()
		if card.kind=="relic" and session.model.play_support("hero",index,0).is_empty() and actions.has("relic_slot"):
			hand_drag.targets.relic_slot=true;actions.relic_slot.disabled=false;actions.relic_slot.add_theme_stylebox_override("normal",T.panel(T.SUCCESS,T.SURFACE_RAISED))
		for i in hand_views.size():hand_views[i].selected=i==index;hand_views[i].queue_redraw()
		drag_ghost=CardView.new();drag_ghost.card=card;drag_ghost.color=S.color(card);drag_ghost.selected=true;drag_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;drag_ghost.size=Vector2(130,112);drag_ghost.modulate.a=.88;drag_ghost.z_index=110;layout.add_child(drag_ghost)
	if is_instance_valid(drag_ghost):drag_ghost.position=layout.get_global_transform().affine_inverse()*at-Vector2(65,104)
	get_viewport().set_input_as_handled()
func _drag_release(at: Vector2, pointer: int, canceled: bool=false) -> void:
	if hand_drag.is_empty() or pointer!=int(hand_drag.pointer):return
	# DOM touchcancel becomes an ordinary release in Godot's Web adapter. The
	# capture-phase version is read here synchronously, before any play command.
	if canceled or _web_drag_cancel_version()!=int(hand_drag.web_cancel):
		get_viewport().set_input_as_handled();_cancel_hand_drag(true);return
	if not hand_drag.active:hand_drag.clear();return # Original tap-to-select still receives the release.
	get_viewport().set_input_as_handled()
	var index=int(hand_drag.index);var p: Dictionary=session.model.state.hero;var lane := -1
	var valid=not canceled and hand_drag.viewport==get_viewport_rect().size and index<p.hand.size() and p.hand[index]==hand_drag.id and Session.digest(session.model.snapshot())==hand_drag.digest
	if valid:
		for key in hand_drag.targets:
			if key=="relic_slot":
				if actions.has(key) and actions[key].get_global_rect().has_point(at):lane=0;break
			elif board_views.has(key) and board_views[key].get_global_rect().has_point(at):lane=int(board_views[key].lane);break
	_cancel_hand_drag()
	if valid and lane>=0:act("play",["hero",index,lane])
	else:message="Karte nicht ausgespielt. Wähle ein gültiges Ziel oder tippe die Karte an.";render()
func _cancel_hand_drag(redraw: bool=false) -> void:
	if hand_drag.is_empty():return
	var was_active=bool(hand_drag.active)
	if was_active:selected=int(hand_drag.previous)
	hand_drag.clear()
	if is_instance_valid(drag_ghost):drag_ghost.hide();drag_ghost.queue_free()
	drag_ghost=null
	if redraw and was_active:render()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:_cancel_hand_drag(true)
func _input(event: InputEvent) -> void:
	if OS.has_feature("web") and Time.get_ticks_msec()<rotation_block_until and event is InputEventScreenTouch:
		get_viewport().set_input_as_handled();return
	# Godot may synthesize a mouse event for touch and touch for mouse. Only the
	# original pointer owns a gesture; synthesized events keep ordinary taps working.
	if event.device==-1:return
	if event is InputEventScreenTouch:
		if event.pressed:_drag_press(event.position,event.index)
		else:_drag_release(event.position,event.index,event.canceled)
	elif event is InputEventScreenDrag:_drag_move(event.position,event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_drag_press(event.position,-2)
		else:_drag_release(event.position,-2)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:_drag_move(event.position,-2)

func battle_heading(s: Dictionary) -> String:
	if mode=="alpha" and s.stage!="battle":return {"mulligan":"STARTHAND WÄHLEN","origins":"URSPRUNG WÄHLEN","second":"ZWEITE MÖGLICHKEIT"}.get(s.stage,"VORBEREITUNG")
	return ("PARTIE BEENDET" if s.winner!=null else "DEIN ZUG" if s.active=="hero" else "KI AM ZUG")+" · "+{"draw":"NACHZIEHEN","main":"AKTIONSPHASE","attack":"ANGRIFFE","end":"ZUGENDE"}.get(s.hero.phase,"VORBEREITUNG")+" · Runde %d" % (floori(float(s.round-1)/2)+1)
