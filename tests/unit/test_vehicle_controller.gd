extends "res://tests/test_case.gd"
## VehicleController on a flat floor, driven by a scripted input source: drive
## rules, steering, brakes, reverse, handbrake, focus loss, resets, exit
## points, the visual interface, and a second vehicle type.

const CAR := "res://game/vehicle/placeholder_car.tscn"
const VAN := "res://game/vehicle/placeholder_van.tscn"
const TICK := 1.0 / 60.0


class ScriptedVehicleInput extends VehicleInputSource:
	var steer := 0.0
	var throttle := 0.0
	var brake := 0.0
	var handbrake := false

	func fill_intent(intent: VehicleIntent, _vehicle: VehicleController) -> void:
		intent.steer = steer
		intent.throttle = throttle
		intent.brake = brake
		intent.handbrake = handbrake


class RecordingVehicleVisual extends VehicleVisual:
	var states := 0
	var braking_seen := false
	var reversing_seen := false
	var wheel_counts: Array[int] = []

	func set_drive_state(_speed: float, _steer: float, braking: bool, reversing: bool) -> void:
		states += 1
		braking_seen = braking_seen or braking
		reversing_seen = reversing_seen or reversing

	func set_wheel_transforms(transforms: Array[Transform3D]) -> void:
		wheel_counts.append(transforms.size())


var vehicle: VehicleController
var source: ScriptedVehicleInput


func _setup(scene := CAR, start := Transform3D.IDENTITY) -> void:
	add_static_box(Vector3(600, 1, 600))
	vehicle = instantiate(scene)
	vehicle.global_transform = start
	vehicle.spawn_transform = start
	source = ScriptedVehicleInput.new()
	add_node(source)
	vehicle.input_source = source
	await physics_frames(60)


func _definition() -> VehicleDefinition:
	return vehicle.definition


func _intent(throttle := 0.0, brake := 0.0, handbrake := false) -> VehicleIntent:
	var intent := VehicleIntent.new()
	intent.throttle = throttle
	intent.brake = brake
	intent.handbrake = handbrake
	return intent


func test_drive_command_rules() -> void:
	var def: VehicleDefinition = load("res://game/vehicle/definitions/compact_car.tres")
	var idle := VehicleController.drive_command(_intent(), 5.0, def)
	check(idle.engine == 0.0 and idle.brake == def.coast_brake and idle.handbrake == 0.0, "no pedal while rolling: coast brake only (%s)" % idle)
	var hold := VehicleController.drive_command(_intent(), def.hold_speed * 0.5, def)
	check(hold.engine == 0.0 and hold.brake == def.brake_force, "no pedal at (almost) standstill: brakes hold (%s)" % hold)
	var go := VehicleController.drive_command(_intent(1.0), 0.0, def)
	check(go.engine == def.engine_force and go.brake == 0.0, "throttle from standstill: full engine force (%s)" % go)
	var top := VehicleController.drive_command(_intent(1.0), def.max_speed, def)
	check(top.engine == 0.0, "no engine force at max speed (%s)" % top)
	check_near(VehicleController.drive_command(_intent(1.0), def.max_speed * 0.5, def).engine, def.engine_force * 0.5, 0.01, "engine force fades with speed")
	var rolling_back := VehicleController.drive_command(_intent(1.0), -3.0, def)
	check(rolling_back.engine == 0.0 and rolling_back.brake == def.brake_force, "throttle while rolling backwards brakes first (%s)" % rolling_back)
	var slow_down := VehicleController.drive_command(_intent(0.0, 1.0), 10.0, def)
	check(slow_down.engine == 0.0 and slow_down.brake == def.brake_force, "brake while moving forward brakes (%s)" % slow_down)
	var reverse := VehicleController.drive_command(_intent(0.0, 1.0), def.reverse_threshold * 0.5, def)
	check(reverse.engine < 0.0 and reverse.brake == 0.0, "brake below the reverse threshold reverses (%s)" % reverse)
	check(VehicleController.drive_command(_intent(0.0, 1.0), -def.max_reverse_speed, def).engine == 0.0, "no reverse force at max reverse speed")
	var both := VehicleController.drive_command(_intent(1.0, 1.0), 0.0, def)
	check(both.engine == 0.0 and both.brake == def.brake_force, "both pedals brake, no reverse (%s)" % both)
	var hand := VehicleController.drive_command(_intent(1.0, 0.0, true), 5.0, def)
	check(hand.engine == 0.0 and hand.handbrake == def.handbrake_force, "handbrake cuts the engine (%s)" % hand)


