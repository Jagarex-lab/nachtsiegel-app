extends Control
const S=preload("res://scripts/alpha/style.gd")
const T=preload("res://scripts/ui_tokens.gd")
const Session=preload("res://scripts/alpha/session.gd")
const AlphaCatalog=preload("res://scripts/production/catalog.gd")
const LegacyCatalog=preload("res://scripts/legacy/catalog.gd")
const CardView=preload("res://scripts/alpha/card_view.gd")
const FullCardFace=preload("res://scripts/card_system/card_face.gd")
const ArtQualityLabel=preload("res://scripts/production/art_quality_label.gd")
const LibraryFilter=preload("res://scripts/card_system/library_filter.gd")
const PresentationAudio=preload("res://scripts/audio/presentation_audio.gd")
const AudioSettings=preload("res://scripts/audio/audio_settings_panel.gd")
const BattleLayout=preload("res://scripts/premium/battle_layout.gd")
const ArenaStage=preload("res://scripts/premium/arena_stage.gd")
var audio_events=PresentationAudio.new()
var audio_settings: VBoxContainer
var audio_context := ""
var audio_paused := false
var session=Session.new()
var services=preload("res://scripts/alpha/integrated_services.gd").new()
var duel_checkpoint=preload("res://scripts/premium/duel_checkpoint.gd").new()
var app_mode_version := -1
var checkpoint_poll := 0.0
var hosted_page: Control
var hosted_name := ""
var alpha_catalog=AlphaCatalog.new()
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
var hand_tap_epoch := 0
var hand_press_epoch := 0
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
var library_page := 0
var library_query_signature := ""
var library_visible_ids: Array=[]
var library_total := 0
var library_page_count := 1
var library_scroll: ScrollContainer
var library_scroll_position := 0
var message := "Lokale Testversion · keine Echtgeldfunktionen"
var layout: Control
var density := 1.0
var compact := false
var short_landscape := false
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
var inspector_rules: Label
var inspector_title: Label
var inspector_face: Control
var inspector_card_id := ""
var log_page := 0
var actions: Dictionary={}
var hand_views: Array=[]
var board_views: Dictionary={}
var hero_badges: Dictionary={}
var battle_surface: Control
var battle_board_host: Control
var battle_hand_host: Control
var battle_dock: VBoxContainer
var battle_header: HBoxContainer
var battle_stage: Control
var battle_geometry: Dictionary={}
var arena_mode := "spatial"
var arena_projection_active := false
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
	DisplayServer.window_set_title("ORAFOLD · Alpha 0.3 · Testbuild")
	if OS.has_feature("web"):
		density=maxf(1,float(JavaScriptBridge.eval("window.devicePixelRatio||1")));qa_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
		JavaScriptBridge.eval("document.title='ORAFOLD · Alpha 0.3';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD Alpha 0.3')")
	services.configure(session)
	duel_checkpoint.load_checkpoint()
	faction=session.profile.faction;difficulty=int(session.profile.difficulty)
	if OS.has_feature("legacy_ui_qa"):mode="legacy";faction="start"
	feedback=preload("res://scripts/alpha/feedback.gd").new();feedback.z_index=100;add_child(feedback)
	render()
func _process(delta: float) -> void:
	checkpoint_poll+=delta
	if checkpoint_poll>=.2:
		checkpoint_poll=0;_checkpoint_duel()
		if OS.has_feature("web"):
			var app_version=int(_web_app_state().get("version",0))
			if app_version!=app_mode_version:
				app_mode_version=app_version
				if page=="settings":render()
	_update_primary_readiness()
	if not hand_drag.is_empty() and Time.get_ticks_msec()-int(hand_drag.updated)>8000:_cancel_hand_drag(true)
	if first_frame:
		first_frame=false
		# Godot applies the project window title after the initial main scene's ready.
		DisplayServer.window_set_title("ORAFOLD · Alpha 0.3")
		if OS.has_feature("web"):JavaScriptBridge.eval("document.title='ORAFOLD · Alpha 0.3';document.querySelector('canvas')?.setAttribute('aria-label','ORAFOLD Alpha 0.3')")
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
	if pulse>0 and not session.profile.reduced_motion:draw_rect(Rect2(Vector2.ZERO,size),Color(.4,.8,1,pulse*.15),false,5)
func _clear() -> void:
	_cancel_hand_drag()
	if is_instance_valid(library_scroll):library_scroll_position=library_scroll.scroll_vertical
	library_scroll=null
	for child in body.get_children():body.remove_child(child);child.queue_free()
	var retained: Dictionary={}
	if is_instance_valid(modal):
		for key in actions:
			if is_instance_valid(actions[key]) and modal.is_ancestor_of(actions[key]):retained[key]=actions[key]
	actions=retained;hand_views.clear();board_views.clear();hero_badges.clear()
func row(parent: Node=null) -> HBoxContainer:
	if parent==null:parent=body
	var box=HBoxContainer.new();box.add_theme_constant_override("separation",5);parent.add_child(box);return box
func text(value: String, parent: Node=null, fs: int=14) -> Label:
	if parent==null:parent=body
	var label=Label.new();label.text=value;label.add_theme_font_size_override("font_size",fs);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func button(id: String, caption: String, callback: Callable, parent: Node=null, disabled_value: bool=false) -> Button:
	if parent==null:parent=body
	var b=Button.new();b.text=caption;b.custom_minimum_size=Vector2(44,44);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.disabled=disabled_value;_bind_press(b,callback);parent.add_child(b);actions[id]=b;return b
func _bind_press(control: BaseButton, callback: Callable) -> void:
	# Godot Web also reports canceled ordinary taps as releases. Let BaseButton
	# reset its held state, but never dispatch its action after DOM cancellation.
	var press={"version":0,"hand_epoch":0}
	control.mouse_entered.connect(func():_audio_event("card.hover" if control is CardView else "ui.hover"))
	control.button_down.connect(func():press.version=_web_drag_cancel_version();press.hand_epoch=hand_tap_epoch)
	control.pressed.connect(func():
		# A long portrait can still contain the release point after a drag. Godot
		# can dispatch a synthesized GUI release after the owned gesture ends;
		# it must never turn that drag into a second hand tap or an inspector.
		if control is CardView and control.get("display_role")=="hand":
			# Godot may deliver emulated mouse-up BEFORE the original touch-up
			# carries its canceled flag. Validate after that input packet, without
			# a timer/cooldown and without blocking the GUI's button-state reset.
			if session.model!=null:_dispatch_hand_press.call_deferred(weakref(control),callback,int(press.hand_epoch),int(press.version),weakref(session.model),session.commands.size())
			return
		if not OS.has_feature("web") or int(press.version)==_web_drag_cancel_version():
			if not control is CardView:_audio_event("ui.confirm")
			callback.call()
	)
func _dispatch_hand_press(control_ref: WeakRef, callback: Callable, captured_epoch: int, cancel_version: int, model_ref: WeakRef, command_count: int) -> void:
	var control=control_ref.get_ref()
	if control==null or not control.is_inside_tree() or control.is_queued_for_deletion() or is_instance_valid(modal):return
	if captured_epoch!=hand_tap_epoch or hand_press_epoch!=hand_tap_epoch:return
	if OS.has_feature("web") and cancel_version!=_web_drag_cancel_version():return
	if session.model!=model_ref.get_ref() or session.commands.size()!=command_count:return
	var index=hand_views.find(control)
	if session.model==null or index<0 or index>=session.model.state.hero.hand.size() or str(control.card.id)!=str(session.model.state.hero.hand[index]):return
	callback.call()
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
	if is_instance_valid(hosted_page):
		outer_margin.visible=false
		_sync_audio_context()
		return
	outer_margin.visible=true
	restore_search_focus=actions.has("search") and is_instance_valid(actions.search) and actions.search.has_focus()
	if restore_search_focus:search_caret=actions.search.caret_column
	_clear()
	_sync_audio_context()
	if is_instance_valid(modal):modal.visible=not (page=="battle" and (portrait or layout.size.y<248))
	if page=="lobby":lobby()
	elif page=="decks":deck_selection()
	elif page in ["builder","collection"]:builder()
	elif page=="settings":settings_page()
	elif page=="battle":
		if portrait or layout.size.y<248:rotation_page()
		else:battle()
	queue_redraw()
