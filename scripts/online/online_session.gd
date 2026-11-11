extends RefCounted
## All credentials are memory-only. Never serialize this object into local saves.
var bearer_token := ""
var csrf_token := ""
var profile: Dictionary = {}
var expires_at: Variant = null
var match_id := ""
var last_sequence := 0
var _next_action_sequence := 1

func accept_login(response: Dictionary) -> bool:
	if not response.get("profile") is Dictionary or not response.get("csrf_token") is String:
		return false
	if profile.get("playerId", "") != response.profile.get("playerId", ""):
		match_id = ""
		last_sequence = 0
		_next_action_sequence = 1
	bearer_token = str(response.get("token", ""))
	csrf_token = response.csrf_token
	profile = response.profile.duplicate(true)
	expires_at = response.get("expires_at")
	return true

func observe(message: Dictionary) -> void:
	var raw_id: Variant = message.get("match_id")
	var state: Variant = message.get("state", {})
	if (not raw_id is String or raw_id.is_empty()) and state is Dictionary:
		raw_id = state.get("match_id")
	if not raw_id is String or raw_id.is_empty():
		return
	var current_id: String = raw_id
	if current_id != match_id:
		match_id = current_id
		last_sequence = 0
		_next_action_sequence = 1
	var action_sequence: Variant = message.get("next_action_sequence", 1)
	if action_sequence is float or action_sequence is int:
		_next_action_sequence = maxi(_next_action_sequence, int(action_sequence))
	var sequence: Variant = message.get("sequence", state.get("sequence", 0) if state is Dictionary else 0)
	if sequence is float or sequence is int:
		last_sequence = maxi(last_sequence, int(sequence))

func next_action_sequence() -> int:
	# A request only uses the last authoritative value; sending never advances it.
	return _next_action_sequence

func clear() -> void:
	bearer_token = ""
	csrf_token = ""
	profile.clear()
	expires_at = null
	match_id = ""
	last_sequence = 0
	_next_action_sequence = 1
