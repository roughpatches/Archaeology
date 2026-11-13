extends RefCounted
## Builds one expedition floor as branching tunnels, the same way for the same seed.
##
## A floor runs left to right through LAYERS layers of chambers. Layer 0 is the landing (the
## rope up). Each later layer has chambers in some of SLOTS rows. Tunnels join each chamber to
## one or more chambers in the next layer, so the player keeps choosing which way to go on.
## Every tunnel ends in a drop (a LEDGE tile) into the next chamber: once you step off it there
## is no climbing back, so each fork is a commitment. Every chamber in the last layer has the
## way down. Each chamber holds one kind of thing (KINDS), and each tunnel mouth shows a hint
## of what is beyond it that is right HINT_ACCURACY of the time.

enum Tile { WALL, FLOOR, PILLAR, LEDGE, RUBBLE, WATER }

const SeededRng := preload("res://core/seeded_rng.gd")

const LAYERS := 5
const SLOTS := 3
const CHAMBER := Vector2i(13, 9)
## Distance from one layer's chambers to the next, and from one slot's to the next.
const LAYER_STEP := 21
const SLOT_STEP := 13
const SIZE := Vector2i(
	1 + (LAYERS - 1) * LAYER_STEP + CHAMBER.x + 1, 1 + (SLOTS - 1) * SLOT_STEP + CHAMBER.y + 1
)
## Column (relative to the chamber's left edge) where a tunnel to another row turns.
const TURN_X := CHAMBER.x + 4

const KINDS: Array[String] = ["dig", "crystal", "creature", "spring", "empty"]
## The first expedition is an ancient jungle tomb (D33). Hints and names are placeholders (D10).
const HINTS := {
	"dig": "carved stonework",
	"crystal": "a glint",
	"creature": "scratching",
	"spring": "trickling water",
	"empty": "still air",
}
const HINT_ACCURACY := 0.65
const CHAMBER_NAMES: Array[String] = [
	"an antechamber",
	"a root-choked hall",
	"a burial gallery",
	"a fallen shrine",
	"a painted crypt",
	"a vine-hung vault",
]
## Chance a chamber (not the landing) has a stream running through it, top to bottom.
const STREAM_CHANCE := 0.4
## In the Rains (D36) the tomb is wetter.
const RAINS_STREAM_CHANCE := 0.7
## At night more of the tomb's creatures are about (D36).
const NIGHT_CREATURE_WEIGHT := 10
## Chance a middle chamber has a natural way out (a shaft to the surface, D38), and that the
## tunnel leading to it carries a warm draft you can notice.
const SHAFT_CHANCE := 0.2
const DRAFT_CHANCE := 0.75
const NO_SHAFT := Vector2i(-1, -1)
## Columns (from the chamber's left edge) a stream may run down.
const STREAM_MIN_X := 2
const STREAM_MAX_X := CHAMBER.x - 3
## Chance of each extra forward tunnel beyond the ones every chamber needs.
const EXTRA_TUNNEL_CHANCE := 0.6

## Slots that layers 1 .. LAYERS-2 may use (always two or more chambers), and the last layer.
const MIDDLE_SLOTS := [[0, 1], [1, 2], [0, 2], [0, 1, 2], [0, 1, 2]]
const LAST_SLOTS := [[1], [0, 2], [0, 1, 2]]


