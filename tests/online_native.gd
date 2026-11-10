extends SceneTree
## Optional live smoke against the LOCAL prototype on 127.0.0.1:8787.
## Creates two disposable local accounts; no combat engine or game UI is loaded.
const Client = preload("res://scripts/online/online_client.gd")
var completed := [{}, {}]
var received := [[], []]
var errors: Array = []
var clients: Array = []
var failures := 0
var assertions := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(label)

func wait_for(predicate: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed := bool(predicate.call())
	check(passed, label)
	return passed

func _run() -> void:
	var suffix := Crypto.new().generate_random_bytes(6).hex_encode()
	var password := Crypto.new().generate_random_bytes(20).hex_encode()
	for index in 2:
		var client := Client.new()
		clients.append(client)
		client.request_completed.connect(func(operation: String, response: Dictionary): completed[index][operation] = response)
		client.message_received.connect(func(message: Dictionary): received[index].append(message))
		client.online_error.connect(func(code: String): errors.append(code))
		root.add_child(client)
		check(client.register_account("native_%d_%s" % [index, suffix], password, "Native Smoke %d" % index) == OK, "native registration starts")
		if not await wait_for(func(): return completed[index].has("register"), "native registration response"):
			_finish()
			return
		check(client.login("native_%d_%s" % [index, suffix], password) == OK, "native login starts")
		if not await wait_for(func(): return completed[index].has("login"), "native login response"):
			_finish()
			return
		check(not client.session.bearer_token.is_empty(), "native token only in memory")
		check(client.connect_online() == OK, "native ticket starts")
		if not await wait_for(func(): return received[index].size() > 0, "native websocket session resume"):
			_finish()
			return
		check(received[index][0].protocol_version == 1, "native versioned response")
		check(client.send_intent("matchmaking.join", {"mode": "casual", "region": "local"}) == OK, "native matchmaking intent")
	if not await wait_for(func(): return not clients[0].session.match_id.is_empty() and clients[0].session.match_id == clients[1].session.match_id, "two native clients assigned same match"):
		_finish()
		return
	for client in clients:
		check(client.send_intent("match.ready", {"match_id": client.session.match_id}) == OK, "native ready intent")
	await wait_for(func(): return received[0].any(func(message: Dictionary): return message.get("status") == "active"), "native match active")
	check(errors.is_empty(), "native smoke has no server or transport errors")
	for index in 2:
		check(clients[index].logout() == OK, "native logout starts")
		await wait_for(func(): return completed[index].has("logout"), "native logout revoked")
		check(clients[index].session.bearer_token.is_empty(), "native logout clears token")
	_finish()

func _finish() -> void:
	for client in clients:
		client.queue_free()
	print("ONLINE NATIVE LIVE: %d assertions, %d failures; disposable local accounts; simulated match only" % [assertions, failures])
	quit(1 if failures else 0)
