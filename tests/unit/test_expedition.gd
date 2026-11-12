extends "res://tests/test_case.gd"

const Expedition := preload("res://core/expedition/expedition.gd")
const FloorGen := preload("res://core/expedition/floor_gen.gd")


func test_same_seed_same_floor_contents() -> void:
	var a := Expedition.new(7)
	var b := Expedition.new(7)
	assert_eq(a.player, b.player)
	assert_eq(a.nodes, b.nodes)
	assert_eq(a.spots.size(), b.spots.size())
	for i in a.spots.size():
		assert_eq(a.spots[i]["pos"], b.spots[i]["pos"])
		assert_eq(a.spots[i]["dig"].find_id, b.spots[i]["dig"].find_id)


func test_first_floor_has_a_spot_and_no_creatures() -> void:
	for s in 10:
		var e := Expedition.new(s)
		assert_true(e.spots.size() >= 1, "seed %d spots" % s)
		assert_eq(e.creatures.size(), 0, "seed %d creatures" % s)


func test_survey_costs_stamina_and_maps_spots_in_range() -> void:
	var e := Expedition.new(3)
	var spot: Dictionary = e.spots[0]
	e.player = spot["pos"]
	assert_true(e.survey())
	assert_eq(e.stamina, 100 - Expedition.SURVEY_COST)
	assert_true(spot["dig"].surveyed)
	assert_true(spot["noticed"])


func test_climb_out_only_from_the_rope() -> void:
	var e := Expedition.new(4)
	e.player = e.floor_data["exits"][0]
	assert_false(e.climb_out())
	e.player = e.floor_data["entry"]
	assert_true(e.climb_out())
	assert_eq(e.state, "climbed_out")
	assert_false(e.move(Vector2i.RIGHT), "nothing happens after the run ends")


func test_descend_goes_one_floor_deeper() -> void:
	var e := Expedition.new(5)
	e.player = e.floor_data["exits"][0]
	assert_true(e.descend())
	assert_eq(e.depth, 2)
	assert_eq(e.stamina, 100 - Expedition.DESCEND_COST)
	assert_eq(e.player, e.floor_data["entry"])


func test_running_out_of_stamina_collapses() -> void:
	var e := Expedition.new(6, 4)
	for i in 5:
		e.bag.append({"kind": "material", "id": "Crystal"})
	assert_true(e.survey())
	assert_eq(e.state, "collapsed")
	assert_eq(e.bag.size(), 2, "lost 3 of 5")


func test_a_creature_next_to_you_bites_then_is_stunned() -> void:
	var e := Expedition.new(8)
	e.player = e.floor_data["entry"]
	var free := Vector2i.ZERO
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if FloorGen.walkable(e.floor_data, e.player + d):
			free = e.player + d
			break
	e.creatures = [{"pos": free + (free - e.player), "flee": 0, "stun": 0}]
	e.spots = []
	e.nodes = []
	# Survey is one tick: the creature steps next to the player and bites.
	e.survey()
	assert_eq(e.stamina, 100 - Expedition.SURVEY_COST - Expedition.BITE_COST)
	assert_eq(e.creatures[0]["stun"], Expedition.STUN_TICKS)


func test_flare_makes_nearby_creatures_flee() -> void:
	var e := Expedition.new(9)
	e.creatures = [{"pos": e.player + Vector2i(3, 0), "flee": 0, "stun": 0}]
	assert_true(e.use_flare())
	assert_eq(e.flares, Expedition.FLARES - 1)
	assert_eq(e.creatures[0]["flee"], Expedition.FLEE_TICKS - 1, "fled one tick already")


func test_last_floor_climbs_out_from_its_far_end() -> void:
	var e := Expedition.new(10)
	e.enter_floor(Expedition.FLOORS)
	e.player = e.floor_data["exits"][0]
	assert_false(e.descend(), "no deeper floor")
	assert_true(e.climb_out())


func test_stepping_off_a_drop_cannot_be_undone() -> void:
	var e := Expedition.new(11)
	e.creatures = []
	var t: Dictionary = e.floor_data["tunnels"][0]
	e.player = t["ledge"] + Vector2i.LEFT
	assert_true(e.move(Vector2i.RIGHT), "onto the lip")
	assert_true(e.on_ledge())
	assert_true(e.move(Vector2i.LEFT), "can still turn back from the lip")
	assert_true(e.move(Vector2i.RIGHT))
	assert_true(e.move(Vector2i.RIGHT), "drop")
	assert_eq(e.current_chamber(), t["to"])
	assert_false(e.move(Vector2i.LEFT), "no climbing back")


func test_you_cannot_see_into_a_chamber_before_you_drop_in() -> void:
	var e := Expedition.new(12)
	var t: Dictionary = e.floor_data["tunnels"][0]
	e.player = t["ledge"]
	e._reveal()
	var below: Vector2i = t["ledge"] + Vector2i(2, 0)
	assert_false(e.seen.has(below))
	e.player = t["ledge"] + Vector2i.RIGHT
	e._reveal()
	assert_true(e.seen.has(below))


