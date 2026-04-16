extends SceneTree

## 极简 headless 测试运行器。
## 用法: godot --headless -s tests/test_runner.gd

var _pass := 0
var _fail := 0
var _errors: Array[String] = []
var _current_test := ""


func _init() -> void:
	var suites: Array[RefCounted] = [
		load("res://tests/test_game_logic.gd").new(self),
	]
	for suite in suites:
		suite.run()
	_print_summary()
	if _fail > 0:
		quit(1)
	else:
		quit(0)


func begin(name: String) -> void:
	_current_test = name


func assert_true(cond: bool, msg: String = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		var txt := "  FAIL: %s — %s" % [_current_test, msg]
		_errors.append(txt)
		printerr(txt)


func assert_false(cond: bool, msg: String = "") -> void:
	assert_true(not cond, msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a == b:
		_pass += 1
	else:
		_fail += 1
		var txt := "  FAIL: %s — expected %s got %s  %s" % [_current_test, str(b), str(a), msg]
		_errors.append(txt)
		printerr(txt)


func assert_neq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		_pass += 1
	else:
		_fail += 1
		var txt := "  FAIL: %s — did not expect %s  %s" % [_current_test, str(a), msg]
		_errors.append(txt)
		printerr(txt)


func assert_gt(a: float, b: float, msg: String = "") -> void:
	assert_true(a > b, "%s > %s  %s" % [a, b, msg])


func assert_lte(a: float, b: float, msg: String = "") -> void:
	assert_true(a <= b, "%s <= %s  %s" % [a, b, msg])


func _print_summary() -> void:
	print("")
	print("═══════════════════════════════════════")
	print("  Tests: %d passed, %d failed" % [_pass, _fail])
	print("═══════════════════════════════════════")
	if not _errors.is_empty():
		print("")
		for e in _errors:
			print(e)
	print("")
