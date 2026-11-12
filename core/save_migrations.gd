extends RefCounted
## The shape of saved game state, and the steps that bring an old save up to date.
##
## Any change to the shape bumps CURRENT_VERSION and adds a _from_N step plus a test.

const CURRENT_VERSION := 1


## Fresh state for a new game on the given world seed.
static func new_game_data(world_seed: int) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"world_seed": world_seed,
		"day": 1,
		"stamina": {"current": 100, "max": 100},
		"inventory": {},
		"finds": [],
		"camp": {"buildings": []},
		"flags": {},
	}


## Returns an up-to-date copy of a save, or an empty dictionary if it can't be read
## (not a dictionary, or written by a newer version of the game). The input is not changed.
static func migrate(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (raw as Dictionary).duplicate(true)
	var version := int(out.get("version", 0))
	if version > CURRENT_VERSION or version < 0:
		return {}
	while version < CURRENT_VERSION:
		match version:
			0:
				out = _from_0(out)
		version += 1
		out["version"] = version
	return out


## Version 0: development saves written before the version field existed.
## Fill in anything missing from a new game, keep everything that is there.
static func _from_0(data: Dictionary) -> Dictionary:
	var base := new_game_data(int(data.get("world_seed", 0)))
	for key: String in base:
		if not data.has(key):
			data[key] = base[key]
	return data
