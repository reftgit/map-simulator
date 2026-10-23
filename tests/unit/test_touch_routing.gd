extends "res://tests/test_case.gd"
## Multi-touch behavior of the HUD: native joystick, camera look area, run button.
## Events go through Input.parse_input_event, like device touches.

var hud: UIController
var input: MobileInputController


func _setup() -> void:
	hud = instantiate("res://game/ui/hud.tscn")
	input = hud.input
	await process_frames(2)


func _joystick_point() -> Vector2:
	var rect := input.joystick.get_global_rect()
	return rect.position + rect.size * Vector2(0.4, 0.6)


func _look_point() -> Vector2:
	var rect := input.look_area.get_global_rect()
	return rect.position + rect.size * Vector2(0.4, 0.3)


func _run_point() -> Vector2:
	return input.run_button.get_global_rect().get_center()


func test_layout_splits_screen() -> void:
	await _setup()
	var view := hud.get_viewport().get_visible_rect()
	check(input.joystick.get_global_rect().get_center().x < view.size.x * 0.5, "joystick zone is on the left")
	check(input.look_area.get_global_rect().get_center().x > view.size.x * 0.5, "look area is on the right")
	check(input.run_button.get_global_rect().get_center().x > view.size.x * 0.5, "run button is on the right")
	check(not input.joystick.get_global_rect().intersects(input.look_area.get_global_rect()), "joystick and look zones do not overlap")
	check(input.run_button.size.x >= 110.0, "run button is at least 110 canvas units wide")


func test_joystick_drives_move_vector() -> void:
	await _setup()
	var start := _joystick_point()
	var radius := input.joystick.joystick_size * 0.5
	touch(0, start, true)
	drag(0, start, start + Vector2(radius * 0.5, 0))
	await process_frames(1)
	# Half deflection is 0.5 raw; the 0.2 action dead zone rescales it to 0.375.
	check_near(input.get_move_vector().x, 0.375, 0.02, "half deflection right")
	drag(0, start + Vector2(radius * 0.5, 0), start + Vector2(0, -radius * 2.0))
	await process_frames(1)
	check_near(input.get_move_vector().y, -1.0, 0.02, "full deflection up is forward")
	touch(0, start + Vector2(0, -radius * 2.0), false)
	await process_frames(1)
	check(input.get_move_vector() == Vector2.ZERO, "release recenters the stick")


func test_look_drag_turns_camera_input() -> void:
	await _setup()
	var start := _look_point()
	touch(0, start, true)
	drag(0, start, start + Vector2(90, -45))
	var delta := input.consume_look_delta()
	var height := hud.get_viewport().get_visible_rect().size.y
	check_near(delta.x, 90.0 / height * input.look_sensitivity, 0.001, "horizontal drag becomes yaw")
	check_near(delta.y, -45.0 / height * input.look_sensitivity, 0.001, "vertical drag becomes pitch")
	check(input.consume_look_delta() == Vector2.ZERO, "look delta is consumed once")
	check(input.get_move_vector() == Vector2.ZERO, "look drag does not move the character")


func test_joystick_and_look_work_simultaneously() -> void:
	await _setup()
	var stick := _joystick_point()
	var look := _look_point()
	touch(0, stick, true)
	touch(1, look, true)
	drag(0, stick, stick + Vector2(0, -200))
	drag(1, look, look + Vector2(120, 0))
	await process_frames(1)
	check(input.get_move_vector().y < -0.9, "finger 0 moves forward")
	check(input.consume_look_delta().x > 0.0, "finger 1 turns the camera")
	touch(1, look + Vector2(120, 0), false)
	drag(0, stick + Vector2(0, -200), stick + Vector2(0, -210))
	await process_frames(1)
	check(input.get_move_vector().y < -0.9, "joystick keeps working after the look finger lifts")


func test_run_button_toggles_without_turning_camera() -> void:
	await _setup()
	var button := _run_point()
	touch(0, button, true)
	drag(0, button, button + Vector2(-100, -60))
	touch(0, button + Vector2(-100, -60), false)
	check(input.is_run_active(), "tap toggles running on")
	check(input.consume_look_delta() == Vector2.ZERO, "dragging from the button does not turn the camera")
	touch(0, button, true)
	touch(0, button, false)
	check(not input.is_run_active(), "second tap toggles running off")


func test_look_drag_over_button_stays_look() -> void:
	await _setup()
	var start := _look_point()
	var over_button := _run_point()
	touch(0, start, true)
	drag(0, start, over_button)
	touch(0, over_button, false)
	check(not input.is_run_active(), "a look drag that ends on the button does not press it")
	check(input.consume_look_delta() != Vector2.ZERO, "the drag still turns the camera")


func test_second_finger_in_look_area_is_ignored() -> void:
	await _setup()
	var look := _look_point()
	touch(0, look, true)
	touch(1, look + Vector2(200, 100), true)
	drag(1, look + Vector2(200, 100), look + Vector2(400, 100))
	check(input.consume_look_delta() == Vector2.ZERO, "only the first look finger counts")
	drag(0, look, look + Vector2(30, 0))
	check(input.consume_look_delta().x > 0.0, "first look finger still works")


func test_run_resets_when_joystick_released() -> void:
	await _setup()
	var button := _run_point()
	touch(1, button, true)
	touch(1, button, false)
	var stick := _joystick_point()
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -150))
	await process_frames(1)
	check(input.is_run_active(), "running while the stick is held")
	touch(0, stick + Vector2(0, -150), false)
	await process_frames(1)
	check(not input.is_run_active(), "running stops when the stick finger lifts")


func test_release_all_touches_clears_state() -> void:
	await _setup()
	var look := _look_point()
	touch(0, look, true)
	drag(0, look, look + Vector2(50, 0))
	input.release_all_touches()
	check(input.consume_look_delta() == Vector2.ZERO, "pending look input is dropped")
	drag(0, look + Vector2(50, 0), look + Vector2(100, 0))
	check(input.consume_look_delta() == Vector2.ZERO, "the dropped finger no longer turns the camera")
