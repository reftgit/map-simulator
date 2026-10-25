extends "res://tests/test_case.gd"
## Multi-touch behavior of the HUD: native joystick, camera look area, run,
## punch, and roll buttons. Events go through Input.parse_input_event, like
## device touches.

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


func _punch_point() -> Vector2:
	return input.punch_button.get_global_rect().get_center()


func _roll_point() -> Vector2:
	return input.roll_button.get_global_rect().get_center()


func _key(keycode: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	send_input(event)


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


func test_debug_view_button_is_routed_before_joystick_zone() -> void:
	await _setup()
	var button: TouchButton = hud.get_node("SafeArea/Controls/DebugViewButton")
	check(button.visible == OS.is_debug_build(), "VIEW button only in debug builds")
	check(input.joystick.get_global_rect().encloses(button.get_global_rect()), "button sits inside the joystick zone (worst case for routing)")
	var requests := [0]
	hud.debug_view_requested.connect(func() -> void: requests[0] += 1)
	var center := button.get_global_rect().get_center()
	touch(0, center, true)
	drag(0, center, center + Vector2(80, 0))
	await process_frames(1)
	check(requests[0] == 1, "tap requests the next view")
	check(input.get_move_vector() == Vector2.ZERO, "the joystick does not get the button's finger")
	touch(0, center + Vector2(80, 0), false)


## Joystick held forward with running on, then the app loses focus or pauses.
func _check_reset_on_notification(what: int) -> void:
	await _setup()
	var button := _run_point()
	touch(1, button, true)
	touch(1, button, false)
	var stick := _joystick_point()
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -200))
	touch(2, _punch_point(), true)
	touch(3, _roll_point(), true)
	touch(3, _roll_point(), false)
	await process_frames(1)
	check(input.get_move_vector().y < -0.9 and input.is_run_active(), "running forward before the notification")
	check(input.punch_button.is_down, "punch button held before the notification")
	tree.root.propagate_notification(what)
	await process_frames(1)
	check(input.get_move_vector() == Vector2.ZERO, "movement stops")
	for action in MobileInputController.ACTIONS:
		check(not Input.is_action_pressed(action), "%s released" % action)
	check(not input.is_run_active(), "run toggle off")
	check(not input.punch_button.is_down and not input.roll_button.is_down, "no action button stays down")
	check(not input.consume_action_press(&"punch") and not input.consume_action_press(&"roll"), "pending punch and roll presses are dropped")
	touch(2, _punch_point(), false)
	check(not input.consume_action_press(&"punch"), "lifting the old punch finger after resume does nothing")
	# The old finger may still report drags after resume; it must not move the character.
	drag(0, stick + Vector2(0, -200), stick + Vector2(0, -230))
	await process_frames(1)
	check(input.get_move_vector() == Vector2.ZERO, "stale finger is ignored after resume")
	touch(0, stick + Vector2(0, -230), false)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(200, 0))
	await process_frames(1)
	check(input.get_move_vector().x > 0.9, "a new touch drives the joystick again")


func test_focus_out_releases_held_joystick_and_run() -> void:
	await _check_reset_on_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)


func test_pause_releases_held_joystick_and_run() -> void:
	await _check_reset_on_notification(Node.NOTIFICATION_APPLICATION_PAUSED)


func test_release_all_touches_clears_state() -> void:
	await _setup()
	var look := _look_point()
	touch(0, look, true)
	drag(0, look, look + Vector2(50, 0))
	input.release_all_touches()
	check(input.consume_look_delta() == Vector2.ZERO, "pending look input is dropped")
	drag(0, look + Vector2(50, 0), look + Vector2(100, 0))
	check(input.consume_look_delta() == Vector2.ZERO, "the dropped finger no longer turns the camera")


func test_action_buttons_layout() -> void:
	await _setup()
	var view := hud.get_viewport().get_visible_rect()
	var safe: Rect2 = hud.get_node("SafeArea").get_global_rect()
	var buttons: Array[TouchButton] = [input.run_button, input.punch_button, input.roll_button]
	for button in buttons:
		var rect := button.get_global_rect()
		check(rect.get_center().x > view.size.x * 0.5, "%s is on the right" % button.name)
		check(safe.encloses(rect), "%s is inside the safe area" % button.name)
		check(button.size.x >= 110.0, "%s is at least 110 canvas units wide" % button.name)
		check(input.look_area.get_global_rect().encloses(rect), "%s sits over the look area, not the joystick zone" % button.name)
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a := buttons[i]
			var b := buttons[j]
			var reach := (a.size.x * 0.5 * a.hit_scale) + (b.size.x * 0.5 * b.hit_scale)
			var gap := a.get_global_rect().get_center().distance_to(b.get_global_rect().get_center()) - reach
			check(gap > 0.0, "%s and %s hit areas do not overlap (gap %.0f)" % [a.name, b.name, gap])
	check(input.punch_button.icon != null and input.roll_button.icon != null, "action buttons have icons")


