extends Node
## Bounded same-origin image delivery; never owns battle/profile state.
const ART = preload("res://scripts/production/art_resolver.gd")
const MANIFEST := "res://data/production/art_delivery.json"
const PREVIEWS := "res://data/production/art_preview_delivery.json"
const MAX_BYTES := 8 * 1024 * 1024
const MAX_PREVIEW_BYTES := 1024 * 1024
const MAX_PENDING := 4
const MAX_PREVIEW_PENDING := 24
const RETRY_MSEC := 30000
const WEB_FETCH_GUARD := """(() => {
  const prefix = __ART_PREFIX__;
  const key = Symbol.for('orafold.art.fetch.guard.v2');
  let guard = window[key];
  if (!guard) {
    const original = window.fetch;
    guard = { original, prefixes: new Map(), controllers: new Map() };
    guard.finish = function(url, abort) {
      const group = guard.controllers.get(url);
      if (group && abort) for (const controller of group) controller.abort();
      guard.controllers.delete(url);
    };
    guard.wrapper = function(resource, options) {
      let url;
      try { url = new URL(typeof resource === 'string' ? resource : resource.url || String(resource), window.location.href); }
      catch (_) { return original.call(this, resource, options); }
      const guarded = url.origin === window.location.origin && Array.from(guard.prefixes.keys()).some(value => url.href.startsWith(value));
      if (!guarded) return original.call(this, resource, options);
      const controller = new AbortController();
      const group = guard.controllers.get(url.href) || new Set();
      group.add(controller); guard.controllers.set(url.href, group);
      return original.call(this, resource, { ...options, redirect: 'error', mode: 'same-origin', credentials: 'omit', signal: controller.signal }).then(response => {
        if (!response.body) return response;
        const reader = response.body.getReader();
        let finished = false;
        const body = new ReadableStream({
          async pull(stream) {
            if (finished) return;
            try {
              const result = await reader.read();
              if (finished) return;
              if (result.done || controller.signal.aborted) { finished = true; stream.close(); }
              else stream.enqueue(result.value);
            } catch (error) {
              if (finished) return;
              finished = true;
              if (controller.signal.aborted) stream.close(); else stream.error(error);
            }
          },
          cancel(reason) {
            finished = true;
            return reader.cancel(reason).catch(error => { if (!controller.signal.aborted) throw error; });
          },
        });
        return new Response(body, { status: response.status, statusText: response.statusText, headers: response.headers });
      }).catch(error => {
        group.delete(controller);
        if (group.size === 0 && guard.controllers.get(url.href) === group) guard.controllers.delete(url.href);
        // Godot logs even a freed fetch's rejection. Only our explicit owner
        // cancellation becomes an empty failure response, never loaded art.
        if (controller.signal.aborted) return new Response(null, { status: 499 });
        throw error;
      });
    };
    window.fetch = guard.wrapper;
    window[key] = guard;
  }
  guard.prefixes.set(prefix, (guard.prefixes.get(prefix) || 0) + 1);
  return true;
})()"""
const WEB_FETCH_RELEASE := """(() => {
  const key = Symbol.for('orafold.art.fetch.guard.v2');
  const guard = window[key];
  if (!guard) return;
  const prefix = __ART_PREFIX__;
  const count = (guard.prefixes.get(prefix) || 0) - 1;
  if (count > 0) guard.prefixes.set(prefix, count); else guard.prefixes.delete(prefix);
  for (const url of Array.from(guard.controllers.keys())) {
    if (!Array.from(guard.prefixes.keys()).some(value => url.startsWith(value))) guard.finish(url, true);
  }
  if (guard.prefixes.size === 0 && window.fetch === guard.wrapper) {
    window.fetch = guard.original;
    delete window[key];
  }
})()"""
var _origin_override := ""
var _origin := ""
var _entries: Dictionary = {}
var _previews: Dictionary = {}
var _states: Dictionary = {}
var _retry_after: Dictionary = {}
var _owners: Dictionary = {}
var _unowned: Dictionary = {}
var _queue: Array[String] = []
var _active := ""
var _http: HTTPRequest
var _response_callback: Callable
var stale_callbacks := 0
var _web_guard_installed := false
var requests_started := 0
var completed := 0
var rejected := 0
var cancelled := 0
var _started_profiles := {"full": 0, "compact": 0}
var _last_http_result := -1
var _last_http_status := 0
var _last_body_bytes := 0
var _last_failure := ""
# Bounded transfer evidence survives later successful previews. Images and
# response bodies are never retained in diagnostics, only their checked hashes.
var _recent_events: Array[Dictionary] = []
var _recent_failures: Array[Dictionary] = []
var _transfer_sequence := 0
var _active_sequence := 0
var _last_body_sha256 := ""

