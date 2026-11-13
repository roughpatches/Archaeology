extends "res://tests/test_case.gd"

const Boat := preload("res://core/boat.gd")
const Finds := preload("res://core/finds.gd")
const GameStateScript := preload("res://autoload/game_state.gd")


func _state(world_seed: int = 5) -> Node:
	var gs: Node = GameStateScript.new()
	gs.new_game(world_seed)
	return gs


func test_intact_finds_sell_for_more_than_pieces() -> void:
	var intact := {"id": "Serpent idol", "rarity": "uncommon", "condition": "intact"}
	var piece := {"id": "Serpent idol", "rarity": "uncommon", "condition": "fragment"}
	assert_true(Boat.offer("dace", intact) > Boat.offer("dace", piece))


func test_a_keen_trader_pays_more() -> void:
	var bead := {"id": "Jade bead", "rarity": "common", "condition": "pristine"}
	assert_true(Boat.likes("mira", bead), "Mira likes common finds")
	assert_false(Boat.likes("dace", bead))
	assert_true(Boat.offer("mira", bead) > Boat.offer("dace", bead))
	assert_true(Boat.likes("corvin", bead), "Corvin likes the jade collection")


func test_every_find_belongs_to_a_collection() -> void:
	for r: String in Finds.BY_RARITY:
		for f: String in Finds.BY_RARITY[r]:
			assert_ne(Finds.collection_of(f), "", f)


func test_the_boat_calls_every_one_to_three_days() -> void:
	var gs := _state()
	var arrivals: Array[int] = []
	for i in 40:
		gs.pass_half()
		if gs.half() == 0 and not gs.boat_here().is_empty() and gs.boat_here()["day"] == gs.day():
			arrivals.append(gs.day())
	assert_eq(arrivals[0], Boat.FIRST_CALL)
	for k in range(1, arrivals.size()):
		var gap := arrivals[k] - arrivals[k - 1]
		assert_true(gap >= Boat.MIN_GAP and gap <= Boat.MAX_GAP, "gap %d" % gap)
	assert_true(arrivals.size() >= 5)
	gs.free()


func test_the_boat_stays_the_day_and_leaves_at_dawn() -> void:
	var gs := _state()
	gs.data["boat"]["next_day"] = 2
	gs.pass_half()
	gs.pass_half()
	assert_false(gs.boat_here().is_empty(), "in on day 2")
	gs.pass_half()
	assert_false(gs.boat_here().is_empty(), "still in that night")
	gs.data["boat"]["next_day"] = 99
	gs.pass_half()
	assert_true(gs.boat_here().is_empty(), "gone at dawn")
	gs.free()


func test_selling_and_buying() -> void:
	var gs := _state()
	gs.data["boat"]["here"] = {"trader": "brask", "collector": "", "day": 1}
	gs.data["finds"] = [{"id": "Bone flute", "rarity": "common", "condition": "intact"}]
	gs.data["inventory"]["Crystal"] = 3
	gs.sell_find(0)
	assert_eq(gs.data["finds"].size(), 0)
	var after_find: int = gs.coin()
	assert_true(after_find > 0)
	gs.sell_crystals()
	assert_eq(gs.coin(), after_find + 3 * Boat.CRYSTAL_PRICE)
	gs.data["coin"] = 100
	gs.data["gear"]["flare"] = 0
	gs.buy_gear("flare")
	assert_eq(gs.coin(), 100 - Boat.GEAR_PRICES["flare"])
	assert_eq(gs.data["gear"]["flare"], 1)
	gs.free()


func test_donating_completes_a_collection_once() -> void:
	var gs := _state()
	gs.data["boat"]["here"] = {"trader": "mira", "collector": "sel", "day": 1}
	gs.data["finds"] = [
		{
			"id": "Star-chart shard",
			"rarity": "uncommon",
			"condition": "worn",
			"context": "unrecorded"
		},
		{"id": "Jade bead", "rarity": "common", "condition": "worn", "context": "documented"},
		{
			"id": "Star-carved lintel stone",
			"rarity": "rare",
			"condition": "intact",
			"context": "documented"
		},
		{
			"id": "Star-chart shard",
			"rarity": "uncommon",
			"condition": "pristine",
			"context": "documented"
		},
	]
	assert_true(gs.donate(1).begins_with("That isn't part"), "wrong collection")
	gs.donate(0)
	assert_true(gs.donate(2).begins_with("They already have"), "duplicate refused")
	gs.donate(1)
	var m: Dictionary = gs.data["museums"]["stars"]
	assert_true(m["complete"])
	assert_eq(m["renown"], 3, "1 unrecorded + 2 documented")
	assert_eq(gs.coin(), Boat.COLLECTION_REWARD)
	assert_eq(gs.data["finds"].size(), 2)
	gs.free()
