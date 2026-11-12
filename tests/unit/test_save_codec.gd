extends "res://tests/test_case.gd"

const Codec := preload("res://core/save_codec.gd")
const Migrations := preload("res://core/save_migrations.gd")


func test_round_trip_keeps_ints_as_ints() -> void:
	var data := Migrations.new_game_data(123456789)
	data["inventory"] = {"rope": 2}
	data["finds"] = [{"id": "lantern_shard", "condition": 3}]
	var back := Codec.decode(Codec.encode(data))
	assert_eq(back, data)
	assert_eq(typeof(back["day"]), TYPE_INT)


func test_real_fractions_stay_floats() -> void:
	var back := Codec.decode(Codec.encode({"ratio": 0.25}))
	assert_eq(back["ratio"], 0.25)


func test_bad_text_decodes_to_empty() -> void:
	assert_eq(Codec.decode("not json"), {})
	assert_eq(Codec.decode("[1, 2]"), {})
