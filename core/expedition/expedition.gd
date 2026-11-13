extends RefCounted
## One expedition run: floors, stamina, the bag, dig spots and creatures. Pure rules.
##
## Turn-based (D29): every step or action is one tick, and creatures move on ticks. There is
## no clock (D26); stamina is the limit. The tomb shifts as you go (D32): rockfalls, tunnel
## collapses and streams that move. See FEEL_EXPEDITION.md for the intent and numbers.

const FloorGen := preload("res://core/expedition/floor_gen.gd")
const DigSpot := preload("res://core/expedition/dig_spot.gd")
const SeededRng := preload("res://core/seeded_rng.gd")

const FLOORS := 5
const BAG_SLOTS := 8
const SIGHT := 5
const SURVEY_COST := 4
const SURVEY_RADIUS := 5
const DESCEND_COST := 3
const MINE_COST := 2
const FLARES := 2
## Getting out (D38): a rope anchor makes a way out where you stand in a chamber.
const ANCHOR_COST := 4
## A trail ration (D39) gives back stamina.
const RATION_GAIN := 20
const FLARE_RADIUS := 6
const FLEE_TICKS := 8
const CHASE_RANGE := 5
const BITE_COST := 10
const STUN_TICKS := 3
## Chance a dig spot shows surface signs. The rest only show up on a survey.
const SIGN_CHANCE := 0.6
const SPRING_GAIN := 15
const MAX_STAMINA := 100
## Wading a stream tile.
const WADE_COST := 1
## Walking into rubble clears one tile of it.
const CLEAR_COST := 3

## The shifting tomb (D32). Each tick with nothing already rumbling, one may start: chance
## QUAKE_CHANCE + QUAKE_PER_FLOOR * floor. It is announced, then lands WARN_TICKS ticks later.
const QUAKE_CHANCE := 0.04
const QUAKE_PER_FLOOR := 0.01
const WARN_TICKS := 2
## Stamina lost if a rockfall lands on you.
const ROCK_HIT := 8
## Tiles of a tunnel, from its mouth, that a collapse fills with rubble.
const COLLAPSE_LENGTH := 3
## Ticks between each step a stream takes sideways.
const STREAM_SHIFT := 6

## Placeholder finds by rarity. Names are placeholders (D10).
## The first expedition is a jungle tomb (D33).
const FINDS := {
	"common": ["Jade bead", "Clay effigy", "Bone flute"],
	"uncommon": ["Obsidian blade", "Serpent idol"],
	"rare": ["Gold-leaf mask piece", "Star-carved lintel stone"],
}
const RARITIES: Array[String] = ["common", "uncommon", "rare"]

var seed_value: int
var depth := 0
var stamina: int
var flares := FLARES
var anchors_left := 0
var rations := 0
## Night and the Rains change the tomb (D36): {night: bool, rains: bool}.
var conditions: Dictionary = {}
## Rope anchors placed on this floor: ways out.
var anchors: Array[Vector2i] = []
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
## Tiles lit right now (Vector2i -> true). Only these are shown: the tomb is dark behind you.
var lit := {}
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
## Tunnels a collapse has filled (tunnel index -> true).
var collapsed := {}
## Something about to come down: {kind: "rockfall" or "collapse", tiles: Array[Vector2i],
## tunnel: int (collapse only), ticks: int left}. Empty when all is quiet.
var rumble: Dictionary = {}
## Streams: {chamber, x, dir}. Each moves a column every STREAM_SHIFT ticks.
var streams: Array[Dictionary] = []
## Whether the tomb starts rumbles by itself. Tests turn it off to stage one with start_rumble.
var quakes := true

var _rng: SeededRng
var _quake_rng: SeededRng


## pack: gear brought in, {anchor, flare, ration}. Empty means the gray-box default (two
## flares, nothing else).
func _init(
	p_seed: int = 0, p_stamina: int = 100, pack: Dictionary = {}, p_conditions: Dictionary = {}
) -> void:
	seed_value = p_seed
	stamina = p_stamina
	conditions = p_conditions
	if not pack.is_empty():
		flares = int(pack.get("flare", 0))
		anchors_left = int(pack.get("anchor", 0))
		rations = int(pack.get("ration", 0))
	enter_floor(1)


func enter_floor(d: int) -> void:
	depth = d
	floor_data = FloorGen.generate(SeededRng.derive(seed_value, ["floor", d]), d, conditions)
	anchors = []
	_rng = SeededRng.new(SeededRng.derive(seed_value, ["contents", d]))
	_quake_rng = SeededRng.new(SeededRng.derive(seed_value, ["quakes", d]))
	collapsed = {}
	rumble = {}
	streams = []
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
		if chamber["stream_x"] >= 0:
			streams.append({"chamber": i, "x": chamber["stream_x"], "dir": _rng.pick([-1, 1])})
	_reveal()
	if d == 1:
		_say("Into the tomb. Tunnels branch ahead; every drop is one way.")
	else:
		_say("Floor %d. No rope down here: you'll need a way out." % d)


# ---- reading the state ------------------------------------------------------------------