func lobby() -> void:
	var content=scroll()
	var center=CenterContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_child(center)
	var panel=VBoxContainer.new();panel.custom_minimum_size.x=minf(layout.size.x-24,520);panel.add_theme_constant_override("separation",8 if portrait else 4);center.add_child(panel)
	text("O R A F O L D",panel,32 if portrait else 26).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("ALPHA 0.3 · LOKALER TESTMODUS",panel,13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("Dein Deck · "+alpha_catalog.source.powers.get(faction,"Testprofil"),panel,16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var play=button("start","SPIELEN GEGEN KI  →",choose_match,panel)
	play.custom_minimum_size.y=58 if portrait else 48
	play.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("403623")))
	if duel_checkpoint.available:button("resume_duel","PARTIE FORTSETZEN",resume_duel,panel)
	elif not duel_checkpoint.issue.is_empty():text(duel_checkpoint.issue,panel,12)
	var grid=GridContainer.new();grid.columns=1 if portrait else 2;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",4);panel.add_child(grid)
	button("campaign","KAMPAGNE · ENTWURF",func():open_feature("campaign"),grid)
	button("builder","DECKBUILDER",func():open_cards(false),grid)
	button("collection","SAMMLUNG · 550 KARTEN",func():open_cards(true),grid)
	button("economy","BOOSTER & FORTSCHRITT",func():open_feature("economy"),grid)
	button("online","ONLINE · EIGENER TESTSERVER",func():open_feature("online"),grid)
	button("settings","EINSTELLUNGEN",func():page="settings";render(),grid)
	text("30 Karten · 30 Leben · vier freie Starterdecks",panel,13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var art_counts=CardView.ART.inventory_counts()
	var art_caption="%d individuelle Illustrationen" % int(art_counts.get("final",0))
	if int(art_counts.get("missing",550))>0:art_caption+=" · %d Konzeptplatzhalter" % int(art_counts.missing)
	text(art_caption+" · Spielstände und Bestände nur lokal",content,12)
	text("Alle Karten im Alpha-Test frei spielbar. Sammelfortschritt ist separat; keine Echtgeldkäufe.",content,12)
	if not session.profile_issues.is_empty():text("Lokale Daten: Wiederherstellungshinweise in Einstellungen.",content,12)

func open_feature(feature: String) -> void:
	if is_instance_valid(hosted_page):return
	close_modal()
	var paths={"campaign":"res://scenes/campaign_orafold/campaign_overview.tscn","economy":"res://scenes/economy/alpha550_panel.tscn","online":"res://scenes/online/online_lobby.tscn"}
	if not paths.has(feature):return
	hosted_page=load(paths[feature]).instantiate()
	hosted_name=feature
	if feature=="campaign":
		hosted_page.configure_host(session,services.reward_campaign)
		hosted_page.exit_requested.connect(close_feature)
	elif feature=="economy":
		hosted_page.configure(services.local_economy())
		hosted_page.back_requested.connect(close_feature)
	else:hosted_page.back_requested.connect(close_feature)
	page=feature
	hosted_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(hosted_page)
	render()

func close_feature() -> void:
	if is_instance_valid(hosted_page):
		# The exit signal can run inside Button.pressed. Keep its sender in the
		# tree until Godot finishes dispatching the current input event.
		hosted_page.hide()
		hosted_page.queue_free()
	hosted_page=null;hosted_name="";page="lobby"
	# Campaign presentation owns its music; discard the old menu cache.
	audio_context=""
	set_audio_paused(false)
	render()

func show_profile_issues() -> void:
	show_modal("LOKALE DATEN",func(box):
		for issue in session.profile_issues:text(str(issue),box,14)
	)
func open_cards(read_only: bool) -> void:
	collection_mode=mode;collection_only=read_only;save_key=faction;deck=current_deck()
	filter_power="all";filter_type="all";filter_cost="all";filter_rarity="all";filter_species="all";filter_sort="cost_asc";filter_text=""
	library_page=0;library_query_signature="";library_scroll_position=0
	page="collection" if read_only else "builder";render()
func save_preferences() -> void:
	if mode=="alpha":session.profile.faction=faction
	session.profile.difficulty=difficulty;session.save_profile()
func settings_page() -> void:
	var top=row();text("EINSTELLUNGEN",top,22);button("settings_back","Hauptmenü",func():page="lobby";render(),top)
	var box=scroll()
	button("settings_audio","Ton und Lautstärke",func():box.get_parent().ensure_control_visible(audio_settings.sliders.master),box)
	text("Starterdeck / gespeichertes Deck",box,18)
	if not session.profile_issues.is_empty():button("profile_recovery","Hinweise zur Wiederherstellung lokaler Daten",show_profile_issues,box)
	button("game_guide","Spielregeln und Touch-Bedienung",show_game_guide,box)
	if OS.has_feature("web"):
		var app=_web_app_state()
		var app_label="Web-App aktiv" if app.get("standalone",false) else "Im Browser"
		text("APP-MODUS · "+app_label,box,18)
		var app_buttons=VBoxContainer.new() if portrait else HBoxContainer.new()
		app_buttons.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(app_buttons)
		button("app_fullscreen","Vollbild beenden" if app.get("fullscreen",false) else "Vollbild" if app.get("fullscreenSupported",false) else "App-Modus",func():
			if _web_app_state().get("fullscreenSupported",false):JavaScriptBridge.eval("window.orafoldApp?.toggleFullscreen()")
			else:show_app_mode_help(),app_buttons)
		button("app_install","Installation / App-Modus",show_app_mode_help,app_buttons)
		if not str(app.get("status","")).is_empty():text(str(app.status),box,14)
	text("Eine laufende KI-Partie wird nach jedem Zug lokal für die Wiederaufnahme gesichert. Rotation und App-Wechsel ändern keine Spielregeln.",box,14)
	if not duel_checkpoint.issue.is_empty():text(duel_checkpoint.issue,box,14)
	if mode=="alpha":
		var power_row: HBoxContainer
		var power_index=0
		for power in alpha_catalog.deck_ids():
			if power_index%2==0:power_row=row(box)
			power_index+=1
			var b=button("faction_"+power,("● " if faction==power else "○ ")+alpha_catalog.source.powers[power],func():faction=power;save_preferences();render(),power_row)
			b.modulate=S.POWER_COLORS[power]
	var options=row(box)
	dropdown("difficulty",["Normal","Einfach","Taktisch"],"Einfach" if difficulty==1 else "Taktisch" if difficulty==5 else "Normal",func(v):difficulty={"Normal":2,"Einfach":1,"Taktisch":5}[v];save_preferences();render(),options)
	button("motion","Bewegung: "+("reduziert" if session.profile.reduced_motion else "normal"),func():session.profile.reduced_motion=not session.profile.reduced_motion;save_preferences();render(),options)
	if FileAccess.file_exists("user://orafold_last_replay.json"):button("last_replay","LETZTES REPLAY ÖFFNEN",load_last_replay,box)
	text("Deckwahl, Schwierigkeit und Bewegung werden lokal gespeichert. Keine Konten oder Käufe.",box,14)
	audio_settings=AudioSettings.new()
	audio_settings.name="AlphaSettings"
	audio_settings.bind_manager(get_node("/root/GameAudio"))
	box.add_child(audio_settings)
	for channel in audio_settings.sliders:
		actions["audio_"+channel]=audio_settings.sliders[channel]
	actions["audio_mute"]=audio_settings.mute_toggle
	actions["audio_reduced"]=audio_settings.reduced_toggle
func _web_app_state() -> Dictionary:
	if not OS.has_feature("web"):return {}
	var value: Variant=JavaScriptBridge.eval("JSON.stringify(window.orafoldApp?.state()||{})")
	var parsed: Variant=JSON.parse_string(value) if value is String else null
	return parsed if parsed is Dictionary else {}
func show_app_mode_help() -> void:
	var app=_web_app_state()
	show_modal("ORAFOLD ALS APP",func(box):
		text("iPhone / iPad: Öffne ORAFOLD in Safari. Tippe auf Teilen und dann auf Zum Home-Bildschirm. Aktiviere Als Web-App öffnen, wenn Safari diese Option zeigt. Starte anschließend über das ORAFOLD-Symbol.",box,16)
		text("Die installierte Web-App nutzt ihren eigenen App-Bereich. Für das Laden des Spiels und der Illustrationen ist eine Internetverbindung erforderlich. Speichere und öffne deine Partie möglichst immer im selben Browser beziehungsweise App-Modus.",box,14)
		text("Im Kampf drehst du das Gerät ins Querformat. Menüs und Deckbuilder sind auch im Hochformat bedienbar. Safari-Webseiten lassen sich auf iPhone nicht zuverlässig per Spielschaltfläche in echtes Vollbild zwingen.",box,14)
		if app.get("standalone",false):text("ORAFOLD läuft bereits als installierte Web-App.",box,16)
		elif app.get("installAvailable",false):button("app_install_confirm","ORAFOLD INSTALLIEREN",func():JavaScriptBridge.eval("window.orafoldApp?.install()"),box)
	)
func _checkpoint_duel() -> void:
	if session.model==null or is_instance_valid(hosted_page) or page!="battle":return
	duel_checkpoint.capture(session,{"faction":faction,"difficulty":difficulty})
func resume_duel() -> void:
	var restored: Dictionary=duel_checkpoint.restore_into(session)
	if not restored.get("ok",false):message=str(restored.get("error","Wiederaufnahme nicht möglich."));render();return
	var config: Dictionary=restored.get("ui",{})
	if config.get("faction") in alpha_catalog.deck_ids():faction=config.faction
	difficulty=int(session.setup.difficulty);mode="alpha";services.begin_duel()
	page="battle";selected=-1;source_lane=-1;action_mode="";convergence_lanes=[];mulligan_indices=[];opening_hand_signature=""
	audio_events.reset();set_audio_paused(false);message="Partie wieder aufgenommen. Wähle deine nächste Aktion.";render()
func show_game_guide() -> void:
	show_modal("ORAFOLD · ERSTE PARTIE",func(box):
		text("1 · Wähle eine Macht und ein gültiges 30-Karten-Deck. Beide Helden beginnen mit 30 Leben, die Starthand enthält 5 Karten.",box,16)
		text("2 · Auf dem Spielfeld markierst du Karten zum Tauschen und bestätigst die Starthand. Wähle dann einen Ursprungspfad: Die erste eigene Beschwörung dort erhält 1 Schild. Als zweiter Spieler kannst du zusätzlich einen Ursprung ändern und eine Handkarte tauschen.",box,16)
		text("3 · Bestätige zu Zugbeginn das Nachziehen. Wenn die Hand sonst mehr als 6 Karten enthält, wähle zuerst eine Karte zum Verbrennen aus.",box,16)
		text("4 · Tippe eine Handkarte und danach ein leuchtendes Ziel an. Erneutes Antippen der Karte öffnet ihre Details. Alternativ ziehst du sie zum Ziel. Außerhalb eines gültigen Ziels, bei Abbruch oder beim Drehen des Geräts wird keine Karte ausgespielt.",box,16)
		text("5 · Am Zugende greifen bereite Wesen auf ihrem Pfad an. Ist das direkt gegenüberliegende Feld leer, trifft der Angriff den gegnerischen Helden. Block absorbiert vor Schild und Leben. Neue Wesen warten normalerweise einen eigenen Angriffszug.",box,16)
		text("6 · Ab der sechsten Runde kannst du drei bereite, unbestrittene Pfade für Konvergenz markieren. Halte dieselben Wesen bis zum nächsten eigenen Zug. Der Gegner kann einen Pfad bestreiten, ein Wesen ausschalten oder die Bereitschaft unterbrechen.",box,16)
		button("guide_resources","Energie, Resonanz und Schlüsselwörter",resource_help,box)
	)
func current_deck() -> Array:
	var key=mode+":"+faction
	if session.profile.decks.has(key) and session.profile.decks[key] is Dictionary:
		var candidate: Dictionary=session.profile.decks[key]
		var ids: Variant=candidate.get("cards")
		var validation=alpha_catalog.validate(ids) if mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(ids)
		if validation.ok:return ids.duplicate()
	return alpha_catalog.deck(faction) if mode=="alpha" else LegacyCatalog.new().deck(faction)
func start_battle() -> void:
	audio_events.reset()
	set_audio_paused(false)
	var seed_value=int(session.profile.last_seed)+1
	var enemy=alpha_catalog.deck(["houses","stillwatch","morph","ninth"][(seed_value%4)]) if mode=="alpha" else []
	if not session.start_match(mode,alpha_catalog.deck(faction) if mode=="alpha" and match_use_starter else current_deck(),seed_value,difficulty,enemy):message="Ungültiges Deck.";render();return
	services.begin_duel()
	last_primary_ms=-1000
	page="battle";selected=-1;source_lane=-1;action_mode="";convergence_lanes=[];mulligan_indices=[];opening_hand_signature="";message="Wähle deine Starthand. Danach legst du den Ursprung fest.";render()
	_checkpoint_duel()
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
	var technical_failure=not reply.ok and bool(reply.get("accepted",false))
	message="Partie angehalten: "+str(session.model.state.get("error","Effektauflösung fehlgeschlagen.")) if technical_failure else names.get(command,"Aktion ausgeführt.") if reply.ok else "Bedingungen fehlen: Energie, Resonanz, gültiges Ziel oder eine noch offene Auswahl prüfen."
	if reply.ok:
		for sound in audio_events.collect(session.model.events.slice(event_offset),before,session.model.catalog):
			_audio_event(sound.event,sound.context)
		selected=-1;source_lane=-1;action_mode="";pulse=.5
		call_deferred("_feedback_events",session.model.events.slice(event_offset),before)
	render()
	if not reply.ok:_audio_event("ui.error")
	_sync_audio_context()
	_checkpoint_duel()
	if technical_failure:show_engine_error()
	elif session.model.state.winner!=null:
		services.reward_completed_duel()
		result_dialog()
func battle() -> void:
	var s: Dictionary=session.model.state
	battle_surface=Control.new();battle_surface.name="PremiumBattle";battle_surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_surface.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(battle_surface)
	battle_surface.resized.connect(_fit_battle)
	var glass=Panel.new();glass.name="HudGlass";glass.mouse_filter=Control.MOUSE_FILTER_IGNORE;glass.add_theme_stylebox_override("panel",T.panel(Color("43516a"),Color("0b1422")));battle_surface.add_child(glass)
	battle_header=row(battle_surface);battle_header.add_theme_constant_override("separation",8)
	var menu_button=button("menu","≡",confirm_menu,battle_header);menu_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;menu_button.custom_minimum_size.x=44;menu_button.tooltip_text="Partie und Hauptmenü"
	_battle_hero_badge(battle_header,"DU",s.hero,T.PLAYER)
	var heading=VBoxContainer.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_theme_constant_override("separation",0);battle_header.add_child(heading)
	var turn=text(_turn_caption(s),heading,15);turn.add_theme_color_override("font_color",T.GOLD if s.active=="hero" else T.FOE);turn.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var phase=text(_phase_caption(s),heading,11);phase.add_theme_color_override("font_color",T.MUTED);phase.tooltip_text=battle_heading(s)
	var resource_caption=("Energie %d / 8" if mode=="alpha" else "Energie %d") % s.hero.energy
	var resource=button("resources",resource_caption+"\nResonanz %d / 15" % s.hero.resonance,resource_help,battle_header);resource.custom_minimum_size.x=140;resource.size_flags_horizontal=Control.SIZE_SHRINK_END;resource.add_theme_font_size_override("font_size",13);resource.add_theme_color_override("font_color",T.ENERGY);resource.tooltip_text="Energie bezahlt Karten. Resonanz bleibt gespeichert und bezahlt besondere Eingriffe. Antippen: Erklärung."
	if mode=="alpha" and s.stage=="battle":_relic_slot(battle_header)
	_battle_hero_badge(battle_header,"KI",s.enemy,T.FOE)
	battle_board_host=Control.new();battle_board_host.name="FivePaths";battle_surface.add_child(battle_board_host)
	battle_stage=null
	battle_stage=ArenaStage.new();battle_stage.set("mode",arena_mode);battle_stage.set("origins",s.get("origins",{}));battle_board_host.add_child(battle_stage)
	if mode=="alpha" and s.stage=="battle":
		var controlled={"hero":[],"enemy":[]}
		for side in ["hero","enemy"]:
			for lane in 5:
				if session.model.controlled(side,lane):controlled[side].append(lane)
		battle_stage.set("controlled",controlled)
	battle_hand_host=Control.new();battle_hand_host.name="IllustratedHand";battle_surface.add_child(battle_hand_host)
	var dock_glass=Panel.new();dock_glass.name="DockGlass";dock_glass.mouse_filter=Control.MOUSE_FILTER_IGNORE;dock_glass.add_theme_stylebox_override("panel",T.panel(Color("43516a"),Color("0b1422")));battle_surface.add_child(dock_glass)
	battle_dock=VBoxContainer.new();battle_dock.name="ActionDock";battle_dock.add_theme_constant_override("separation",3);battle_surface.add_child(battle_dock)
	if mode=="alpha" and s.stage!="battle":opening()
	else:
		_battle_board()
		_build_hand(false)
		_combat_dock()
	if arena_mode=="three_d":
		var projected: Array=[]
		for side in ["enemy","hero"]:
			for lane in 5:
				var view=board_views[side+str(lane)]
				projected.append({"side":side,"lane":lane,"card":view.card,"unit":view.unit,"target":view.target,"invalid_target":view.invalid_target,"selected":view.selected,"combat_ready":view.combat_ready,"attack_penalty":view.attack_penalty,"convergence":view.convergence,"broken_convergence":view.broken_convergence,"reduced_motion":bool(session.profile.reduced_motion)})
		battle_stage.configure(projected)
	_fit_battle()
	call_deferred("_fit_battle")

func select_presentation_variant(value: String) -> bool:
	# Used by the runnable comparison scenes, never a rules/profile switch.
	if value not in ["flat","spatial","three_d"]:return false
	_cancel_hand_drag(true);arena_mode=value;render();return true

func _battle_hero_badge(parent: Node, title: String, player: Dictionary, hue: Color) -> void:
	var badge=VBoxContainer.new();badge.custom_minimum_size.x=110;badge.add_theme_constant_override("separation",0);parent.add_child(badge)
	hero_badges["hero" if title=="DU" else "enemy"]=badge
	var life=text("%s · %d LP" % [title,player.hp],badge,18);life.add_theme_color_override("font_color",hue)
	var defense=text("Schild %d · Block %d" % [player.ward,player.block],badge,11);defense.add_theme_color_override("font_color",T.TEXT)
	badge.tooltip_text="%s: %d Leben, %d Schild, %d Block. Schaden verbraucht zuerst Block, dann Schild, dann Leben." % [title,player.hp,player.ward,player.block]
	if player.get("relic")!=null:badge.tooltip_text+="\nRelikt: "+str(session.card(player.relic.id).name)

func _turn_caption(s: Dictionary) -> String:
	if mode=="alpha" and s.stage!="battle":return {"mulligan":"DEINE STARTHAND","origins":"DEIN URSPRUNG","second":"ZWEITE MÖGLICHKEIT"}.get(s.stage,"VORBEREITUNG")
	if not str(s.get("error","")).is_empty():return "PARTIE ANGEHALTEN"
	if s.winner!=null:return "PARTIE BEENDET"
	return ("DEIN ZUG" if s.active=="hero" else "KI AM ZUG")+" · "+str(floori(float(s.round-1)/2)+1)

func _phase_caption(s: Dictionary) -> String:
	if mode=="alpha" and s.stage!="battle":return {"mulligan":"1 / 3 · Austauschen oder behalten","origins":"2 / 3 · Einen eigenen Pfad wählen","second":"3 / 3 · Optionaler Startausgleich"}.get(s.stage,"")
	if s.hero.pendingTarget!=null:return "Ankunft · Gegnerisches Ziel wählen"
	if s.hero.pendingShift!=null:return "Pfadwechsel · Markiertes Ziel wählen"
	if action_mode=="converge":return "Konvergenz · Drei freie Pfade binden"
	return {"draw":"NACHZIEHEN","main":"AKTIONEN · Angriffe am Zugende","attack":"ANGRIFFE","end":"ZUGENDE"}.get(s.hero.phase,"VORBEREITUNG")

func _fit_battle() -> void:
	if not is_instance_valid(battle_surface) or page!="battle":return
	var available=battle_surface.size
	if available.x<100 or available.y<100:
		var margin=4.0 if compact else 8.0
		available=layout.size-Vector2(margin*2,margin*2)
	battle_geometry=BattleLayout.measure(available,hand_views.size(),selected)
	var header: Rect2=battle_geometry.header;var board: Rect2=battle_geometry.board
	battle_header.position=header.position;battle_header.size=header.size
	var glass=battle_surface.get_node_or_null("HudGlass")
	if glass!=null:glass.position=header.position;glass.size=header.size
	battle_board_host.position=board.position;battle_board_host.size=board.size
	if is_instance_valid(battle_stage):battle_stage.position=Vector2.ZERO;battle_stage.size=board.size
	var projected_slots: Dictionary={}
	arena_projection_active=arena_mode=="three_d"
	if arena_projection_active:
		var occupied: Array=[]
		for side in ["enemy","hero"]:
			for lane in 5:
				var slot: Rect2=battle_stage.projected_card_rect(side,lane)
				if slot.size.x<44 or slot.size.y<44 or not Rect2(Vector2.ZERO,board.size).grow(.1).encloses(slot):arena_projection_active=false
				for previous in occupied:
					if slot.intersects(previous):arena_projection_active=false
				occupied.append(slot);projected_slots[side+str(lane)]=slot
	for key in board_views:
		var view=board_views[key]
		var side="hero" if str(key).begins_with("hero") else "enemy"
		var slot=projected_slots[key] if arena_projection_active else ArenaStage.slot_rect(side,view.lane,Rect2(Vector2.ZERO,board.size),arena_mode)
		view.position=slot.position;view.size=slot.size
		# The developer-only3D variant draws the same faces on actual meshes.
		# Upright transparent controls provide their exact projected hit bounds.
		view.self_modulate.a=0.0 if arena_projection_active else 1.0
	var rail: Rect2=battle_geometry.hand
	battle_hand_host.position=rail.position;battle_hand_host.size=rail.size
	for index in hand_views.size():
		var view=hand_views[index]
		var tile=BattleLayout.hand_rect(battle_geometry,index,hand_views.size(),selected==index)
		view.position=tile.position-rail.position;view.size=tile.size;view.z_index=4 if selected==index else 1
	var dock: Rect2=battle_geometry.dock
	var dock_glass=battle_surface.get_node_or_null("DockGlass")
	if dock_glass!=null:dock_glass.position=dock.position;dock_glass.size=dock.size
	if is_instance_valid(status):status.visible=dock.size.y>=120
	battle_dock.position=dock.position+Vector2(4,0);battle_dock.size=dock.size-Vector2(8,0)

func _build_hand(preparing: bool=false) -> void:
	var s: Dictionary=session.model.state
	var signature=JSON.stringify(s.hero.hand)
	var animate=preparing and signature!=opening_hand_signature and not session.profile.reduced_motion
	if preparing:opening_hand_signature=signature
	for index in s.hero.hand.size():
		var view=CardView.new();view.card=session.card(s.hero.hand[index]);view.color=S.color(view.card);view.set("display_role","hand");view.set("reduced_motion",bool(session.profile.reduced_motion));view.selected=selected==index or preparing and s.stage=="mulligan" and mulligan_indices.has(index)
		var availability=_card_availability(index)
		view.set("availability_shown",not preparing);view.set("playable",bool(availability.playable));view.set("unavailable_reason",str(availability.reason))
		view.custom_minimum_size=Vector2(44,44)
		view.tooltip_text=view.card.name+"\n"+str(view.card.get("description",""))+"\n"+("Ausspielbar · leuchtendes Ziel wählen" if availability.playable else str(availability.reason))+"\nAntippen: auswählen · nochmals antippen oder Details: ganze Karte"
		_bind_press(view,func():_opening_hand_click(index) if preparing else _hand_click(index));battle_hand_host.add_child(view);hand_views.append(view)
		if preparing and s.stage=="mulligan":
			actions["mulligan_"+str(index)]=view
			if mulligan_indices.has(index):
				var ribbon=PanelContainer.new();ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE;ribbon.add_theme_stylebox_override("panel",T.panel(T.GOLD,Color("172532")));view.add_child(ribbon)
				ribbon.anchor_left=.05;ribbon.anchor_right=.95;ribbon.anchor_top=.40;ribbon.anchor_bottom=.57
				var mark=Label.new();mark.text="↻ TAUSCH";mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mark.add_theme_font_size_override("font_size",11);mark.add_theme_color_override("font_color",T.GOLD);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;ribbon.add_child(mark)
		elif preparing and s.stage=="second":actions["second_card_"+str(index)]=view
		if animate:
			view.modulate.a=.35
			var deal=view.create_tween();deal.tween_property(view,"modulate:a",1.0,.16).set_delay(index*.025)

func _card_availability(index: int) -> Dictionary:
	var s: Dictionary=session.model.state;var p: Dictionary=s.hero
	if mode=="alpha" and s.stage!="battle":return {"playable":false,"reason":"Vorbereitung · Karte lesen oder zum Tauschen markieren"}
	if s.winner!=null or not str(s.get("error","")).is_empty():return {"playable":false,"reason":"Diese Partie ist beendet oder angehalten"}
	if s.active!="hero":return {"playable":false,"reason":"Die KI ist am Zug"}
	if p.pendingTarget!=null or p.pendingShift!=null:return {"playable":false,"reason":"Löse zuerst die markierte Zielauswahl"}
	if p.phase!="main":return {"playable":false,"reason":"Bestätige zuerst das Nachziehen"}
	var c=session.card(p.hand[index])
	if int(c.cost)>int(p.energy):return {"playable":false,"reason":"Es fehlen %d Energie" % (int(c.cost)-int(p.energy))}
	if int(c.get("resonance_cost",0))>int(p.resonance):return {"playable":false,"reason":"Es fehlt Resonanz"}
	for lane in 5:
		if session.model.play_support("hero",index,lane).is_empty():return {"playable":true,"reason":"Ausspielbar"}
	return {"playable":false,"reason":"Kein gültiges Ziel · Details erklärt die Bedingungen"}

func _dock_context(caption: String) -> void:
	status=text(caption,battle_dock,12);status.size_flags_vertical=Control.SIZE_EXPAND_FILL;status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;status.max_lines_visible=2;status.tooltip_text=caption
	status.add_theme_color_override("font_color",T.GOLD if selected>=0 else T.TEXT)

func _dock_tools(preparing: bool=false) -> void:
	var tools=row(battle_dock)
	button("inspect","Details",func():if selected>=0:inspect(session.card(session.model.state.hero.hand[selected])),tools,selected<0).add_theme_font_size_override("font_size",12)
	var more=button("actions","Mehr …"+(" !" if not _duel_save_issue().is_empty() else ""),show_actions,tools);more.add_theme_font_size_override("font_size",12)
	if not _duel_save_issue().is_empty():more.add_theme_color_override("font_color",T.WARNING);more.tooltip_text="Die laufende Partie konnte zuletzt nicht lokal gesichert werden. Mehr zeigt den Grund."
	if not preparing and (selected>=0 or not action_mode.is_empty()):
		var cancel=button("cancel_selection","×",cancel_selection,tools);cancel.size_flags_horizontal=Control.SIZE_SHRINK_END;cancel.tooltip_text="Auswahl aufheben"

func _combat_dock() -> void:
	var s: Dictionary=session.model.state
	var overflow: bool=s.hero.phase=="draw" and s.hero.hand.size()+mini(int(s.hero.pendingDraw),s.hero.deck.size())>6
	var pending_shift=s.hero.pendingShift!=null
	var picking=selected>=0 and s.hero.phase=="main" and not pending_shift
	var context=phase_message()
	if selected>=0:
		var chosen=session.card(s.hero.hand[selected])
		context=str(chosen.name)+(" · zum Verbrennen gewählt" if overflow else " · markiertes Ziel antippen")
		if not overflow:
			var availability=_card_availability(selected)
			if not availability.playable:context=str(availability.reason)
	elif s.hero.pendingTarget==null and s.hero.pendingShift==null and action_mode.is_empty():context="Handkarte wählen · Details durch erneutes Antippen" if s.hero.phase=="main" else "Ziehe deine Karten, dann beginnt die Aktionsphase."
	if mode=="alpha" and s.enemy.get("convergence")!=null and selected<0 and action_mode.is_empty():context="KI-Konvergenz: markierten Gegenpfad bestreiten!" if not s.enemy.convergence.broken else "KI-Konvergenz unterbrochen."
	if message.begins_with("Ungültiges Ziel"):context=message
	_dock_context(context)
	_dock_tools()
	var caption="WECHSEL AUSLASSEN" if pending_shift else "KONVERGENZ %d / 3" % convergence_lanes.size() if action_mode=="converge" else "ZIEL WÄHLEN" if s.hero.pendingTarget!=null or picking else "KARTE VERBRENNEN" if overflow else "NACHZIEHEN  →" if s.hero.phase=="draw" else "ZUG BEENDEN  →"
	if s.active!="hero":caption="KI AM ZUG"
	var blocked=not str(s.get("error","")).is_empty() or s.winner!=null or s.active!="hero" or overflow and selected<0 or s.hero.pendingTarget!=null or picking or action_mode=="converge" and convergence_lanes.size()!=3
	var primary=button("end",caption,func():act("skipShift",["hero"]) if pending_shift else convergence_action() if action_mode=="converge" else act("burn",["hero",selected]) if overflow else act("finishDraw",["hero"]) if s.hero.phase=="draw" else act("endTurn",["hero"]),battle_dock,blocked)
	primary.size_flags_vertical=Control.SIZE_EXPAND_FILL
	primary.add_theme_font_size_override("font_size",14);primary.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("463422")));primary.set_meta("rule_blocked",blocked);primary_ref=weakref(primary);_update_primary_readiness()
	if action_mode=="converge":actions.convergence=primary
	if pending_shift:actions.skip=primary