func test_steering_input_and_angle() -> void:
	var def: VehicleDefinition = load("res://game/vehicle/definitions/compact_car.tres")
	var steer := 0.0
	for i in 10:
		steer = VehicleController.approach_steer(steer, 1.0, TICK, def)
	check_near(steer, def.steer_rate * 10 * TICK, 0.0001, "steering builds up at steer_rate")
	for i in 600:
		steer = VehicleController.approach_steer(steer, 1.0, TICK, def)
	check(steer == 1.0, "steering saturates at full input")
	for i in 10:
		steer = VehicleController.approach_steer(steer, 0.0, TICK, def)
	check_near(steer, 1.0 - def.steer_return_rate * 10 * TICK, 0.0001, "released steering returns at steer_return_rate")
	check_near(rad_to_deg(VehicleController.steer_angle(1.0, 0.0, def)), def.max_steer_degrees, 0.001, "full angle at standstill")
	check_near(rad_to_deg(VehicleController.steer_angle(-1.0, def.max_speed, def)), -def.steer_at_max_speed_degrees, 0.001, "narrow angle at max speed, sign kept")


func test_parked_without_driver() -> void:
	await _setup()
	vehicle.input_source = null
	var start := vehicle.global_position
	await physics_frames(60)
	check(vehicle.global_position.distance_to(start) < 0.05, "no driver: stays put")
	for wheel in vehicle.wheels:
		if not wheel.use_as_steering:
			check(wheel.brake == _definition().handbrake_force, "rear wheels held by the handbrake")


func test_throttle_accelerates_forward_up_to_max_speed() -> void:
	await _setup()
	source.throttle = 1.0
	await physics_frames(180)
	var moved := vehicle.global_position
	check(vehicle.get_forward_speed() > 8.0, "3 s of throttle: faster than 8 m/s (%.2f)" % vehicle.get_forward_speed())
	check(moved.z > 10.0 and absf(moved.x) < 0.5, "drove forward along +Z (%s)" % moved)
	await physics_frames(600)
	check(vehicle.get_forward_speed() <= _definition().max_speed + 0.3, "never above max speed (%.2f)" % vehicle.get_forward_speed())
	check(vehicle.get_forward_speed() > _definition().max_speed - 2.0, "gets close to max speed (%.2f)" % vehicle.get_forward_speed())
	check(vehicle.global_basis.y.dot(Vector3.UP) > 0.99, "stays upright")
	source.steer = 1.0
	var lowest := 1.0
	for i in 180:
		await tree.physics_frame
		lowest = minf(lowest, vehicle.global_basis.y.dot(Vector3.UP))
	check(lowest > 0.9, "full steering at top speed for 3 s does not roll it over (lowest up %.3f)" % lowest)


func test_brake_slows_then_reverses() -> void:
	await _setup()
	source.throttle = 1.0
	await physics_frames(150)
	var fast := vehicle.get_forward_speed()
	source.throttle = 0.0
	source.brake = 1.0
	await physics_frames(30)
	check(vehicle.get_forward_speed() < fast - 2.0, "brake slows the vehicle (%.2f -> %.2f)" % [fast, vehicle.get_forward_speed()])
	check(not vehicle.reversing, "no reverse while still moving forward")
	var stopped_at := await _ticks_until(func() -> bool: return vehicle.get_forward_speed() < 0.0, 600)
	check(stopped_at >= 0, "comes to a stop and starts reversing (after %d ticks)" % stopped_at)
	await physics_frames(180)
	check(vehicle.reversing and vehicle.get_forward_speed() < -2.0, "holding the brake reverses (%.2f m/s)" % vehicle.get_forward_speed())
	check(vehicle.get_forward_speed() >= -_definition().max_reverse_speed - 0.3, "reverse speed limited (%.2f)" % vehicle.get_forward_speed())
	source.brake = 0.0
	source.throttle = 1.0
	await physics_frames(60)
	check(vehicle.get_forward_speed() > -1.0, "throttle while reversing brakes and then drives forward (%.2f)" % vehicle.get_forward_speed())


