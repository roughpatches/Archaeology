extends RefCounted
## One expedition run: floors, stamina, the bag, dig spots and creatures. Pure rules.
##
## Turn-based (D29): every step or action is one tick, and creatures move on ticks. There is
## no clock (D26); stamina is the limit. See FEEL_EXPEDITION.md for the intent and numbers.

const FloorGen := preload("res://core/expedition/floor_gen.gd")
const DigSpot := preload("res://core/expedition/dig_spot.gd")
const SeededRng := preload("res://core/seeded_rng.gd")

const FLOORS := 5
const BAG_SLOTS := 8
const SIGHT := 4
const SURVEY_COST := 4
const SURVEY_RADIUS := 5
const DESCEND_COST := 3
const MINE_COST := 2
const FLARES := 2
const FLARE_RADIUS := 6
const FLEE_TICKS := 8
const CHASE_RANGE := 5
const BITE_COST := 10
const STUN_TICKS := 3
## Chance a dig spot shows surface signs. The rest only show up on a survey.
const SIGN_CHANCE := 0.6

## Placeholder finds by rarity. Names are placeholders (D10).
const FINDS := {
	"common": ["Potsherd", "Bone needle", "Tide bead"],
	"uncommon": ["Carved idol", "Bronze lamp"],
	"rare": ["Star-chart fragment", "Sunken crown piece"],
}
const RARITIES: Array[String] = ["common", "uncommon", "rare"]

var seed_value: int
var depth := 0
var stamina: int
var flares := FLARES
## Items carried: finds {kind: "find", id, rarity, condition, context} or {kind: "material", id}.
var bag: Array[Dictionary] = []
## "exploring", "climbed_out" or "collapsed".
var state := "exploring"
var ticks := 0
var log_lines: Array[String] = []

var floor_data: Dictionary
var player: Vector2i
## Tiles the player has seen on this floor (Vector2i -> true).
var seen := {}
## Dig spots: {pos, has_sign, noticed, dig (DigSpot)}.
var spots: Array[Dictionary] = []
## Material nodes (Vector2i). Bump one to mine it.
var nodes: Array[Vector2i] = []
## Creatures: {pos, flee, stun}.
var creatures: Array[Dictionary] = []

var _rng: SeededRng


func _init(p_seed: int = 0, p_stamina: int = 100) -> void:
	seed_value = p_seed
	stamina = p_stamina
	enter_floor(1)


func enter_floor(d: int) -> void:
	depth = d
	floor_data = FloorGen.generate(SeededRng.derive(seed_value, ["floor", d]))
	_rng = SeededRng.new(SeededRng.derive(seed_value, ["contents", d]))
	player = floor_data["entry"]
	seen = {}
	spots = []
	nodes = []
	creatures = []
	var entry: Vector2i = floor_data["entry"]
	var open: Array = floor_data["open"]
	var near_ok := func(p: Vector2i, min_d: int) -> bool: return _manhattan(p, entry) >= min_d
	var used := {}
	for p: Vector2i in open:
		if spots.size() >= 2 + d / 2:
			break
		if near_ok.call(p, 4) and not _near_used(used, p):
			var rarity := RARITIES[_rng.weighted_index(_rarity_weights(d))]
			var find_id: String = _rng.pick(FINDS[rarity])
			var dig := DigSpot.new(
				SeededRng.derive(seed_value, ["dig", d, spots.size()]), find_id, rarity
			)
			spots.append(
				{"pos": p, "has_sign": _rng.chance(SIGN_CHANCE), "noticed": false, "dig": dig}
			)
			used[p] = true
	for p: Vector2i in open:
		if nodes.size() >= 2:
			break
		if near_ok.call(p, 3) and not _near_used(used, p):
			nodes.append(p)
			used[p] = true
	for p: Vector2i in open:
		if creatures.size() >= d - 1:
			break
		if near_ok.call(p, 9) and not used.has(p):
			creatures.append({"pos": p, "flee": 0, "stun": 0})
			used[p] = true
	_reveal()
	_say("Floor %d." % d)


# ---- reading the state ------------------------------------------------------------------


func spot_at(p: Vector2i) -> int:
	for i in spots.size():
		if spots[i]["pos"] == p:
			return i
	return -1


func creature_at(p: Vector2i) -> int:
	for i in creatures.size():
		if creatures[i]["pos"] == p:
			return i
	return -1


func bag_full() -> bool:
	return bag.size() >= BAG_SLOTS


## A creature is closing in: near, not stunned and not fleeing.
func hunted() -> bool:
	for c in creatures:
		if c["flee"] == 0 and c["stun"] == 0 and _manhattan(c["pos"], player) <= CHASE_RANGE:
			return true
	return false


func on_exit() -> bool:
	return player == floor_data["exit"]


func on_entry() -> bool:
	return player == floor_data["entry"]


func is_over() -> bool:
	return state != "exploring"


# ---- acting -----------------------------------------------------------------------------


## Steps one tile. Walking into a material node mines it. Walking is free; mining costs.
func move(dir: Vector2i) -> bool:
	if is_over():
		return false
	var target := player + dir
	var node := nodes.find(target)
	if node >= 0:
		return _mine(node)
	if not FloorGen.walkable(floor_data, target) or creature_at(target) >= 0:
		return false
	player = target
	_reveal()
	_tick()
	return true


## A survey reading: reveals every dig spot within SURVEY_RADIUS and maps them, so their finds
## come out documented and their digs show the find's outline.
func survey() -> bool:
	if is_over() or stamina < SURVEY_COST:
		return false
	var found := 0
	for s in spots:
		if _manhattan(s["pos"], player) <= SURVEY_RADIUS and not s["dig"].lifted:
			s["noticed"] = true
			s["dig"].surveyed = true
			found += 1
	_say("Survey: %d dig spot%s mapped nearby." % [found, "" if found == 1 else "s"])
	_spend(SURVEY_COST)
	_tick()
	return true


