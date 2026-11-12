extends SceneTree
## Headless test runner (D27). Run from the project folder:
##   godot --headless -s res://tests/run_tests.gd
## Runs every tests/unit/test_*.gd. Exits 1 if any test fails or makes no assertions.

const TEST_DIR := "res://tests/unit"


func _init() -> void:
	var ran := 0
	var failed := 0
	for file in _test_files():
		var script: GDScript = load(TEST_DIR.path_join(file))
		if script == null or not script.can_instantiate():
			print("  FAIL %s :: could not load (parse error?)" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			ran += 1
			var case: Variant = script.new()
			case.call(test_name)
			var problems: Array[String] = case.failures
			if case.assertions == 0:
				problems.append("no assertions ran (did the test hit a script error?)")
			if problems.is_empty():
				print("  ok   %s :: %s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL %s :: %s" % [file, test_name])
				for problem in problems:
					print("         " + problem)
	print("\n%d tests, %d failed" % [ran, failed])
	quit(1 if failed > 0 or ran == 0 else 0)


func _test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	return files
