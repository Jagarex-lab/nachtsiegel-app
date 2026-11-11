extends Control
## A network presentation only. Every offered combat action comes from the
## authoritative Production kernel. This Control owns no combat model.
signal back_requested
const Client = preload("res://scripts/online/online_client.gd")
const CardView = preload("res://scripts/alpha/card_view.gd")
const Style = preload("res://scripts/alpha/style.gd")
const Catalog = preload("res://scripts/production/catalog.gd")
var client
var catalog = Catalog.new()
var _content: VBoxContainer
var _status: Label
var _url: LineEdit
var _username: LineEdit
var _password: LineEdit
var _invite: LineEdit
var _starter: OptionButton
var _view: Dictionary={}
var _match_status := ""
var _selection := -1
var _mulligan: Array=[]
var _pending := false
var _socket_ready := false
var _invite_code := ""
var _last_error := ""
var actions: Dictionary={}
var _responsive_boxes: Array=[]
var _board_cards: Array=[]
var _starter_value := "houses"
var _custom_deck := ""
var _account_rows: Array=[]
var _account_expanded := true

func _ready() -> void:
	var theme_value=Theme.new();theme_value.default_font=Style.font;theme_value.default_font_size=16;theme=theme_value
	var background=ColorRect.new();background.color=Color("0b1220");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,18)
	add_child(margin)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;margin.add_child(scroll)
	var root=VBoxContainer.new();root.size_flags_horizontal=Control.SIZE_EXPAND_FILL;root.add_theme_constant_override("separation",12);scroll.add_child(root)
	var top=_responsive_row(root);_button(top,"← Zurück",func():back_requested.emit(),"back")
	_label(top,"ORAFOLD · Online-Duell",24).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_label(root,"Online: lokaler Testserver / kein öffentlicher Server",17)
	_label(root,"Zwei menschliche Konten · 550 Karten · fünf Pfade · 30 Leben. Offline-KI bleibt im Hauptmenü erreichbar.")
	_button(root,"Server & Konto ein-/ausblenden",_toggle_account,"account_settings")
	var settings=_responsive_row(root)
	_url=_line(settings,"Serveradresse",client.api_base if client!=null else "http://127.0.0.1:8787");_url.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions["server_url"]=_url
	_button(settings,"Adresse anwenden",_configure,"server_apply")
	if OS.has_feature("web"):_url.text=str(JavaScriptBridge.eval("window.location.origin",true));_url.editable=false
	var auth=_responsive_row(root)
	_account_rows=[settings,auth]
	_username=_line(auth,"Kontoname","");_username.max_length=32
	_password=_line(auth,"Passwort (mindestens 12 Zeichen)","");_password.secret=true;_password.max_length=128;_password.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions["username"]=_username;actions["password"]=_password
	var auth_buttons=HFlowContainer.new();auth.add_child(auth_buttons)
	_button(auth_buttons,"Anmelden",_login_account,"login")
	_button(auth_buttons,"Konto erstellen",_register_account,"register")
	_button(auth_buttons,"Abmelden",func():client.logout();_view={};_socket_ready=false;_render(),"logout")
	_status=_label(root,"Testserver starten und anmelden. Zugangsdaten bleiben nur im Arbeitsspeicher.")
	if OS.has_feature("web"):_status.text="Kein öffentlicher Server. Diese Web-Version benötigt eine API hinter derselben Origin; lokal über einen Reverse-Proxy."
	_content=VBoxContainer.new();_content.add_theme_constant_override("separation",12);root.add_child(_content)
	client=Client.new();add_child(client)
	client.authenticated.connect(func(_profile):_status.text="Angemeldet. Verbindung wird aufgebaut …";client.connect_online())
	client.connected.connect(func():_socket_ready=true;_account_expanded=false;_update_account();_status.text="Mit lokalem Testserver verbunden.";client.send_intent("catalog.get");_render())
	client.disconnected.connect(func():_socket_ready=false;_status.text="Verbindung unterbrochen. Automatische Wiederverbindung läuft …";_render())
	client.online_error.connect(func(code):_last_error=code;_pending=false;_status.text="Online: "+code;_render())
	client.message_received.connect(_message)
	client.request_completed.connect(func(operation,_response):
		if operation=="register":_status.text="Konto erstellt. Anmeldung …";client.login(_username.text,_password.text))
	resized.connect(_update_responsive)
	_update_responsive()
	_render()

