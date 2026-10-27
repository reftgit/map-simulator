extends "res://tests/test_case.gd"
## Getting in and out of a vehicle on a flat floor with the real HUD, camera,
## player, and touch input: interact button, HUD groups, camera handover,
## exit rules, focus loss, and on-foot actions while driving.

const CAR := "res://game/vehicle/placeholder_car.tscn"
const VAN := "res://tests/fixtures/test_van.tscn"
const TICK := 1.0 / 60.0
## Beside the car's driver door (+X), inside its interaction area.
const NEAR := Vector3(2.2, 0.1, 0.0)
const FAR := Vector3(12.0, 0.1, 0.0)

var hud: UIController
var input: MobileInputController
var rig: ThirdPersonCamera
var player: PlayerController
var vehicle: VehicleController
var vehicle_input: TouchVehicleInput
var interaction: VehicleInteraction
var refusals: Array[String] = []


func _setup(scene := CAR) -> void:
	add_static_box(Vector3(300, 1, 300))
	hud = instantiate("res://game/ui/hud.tscn")
	input = hud.input
	rig = instantiate("res://game/camera/third_person_camera.tscn")
	player = instantiate("res://game/player/player.tscn")
	var player_input := TouchPlayerInput.new()
	add_node(player_input)
	player_input.input = input
	player_input.camera = rig
	player.input_source = player_input
	rig.input = input
	rig.set_target(player)
	hud.bind_player(player)
	vehicle_input = TouchVehicleInput.new()
	add_node(vehicle_input)
	vehicle_input.input = input
	interaction = VehicleInteraction.new()
	add_node(interaction)
	interaction.setup(player, rig, input, vehicle_input)
	interaction.entered.connect(hud.bind_vehicle)
	interaction.exited.connect(func(_v: VehicleController) -> void: hud.bind_vehicle(null))
	interaction.exit_refused.connect(func(reason: String) -> void: refusals.append(reason))
	vehicle = instantiate(scene)
	vehicle.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0))
	interaction.register_vehicle(vehicle)
	player.teleport(Transform3D(Basis.IDENTITY, FAR))
	await physics_frames(30)


func _tap(button: TouchButton, index := 3) -> void:
	var point := button.get_global_rect().get_center()
	touch(index, point, true)
	touch(index, point, false)


func _hold(button: TouchButton, index: int, pressed: bool) -> void:
	touch(index, button.get_global_rect().get_center(), pressed)


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	send_input(event)


func _enter() -> void:
	player.teleport(Transform3D(Basis.IDENTITY, NEAR))
	await physics_frames(15)
	_tap(input.interact_button)
	await physics_frames(3)


## Stops the vehicle with the handbrake (holding the brake would reverse).
func _stop() -> void:
	_hold(input.handbrake_button, 6, true)
	for i in 600:
		if vehicle.linear_velocity.length() < 0.2:
			break
		await tree.physics_frame
	_hold(input.handbrake_button, 6, false)
	await physics_frames(2)


func test_interact_button_only_in_reach_and_on_floor() -> void:
	await _setup()
	check(not input.interact_button.visible, "hidden out of reach")
	_tap(input.interact_button)
	await physics_frames(3)
	check(not interaction.is_driving(), "a press out of reach does nothing")
	player.teleport(Transform3D(Basis.IDENTITY, NEAR))
	await physics_frames(5)
	check(input.interact_button.visible, "shown in reach while standing")
	player.teleport(Transform3D(Basis.IDENTITY, NEAR + Vector3(0, 1.2, 0)))
	await physics_frames(3)
	check(not player.is_on_floor(), "in the air")
	check(not input.interact_button.visible, "hidden while in the air, although in reach")
	var landed := 0
	while not player.is_on_floor() and landed < 120:
		await tree.physics_frame
		landed += 1
	await physics_frames(2)
	check(input.interact_button.visible, "shown again after landing")
	player.teleport(Transform3D(Basis.IDENTITY, FAR))
	await physics_frames(5)
	check(not input.interact_button.visible, "hidden again after walking away")