func test_positive_steer_turns_right() -> void:
	await _setup()
	source.throttle = 0.6
	await physics_frames(60)
	source.steer = 1.0
	var heading_before := vehicle.global_basis.z
	await physics_frames(60)
	var heading := vehicle.global_basis.z
	var right_of_start := heading_before.cross(Vector3.UP)
	check(heading.dot(right_of_start) > 0.2, "steer +1 turns toward the driver's right (heading %s)" % heading)
	source.steer = -1.0
	await physics_frames(120)
	check(vehicle.global_basis.z.dot(right_of_start) < heading.dot(right_of_start), "steer -1 turns back to the left")


func test_handbrake_stops_the_vehicle() -> void:
	await _setup()
	source.throttle = 1.0
	await physics_frames(120)
	source.throttle = 0.0
	source.handbrake = true
	var ticks := await _ticks_until(func() -> bool: return vehicle.linear_velocity.length() < 0.3, 600)
	check(ticks >= 0 and ticks < 300, "handbrake stops the vehicle within 5 s (%d ticks)" % ticks)
	check(vehicle.global_basis.y.dot(Vector3.UP) > 0.95, "stays upright while stopping")


func test_focus_out_drops_throttle_and_holds_handbrake() -> void:
	await _setup()
	source.throttle = 1.0
	await physics_frames(90)
	check(vehicle.engine_force > 0.0, "driving before the notification")
	# Real input is released on focus loss (MobileInputController); the scripted
	# driver lets go at the same moment.
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	source.throttle = 0.0
	check(vehicle.engine_force == 0.0, "engine force dropped at once")
	await physics_frames(2)
	for wheel in vehicle.wheels:
		if not wheel.use_as_steering:
			check(wheel.brake == _definition().handbrake_force, "handbrake held on the rear wheels")
	var stopped := await _ticks_until(func() -> bool: return vehicle.linear_velocity.length() < 0.3, 600)
	check(stopped >= 0, "comes to a stop")
	await physics_frames(30)
	check(vehicle.linear_velocity.length() < 0.3, "handbrake keeps holding without input")
	source.throttle = 1.0
	await physics_frames(60)
	check(vehicle.get_forward_speed() > 2.0, "a pedal press releases the held handbrake")


func test_flipped_vehicle_resets_to_spawn() -> void:
	await _setup(CAR, Transform3D(Basis(Vector3.UP, 0.5), Vector3(5, 0.1, -3)))
	var resets := [0]
	vehicle.respawned.connect(func() -> void: resets[0] += 1)
	vehicle.global_transform = Transform3D(Basis(Vector3.BACK, PI), Vector3(12, 2.5, 8))
	await physics_frames(roundi(_definition().flip_reset_seconds / TICK) - 20)
	check(resets[0] == 0, "no reset before the flip time")
	await physics_frames(90)
	check(resets[0] == 1, "reset once after lying flipped (%d)" % resets[0])
	await physics_frames(30)
	check(vehicle.global_position.distance_to(Vector3(5, 0, -3)) < 0.3, "back at the spawn (%s)" % vehicle.global_position)
	check(vehicle.global_basis.y.dot(Vector3.UP) > 0.99, "upright again")


func test_falling_below_kill_height_resets() -> void:
	await _setup()
	vehicle.kill_height = -5.0
	var resets := [0]
	vehicle.respawned.connect(func() -> void: resets[0] += 1)
	vehicle.global_position = Vector3(400, -8, 0)
	await physics_frames(2)
	check(resets[0] == 1, "reset when below the kill height")
	check(vehicle.global_position.distance_to(Vector3.ZERO) < 0.5, "at the spawn (%s)" % vehicle.global_position)


func test_visual_gets_drive_state_and_wheels() -> void:
	await _setup()
	var recording := RecordingVehicleVisual.new()
	vehicle.add_child(recording)
	vehicle.visual = recording
	source.throttle = 1.0
	await physics_frames(60)
	source.throttle = 0.0
	source.brake = 1.0
	await physics_frames(240)
	check(recording.states >= 290, "drive state every tick (%d)" % recording.states)
	check(recording.braking_seen and recording.reversing_seen, "braking and reversing reported")
	check(recording.wheel_counts.all(func(count: int) -> bool: return count == 4), "four wheel poses every tick")