func test_action_buttons_fire_once_on_touch_down() -> void:
	await _setup()
	var punch := _punch_point()
	touch(0, punch, true)
	check(input.consume_action_press(&"punch"), "touch-down presses punch")
	check(not input.consume_action_press(&"punch"), "a press is consumed once")
	drag(0, punch, punch + Vector2(-140, -90))
	await process_frames(3)
	check(not input.consume_action_press(&"punch"), "holding and dragging does not repeat the press")
	check(input.consume_look_delta() == Vector2.ZERO, "dragging from the punch button does not turn the camera")
	touch(0, punch + Vector2(-140, -90), false)
	check(not input.consume_action_press(&"punch"), "lifting does not press again")
	var roll := _roll_point()
	touch(1, roll, true)
	drag(1, roll, roll + Vector2(-200, 50))
	touch(1, roll + Vector2(-200, 50), false)
	check(input.consume_action_press(&"roll"), "tap presses roll")
	check(not input.consume_action_press(&"punch"), "roll does not press punch")
	check(input.consume_look_delta() == Vector2.ZERO, "dragging from the roll button does not turn the camera")
	check(not input.is_run_active(), "action buttons do not touch the run toggle")


func test_joystick_look_and_action_buttons_together() -> void:
	await _setup()
	var stick := _joystick_point()
	var look := _look_point()
	touch(0, stick, true)
	touch(1, look, true)
	drag(0, stick, stick + Vector2(0, -200))
	touch(2, _punch_point(), true)
	drag(1, look, look + Vector2(80, 0))
	touch(3, _roll_point(), true)
	await process_frames(1)
	check(input.get_move_vector().y < -0.9, "joystick finger keeps moving forward")
	check(input.consume_look_delta().x > 0.0, "look finger keeps turning the camera")
	check(input.consume_action_press(&"punch") and input.consume_action_press(&"roll"), "both buttons pressed while stick and look are held")
	touch(2, _punch_point(), false)
	touch(3, _roll_point(), false)
	drag(1, look + Vector2(80, 0), look + Vector2(120, 0))
	drag(0, stick + Vector2(0, -200), stick + Vector2(0, -210))
	await process_frames(1)
	check(input.consume_look_delta().x > 0.0, "look still works after the button fingers lift")
	check(input.get_move_vector().y < -0.9, "joystick still works after the button fingers lift")


func test_look_drag_over_action_button_stays_look() -> void:
	await _setup()
	var start := _look_point()
	touch(0, start, true)
	drag(0, start, _punch_point())
	touch(0, _punch_point(), false)
	check(not input.consume_action_press(&"punch"), "a look drag that ends on the punch button does not press it")
	check(input.consume_look_delta() != Vector2.ZERO, "the drag still turns the camera")


func test_action_keys() -> void:
	await _setup()
	_key(KEY_J, true)
	_key(KEY_J, true, true)
	_key(KEY_J, false)
	check(input.consume_action_press(&"punch"), "J presses punch")
	check(not input.consume_action_press(&"punch"), "key repeat (echo) does not press again")
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	check(input.consume_action_press(&"roll"), "Space presses roll")
	check(not input.consume_action_press(&"punch"), "Space does not press punch")


func test_touch_input_fills_one_shot_intent() -> void:
	await _setup()
	var source := TouchPlayerInput.new()
	add_node(source)
	source.input = input
	var intent := PlayerIntent.new()
	touch(0, _roll_point(), true)
	source.fill_intent(intent, null)
	check(intent.roll and not intent.punch, "roll tap reaches the intent")
	intent.clear()
	source.fill_intent(intent, null)
	check(not intent.roll, "the same tap does not reach the next tick while the finger is held")
	touch(0, _roll_point(), false)


func test_debug_dummy_button_requests_the_dummy() -> void:
	await _setup()
	var button: TouchButton = hud.get_node("SafeArea/Controls/DebugDummyButton")
	check(button.visible == OS.is_debug_build(), "DUMMY button only in debug builds")
	var requests := [0]
	hud.debug_dummy_requested.connect(func() -> void: requests[0] += 1)
	var center := button.get_global_rect().get_center()
	touch(0, center, true)
	drag(0, center, center + Vector2(60, 0))
	touch(0, center + Vector2(60, 0), false)
	await process_frames(1)
	check(requests[0] == 1, "tap requests the dummy toggle once")
	check(input.get_move_vector() == Vector2.ZERO, "the joystick does not get the button's finger")