func test_enter_and_exit_switch_hud_camera_and_player() -> void:
	await _setup()
	var on_foot_profile := rig.profile
	await _enter()
	check(interaction.is_driving() and interaction.vehicle == vehicle, "in the vehicle")
	check(player.seated and not player.visible and player.body_shape.disabled, "player hidden without collision")
	check(not player.is_physics_processing(), "player physics off while seated")
	check(not input.on_foot_controls.visible and input.vehicle_controls.visible, "vehicle controls shown, on-foot controls hidden")
	check(input.vehicle_mode, "input in vehicle mode")
	check(rig.target == vehicle and rig.profile == vehicle.definition.camera_profile, "camera follows the vehicle with its profile")
	check((-rig.global_basis.z).dot(vehicle.global_basis.z) > 0.95, "camera behind the vehicle, looking along its +Z forward")
	check(vehicle.input_source == vehicle_input, "vehicle driven by the touch input")
	check(player.global_position.distance_to(vehicle.seat.global_position) < 0.01, "player kept at the seat")
	_tap(input.exit_button)
	await physics_frames(3)
	check(not interaction.is_driving(), "out of the vehicle")
	check(player.visible and not player.seated and not player.body_shape.disabled and player.is_physics_processing(), "player back with collision and physics")
	check(input.on_foot_controls.visible and not input.vehicle_controls.visible and not input.vehicle_mode, "on-foot controls back")
	check(rig.target == player and rig.profile == on_foot_profile, "camera back on the player with the on-foot profile")
	check(vehicle.input_source == null, "vehicle left parked (no driver)")
	var local := vehicle.to_local(player.global_position)
	check(local.x > 1.0, "got out on the driver's side (%s)" % local)
	await physics_frames(10)
	check(player.is_on_floor(), "standing on the floor after getting out")


func test_drive_with_touch_buttons() -> void:
	await _setup()
	await _enter()
	_hold(input.throttle_button, 4, true)
	await physics_frames(90)
	check(vehicle.get_forward_speed() > 3.0, "throttle button drives forward (%.2f m/s)" % vehicle.get_forward_speed())
	check(vehicle.global_position.z > 2.0, "moved along +Z (%s)" % vehicle.global_position)
	var right := vehicle.global_basis.z.cross(Vector3.UP)
	_hold(input.steer_right_button, 5, true)
	await physics_frames(60)
	_hold(input.steer_right_button, 5, false)
	check(vehicle.global_basis.z.dot(right) > 0.2, "right button turns right")
	_hold(input.throttle_button, 4, false)
	_hold(input.brake_button, 4, true)
	var reversed := 0
	while vehicle.get_forward_speed() > -1.0 and reversed < 600:
		await tree.physics_frame
		reversed += 1
	check(vehicle.reversing, "brake button slows and then reverses")
	_hold(input.brake_button, 4, false)
	await _stop()
	check(vehicle.linear_velocity.length() < 0.2, "handbrake button stops it")


func test_exit_refused_while_too_fast() -> void:
	await _setup()
	await _enter()
	_hold(input.throttle_button, 4, true)
	await physics_frames(60)
	_hold(input.throttle_button, 4, false)
	check(vehicle.linear_velocity.length() > vehicle.definition.safe_exit_speed, "faster than the safe exit speed")
	await process_frames(1)
	check(input.exit_button.dimmed, "exit button faded while too fast")
	_tap(input.exit_button)
	await physics_frames(3)
	check(interaction.is_driving(), "exit refused at speed")
	check(refusals == (["speed"] as Array[String]), "refusal reason (%s)" % [refusals])
	await _stop()
	await process_frames(1)
	check(not input.exit_button.dimmed, "exit button back once slow")
	_tap(input.exit_button)
	await physics_frames(3)
	check(not interaction.is_driving(), "exit accepted at a safe speed")


func test_exit_tries_the_other_side_then_refuses() -> void:
	await _setup()
	await _enter()
	add_static_box(Vector3(1, 3, 6), vehicle.to_global(Vector3(1.6, 1.5, 0)))
	await physics_frames(2)
	_tap(input.exit_button)
	await physics_frames(3)
	check(not interaction.is_driving(), "got out although the driver's side is blocked")
	check(vehicle.to_local(player.global_position).x < -1.0, "on the passenger side (%s)" % vehicle.to_local(player.global_position))
	player.teleport(Transform3D(Basis.IDENTITY, vehicle.to_global(Vector3(-2.2, 0.1, 0))))
	await physics_frames(15)
	_tap(input.interact_button)
	await physics_frames(3)
	check(interaction.is_driving(), "back in from the passenger side")
	add_static_box(Vector3(1, 3, 6), vehicle.to_global(Vector3(-1.6, 1.5, 0)))
	await physics_frames(2)
	_tap(input.exit_button)
	await physics_frames(3)
	check(interaction.is_driving(), "both sides blocked: stays in")
	check(refusals.has("blocked"), "refusal reason blocked (%s)" % [refusals])


