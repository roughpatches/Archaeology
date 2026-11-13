extends "res://tests/test_case.gd"

const FloorGen := preload("res://core/expedition/floor_gen.gd")


func test_same_seed_same_floor() -> void:
	var a := FloorGen.generate(11, 2)
	var b := FloorGen.generate(11, 2)
	assert_eq(a["tiles"], b["tiles"])
	assert_eq(a["entry"], b["entry"])
	assert_eq(a["exits"], b["exits"])
	assert_eq(a["tunnels"].size(), b["tunnels"].size())
	for i in a["tunnels"].size():
		assert_eq(a["tunnels"][i]["hint"], b["tunnels"][i]["hint"])


func test_every_chamber_can_be_reached_and_leads_on() -> void:
	for s in 40:
		var f := FloorGen.generate(s, 3)
		var from_entry := FloorGen.reachable(f, f["entry"])
		for c: Dictionary in f["chambers"]:
			assert_true(from_entry.has(c["centre"]), "seed %d: chamber reachable" % s)
			var ahead := FloorGen.reachable(f, c["centre"])
			var exits: Array = f["exits"]
			assert_true(exits.any(func(e: Vector2i) -> bool: return ahead.has(e)), "seed %d" % s)


func test_drops_are_one_way() -> void:
	for s in 20:
		var f := FloorGen.generate(s)
		for t: Dictionary in f["tunnels"]:
			var below: Vector2i = t["ledge"] + Vector2i.RIGHT
			assert_true(FloorGen.can_step(f, t["ledge"], Vector2i.RIGHT), "seed %d down" % s)
			assert_false(FloorGen.can_step(f, below, Vector2i.LEFT), "seed %d back up" % s)
		var after_first_drop := FloorGen.reachable(f, f["chambers"][1]["centre"])
		assert_false(after_first_drop.has(f["entry"]), "seed %d: no way back to landing" % s)


func test_landing_forks_and_tunnels_go_forward_one_layer() -> void:
	for s in 40:
		var f := FloorGen.generate(s)
		var from_landing := 0
		for t: Dictionary in f["tunnels"]:
			var a: Dictionary = f["chambers"][t["from"]]
			var b: Dictionary = f["chambers"][t["to"]]
			assert_eq(b["layer"], a["layer"] + 1, "seed %d" % s)
			assert_true(absi(b["slot"] - a["slot"]) <= 1, "seed %d" % s)
			if t["from"] == 0:
				from_landing += 1
		assert_true(from_landing >= 2, "seed %d: the landing forks" % s)


func test_tunnels_never_touch_each_other() -> void:
	for s in 40:
		var f := FloorGen.generate(s)
		var owner := {}
		var tunnels: Array = f["tunnels"]
		for i in tunnels.size():
			for p: Vector2i in tunnels[i]["path"]:
				assert_false(owner.has(p), "seed %d: tunnels overlap at %s" % [s, p])
				owner[p] = i
		for p: Vector2i in owner:
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var n: Vector2i = p + d
				if owner.has(n):
					assert_eq(owner[n], owner[p], "seed %d: tunnels touch at %s" % [s, p])


func test_hints_are_mostly_right_and_every_floor_has_a_dig() -> void:
	var right := 0
	var total := 0
	for s in 60:
		var f := FloorGen.generate(s, 2)
		for t: Dictionary in f["tunnels"]:
			total += 1
			if t["hint"] == f["chambers"][t["to"]]["kind"]:
				right += 1
		var kinds: Array = f["chambers"].map(func(c: Dictionary) -> String: return c["kind"])
		assert_true(kinds.has("dig"), "seed %d: a dig chamber" % s)
	var share := float(right) / total
	assert_true(share > 0.55 and share < 0.8, "hint accuracy %.2f" % share)


func test_no_creatures_on_floor_one() -> void:
	for s in 30:
		var f := FloorGen.generate(s, 1)
		for c: Dictionary in f["chambers"]:
			assert_ne(c["kind"], "creature", "seed %d" % s)


func test_night_brings_creatures_and_the_rains_bring_streams() -> void:
	var day_creatures := 0
	var night_creatures := 0
	var dry_streams := 0
	var wet_streams := 0
	for s in 40:
		var day := FloorGen.generate(s, 1)
		var night := FloorGen.generate(s, 1, {"night": true})
		var wet := FloorGen.generate(s, 1, {"rains": true})
		for c: Dictionary in day["chambers"]:
			day_creatures += 1 if c["kind"] == "creature" else 0
			dry_streams += 1 if c["stream_x"] >= 0 else 0
		for c: Dictionary in night["chambers"]:
			night_creatures += 1 if c["kind"] == "creature" else 0
		for c: Dictionary in wet["chambers"]:
			wet_streams += 1 if c["stream_x"] >= 0 else 0
	assert_eq(day_creatures, 0, "none on floor 1 by day")
	assert_true(night_creatures > 0)
	assert_true(wet_streams > dry_streams)


func test_a_draft_only_ever_points_at_a_real_shaft() -> void:
	for s in 60:
		var f := FloorGen.generate(s, 2)
		for t: Dictionary in f["tunnels"]:
			if t["draft"]:
				assert_ne(f["chambers"][t["to"]]["shaft"], FloorGen.NO_SHAFT, "seed %d" % s)
