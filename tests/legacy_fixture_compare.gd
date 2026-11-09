extends RefCounted
## Structural JSON comparison for P01c, deliberately not P11 replay hashing.
const MAX_SAFE_NUMBER := 9007199254740991.0
static func _kind(value: Variant) -> String:
	if value==null:return "null"
	if value is bool:return "boolean"
	if value is int or value is float:return "number"
	if value is String:return "string"
	if value is Array:return "array"
	if value is Dictionary:return "object"
	return "unsupported"
static func _pointer(key: String) -> String:
	return key.replace("~","~0").replace("/","~1")
static func difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	var kind := _kind(expected)
	if kind!=_kind(actual):return {"path":path,"reason":"type"}
	match kind:
		"number":
			if not is_finite(float(expected)) or not is_finite(float(actual)) or abs(float(expected))>MAX_SAFE_NUMBER or abs(float(actual))>MAX_SAFE_NUMBER:
				return {"path":path,"reason":"unsupported_number"}
			if float(expected)!=float(actual):return {"path":path,"reason":"value"}
		"array":
			if expected.size()!=actual.size():return {"path":path,"reason":"array_length"}
			for index in expected.size():
				var delta := difference(expected[index],actual[index],path+"/"+str(index))
				if not delta.is_empty():return delta
		"object":
			var keys: Array = expected.keys()
			for key in actual:
				if not keys.has(key):keys.append(key)
			for key in keys:
				if not key is String:return {"path":path,"reason":"unsupported_key"}
			keys.sort()
			for key: String in keys:
				var child := path+"/"+_pointer(key)
				if not expected.has(key) or not actual.has(key):return {"path":child,"reason":"missing_or_extra_field"}
				var delta := difference(expected[key],actual[key],child)
				if not delta.is_empty():return delta
		"null","boolean","string":
			if expected!=actual:return {"path":path,"reason":"value"}
		_:
			return {"path":path,"reason":"unsupported_value"}
	return {}