func test_placeholder_lights_and_wheels_follow() -> void:
	await _setup()
	var visual: PlaceholderVehicleVisual = vehicle.visual
	var wheel_mesh: Node3D = visual.wheel_meshes[2]
	var rest := wheel_mesh.transform
	source.throttle = 1.0
	await physics_frames(30)
	check(not wheel_mesh.transform.basis.is_equal_approx(rest.basis), "rear wheel mesh spins with the physics wheel")
	check(not visual.brake_lights.visible and not visual.reverse_lights.visible, "lights off while accelerating")
	source.throttle = 0.0
	source.brake = 1.0
	await physics_frames(5)
	check(visual.brake_lights.visible, "brake lights on while braking")
	await _ticks_until(func() -> bool: return vehicle.reversing, 600)
	await physics_frames(2)
	check(visual.reverse_lights.visible, "reverse lights on while reversing")


func _capsule() -> CapsuleShape3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	return capsule


func test_exit_point_prefers_driver_side_and_avoids_obstacles() -> void:
	await _setup()
	var left = vehicle.find_exit_transform(_capsule(), 0.9)
	check(left != null, "open floor: an exit place exists")
	var left_local: Vector3 = vehicle.to_local(left.origin)
	check(left_local.x > 1.0, "driver's side (+X) first (%s)" % left_local)
	check_near(left.origin.y, 0.05, 0.02, "standing on the floor")
	add_static_box(Vector3(1, 3, 6), vehicle.to_global(Vector3(1.6, 1.5, 0)))
	await physics_frames(2)
	var right = vehicle.find_exit_transform(_capsule(), 0.9)
	check(right != null and vehicle.to_local(right.origin).x < -1.0, "driver's side blocked: the other side (%s)" % [right])
	add_static_box(Vector3(1, 3, 6), vehicle.to_global(Vector3(-1.6, 1.5, 0)))
	await physics_frames(2)
	check(vehicle.find_exit_transform(_capsule(), 0.9) == null, "both sides blocked: no exit")


func test_exit_needs_a_floor() -> void:
	# Narrow strip: the vehicle fits, the exit points hang over nothing.
	add_static_box(Vector3(2.0, 1, 40), Vector3(0, -0.5, 0))
	vehicle = instantiate(CAR)
	source = ScriptedVehicleInput.new()
	add_node(source)
	vehicle.input_source = source
	await physics_frames(60)
	check(vehicle.find_exit_transform(_capsule(), 0.9) == null, "no floor beside the vehicle: no exit")


func test_second_vehicle_type_from_definition_and_scene() -> void:
	await _setup(VAN)
	check(vehicle.definition.display_name.begins_with("Van"), "van definition loaded")
	check(vehicle.mass == 2200.0 and vehicle.wheels.size() == 4, "mass and wheels from the van's definition and scene")
	source.throttle = 1.0
	await physics_frames(600)
	check(vehicle.get_forward_speed() <= vehicle.definition.max_speed + 0.3 and vehicle.get_forward_speed() > vehicle.definition.max_speed - 2.0, "van reaches its own top speed (%.2f, max %.1f)" % [vehicle.get_forward_speed(), vehicle.definition.max_speed])
	check(vehicle.global_basis.y.dot(Vector3.UP) > 0.99, "van stays upright")
	var exit_place = vehicle.find_exit_transform(_capsule(), 0.9)
	check(exit_place != null and vehicle.to_local(exit_place.origin).x > 1.4, "van uses its own exit points")


## Steps physics ticks until `predicate` holds; returns the ticks waited, or -1.
func _ticks_until(predicate: Callable, max_ticks := 240) -> int:
	for i in max_ticks:
		if predicate.call():
			return i
		await tree.physics_frame
	return max_ticks if predicate.call() else -1


func test_driven_vehicle_holds_on_a_slope_without_pedals() -> void:
	# 10° ramp falling toward +Z; the vehicle stands on it nose downhill.
	var ramp := add_static_box(Vector3(40, 1, 60), Vector3(0, -0.5, 0))
	ramp.rotation.x = deg_to_rad(10.0)
	vehicle = instantiate(CAR)
	source = ScriptedVehicleInput.new()
	add_node(source)
	vehicle.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0, 0.6, 0))
	await physics_frames(90)
	# Parked (no driver, handbrake) until settled, then a driver who presses nothing.
	vehicle.input_source = source
	var settled := vehicle.global_position
	await physics_frames(120)
	check(vehicle.global_position.distance_to(settled) < 0.1, "a driven vehicle with no pedal pressed does not roll away on a 10° slope (moved %.2f m)" % vehicle.global_position.distance_to(settled))
	source.throttle = 1.0
	await physics_frames(60)
	check(vehicle.global_position.distance_to(settled) > 1.0, "throttle drives off the hold")


