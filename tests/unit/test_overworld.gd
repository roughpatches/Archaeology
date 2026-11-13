extends "res://tests/test_case.gd"

const Forage := preload("res://core/overworld/forage.gd")
const Crafting := preload("res://core/overworld/crafting.gd")
const IslandMap := preload("res://core/overworld/island_map.gd")
const Philius := preload("res://core/overworld/philius.gd")
const Calendar := preload("res://core/calendar.gd")

## A day in each season (day 1 is the Dry season).
const DRY := 1
const RAINS := 8
const BLOOM := 15
const MISTS := 22


func test_plants_keep_to_their_time_and_season() -> void:
	assert_eq(Forage.why_not("glowcap", 0, RAINS, 1), "")
	assert_ne(Forage.why_not("glowcap", 0, RAINS, 0), "", "glowcaps hide by day")
	assert_ne(Forage.why_not("fruit", 0, DRY, 0), "", "nothing fruits in the dry")
	assert_eq(Forage.why_not("fruit", 0, BLOOM, 0), "")
	assert_eq(Forage.why_not("resin", 0, DRY, 0), "")
	assert_ne(Forage.why_not("resin", 0, DRY, 1), "", "resin by day only")


func test_a_picked_plant_grows_back() -> void:
	var ready := Forage.regrown_at("fiber", 1, 0)
	assert_ne(Forage.why_not("fiber", ready, 1, 1), "", "not yet")
	assert_eq(Forage.why_not("fiber", ready, 2, 0), "", "two halves later")


func test_best_season_gives_two() -> void:
	assert_eq(Forage.yield_now("fruit", BLOOM), 2)
	assert_eq(Forage.yield_now("fruit", RAINS), 1)
	assert_eq(Forage.yield_now("glowcap", MISTS), 2)


func test_crafting_spends_materials_and_respects_the_pack_cap() -> void:
	var inv := {"fiber": 5, "wood": 2}
	var gear := {"anchor": 0, "flare": 0, "ration": 0}
	assert_true(Crafting.craft("anchor", inv, gear))
	assert_eq(inv, {"fiber": 3, "wood": 1})
	assert_eq(gear["anchor"], 1)
	assert_false(Crafting.craft("flare", inv, gear), "no resin")
	assert_eq(Crafting.why_not("flare", inv, gear), "Needs 1 Resin + 1 Vine fiber.")
	gear["anchor"] = Crafting.PACK_CAP
	assert_false(Crafting.craft("anchor", inv, gear), "pack full")


func test_everything_on_the_island_can_be_reached() -> void:
	var start := IslandMap.start()
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if not seen.has(p + d) and IslandMap.walkable(p + d):
				seen[p + d] = true
				queue.append(p + d)
	var kinds := {}
	for t in IslandMap.things():
		kinds[t["kind"]] = true
		var reachable := false
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			reachable = reachable or seen.has(t["pos"] + d)
		assert_true(reachable, "%s reachable" % t["id"])
	for k: String in (
		["tent", "bench", "philius", "tomb", "trader", "collector", "boat"] + Forage.KINDS.keys()
	):
		assert_true(kinds.has(k), "the island has a %s" % k)


func test_philius_always_has_something_to_say() -> void:
	for s: String in Calendar.SEASONS:
		for n in 6:
			assert_ne(Philius.line(s, n % 2 == 1, n), "")
