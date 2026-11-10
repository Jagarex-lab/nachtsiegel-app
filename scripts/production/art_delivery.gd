extends Node
## Same-origin illustration delivery only. Never owns battle/profile state.
const ART = preload("res://scripts/production/art_resolver.gd")
const MANIFEST := "res://data/production/art_delivery.json"
const MAX_BYTES := 8 * 1024 * 1024
const MAX_PENDING := 4
const RETRY_MSEC := 30000
const WEB_FETCH_GUARD := """(() => {
  const prefix = __ART_PREFIX__;
  const key = Symbol.for('orafold.art.fetch.guard.v1');
  let guard = window[key];
  if (!guard) {
    const original = window.fetch;
    guard = { original, prefixes: new Map() };
    guard.wrapper = function(resource, options) {
      let url;
      try { url = new URL(typeof resource === 'string' ? resource : resource.url || String(resource), window.location.href); }
      catch (_) { return original.call(this, resource, options); }
      const guarded = url.origin === window.location.origin && Array.from(guard.prefixes.keys()).some(value => url.href.startsWith(value));
      return original.call(this, resource, guarded ? { ...options, redirect: 'error', mode: 'same-origin', credentials: 'omit' } : options);
    };
    window.fetch = guard.wrapper;
    window[key] = guard;
  }
  guard.prefixes.set(prefix, (guard.prefixes.get(prefix) || 0) + 1);
  return true;
})()"""
const WEB_FETCH_RELEASE := """(() => {
  const key = Symbol.for('orafold.art.fetch.guard.v1');
  const guard = window[key];
  if (!guard) return;
  const prefix = __ART_PREFIX__;
  const count = (guard.prefixes.get(prefix) || 0) - 1;
  if (count > 0) guard.prefixes.set(prefix, count); else guard.prefixes.delete(prefix);
  if (guard.prefixes.size === 0 && window.fetch === guard.wrapper) {
    window.fetch = guard.original;
    delete window[key];
  }
})()"""
var _origin_override := ""
var _origin := ""
var _entries: Dictionary = {}
var _states: Dictionary = {}
var _retry_after: Dictionary = {}
var _queue: Array[String] = []
var _active := ""
var _http: HTTPRequest
var requests_started := 0
var completed := 0
var rejected := 0
var _web_guard_installed := false

func _init(origin_override := "") -> void:
	# Dependency injection supports real native HTTP integration tests and future
	# native content delivery. The normal native autoload has no origin/network.
	_origin_override = origin_override

func _ready() -> void:
	if OS.has_feature("web"):
		# Base tags must not redirect image requests to a different origin.
		_origin = str(JavaScriptBridge.eval("new URL('.', window.location.href).href"))
	else: _origin = _origin_override
	if not (_origin.begins_with("https://") or _origin.begins_with("http://127.0.0.1:") or _origin.begins_with("http://localhost:")): _origin = ""
	if not _origin.is_empty() and not _origin.ends_with("/"): _origin += "/"
	if OS.has_feature("web") and not _origin.is_empty():
		# Godot4.6.3's Web HTTP client delegates to browser fetch without a
		# redirect option. Enforce refusal only for this same-origin art prefix;
		# unrelated engine/PCK/wasm requests preserve their original behavior.
		_web_guard_installed = bool(JavaScriptBridge.eval(WEB_FETCH_GUARD.replace("__ART_PREFIX__", JSON.stringify(_origin + "art/full/"))))
		if not _web_guard_installed: _origin = ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	if parsed is Dictionary and parsed.get("schema_version") == 1 and parsed.get("profile") == "orafold-web-art-v1" and parsed.get("entries") is Dictionary and parsed.entries.size() <= 550:
		for id in parsed.entries:
			var item: Variant = parsed.entries[id]
			if not item is Dictionary or not item.get("web_sha256") is String: continue
			var sha: String = item.web_sha256
			if sha.length() != 64 or not sha.is_valid_hex_number(false) or item.get("relative_url") != "art/full/" + sha + ".webp": continue
			if not _whole(item.get("width"), 1024, 4096) or not _whole(item.get("height"), 768, 4096) or not _whole(item.get("bytes"), 1, MAX_BYTES): continue
			if ART.manifest_entry(str(id)).get("sha256", "") != item.get("source_sha256", ""): continue
			_entries[str(id)] = item.duplicate(true)
	if not _origin.is_empty():
		_http = HTTPRequest.new(); _http.body_size_limit = MAX_BYTES; _http.timeout = 10; _http.max_redirects = 0
		add_child(_http); _http.request_completed.connect(_received)

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func state_for(card_id: String) -> String:
	if ART.has_full_texture(card_id): return "ready"
	var state := str(_states.get(card_id, "preview")) if not _origin.is_empty() else "preview"
	return "preview" if state == "ready" else state

func external_enabled() -> bool: return not _origin.is_empty()

func request_full(card_id: String) -> void:
	if _http == null or not _entries.has(card_id) or ART.has_full_texture(card_id): return
	if card_id == _active or _queue.has(card_id) or Time.get_ticks_msec() < int(_retry_after.get(card_id, 0)): return
	if _queue.size() >= MAX_PENDING:
		var discarded: String = _queue.pop_back(); _states[discarded] = "preview"; ART.delivery_changed(discarded)
	_queue.push_front(card_id); _states[card_id] = "loading"; ART.delivery_changed(card_id)
	_start_next.call_deferred()

func _start_next() -> void:
	if not _active.is_empty() or _queue.is_empty() or _http == null: return
	_active = _queue.pop_front()
	var entry: Dictionary = _entries[_active]
	requests_started += 1
	var code := _http.request(_origin + str(entry.relative_url), [], HTTPClient.METHOD_GET)
	if code != OK: _fail("request_failed")

func _fail(_reason: String) -> void:
	if _active.is_empty(): return
	var id := _active
	_states[id] = "failed"; _retry_after[id] = Time.get_ticks_msec() + RETRY_MSEC
	rejected += 1; _active = ""; ART.delivery_changed(id); _start_next.call_deferred()

func _received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _active.is_empty(): return
	var id := _active
	var entry: Dictionary = _entries[id]
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.size() != int(entry.bytes): _fail("http_failed"); return
	var hash_context := HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256); hash_context.update(body)
	if hash_context.finish().hex_encode() != entry.web_sha256: _fail("hash_mismatch"); return
	var image := Image.new()
	if image.load_webp_from_buffer(body) != OK or image.is_empty() or image.get_width() != int(entry.width) or image.get_height() != int(entry.height): _fail("invalid_image"); return
	if image.generate_mipmaps() != OK: _fail("invalid_mipmaps"); return
	var texture := ImageTexture.create_from_image(image)
	if not ART.store_delivered_full(id, texture): _fail("cache_rejected"); return
	_states[id] = "ready"; _retry_after.erase(id); completed += 1; _active = ""
	ART.delivery_changed(id); _start_next.call_deferred()

func metrics() -> Dictionary:
	return {"started": requests_started, "completed": completed, "rejected": rejected, "queued": _queue.size(), "active": _active, "origin_enabled": not _origin.is_empty()}

func _exit_tree() -> void:
	if is_instance_valid(_http): _http.cancel_request()
	if _web_guard_installed:
		JavaScriptBridge.eval(WEB_FETCH_RELEASE.replace("__ART_PREFIX__", JSON.stringify(_origin + "art/full/")))
		_web_guard_installed = false
	_queue.clear(); _active = ""
