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