## Lights a flare: creatures within FLARE_RADIUS flee for FLEE_TICKS.
func use_flare() -> bool:
	if is_over() or flares <= 0:
		return false
	flares -= 1
	for c in creatures:
		if _manhattan(c["pos"], player) <= FLARE_RADIUS:
			c["flee"] = FLEE_TICKS
			c["stun"] = 0
	_say("Flare! Creatures scatter.")
	_tick()
	return true


## Takes the way down, if standing on it.
func descend() -> bool:
	if is_over() or not on_exit() or depth >= FLOORS or stamina < DESCEND_COST:
		return false
	_spend(DESCEND_COST)
	if not is_over():
		enter_floor(depth + 1)
	return true


## Climbs the rope out, if standing on it. Ends the expedition with everything in the bag.
func climb_out() -> bool:
	if is_over() or not on_entry():
		return false
	state = "climbed_out"
	_say("You climb out with %d item%s." % [bag.size(), "" if bag.size() == 1 else "s"])
	return true


## Uses a dig tool on tile i of the dig spot the player stands on. Each use is a tick.
func dig_use(spot: int, i: int, tool: String) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if is_over() or spot < 0 or spots[spot]["pos"] != player:
		return none
	var dig: DigSpot = spots[spot]["dig"]
	if not dig.can_use(i, tool, stamina):
		return none
	var events := dig.use(i, tool)
	_spend(DigSpot.COST[tool])
	_tick()
	return events


func can_lift(spot: int) -> bool:
	if is_over() or spot < 0 or bag_full():
		return false
	return spots[spot]["dig"].can_lift(stamina)


## Lifts the find out of the dig spot into the bag. Returns the find, or {} if it can't.
func dig_lift(spot: int) -> Dictionary:
	if not can_lift(spot) or spots[spot]["pos"] != player:
		return {}
	var dig: DigSpot = spots[spot]["dig"]
	dig.lift()
	var item := dig.result()
	item["kind"] = "find"
	bag.append(item)
	_say("Lifted: %s (%s, %s)." % [item["id"], item["condition"], item["context"]])
	_spend(DigSpot.LIFT_COST)
	_tick()
	return item


# ---- internals --------------------------------------------------------------------------


func _mine(node: int) -> bool:
	if stamina < MINE_COST or bag_full():
		_say("Bag full." if bag_full() else "Too tired to mine.")
		return false
	nodes.remove_at(node)
	bag.append({"kind": "material", "id": "Crystal"})
	_say("Mined a crystal.")
	_spend(MINE_COST)
	_tick()
	return true


func _spend(amount: int) -> void:
	stamina = maxi(0, stamina - amount)
	if stamina == 0 and state == "exploring":
		_collapse()


## Out of stamina: Professor Philius drags you home. Half the bag (rounded up) is lost.
func _collapse() -> void:
	state = "collapsed"
	var lose := ceili(bag.size() / 2.0)
	var order := _rng.shuffled(range(bag.size()))
	var drop := order.slice(0, lose)
	drop.sort()
	drop.reverse()
	for i: int in drop:
		bag.remove_at(i)
	_say(
		(
			"You collapse. Professor Philius drags you home; %d item%s lost."
			% [lose, "" if lose == 1 else "s"]
		)
	)


func _tick() -> void:
	ticks += 1
	if is_over():
		return
	var dist := FloorGen.bfs(floor_data["tiles"], player)
	for c in creatures:
		if c["stun"] > 0:
			c["stun"] -= 1
			continue
		var pos: Vector2i = c["pos"]
		var options: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := pos + d
			if FloorGen.walkable(floor_data, n) and n != player and creature_at(n) < 0:
				options.append(n)
		if options.is_empty():
			continue
		var here: int = dist.get(pos, 999)
		if c["flee"] > 0:
			c["flee"] -= 1
			options.sort_custom(func(a, b): return dist.get(a, 999) > dist.get(b, 999))
			if dist.get(options[0], 999) >= here:
				c["pos"] = options[0]
		elif _manhattan(pos, player) <= CHASE_RANGE:
			options.sort_custom(func(a, b): return dist.get(a, 999) < dist.get(b, 999))
			if dist.get(options[0], 999) < here:
				c["pos"] = options[0]
		elif _rng.chance(0.5):
			c["pos"] = _rng.pick(options)
		if c["flee"] == 0 and _manhattan(c["pos"], player) == 1:
			c["stun"] = STUN_TICKS
			_say("Bitten! -%d stamina." % BITE_COST)
			_spend(BITE_COST)
			if is_over():
				return


func _reveal() -> void:
	for dy in range(-SIGHT, SIGHT + 1):
		for dx in range(-SIGHT, SIGHT + 1):
			if absi(dx) + absi(dy) <= SIGHT:
				seen[player + Vector2i(dx, dy)] = true
	for s in spots:
		if s["has_sign"] and _manhattan(s["pos"], player) <= SIGHT:
			s["noticed"] = true


func _say(line: String) -> void:
	log_lines.append(line)


func _near_used(used: Dictionary, p: Vector2i) -> bool:
	for q: Vector2i in used:
		if _manhattan(p, q) < 3:
			return true
	return false


static func _rarity_weights(d: int) -> Array:
	return [maxi(10, 75 - 12 * (d - 1)), 20 + 6 * (d - 1), 5 + 6 * (d - 1)]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
