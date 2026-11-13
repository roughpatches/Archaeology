extends "res://tests/test_case.gd"

const Migrations := preload("res://core/save_migrations.gd")


func test_new_game_is_current_version() -> void:
	var data := Migrations.new_game_data(5)
	assert_eq(data["version"], Migrations.CURRENT_VERSION)
	assert_eq(data["world_seed"], 5)
	assert_eq(data["day"], 1)


func test_current_save_passes_through_unchanged() -> void:
	var data := Migrations.new_game_data(5)
	assert_eq(Migrations.migrate(data), data)


func test_version_0_gets_defaults_and_keeps_its_values() -> void:
	var old := {"world_seed": 12, "day": 4}
	var migrated := Migrations.migrate(old)
	assert_eq(migrated["version"], Migrations.CURRENT_VERSION)
	assert_eq(migrated["day"], 4, "kept")
	assert_eq(migrated["world_seed"], 12, "kept")
	assert_eq(migrated["stamina"], {"current": 100, "max": 100}, "filled in")
	assert_false(old.has("version"), "input not changed")


func test_save_from_a_newer_game_is_refused() -> void:
	var future := {"version": Migrations.CURRENT_VERSION + 1}
	assert_eq(Migrations.migrate(future), {})


func test_non_dictionary_is_refused() -> void:
	assert_eq(Migrations.migrate([1, 2]), {})
	assert_eq(Migrations.migrate(null), {})


func test_version_1_gains_time_of_day_gear_and_regrowth() -> void:
	var v1 := {
		"version": 1,
		"world_seed": 3,
		"day": 6,
		"stamina": {"current": 40, "max": 100},
		"inventory": {"Crystal": 2},
		"finds": [],
		"camp": {"buildings": []},
		"flags": {},
	}
	var migrated := Migrations.migrate(v1)
	assert_eq(migrated["version"], Migrations.CURRENT_VERSION)
	assert_eq(migrated["half"], 0)
	assert_eq(migrated["gear"], Migrations.starting_gear())
	assert_eq(migrated["forage"], {})
	assert_eq(migrated["day"], 6, "kept")
	assert_eq(migrated["inventory"], {"Crystal": 2}, "kept")


func test_version_2_gains_coin_the_boat_and_museums() -> void:
	var v2 := Migrations.new_game_data(4)
	v2["version"] = 2
	v2["day"] = 9
	v2.erase("coin")
	v2.erase("boat")
	v2.erase("museums")
	var migrated := Migrations.migrate(v2)
	assert_eq(migrated["coin"], 0)
	assert_eq(migrated["boat"]["next_day"], 10, "the boat calls the next day")
	assert_eq(migrated["museums"], {})


func test_version_3_gains_the_shelf_and_a_journal_of_what_you_have() -> void:
	var v3 := Migrations.new_game_data(4)
	v3["version"] = 3
	v3.erase("shelf")
	v3.erase("journal")
	v3["finds"] = [{"id": "Bone flute"}]
	v3["museums"] = {"jade": {"donated": ["Jade bead"], "renown": 1, "complete": false}}
	var migrated := Migrations.migrate(v3)
	assert_eq(migrated["version"], 4)
	assert_eq(migrated["shelf"], [])
	assert_true(migrated["journal"]["seen"].has("Bone flute"))
	assert_true(migrated["journal"]["seen"].has("Jade bead"))
	assert_eq(migrated["journal"]["notes"], [])
