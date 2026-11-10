extends SceneTree
const Protocol = preload("res://scripts/online/online_protocol.gd")
const Session = preload("res://scripts/online/online_session.gd")
const Client = preload("res://scripts/online/online_client.gd")
var assertions := 0
var failures := 0

func check(value: bool, description: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var request := Protocol.request("matchmaking.join", {"mode": "casual", "region": "local"}, "fixed-request")
	check(request.protocol_version == 1 and request.request_id == "fixed-request", "versioned request")
	check(Protocol.request("match.action", {"match_id": "fixture", "sequence": 1, "action": {"type": "advance", "damage": 999}}).is_empty(), "client values rejected")
	check(Protocol.request("match.action", {"match_id": "fixture", "sequence": 0, "action": {"type": "advance"}}).is_empty(), "zero sequence rejected")
	check(Protocol.request("match.action", {"match_id": "fixture", "sequence": 1, "action": {"type": "play_card"}}).is_empty(), "real combat unavailable")
	check(Protocol.request("matchmaking.join", {"token": "secret"}).is_empty(), "extra envelope field rejected")
	check(Protocol.decode(JSON.stringify(request).to_utf8_buffer()).ok, "request parse")
	check(not Protocol.decode("[]".to_utf8_buffer()).ok, "array rejected")
	check(not Protocol.decode("{broken".to_utf8_buffer()).ok, "malformed json rejected")
	check(not Protocol.decode(JSON.stringify({"protocol_version": 2, "type": "match.state"}).to_utf8_buffer()).ok, "version rejected")
	check(not Protocol.decode("x".repeat(Protocol.MAX_MESSAGE_BYTES + 1).to_utf8_buffer()).ok, "message cap")
	var session := Session.new()
	check(session.accept_login({"token": "native-memory-token", "csrf_token": "csrf", "profile": {"playerId": "player"}}), "native session accepts login")
	session.observe({"protocol_version": 1, "type": "session.resumed", "match_id": null})
	check(session.match_id.is_empty() and session.last_sequence == 0, "null session match does not create a match")
	session.observe({"type": "match.state", "match_id": 123})
	check(session.match_id.is_empty(), "non-string match identifier ignored")
	session.observe({"type": "match.state", "match_id": "fixture", "sequence": 3, "next_action_sequence": 2})
	check(session.next_action_sequence() == 2, "action sequence uses per-player authority")
	session.observe({"type": "match.state", "match_id": "fixture", "sequence": 2})
	check(session.last_sequence == 3 and session.next_action_sequence() == 2, "stale responses never rewind")
	session.observe({"type": "match.state", "match_id": "new_fixture", "sequence": 0})
	check(session.last_sequence == 0, "new match resets sequence")
	var before := session.last_sequence
	Protocol.request("match.action", {"match_id": session.match_id, "sequence": session.next_action_sequence(), "action": {"type": "advance"}})
	check(session.last_sequence == before, "sending does not add actions")
	check(session.accept_login({"token": "new-memory-token", "csrf_token": "new-csrf", "profile": {"playerId": "other-player"}}), "account switch login accepted")
	check(session.match_id.is_empty() and session.next_action_sequence() == 1, "account switch clears previous match state")
	session.clear()
	check(session.bearer_token.is_empty() and session.csrf_token.is_empty() and session.profile.is_empty() and session.match_id.is_empty(), "logout clears all local credentials")
	var client := Client.new()
	check(not client.configure_base("http://remote.invalid"), "remote plaintext rejected")
	check(client.configure_base("https://online.example.invalid"), "TLS supported")
	client.free()
	print("ONLINE CLIENT: %d assertions, %d failures; transport fixture only" % [assertions, failures])
	quit(1 if failures else 0)
