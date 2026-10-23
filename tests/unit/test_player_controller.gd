extends "res://tests/test_case.gd"
## PlayerController and its state machine on a flat floor, driven by a scripted
## input source instead of touch.


class ScriptedInput extends PlayerInputSource:
	var move := Vector3.ZERO
	var run := false

	func fill_intent(intent: PlayerIntent, _player: PlayerController) -> void:
		intent.move = move
		intent.run = run


var player: PlayerController
var source: ScriptedInput


func _setup() -> void:
	add_static_box()
	player = instantiate("res://game/player/player.tscn")
	source = ScriptedInput.new()
	add_node(source)
	player.input_source = source
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	await physics_frames(10)


func test_starts_idle_on_floor() -> void:
	await _setup()
	check(player.state_machine.get_state_name() == &"Idle", "starts idle")
	check(player.is_on_floor(), "settles on the floor")
	check_near(player.global_position.y, 0.0, 0.05, "capsule bottom rests on the floor")


func test_walk_reaches_walk_speed() -> void:
	await _setup()
	source.move = Vector3(0, 0, -1)
	await physics_frames(60)
	check(player.state_machine.get_state_name() == &"Walk", "full stick without run walks")
	check_near(player.get_horizontal_speed(), player.walk_speed, 0.05, "walk speed")
	check(player.global_position.z < -3.0, "moved forward (-Z)")
	check(player.is_on_floor(), "stays on the floor")


func test_half_stick_walks_at_half_speed() -> void:
	await _setup()
	source.move = Vector3(0.5, 0, 0)
	await physics_frames(60)
	check_near(player.get_horizontal_speed(), player.walk_speed * 0.5, 0.05, "analog walk speed")


func test_run_reaches_run_speed() -> void:
	await _setup()
	source.move = Vector3(0, 0, -0.6)
	source.run = true
	await physics_frames(60)
	check(player.state_machine.get_state_name() == &"Run", "run intent runs")
	check_near(player.get_horizontal_speed(), player.run_speed, 0.05, "run ignores stick tilt")


func test_release_stops_and_returns_to_idle() -> void:
	await _setup()
	source.move = Vector3(0, 0, -1)
	source.run = true
	await physics_frames(45)
	source.move = Vector3.ZERO
	source.run = false
	await physics_frames(30)
	check(player.state_machine.get_state_name() == &"Idle", "no stick returns to idle")
	check_near(player.get_horizontal_speed(), 0.0, 0.01, "comes to a stop")


func test_state_sequence_is_reported() -> void:
	await _setup()
	var seen: Array[StringName] = []
	player.state_machine.state_changed.connect(func(_previous: StringName, current: StringName) -> void: seen.append(current))
	source.move = Vector3(0, 0, -1)
	await physics_frames(5)
	source.run = true
	await physics_frames(5)
	source.run = false
	source.move = Vector3.ZERO
	await physics_frames(5)
	check(seen == ([&"Walk", &"Run", &"Idle"] as Array[StringName]), "Idle -> Walk -> Run -> Idle (got %s)" % [seen])


func test_turns_to_face_movement() -> void:
	await _setup()
	source.move = Vector3(1, 0, 0)
	await physics_frames(60)
	var forward := -player.global_basis.z
	check(forward.dot(Vector3.RIGHT) > 0.99, "faces +X after moving +X (forward %s)" % forward)


func test_teleport_resets_motion() -> void:
	await _setup()
	source.move = Vector3(0, 0, -1)
	await physics_frames(30)
	source.move = Vector3.ZERO
	player.teleport(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5, 0.1, 5)))
	check(player.velocity == Vector3.ZERO, "velocity cleared")
	check(player.state_machine.get_state_name() == &"Idle", "state reset to idle")
	check_near(player.rotation.y, PI * 0.5, 0.001, "spawn facing applied")
	check(player.global_position.distance_to(Vector3(5, 0.1, 5)) < 0.001, "moved to target")


func test_slides_along_wall_instead_of_passing_through() -> void:
	await _setup()
	add_static_box(Vector3(20, 4, 1), Vector3(0, 2, -3))
	source.move = Vector3(0, 0, -1)
	await physics_frames(90)
	check(player.global_position.z > -2.7, "wall stops the player (z = %.2f)" % player.global_position.z)