func spot_at(p: Vector2i) -> int:
	for i in spots.size():
		if spots[i]["pos"] == p:
			return i
	return -1


func _creature_at(p: Vector2i) -> int:
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


func _on_entry() -> bool:
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
		var text: String = FloorGen.HINTS[kind]
		if collapsed.has(i):
			text = "caved in"
		elif t["draft"]:
			text += ", a warm draft"
		out.append({"pos": t["mouth"], "text": text, "checked": checked or collapsed.has(i)})
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
	if FloorGen.tile_at(floor_data, target) == FloorGen.Tile.RUBBLE:
		return _clear(target)
	if not FloorGen.can_step(floor_data, player, dir) or _creature_at(target) >= 0:
		return false
	var dropping := on_ledge() and dir == Vector2i.RIGHT
	player = target
	if dropping:
		var room: String = floor_data["chambers"][current_chamber()]["name"]
		_say("You slide down into %s. No way back up." % room)
	elif on_ledge():
		_say("A drop. Step forward and there's no climbing back.")
	var spring := springs.find(player)
	if spring >= 0:
		springs.remove_at(spring)
		var gain := mini(SPRING_GAIN, MAX_STAMINA - stamina)
		stamina += gain
		_say("Cold spring water. +%d stamina." % gain)
	_reveal()
	if FloorGen.tile_at(floor_data, player) == FloorGen.Tile.WATER:
		_spend(WADE_COST)
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


## A way out under your feet (D38): the rope you came in by (floor 1 only), an anchor you
## placed, a natural shaft, or the far end of the last floor.
func can_climb_out() -> bool:
	if (depth == 1 and _on_entry()) or anchors.has(player) or on_shaft():
		return true
	return on_exit() and depth >= FLOORS


func on_shaft() -> bool:
	return _is_shaft(player)


func _is_shaft(p: Vector2i) -> bool:
	var c := FloorGen.chamber_at(floor_data, p)
	return c >= 0 and floor_data["chambers"][c]["shaft"] == p


## Gear not used, to go back to camp.
func pack_left() -> Dictionary:
	return {"anchor": anchors_left, "flare": flares, "ration": rations}


## Drives a rope anchor in here: from now on you can climb out from this tile.
func place_anchor() -> String:
	if is_over():
		return "The expedition is over."
	if anchors_left <= 0:
		return "No rope anchors left."
	if FloorGen.chamber_at(floor_data, player) < 0:
		return "The tunnel is too tight to rig a rope. Try a chamber."
	if can_climb_out():
		return "There's already a way out here."
	if stamina < ANCHOR_COST:
		return "Too tired to rig a rope."
	anchors_left -= 1
	anchors.append(player)
	_say("You drive in a rope anchor. A way out, right here.")
	_spend(ANCHOR_COST)
	_tick()
	return ""


func eat_ration() -> String:
	if is_over():
		return "The expedition is over."
	if rations <= 0:
		return "No rations left."
	rations -= 1
	var gain := mini(RATION_GAIN, MAX_STAMINA - stamina)
	stamina += gain
	_say("You eat a trail ration. +%d stamina." % gain)
	_tick()
	return ""


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


func _clear(p: Vector2i) -> bool:
	if stamina < CLEAR_COST:
		_say("Too tired to shift the rubble.")
		return false
	_set_tile(p, FloorGen.Tile.FLOOR)
	_say("You heave the rubble aside.")
	_spend(CLEAR_COST)
	_reveal()
	_tick()
	return true


func _set_tile(p: Vector2i, t: int) -> void:
	var tiles: PackedByteArray = floor_data["tiles"]
	tiles[p.y * FloorGen.SIZE.x + p.x] = t
	floor_data["tiles"] = tiles


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
			if plain and n != player and _creature_at(n) < 0:
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
	_shift_streams()
	_shift_tomb()
	_reveal()


# ---- the shifting tomb (D32) --------------------------------------------------------------


func _shift_streams() -> void:
	if ticks % STREAM_SHIFT != 0:
		return
	for st in streams:
		var rect: Rect2i = floor_data["chambers"][st["chamber"]]["rect"]
		var lo := rect.position.x + FloorGen.STREAM_MIN_X
		var hi := rect.position.x + FloorGen.STREAM_MAX_X
		if st["x"] + st["dir"] < lo or st["x"] + st["dir"] > hi:
			st["dir"] = -st["dir"]
		var old_x: int = st["x"]
		st["x"] = old_x + st["dir"]
		for y in range(rect.position.y, rect.end.y):
			if FloorGen.tile_at(floor_data, Vector2i(old_x, y)) == FloorGen.Tile.WATER:
				_set_tile(Vector2i(old_x, y), FloorGen.Tile.FLOOR)
			if FloorGen.tile_at(floor_data, Vector2i(st["x"], y)) == FloorGen.Tile.FLOOR:
				_set_tile(Vector2i(st["x"], y), FloorGen.Tile.WATER)
		if st["chamber"] == FloorGen.chamber_at(floor_data, player):
			_say("The stream shifts its course.")