func _battle_board(preparing: bool=false) -> void:
	# The opening and combat use these exact ten upright lane hit rectangles.
	var m=session.model;var s: Dictionary=m.state
	for side in ["enemy","hero"]:
		for lane in 5:
			var u: Variant=s[side].lanes[lane];var view=CardView.new();view.lane=lane;view.owner_label="KI" if side=="enemy" else "DU";view.color=T.FOE if side=="enemy" else T.PLAYER;view.set("display_role","board");view.set("reduced_motion",bool(session.profile.reduced_motion))
			if u!=null:view.card=session.card(u.id);view.unit=u;view.combat_ready=m.can_fight(side,lane) if mode=="alpha" else int(u.stun)==0 and (not u.summoned or view.card.effect=="haste")
			view.attack_penalty=int(s[side].get("weak",0));view.origin=mode=="alpha" and s.origins[side]==lane;view.custom_minimum_size=Vector2(44,44)
			view.selected=convergence_lanes.has(lane) and side=="hero" or source_lane==lane and side=="hero"
			if u!=null:view.tooltip_text="%s · Angriff %d · Leben %d · Schild %d · Block %d · Stasis %d\n%s" % [view.card.name,view.current_attack(),int(u.hp),int(u.get("ward",0)),int(u.get("block",0)),int(u.get("stun",0)),"Angriffsbereit" if view.combat_ready else "Noch nicht angriffsbereit"]
			if preparing:
				view.target=side=="hero" and (s.stage=="origins" or s.stage=="second" and not s.second_path);view.disabled=not view.target
				view.tooltip_text="Ursprung auf Pfad %d wählen" % (lane+1) if view.target else "Dein Pfad %d" % (lane+1) if side=="hero" else "Gegnerischer Pfad %d" % (lane+1)
				if side=="hero" and s.stage in ["origins","second"]:actions[("origin_" if s.stage=="origins" else "second_origin_")+str(lane)]=view
				_bind_press(view,func():_opening_lane_click(side,lane))
			else:
				view.target=target_allowed(side,lane);view.invalid_target=selected>=0 and not view.target and s.hero.phase=="main"
				if mode=="alpha" and s[side].convergence!=null and s[side].convergence.lanes.has(lane):view.convergence=not s[side].convergence.broken;view.broken_convergence=bool(s[side].convergence.broken)
				_bind_press(view,func():field_click(side,lane))
			battle_board_host.add_child(view);board_views[side+str(lane)]=view
