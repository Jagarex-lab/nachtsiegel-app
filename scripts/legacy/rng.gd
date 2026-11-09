extends RefCounted
## Exact JS rng(seed): unsigned 32-bit LCG; never used for economy/security.
const MASK := 0xffffffff
const DENOMINATOR := 4294967296.0
var state: int
var calls := 0
func _init(seed_value: int = 0) -> void:
	state = seed_value & MASK
func next_float() -> float:
	state = (state * 1664525 + 1013904223) & MASK
	calls += 1
	return float(state) / DENOMINATOR
func shuffle(values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size()-1,0,-1):
		var j := int(floor(next_float()*float(i+1)))
		var saved: Variant = result[i]
		result[i] = result[j]
		result[j] = saved
	return result
