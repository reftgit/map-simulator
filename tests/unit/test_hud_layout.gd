extends "res://tests/test_case.gd"
## HUD layout over a matrix of screens and safe areas (window pixels, as the
## platform would report them), for the on-foot and the vehicle control group
## with the debug overlay shown: every control inside the safe area, hit areas
## apart, the joystick and the camera drag area clear of buttons, the debug
## overlay clear of controls, and touch targets at least MIN_TARGET_MM wide on
## the device. Insets of the Android phones are assumed typical values.

## Apple's 44 pt minimum is ~7 mm on an iPhone.
const MIN_TARGET_MM := 7.0
const SCREENS := {
	"16x9": {"window": Vector2i(1920, 1080), "safe": Rect2i(0, 0, 1920, 1080), "ppi": 401.0,
			"about": "16:9 phone, 5.5\", no cutout"},
	"iphone_notch_left": {"window": Vector2i(2532, 1170), "safe": Rect2i(141, 0, 2250, 1107), "ppi": 460.0,
			"about": "19.5:9 iPhone 13 Pro, notch on the left (iOS insets 47 pt both sides, 21 pt home indicator)"},
	"iphone_notch_right": {"window": Vector2i(2532, 1170), "safe": Rect2i(141, 0, 2250, 1107), "ppi": 460.0,
			"about": "19.5:9 iPhone 13 Pro, notch on the right (iOS reports the same symmetric insets)"},
	"20x9_hole_left_buttons_right": {"window": Vector2i(2400, 1080), "safe": Rect2i(110, 0, 2164, 1080), "ppi": 411.0,
			"about": "20:9 Android, punch-hole left (110 px), 3-button navigation bar right (126 px)"},
	"20x9_hole_right_buttons_left": {"window": Vector2i(2400, 1080), "safe": Rect2i(126, 0, 2164, 1080), "ppi": 411.0,
			"about": "20:9 Android, punch-hole right, 3-button navigation bar left"},
	"20x9_hole_left_gesture": {"window": Vector2i(2400, 1080), "safe": Rect2i(110, 0, 2290, 1017), "ppi": 411.0,
			"about": "20:9 Android, punch-hole left, gesture navigation handle at the bottom (63 px)"},
	"20x9_hole_right_gesture": {"window": Vector2i(2400, 1080), "safe": Rect2i(0, 0, 2290, 1017), "ppi": 411.0,
			"about": "20:9 Android, punch-hole right, gesture navigation handle at the bottom"},
	"4x3_ipad": {"window": Vector2i(2048, 1536), "safe": Rect2i(0, 48, 2048, 1448), "ppi": 264.0,
			"about": "4:3 iPad 9.7\", status bar 24 pt, home indicator 20 pt"},
	"16x10_tab_a7": {"window": Vector2i(2000, 1200), "safe": Rect2i(0, 0, 2000, 1200), "ppi": 224.0,
			"about": "16:10 Galaxy Tab A7 10.4\", immersive mode, no cutout"},
}

var hud: UIController
var input: MobileInputController


func cleanup() -> void:
	tree.root.size = Vector2i(1440, 900)
	BuildFeatures.reset_overrides()
	await super()


func test_16x9() -> void:
	await _check_screen("16x9")


func test_iphone_notch_left() -> void:
	await _check_screen("iphone_notch_left")


func test_iphone_notch_right() -> void:
	await _check_screen("iphone_notch_right")


func test_20x9_hole_left_buttons_right() -> void:
	await _check_screen("20x9_hole_left_buttons_right")


func test_20x9_hole_right_buttons_left() -> void:
	await _check_screen("20x9_hole_right_buttons_left")


func test_20x9_hole_left_gesture() -> void:
	await _check_screen("20x9_hole_left_gesture")


func test_20x9_hole_right_gesture() -> void:
	await _check_screen("20x9_hole_right_gesture")


func test_4x3_ipad() -> void:
	await _check_screen("4x3_ipad")


func test_16x10_tab_a7() -> void:
	await _check_screen("16x10_tab_a7")