func armed_impulses() -> Array:
	if session.model!=null and session.model.has_method("armed_impulses"):return session.model.armed_impulses("hero")
	return []
func show_armed_impulses() -> void:
	show_modal("BEREITE REAKTIONEN",func(box):
		text("Reaktive Impulse warten nach dem Ausspielen auf ihren Auslöser. Es sind höchstens drei gleichzeitig bereit. Nicht ausgelöste Impulse verfallen zu deinem nächsten eigenen Zugbeginn.",box,16)
		for armed in armed_impulses():
			var card=session.card(str(armed.id))
			text(str(card.name),box,20)
			text(str(card.get("description","")),box,16)
			text("Vorgemerkter Pfad %d" % (int(armed.get("lane",0))+1),box,13)
	)
func _relic_slot(parent: Node) -> void:
	var p: Dictionary=session.model.state.hero
	var chosen=selected>=0 and selected<p.hand.size() and session.card(p.hand[selected]).kind=="relic"
	var allowed=chosen and session.model.play_support("hero",selected,0).is_empty()
	var slot=button("relic_slot","RELIKT\n"+("ERSETZEN" if p.relic!=null else "AUSLEGEN") if chosen else "RELIKT\n"+("AKTIV" if p.relic!=null else "FREI"),func():
		if chosen and allowed:act("play",["hero",selected,0])
		elif p.relic!=null:inspect(session.card(p.relic.id))
	,parent,not allowed and p.relic==null)
	slot.size_flags_horizontal=Control.SIZE_SHRINK_END;slot.custom_minimum_size.x=68;slot.add_theme_font_size_override("font_size",10)
	slot.tooltip_text="Ein Relikt aktiv. Ein neues Relikt ersetzt das vorige; das vorige wird abgelegt."+("\n"+session.card(p.relic.id).name if p.relic!=null else "")
	if allowed:slot.add_theme_stylebox_override("normal",T.panel(T.SUCCESS,T.SURFACE_RAISED))
func phase_message() -> String:
	if not str(session.model.state.get("error","")).is_empty():return "Partie angehalten. Protokoll sichern, neu starten oder zum Menü zurückkehren."
	var p: Dictionary=session.model.state.hero
	if p.pendingTarget!=null:return "Ankunftsschlag: tippe eine gegnerische Kreatur an."
	if p.phase=="draw":return "Nachziehen: bei Handüberlauf zuerst eine Karte auswählen und verbrennen. Sonst Nachziehen bestätigen."
	if p.pendingShift!=null:return "Pfadwechsel: Nachbarwesen, dann freies Ziel wählen." if source_lane<0 else "Nun ein freies Nachbarfeld antippen."
	if action_mode=="converge":return "Wähle drei kampffähige unbestrittene Pfade, dann Erklären."
	if mode=="alpha" and session.model.state.enemy.convergence!=null and selected<0:return "KI-Konvergenz unterbrochen." if session.model.state.enemy.convergence.broken else "KI-Konvergenz: einen markierten Pfad bestreiten oder eine gebundene Kreatur ausschalten."
	return message
func target_allowed(side: String, lane: int) -> bool:
	var m=session.model;var p: Dictionary=m.state.hero
	if m.state.winner!=null or m.state.active!="hero" or not str(m.state.get("error","")).is_empty():return false
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
	var c=session.card(p.hand[selected])
	if c.kind=="relic":return false # Separate permanent slot, never a creature path.
	return side==card_target_side(c) and m.play_support("hero",selected,lane).is_empty()
func card_target_side(card: Dictionary) -> String:
	if session.model!=null and session.model.has_method("target_side_for_card"):
		return "enemy" if session.model.target_side_for_card(card)=="enemy" else "hero"
	return "enemy" if mode=="alpha" and card.get("effect","") in ["bolt","stasis","delay","redirect","displace"] else "hero"
func relic_activation_cost() -> Dictionary:
	if session.model!=null and session.model.has_method("relic_activation_cost"):return session.model.relic_activation_cost("hero")
	return {"energy":1,"resonance":0}
func relic_can_activate() -> bool:
	if session.model==null or mode!="alpha":return false
	if session.model.has_method("can_activate_relic"):return session.model.can_activate_relic("hero")
	var state: Dictionary=session.model.state;var p: Dictionary=state.hero
	return state.active=="hero" and state.winner==null and p.phase=="main" and p.pendingTarget==null and p.pendingShift==null and p.relic!=null and not p.relic_used and p.energy>=1
