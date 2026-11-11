extends RefCounted
## Transport-only protocol fixture. This script contains no ORAFOLD combat rules.
const VERSION := 1
const MAX_MESSAGE_BYTES := 8192
const MAX_RESPONSE_BYTES := 262144
const REQUEST_FIELDS := {
	"session.resume": [],
	"catalog.get": [],
	"deck.select": ["selection"],
	"social.list": [],
	"social.request": ["target_user_id"],
	"social.accept": ["target_user_id"],
	"social.remove": ["target_user_id"],
	"social.block": ["target_user_id"],
	"matchmaking.join": ["mode", "region"],
	"matchmaking.leave": [],
	"private.create": [],
	"private.join": ["invite_code"],
	"match.ready": ["match_id"],
	"match.action": ["match_id", "sequence", "action"],
	"match.reconnect": ["match_id", "after_sequence"],
}

static func request(message_type: String, payload: Dictionary = {}, request_id: String = "") -> Dictionary:
	if not REQUEST_FIELDS.has(message_type):
		return {}
	for field in payload:
		if not field in REQUEST_FIELDS[message_type]:
			return {}
	if message_type == "match.action":
		var action: Variant = payload.get("action")
		if not action is Dictionary:
			return {}
		if action.get("type")=="command":
			if action.size()!=3 or not action.get("name") is String or not action.get("args") is Array:return {}
		elif action.size()!=1 or action.get("type")!="concede":return {}
		if not payload.get("sequence") is int or payload.sequence < 1:
			return {}
	if request_id.is_empty():
		request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if RegEx.create_from_string("^[A-Za-z0-9_-]{1,80}$").search(request_id) == null:
		return {}
	var envelope := payload.duplicate(true)
	envelope.protocol_version = VERSION
	envelope.type = message_type
	envelope.request_id = request_id
	return envelope if JSON.stringify(envelope).to_utf8_buffer().size() <= MAX_MESSAGE_BYTES else {}

static func decode(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_RESPONSE_BYTES:
		return {"ok": false, "code": "MESSAGE_SIZE"}
	var parser := JSON.new()
	if parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok": false, "code": "INVALID_JSON"}
	var message: Dictionary = parser.data
	if message.get("protocol_version") != VERSION or not message.get("type") is String or message.type.is_empty():
		return {"ok": false, "code": "PROTOCOL_VERSION"}
	return {"ok": true, "message": message}
