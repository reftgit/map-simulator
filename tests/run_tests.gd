extends SceneTree
## Headless test runner.
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd            # all suites
##   godot --headless --path . --script res://tests/run_tests.gd -- unit    # one suite
## Exit code 0 when every test passes.

const SUITES := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
}


func _initialize() -> void:
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
	for suite in selected:
		if not SUITES.has(suite):
			printerr("Unknown suite: ", suite)
			failed += 1
			continue
		for path in _test_files(SUITES[suite]):
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate():
				failed += 1
				print("FAIL ", path.get_file(), " (script failed to load)")
				continue
			for method in script.get_script_method_list():
				var test_name: String = method.name
				if not test_name.begins_with("test_"):
					continue
				var case = script.new()
				case.tree = self
				var started := Time.get_ticks_msec()
				await case.call(test_name)
				await case.cleanup()
				var label := "%s::%s (%d ms)" % [path.get_file(), test_name, Time.get_ticks_msec() - started]
				if case.failures.is_empty():
					passed += 1
					print("PASS ", label)
				else:
					failed += 1
					print("FAIL ", label)
					for failure in case.failures:
						print("     - ", failure)
	print("RESULT %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _test_files(directory: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(directory.path_join(file))
	files.sort()
	return files
