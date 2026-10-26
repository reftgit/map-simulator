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
		&"punch": KEY_J,
		&"roll": KEY_SPACE,
		&"interact": KEY_E,
		&"vehicle_throttle": KEY_W,
		&"vehicle_brake": KEY_S,
		&"vehicle_left": KEY_A,
		&"vehicle_right": KEY_D,
		&"vehicle_handbrake": KEY_SPACE,
	}
	for action: StringName in expected:
		check(InputMap.has_action(action), "action exists: %s" % action)
		var key := InputEventKey.new()
		key.physical_keycode = expected[action]
		key.pressed = true
		check(InputMap.event_is_action(key, action), "%s bound to %s" % [action, OS.get_keycode_string(expected[action])])


func test_active_physics_engine_is_detected() -> void:
	# Godot 4.7.2 maps the "DEFAULT" setting to GodotPhysics3D; the engine is
	# identified by the class of the world's direct space state (open question 8).
	# Switching engines is a user decision: update this test with it.
	var game_script: GDScript = load("res://game/game.gd")
	var space_state := tree.root.get_world_3d().direct_space_state
	check(ProjectSettings.get_setting("physics/3d/physics_engine") == "DEFAULT", "engine setting left at DEFAULT")
	check(space_state.get_class() == "GodotPhysicsDirectSpaceState3D", "direct space state class (%s)" % space_state.get_class())
	check(game_script.physics_engine_name(space_state) == "GodotPhysics3D", "active engine is GodotPhysics3D (%s)" % game_script.physics_engine_name(space_state))


func test_measurement_overrides_do_not_touch_defaults() -> void:
	# Feature-tagged overrides apply only in the perf presets that carry the tag.
	check(not OS.has_feature("perf_jolt") and not OS.has_feature("perf_60hz"), "no measurement feature tag in normal runs")
	check(ProjectSettings.get_setting("display/window/ios/allow_high_refresh_rate") == true, "high refresh rate allowed by default")
	check(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 60, "60 Hz physics")
	var text := FileAccess.get_file_as_string("res://project.godot")
	check(text.contains('3d/physics_engine.perf_jolt="Jolt Physics"'), "Jolt only behind the perf_jolt tag")
	check(text.contains("window/ios/allow_high_refresh_rate.perf_60hz=false"), "60 Hz only behind the perf_60hz tag")
