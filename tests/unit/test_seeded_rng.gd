extends "res://tests/test_case.gd"

const SeededRng := preload("res://core/seeded_rng.gd")


func test_same_seed_gives_same_sequence() -> void:
	var a := SeededRng.new(42)
	var b := SeededRng.new(42)
	for i in 20:
		assert_eq(a.range_int(0, 1000), b.range_int(0, 1000), "draw %d" % i)


func test_different_seeds_differ() -> void:
	var a := SeededRng.new(1)
	var b := SeededRng.new(2)
	var same := 0
	for i in 20:
		if a.range_int(0, 1_000_000) == b.range_int(0, 1_000_000):
			same += 1
	assert_true(same < 20)


func test_range_int_stays_in_bounds() -> void:
	var rng := SeededRng.new(7)
	for i in 200:
		var v := rng.range_int(3, 5)
		assert_true(v >= 3 and v <= 5, "value %d" % v)


func test_weighted_index_never_picks_zero_weight() -> void:
	var rng := SeededRng.new(9)
	for i in 200:
		assert_ne(rng.weighted_index([1, 0, 2]), 1)


func test_weighted_index_with_no_positive_weight() -> void:
	var rng := SeededRng.new(9)
	assert_eq(rng.weighted_index([0, 0]), -1)
	assert_eq(rng.weighted_index([]), -1)


func test_shuffled_keeps_elements_and_original() -> void:
	var rng := SeededRng.new(3)
	var items := [1, 2, 3, 4, 5, 6]
	var out := rng.shuffled(items)
	assert_eq(items, [1, 2, 3, 4, 5, 6], "original untouched")
	out.sort()
	assert_eq(out, [1, 2, 3, 4, 5, 6])


func test_derive_is_stable_and_depends_on_parts() -> void:
	assert_eq(SeededRng.derive(100, ["cave", 3]), SeededRng.derive(100, ["cave", 3]))
	assert_ne(SeededRng.derive(100, ["cave", 3]), SeededRng.derive(100, ["cave", 4]))
	assert_ne(SeededRng.derive(100, ["cave", 3]), SeededRng.derive(101, ["cave", 3]))