func test_safe_area_change_without_resize_is_applied_and_releases_fingers() -> void:
	# A 180° turn moves a punch-hole and a navigation bar to the other side; the
	# window size stays the same, so only the periodic check notices.
	await _show("20x9_hole_left_buttons_right")
	var before := hud.safe_rect
	var stick := input.joystick.get_global_rect().position + input.joystick.get_global_rect().size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -80))
	touch(1, input.run_button.get_global_rect().get_center(), true)
	await process_frames(2)
	check(input.get_move_vector() != Vector2.ZERO, "joystick held before the turn")
	var turned: Dictionary = SCREENS["20x9_hole_right_buttons_left"]
	hud.safe_area_source = SafeAreaSource.fixed(turned.window, turned.safe)
	await _seconds(UIController.SAFE_AREA_CHECK_INTERVAL + 0.1)
	check(not hud.safe_rect.is_equal_approx(before), "safe area re-applied after the turn (%s -> %s)" % [before, hud.safe_rect])
	var expected := UIController.safe_rect_in_viewport(turned.safe, turned.window, _viewport_size())
	check(hud.safe_rect.is_equal_approx(expected), "the new safe area (%s, expected %s)" % [hud.safe_rect, expected])
	check(input.get_move_vector() == Vector2.ZERO, "the held joystick was released")
	check(not input.run_button.is_down, "the held button was released")
	touch(0, stick + Vector2(0, -80), false)
	touch(1, input.run_button.get_global_rect().get_center(), false)


## Lays the HUD out on `screen` (debug overlay on) and checks both groups.
func _check_screen(screen_name: String) -> void:
	await _show(screen_name)
	var screen: Dictionary = SCREENS[screen_name]
	var safe := UIController.safe_rect_in_viewport(screen.safe, screen.window, _viewport_size())
	check(hud.safe_rect.is_equal_approx(safe), "%s: HUD uses the platform safe area (%s, expected %s)" % [screen_name, hud.safe_rect, safe])
	for vehicle in [false, true]:
		input.set_vehicle_mode(vehicle)
		input.set_interact_available(not vehicle)
		await process_frames(2)
		_check_group(screen_name, "vehicle" if vehicle else "on foot", safe, screen.ppi)


func _show(screen_name: String) -> void:
	var screen: Dictionary = SCREENS[screen_name]
	BuildFeatures.debug_override = 1
	tree.root.size = screen.window
	hud = instantiate("res://game/ui/hud.tscn")
	input = hud.input
	hud.safe_area_source = SafeAreaSource.fixed(screen.window, screen.safe)
	hud.apply_safe_area()
	await process_frames(2)