## A vehicle without a driver on a floor (a 600 m one unless `floor` is
## given), waited until it falls asleep.
func _park(start := Transform3D.IDENTITY, floor: StaticBody3D = null) -> void:
	if floor == null:
		add_static_box(Vector3(600, 1, 600))
	vehicle = instantiate(CAR)
	vehicle.global_transform = start
	vehicle.spawn_transform = start
	source = ScriptedVehicleInput.new()
	add_node(source)
	check(await _ticks_until(vehicle.is_asleep, 600) >= 0, "the parked vehicle falls asleep")


func test_parked_vehicle_falls_asleep_after_resting() -> void:
	add_static_box(Vector3(600, 1, 600))
	vehicle = instantiate(CAR)
	var changes: Array[bool] = []
	vehicle.sleep_changed.connect(func(asleep: bool) -> void: changes.append(asleep))
	var rest := roundi(_definition().sleep_after_seconds / TICK)
	var ticks := await _ticks_until(vehicle.is_asleep, 600)
	check(ticks >= rest and ticks < rest + 120, "no driver, at rest: asleep after its rest time (%d ticks, rest %d)" % [ticks, rest])
	var settled := vehicle.global_position
	await physics_frames(120)
	check(vehicle.is_asleep() and changes == [true], "stays asleep on flat ground; one sleep_changed (%s)" % [changes])
	check(vehicle.global_position.distance_to(settled) < 0.001, "does not move while asleep")
	check(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS) == 0, "the physics server simulates nothing (active objects %d)" % PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS))
	for wheel in vehicle.wheels:
		if not wheel.use_as_steering:
			check(wheel.brake == _definition().handbrake_force, "the handbrake stays on while asleep")


func test_rolling_vehicle_sleeps_only_after_it_has_stopped() -> void:
	await _park()
	# A push without a driver (as from a hit): it rolls, the handbrake stops it.
	vehicle.linear_velocity = vehicle.global_basis.z * 6.0
	var rest := roundi(_definition().sleep_after_seconds / TICK)
	var speeds: Array[float] = []
	for i in 600:
		await tree.physics_frame
		if vehicle.is_asleep():
			break
		speeds.append(vehicle.linear_velocity.length())
	check(vehicle.is_asleep(), "asleep again after stopping")
	check(speeds.size() > rest and speeds[0] > 1.0, "it rolled before sleeping (%d awake ticks, first %.2f m/s)" % [speeds.size(), speeds[0] if speeds else 0.0])
	var window := speeds.slice(maxi(speeds.size() - rest + 1, 0))
	check(window.max() < _definition().sleep_linear_speed, "at rest for its whole rest time before sleeping (fastest %.3f m/s)" % window.max())


func test_vehicle_with_a_driver_stays_awake() -> void:
	await _setup()
	await physics_frames(roundi(_definition().sleep_after_seconds / TICK) + 120)
	check(not vehicle.is_asleep(), "a driver who presses nothing keeps the vehicle awake")
	check(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS) == 1, "simulated (active objects %d)" % PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS))
	# Read between physics steps too, as the overlay and the benchmark do: the
	# engine's own sleep test would mark a resting body inactive after a step.
	var asleep_reads := 0
	for i in 120:
		await tree.process_frame
		asleep_reads += int(vehicle.is_asleep())
	check(asleep_reads == 0, "never reads as asleep between steps (%d of 120 frames)" % asleep_reads)


func test_driver_wakes_a_sleeping_vehicle() -> void:
	await _park()
	vehicle.input_source = source
	check(not vehicle.is_asleep(), "awake as soon as a driver gets in")
	source.throttle = 1.0
	await physics_frames(60)
	check(vehicle.get_forward_speed() > 2.0, "drives off (%.2f m/s)" % vehicle.get_forward_speed())


