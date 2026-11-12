extends "res://tests/test_case.gd"

const FloorGen := preload("res://core/expedition/floor_gen.gd")


func test_same_seed_same_floor() -> void:
	var a := FloorGen.generate(11)
	var b := FloorGen.generate(11)
	assert_eq(a["tiles"], b["tiles"])
	assert_eq(a["entry"], b["entry"])
	assert_eq(a["exit"], b["exit"])


func test_every_room_and_the_exit_can_be_reached() -> void:
	for s in 30:
		var f := FloorGen.generate(s)
		var dist := FloorGen.bfs(f["tiles"], f["entry"])
		assert_true(dist.has(f["exit"]), "seed %d: exit reachable" % s)
		for origin: Vector2i in f["rooms"]:
			var centre := origin + Vector2i(FloorGen.ROOM.x / 2, FloorGen.ROOM.y / 2)
			assert_true(dist.has(centre), "seed %d: room %s reachable" % [s, origin])


func test_exit_is_away_from_entry() -> void:
	for s in 30:
		var f := FloorGen.generate(s)
		assert_true(FloorGen.distance(f, f["entry"], f["exit"]) >= 10, "seed %d" % s)


func test_entry_and_exit_are_walkable() -> void:
	var f := FloorGen.generate(5)
	assert_true(FloorGen.walkable(f, f["entry"]))
	assert_true(FloorGen.walkable(f, f["exit"]))
	assert_false(FloorGen.walkable(f, Vector2i(0, 0)), "outer wall")
