extends SceneTree
## Emits the exact browser expressions used by SaveAdapter; no Web export needed.
const Store = preload("res://scripts/economy/save_adapter.gd")
func _initialize() -> void:
	var key := "orafold.economy.browser-test"
	var first := {"wallet": {"gold": 100}, "receipts": {"first": true}}
	var second := {"wallet": {"gold": 0}, "receipts": {"first": true, "purchase": true}}
	var first_envelope := Store.web_envelope_for_save(first, {})
	var second_envelope := Store.web_envelope_for_save(second, first_envelope)
	var third_envelope := Store.web_envelope_for_save({"wallet":{"gold":25},"receipts":{"third":true}}, second_envelope)
	# Reproduce the actual JavaScriptBridge read/JSON.parse numeric transport;
	# using only native int fixtures misses Godot's 1 -> 1.0 CAS representation.
	var parsed_second: Dictionary = JSON.parse_string(JSON.stringify(second_envelope))
	print("ECONOMY_WEB_SCRIPTS=" + JSON.stringify({"key": key, "read": Store.web_read_script(key), "first": Store.web_write_script(key, first_envelope), "second": Store.web_write_script(key, second_envelope), "compare_third":Store.web_compare_write_script(key, third_envelope, parsed_second), "stale":Store.web_compare_write_script(key, first_envelope, parsed_second)}))
	quit()