## Returns {
##   size: Vector2i, tiles: PackedByteArray (Tile values, row-major),
##   chambers: Array of {layer, slot, rect: Rect2i, centre: Vector2i, kind: String,
##     name: String, stream_x: int (tile column of its stream, or -1),
##     shaft: Vector2i (a natural way out, or NO_SHAFT)},
##   tunnels: Array of {from, to (chamber indices), path: Array[Vector2i] (mouth first, ledge
##     last), mouth: Vector2i, ledge: Vector2i, hint: String (a KINDS value),
##     draft: bool (a shaft lies beyond, and you can feel it)},
##   entry: Vector2i (the landing, chamber 0's centre), exits: Array[Vector2i] (way down),
## }.
## conditions: {night: bool, rains: bool} from the island's time and season, and
## optionally hint_accuracy (the display shelf, D45).
static func generate(seed_value: int, depth: int = 1, conditions: Dictionary = {}) -> Dictionary:
	var night := bool(conditions.get("night", false))
	var hint_accuracy := float(conditions.get("hint_accuracy", HINT_ACCURACY))
	var stream_chance := RAINS_STREAM_CHANCE if conditions.get("rains", false) else STREAM_CHANCE
	var rng := SeededRng.new(seed_value)
	var tiles := PackedByteArray()
	tiles.resize(SIZE.x * SIZE.y)
	tiles.fill(Tile.WALL)

	var chambers: Array[Dictionary] = []
	var by_layer: Array = []
	for layer in LAYERS:
		var slots: Array = [1]
		if layer == LAYERS - 1:
			slots = rng.pick(LAST_SLOTS)
		elif layer > 0:
			slots = rng.pick(MIDDLE_SLOTS)
		var ids: Array[int] = []
		for slot: int in slots:
			ids.append(chambers.size())
			var chamber := _make_chamber(tiles, rng, layer, slot, stream_chance)
			chamber["kind"] = KINDS[rng.weighted_index(kind_weights(depth, night))]
			chamber["shaft"] = NO_SHAFT
			if layer > 0 and layer < LAYERS - 1 and rng.chance(SHAFT_CHANCE):
				chamber["shaft"] = (chamber["rect"] as Rect2i).position + Vector2i(1, 1)
			chambers.append(chamber)
		by_layer.append(ids)
	chambers[0]["kind"] = "empty"
	_ensure_a_dig(chambers, rng)

	var tunnels: Array[Dictionary] = []
	for layer in LAYERS - 1:
		for link: Array in _links(rng, chambers, by_layer[layer], by_layer[layer + 1], layer == 0):
			var tunnel := _carve_tunnel(tiles, chambers[link[0]], chambers[link[1]])
			tunnel["from"] = link[0]
			tunnel["to"] = link[1]
			var kind: String = chambers[link[1]]["kind"]
			if not rng.chance(hint_accuracy):
				# A wrong hint is still something this floor could hold.
				var weights := kind_weights(depth, night)
				var others := KINDS.filter(
					func(k: String) -> bool: return k != kind and weights[KINDS.find(k)] > 0
				)
				kind = rng.pick(others)
			tunnel["hint"] = kind
			var shaft: Vector2i = chambers[link[1]]["shaft"]
			tunnel["draft"] = shaft != NO_SHAFT and rng.chance(DRAFT_CHANCE)
			tunnels.append(tunnel)

	var exits: Array[Vector2i] = []
	for i: int in by_layer[LAYERS - 1]:
		exits.append(chambers[i]["centre"])
	return {
		"size": SIZE,
		"tiles": tiles,
		"chambers": chambers,
		"tunnels": tunnels,
		"entry": chambers[0]["centre"],
		"exits": exits,
	}


static func tile_at(floor_data: Dictionary, p: Vector2i) -> int:
	if p.x < 0 or p.y < 0 or p.x >= SIZE.x or p.y >= SIZE.y:
		return Tile.WALL
	var tiles: PackedByteArray = floor_data["tiles"]
	return tiles[_index(p)]


## Ground you can stand on (floor, shallow water, or the lip of a drop).
static func walkable(floor_data: Dictionary, p: Vector2i) -> bool:
	var t := tile_at(floor_data, p)
	return t == Tile.FLOOR or t == Tile.LEDGE or t == Tile.WATER


## Tiles light passes over: anything you could walk on.
static func open(t: int) -> bool:
	return t == Tile.FLOOR or t == Tile.LEDGE or t == Tile.WATER


## Whether the player may step from `from` in direction `dir`. Drops only go forward: you can
## never step onto a ledge from the chamber below it.
static func can_step(floor_data: Dictionary, from: Vector2i, dir: Vector2i) -> bool:
	var to := from + dir
	if not walkable(floor_data, to):
		return false
	return not (tile_at(floor_data, to) == Tile.LEDGE and dir == Vector2i.LEFT)


## Index of the chamber containing p, or -1 (in a tunnel or rock).
static func chamber_at(floor_data: Dictionary, p: Vector2i) -> int:
	var chambers: Array = floor_data["chambers"]
	for i in chambers.size():
		if (chambers[i]["rect"] as Rect2i).has_point(p):
			return i
	return -1


## Index of the tunnel whose path contains p, or -1.
static func tunnel_at(floor_data: Dictionary, p: Vector2i) -> int:
	var tunnels: Array = floor_data["tunnels"]
	for i in tunnels.size():
		if (tunnels[i]["path"] as Array).has(p):
			return i
	return -1