func test_focus_out_while_driving_releases_controls() -> void:
	await _setup()
	await _enter()
	_hold(input.throttle_button, 4, true)
	_hold(input.steer_left_button, 5, true)
	await physics_frames(60)
	check(input.throttle_button.is_down and vehicle.engine_force > 0.0, "driving before the notification")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await physics_frames(2)
	check(not input.throttle_button.is_down and not input.steer_left_button.is_down, "no vehicle button stays down")
	check(input.get_vehicle_throttle() == 0.0 and input.get_vehicle_steer() == 0.0, "throttle and steering released")
	check(vehicle.engine_force == 0.0, "engine force zero")
	for wheel in vehicle.wheels:
		if not wheel.use_as_steering:
			check(wheel.brake == vehicle.definition.handbrake_force, "handbrake held")
	var stopped := 0
	while vehicle.linear_velocity.length() > 0.2 and stopped < 600:
		await tree.physics_frame
		stopped += 1
	check(vehicle.linear_velocity.length() <= 0.2, "vehicle comes to rest")
	check(interaction.is_driving(), "still seated (focus loss does not get out)")


func test_on_foot_actions_are_inert_while_driving() -> void:
	await _setup()
	await _enter()
	_key(KEY_J, true)
	_key(KEY_J, false)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await physics_frames(3)
	check(not input.consume_action_press(&"punch") and not input.consume_action_press(&"roll"), "J and Space record no punch or roll while driving")
	_key(KEY_J, true)
	_key(KEY_J, false)
	_tap(input.exit_button)
	await physics_frames(2)
	check(not interaction.is_driving(), "out")
	var states: Array[StringName] = []
	for i in 30:
		await tree.physics_frame
		var state := player.state_machine.get_state_name()
		if states.is_empty() or states.back() != state:
			states.append(state)
	check(states == ([&"Idle"] as Array[StringName]), "nothing pressed in the vehicle fires after getting out (%s)" % [states])
	_tap(input.punch_button)
	await physics_frames(3)
	check(player.state_machine.get_state_name() == &"Punch", "punch works again on foot")


func test_keyboard_enters_drives_and_exits() -> void:
	await _setup()
	player.teleport(Transform3D(Basis.IDENTITY, NEAR))
	await physics_frames(5)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await physics_frames(3)
	check(interaction.is_driving(), "E gets in")
	_key(KEY_W, true)
	await physics_frames(60)
	check(vehicle.get_forward_speed() > 2.0, "W drives forward (%.2f)" % vehicle.get_forward_speed())
	_key(KEY_E, true)
	_key(KEY_E, false)
	await physics_frames(2)
	check(interaction.is_driving(), "E refused while moving")
	_key(KEY_W, false)
	_key(KEY_SPACE, true)
	for i in 600:
		if vehicle.linear_velocity.length() < 0.2:
			break
		await tree.physics_frame
	_key(KEY_SPACE, false)
	check(vehicle.linear_velocity.length() < 0.2, "Space (handbrake) stops it")
	_key(KEY_E, true)
	_key(KEY_E, false)
	await physics_frames(2)
	check(not interaction.is_driving(), "E gets out when stopped")


func test_second_vehicle_type_enter_and_exit() -> void:
	await _setup(VAN)
	await _enter()
	check(interaction.vehicle == vehicle and vehicle.definition.display_name.begins_with("Test van"), "in the van")
	check(rig.profile == vehicle.definition.camera_profile, "van's camera profile")
	_tap(input.exit_button)
	await physics_frames(3)
	check(not interaction.is_driving(), "out of the van")
	check(vehicle.to_local(player.global_position).x > 1.4, "beside the van's own exit point")


func test_entering_while_walking_leaves_the_player_idle() -> void:
	await _setup()
	player.teleport(Transform3D(Basis.IDENTITY, NEAR))
	await physics_frames(15)
	var rect := input.joystick.get_global_rect()
	var stick := rect.position + rect.size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -60))
	await physics_frames(2)
	_tap(input.interact_button)
	await physics_frames(3)
	check(interaction.is_driving(), "got in while the stick was held")
	check(player.state_machine.get_state_name() == &"Idle", "seated player is Idle, not walking (%s)" % player.state_machine.get_state_name())
	check(player.velocity == Vector3.ZERO, "no velocity while seated")
	touch(0, stick + Vector2(0, -60), false)


class ScriptedWalk extends PlayerInputSource:
	var move := Vector3.ZERO

	func fill_intent(intent: PlayerIntent, _player: PlayerController) -> void:
		intent.move = move