func test_survey_checks_the_hints_of_the_ways_ahead() -> void:
	var e := Expedition.new(13)
	assert_true(e.survey())
	var hints := e.tunnel_hints()
	var tunnels: Array = e.floor_data["tunnels"]
	for i in tunnels.size():
		var kind: String = e.floor_data["chambers"][tunnels[i]["to"]]["kind"]
		if tunnels[i]["from"] == 0:
			assert_true(hints[i]["checked"])
			assert_eq(hints[i]["text"], FloorGen.HINTS[kind])
		else:
			assert_false(hints[i]["checked"])


func test_a_spring_gives_stamina_back_once() -> void:
	var e := Expedition.new(14, 50)
	e.creatures = []
	e.nodes = []
	var p := e.player + Vector2i.RIGHT
	e.springs = [p]
	assert_true(e.move(Vector2i.RIGHT))
	assert_eq(e.stamina, 50 + Expedition.SPRING_GAIN)
	e.move(Vector2i.LEFT)
	e.move(Vector2i.RIGHT)
	assert_eq(e.stamina, 50 + Expedition.SPRING_GAIN)


func _quiet(seed_value: int, stamina: int = 100) -> Expedition:
	var e := Expedition.new(seed_value, stamina)
	e.quakes = false
	e.creatures = []
	e.streams = []
	return e


func _wait(e: Expedition, n: int) -> void:
	for i in n:
		e.ticks += 1
		e._shift_tomb()


func test_a_rockfall_warns_then_lands_as_rubble_you_can_clear() -> void:
	var e := _quiet(20)
	assert_true(e.start_rumble("rockfall"))
	var tiles: Array = e.rumble["tiles"]
	assert_true(tiles.size() >= 1)
	assert_eq(FloorGen.tile_at(e.floor_data, tiles[0]), FloorGen.Tile.FLOOR, "warning first")
	_wait(e, Expedition.WARN_TICKS)
	assert_true(e.rumble.is_empty())
	var rubble: Vector2i = tiles[tiles.size() - 1]
	assert_eq(FloorGen.tile_at(e.floor_data, rubble), FloorGen.Tile.RUBBLE)
	assert_false(FloorGen.walkable(e.floor_data, rubble))
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if FloorGen.tile_at(e.floor_data, rubble - d) == FloorGen.Tile.FLOOR:
			e.player = rubble - d
			assert_true(e.move(d), "walk into rubble clears it")
			assert_eq(FloorGen.tile_at(e.floor_data, rubble), FloorGen.Tile.FLOOR)
			assert_eq(e.stamina, 100 - Expedition.CLEAR_COST)
			return
	assert_true(false, "rubble had an open side")


func test_a_rockfall_on_you_costs_stamina() -> void:
	var e := _quiet(21)
	assert_true(e.start_rumble("rockfall"))
	e.player = e.rumble["tiles"][0]
	_wait(e, Expedition.WARN_TICKS)
	assert_eq(e.stamina, 100 - Expedition.ROCK_HIT)
	assert_eq(FloorGen.tile_at(e.floor_data, e.player), FloorGen.Tile.FLOOR, "you're not buried")


func test_a_collapse_never_seals_the_last_way_on() -> void:
	for s in 15:
		var e := _quiet(30 + s)
		var ways: Array = e.floor_data["tunnels"].filter(
			func(t: Dictionary) -> bool: return t["from"] == 0
		)
		var caved := 0
		for k in ways.size() + 2:
			if e.start_rumble("collapse") and e.rumble["kind"] == "collapse":
				_wait(e, Expedition.WARN_TICKS + 1)
				caved += 1
			else:
				e.rumble = {}
		assert_eq(caved, ways.size() - 1, "seed %d" % s)
		var open_ways := 0
		for i in e.floor_data["tunnels"].size():
			if e.floor_data["tunnels"][i]["from"] == 0:
				if e.collapsed.has(i):
					assert_eq(e.tunnel_hints()[i]["text"], "caved in")
				else:
					open_ways += 1
		assert_eq(open_ways, 1, "seed %d" % s)


func test_streams_shift_and_cost_stamina_to_wade() -> void:
	for s in 40:
		var e := Expedition.new(s)
		e.quakes = false
		e.enter_floor(2)
		if e.streams.is_empty():
			continue
		var st: Dictionary = e.streams[0]
		var x: int = st["x"]
		var rect: Rect2i = e.floor_data["chambers"][st["chamber"]]["rect"]
		var y := rect.position.y + 4
		assert_eq(FloorGen.tile_at(e.floor_data, Vector2i(x, y)), FloorGen.Tile.WATER)
		e.creatures = []
		e.player = Vector2i(x - 1, y)
		var before := e.stamina
		e.ticks = 1
		assert_true(e.move(Vector2i.RIGHT))
		assert_eq(e.stamina, before - Expedition.WADE_COST)
		e.ticks = Expedition.STREAM_SHIFT - 1
		e._tick()
		assert_ne(st["x"], x, "moved")
		assert_eq(FloorGen.tile_at(e.floor_data, Vector2i(st["x"], y)), FloorGen.Tile.WATER)
		return
	assert_true(false, "no stream found in 40 seeds")


func test_light_does_not_remember_where_you_have_been() -> void:
	var e := _quiet(22)
	var start := e.player
	for i in 8:
		e.move(Vector2i.RIGHT)
	assert_false(e.lit.has(start))
	assert_true(e.seen.has(start))
	assert_true(e.lit.has(e.player))