func _check_group(screen_name: String, group: String, safe: Rect2, ppi: float) -> void:
	var tag := "%s, %s" % [screen_name, group]
	var buttons: Array[TouchButton] = []
	for control in [input.run_button, input.punch_button, input.roll_button, input.interact_button,
			input.steer_left_button, input.steer_right_button, input.throttle_button, input.brake_button,
			input.handbrake_button, input.exit_button]:
		if control.is_visible_in_tree():
			buttons.append(control)
	for control in input.extra_controls:
		if control is TouchButton and control.is_visible_in_tree():
			buttons.append(control)
	check(buttons.size() >= 8, "%s: buttons shown (%d)" % [tag, buttons.size()])
	var circles := {}
	for button in buttons:
		circles[button.name] = _hit_circle(button)
	# Inside the platform safe area.
	for button in buttons:
		check(safe.encloses(button.get_global_rect()), "%s: %s inside the safe area (%s in %s)" % [tag, button.name, button.get_global_rect(), safe])
	# Hit areas apart; the smallest gaps are reported for gameplay buttons and
	# for pairs with a debug button.
	var smallest_gap := {"gameplay": INF, "debug": INF}
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a: Vector3 = circles[buttons[i].name]
			var b: Vector3 = circles[buttons[j].name]
			var gap := Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) - a.z - b.z
			check(gap > 0.0, "%s: %s and %s hit areas apart (gap %.0f)" % [tag, buttons[i].name, buttons[j].name, gap])
			var kind := "debug" if buttons[i] in input.extra_controls or buttons[j] in input.extra_controls else "gameplay"
			smallest_gap[kind] = minf(smallest_gap[kind], gap)
	# Touch target size on the device.
	var px_per_unit := tree.root.get_final_transform().x.x
	var smallest_mm := {"gameplay": INF, "debug": INF}
	for button in buttons:
		var mm := (circles[button.name] as Vector3).z * 2.0 * px_per_unit / ppi * 25.4
		check(mm >= MIN_TARGET_MM, "%s: %s target %.1f mm >= %.1f mm" % [tag, button.name, mm, MIN_TARGET_MM])
		var kind := "debug" if button in input.extra_controls else "gameplay"
		smallest_mm[kind] = minf(smallest_mm[kind], mm)
	print("     layout %s: canvas %s, %.3f px/unit, %d buttons; smallest target %.1f mm gameplay / %.1f mm debug; smallest gap %.0f units gameplay / %.0f with debug" % [
			tag, _viewport_size().round(), px_per_unit, buttons.size(), smallest_mm.gameplay, smallest_mm.debug, smallest_gap.gameplay, smallest_gap.debug])
	# Camera drag area and joystick zone.
	var look := input.look_area.get_global_rect()
	var right_side: Array[TouchButton] = [input.run_button, input.punch_button, input.roll_button, input.interact_button,
			input.throttle_button, input.brake_button, input.handbrake_button, input.exit_button]
	for button in right_side:
		if button in buttons:
			var c: Vector3 = circles[button.name]
			check(c.x - c.z >= look.position.x, "%s: %s entirely over the camera drag area" % [tag, button.name])
	for button in [input.steer_left_button, input.steer_right_button]:
		if button in buttons:
			var c: Vector3 = circles[button.name]
			check(c.x + c.z <= look.position.x, "%s: %s entirely left of the camera drag area" % [tag, button.name])
	if input.joystick.is_visible_in_tree():
		var zone := input.joystick.get_global_rect()
		var stick := _joystick_circle()
		check(zone.end.x <= look.position.x + 0.5, "%s: joystick zone left of the camera drag area" % tag)
		check(safe.encloses(Rect2(Vector2(stick.x, stick.y) - Vector2.ONE * stick.z, Vector2.ONE * stick.z * 2.0)), "%s: joystick at rest inside the safe area" % tag)
		var stick_mm := stick.z * 2.0 * px_per_unit / ppi * 25.4
		check(stick_mm >= MIN_TARGET_MM, "%s: joystick %.1f mm" % [tag, stick_mm])
		for button in buttons:
			var c: Vector3 = circles[button.name]
			var gap := Vector2(stick.x, stick.y).distance_to(Vector2(c.x, c.y)) - stick.z - c.z
			check(gap > 0.0, "%s: joystick at rest clear of %s (gap %.0f)" % [tag, button.name, gap])
	# Debug overlay text clear of the controls.
	var label: Label = hud.get_node("SafeArea/DebugLabel")
	if label.is_visible_in_tree():
		var text_rect := label.get_global_rect()
		for button in buttons:
			var c: Vector3 = circles[button.name]
			var nearest := Vector2(clampf(c.x, text_rect.position.x, text_rect.end.x), clampf(c.y, text_rect.position.y, text_rect.end.y))
			check(nearest.distance_to(Vector2(c.x, c.y)) > c.z, "%s: debug overlay clear of %s" % [tag, button.name])


## Centre (x, y) and hit radius (z) in canvas units.
func _hit_circle(button: TouchButton) -> Vector3:
	var rect := button.get_global_rect()
	return Vector3(rect.get_center().x, rect.get_center().y, minf(rect.size.x, rect.size.y) * 0.5 * button.hit_scale)


## Centre (x, y) and base radius (z) of the joystick at rest, in canvas units.
func _joystick_circle() -> Vector3:
	var zone := input.joystick.get_global_rect()
	var center := zone.position + zone.size * input.joystick.initial_offset_ratio
	return Vector3(center.x, center.y, input.joystick.joystick_size * 0.5)


func _viewport_size() -> Vector2:
	return tree.root.get_visible_rect().size


func _seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await tree.process_frame
