extends RefCounted
## Builds one expedition floor from hand-made room pieces, the same way for the same seed.
##
## The floor is a 3 x 3 grid of cells. Each cell holds one room piece (ROOM_PIECES, 9 x 7).
## Rooms are joined along a random spanning tree plus one extra link, so every room can be
## reached and there is usually more than one way round. The rope up is in a random room;
## the way down is in the room farthest from it.

enum Tile { WALL, FLOOR, PILLAR }

const SeededRng := preload("res://core/seeded_rng.gd")

const GRID := Vector2i(3, 3)
const ROOM := Vector2i(9, 7)
## A cell is a room plus a one-tile wall on its right and bottom.
const CELL := Vector2i(ROOM.x + 1, ROOM.y + 1)
const SIZE := Vector2i(GRID.x * CELL.x + 1, GRID.y * CELL.y + 1)

## Hand-made room pieces. "." floor, "#" pillar (blocks walking). Keep the middle tile
## and the middle of each edge open: rope, stairs and doors go there.
const ROOM_PIECES: Array[String] = [
	".........\n.........\n.........\n.........\n.........\n.........\n.........",
	".........\n.#.....#.\n.........\n.........\n.........\n.#.....#.\n.........",
	".........\n.........\n..##.##..\n.........\n..##.##..\n.........\n.........",
	"..#...#..\n..#...#..\n.........\n.........\n.........\n..#...#..\n..#...#..",
	".........\n.##...##.\n.#.....#.\n.........\n.#.....#.\n.##...##.\n.........",
]


## Returns {size: Vector2i, tiles: PackedByteArray (Tile values, row-major), entry: Vector2i,
## exit: Vector2i, rooms: Array[Vector2i] (top-left floor tile of each cell's room),
## open: Array[Vector2i] (floor tiles with nothing special on them, for placing things)}.
static func generate(seed_value: int) -> Dictionary:
	var rng := SeededRng.new(seed_value)
	var tiles := PackedByteArray()
	tiles.resize(SIZE.x * SIZE.y)
	tiles.fill(Tile.WALL)

	var rooms: Array[Vector2i] = []
	for cy in GRID.y:
		for cx in GRID.x:
			var origin := Vector2i(cx * CELL.x + 1, cy * CELL.y + 1)
			rooms.append(origin)
			var rows: PackedStringArray = (rng.pick(ROOM_PIECES) as String).split("\n")
			for y in ROOM.y:
				for x in ROOM.x:
					var t := Tile.PILLAR if rows[y][x] == "#" else Tile.FLOOR
					tiles[_index(origin + Vector2i(x, y))] = t

	for link in _links(rng):
		_carve_door(tiles, link[0], link[1])

	var entry_cell := rng.range_int(0, rooms.size() - 1)
	var exit_cell := _farthest_cell(tiles, rooms, entry_cell)
	var entry := rooms[entry_cell] + Vector2i(ROOM.x / 2, ROOM.y / 2)
	var exit := rooms[exit_cell] + Vector2i(ROOM.x / 2, ROOM.y / 2)

	var open: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var p := Vector2i(x, y)
			if tiles[_index(p)] == Tile.FLOOR and p != entry and p != exit:
				open.append(p)
	return {
		"size": SIZE,
		"tiles": tiles,
		"entry": entry,
		"exit": exit,
		"rooms": rooms,
		"open": rng.shuffled(open),
	}


static func walkable(floor_data: Dictionary, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= SIZE.x or p.y >= SIZE.y:
		return false
	var tiles: PackedByteArray = floor_data["tiles"]
	return tiles[_index(p)] == Tile.FLOOR


## Steps between two tiles walking round walls, or -1 if there is no way.
static func distance(floor_data: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var dist := bfs(floor_data["tiles"], from)
	return dist.get(to, -1)


## Breadth-first distances from a tile over walkable ground.
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


static func _index(p: Vector2i) -> int:
	return p.y * SIZE.x + p.x


## Pairs of neighbouring cells to join: a random spanning tree plus one extra link.
static func _links(rng: SeededRng) -> Array:
	var all: Array = []
	for cy in GRID.y:
		for cx in GRID.x:
			if cx + 1 < GRID.x:
				all.append([Vector2i(cx, cy), Vector2i(cx + 1, cy)])
			if cy + 1 < GRID.y:
				all.append([Vector2i(cx, cy), Vector2i(cx, cy + 1)])
	all = rng.shuffled(all)
	# Kruskal's algorithm over the cells, with a simple union-find.
	var parent := {}
	for cy in GRID.y:
		for cx in GRID.x:
			parent[Vector2i(cx, cy)] = Vector2i(cx, cy)
	var chosen: Array = []
	var spare: Array = []
	for link: Array in all:
		var a: Vector2i = _root(parent, link[0])
		var b: Vector2i = _root(parent, link[1])
		if a != b:
			parent[a] = b
			chosen.append(link)
		else:
			spare.append(link)
	if not spare.is_empty():
		chosen.append(spare[0])
	return chosen


static func _root(parent: Dictionary, c: Vector2i) -> Vector2i:
	while parent[c] != c:
		c = parent[c]
	return c


## Opens a one-tile door in the wall between two neighbouring cells, at the room's middle.
static func _carve_door(tiles: PackedByteArray, a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var origin := Vector2i(lo.x * CELL.x + 1, lo.y * CELL.y + 1)
	if a.y == b.y:
		var y := origin.y + ROOM.y / 2
		var wall_x := origin.x + ROOM.x
		tiles[_index(Vector2i(wall_x, y))] = Tile.FLOOR
		# Clear the tiles either side, so a pillar never blocks a door.
		tiles[_index(Vector2i(wall_x - 1, y))] = Tile.FLOOR
		tiles[_index(Vector2i(wall_x + 1, y))] = Tile.FLOOR
	else:
		var x := origin.x + ROOM.x / 2
		var wall_y := origin.y + ROOM.y
		tiles[_index(Vector2i(x, wall_y))] = Tile.FLOOR
		tiles[_index(Vector2i(x, wall_y - 1))] = Tile.FLOOR
		tiles[_index(Vector2i(x, wall_y + 1))] = Tile.FLOOR


static func _farthest_cell(tiles: PackedByteArray, rooms: Array[Vector2i], from_cell: int) -> int:
	var centre := Vector2i(ROOM.x / 2, ROOM.y / 2)
	var dist := bfs(tiles, rooms[from_cell] + centre)
	var best := from_cell
	var best_d := -1
	for i in rooms.size():
		var d: int = dist.get(rooms[i] + centre, -1)
		if d > best_d:
			best_d = d
			best = i
	return best
