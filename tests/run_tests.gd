extends SceneTree
## Headless test runner.
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd            # all suites
##   godot --headless --path . --script res://tests/run_tests.gd -- unit    # one suite
##
## A test fails when a check fails or when any engine or script error is
## logged while it runs. GDScript runtime errors abort only the failing
## function and the caller continues, so errors are caught with a Logger
## instead of relying on the test reaching its end.
##
## A test file can define `skip_reason() -> String`; a non-empty result marks
## all its tests SKIP (e.g. integration tests without the map GLB).
##
## Exit code: 0 = no failures and no skips; 1 = a failure, an error logged
## outside a test, or nothing passed; 2 = no failures, but tests were skipped.

const SUITES := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
}


class ErrorCapture extends Logger:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := "%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line]
		_mutex.lock()
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	## Returns and clears everything captured so far.
	func take() -> Dictionary:
		_mutex.lock()
		var captured := {"errors": errors.duplicate(), "warnings": warnings.duplicate()}
		errors.clear()
		warnings.clear()
		_mutex.unlock()
		return captured


var _capture := ErrorCapture.new()


func _initialize() -> void:
	OS.add_logger(_capture)
	_run.call_deferred()


func _run() -> void:
	# Headless windows default to 64x64; use the project's design resolution.
	root.size = Vector2i(1440, 900)
	await process_frame
	var selected := OS.get_cmdline_user_args()
	if selected.is_empty():
		selected = PackedStringArray(SUITES.keys())
	var passed := 0
	var failed := 0
	var skipped := 0
	var outside: Array[String] = []
	for suite in selected:
		if not SUITES.has(suite):
			printerr("Unknown suite: ", suite)
			failed += 1
			continue
		for path in _test_files(SUITES[suite]):
			var script := load(path) as GDScript
			outside.append_array(_capture.take().errors)
			if script == null or not script.can_instantiate():
				failed += 1
				print("FAIL ", path.get_file(), " (script failed to load)")
				continue
			var skip_reason := ""
			if script.new().has_method(&"skip_reason"):
				skip_reason = script.new().skip_reason()
			for method in script.get_script_method_list():
				var test_name: String = method.name
				if not test_name.begins_with("test_"):
					continue
				var label := "%s::%s" % [path.get_file(), test_name]
				if not skip_reason.is_empty():
					skipped += 1
					print("SKIP ", label, " (", skip_reason, ")")
					continue
				var case = script.new()
				case.tree = self
				var started := Time.get_ticks_msec()
				_capture.take()
				await case.call(test_name)
				await case.cleanup()
				var captured := _capture.take()
				var problems: Array[String] = []
				problems.append_array(case.failures)
				for error: String in captured.errors:
					problems.append("logged error: " + error)
				label += " (%d ms)" % (Time.get_ticks_msec() - started)
				if problems.is_empty():
					passed += 1
					print("PASS ", label)
				else:
					failed += 1
					print("FAIL ", label)
					for problem in problems:
						print("     - ", problem)
				for warning: String in captured.warnings:
					print("     ! warning: ", warning)
	outside.append_array(_capture.take().errors)
	for error in outside:
		print("ERROR outside tests: ", error)
	print("RESULT %d passed, %d failed, %d skipped%s" % [passed, failed, skipped, ", %d errors outside tests" % outside.size() if outside.size() > 0 else ""])
	OS.remove_logger(_capture)
	if failed > 0 or not outside.is_empty() or passed == 0:
		quit(1)
	elif skipped > 0:
		quit(2)
	else:
		quit(0)


func _test_files(directory: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(directory.path_join(file))
	files.sort()
	return files