func _configure() -> bool:
	if client!=null and client.configure_base(_url.text):return true
	_status.text="Native: HTTPS oder http://127.0.0.1:8787 / localhost:8787. Web: dieselbe HTTPS-Origin."
	return false

func _report(error: Error) -> void:
	if error!=OK:_status.text="Verbindung konnte nicht gestartet werden: "+error_string(error)

func _login_account() -> void:
	if _configure():_report(client.login(_username.text,_password.text))

func _register_account() -> void:
	if _configure():_report(client.register_account(_username.text,_password.text,_username.text))

func _toggle_account() -> void:
	_account_expanded=not _account_expanded;_update_account()

func _update_account() -> void:
	for row in _account_rows:row.visible=_account_expanded

func _message(message: Dictionary) -> void:
	_pending=false
	match message.type:
		"error":_status.text="Server: "+str(message.get("code","Fehler"))
		"private.created":_invite_code=message.invite_code;_status.text="Einladung erstellt. Code an die zweite Person weitergeben."
		"matchmaking.queued":_status.text="Warte auf eine zweite Person im lokalen Testserver …"
		"deck.selected":_status.text="Deck serverseitig geprüft und ausgewählt."
		"match.found":client.send_intent("match.reconnect",{"match_id":message.match_id,"after_sequence":0})
		"match.state":
			_view=message.state.duplicate(true);_match_status=message.status;_selection=-1;_mulligan=[]
			_status.text="Partie "+str(message.match_id)+" · "+str(message.status)+" · Sequenz "+str(message.sequence)
	_render()

func _render() -> void:
	if _content==null:return
	for key in actions.keys():
		if not is_instance_valid(actions[key]) or _content.is_ancestor_of(actions[key]):actions.erase(key)
	_board_cards=[]
	for child in _content.get_children():child.queue_free();_content.remove_child(child)
	if not _socket_ready:
		_label(_content,"Keine Online-Verbindung. Lokale Tests benötigen den separat gestarteten Node-24/Godot-4.6.3-Testserver.")
		return
	if _view.is_empty():_lobby();return
	if _match_status=="waiting_ready":
		_label(_content,"Zweite Person gefunden. Beide bestätigen ihre Bereitschaft.",22)
		_button(_content,"Bereit für echtes Duell",func():client.send_intent("match.ready",{"match_id":client.session.match_id}),"match_ready")
		return
	_duel()

func _lobby() -> void:
	_label(_content,"Ein Duell vorbereiten",22)
	var row=_responsive_row(_content)
	_starter=OptionButton.new();_starter.clip_text=true;_starter.custom_minimum_size=Vector2(180,44);row.add_child(_starter);actions["starter_select"]=_starter
	for id in catalog.deck_ids():
		_starter.add_item(str(catalog.source.powers.get(id,id)));_starter.set_item_metadata(_starter.item_count-1,id)
		if id==_starter_value:_starter.select(_starter.item_count-1)
	_starter.item_selected.connect(func(index):_starter_value=str(_starter.get_item_metadata(index)))
	_button(row,"Starter wählen",func():client.send_intent("deck.select",{"selection":{"starter_id":_starter_value}}),"starter_apply")
	_button(row,"Person suchen",func():client.send_intent("matchmaking.join",{"mode":"casual","region":"local"}),"queue_join")
	_button(row,"Suche verlassen",func():client.send_intent("matchmaking.leave"),"queue_leave")
	var invite_row=_responsive_row(_content)
	_button(invite_row,"Einladung erstellen",func():client.send_intent("private.create"),"private_create")
	_invite=_line(invite_row,"Einladungscode",_invite_code);_invite.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_invite.text_changed.connect(func(value):_invite_code=value);actions["invite_code"]=_invite
	_button(invite_row,"Mit Code beitreten",func():client.send_intent("private.join",{"invite_code":_invite.text.strip_edges()}),"private_join")
	var custom=_line(_content,"30 Karten-IDs, durch Komma getrennt",_custom_deck);actions["custom_deck"]=custom
	custom.text_changed.connect(func(value):_custom_deck=value)
	_button(_content,"Eigenes Deck prüfen und wählen",func():
		var ids: Array=[]
		for id in custom.text.split(",",false):ids.append(id.strip_edges())
		client.send_intent("deck.select",{"selection":{"cards":ids}}),"custom_apply")
	_label(_content,"Vier Starter stehen vollständig zur Verfügung. Ein eigenes Deck wird gegen denselben 550-Karten-Katalog auf dem Server geprüft.")

