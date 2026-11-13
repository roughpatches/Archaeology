extends "res://tests/test_case.gd"

const Calendar := preload("res://core/calendar.gd")


func test_halves_alternate_and_days_count_up() -> void:
	assert_eq(Calendar.next(1, 0), [1, 1] as Array[int])
	assert_eq(Calendar.next(1, 1), [2, 0] as Array[int])
	assert_eq(Calendar.half_index(1, 0), 0)
	assert_eq(Calendar.half_index(3, 1), 5)


func test_seasons_turn_over_and_wrap() -> void:
	assert_eq(Calendar.season(1), 0)
	assert_eq(Calendar.season(Calendar.SEASON_DAYS), 0)
	assert_eq(Calendar.season(Calendar.SEASON_DAYS + 1), 1)
	assert_eq(Calendar.season(Calendar.SEASON_DAYS * 4 + 1), 0, "a year later")
	assert_eq(Calendar.day_of_season(Calendar.SEASON_DAYS + 2), 2)


func test_describe_reads_well() -> void:
	assert_eq(Calendar.describe(9, 1), "Day 9, night. The Rains, day 2 of 7.")
