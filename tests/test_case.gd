extends RefCounted
## Base for test files. Every method whose name starts with test_ is run by run_tests.gd,
## each on a fresh instance.

var failures: Array[String] = []
var assertions := 0


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected %s, got %s" % [var_to_str(expected), var_to_str(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("did not expect %s" % var_to_str(actual), message)


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	assertions += 1
	if condition:
		_fail("expected false", message)


func _fail(detail: String, message: String) -> void:
	failures.append(detail if message.is_empty() else "%s: %s" % [message, detail])
