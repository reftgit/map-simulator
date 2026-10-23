extends "res://tests/test_case.gd"
## Camera-relative conversion of the screen-space stick.


func _is(actual: Vector3, expected: Vector3, message: String) -> void:
	check(actual.distance_to(expected) < 0.0001, "%s (got %s, expected %s)" % [message, actual, expected])


func test_stick_up_moves_away_from_camera() -> void:
	_is(TouchPlayerInput.camera_relative(Vector2(0, -1), 0.0), Vector3(0, 0, -1), "yaw 0: up is -Z")
	_is(TouchPlayerInput.camera_relative(Vector2(0, -1), PI * 0.5), Vector3(-1, 0, 0), "camera turned left: up is -X")
	_is(TouchPlayerInput.camera_relative(Vector2(0, -1), PI), Vector3(0, 0, 1), "camera turned around: up is +Z")


func test_stick_right_strafes_right_of_camera() -> void:
	_is(TouchPlayerInput.camera_relative(Vector2(1, 0), 0.0), Vector3(1, 0, 0), "yaw 0: right is +X")
	_is(TouchPlayerInput.camera_relative(Vector2(1, 0), PI * 0.5), Vector3(0, 0, -1), "camera turned left: right is -Z")


func test_magnitude_is_kept_and_limited() -> void:
	check_near(TouchPlayerInput.camera_relative(Vector2(0.3, -0.4), 1.0).length(), 0.5, 0.0001, "partial tilt keeps its length")
	check_near(TouchPlayerInput.camera_relative(Vector2(1, -1), 0.3).length(), 1.0, 0.0001, "diagonal is limited to 1")
	check(TouchPlayerInput.camera_relative(Vector2.ZERO, 2.0) == Vector3.ZERO, "no stick, no movement")