## Lands a rumble whose warning has run out, or maybe starts a new one.
func _shift_tomb() -> void:
	if not rumble.is_empty():
		rumble["ticks"] -= 1
		if rumble["ticks"] <= 0:
			_land(rumble)
			rumble = {}
		return
	if quakes and _quake_rng.chance(QUAKE_CHANCE + QUAKE_PER_FLOOR * depth):
		start_rumble("collapse" if _quake_rng.chance(0.4) else "rockfall")


## Announces a rockfall near the player or a collapse in a tunnel ahead. Returns whether one
## started (there may be nowhere for it to happen).
func start_rumble(kind: String) -> bool:
	if kind == "collapse":
		var t := _collapsible_tunnel()
		if t >= 0:
			var path: Array = floor_data["tunnels"][t]["path"]
			rumble = {
				"kind": "collapse",
				"tunnel": t,
				"tiles": path.slice(0, COLLAPSE_LENGTH),
				"ticks": WARN_TICKS + 1,
			}
			_say("A deep groan from one of the tunnels ahead...")
			return true
	var tiles := _rockfall_tiles()
	if tiles.is_empty():
		return false
	rumble = {"kind": "rockfall", "tiles": tiles, "ticks": WARN_TICKS}
	_say("Dust trickles from the ceiling. Something's coming down!")
	return true


func _land(r: Dictionary) -> void:
	var hit := false
	for p: Vector2i in r["tiles"]:
		if p == player:
			hit = true
			continue
		if _creature_at(p) >= 0 or nodes.has(p) or spot_at(p) >= 0:
			continue
		_set_tile(p, FloorGen.Tile.RUBBLE)
	if r["kind"] == "collapse":
		collapsed[r["tunnel"]] = true
		_say("A tunnel ahead caves in with a roar.")
	else:
		_say("Rocks crash down!")
	if hit:
		_say("Struck by falling rock! -%d stamina." % ROCK_HIT)
		_spend(ROCK_HIT)


## A tunnel leading on from here that may cave in: not one you're in, not already caved in,
## and never the last open way on.
func _collapsible_tunnel() -> int:
	var here := current_chamber()
	var open_ways: Array[int] = []
	var tunnels: Array = floor_data["tunnels"]
	for i in tunnels.size():
		if tunnels[i]["from"] == here and not collapsed.has(i):
			open_ways.append(i)
	if open_ways.size() < 2:
		return -1
	var choices := open_ways.filter(
		func(i: int) -> bool: return not (tunnels[i]["path"] as Array).has(player)
	)
	return _quake_rng.pick(choices) if not choices.is_empty() else -1


## A cross of tiles near the player, in the open, never on the rope or the way down.
func _rockfall_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for p: Vector2i in lit:
		var d := _manhattan(p, player)
		if d >= 1 and d <= 3 and FloorGen.tile_at(floor_data, p) == FloorGen.Tile.FLOOR:
			near.append(p)
	if near.is_empty():
		return out
	var centre: Vector2i = _quake_rng.pick(near)
	for d: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var p := centre + d
		if FloorGen.tile_at(floor_data, p) != FloorGen.Tile.FLOOR:
			continue
		if p == floor_data["entry"] or (floor_data["exits"] as Array).has(p):
			continue
		if anchors.has(p) or _is_shaft(p):
			continue
		out.append(p)
	return out


## Lights what the player's lamp reaches: tiles within SIGHT steps of open ground, and the walls
## around them. Light doesn't pass into other chambers: you can't see past a drop, only guess
## from the hint at the tunnel mouth. Nothing stays lit behind you.
func _reveal() -> void:
	var here := FloorGen.chamber_at(floor_data, player)
	lit = {player: true}
	var dist := {player: 0}
	var queue: Array[Vector2i] = [player]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := p + d
			if dist.has(n):
				continue
			var c := FloorGen.chamber_at(floor_data, n)
			if c >= 0 and c != here:
				continue
			if dist[p] + 1 > SIGHT:
				continue
			lit[n] = true
			if FloorGen.open(FloorGen.tile_at(floor_data, n)):
				dist[n] = dist[p] + 1
				queue.append(n)
	for p: Vector2i in lit:
		seen[p] = true
	for s in spots:
		if s["has_sign"] and lit.has(s["pos"]):
			s["noticed"] = true


func _say(line: String) -> void:
	log_lines.append(line)


## Tiles in a chamber where things can go: rows 2 and 6, never a pillar or water, so nothing
## blocks the rows that tunnels use.
func _places(chamber: Dictionary) -> Array:
	var out: Array = []
	var rect: Rect2i = chamber["rect"]
	for y: int in [rect.position.y + 2, rect.position.y + 6]:
		for x in range(rect.position.x + 2, rect.end.x - 2):
			var p := Vector2i(x, y)
			if FloorGen.tile_at(floor_data, p) == FloorGen.Tile.FLOOR:
				out.append(p)
	return out


static func _rarity_weights(d: int) -> Array:
	return [maxi(10, 75 - 12 * (d - 1)), 20 + 6 * (d - 1), 5 + 6 * (d - 1)]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