func relic_cost_caption() -> String:
	var cost=relic_activation_cost()
	return "%d Energie%s" % [int(cost.get("energy",0))," + %d Resonanz" % int(cost.get("resonance",0)) if int(cost.get("resonance",0))>0 else ""]
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
		else:_audio_event("ui.error");message="Ungültiges Ziel · Leuchtenden Pfad wählen.";render()
	elif m.state[side].lanes[lane]!=null:
		var detail: Dictionary=m.state[side].lanes[lane].duplicate(true)
		detail.display_attack=maxi(0,int(detail.atk)-int(m.state[side].get("weak",0)))
		detail.attack_penalty=int(m.state[side].get("weak",0))
		inspect(session.card(detail.id),detail)
func hand_height_for_viewport(_preparing: bool=false) -> int:
	var margin=4.0 if compact else 8.0
	return floori(BattleLayout.measure(layout.size-Vector2(margin*2,margin*2),6).card_size.y)
func opening() -> void:
	var s: Dictionary=session.model.state
	_battle_board(true)
	_build_hand(true)
	var instructions={"mulligan":"Tippe Karten zum Tauschen an. Details zeigt die ganze Karte.","origins":("Du beginnst · " if s.coin=="hero" else "KI beginnt · ")+"Ursprung: erstes Wesen erhält 1 Schild.","second":"Optional: Ursprung ändern + eine Handkarte tauschen."}
	_dock_context(instructions.get(s.stage,"Vorbereitung"))
	_dock_tools(true)
	if s.stage=="mulligan":
		var primary=button("mulligan_done","%d TAUSCHEN  →" % mulligan_indices.size() if not mulligan_indices.is_empty() else "HAND BEHALTEN  →",func():act("mulligan",[mulligan_indices]),battle_dock)
		primary.size_flags_vertical=Control.SIZE_EXPAND_FILL
		primary.add_theme_font_size_override("font_size",14);primary.add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("463422")))
	elif s.stage=="origins":
		var hint=text("URSPRUNG · PFAD 1–5",battle_dock,13);hint.custom_minimum_size.y=44;hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",T.ENERGY)
	else:
		var row_actions=row(battle_dock)
		row_actions.size_flags_vertical=Control.SIZE_EXPAND_FILL
		button("second_exchange","TAUSCHEN" if not s.second_card else "GETAUSCHT ✓",func():act("secondCard",[selected]),row_actions,s.second_card or selected<0).add_theme_font_size_override("font_size",11)
		button("opening_done","KAMPF  →",func():act("openingDone",[]),row_actions).add_theme_stylebox_override("normal",T.panel(T.GOLD,Color("463422")))
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
	var usable: bool=session.model.state.active=="hero" and session.model.state.winner==null and p.phase=="main" and str(session.model.state.get("error","")).is_empty()
	var pending: bool=p.pendingTarget!=null or p.pendingShift!=null
	var friends=0
	var moves=false
	for lane in 5:
		if p.lanes[lane]==null:continue
		friends+=1
		for to in [lane-1,lane+1]:
			if to>=0 and to<5 and p.lanes[to]==null:moves=true
	show_modal("RESSOURCEN / SONDERAKTIONEN",func(box):
		var navigation=row(box)
		button("log","Protokoll / Replay",show_log,navigation)
		button("restart","Neue Partie",func():show_modal("Neue Partie?",func(confirm):button("confirm_restart","Neu starten",func():close_modal();start_battle(),confirm)),navigation)
		text("Energie %d · Resonanz %d/15" % [p.energy,p.resonance],box,22)
		text("Nachziehstapel %d · Ablage %d · Hand %d/6" % [p.deck.size(),p.discard.size(),p.hand.size()],box,14)
		if not _duel_save_issue().is_empty():text("Fortsetzen noch nicht gesichert: "+_duel_save_issue()+" Die Partie bleibt spielbar. Ein Seitenneustart kann den letzten Zug verlieren.",box,14).add_theme_color_override("font_color",T.WARNING)
		if not armed_impulses().is_empty():button("armed_impulses","Bereite Reaktionen · %d" % armed_impulses().size(),show_armed_impulses,box)
		button("resource_help","Energie, Resonanz und Schlüsselwörter erklärt",resource_help,box)
		if mode=="alpha":button("convergence","Konvergenz · drei unbestrittene bereite Pfade",func():close_modal();convergence_action(),box,not usable or pending or int(session.model.state.round)<11)
		button("recover",res_caption("Rückholung",5),func():close_modal();act("recover",["hero"]),box,not usable or p.cycled or p.resonance<5 or p.hand.size()>=6 or p.discard.is_empty())
		button("move",res_caption("Pfadmanöver",3),func():close_modal();selected=-1;action_mode="move";source_lane=-1;message="Eigene Kreatur, dann freien Nachbarpfad wählen.";render(),box,not usable or pending or p.tacticUsed or p.resonance<3 or not moves)
		button("fortify",res_caption("Pfadwacht",2),func():close_modal();selected=-1;action_mode="fortify";message="Markierte eigene Kreatur wählen.";render(),box,not usable or pending or p.fortifyUsed or p.resonance<2 or friends==0)
		if mode=="alpha":
			button("relic","Relikt aktivieren · "+relic_cost_caption(),func():close_modal();act("activateRelic",["hero"]),box,not usable or pending or not relic_can_activate())
			text("Aktives Relikt: "+(session.card(p.relic.id).name if p.relic!=null else "keines"),box)
		for order in ([faction] if mode=="alpha" else ["ash","tide","thorn","veil"]):
			var matching=0
			for u in p.lanes:
				if u!=null and session.card(u.id).order==order:matching+=1
			if mode=="alpha":text(S.burst_description(order)+" n = eigene Kreaturen dieser Macht.",box,14)
			button("burst_"+order,str(alpha_catalog.source.powers.get(order,order.to_upper()))+" entfesseln\n15 benötigt · verbraucht 8 Resonanz",func():close_modal();act("burst",["hero",order]),box,not usable or int(p.resonance)<15 or p.burstUsed or matching==0)
	)
func _duel_save_issue() -> String:
	# The PWA controller owns persistence. This view reads an optional issue;
	# opening/closing a sheet must never retry a write or request a render loop.
	for property in get_property_list():
		if property.name=="duel_checkpoint":
			var checkpoint=get("duel_checkpoint")
			return str(checkpoint.get("issue")) if checkpoint!=null else ""
	return ""
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
	modal=PanelContainer.new();modal.z_index=200;modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_theme_stylebox_override("panel",T.panel(T.GOLD,Color("08111c")));layout.add_child(modal)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",16);margin.add_theme_constant_override("margin_right",16);margin.add_theme_constant_override("margin_top",8);margin.add_theme_constant_override("margin_bottom",8);modal.add_child(margin)
	var box=VBoxContainer.new();margin.add_child(box)
	var top=row(box);text(title,top,18);button("modal_close","ZURÜCK",close_modal,top).size_flags_horizontal=Control.SIZE_SHRINK_END
	var content_box=scroll(box);content.call(content_box)
func close_modal() -> void:
	set_audio_paused(false)
	modal_version+=1
	if is_instance_valid(modal):modal.hide();modal.queue_free()
	modal=null;inspector_rules=null;inspector_title=null;inspector_face=null;inspector_card_id=""
func inspect(c: Dictionary, current: Dictionary={}) -> void:
	_audio_event("card.enlarge",{"faction":c.get("faction",c.get("order","neutral")),"rarity":c.get("rarity","common")})
	show_modal(str(c.get("name",c.id)),func(box):
		# Every orientation gets the canonical portrait face. The adjacent readable
		# rules column reflows below it on portrait rotation without closing or
		# rebuilding the inspected card, selection or model.
		var composition=BoxContainer.new();composition.add_theme_constant_override("separation",18);composition.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(composition)
		var portrait_wrap=Control.new();portrait_wrap.mouse_filter=Control.MOUSE_FILTER_IGNORE;composition.add_child(portrait_wrap)
		var full_card=FullCardFace.new();full_card.card=c;full_card.set("reduced_motion",bool(session.profile.reduced_motion));portrait_wrap.add_child(full_card)
		inspector_face=full_card
		var details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",8);composition.add_child(details)
		var fit=func():
			var vertical=composition.size.x<620
			composition.vertical=vertical
			var width=minf(374,maxf(140,composition.size.x)) if vertical else clampf((layout.size.y-100)*63.0/88.0,106,294)
			var height=width*88.0/63.0
			portrait_wrap.custom_minimum_size=Vector2(0 if vertical else width,height)
			full_card.size=Vector2(width,height);full_card.position=Vector2(maxf(0,(portrait_wrap.size.x-width)/2.0),0)
		composition.resized.connect(fit);portrait_wrap.resized.connect(fit);fit.call()
		inspector_card_id=str(c.id);inspector_title=text(str(c.name),details,24)
		# The fixed44px top return is the single dismiss/return-to-target action.
		# Retain the semantic inspector action for input and accessibility tests.
		actions.inspect_target=actions.modal_close
		text("%s · %s · %s" % [alpha_catalog.source.powers.get(c.get("faction","neutral"),c.get("order","")),S.KINDS.get(c.kind,c.kind),S.RARITIES.get(c.rarity,c.rarity)],details,15)
		var resonance=int(c.get("resonance_cost",0))
		text("Energie %d%s" % [c.cost," · Resonanz %d" % resonance if resonance>0 else ""],details,16).add_theme_color_override("font_color",T.ENERGY)
		if c.kind=="creature":
			text("Angriff %d  /  Leben %d" % [current.get("display_attack",current.get("atk",c.atk)),current.get("hp",c.hp)],details,22)
			var species: Array=[]
			var labels=LibraryFilter.species_labels()
			for species_id in c.get("species",[]):species.append(str(labels.get(species_id,species_id)))
			if not species.is_empty():text("Wesensarten: "+" · ".join(species),details,15)
		if not current.is_empty():text("Wesenschild %d · Block %d · Stasis %d · Zusätzliche Angriffe %d" % [current.get("ward",0),current.get("block",0),current.get("stun",0),current.get("extra_attacks",0)],details,15)
		if int(current.get("attack_penalty",0))>0:text("Aktuelle Schwächung: −%d Angriff in der nächsten eigenen Angriffsphase." % int(current.attack_penalty),details,14)
		inspector_rules=text(str(c.get("description","")),details,18)
		text("SCHLÜSSELWÖRTER",details,14);text(S.card_keywords(c),details,14)
		var art_note=ArtQualityLabel.new();art_note.card=c;details.add_child(art_note)
		if c.kind=="event" and c.effect=="redirect":text("Voraussetzung: Ein eigener verzögerter Treffer wartet bereits. Neunte-Stunde-Karten wie Vorgemerkter Einschlag bereiten ihn vor.",details,14)
		if page=="battle" and mode=="alpha" and c.kind=="relic" and session.model.state.hero.relic!=null and session.model.state.hero.relic.id==c.id:
			button("inspect_relic_activate","RELIKT AKTIVIEREN · "+relic_cost_caption(),func():close_modal();act("activateRelic",["hero"]),details,not relic_can_activate())
	)
