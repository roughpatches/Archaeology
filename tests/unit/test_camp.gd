extends "res://tests/test_case.gd"

const Camp := preload("res://core/overworld/camp.gd")
const Story := preload("res://core/overworld/story.gd")
const Expedition := preload("res://core/expedition/expedition.gd")
const FloorGen := preload("res://core/expedition/floor_gen.gd")
const GameStateScript := preload("res://autoload/game_state.gd")


func _state(coin: int = 0) -> Node:
	var gs: Node = GameStateScript.new()
	gs.new_game(11)
	gs.data["coin"] = coin
	return gs


func _find(id: String, context: String = "documented") -> Dictionary:
	return {"id": id, "rarity": "common", "condition": "intact", "context": context}


func test_an_upgrade_costs_coin_and_is_built_once() -> void:
	var gs := _state(70)
	assert_eq(gs.build("lamp"), "")
	assert_eq(gs.coin(), 10)
	assert_ne(gs.build("lamp"), "", "already built")
	assert_ne(gs.build("bag"), "", "can't afford it")
	gs.free()


func test_the_cot_raises_stamina() -> void:
	var gs := _state(500)
	gs.build("cot")
	assert_eq(int(gs.data["stamina"]["max"]), Camp.COT_STAMINA)
	gs.rest()
	assert_eq(gs.stamina(), Camp.COT_STAMINA)
	gs.free()


func test_upgrades_reach_the_tomb() -> void:
	var gs := _state(500)
	for id: String in ["lamp", "bag", "rope"]:
		gs.build(id)
	var e := Expedition.new(3, 100, {}, gs.expedition_conditions())
	assert_eq(e.sight, Camp.LAMP_SIGHT)
	assert_eq(e.bag_slots, Camp.BIG_BAG)
	e.enter_floor(2)
	assert_true(e.can_climb_out(), "the fixed rope hangs at the top of floor 2")
	e.enter_floor(3)
	assert_false(e.can_climb_out(), "but not floor 3")
	gs.free()


func test_the_shelf_holds_five_and_sharpens_hints() -> void:
	var gs := _state()
	for i in 6:
		gs.data["finds"].append(_find("Jade bead"))
	for i in 5:
		gs.display(0)
	assert_eq(gs.shelf().size(), Camp.SHELF_SLOTS)
	assert_ne(gs.display(0), "", "a sixth doesn't fit")
	assert_eq(gs.data["finds"].size(), 1)
	assert_true(gs.expedition_conditions()["hint_accuracy"] > Camp.BASE_HINT + 0.1)
	gs.take_down()
	assert_eq(gs.shelf().size(), 4)
	assert_eq(gs.data["finds"].size(), 2)
	gs.free()


func test_perfect_hints_are_always_right() -> void:
	var floor_data := FloorGen.generate(21, 3, {"hint_accuracy": 1.0})
	for t: Dictionary in floor_data["tunnels"]:
		assert_eq(t["hint"], floor_data["chambers"][t["to"]]["kind"])


func test_story_moves_on_only_when_ready() -> void:
	assert_eq(Story.next(0, 0, []), {}, "not before the first expedition")
	assert_eq(Story.next(0, 1, [])["stage"], 1)
	assert_eq(Story.next(1, 3, ["Jade bead"]), {}, "waits for a star find")
	assert_eq(Story.next(1, 3, ["Star-chart shard"])["stage"], 2)
	var last := Story.next(2, 3, ["Star-carved lintel stone"])
	assert_eq(last["stage"], Story.DONE)
	assert_eq(last["reward"], Story.REWARD)
	assert_eq(Story.next(Story.DONE, 9, ["Star-carved lintel stone"]), {})


func test_talking_to_philius_tells_the_story_and_notes_it() -> void:
	var gs := _state()
	assert_eq(gs.story_talk(), [], "nothing until you've been in")
	gs.apply_expedition([{"kind": "find", "id": "Star-chart shard"}], 50)
	assert_eq(int(gs.data["flags"]["expeditions"]), 1)
	assert_true(gs.data["journal"]["seen"].has("Star-chart shard"))
	assert_false(gs.story_talk().is_empty())
	assert_false(gs.story_talk().is_empty(), "the shard moves it on again")
	assert_eq(gs.story_stage(), 2)
	assert_eq(gs.data["journal"]["notes"].size(), 2)
	gs.data["shelf"].append(_find("Star-carved lintel stone"))
	gs.story_talk()
	assert_eq(gs.story_stage(), Story.DONE)
	assert_eq(gs.coin(), Story.REWARD)
	gs.free()


func test_giving_up_loses_half_the_bag() -> void:
	var e := Expedition.new(6)
	for i in 4:
		e.bag.append({"kind": "material", "id": "Crystal"})
	assert_true(e.give_up())
	assert_eq(e.state, "collapsed")
	assert_eq(e.bag.size(), 2)
	assert_false(e.give_up(), "already over")
