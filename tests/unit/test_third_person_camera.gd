extends "res://tests/test_case.gd"
## ThirdPersonCamera orbit, limits, following, and wall collision.

var rig: ThirdPersonCamera
var target: Node3D


func _setup() -> void:
	target = add_node(Node3D.new())
	rig = instantiate("res://game/camera/third_person_camera.tscn")
	rig.set_target(target)
	await physics_frames(3)


func test_starts_behind_target_at_profile_distance() -> void:
	await _setup()
	await physics_frames(5)
	check_near(rig.get_arm_length(), rig.profile.distance, 0.05, "full arm length in open space")
	var offset := rig.camera.global_position - target.global_position
	check(offset.z > 3.0, "camera is behind the target (+Z) when both face north")
	check(offset.y > rig.profile.pivot_height, "default pitch looks down from above the pivot")


func test_look_rotates_yaw_and_clamps_pitch() -> void:
	await _setup()
	rig.add_look(Vector2(0.5, 0))
	check_near(rig.yaw, -0.5, 0.0001, "dragging right turns the view right (negative yaw)")
	rig.add_look(Vector2(0, -10))
	check_near(rad_to_deg(rig.pitch), rig.profile.max_pitch_degrees, 0.001, "pitch up is clamped")
	rig.add_look(Vector2(0, 10))
	check_near(rad_to_deg(rig.pitch), rig.profile.min_pitch_degrees, 0.001, "pitch down is clamped")


func test_follows_target() -> void:
	await _setup()
	target.global_position = Vector3(10, 0, -4)
	await process_frames(30)
	var pivot := rig.global_position
	check_near(pivot.x, 10.0, 0.01, "pivot follows target x")
	check_near(pivot.z, -4.0, 0.01, "pivot follows target z")
	check_near(pivot.y, rig.profile.pivot_height, 0.05, "pivot height above target")


func test_spring_arm_keeps_camera_in_front_of_wall() -> void:
	await _setup()
	# Wall 2 m behind the target, between the pivot and the 4.5 m camera spot.
	add_static_box(Vector3(10, 10, 0.4), Vector3(0, 1.5, 2.0))
	await physics_frames(5)
	check(rig.get_arm_length() < 2.0, "arm shortened by the wall (length %.2f)" % rig.get_arm_length())
	check(rig.camera.global_position.z < 1.8, "camera stays on the target side of the wall (z %.2f)" % rig.camera.global_position.z)


func test_spring_arm_ignores_the_followed_body() -> void:
	add_static_box()
	var player: PlayerController = instantiate("res://game/player/player.tscn")
	rig = instantiate("res://game/camera/third_person_camera.tscn")
	rig.set_target(player)
	await physics_frames(5)
	check_near(rig.get_arm_length(), rig.profile.distance, 0.05, "player capsule does not shorten the arm")


func test_profile_swap_changes_framing() -> void:
	await _setup()
	var far := CameraProfile.new()
	far.distance = 8.0
	far.default_pitch_degrees = -25.0
	rig.set_target(target, far)
	await physics_frames(5)
	check_near(rig.get_arm_length(), 8.0, 0.05, "new profile distance")
	check_near(rad_to_deg(rig.pitch), -25.0, 0.001, "new profile pitch")