## Steps physics ticks until the vehicle is asleep; false if it is not
## within 10 s.
func _until_asleep() -> bool:
	for i in 600:
		if vehicle.is_asleep():
			return true
		await tree.physics_frame
	return vehicle.is_asleep()


func test_interact_button_works_while_the_vehicle_sleeps() -> void:
	await _setup()
	check(await _until_asleep(), "parked car asleep")
	player.teleport(Transform3D(Basis.IDENTITY, NEAR))
	await physics_frames(15)
	check(input.interact_button.visible, "in reach of the sleeping car: interact button shown")
	check(vehicle.is_asleep(), "being in reach does not wake it")
	_tap(input.interact_button)
	await physics_frames(3)
	check(interaction.is_driving() and not vehicle.is_asleep(), "got in: awake")
	_hold(input.throttle_button, 5, true)
	await physics_frames(60)
	_hold(input.throttle_button, 5, false)
	check(vehicle.get_forward_speed() > 2.0, "drives off from sleep (%.2f m/s)" % vehicle.get_forward_speed())


func test_walking_into_a_sleeping_vehicle_wakes_it() -> void:
	await _setup()
	var walk := ScriptedWalk.new()
	add_node(walk)
	player.input_source = walk
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(3.2, 0.1, 0)))
	check(await _until_asleep(), "parked car asleep")
	var parked := vehicle.global_position
	walk.move = Vector3(-1, 0, 0)
	var woke := -1
	for i in 90:
		await tree.physics_frame
		if not vehicle.is_asleep():
			woke = i
			break
	check(woke >= 0, "walking into its side wakes it (after %d ticks)" % woke)
	check(player.global_position.x > 0.9 + 0.3, "the player is stopped by the car (x %.2f)" % player.global_position.x)
	await physics_frames(60)
	check(not vehicle.is_asleep(), "stays awake while the player keeps pushing")
	check(vehicle.global_position.distance_to(parked) < 0.01, "the player does not move the car (vehicles do not collide with the player layer)")
	walk.move = Vector3.ZERO
	check(await _until_asleep(), "asleep again after the player stops")
	# Standing still against the car does not keep waking it (found on the
	# iPhone in Phase 4c: the car stayed awake while the player stood beside it).
	var wakes := [0]
	vehicle.sleep_changed.connect(func(asleep: bool) -> void: wakes[0] += int(not asleep))
	await physics_frames(180)
	check(wakes[0] == 0 and vehicle.is_asleep(), "stays asleep while the player stands against it (woke %d times in 3 s)" % wakes[0])


func test_overlay_status_shows_the_vehicle_while_driving() -> void:
	await _setup()
	hud.vehicles.append(vehicle)
	check(await _until_asleep(), "parked car asleep")
	check(hud.status_text() == "Idle 0.0 m/s | car asleep", "on foot: player state and speed, car asleep (%s)" % hud.status_text())
	await _enter()
	_hold(input.throttle_button, 5, true)
	await physics_frames(60)
	var text := hud.status_text()
	var expected := "Driving %.1f m/s | car awake" % vehicle.get_forward_speed()
	_hold(input.throttle_button, 5, false)
	check(text == expected and vehicle.get_forward_speed() > 2.0, "driving: the vehicle's speed, not the player's (%s, expected %s)" % [text, expected])


func test_standing_against_a_parked_car_on_a_slope_lets_it_sleep() -> void:
	# Found on the iPhone in Phase 4c: on a sloped street the idle player keeps a
	# wall contact with the car beside it, and that kept waking the car.
	var tilt := deg_to_rad(-6.0)
	var ramp := add_static_box(Vector3(60, 1, 60))
	ramp.rotation.z = tilt
	vehicle = instantiate(CAR)
	vehicle.global_transform = Transform3D(Basis(Vector3.BACK, tilt), Vector3(0, 0.6, 0))
	player = instantiate("res://game/player/player.tscn")
	var walk := ScriptedWalk.new()
	add_node(walk)
	player.input_source = walk
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(3.2, 3.2 * tan(tilt) + 0.3, 0)))
	check(await _until_asleep(), "parked car asleep on the slope")
	walk.move = Vector3(-1, 0, 0)
	await physics_frames(90)
	check(not vehicle.is_asleep(), "walking into it wakes it")
	walk.move = Vector3.ZERO
	await physics_frames(120)
	var awake := 0
	for i in 300:
		await tree.physics_frame
		awake += int(not vehicle.is_asleep())
	check(player.is_on_wall(), "the idle player still touches the car")
	check(awake == 0, "the car sleeps while the player stands still against it (awake %d of 300 ticks)" % awake)