func test_moving_or_resetting_wakes_a_sleeping_vehicle() -> void:
	await _park(Transform3D(Basis.IDENTITY, Vector3(5, 0.1, 0)))
	vehicle.place_at(Transform3D(Basis.IDENTITY, Vector3(20, 0.1, 0)))
	check(not vehicle.is_asleep(), "placed elsewhere (teleport, VIEW): awake")
	check(await _ticks_until(vehicle.is_asleep, 600) >= 0, "asleep again at the new place")
	check(Vector2(vehicle.global_position.x - 20, vehicle.global_position.z).length() < 0.05, "rests where it was placed (%s)" % vehicle.global_position)
	vehicle.reset_to_spawn()
	check(not vehicle.is_asleep(), "reset: awake")
	check(await _ticks_until(vehicle.is_asleep, 600) >= 0, "asleep again at the spawn")
	check(Vector2(vehicle.global_position.x - 5, vehicle.global_position.z).length() < 0.05, "at the spawn (%s)" % vehicle.global_position)


func test_a_body_hitting_a_sleeping_vehicle_wakes_it() -> void:
	await _park()
	var box := RigidBody3D.new()
	box.mass = 400.0
	box.collision_mask = 9
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	box.add_child(shape)
	# Placed before entering the tree, so it never overlaps the vehicle.
	box.position = Vector3(0, 1.0, -4.0)
	box.linear_velocity = Vector3(0, 0, 8)
	add_node(box)
	var woke := await _ticks_until(func() -> bool: return not vehicle.is_asleep(), 120)
	check(woke >= 0, "a 400 kg box thrown at it wakes it (after %d ticks)" % woke)
	check(box.global_position.z < -2.1 - 0.4, "the box did not pass through (z %.2f)" % box.global_position.z)
	check(await _ticks_until(vehicle.is_asleep, 600) >= 0, "back asleep once at rest")


func test_losing_the_ground_wakes_a_sleeping_vehicle() -> void:
	var floor := add_static_box(Vector3(40, 1, 40))
	await _park(Transform3D.IDENTITY, floor)
	floor.process_mode = Node.PROCESS_MODE_DISABLED
	var woke := await _ticks_until(func() -> bool: return not vehicle.is_asleep(), roundi(VehicleController.GROUND_CHECK_INTERVAL / TICK) + 5)
	check(woke >= 0, "floor switched off: awake within one ground check (%d ticks)" % woke)
	await physics_frames(30)
	check(vehicle.global_position.y < -0.5, "falls once awake (y %.2f)" % vehicle.global_position.y)


func test_sleeping_vehicle_stays_on_a_slope_and_the_hill_hold_takes_over() -> void:
	# 10° ramp falling toward +Z; the vehicle stands on it nose downhill.
	var ramp := add_static_box(Vector3(40, 1, 60), Vector3(0, -0.5, 0))
	ramp.rotation.x = deg_to_rad(10.0)
	await _park(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), Vector3(0, 0.6, 0)), ramp)
	var parked := vehicle.global_position
	var wakes := [0]
	vehicle.sleep_changed.connect(func(asleep: bool) -> void: wakes[0] += int(not asleep))
	await physics_frames(300)
	check(vehicle.is_asleep() and wakes[0] == 0, "stays asleep on the slope for 5 s (woke %d times)" % wakes[0])
	check(vehicle.global_position.distance_to(parked) < 0.001, "does not slide while asleep (moved %.4f m)" % vehicle.global_position.distance_to(parked))
	vehicle.wake_up()
	await physics_frames(30)
	check(vehicle.global_position.distance_to(parked) < 0.02, "woken without a driver (a bump): the parked brakes hold (moved %.3f m)" % vehicle.global_position.distance_to(parked))
	check(await _ticks_until(vehicle.is_asleep, 600) >= 0, "and it falls asleep again")
	# Same rule and limit as test_driven_vehicle_holds_on_a_slope_without_pedals
	# (the hold brakes let the car creep ~2 cm/s on 10°, asleep before or not).
	var held := vehicle.global_position
	vehicle.input_source = source
	await physics_frames(120)
	check(vehicle.global_position.distance_to(held) < 0.1, "awake with a driver who presses nothing: the hill hold keeps it (moved %.3f m)" % vehicle.global_position.distance_to(held))
	source.throttle = 1.0
	await physics_frames(60)
	check(vehicle.global_position.distance_to(held) > 1.0, "throttle drives off")