func _duel() -> void:
	var own: Dictionary=_view["self"];var opponent: Dictionary=_view.opponent
	var player_id: String=str(client.session.profile.get("playerId",""))
	var stage: String=_view.stage
	_label(_content,"Runde %d · Du %d Leben / %d Schild / %d Energie / %d Resonanz · Gegenüber %d Leben / %d Schild" % [int(_view.round),int(own.hp),int(own.ward),int(own.energy),int(own.resonance),int(opponent.hp),int(opponent.ward)],20)
	_label(_content,"Gegnerhand: %d Karten · Deck: %d · Dein Deck: %d" % [int(opponent.handCount),int(opponent.deckCount),int(own.deckCount)])
	if _view.get("finished",false):
		_label(_content,"Unentschieden" if _view.get("winner_player_id")==null else "Du hast gewonnen!" if _view.winner_player_id==player_id else "Du hast verloren.",28)
		_button(_content,"Zur Lobby",func():_view={};client.session.match_id="";_render(),"return_lobby")
		return
	if stage=="mulligan":_label(_content,"Starthand: Karten zum Austauschen markieren. Beide Personen entscheiden selbst.",18)
	elif stage=="origins":_label(_content,"Ursprung: Wähle einen deiner fünf Pfade. Die Wahl wird gemeinsam aufgedeckt.",18)
	elif stage=="second":_label(_content,"Zweite Möglichkeit: Die zweite Person darf einen Ursprung und eine Handkarte ändern, dann bestätigen.",18)
	else:_label(_content,"Dein Zug" if _view.active_player_id==player_id else "Die andere Person ist am Zug.",18)
	var grid=GridContainer.new();grid.columns=5;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_content.add_child(grid)
	for side in ["opponent","self"]:
		var public: Dictionary=_view[side]
		for lane in 5:
			var card=CardView.new();card.custom_minimum_size=Vector2(_board_width(),150);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.lane=lane;card.owner_label="DU" if side=="self" else "GEGENÜBER";card.color=Color("79ddd4") if side=="self" else Color("e19c9c")
			card.origin=int(_view.origins[side if side=="self" else "opponent"])==lane
			if public.lanes[lane]!=null:card.unit=public.lanes[lane];card.card=catalog.card(card.unit.id)
			grid.add_child(card);card.pressed.connect(_lane.bind(side,lane));_board_cards.append(card);actions[side+"_lane_"+str(lane)]=card
	var hand=HFlowContainer.new();hand.add_theme_constant_override("h_separation",8);hand.add_theme_constant_override("v_separation",8);_content.add_child(hand)
	for i in own.hand.size():
		var card=CardView.new();card.card=catalog.card(own.hand[i]);card.color=Style.color(card.card);card.selected=i==_selection or _mulligan.has(i);card.custom_minimum_size=Vector2(104,150) if size.x<760 else Vector2(128,180);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.tooltip_text=str(card.card.get("description",""));hand.add_child(card)
		actions["hand_"+str(i)]=card
		card.pressed.connect(func():
			if stage=="mulligan":
				if _mulligan.has(i):_mulligan.erase(i)
				else:_mulligan.append(i)
			else:_selection=i
			_render())
	var action_flow=HFlowContainer.new();action_flow.add_theme_constant_override("h_separation",8);action_flow.add_theme_constant_override("v_separation",8);_content.add_child(action_flow)
	if stage=="mulligan" and not _view.opening.mulligan_done:_button(action_flow,"Starthand bestätigen (%d tauschen)" % _mulligan.size(),func():_command("mulligan",[_mulligan.duplicate()]),"mulligan_confirm")
	for action in _view.get("legal_actions",[]):
		if action.name in ["play","mulligan","origin","secondOrigin","secondCard"]:continue
		_button(action_flow,_action_label(action),func():_command(action.name,action.args),"command_"+action.name+"_"+str(action.args))
	if stage=="second" and _selection>=0:_button(action_flow,"Gewählte Karte einmal tauschen",func():_command("secondCard",[_selection]),"second_card")
	if stage=="battle" and _selection>=0:_label(_content,"Gewählte Handkarte: "+catalog.card(own.hand[_selection]).name+" · Zielpfad anklicken.")
	_button(action_flow,"Verbindung erneuern",func():client.connect_online(),"reconnect")
	_button(action_flow,"Aufgeben",func():_send({"type":"concede"}),"concede")
	if _pending:_label(_content,"Server prüft den Befehl …")