func _init(origin_override := "") -> void: _origin_override = origin_override
func _ready() -> void:
	_origin = str(JavaScriptBridge.eval("new URL('.', window.location.href).href")) if OS.has_feature("web") else _origin_override
	if not (_origin.begins_with("https://") or _origin.begins_with("http://127.0.0.1:") or _origin.begins_with("http://localhost:")): _origin = ""
	if not _origin.is_empty() and not _origin.ends_with("/"): _origin += "/"
	if OS.has_feature("web") and not _origin.is_empty():
		_web_guard_installed = bool(JavaScriptBridge.eval(WEB_FETCH_GUARD.replace("__ART_PREFIX__", JSON.stringify(_origin + "art/"))))
		if not _web_guard_installed: _origin = ""
	_load_entries(MANIFEST, "full")
	_load_entries(PREVIEWS, "compact")

func _load_entries(path: String, profile: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var expected := "orafold-web-art-v1" if profile == "full" else "orafold-web-preview-v1"
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or parsed.get("profile") != expected or not parsed.get("entries") is Dictionary or parsed.entries.size() > 550: return
	for id in parsed.entries:
		var item: Variant = parsed.entries[id]
		if not item is Dictionary: continue
		var source := ART.manifest_entry(str(id))
		if source.get("sha256", "") != item.get("source_sha256", ""): continue
		if profile == "compact":
			if item.get("delivery") != "external" or source.get("preview_sha256", "") != item.get("preview_sha256", "") or source.get("preview_asset_path", "") != item.get("asset_path", ""): continue
		if not item.get("web_sha256") is String: continue
		var sha: String = item.web_sha256
		var folder := "full" if profile == "full" else "preview"
		if sha.length() != 64 or not sha.is_valid_hex_number(false) or item.get("relative_url") != "art/" + folder + "/" + sha + ".webp": continue
		var minimum_width := 1024 if profile == "full" else 1
		var minimum_height := 768 if profile == "full" else 1
		var maximum_edge := 4096 if profile == "full" else 512
		var limit := MAX_BYTES if profile == "full" else MAX_PREVIEW_BYTES
		if not _whole(item.get("width"), minimum_width, maximum_edge) or not _whole(item.get("height"), minimum_height, maximum_edge) or not _whole(item.get("bytes"), 1, limit): continue
		var width_key := "original_width" if profile == "full" else "preview_width"
		var height_key := "original_height" if profile == "full" else "preview_height"
		if item.width != source.get(width_key) or item.height != source.get(height_key): continue
		if float(item.width) * float(item.height) * 4.0 * 4.0 / 3.0 > ART.MAX_CACHE_BYTES: continue
		if profile == "full": _entries[str(id)] = item.duplicate(true)
		else: _previews[str(id)] = item.duplicate(true)

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum
func external_enabled() -> bool: return not _origin.is_empty()
func external_preview(card_id: String) -> bool: return _previews.has(card_id)
func _key(card_id: String, profile: String) -> String: return profile + "|" + card_id
func _profile(key: String) -> String: return key.get_slice("|", 0)
func _id(key: String) -> String: return key.get_slice("|", 1)
func _entry(key: String) -> Dictionary: return (_entries if _profile(key) == "full" else _previews).get(_id(key), {})
func _cached(card_id: String, profile: String) -> bool: return ART.has_full_texture(card_id) if profile == "full" else ART.has_preview_texture(card_id)
func state_for(card_id: String, profile := "full") -> String:
	if _cached(card_id, profile): return "ready"
	var state := str(_states.get(_key(card_id, profile), "preview")) if not _origin.is_empty() else "preview"
	return "preview" if state == "ready" else state
func _changed(key: String) -> void: ART.delivery_changed(_id(key), _profile(key))
func _live_owner(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node and ART.visible_owner(value)
func _prune_owners() -> void:
	for key in _owners.keys():
		var owners: Dictionary = _owners[key]
		for owner_id in owners.keys():
			var reference: WeakRef = owners[owner_id]
			if not _live_owner(reference.get_ref()): owners.erase(owner_id)
		if owners.is_empty(): _owners.erase(key)
func _needed(key: String) -> bool: return _unowned.has(key) or (_owners.has(key) and not _owners[key].is_empty())
func preview_visible(card_id: String) -> bool: return _owners.has(_key(card_id, "compact")) and not _owners[_key(card_id, "compact")].is_empty()
func texture_visible(card_id: String, profile: String) -> bool: return _owners.has(_key(card_id, profile)) and not _owners[_key(card_id, profile)].is_empty()
func release_owner(owner: Node) -> void:
	for key in _owners.keys():
		_owners[key].erase(owner.get_instance_id())
		if _owners[key].is_empty(): _owners.erase(key)
	_drop_unneeded()
func request_full(card_id: String, owner: Node = null) -> void: _request(card_id, "full", owner)
func request_preview(card_id: String, owner: Node) -> void:
	if owner != null: _request(card_id, "compact", owner)
func _request(card_id: String, profile: String, owner: Node) -> void:
	if _origin.is_empty() or not (_entries if profile == "full" else _previews).has(card_id): return
	var key := _key(card_id, profile)
	if owner != null:
		if not _live_owner(owner): return
		if not _owners.has(key): _owners[key] = {}
		_owners[key][owner.get_instance_id()] = weakref(owner)
	elif profile == "full": _unowned[key] = true
	else: return
	if _cached(card_id, profile) or key == _active or _queue.has(key) or Time.get_ticks_msec() < int(_retry_after.get(key, 0)): return
	_prune_owners(); _drop_unneeded()
	var limit := MAX_PENDING if profile == "full" else MAX_PREVIEW_PENDING
	var pending: Array[String] = []
	for queued in _queue:
		if _profile(queued) == profile: pending.append(queued)
	if pending.size() >= limit:
		var discarded: String = pending.back() if profile == "full" else pending.front()
		_queue.erase(discarded); _states[discarded] = "preview"; _unowned.erase(discarded); _changed(discarded)
	if profile == "full": _queue.push_front(key)
	else: _queue.push_back(key)
	_states[key] = "loading"; _changed(key)
	if profile == "full" and not _active.is_empty() and _profile(_active) == "compact":
		var previous := _active
		_cancel_active()
		if _needed(previous): _queue.push_back(previous); _states[previous] = "loading"; _changed(previous)
	_start_next.call_deferred()
func _process(_delta: float) -> void:
	_prune_owners(); _drop_unneeded()
	# A still-visible face must recover after the existing cooldown even when
	# its binding is stable and no offscreen quality-label lookup occurs.
	for key in _owners.keys():
		if _states.get(key,"")!="failed" or Time.get_ticks_msec()<int(_retry_after.get(key,0)):continue
		for reference in _owners[key].values():
			var owner: Node=reference.get_ref()
			if _live_owner(owner):_request(_id(key),_profile(key),owner);break
func _drop_unneeded() -> void:
	for key in _queue.duplicate():
		if not _needed(key): _queue.erase(key); _states[key] = "preview"; _changed(key)
	if not _active.is_empty() and not _needed(_active): _cancel_active()
func _finish_web(key: String, abort: bool) -> void:
	if not _web_guard_installed or key.is_empty(): return
	var entry := _entry(key)
	if entry.is_empty(): return
	var url := _origin + str(entry.relative_url)
	JavaScriptBridge.eval("(()=>{const g=window[Symbol.for('orafold.art.fetch.guard.v2')];if(g)g.finish(" + JSON.stringify(url) + "," + ("true" if abort else "false") + ");})()")
func _record_transfer(event: String, key: String, extra: Dictionary = {}) -> void:
	var entry:=_entry(key)
	var row: Dictionary={"event":event,"key":key,"request":_active_sequence,"msec":Time.get_ticks_msec(),"needed":_needed(key),"owners":_owners.get(key,{}).size(),"expected_bytes":int(entry.get("bytes",0))}
	row.merge(extra)
	_recent_events.append(row)
	if _recent_events.size()>32:_recent_events.pop_front()
	if event=="failed":
		_recent_failures.append(row.duplicate(true))
		if _recent_failures.size()>16:_recent_failures.pop_front()

func _cancel_active() -> void:
	if _active.is_empty(): return
	var key := _active
	_record_transfer("cancelled",key)
	_active = "";_active_sequence=0
	_retire_http();_finish_web(key, true)
	cancelled += 1; _states[key] = "preview"; _changed(key)
	_start_next.call_deferred()
func _retire_http() -> void:
	if is_instance_valid(_http):
		if _http.request_completed.is_connected(_response_callback):_http.request_completed.disconnect(_response_callback)
		_http.cancel_request();_http.queue_free()
	_http=null;_response_callback=Callable()

func _start_next() -> void:
	if not _active.is_empty() or _queue.is_empty() or _origin.is_empty(): return
	_prune_owners(); _drop_unneeded()
	if _queue.is_empty(): return
	var next_index := 0
	for index in _queue.size():
		if _profile(_queue[index]) == "full": next_index = index; break
	_active = _queue[next_index]; _queue.remove_at(next_index)
	var entry := _entry(_active)
	_last_http_result = -1; _last_http_status = 0; _last_body_bytes = 0; _last_body_sha256 = ""; _last_failure = ""
	_transfer_sequence+=1;_active_sequence=_transfer_sequence
	# Godot's deferred native _request_done cancels its HTTPRequest before
	# emitting. Never reuse that node: an old completion could otherwise cancel
	# the new transfer before a script-level callback guard can inspect it.
	_retire_http()
	_http=HTTPRequest.new();_http.timeout=10;_http.max_redirects=0
	_http.body_size_limit=MAX_BYTES if _profile(_active)=="full" else MAX_PREVIEW_BYTES
	_response_callback=_received.bind(_active_sequence,_active)
	add_child(_http);_http.request_completed.connect(_response_callback)
	_record_transfer("started",_active)
	requests_started += 1; _started_profiles[_profile(_active)] += 1
	var code := _http.request(_origin + str(entry.relative_url), [], HTTPClient.METHOD_GET)
	if code != OK: _fail("request_failed")
func _fail(reason: String) -> void:
	if _active.is_empty(): return
	var key := _active
	_finish_web(key, false)
	_states[key] = "failed"; _retry_after[key] = Time.get_ticks_msec() + RETRY_MSEC
	_record_transfer("failed",key,{"reason":reason,"http_result":_last_http_result,"http_status":_last_http_status,"body_bytes":_last_body_bytes,"body_sha256":_last_body_sha256,"expected_sha256":str(_entry(key).get("web_sha256",""))})
	_last_failure = reason; rejected += 1; _active = "";_active_sequence=0; _unowned.erase(key)
	_retire_http()
	_changed(key); _start_next.call_deferred()
func _received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, sequence: int, expected_key: String) -> void:
	if _active.is_empty() or sequence!=_active_sequence or expected_key!=_active:
		stale_callbacks+=1
		_record_transfer("stale_callback",expected_key,{"callback_request":sequence,"active_key":_active,"http_result":result,"http_status":response_code,"body_bytes":body.size()})
		return
	var key := _active
	var entry := _entry(key)
	_last_http_result = result; _last_http_status = response_code; _last_body_bytes = body.size()
	var hash_context := HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256)
	if not body.is_empty():hash_context.update(body)
	_last_body_sha256=hash_context.finish().hex_encode()
	_record_transfer("response",key,{"http_result":result,"http_status":response_code,"body_bytes":body.size(),"body_sha256":_last_body_sha256})
	if result != HTTPRequest.RESULT_SUCCESS: _fail("transport_failed"); return
	if response_code != 200: _fail("http_status"); return
	if body.size() != int(entry.bytes): _fail("byte_length"); return
	if _last_body_sha256 != entry.web_sha256: _fail("hash_mismatch"); return
	var image := Image.new()
	if image.load_webp_from_buffer(body) != OK or image.is_empty() or image.get_width() != int(entry.width) or image.get_height() != int(entry.height): _fail("invalid_image"); return
	if image.generate_mipmaps() != OK: _fail("invalid_mipmaps"); return
	var texture := ImageTexture.create_from_image(image)
	var stored: bool = ART.store_delivered_full(_id(key), texture) if _profile(key) == "full" else ART.store_delivered_preview(_id(key), texture)
	if not stored: _fail("cache_rejected"); return
	_finish_web(key, false)
	_record_transfer("ready",key)
	_states[key] = "ready"; _retry_after.erase(key); completed += 1; _active = "";_active_sequence=0; _unowned.erase(key)
	_retire_http()
	_changed(key); _start_next.call_deferred()
func metrics() -> Dictionary:
	return {"started": requests_started, "completed": completed, "rejected": rejected, "cancelled": cancelled,"stale_callbacks":stale_callbacks, "queued": _queue.size(), "active": _active, "origin_enabled": not _origin.is_empty(), "full_entries": _entries.size(), "preview_entries": _previews.size(), "owner_keys": _owners.size(), "started_profiles": _started_profiles.duplicate(), "last_http_result": _last_http_result, "last_http_status": _last_http_status, "last_body_bytes": _last_body_bytes, "last_failure": _last_failure,"recent_events":_recent_events.duplicate(true),"recent_failures":_recent_failures.duplicate(true)}
func _exit_tree() -> void:
	_retire_http()
	_finish_web(_active, true)
	if _web_guard_installed:
		JavaScriptBridge.eval(WEB_FETCH_RELEASE.replace("__ART_PREFIX__", JSON.stringify(_origin + "art/")))
		_web_guard_installed = false
	_queue.clear(); _active = ""; _owners.clear(); _unowned.clear()