func show_log(requested_page: int=0) -> void:
	var event_count: int=session.model.events.size()
	var pages=maxi(1,ceili(event_count/60.0))
	log_page=clampi(requested_page,0,pages-1)
	show_modal("KAMPFPROTOKOLL / REPLAY",func(box):
		var replay_actions=row(box)
		button("export_replay","Replay speichern",func():message="Replay gespeichert." if session.export_replay() else "Speichern fehlgeschlagen.",replay_actions)
		button("verify_replay","Replay prüfen",func():var result=Session.replay(session.audit());message="Replay identisch." if result.ok else "Replay abweichend.";close_modal();render(),replay_actions)
		var navigation=row(box)
		button("log_older","Älter",func():show_log(log_page+1),navigation,log_page>=pages-1)
		text("%d Ereignisse · Seite %d / %d" % [event_count,log_page+1,pages],navigation,13)
		button("log_newer","Neuer",func():show_log(log_page-1),navigation,log_page==0)
		var names={"hero_hit":"Direkter Heldenangriff","unit_hit":"Kreaturenangriff","attack":"Angriff","death":"Kreaturentod","summon":"Beschwörung","effect":"Fähigkeit","reaction":"Ordensreaktion","begin":"Zugbeginn","recycle":"Kartenkreislauf","fatigue":"Erschöpfung","result":"Spielabschluss","convergence_win":"Konvergenz vollendet","convergence_declared":"Konvergenz angekündigt","convergence_failed":"Konvergenz unterbrochen"}
		# All events remain available. A long deterministic chain must not create
		# thousands of permanent Label nodes just to inspect its latest result.
		for i in range(maxi(0,event_count-(log_page+1)*60),maxi(0,event_count-log_page*60)):
			var e: Dictionary=session.model.events[i]
			text("%03d  %s · %s · LP %d:%d · Energie %d:%d" % [i,{"hero":"DU","enemy":"KI","system":"SYSTEM"}.get(e.side,e.side),names.get(e.kind,str(e.kind).replace("_"," ")),e.state.hero.hp,e.state.enemy.hp,e.state.hero.energy,e.state.enemy.energy],box,13)
	)
func show_engine_error() -> void:
	show_modal("PARTIE ANGEHALTEN",func(box):
		text("Eine Effektkette konnte nicht sicher abgeschlossen werden. Weitere Spielzüge sind gesperrt; du kannst das Protokoll sichern und eine neue Partie beginnen.",box,18)
		text(str(session.model.state.get("error","Unbekannter Auflösungsfehler.")),box,14)
		button("error_export","PROTOKOLL / REPLAY SICHERN",func():message="Replay gespeichert." if session.export_replay() else "Speichern fehlgeschlagen.",box)
		button("error_restart","NEUE PARTIE",func():close_modal();start_battle(),box)
		button("error_menu","ZUM MENÜ",func():close_modal();page="lobby";render(),box)
	)
