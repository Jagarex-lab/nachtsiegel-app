extends SceneTree
const Lobby = preload("res://scripts/online/online_lobby.gd")
var lobby
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(390,844)
	lobby=Lobby.new();root.add_child(lobby);lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame;await process_frame;await process_frame
	lobby.actions.username.text="rotation-test"
	lobby.actions.password.text="memory-only-test-password"
	_check_width()
	for id in ["back","server_url","server_apply","username","password","login","register","logout"]:
		assert(lobby.actions.has(id));assert(lobby.actions[id].size.y>=44)
	lobby._socket_ready=true;lobby._render()
	await process_frame;await process_frame
	_check_width()
	assert(lobby.actions.has("private_create") and lobby.actions.has("starter_select") and lobby.actions.has("private_join"))
	lobby._view=JSON.parse_string(FileAccess.get_file_as_string("res://data/online/test_opening_view.json"))
	lobby.client.session.profile={"playerId":"a"};lobby._match_status="active";lobby._account_expanded=false;lobby._update_account();lobby._render()
	await process_frame;await process_frame
	_check_width()
	for lane in 5:
		assert(lobby.actions.has("self_lane_"+str(lane)) and lobby.actions.has("opponent_lane_"+str(lane)))
	assert(lobby.actions.has("hand_0"))
	root.size=Vector2i(844,390)
	await process_frame;await process_frame;await process_frame
	assert(lobby.actions.username.text=="rotation-test" and lobby.actions.password.text=="memory-only-test-password")
	assert(not JSON.stringify(lobby.qa_snapshot()).contains("memory-only-test-password"))
	assert(not JSON.stringify(lobby.qa_snapshot()).contains("rotation-test"))
	_check_width()
	lobby.queue_free();await process_frame
	print("ONLINE_LOBBY_LAYOUT_PASS portrait lobby/5-path duel, rotation, 44px controls, credential-free QA")
	quit()
func _check_width() -> void:
	for control in lobby.find_children("*","Control",true,false):
		if control.is_visible_in_tree():
			var rect=control.get_global_rect()
			assert(rect.position.x>=-1 and rect.end.x<=root.size.x+1,"Online horizontal overflow: "+control.get_class()+" "+str(rect))
