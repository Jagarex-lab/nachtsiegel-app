extends Node
## Optional client: add explicitly to a scene or test. No autoload or offline hook.
## Native clients use an in-memory Bearer token. Web uses same-origin HttpOnly
## cookies through fetch; no password/token is written to browser storage.
const Protocol = preload("res://scripts/online/online_protocol.gd")
const Session = preload("res://scripts/online/online_session.gd")
signal authenticated(profile: Dictionary)
signal connected
signal disconnected
signal message_received(message: Dictionary)
signal request_completed(operation: String, response: Dictionary)
signal online_error(code: String)
var session := Session.new()
var api_base := "http://127.0.0.1:8787"
var reconnect_enabled := true
var _peer := WebSocketPeer.new()
var _http: HTTPRequest
var _http_busy := false
var _operation := ""
var _http_request_id := ""
var _browser_callback: JavaScriptObject
var _browser_callback_key := ""
var _was_open := false
var _connecting := false
var _connect_deadline_ms := 0
var _want_connection := false
var _retry_attempt := 0
var _retry_at_ms := 0

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_native_response)
	if OS.has_feature("web"):
		api_base = str(JavaScriptBridge.eval("window.location.origin", true))
		_browser_callback = JavaScriptBridge.create_callback(_on_browser_response)
		_browser_callback_key = "__orafold_http_" + str(get_instance_id())
		JavaScriptBridge.get_interface("window").set(_browser_callback_key, _browser_callback)
	set_process(true)

func configure_base(url: String) -> bool:
	var normalized := url.trim_suffix("/")
	if OS.has_feature("web"):
		if normalized != str(JavaScriptBridge.eval("window.location.origin", true)):
			return false
	elif not normalized.begins_with("https://") and not normalized in ["http://127.0.0.1:8787", "http://localhost:8787"]:
		return false
	api_base = normalized
	return true

func register_account(username: String, password: String, display_name: String) -> Error:
	return _request("register", "/auth/register", {"username": username, "password": password, "display_name": display_name})

func login(username: String, password: String) -> Error:
	var body := {"username": username, "password": password}
	if not OS.has_feature("web"):
		body.client = "native"
	return _request("login", "/auth/login", body)

func resume_cookie_session() -> Error:
	# Same-origin GET bootstrap recovers CSRF while the cookie stays HttpOnly.
	return _request("resume", "/auth/session", {}, true)

func rotate_session() -> Error:
	return _request("rotate", "/auth/rotate", {})

func load_profile() -> Error:
	return _request("profile", "/profile", {}, true)

func connect_online() -> Error:
	_want_connection = true
	return _request("ticket", "/transport/ticket", {})

func logout() -> Error:
	if _http_busy:
		return ERR_BUSY
	_want_connection = false
	_retry_at_ms = 0
	_peer.close(1000, "logout")
	var result := _request("logout", "/auth/logout", {})
	# Revocation happens remotely; clear local data even when the request fails.
	session.clear()
	return result

func send_intent(message_type: String, payload: Dictionary = {}, request_id: String = "") -> Error:
	if _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_CONNECTION_ERROR
	var envelope := Protocol.request(message_type, payload, request_id)
	if envelope.is_empty():
		return ERR_INVALID_PARAMETER
	return _peer.send_text(JSON.stringify(envelope))

func advance_fixture() -> Error:
	return send_intent("match.action", {"match_id": session.match_id, "sequence": session.next_action_sequence(), "action": {"type": "advance"}})

func _request(operation: String, path: String, body: Dictionary, is_get := false) -> Error:
	if _http_busy or not is_instance_valid(_http):
		return ERR_BUSY
	_http_busy = true
	_operation = operation
	_http_request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var headers := {"Content-Type": "application/json"}
	if not session.bearer_token.is_empty():
		headers.Authorization = "Bearer " + session.bearer_token
	if not session.csrf_token.is_empty():
		headers["X-CSRF-Token"] = session.csrf_token
	if OS.has_feature("web"):
		var source := """
(async () => {
 const controller = new AbortController();
 const timer = setTimeout(() => controller.abort(), 15000);
 const callback = window[%s];
 try {
  const response = await fetch(%s, {method:%s, credentials:'same-origin',
   headers:%s, body:%s, signal:controller.signal});
  callback(%s, response.status, await response.text());
 } catch (_) { callback(%s, 0, '{}'); }
 finally { clearTimeout(timer); }
})();
""" % [JSON.stringify(_browser_callback_key), JSON.stringify(api_base + path), JSON.stringify("GET" if is_get else "POST"), JSON.stringify(headers), "undefined" if is_get else JSON.stringify(JSON.stringify(body)), JSON.stringify(_http_request_id), JSON.stringify(_http_request_id)]
		JavaScriptBridge.eval(source, true)
		return OK
	var native_headers := PackedStringArray()
	for key in headers:
		native_headers.append(str(key) + ": " + str(headers[key]))
	var error := _http.request(api_base + path, native_headers, HTTPClient.METHOD_GET if is_get else HTTPClient.METHOD_POST, "" if is_get else JSON.stringify(body))
	if error != OK:
		_http_busy = false
	return error

