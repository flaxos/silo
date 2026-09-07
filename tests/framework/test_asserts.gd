# tests/framework/test_asserts.gd
class_name TestAsserts
extends RefCounted

var passed_count: int = 0
var failed_count: int = 0
var failures: Array[String] = []
var current_test_name: String = ""

func set_current_test(test_name: String) -> void:
	current_test_name = test_name

func record_pass() -> void:
	passed_count += 1

func record_fail(message: String) -> void:
	failed_count += 1
	var formatted_msg: String = "[FAIL] %s: %s" % [current_test_name, message]
	failures.append(formatted_msg)
	push_error(formatted_msg)

func assert_true(condition: bool, msg: String = "Expected true, got false") -> bool:
	if condition:
		record_pass()
		return true
	else:
		record_fail(msg)
		return false

func assert_false(condition: bool, msg: String = "Expected false, got true") -> bool:
	if not condition:
		record_pass()
		return true
	else:
		record_fail(msg)
		return false

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual == expected:
		record_pass()
		return true
	else:
		var detail: String = "Expected <%s>, got <%s>. %s" % [str(expected), str(actual), msg]
		record_fail(detail)
		return false

func assert_ne(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		record_pass()
		return true
	else:
		var detail: String = "Expected value not equal to <%s>, but they matched. %s" % [str(expected), msg]
		record_fail(detail)
		return false

func assert_almost_eq(actual: float, expected: float, epsilon: float = 0.0001, msg: String = "") -> bool:
	if absf(actual - expected) <= epsilon:
		record_pass()
		return true
	else:
		var detail: String = "Expected <%s> (±%s), got <%s>. %s" % [str(expected), str(epsilon), str(actual), msg]
		record_fail(detail)
		return false

func assert_null(val: Variant, msg: String = "Expected null") -> bool:
	if val == null:
		record_pass()
		return true
	else:
		record_fail("Expected null, got <%s>. %s" % [str(val), msg])
		return false

func assert_not_null(val: Variant, msg: String = "Expected non-null") -> bool:
	if val != null:
		record_pass()
		return true
	else:
		record_fail("Expected non-null, got null. %s" % [msg])
		return false

func assert_gt(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual > expected:
		record_pass()
		return true
	else:
		record_fail("Expected <%s> > <%s>. %s" % [str(actual), str(expected), msg])
		return false

func assert_gte(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual >= expected:
		record_pass()
		return true
	else:
		record_fail("Expected <%s> >= <%s>. %s" % [str(actual), str(expected), msg])
		return false

func assert_lt(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual < expected:
		record_pass()
		return true
	else:
		record_fail("Expected <%s> < <%s>. %s" % [str(actual), str(expected), msg])
		return false

func assert_lte(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual <= expected:
		record_pass()
		return true
	else:
		record_fail("Expected <%s> <= <%s>. %s" % [str(actual), str(expected), msg])
		return false

func reset() -> void:
	passed_count = 0
	failed_count = 0
	failures.clear()
	current_test_name = ""