func test_vehicle_controls_layout_and_group_switch() -> void:
	await _setup()
	check(input.on_foot_controls.visible and not input.vehicle_controls.visible, "on foot by default")
	check(not input.interact_button.visible, "interact hidden until a vehicle is in reach")
	input.set_vehicle_mode(true)
	await process_frames(1)
	check(not input.on_foot_controls.visible and input.vehicle_controls.visible, "vehicle mode swaps the groups")
	var view := hud.get_viewport().get_visible_rect()
	var safe: Rect2 = hud.get_node("SafeArea").get_global_rect()
	var buttons: Array[TouchButton] = [input.steer_left_button, input.steer_right_button, input.throttle_button, input.brake_button, input.handbrake_button, input.exit_button]
	for button in buttons:
		check(button.is_visible_in_tree(), "%s visible" % button.name)
		check(safe.encloses(button.get_global_rect()), "%s inside the safe area" % button.name)
		check(button.size.x >= 110.0, "%s at least 110 units" % button.name)
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a := buttons[i]
			var b := buttons[j]
			var gap := a.get_global_rect().get_center().distance_to(b.get_global_rect().get_center()) - a.size.x * 0.5 * a.hit_scale - b.size.x * 0.5 * b.hit_scale
			check(gap > 0.0, "%s and %s hit areas do not overlap (gap %.0f)" % [a.name, b.name, gap])
	check(input.steer_left_button.get_global_rect().get_center().x < view.size.x * 0.5 and input.steer_right_button.get_global_rect().get_center().x < view.size.x * 0.5, "steering on the left")
	for button in [input.throttle_button, input.brake_button, input.handbrake_button, input.exit_button]:
		check(button.get_global_rect().get_center().x > view.size.x * 0.5, "%s on the right" % button.name)
	# Hidden on-foot buttons never take a finger.
	var punch := input.punch_button.get_global_rect().get_center()
	touch(0, punch, true)
	touch(0, punch, false)
	check(not input.consume_action_press(&"punch"), "hidden punch button ignored in vehicle mode")
	var stick := input.joystick.get_global_rect().position + input.joystick.get_global_rect().size * Vector2(0.6, 0.3)
	touch(1, stick, true)
	drag(1, stick, stick + Vector2(0, -200))
	await process_frames(1)
	check(input.get_move_vector() == Vector2.ZERO, "hidden joystick does not move")
	touch(1, stick + Vector2(0, -200), false)
	# Held vehicle button, then back on foot: nothing stays down.
	touch(2, input.throttle_button.get_global_rect().get_center(), true)
	check(input.get_vehicle_throttle() == 1.0, "throttle button held")
	drag(2, input.throttle_button.get_global_rect().get_center(), input.throttle_button.get_global_rect().get_center() + Vector2(-200, -100))
	check(input.consume_look_delta() == Vector2.ZERO, "a drag from a vehicle button does not turn the camera")
	input.set_vehicle_mode(false)
	await process_frames(1)
	check(input.on_foot_controls.visible and not input.vehicle_controls.visible, "back on foot")
	check(input.get_vehicle_throttle() == 0.0 and not input.throttle_button.is_down, "switching groups releases held vehicle buttons")


func test_vehicle_keys_and_steer_buttons() -> void:
	await _setup()
	input.set_vehicle_mode(true)
	await process_frames(1)
	_key(KEY_A, true)
	check(input.get_vehicle_steer() == -1.0, "A steers left")
	_key(KEY_A, false)
	touch(0, input.steer_right_button.get_global_rect().get_center(), true)
	check(input.get_vehicle_steer() == 1.0, "right button steers right")
	touch(1, input.steer_left_button.get_global_rect().get_center(), true)
	check(input.get_vehicle_steer() == 0.0, "both steering buttons cancel out")
	touch(0, input.steer_right_button.get_global_rect().get_center(), false)
	touch(1, input.steer_left_button.get_global_rect().get_center(), false)
	_key(KEY_S, true)
	check(input.get_vehicle_brake() == 1.0, "S brakes")
	_key(KEY_S, false)
	_key(KEY_SPACE, true)
	check(input.is_vehicle_handbrake_held() and not input.consume_action_press(&"roll"), "Space is the handbrake, not a roll, while driving")
	_key(KEY_SPACE, false)