## Steps between two tiles walking round walls, or -1 if there is no way (ignores drops).
static func distance(floor_data: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var dist := bfs(floor_data["tiles"], from)
	return dist.get(to, -1)


## Breadth-first distances from a tile over plain floor. Ledges are left out, so creatures
## never cross a drop.
static func bfs(tiles: PackedByteArray, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := p + d
			if n.x < 0 or n.y < 0 or n.x >= SIZE.x or n.y >= SIZE.y:
				continue
			if dist.has(n) or tiles[_index(n)] != Tile.FLOOR:
				continue
			dist[n] = dist[p] + 1
			queue.append(n)
	return dist


## Tiles the player can reach from `from`, following the one-way drops.
static func reachable(floor_data: Dictionary, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := p + d
			if not seen.has(n) and can_step(floor_data, p, d):
				seen[n] = true
				queue.append(n)
	return seen


static func _index(p: Vector2i) -> int:
	return p.y * SIZE.x + p.x


static func _origin(layer: int, slot: int) -> Vector2i:
	return Vector2i(1 + layer * LAYER_STEP, 1 + slot * SLOT_STEP)


## Carves a chamber: open floor with a few pillars on rows 2 and 6. Rows 0, 4 and 8 stay
## open from side to side, because tunnels leave and arrive on them. Some chambers have a
## stream running down one column; it is shallow, so the player can wade it, but creatures won't.
static func _make_chamber(
	tiles: PackedByteArray, rng: SeededRng, layer: int, slot: int, stream_chance: float
) -> Dictionary:
	var origin := _origin(layer, slot)
	for y in CHAMBER.y:
		for x in CHAMBER.x:
			tiles[_index(origin + Vector2i(x, y))] = Tile.FLOOR
	for y: int in [2, 6]:
		for x: int in [3, 6, 9]:
			if rng.chance(0.3):
				tiles[_index(origin + Vector2i(x, y))] = Tile.PILLAR
	var stream_x := -1
	if layer > 0 and rng.chance(stream_chance):
		stream_x = origin.x + rng.range_int(STREAM_MIN_X, STREAM_MAX_X)
		for y in CHAMBER.y:
			tiles[_index(Vector2i(stream_x, origin.y + y))] = Tile.WATER
	return {
		"name": CHAMBER_NAMES[rng.range_int(0, CHAMBER_NAMES.size() - 1)],
		"stream_x": stream_x,
		"layer": layer,
		"slot": slot,
		"rect": Rect2i(origin, CHAMBER),
		"centre": origin + CHAMBER / 2,
	}


## How likely each of KINDS is at a depth. No creatures on floor 1 by day.
static func kind_weights(depth: int, night: bool = false) -> Array:
	var creature := 0 if depth <= 1 else 8 + 6 * (depth - 2)
	if night:
		creature += NIGHT_CREATURE_WEIGHT
	return [35, 25, creature, 12, 15]


static func _ensure_a_dig(chambers: Array[Dictionary], rng: SeededRng) -> void:
	for c in chambers:
		if c["kind"] == "dig":
			return
	chambers[rng.range_int(1, chambers.size() - 1)]["kind"] = "dig"


## Chooses which chambers of one layer lead to which of the next. Tunnels only go to the same
## row or a neighbouring one, never cross, every chamber gets at least one way out and one way
## in, and the landing (`fork`) gets two ways out where it can.
static func _links(rng: SeededRng, chambers: Array, here: Array, ahead: Array, fork: bool) -> Array:
	var candidates: Array = []
	for a: int in here:
		for b: int in ahead:
			if absi(chambers[a]["slot"] - chambers[b]["slot"]) <= 1:
				candidates.append([a, b])
	candidates = rng.shuffled(candidates)
	var chosen: Array = []
	for a: int in here:
		_add_first(chambers, chosen, candidates.filter(func(l: Array) -> bool: return l[0] == a))
	for b: int in ahead:
		if not chosen.any(func(l: Array) -> bool: return l[1] == b):
			_add_first(
				chambers, chosen, candidates.filter(func(l: Array) -> bool: return l[1] == b)
			)
	for link: Array in candidates:
		if chosen.has(link):
			continue
		var outs := chosen.filter(func(l: Array) -> bool: return l[0] == link[0]).size()
		if (fork and outs < 2) or rng.chance(EXTRA_TUNNEL_CHANCE):
			_add_first(chambers, chosen, [link])
	return chosen


## Adds the first link in `options` that is new and crosses nothing already chosen.
static func _add_first(chambers: Array, chosen: Array, options: Array) -> void:
	for link: Array in options:
		if chosen.has(link):
			return
		var crosses := chosen.any(
			func(l: Array) -> bool:
				return (
					chambers[l[0]]["slot"] == chambers[link[1]]["slot"]
					and chambers[l[1]]["slot"] == chambers[link[0]]["slot"]
					and l[0] != link[0]
				)
		)
		if not crosses:
			chosen.append(link)
			return


## Carves the tunnel from chamber a to chamber b in the next layer. Same row: straight along
## the middle row. Next row down (up): leaves along a's bottom (top) row, turns at TURN_X and
## arrives on b's top (bottom) row. The last tile is the ledge.
static func _carve_tunnel(tiles: PackedByteArray, a: Dictionary, b: Dictionary) -> Dictionary:
	var a_rect: Rect2i = a["rect"]
	var b_rect: Rect2i = b["rect"]
	var dy := signi(b["slot"] - a["slot"])
	var half := CHAMBER.y / 2
	var leave_y: int = a["centre"].y + dy * half
	var arrive_y: int = b["centre"].y - dy * half
	var start_x := a_rect.end.x
	var turn_x := a_rect.position.x + TURN_X
	var ledge_x := b_rect.position.x - 1
	var path: Array[Vector2i] = []
	if dy == 0:
		for x in range(start_x, ledge_x + 1):
			path.append(Vector2i(x, leave_y))
	else:
		for x in range(start_x, turn_x + 1):
			path.append(Vector2i(x, leave_y))
		var y := leave_y + dy
		while y != arrive_y + dy:
			path.append(Vector2i(turn_x, y))
			y += dy
		for x in range(turn_x + 1, ledge_x + 1):
			path.append(Vector2i(x, arrive_y))
	for p in path:
		tiles[_index(p)] = Tile.FLOOR
	var ledge: Vector2i = path[path.size() - 1]
	tiles[_index(ledge)] = Tile.LEDGE
	return {"path": path, "mouth": path[0], "ledge": ledge}