func _lane(side: String, lane: int) -> void:
	if _view.is_empty():return
	if _view.stage=="origins" and side=="self":_command("origin",[lane])
	elif _view.stage=="second" and side=="self":_command("secondOrigin",[lane])
	elif _view.stage=="battle":
		if _view["self"].pendingTarget!=null and side=="opponent":_command("chooseStrikeTarget",[lane])
		elif _selection>=0:_command("play",[_selection,lane])

func _command(name: String, args: Array) -> void:
	for action in _view.get("legal_actions",[]):
		if action.name==name and action.args==args:_send({"type":"command","name":name,"args":args});return
	_status.text="Diese Aktion ist aktuell nicht verfügbar."

func _send(action: Dictionary) -> void:
	if _pending:return
	var error=client.send_intent("match.action",{"match_id":client.session.match_id,"sequence":client.session.next_action_sequence(),"action":action})
	if error==OK:_pending=true
	else:_report(error)

func _action_label(action: Dictionary) -> String:
	var names={"openingDone":"Eröffnung abschließen","finishDraw":"Karte ziehen","burn":"Handkarte ablegen","endTurn":"Angreifen und Zug beenden","chooseStrikeTarget":"Zielpfad","moveCreature":"Pfadwechsel","skipShift":"Verschiebung überspringen","recover":"Rückholung","burst":"Entfesselung","tacticalMove":"Pfadmanöver","fortify":"Pfadwacht","activateRelic":"Relikt aktivieren","converge":"Konvergenz erklären"}
	var label=str(names.get(action.name,action.name))
	if not action.args.is_empty():label+=" "+str(action.args)
	return label

func _label(parent: Node, value: String, font_size: int=16) -> Label:
	var label=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",font_size);parent.add_child(label);return label

func _line(parent: Node, placeholder: String, value: String) -> LineEdit:
	var line=LineEdit.new();line.placeholder_text=placeholder;line.text=value;line.custom_minimum_size=Vector2(180,44);line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(line);return line

func _button(parent: Node, value: String, callback: Callable, action_id: String="") -> Button:
	var button=Button.new();button.text=value;button.clip_text=true;button.tooltip_text=value;button.custom_minimum_size=Vector2(minf(280,maxf(90,value.length()*8+24)),44);button.pressed.connect(callback);parent.add_child(button)
	if not action_id.is_empty():actions[action_id]=button;button.name=action_id.validate_node_name()
	return button

func _responsive_row(parent: Node) -> BoxContainer:
	var box=BoxContainer.new();box.vertical=size.x<760;box.add_theme_constant_override("separation",8);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(box);_responsive_boxes.append(box);return box

func _board_width() -> float:return clampf(floor((size.x-64)/5),52,140)

func _update_responsive() -> void:
	var retained: Array=[]
	for box in _responsive_boxes:
		if is_instance_valid(box):box.vertical=size.x<760;retained.append(box)
	_responsive_boxes=retained
	for card in _board_cards:
		if is_instance_valid(card):card.custom_minimum_size.x=_board_width()

func qa_controls() -> Dictionary:return actions

func qa_snapshot() -> Dictionary:
	# QA exposes geometry through qa_controls(), never text input or credentials.
	return {"connected":_socket_ready,"authenticated":client!=null and not client.session.profile.is_empty(),"stage":_view.get("stage","lobby"),"match_status":_match_status,"pending":_pending,"public_server":false,"own_hand_count":_view.get("self",{}).get("handCount",0),"opponent_hand_count":_view.get("opponent",{}).get("handCount",0)}