func _on_native_response(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_finish_response(status if result == HTTPRequest.RESULT_SUCCESS else 0, body.get_string_from_utf8())

func _on_browser_response(arguments: Array) -> void:
	if arguments.size() == 3 and str(arguments[0]) == _http_request_id:
		_finish_response(int(arguments[1]), str(arguments[2]))

func _finish_response(status: int, raw_body: String) -> void:
	var operation := _operation
	_http_busy = false
	_operation = ""
	var parsed: Variant = JSON.parse_string(raw_body)
	var response: Dictionary = parsed if parsed is Dictionary else {}
	if status < 200 or status >= 300:
		if status == 401:
			_want_connection = false
			_retry_at_ms = 0
			_peer.close(1000, "session expired")
			session.clear()
		online_error.emit(str(response.get("code", "HTTP_" + str(status))))
		if operation == "ticket":
			_schedule_reconnect()
		return
	if operation in ["login", "rotate", "resume"]:
		if not session.accept_login(response):
			online_error.emit("INVALID_AUTH_RESPONSE")
			return
		authenticated.emit(session.profile.duplicate(true))
	elif operation == "ticket":
		var ticket: Variant = response.get("ticket")
		if not ticket is String or ticket.is_empty():
			online_error.emit("INVALID_TICKET")
			return
		var socket_base := api_base.replace("https://", "wss://").replace("http://", "ws://")
		_peer = WebSocketPeer.new()
		_peer.inbound_buffer_size = Protocol.MAX_MESSAGE_BYTES * 4
		_peer.outbound_buffer_size = Protocol.MAX_MESSAGE_BYTES * 2
		var error := _peer.connect_to_url(socket_base + "/ws?ticket=" + ticket.uri_encode())
		_connecting = error == OK
		_connect_deadline_ms = Time.get_ticks_msec() + 15000
		if error != OK:
			online_error.emit("WS_CONNECT")
			_schedule_reconnect()
	request_completed.emit(operation, response)

func _process(_delta: float) -> void:
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_connecting = false
		if not _was_open:
			_was_open = true
			_retry_attempt = 0
			connected.emit()
			if not session.match_id.is_empty():
				send_intent("match.reconnect", {"match_id": session.match_id, "after_sequence": session.last_sequence})
			else:
				send_intent("session.resume")
		while _peer.get_available_packet_count() > 0:
			var decoded := Protocol.decode(_peer.get_packet())
			if not decoded.ok:
				online_error.emit(decoded.code)
				_peer.close(1002, "invalid protocol")
				break
			session.observe(decoded.message)
			message_received.emit(decoded.message)
	elif state == WebSocketPeer.STATE_CLOSED and (_was_open or _connecting):
		_was_open = false
		_connecting = false
		disconnected.emit()
		_schedule_reconnect()
	elif state == WebSocketPeer.STATE_CONNECTING and _connect_deadline_ms > 0 and Time.get_ticks_msec() >= _connect_deadline_ms:
		_peer.close()
		_connecting = false
		_schedule_reconnect()
	if _want_connection and _retry_at_ms > 0 and Time.get_ticks_msec() >= _retry_at_ms and not _http_busy:
		_retry_at_ms = 0
		connect_online()

func _schedule_reconnect() -> void:
	if _want_connection and reconnect_enabled and _retry_attempt < 10:
		_retry_attempt += 1
		_retry_at_ms = Time.get_ticks_msec() + mini(15000, 1000 * int(pow(2, mini(_retry_attempt - 1, 4))))

func _exit_tree() -> void:
	_want_connection = false
	_peer.close(1000, "client closed")
	session.clear()
	if OS.has_feature("web") and not _browser_callback_key.is_empty():
		JavaScriptBridge.eval("delete window[%s]" % JSON.stringify(_browser_callback_key), true)
