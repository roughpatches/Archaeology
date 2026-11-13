extends RefCounted
## The shape of saved game state, and the steps that bring an old save up to date.
##
## Any change to the shape bumps CURRENT_VERSION and adds a _from_N step plus a test.

const CURRENT_VERSION := 3


## Fresh state for a new game on the given world seed.
static func new_game_data(world_seed: int) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"world_seed": world_seed,
		"day": 1,
		"half": 0,
		"stamina": {"current": 100, "max": 100},
		"gear": starting_gear(),
		"forage": {},
		"coin": 0,
		"boat": new_boat(),
		"museums": {},
		"inventory": {},
		"finds": [],
		"camp": {"buildings": []},
		"flags": {},
	}


## The supply boat's state (D42): how many times it has called, when it next calls, and who is
## here now ({} when it's away).
static func new_boat() -> Dictionary:
	return {"calls": 0, "next_day": 2, "here": {}}


## The pack you start with: one rope anchor and two flares, so the first expedition has a way
## out besides the rope you came in by.
static func starting_gear() -> Dictionary:
	return {"anchor": 1, "flare": 2, "ration": 0}


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
			1:
				out = _from_1(out)
			2:
				out = _from_2(out)
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


## Version 1 to 2 (D35, D39): saves gain the half of the day, a gear pack, and plant regrowth.
static func _from_1(data: Dictionary) -> Dictionary:
	data["half"] = 0
	data["gear"] = starting_gear()
	data["forage"] = {}
	return data


## Version 2 to 3 (D42, D43): coin, the supply boat, and museum collections.
static func _from_2(data: Dictionary) -> Dictionary:
	data["coin"] = 0
	var boat := new_boat()
	boat["next_day"] = int(data.get("day", 1)) + 1
	data["boat"] = boat
	data["museums"] = {}
	return data
