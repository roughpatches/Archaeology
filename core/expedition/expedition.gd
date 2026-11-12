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
const SPRING_GAIN := 15
const MAX_STAMINA := 100

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
## Springs not yet drunk from (Vector2i). Step on one to get SPRING_GAIN stamina back.
var springs: Array[Vector2i] = []
## Tunnels whose hint a survey has checked (tunnel index -> true). Checked hints are always right.
var confirmed := {}

var _rng: SeededRng


func _init(p_seed: int = 0, p_stamina: int = 100) -> void:
	seed_value = p_seed
	stamina = p_stamina
	enter_floor(1)


func enter_floor(d: int) -> void:
	depth = d
	floor_data = FloorGen.generate(SeededRng.derive(seed_value, ["floor", d]), d)
	_rng = SeededRng.new(SeededRng.derive(seed_value, ["contents", d]))
	player = floor_data["entry"]
	seen = {}
	spots = []
	nodes = []
	creatures = []
	springs = []
	confirmed = {}
	for i in floor_data["chambers"].size():
		var chamber: Dictionary = floor_data["chambers"][i]
		var places: Array = _rng.shuffled(_places(chamber))
		match chamber["kind"]:
			"dig":
				var rarity := RARITIES[_rng.weighted_index(_rarity_weights(d))]
				var find_id: String = _rng.pick(FINDS[rarity])
				var dig := DigSpot.new(SeededRng.derive(seed_value, ["dig", d, i]), find_id, rarity)
				spots.append(
					{
						"pos": places[0],
						"has_sign": _rng.chance(SIGN_CHANCE),
						"noticed": false,
						"dig": dig
					}
				)
			"crystal":
				nodes.append(places[0])
				nodes.append(places[1])
			"creature":
				for k in 1 if d < 4 else 2:
					creatures.append({"pos": places[k], "flee": 0, "stun": 0})
			"spring":
				springs.append(places[0])
	_reveal()
	_say("Floor %d. Tunnels branch ahead; every drop is one way." % d)


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
	return (floor_data["exits"] as Array).has(player)


func on_entry() -> bool:
	return player == floor_data["entry"]


func is_over() -> bool:
	return state != "exploring"


## The chamber the player is in, or the one whose tunnel they are walking down.
func current_chamber() -> int:
	var c := FloorGen.chamber_at(floor_data, player)
	if c >= 0:
		return c
	var t := FloorGen.tunnel_at(floor_data, player)
	return floor_data["tunnels"][t]["from"] if t >= 0 else -1


## Standing on the lip of a drop.
func on_ledge() -> bool:
	return FloorGen.tile_at(floor_data, player) == FloorGen.Tile.LEDGE


## What each tunnel mouth seems to say: {pos, text, checked}. A checked hint is the truth.
func tunnel_hints() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tunnels: Array = floor_data["tunnels"]
	for i in tunnels.size():
		var t: Dictionary = tunnels[i]
		var checked := confirmed.has(i)
		var kind: String = floor_data["chambers"][t["to"]]["kind"] if checked else t["hint"]
		out.append({"pos": t["mouth"], "text": FloorGen.HINTS[kind], "checked": checked})
	return out


# ---- acting -----------------------------------------------------------------------------


## Steps one tile. Walking into a material node mines it. Walking is free; mining costs.
func move(dir: Vector2i) -> bool:
	if is_over():
		return false
	var target := player + dir
	var node := nodes.find(target)
	if node >= 0:
		return _mine(node)
	if not FloorGen.can_step(floor_data, player, dir) or creature_at(target) >= 0:
		return false
	var dropping := on_ledge() and dir == Vector2i.RIGHT
	player = target
	if dropping:
		_say("You slide down the drop. No way back up.")
	elif on_ledge():
		_say("A drop. Step forward and there's no climbing back.")
	var spring := springs.find(player)
	if spring >= 0:
		springs.remove_at(spring)
		var gain := mini(SPRING_GAIN, MAX_STAMINA - stamina)
		stamina += gain
		_say("Cold spring water. +%d stamina." % gain)
	_reveal()
	_tick()
	return true


## A survey reading: reveals every dig spot within SURVEY_RADIUS and maps them, so their finds
## come out documented and their digs show the find's outline. It also checks the hints of the
## tunnels leading on from this chamber.
func survey() -> bool:
	if is_over() or stamina < SURVEY_COST:
		return false
	var found := 0
	for s in spots:
		if _manhattan(s["pos"], player) <= SURVEY_RADIUS and not s["dig"].lifted:
			s["noticed"] = true
			s["dig"].surveyed = true
			found += 1
	var here := current_chamber()
	var tunnels: Array = floor_data["tunnels"]
	for i in tunnels.size():
		if tunnels[i]["from"] == here:
			confirmed[i] = true
	_say(
		(
			"Survey: %d dig spot%s mapped nearby; the ways ahead read true."
			% [found, "" if found == 1 else "s"]
		)
	)
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


func can_climb_out() -> bool:
	return on_entry() or (on_exit() and depth >= FLOORS)


## Takes the way down, if standing on it. The last floor has no way down.
func descend() -> bool:
	if is_over() or not on_exit() or depth >= FLOORS or stamina < DESCEND_COST:
		return false
	_spend(DESCEND_COST)
	if not is_over():
		enter_floor(depth + 1)
	return true


## Climbs out, from the rope at the landing or from the far end of the last floor. Ends the
## expedition with everything in the bag.
func climb_out() -> bool:
	if is_over() or not can_climb_out():
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
			var plain := FloorGen.tile_at(floor_data, n) == FloorGen.Tile.FLOOR
			if plain and n != player and creature_at(n) < 0:
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


## Lights tiles within SIGHT, except inside other chambers: you can't see past a drop, only
## guess from the hint at the tunnel mouth. Stepping into a chamber shows all of it.
func _reveal() -> void:
	var here := FloorGen.chamber_at(floor_data, player)
	for dy in range(-SIGHT, SIGHT + 1):
		for dx in range(-SIGHT, SIGHT + 1):
			var p := player + Vector2i(dx, dy)
			if absi(dx) + absi(dy) > SIGHT:
				continue
			var c := FloorGen.chamber_at(floor_data, p)
			if c < 0 or c == here:
				seen[p] = true
	if here >= 0:
		var rect: Rect2i = floor_data["chambers"][here]["rect"]
		for y in range(rect.position.y - 1, rect.end.y + 1):
			for x in range(rect.position.x - 1, rect.end.x + 1):
				seen[Vector2i(x, y)] = true
	for s in spots:
		if s["has_sign"] and seen.has(s["pos"]) and _manhattan(s["pos"], player) <= SIGHT:
			s["noticed"] = true


func _say(line: String) -> void:
	log_lines.append(line)


## Tiles in a chamber where things can go: its inner rows, never a pillar or the middle, so
## nothing blocks the rows that tunnels use.
func _places(chamber: Dictionary) -> Array:
	var out: Array = []
	var rect: Rect2i = chamber["rect"]
	for y: int in [rect.position.y + 1, rect.end.y - 2]:
		for x in range(rect.position.x + 1, rect.end.x - 1):
			var p := Vector2i(x, y)
			if FloorGen.tile_at(floor_data, p) == FloorGen.Tile.FLOOR:
				out.append(p)
	return out


static func _rarity_weights(d: int) -> Array:
	return [maxi(10, 75 - 12 * (d - 1)), 20 + 6 * (d - 1), 5 + 6 * (d - 1)]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
