extends "res://tests/test_case.gd"
## Project-level mobile configuration.


func test_main_scene_is_game() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://game/main.tscn", "main scene is game/main.tscn")


func test_mobile_renderer() -> void:
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "desktop renderer is mobile")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "mobile", "mobile renderer is mobile")


func test_landscape_layout() -> void:
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "sensor landscape orientation")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "canvas_items stretch")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "expand aspect fills any phone ratio")


func test_physics_interpolation_enabled() -> void:
	check(ProjectSettings.get_setting("physics/common/physics_interpolation") == true, "physics interpolation on")


func test_mouse_emulates_touch_for_desktop_testing() -> void:
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse") == true, "mouse emulates touch")


func test_no_packed_string_array_exports() -> void:
	# Godot 4.7.2's export conversion of text resources dropped an exported
	# PackedStringArray (MapDefinition.debug_viewpoint_names, found on device).
	# Exported builds would silently lose such data; use Array[String].
	for directory in ["res://game", "res://maps"]:
		for path in _scripts_under(directory):
			var script := load(path) as Script
			for property in script.get_script_property_list():
				var exported: bool = property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
				check(not (exported and property.type == TYPE_PACKED_STRING_ARRAY), "%s: %s is an exported PackedStringArray" % [path, property.name])


func _scripts_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			found.append(directory.path_join(file))
	for sub in DirAccess.get_directories_at(directory):
		found.append_array(_scripts_under(directory.path_join(sub)))
	return found


func test_input_actions() -> void:
	var expected := {
		&"move_forward": KEY_W,
		&"move_back": KEY_S,
		&"move_left": KEY_A,
		&"move_right": KEY_D,
		&"run": KEY_SHIFT,
	}
	for action: StringName in expected:
		check(InputMap.has_action(action), "action exists: %s" % action)
		var key := InputEventKey.new()
		key.physical_keycode = expected[action]
		key.pressed = true
		check(InputMap.event_is_action(key, action), "%s bound to %s" % [action, OS.get_keycode_string(expected[action])])
