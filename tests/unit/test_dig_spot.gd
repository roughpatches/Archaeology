extends "res://tests/test_case.gd"

const DigSpot := preload("res://core/expedition/dig_spot.gd")


func _spot() -> DigSpot:
	return DigSpot.new(42, "Potsherd", "common")


func test_find_is_two_to_four_connected_tiles() -> void:
	for s in 20:
		var d := DigSpot.new(s)
		assert_true(d.find_tiles.size() >= 2 and d.find_tiles.size() <= 4, "seed %d" % s)


func test_brush_exposes_cleanly_and_trowel_chips() -> void:
	var d := _spot()
	var a: int = d.find_tiles[0]
	var b: int = d.find_tiles[1]
	while d.tiles[a]["depth"] > 0:
		d.use(a, "brush")
	while d.tiles[b]["depth"] > 0:
		d.use(b, "trowel")
	assert_false(d.tiles[a]["chipped"], "brush is safe")
	assert_true(d.tiles[b]["chipped"], "trowel chips on the last layer")


func test_probe_marks_without_digging() -> void:
	var d := _spot()
	var before: int = d.tiles[0]["depth"]
	var events := d.use(0, "probe")
	assert_eq(events[0]["kind"], "probed")
	assert_eq(d.tiles[0]["depth"], before)
	assert_false(d.can_use(0, "probe", 100), "can't probe twice")


func test_lifting_locked_find_does_damage() -> void:
	var d := _spot()
	for i in d.find_tiles:
		while d.tiles[i]["depth"] > 0:
			d.use(i, "brush")
	assert_true(d.is_exposed())
	var expected := ceili(d.locked_sides().size() / 3.0)
	assert_true(expected > 0, "soil still round it")
	assert_eq(d.lift(), expected)
	assert_eq(d.result()["condition"] == "pristine", false)


func test_clean_lift_is_pristine_and_survey_documents() -> void:
	var d := _spot()
	d.surveyed = true
	for i in d.tiles.size():
		while d.tiles[i]["depth"] > 0:
			d.use(i, "brush")
	assert_eq(d.lift(), 0)
	assert_eq(d.result()["condition"], "pristine")
	assert_eq(d.result()["context"], "documented")


func test_grade_condition() -> void:
	assert_eq(DigSpot.grade_condition(4, 0), "pristine")
	assert_eq(DigSpot.grade_condition(4, 1), "intact")
	assert_eq(DigSpot.grade_condition(4, 2), "worn")
	assert_eq(DigSpot.grade_condition(4, 3), "fragment")