func result_dialog() -> void:
	var s: Dictionary=session.model.state
	show_modal("SIEG" if s.winner=="hero" else "UNENTSCHIEDEN" if s.winner=="draw" else "NIEDERLAGE",func(box):
		text("Regulärer Spielabschluss. Alle weiteren Kampfaktionen sind gesperrt.",box,20)
		if not services.last_reward.is_empty():text("Lokaler Fortschritt verbucht." if services.last_reward.get("ok",false) else "Fortschritt konnte nicht gespeichert werden; der Kampfabschluss bleibt gültig.",box,14)
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
	set_audio_paused(true)
func builder() -> void:
	var small_builder=layout.size.y<600
	var top=row();text("SAMMLUNG" if collection_only else "DECKWERKSTATT",top,22);button("builder_back","Menü",func():page="lobby";render(),top).size_flags_horizontal=Control.SIZE_SHRINK_END
	if not collection_only and not small_builder and collection_mode=="alpha":
		var powers: HBoxContainer
		var index=0
		for power in alpha_catalog.deck_ids():
			if index%2==0 or not portrait:powers=row() if index==0 or portrait else powers
			index+=1
			button("builder_power_"+power,S.SYMBOLS[power]+" "+alpha_catalog.source.powers[power]+(" ●" if faction==power else ""),func():faction=power;save_preferences();deck=current_deck();filter_power="all";render(),powers)
		text(alpha_catalog.source.powers.get(faction,faction)+" · %d / 30 Karten" % deck.size(),body,18)
	var search_row=row()
	var search=LineEdit.new();search.placeholder_text="Name, Fähigkeit oder Wesensart suchen";search.text=filter_text;search.custom_minimum_size=Vector2(80,44);search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search_row.add_child(search)
	search.add_theme_font_size_override("font_size",16)
	search.text_changed.connect(func(v):filter_text=v)
	search.text_submitted.connect(func(v):filter_text=v;search.release_focus();render());actions.search=search
	if restore_search_focus:search.call_deferred("grab_focus");search.set_deferred("caret_column",search_caret)
	button("search_apply","Suchen",func():filter_text=search.text;render(),search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
	button("filters","Filter",show_filters,search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
	if small_builder and not collection_only and collection_mode=="alpha":button("builder_power",alpha_catalog.source.powers[faction],show_power_picker,top if layout.size.x<700 else search_row).size_flags_horizontal=Control.SIZE_SHRINK_END
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
		var starter_catalog=alpha_catalog if collection_mode=="alpha" else LegacyCatalog.new()
		button("reset_deck","Starter kopieren",func():deck=starter_catalog.deck(faction);message="Starter als bearbeitbare Vorlage kopiert.";render(),footer)
		if collection_mode=="alpha":button("strategy_templates","Testdecks",show_test_decks,body if layout.size.x<700 else footer)
		if not small_builder:text(message,body,12)
func show_test_decks() -> void:
	var templates: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/production/test_decks.json"))
	var cat=alpha_catalog
	show_modal("STRATEGIEVORLAGEN",func(box):
		text("Vierzehn Referenzdecks aus dem aktiven Kartenpool. Lade eine Vorlage und speichere sie, um sie für eine Partie auszuwählen. Die vier Starter bleiben erhalten.",box,16)
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
	var cat=alpha_catalog if collection_mode=="alpha" else LegacyCatalog.new()
	for raw in cat.all_cards():
		var c: Dictionary=raw.duplicate(true)
		if collection_mode=="legacy":c.name=session.legacy_text[c.id].name;c.description=session.legacy_text[c.id].description
		if not collection_only and collection_mode=="alpha" and c.faction not in [faction,"neutral"]:continue
		cards.append(c)
	return cards
func library_query() -> Dictionary:
	return LibraryFilter.select(library_cards(),{"query":filter_text,"kind":filter_type,"cost":filter_cost,"rarity":filter_rarity,"power":filter_power,"species":filter_species,"sort":filter_sort})
func library_window(cards: Array, desktop: bool) -> Dictionary:
	# Only the active page owns controls/textures. A 550-card collection must not
	# instantiate hundreds of interactive cards just to show its first screen.
	var ids: Array=[]
	for card in cards:ids.append(str(card.id))
	var signature=JSON.stringify([collection_mode,collection_only,faction,filter_text,filter_type,filter_cost,filter_rarity,filter_power,filter_species,filter_sort,desktop,ids])
	if signature!=library_query_signature:
		library_query_signature=signature;library_page=0;library_scroll_position=0
	var limit=24 if desktop else 12
	# The archived small catalog can retain its established continuous library.
	if cards.size()<=60:limit=maxi(1,cards.size())
	library_total=cards.size();library_page_count=maxi(1,ceili(float(cards.size())/limit))
	library_page=clampi(library_page,0,library_page_count-1)
	var first=library_page*limit;var last=mini(cards.size(),first+limit)
	var visible=cards.slice(first,last)
	library_visible_ids=[]
	for card in visible:library_visible_ids.append(str(card.id))
	return {"cards":visible,"first":first,"last":last,"total":cards.size(),"page":library_page,"pages":library_page_count,"limit":limit}
func change_library_page(delta: int) -> void:
	library_page=clampi(library_page+delta,0,library_page_count-1);library_scroll_position=0
	if is_instance_valid(library_scroll):library_scroll.scroll_vertical=0
	render()
func library_panel(parent: Node, desktop: bool) -> void:
	var pane=VBoxContainer.new();pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pane.size_flags_stretch_ratio=1.6;parent.add_child(pane)
	var query=library_query()
	if not query.ok:
		text("Filter konnte nicht angewendet werden: "+str(query.error),pane);return
	var window=library_window(query.cards,desktop)
	var sc=ScrollContainer.new();library_scroll=sc;sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sc.scroll_deadzone=10;pane.add_child(sc)
	sc.set_deferred("scroll_vertical",library_scroll_position)
	# A short search result retains the same portrait-card width as a full page;
	# shrinking the grid prevents one result stretching across the whole pane.
	var grid=GridContainer.new();grid.columns=1;grid.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",10);sc.add_child(grid)
	var card_tiles: Array=[]
	var card_views: Array=[]
	for c: Dictionary in window.cards:
		var tile=VBoxContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.custom_minimum_size.x=156;grid.add_child(tile);card_tiles.append(tile)
		var v=CardView.new();v.card=c;v.library=true;v.color=S.color(c);v.custom_minimum_size=Vector2(156,218);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_child(v);card_views.append(v);actions["card_"+c.id]=v
		_bind_press(v,func():inspect(c) if collection_only or not can_add(c) else add_card(c))
		if services.economy!=null and collection_mode=="alpha":text("Gesammelt: %d · Alpha frei spielbar" % services.economy.owned_count(c.id),tile,12)
		var controls=row(tile)
		button("detail_"+c.id,"Details",func():inspect(c),controls)
		if not collection_only:button("add_"+c.id,"+  %d/%d" % [deck.count(c.id),1 if c.rarity=="legendary" else 3],func():add_card(c),controls,not can_add(c))
	var fit_cards=func():
		if not is_instance_valid(sc) or not is_instance_valid(grid) or sc.size.x<=0:return
		# Reserve the themed scrollbar even on a short result page. This keeps
		# widths stable when the next result needs vertical scrolling.
		var usable=maxf(44,sc.size.x-sc.get_v_scroll_bar().get_combined_minimum_size().x)
		var fitted=preload("res://scripts/premium/library_geometry.gd").fit(usable,desktop)
		grid.columns=int(fitted.columns)
		for index in card_views.size():
			card_tiles[index].custom_minimum_size.x=float(fitted.card_width)
			card_views[index].custom_minimum_size=Vector2(float(fitted.card_width),float(fitted.card_height))
	# Layout is asynchronous: measure the real assigned pane after Containers
	# settle, then repeat only when that pane actually changes its dimensions.
	sc.resized.connect(fit_cards)
	fit_cards.call_deferred()
	if window.total==0:text("Keine Karten für diese Filter. Suche oder Filter ändern.",pane)
	elif window.pages>1:
		var pager=row(pane)
		button("library_previous","←",func():change_library_page(-1),pager,window.page==0).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		var summary=text("%d–%d / %d · %d/%d" % [window.first+1,window.last,window.total,window.page+1,window.pages],pager,12)
		summary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;summary.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		button("library_next","→",func():change_library_page(1),pager,window.page==window.pages-1).size_flags_horizontal=Control.SIZE_SHRINK_END
func deck_panel(parent: Node) -> void:
	var pane=VBoxContainer.new();pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(pane)
	text("DEINE KARTEN · %d/%d" % [deck.size(),30 if collection_mode=="alpha" else 25],pane,16)
	var curve=row(pane);var counts=[]
	var cat=alpha_catalog if collection_mode=="alpha" else LegacyCatalog.new()
	var maximum_cost=8
	for card in cat.all_cards():maximum_cost=maxi(maximum_cost,int(card.get("cost",0)))
	maximum_cost=mini(maximum_cost,10);counts.resize(maximum_cost+1);counts.fill(0)
	for id in deck:counts[mini(maximum_cost,int(cat.card(id).cost))]+=1
	for cost in maximum_cost+1:
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
	var result=alpha_catalog.validate(deck) if collection_mode=="alpha" else preload("res://scripts/legacy/deck_validator.gd").new().validate(deck)
	if result.ok and collection_mode=="alpha" and result.faction!=faction:return {"ok":false,"message":"Mindestens eine Karte der gewählten Macht erforderlich."}
	return result
func save_current_deck() -> void:
	var valid=deck_check()
	if not valid.ok:message=valid.message;render();return
	var result=session.save_deck(collection_mode+":"+faction,deck,collection_mode);message=result.get("message","");render()
func _qa_clip_rect(control: Control) -> Rect2:
	var bounds=get_viewport_rect()
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		var clipper=ancestor as Control
		if clipper!=null and clipper.clip_contents:bounds=bounds.intersection(clipper.get_global_rect())
		ancestor=ancestor.get_parent()
	return bounds
func _qa_css_rect(rect: Rect2) -> Array:
	return [rect.position.x/density,rect.position.y/density,rect.size.x/density,rect.size.y/density]
func _qa_art_report(view: Control) -> Dictionary:
	var report: Dictionary=view.art_report()
	for field in ["illustration_rect","frame_rect"]:
		if report.get(field) is Array and report[field].size()==4:
			var value: Array=report[field]
			var local=Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
			report[field]=_qa_css_rect(view.get_global_transform()*local)
	report.coordinate_space="css"
	return report
func _hosted_qa(node: Node, output: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree():
		output.append({"id":str(node.get_meta("qa_id",node.name)),"text":str(node.text) if node is Button else "","rect":_qa_css_rect(node.get_global_rect()),"disabled":node.disabled})
	for child in node.get_children():_hosted_qa(child,output)

func publish_qa() -> void:
	var state={"page":page,"mode":mode,"actions":{},"action_visibility":{},"hand":[],"board":{},"modal":is_instance_valid(modal),"message":message,"profile_wins":session.profile.wins,"deck_size":deck.size(),"selected":selected,"action_mode":action_mode,"render_version":render_version,"modal_version":modal_version,"portrait":portrait,"density":density,"layout_size":[layout.size.x,layout.size.y],"deck_ids":deck.duplicate(),"power":faction,"deck_tab":deck_tab,"search_text":filter_text,"font_msdf":S.font.multichannel_signed_distance_field,"library_total":library_total,"library_page":library_page,"library_pages":library_page_count,"library_visible_ids":library_visible_ids.duplicate()}
	state.hosted_page=hosted_name
	state.arena_mode=arena_mode
	state.arena_projection_active=arena_projection_active
	state.battle_regions={}
	if page=="battle" and is_instance_valid(battle_surface):
		for region in ["header","board","hand","dock"]:
			if battle_geometry.has(region):
				var local: Rect2=battle_geometry[region]
				state.battle_regions[region]=_qa_css_rect(Rect2(battle_surface.global_position+local.position*density,local.size*density))
	state.hosted_actions=[]
	if is_instance_valid(hosted_page):_hosted_qa(hosted_page,state.hosted_actions)
	if services.economy!=null:state.economy_ready=services.economy.ready
	state.audio=get_node("/root/GameAudio").snapshot()
	state.audio_paused=audio_paused
	state.audio_controls={}
	if is_instance_valid(audio_settings) and audio_settings.is_inside_tree():
		for channel in audio_settings.sliders:
			state.audio_controls[channel]=audio_settings.sliders[channel].value
		state.audio_persistence_note=audio_settings.persistence_note.text
	if is_instance_valid(inspector_rules) and is_instance_valid(modal):
		var r=inspector_rules.get_global_rect()
		state.inspection={"id":inspector_card_id,"title":inspector_title.text,"rules":inspector_rules.text,"rules_font_size":inspector_rules.get_theme_font_size("font_size"),"rules_rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]}
		if is_instance_valid(inspector_face):state.inspection.card_rect=_qa_css_rect(inspector_face.get_global_rect());state.inspection.card_aspect=inspector_face.size.x/inspector_face.size.y
		# Observe the face that actually painted the inspector, not a newer cache
		# entry that may not have reached that Control's framebuffer yet.
		state.inspection.art=inspector_face.art_report() if is_instance_valid(inspector_face) and inspector_face.has_method("art_report") else {"state":"unbound","preview_only":true,"pixels":[]}
	state.library_art={}
	for card_id in library_visible_ids:
		var library_view=actions.get("card_"+str(card_id))
		var observed=library_view.art_report() if is_instance_valid(library_view) and library_view.has_method("art_report") else {}
		state.library_art[card_id]={"state":observed.get("delivery_state","unbound"),"pixels":observed.get("pixels",[]),"pending":observed.get("pending",true)}
	var art_service=get_tree().root.get_node_or_null("ArtDelivery")
	if art_service!=null:state.art_delivery=art_service.metrics();state.art_cache=CardView.ART.stats()
	state.opening_marks=mulligan_indices.duplicate();state.drag={"active":bool(hand_drag.get("active",false)),"targets":hand_drag.get("targets",{}).keys()}
	for key in actions:
		var b=actions[key]
		if is_instance_valid(b) and b.is_visible_in_tree():
			var r=b.get_global_rect();state.actions[key]={"rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density],"disabled":b.disabled if b is BaseButton else false}
			var clip=_qa_clip_rect(b)
			state.action_visibility[key]={"clip_rect":_qa_css_rect(clip),"visible_rect":_qa_css_rect(r.intersection(clip))}
	state.battle_art=[]
	for b in hand_views:
		var report=_qa_art_report(b);report.zone="hand";state.battle_art.append(report)
		var r=b.get_global_rect();var availability=_card_availability(hand_views.find(b));state.hand.append({"id":b.card.id,"name":b.card.name,"selected":selected==hand_views.find(b),"availability_shown":bool(b.get("availability_shown")),"playable":bool(availability.playable),"unavailable_reason":str(availability.reason) if not availability.playable else "","rect":[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]})
		if selected==hand_views.find(b):state.selected_card_rect=_qa_css_rect(r)
	for key in board_views:
		var report=_qa_art_report(board_views[key]);report.zone="board";report.slot=key;state.battle_art.append(report)
		var r=board_views[key].get_global_rect();state.board[key]=[r.position.x/density,r.position.y/density,r.size.x/density,r.size.y/density]
	if session.model!=null:
		state.battle=session.model.snapshot();state.command_count=session.commands.size()
		state.legal_plays=[];state.controlled_lanes=[];state.board_details={}
		if page=="battle" and session.model.state.active=="hero" and session.model.state.winner==null:
			for index in session.model.state.hero.hand.size():
				var lanes: Array=[]
				for lane in 5:
					if session.model.play_support("hero",index,lane).is_empty():lanes.append(lane)
				var card=session.card(session.model.state.hero.hand[index])
				state.legal_plays.append({"index":index,"id":card.id,"lanes":lanes,"side":card_target_side(card),"relic":card.kind=="relic"})
		if mode=="alpha" and session.model.state.get("stage")=="battle":
			for lane in 5:
				if session.model.controlled("hero",lane):state.controlled_lanes.append(lane)
		for key in board_views:
			var view=board_views[key]
			state.board_details[key]={"target":view.target,"ready":view.combat_ready,"attack":view.current_attack(),"shield":view.unit.get("ward",0),"block":view.unit.get("block",0),"stasis":view.unit.get("stun",0)}
	JavaScriptBridge.eval("window.orafoldQA="+JSON.stringify(state))

func _hand_click(index: int) -> void:
	if index<0 or index>=session.model.state.hero.hand.size():return
	var c=session.card(session.model.state.hero.hand[index])
	if session.model.state.hero.pendingTarget!=null or session.model.state.hero.pendingShift!=null:inspect(c);return
	if selected==index:inspect(c)
	else:_audio_event("card.select");selected=index;source_lane=-1;action_mode="";message=c.name+" · leuchtendes Ziel wählen. Nochmals tippen: Details.";render()
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
	var image=TextureRect.new();image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.texture=tex;image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;image.custom_minimum_size=Vector2(height,height);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;parent.add_child(image)

func load_last_replay() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("user://orafold_last_replay.json"))
	var result=Session.replay(data)
	if not result.ok:message="Replay ungültig oder beschädigt.";render();return
	replay_step(data,0)
func replay_step(data: Dictionary, step: int) -> void:
	var replay=Session.replay_prefix(data,step)
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
	var next_portrait=size.y>size.x
	var metrics=preload("res://scripts/production/mobile_metrics.gd")
	if OS.has_feature("web"):
		# Read one atomic CSS snapshot. Neither screen.orientation nor the Godot
		# backing buffer is an authority on Safari's current layout orientation.
		var value=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.orafoldViewportMetrics?window.orafoldViewportMetrics():{})")))
		var fitted=metrics.web_layout(size,value if value is Dictionary else {})
		layout.position=fitted.position;layout.scale=fitted.scale;layout.size=fitted.size
		density=maxf(.5,float(fitted.scale.x));next_portrait=fitted.portrait
	else:
		if OS.has_feature("mobile"):
			density=metrics.native_density(DisplayServer.screen_get_scale(),DisplayServer.screen_get_dpi(),true)
			insets=metrics.safe_insets(size,Rect2(DisplayServer.get_display_safe_area()),Vector2(DisplayServer.window_get_position()),density)
		var left=float(insets.get("left",0));var right=float(insets.get("right",0));var top=float(insets.get("top",0));var bottom=float(insets.get("bottom",0))
		layout.position=Vector2(left,top)*density;layout.scale=Vector2.ONE*density
		layout.size=Vector2(maxf(320,size.x/density-left-right),maxf(160,size.y/density-top-bottom))
	if OS.has_feature("web") and page=="battle" and next_portrait!=portrait:rotation_block_until=Time.get_ticks_msec()+180
	portrait=next_portrait
	compact=layout.size.y<380
	short_landscape=not portrait and layout.size.y<296
	for side in ["left","right","top","bottom"]:outer_margin.add_theme_constant_override("margin_"+side,4 if compact else 8)
	body.add_theme_constant_override("separation",1 if short_landscape and page=="battle" else 2 if compact or page=="battle" else 4)

func _feedback_events(events: Array, previous: Dictionary) -> void:
	if not is_instance_valid(feedback) or is_instance_valid(modal):return
	feedback.reduced=bool(session.profile.reduced_motion);feedback.density=density
	for e in events:
		var side: String=e.side if e.side in ["hero","enemy"] else "hero"
		var target_side: String=session.model._other(side) if e.kind in ["attack","hero_hit","unit_hit","strike_hit"] else side
		var lane: int=int(e.get("lane",e.get("to",0)))
		if e.get("pendingDeath") is Dictionary:lane=int(e.pendingDeath.get("lane",0))
		var target=hero_badges[target_side].get_global_rect().get_center() if hero_badges.has(target_side) else Vector2(size.x*(.28 if target_side=="hero" else .78),70*density)
		if board_views.has(target_side+str(lane)) and e.kind!="hero_hit" and not e.get("hero_target",false):target=board_views[target_side+str(lane)].get_global_rect().get_center()
		var origin=Vector2(size.x*.5,size.y-70*density)
		if board_views.has(side+str(int(e.get("from",lane)))):origin=board_views[side+str(int(e.get("from",lane)))].get_global_rect().get_center()
		if e.kind in ["attack","hero_hit","unit_hit","strike_hit","summon","death","recall","shift","draw_finished","effect_draw","convergence_declared","convergence_win","event","tactical_move"]:
			if e.kind in ["draw_finished","effect_draw"]:target=battle_hand_host.get_global_rect().get_center() if is_instance_valid(battle_hand_host) else Vector2(size.x*.5,size.y-80*density)
			feedback.emit(e.kind,origin,target,T.FOE if side=="enemy" else T.PLAYER,"×" if e.kind=="death" else "")
		for who in ["hero","enemy"]:
			var hp_loss=maxi(0,int(previous[who].hp)-int(e.state[who].hp))
			var shield_absorb=maxi(0,int(previous[who].ward)-int(e.state[who].ward))
			var block_absorb=maxi(0,int(previous[who].block)-int(e.state[who].block))
			var point=hero_badges[who].get_global_rect().get_center() if hero_badges.has(who) else Vector2(size.x*(.28 if who=="hero" else .78),70*density)
			var healed=maxi(0,int(e.state[who].hp)-int(previous[who].hp))
			if healed>0:feedback.emit("heal",point,point,T.SUCCESS,"+"+str(healed))
			if hp_loss>0:feedback.emit("damage",point,point,T.DANGER,"−"+str(hp_loss))
			if shield_absorb>0:feedback.emit("shield",point,point+Vector2(0,14*density),T.ENERGY,"SCHILD −"+str(shield_absorb))
			if block_absorb>0:feedback.emit("block",point,point+Vector2(0,28*density),T.GOLD,"BLOCK −"+str(block_absorb))
			var resonance_gain=int(e.state[who].resonance)-int(previous[who].resonance)
			if resonance_gain>0:feedback.emit("resonance",point,point+Vector2(0,42*density),Color("c5b7ef"),"+%d RES" % resonance_gain)
			for index in 5:
				var before_unit: Variant=previous[who].lanes[index];var after_unit: Variant=e.state[who].lanes[index]
				if not before_unit is Dictionary or not after_unit is Dictionary:continue
				if before_unit.get("uid",before_unit.id)!=after_unit.get("uid",after_unit.id):continue
				if not board_views.has(who+str(index)):continue
				var at=board_views[who+str(index)].get_global_rect().get_center()
				var unit_loss=int(before_unit.hp)-int(after_unit.hp)
				var shield_loss=int(before_unit.get("ward",0))-int(after_unit.get("ward",0))
				var block_loss=int(before_unit.get("block",0))-int(after_unit.get("block",0))
				if unit_loss>0:feedback.emit("unit_damage",at,at,T.DANGER,"−%d LP" % unit_loss)
				elif unit_loss<0:feedback.emit("heal",at,at,T.SUCCESS,"+%d LP" % -unit_loss)
				if block_loss>0:feedback.emit("block",at,at+Vector2(0,28*density),T.GOLD,"B −%d" % block_loss)
				if shield_loss>0:feedback.emit("shield",at,at+Vector2(0,16*density),T.ENERGY,"S −%d" % shield_loss)
				elif shield_loss<0:feedback.emit("shield",at,at+Vector2(0,16*density),T.ENERGY,"S +%d" % -shield_loss)
				var stun_gain=int(after_unit.get("stun",0))-int(before_unit.get("stun",0))
				if stun_gain>0:feedback.emit("stasis",at,at,T.WARNING,"STASIS %d" % int(after_unit.stun))
				var buff=int(after_unit.atk)-int(before_unit.atk)
				if buff!=0:feedback.emit("buff",at,at+Vector2(0,26*density),T.SUCCESS if buff>0 else T.WARNING,("+" if buff>0 else "")+str(buff)+" ANG")
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
	var cat=alpha_catalog
	for power in cat.deck_ids():
		var frame=PanelContainer.new();frame.mouse_filter=Control.MOUSE_FILTER_PASS;frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;frame.add_theme_stylebox_override("panel",T.panel(S.POWER_COLORS[power],Color("15212d")));grid.add_child(frame)
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
	var cat=alpha_catalog;var ids=cat.deck(power)
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
	if not portrait:
		# A short landscape window needs more vertical space, not another turn.
		# Keep the safe exit pinned while the explanation can scroll.
		var top=row();text("MEHR PLATZ FÜR FÜNF PFADE",top,18)
		button("rotate_menu","Sicher zum Menü",confirm_menu,top).size_flags_horizontal=Control.SIZE_SHRINK_END
		var box=scroll()
		text("Schließe die Tastatur, setze den Seitenzoom zurück oder blende die Browserleisten kurz aus. Am Desktop: Fenster vergrößern. Unter 248 nutzbaren Pixeln würden Karten und Touchflächen zu klein. Dein Spielzustand bleibt erhalten.",box,16)
		return
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
		for power in alpha_catalog.deck_ids():button("builder_power_"+power,alpha_catalog.source.powers[power],func():faction=power;save_preferences();deck=current_deck();filter_power="all";close_modal();render(),box)
	)

func _web_drag_cancel_version() -> int:
	if not OS.has_feature("web"):return 0
	return int(JavaScriptBridge.eval("window.orafoldTouchCancelVersion||0"))
func _drag_press(at: Vector2, pointer: int) -> void:
	if not hand_drag.is_empty():
		if pointer!=int(hand_drag.pointer):get_viewport().set_input_as_handled()
		return
	# Arm from the original input event, never from a synthesized button_down
	# emitted while Godot transfers a held pointer across a resize/rebuilt hand.
	hand_press_epoch=hand_tap_epoch
	if page!="battle" or mode!="alpha" or portrait or is_instance_valid(modal) or session.model==null:return
	var s: Dictionary=session.model.state;var p: Dictionary=s.hero
	if s.stage!="battle" or not str(s.get("error","")).is_empty() or s.winner!=null or s.active!="hero" or p.phase!="main" or p.pendingTarget!=null or p.pendingShift!=null or not action_mode.is_empty():return
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
		hand_tap_epoch+=1
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
		drag_ghost=CardView.new();drag_ghost.card=card;drag_ghost.color=S.color(card);drag_ghost.set("display_role","hand");drag_ghost.set("reduced_motion",bool(session.profile.reduced_motion));drag_ghost.selected=true;drag_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;drag_ghost.size=Vector2(100,100*88.0/63.0);drag_ghost.modulate.a=.94;drag_ghost.z_index=110;layout.add_child(drag_ghost)
	if is_instance_valid(drag_ghost):drag_ghost.position=layout.get_global_transform().affine_inverse()*at-Vector2(50,130)
	get_viewport().set_input_as_handled()
func _drag_release(at: Vector2, pointer: int, canceled: bool=false) -> void:
	if canceled and hand_drag.is_empty():hand_tap_epoch+=1
	if hand_drag.is_empty() or pointer!=int(hand_drag.pointer):return
	# DOM touchcancel becomes an ordinary release in Godot's Web adapter. The
	# capture-phase version is read here synchronously, before any play command.
	if canceled or _web_drag_cancel_version()!=int(hand_drag.web_cancel):
		# The epoch blocks the card action, while GUI still receives the release
		# to clear its held-button/mouse-focus state before the next real tap.
		_cancel_hand_drag(true);return
	if not hand_drag.active:hand_drag.clear();return # Original tap-to-select still receives the release.
	var index=int(hand_drag.index);var p: Dictionary=session.model.state.hero;var lane := -1
	var valid=not canceled and hand_drag.viewport==get_viewport_rect().size and index<p.hand.size() and p.hand[index]==hand_drag.id and Session.digest(session.model.snapshot())==hand_drag.digest
	if valid:
		for key in hand_drag.targets:
			if key=="relic_slot":
				if actions.has(key) and actions[key].get_global_rect().has_point(at):lane=0;break
			elif board_views.has(key) and board_views[key].get_global_rect().has_point(at):lane=int(board_views[key].lane);break
	_cancel_hand_drag()
	if valid and lane>=0:act("play",["hero",index,lane])
	else:message="Karte nicht ausgespielt. Wähle ein gültiges Ziel oder tippe die Karte an.";render.call_deferred()
func _cancel_hand_drag(redraw: bool=false) -> void:
	if hand_drag.is_empty():return
	var was_active=bool(hand_drag.active)
	hand_tap_epoch+=1
	if was_active:selected=int(hand_drag.previous)
	hand_drag.clear()
	if is_instance_valid(drag_ghost):drag_ghost.hide();drag_ghost.queue_free()
	drag_ghost=null
	if redraw:render.call_deferred()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_hand_drag(true)
		_checkpoint_duel()
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
	elif event is InputEventKey and event.pressed:hand_press_epoch=hand_tap_epoch

func battle_heading(s: Dictionary) -> String:
	if mode=="alpha" and s.stage!="battle":return {"mulligan":"STARTHAND WÄHLEN","origins":"URSPRUNG WÄHLEN","second":"ZWEITE MÖGLICHKEIT"}.get(s.stage,"VORBEREITUNG")
	return ("PARTIE ANGEHALTEN" if not str(s.get("error","")).is_empty() else "PARTIE BEENDET" if s.winner!=null else "DEIN ZUG" if s.active=="hero" else "KI AM ZUG")+" · "+{"draw":"NACHZIEHEN","main":"AKTIONSPHASE","attack":"ANGRIFFE","end":"ZUGENDE"}.get(s.hero.phase,"VORBEREITUNG")+" · Runde %d" % (floori(float(s.round-1)/2)+1)

func _audio_event(event_name: String, context: Dictionary={}) -> void:
	var audio=get_node_or_null("/root/GameAudio")
	if audio!=null:audio.play_event(event_name,context)

func set_audio_paused(value: bool) -> void:
	audio_paused=value
	var audio=get_node_or_null("/root/GameAudio")
	if audio!=null:audio.set_suspended(value)

func _sync_audio_context() -> void:
	var wanted="collection" if page=="collection" else "deckbuilder" if page=="builder" else "duel" if page=="battle" else "menu"
	if page=="battle" and session.model!=null:
		var state: Dictionary=session.model.state
		if state.winner!=null:
			wanted="victory" if state.winner=="hero" else "defeat" if state.winner=="enemy" else "menu"
		elif state.hero.get("convergence")!=null or state.enemy.get("convergence")!=null:wanted="convergence"
	if wanted==audio_context:return
	audio_context=wanted
	var audio=get_node_or_null("/root/GameAudio")
	if audio==null:return
	audio.set_music(wanted)
	if page=="battle":audio.set_ambience("ambience.rift")
	else:audio.stop_ambience()
	if wanted in ["victory","defeat"]:_audio_event("battle."+wanted)

func _exit_tree() -> void:
	_checkpoint_duel()
	set_audio_paused(false)
