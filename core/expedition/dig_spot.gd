extends RefCounted
## A dig spot found during an expedition: a small trench with one buried find.
##
## Ported from the Phaser gray-box dig (docs/phaser-prototype/FEEL_DIG.md) and scaled down so
## a find takes minutes, not days: 6 x 5 tiles, 1 to 3 layers, one find of 2 to 4 tiles.
## Pure rules: the scene draws `tiles` and calls use()/lift().

const SeededRng := preload("res://core/seeded_rng.gd")

const COLS := 6
const ROWS := 5
const MIN_DEPTH := 1
const MAX_DEPTH := 3
const COST := {"pick": 3, "trowel": 1, "brush": 2, "probe": 1}
const LIFT_COST := 2
const STAIN_CHANCE := 0.75
const FALSE_STAIN_CHANCE := 0.1
const TOOLS: Array[String] = ["pick", "trowel", "brush", "probe"]

## Each tile: {depth, start_depth, find (bool), chipped, stain, probed}
var tiles: Array[Dictionary] = []
var find_tiles: Array[int] = []
var find_id: String
var rarity: String
## A surveyed spot comes with an exact map of the find; its context is documented.
var surveyed := false
var lifted := false
var lift_damage_taken := 0


func _init(p_seed: int = 0, p_find_id: String = "", p_rarity: String = "common") -> void:
	find_id = p_find_id
	rarity = p_rarity
	var rng := SeededRng.new(p_seed)
	var size := rng.range_int(2, 4)
	var start := rng.range_int(1, COLS - 2) + rng.range_int(1, ROWS - 2) * COLS
	find_tiles = _grow(rng, start, size)
	for i in COLS * ROWS:
		var is_find := find_tiles.has(i)
		var depth := rng.range_int(MIN_DEPTH, MAX_DEPTH)
		(
			tiles
			. append(
				{
					"depth": depth,
					"start_depth": depth,
					"find": is_find,
					"chipped": false,
					"stain": rng.chance(STAIN_CHANCE if is_find else FALSE_STAIN_CHANCE),
					"probed": false,
				}
			)
		)


static func neighbours(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % COLS
	var y := i / COLS
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if nx >= 0 and nx < COLS and ny >= 0 and ny < ROWS:
			out.append(ny * COLS + nx)
	return out


## Tiles a tool works on at i: the pick takes a 3 x 3 patch, the rest one tile.
static func area(i: int, tool: String) -> Array[int]:
	if tool != "pick":
		return [i]
	var out: Array[int] = []
	var x := i % COLS
	var y := i / COLS
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and nx < COLS and ny >= 0 and ny < ROWS:
				out.append(ny * COLS + nx)
	return out


func shows_stain(i: int) -> bool:
	return tiles[i]["depth"] == 1 and tiles[i]["stain"]


func can_use(i: int, tool: String, stamina: int) -> bool:
	return why_not(i, tool, stamina) == ""


## Why a tool can't be used at tile i, in words for the player, or "" if it can.
func why_not(i: int, tool: String, stamina: int) -> String:
	if lifted or i < 0 or i >= tiles.size():
		return "The find is already lifted" if lifted else "Off the dig"
	if stamina < COST[tool]:
		return "Too tired: %s needs %d stamina, you have %d" % [tool, COST[tool], stamina]
	if tool == "probe":
		return _why_not_probe(i)
	for j in area(i, tool):
		if tiles[j]["depth"] > 0:
			return ""
	if tiles[i]["find"]:
		return "That's the find: dig around it, or press L to lift"
	return "Nothing left to dig there"


func _why_not_probe(i: int) -> String:
	if tiles[i]["probed"]:
		return "Already probed there"
	if tiles[i]["depth"] == 0:
		return "Nothing left to probe there"
	return ""


## Uses a tool at tile i. Returns events [{i, kind}] where kind is removed, floor (dug to the
## find level on empty ground), exposed (cleanly), chipped (a pick or trowel hit the find) or
## probed. The caller pays COST[tool] in stamina.
func use(i: int, tool: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if tool == "probe":
		tiles[i]["probed"] = true
		events.append({"i": i, "kind": "probed"})
		return events
	for j in area(i, tool):
		var t: Dictionary = tiles[j]
		if t["depth"] == 0:
			continue
		t["depth"] -= 1
		var kind := "removed"
		if t["depth"] == 0:
			if not t["find"]:
				kind = "floor"
			elif tool == "brush":
				kind = "exposed"
			else:
				t["chipped"] = true
				kind = "chipped"
		events.append({"i": j, "kind": kind})
	return events


func is_exposed() -> bool:
	for i in find_tiles:
		if tiles[i]["depth"] > 0:
			return false
	return true


## Soil still packed against the find. Lifting it now damages it.
func locked_sides() -> Array[int]:
	var locked: Array[int] = []
	for i in find_tiles:
		for n in neighbours(i):
			if not find_tiles.has(n) and tiles[n]["depth"] > 0 and not locked.has(n):
				locked.append(n)
	return locked


## Damage a lift would do now: a point for every three tiles of soil still against it.
func lift_damage() -> int:
	return ceili(locked_sides().size() / 3.0)


func can_lift(stamina: int) -> bool:
	return not lifted and is_exposed() and stamina >= LIFT_COST


## Lifts the find. The caller pays LIFT_COST. Returns the damage the lift did.
func lift() -> int:
	lift_damage_taken = lift_damage()
	lifted = true
	return lift_damage_taken


func damage() -> int:
	var chips := 0
	for i in find_tiles:
		if tiles[i]["chipped"]:
			chips += 1
	return chips + lift_damage_taken


## pristine (no damage), intact (up to 15%, at least 1), worn (up to half), else fragment.
static func grade_condition(total: int, dmg: int) -> String:
	if dmg == 0:
		return "pristine"
	if dmg <= maxi(1, floori(total * 0.15)):
		return "intact"
	if dmg <= ceili(total * 0.5):
		return "worn"
	return "fragment"


## The find as it goes into the bag.
func result() -> Dictionary:
	return {
		"id": find_id,
		"rarity": rarity,
		"condition": grade_condition(find_tiles.size(), damage()),
		"context": "documented" if surveyed else "unrecorded",
	}


func _grow(rng: SeededRng, start: int, size: int) -> Array[int]:
	var shape: Array[int] = [start]
	while shape.size() < size:
		var frontier: Array[int] = []
		for i in shape:
			for n in neighbours(i):
				if not shape.has(n) and not frontier.has(n):
					frontier.append(n)
		if frontier.is_empty():
			break
		shape.append(rng.pick(frontier))
	return shape
