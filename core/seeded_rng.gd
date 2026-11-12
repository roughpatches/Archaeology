extends RefCounted
## Deterministic randomness for game rules.
##
## Everything in core/ that needs randomness takes one of these, so the same seed always
## makes the same floor, find or reading. Never call the global randi()/randf() in core/.

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	_rng.seed = p_seed


## A float in [0, 1).
func next_float() -> float:
	return _rng.randf()


## An int in [from, to], both ends included.
func range_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## True with probability p.
func chance(p: float) -> bool:
	return _rng.randf() < p


## One element of a non-empty array.
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "pick() needs a non-empty array")
	return items[_rng.randi_range(0, items.size() - 1)]


## An index chosen in proportion to its weight. Zero or negative weights are never chosen.
## Returns -1 if no weight is positive.
func weighted_index(weights: Array) -> int:
	var total := 0.0
	for w: Variant in weights:
		total += maxf(float(w), 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	for i in weights.size():
		var w := maxf(float(weights[i]), 0.0)
		if w <= 0.0:
			continue
		if roll < w:
			return i
		roll -= w
	# Floating-point leftovers: fall back to the last positive weight.
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return -1


## A shuffled copy of the array (Fisher-Yates); the original is left alone.
func shuffled(items: Array) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## A child seed for a named part of the world, e.g. derive(world_seed, ["cave", 3]) for floor 3.
## Same inputs, same seed.
static func derive(base_seed: int, parts: Array) -> int:
	var key := str(base_seed)
	for part: Variant in parts:
		key += "/" + str(part)
	return key.hash()
