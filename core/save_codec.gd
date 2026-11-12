extends RefCounted
## Turns game state into save-file text and back.
##
## JSON has one number type, so whole numbers come back from Godot's parser as floats.
## decode() turns any float with no fractional part back into an int, so a saved
## {"day": 3} loads as int 3. Game state should therefore never rely on a value being a
## whole-number float.


static func encode(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true)


## The decoded dictionary, or an empty one if the text isn't a JSON object.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var value: Variant = json.data
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return _restore_ints(value)


static func _restore_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = _restore_ints(value[key])
			return out
		TYPE_ARRAY:
			var arr := []
			for item: Variant in value:
				arr.append(_restore_ints(item))
			return arr
		_:
			return value
