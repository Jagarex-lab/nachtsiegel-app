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

static func mul_u32(a: int, b: int) -> int:
	# Math.imul low32 without overflowing int64 for two unsigned32 inputs.
	var lo := (a & 0xffff) * (b & 0xffff)
	var cross := ((a >> 16) & 0xffff) * (b & 0xffff) + (a & 0xffff) * ((b >> 16) & 0xffff)
	return (lo + ((cross & 0xffff) << 16)) & MASK
