extends "res://tests/test_case.gd"
## Punch and roll on a flat floor: state rules, the action buffer, hitbox
## timing, the CharacterVisual hooks, and camera follow. Driven by a scripted
## input source, except where the real HUD and camera are needed.

const TICK := 1.0 / 60.0


class ScriptedInput extends PlayerInputSource:
	var move := Vector3.ZERO
	var run := false
	var _punch := false
	var _roll := false

	func press_punch() -> void:
		_punch = true

	func press_roll() -> void:
		_roll = true

	func fill_intent(intent: PlayerIntent, _player: PlayerController) -> void:
		intent.move = move
		intent.run = run
		intent.punch = _punch
		intent.roll = _roll
		_punch = false
		_roll = false


## Samples the camera after ThirdPersonCamera._process in the same frame.
class FrameProbe extends Node:
	var rig: ThirdPersonCamera
	var target: Node3D
	var samples: Array[Array] = []

	func _init() -> void:
		process_priority = 100

	func _process(delta: float) -> void:
		samples.append([rig.global_position, target.get_global_transform_interpolated().origin, delta])


class RecordingVisual extends CharacterVisual:
	var calls: Array[String] = []
	var locomotion_calls := 0
	var last_speed := 0.0

	func set_locomotion(speed: float, _on_floor: bool) -> void:
		locomotion_calls += 1
		last_speed = speed

	func play_action(action: StringName, duration: float, impact := -1.0) -> void:
		calls.append("play %s %.2f %.2f" % [action, duration, impact])

	func stop_action() -> void:
		calls.append("stop")


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


func _state() -> StringName:
	return player.state_machine.get_state_name()


func _punch() -> PunchState:
	return player.state_machine.get_node("Punch")


func _roll() -> RollState:
	return player.state_machine.get_node("Roll")


func _hitbox() -> Hitbox:
	return player.get_node("Hitbox")


## Steps physics ticks until `predicate` holds; returns the ticks waited, or
## -1 if it never held within `max_ticks`.
func _ticks_until(predicate: Callable, max_ticks := 240) -> int:
	for i in max_ticks:
		if predicate.call():
			return i
		await tree.physics_frame
	return max_ticks if predicate.call() else -1


## One sample per physics tick: state, punch phase, hitbox open, position.
func _record(ticks: int) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for i in ticks:
		await tree.physics_frame
		samples.append({"state": _state(), "phase": _punch().phase, "hitbox": _hitbox().is_active(), "position": player.global_position})
	return samples


func _count(samples: Array[Dictionary], key: String, value: Variant) -> int:
	return samples.filter(func(sample: Dictionary) -> bool: return sample[key] == value).size()


func _states_seen(samples: Array[Dictionary]) -> Array[StringName]:
	var seen: Array[StringName] = []
	for sample in samples:
		if seen.is_empty() or seen.back() != sample.state:
			seen.append(sample.state)
	return seen


func _add_hurtbox(center: Vector3) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.4
	cylinder.height = 1.8
	shape.shape = cylinder
	hurtbox.add_child(shape)
	hurtbox.position = center
	add_node(hurtbox)
	return hurtbox


func test_action_buffer_keeps_presses_for_the_window() -> void:
	var buffer := ActionBuffer.new()
	buffer.window = 0.18
	buffer.press(&"punch")
	for i in 10:
		buffer.tick(TICK)
	check(buffer.has(&"punch"), "a press is still there after 10 ticks (0.167 s)")
	buffer.tick(TICK)
	check(not buffer.has(&"punch"), "a press older than the window is dropped")
	buffer.press(&"punch")
	check(buffer.take(&"punch") and not buffer.take(&"punch"), "take() consumes a press once")
	buffer.block(&"roll", 0.5)
	buffer.press(&"roll")
	check(not buffer.has(&"roll") and buffer.is_blocked(&"roll"), "presses while blocked are ignored")
	for i in 31:
		buffer.tick(TICK)
	check(not buffer.is_blocked(&"roll"), "the block ends after its time")
	buffer.press(&"roll")
	buffer.block(&"roll", INF)
	check(not buffer.has(&"roll"), "blocking drops a pending press")
	for i in 600:
		buffer.tick(TICK)
	check(buffer.is_blocked(&"roll"), "an INF block lasts until it is replaced")
	buffer.press(&"punch")
	buffer.clear_presses()
	check(not buffer.has(&"punch") and buffer.is_blocked(&"roll"), "clear_presses() keeps blocks")


func test_punch_phases_and_hitbox_timing() -> void:
	await _setup()
	var punch := _punch()
	source.press_punch()
	var samples := await _record(40)
	var punching := samples.filter(func(sample: Dictionary) -> bool: return sample.state == &"Punch")
	var expected_ticks := roundi(punch.get_duration() / TICK)
	check(absi(punching.size() - expected_ticks) <= 1, "punch lasts its duration (%d ticks, expected %d ± 1)" % [punching.size(), expected_ticks])
	var open := _count(samples, "hitbox", true)
	check(open == roundi(punch.active / TICK), "hitbox open for exactly the active phase (%d ticks)" % open)
	for sample in samples:
		if sample.hitbox:
			check(sample.state == &"Punch" and sample.phase == PunchState.Phase.ACTIVE, "hitbox only open in the active phase")
	var first_open := samples.find_custom(func(sample: Dictionary) -> bool: return sample.hitbox)
	check(first_open >= roundi(punch.startup / TICK), "startup passes before the hitbox opens (tick %d)" % first_open)
	check(samples.back().state == &"Idle" and not samples.back().hitbox, "back to Idle with the hitbox closed")


func test_punch_slows_movement_and_locomotion_resumes() -> void:
	await _setup()
	source.move = Vector3(0, 0, -1)
	source.run = true
	await physics_frames(60)
	check(_state() == &"Run" and player.get_horizontal_speed() > 7.9, "running before the punch")
	var facing := -player.global_basis.z
	source.move = Vector3(1, 0, 0)
	source.press_punch()
	await physics_frames(20)
	check(_state() == &"Punch", "still punching after 20 ticks")
	check(player.get_horizontal_speed() < 0.5, "the punch stops the body (%.2f m/s)" % player.get_horizontal_speed())
	check((-player.global_basis.z).dot(facing) > 0.999, "facing does not follow the stick during the punch")
	var ticks := await _ticks_until(func() -> bool: return _state() != &"Punch")
	check(ticks >= 0 and _state() == &"Run", "locomotion resumes as Run with the stick and toggle held (%s)" % _state())
	await physics_frames(40)
	check_near(player.get_horizontal_speed(), player.run_speed, 0.05, "back to run speed")
	check((-player.global_basis.z).dot(Vector3.RIGHT) > 0.99, "turns to the stick again after the punch")


func test_roll_direction() -> void:
	var intent := PlayerIntent.new()
	intent.move = Vector3(0.3, 0, -0.4)
	check(RollState.roll_direction(intent, 2.0).distance_to(Vector3(0.6, 0, -0.8)) < 0.0001, "stick direction, normalized, ignores facing")
	intent.move = Vector3.ZERO
	check(RollState.roll_direction(intent, 0.0).distance_to(Vector3(0, 0, -1)) < 0.0001, "no stick, yaw 0: forward (-Z)")
	check(RollState.roll_direction(intent, PI * 0.5).distance_to(Vector3(-1, 0, 0)) < 0.0001, "no stick, yaw 90°: -X")
	intent.move = Vector3(0.03, 0, 0)
	check(RollState.roll_direction(intent, PI).distance_to(Vector3(0, 0, 1)) < 0.0001, "a stick inside the dead zone counts as no stick")


func test_roll_follows_move_direction_for_its_distance() -> void:
	await _setup()
	var roll := _roll()
	var start := player.global_position
	source.move = Vector3(0.6, 0, 0.8)
	source.press_roll()
	await physics_frames(1)
	var samples := await _record(60)
	var rolling := _count(samples, "state", &"Roll")
	check(absi(rolling - roundi(roll.duration / TICK)) <= 1, "roll lasts its duration (%d ticks)" % rolling)
	var end_index := samples.find_custom(func(sample: Dictionary) -> bool: return sample.state != &"Roll")
	var moved: Vector3 = samples[end_index].position - start
	check_near(Vector2(moved.x, moved.z).length(), roll.distance, 0.3, "roll covers its distance")
	check(Vector2(moved.x, moved.z).normalized().dot(Vector2(0.6, 0.8)) > 0.999, "roll goes where the stick points (moved %s)" % moved)
	check((-player.global_basis.z).dot(Vector3(0.6, 0, 0.8)) > 0.99, "body faces the roll direction")
	check(samples[end_index].state == &"Walk", "stick held: Walk after the roll (%s)" % samples[end_index].state)


func test_roll_without_stick_goes_where_the_body_faces() -> void:
	await _setup()
	player.rotation.y = 0.7
	var start := player.global_position
	source.press_roll()
	var ticks := await _ticks_until(func() -> bool: return _state() == &"Roll")
	ticks = await _ticks_until(func() -> bool: return _state() != &"Roll")
	var moved := player.global_position - start
	var facing := Vector3.FORWARD.rotated(Vector3.UP, 0.7)
	check(ticks > 0, "the roll ended")
	check(Vector3(moved.x, 0, moved.z).normalized().dot(facing) > 0.999, "rolled forward along the facing (moved %s)" % moved)
	check_near(Vector2(moved.x, moved.z).length(), _roll().distance, 0.3, "full distance without stick input")
	check(_state() == &"Idle", "no stick: Idle after the roll")


func test_punch_pressed_late_in_roll_runs_right_after() -> void:
	await _setup()
	source.press_roll()
	await _ticks_until(func() -> bool: return _state() == &"Roll")
	await physics_frames(roundi((_roll().duration - 0.1) / TICK))
	check(_state() == &"Roll", "still rolling when punch is pressed")
	source.press_punch()
	var samples := await _record(50)
	check(_states_seen(samples).slice(0, 3) == ([&"Roll", &"Punch", &"Idle"] as Array[StringName]), "Roll -> Punch -> Idle (got %s)" % [_states_seen(samples)])


func test_punch_pressed_early_in_roll_expires() -> void:
	await _setup()
	source.press_roll()
	await _ticks_until(func() -> bool: return _state() == &"Roll")
	await physics_frames(3)
	source.press_punch()
	var samples := await _record(60)
	check(_count(samples, "state", &"Punch") == 0, "a press older than the buffer window when the roll ends is dropped (%s)" % [_states_seen(samples)])
	check(samples.back().state == &"Idle", "Idle after the roll")


func test_roll_cancels_punch_recovery() -> void:
	await _setup()
	var punch := _punch()
	source.press_punch()
	await _ticks_until(func() -> bool: return punch.phase == PunchState.Phase.RECOVERY and _state() == &"Punch")
	check(not _hitbox().is_active(), "hitbox closed in recovery")
	source.press_roll()
	await physics_frames(2)
	check(_state() == &"Roll", "a roll press in recovery starts the roll at once (%s)" % _state())
	check(not _hitbox().is_active(), "hitbox stays closed after the cancel")


## Roll pressed `ticks_in` ticks into a punch, while it is in `expected_phase`
## (close enough to the recovery that the press is still buffered then).
func _check_roll_waits_for_recovery(ticks_in: int, expected_phase: PunchState.Phase) -> void:
	await _setup()
	var punch := _punch()
	source.press_punch()
	await _ticks_until(func() -> bool: return _state() == &"Punch")
	await physics_frames(ticks_in)
	check(punch.phase == expected_phase, "roll pressed in phase %d (got %d)" % [expected_phase, punch.phase])
	source.press_roll()
	var samples := await _record(30)
	var first_roll := samples.find_custom(func(sample: Dictionary) -> bool: return sample.state == &"Roll")
	check(first_roll > 0, "the buffered roll starts later (%s)" % [_states_seen(samples)])
	for i in maxi(first_roll, 0):
		check(samples[i].state == &"Punch" and samples[i].phase != PunchState.Phase.RECOVERY, "no roll before recovery (tick %d: %s)" % [i, samples[i]])
	if first_roll > 0:
		check(samples[first_roll - 1].phase == PunchState.Phase.ACTIVE, "the roll starts on the first recovery tick")


func test_roll_cannot_cancel_punch_active_phase() -> void:
	await _check_roll_waits_for_recovery(9, PunchState.Phase.ACTIVE)


func test_roll_cannot_cancel_punch_startup() -> void:
	await _check_roll_waits_for_recovery(3, PunchState.Phase.STARTUP)


func test_roll_pressed_at_punch_start_expires_before_recovery() -> void:
	await _setup()
	source.press_punch()
	await _ticks_until(func() -> bool: return _state() == &"Punch")
	source.press_roll()
	var samples := await _record(40)
	check(_count(samples, "state", &"Roll") == 0, "a roll pressed more than the buffer window before the recovery is dropped (%s)" % [_states_seen(samples)])


func test_actions_do_not_start_in_the_air() -> void:
	await _setup()
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 6, 0)))
	await physics_frames(2)
	check(not player.is_on_floor(), "in the air")
	source.press_punch()
	await physics_frames(1)
	source.press_roll()
	var samples: Array[Dictionary] = []
	while not player.is_on_floor() and samples.size() < 120:
		samples.append_array(await _record(1))
	check(player.is_on_floor(), "landed")
	check(_count(samples, "state", &"Punch") + _count(samples, "state", &"Roll") == 0, "no action while airborne (%s)" % [_states_seen(samples)])
	check(samples.size() * TICK > player.input_buffer_time, "the fall outlasted the buffer window")
	samples = await _record(30)
	check(_states_seen(samples) == ([&"Idle"] as Array[StringName]), "expired presses do not fire on landing (%s)" % [_states_seen(samples)])


func test_roll_press_during_cooldown_is_ignored() -> void:
	await _setup()
	var roll := _roll()
	source.press_roll()
	await _ticks_until(func() -> bool: return _state() == &"Roll")
	await _ticks_until(func() -> bool: return _state() != &"Roll")
	check(player.actions.is_blocked(&"roll"), "cooldown after the roll")
	source.press_roll()
	await physics_frames(roundi((roll.cooldown - 0.1) / TICK))
	source.press_roll()
	var samples := await _record(roundi(0.4 / TICK))
	check(_count(samples, "state", &"Roll") == 0, "presses during the cooldown never start a roll, even after it ends")
	check(not player.actions.is_blocked(&"roll"), "cooldown over")
	source.press_roll()
	await physics_frames(2)
	check(_state() == &"Roll", "a press after the cooldown rolls")


func test_roll_press_during_roll_is_ignored() -> void:
	await _setup()
	source.press_roll()
	await _ticks_until(func() -> bool: return _state() == &"Roll")
	await physics_frames(roundi((_roll().duration - 0.05) / TICK))
	source.press_roll()
	var samples := await _record(roundi(1.0 / TICK))
	check(_states_seen(samples) == ([&"Roll", &"Idle"] as Array[StringName]), "rolls do not chain (%s)" % [_states_seen(samples)])


func _check_interrupt(what: int, action: StringName) -> void:
	await _setup()
	if action == &"punch":
		source.press_punch()
		await _ticks_until(func() -> bool: return _punch().phase == PunchState.Phase.ACTIVE and _state() == &"Punch")
		check(_hitbox().is_active(), "hitbox open before the notification")
	else:
		source.press_roll()
		await _ticks_until(func() -> bool: return _state() == &"Roll")
		await physics_frames(10)
	source.press_punch()
	await physics_frames(1)
	tree.root.propagate_notification(what)
	check(_state() == &"Idle", "%s interrupted: Idle at once (%s)" % [action, _state()])
	check(not _hitbox().is_active(), "hitbox closed")
	var pivot: Node3D = player.get_node("Visual/Pivot")
	check(pivot.rotation.is_zero_approx() and pivot.scale.is_equal_approx(Vector3.ONE) and not player.get_node("Visual/Pivot/Fist").visible, "visual back to its rest pose")
	var samples := await _record(30)
	check(_states_seen(samples) == ([&"Idle"] as Array[StringName]), "nothing buffered fires after resume (%s)" % [_states_seen(samples)])
	check_near(player.get_horizontal_speed(), 0.0, 0.01, "body at rest")
	source.move = Vector3(0, 0, -1)
	await physics_frames(60)
	check(_state() == &"Walk" and absf(player.get_horizontal_speed() - player.walk_speed) < 0.05, "walking works after the interruption")


func test_focus_out_ends_punch() -> void:
	await _check_interrupt(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, &"punch")


func test_pause_ends_punch() -> void:
	await _check_interrupt(Node.NOTIFICATION_APPLICATION_PAUSED, &"punch")


func test_focus_out_ends_roll() -> void:
	await _check_interrupt(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, &"roll")


func test_pause_ends_roll() -> void:
	await _check_interrupt(Node.NOTIFICATION_APPLICATION_PAUSED, &"roll")


func test_hitbox_hits_a_hurtbox_once_per_punch() -> void:
	await _setup()
	var front := _add_hurtbox(Vector3(0, 0.9, -1.0))
	var behind := _add_hurtbox(Vector3(0, 0.9, 1.5))
	var hits := {front: 0, behind: 0}
	front.hit_received.connect(func(attacker: Node3D) -> void:
		hits[front] += 1
		check(attacker == player, "the attacker is the player"))
	behind.hit_received.connect(func(_attacker: Node3D) -> void: hits[behind] += 1)
	await physics_frames(5)
	check(hits[front] == 0, "no hit while the hitbox is closed, although it overlaps")
	source.press_punch()
	await physics_frames(40)
	check(hits[front] == 1, "one punch hits the target in front exactly once (got %d)" % hits[front])
	check(hits[behind] == 0, "the target behind is not hit")
	source.press_punch()
	await physics_frames(40)
	check(hits[front] == 2, "a second punch hits again (got %d)" % hits[front])


func test_visual_can_be_replaced() -> void:
	await _setup()
	var recording := RecordingVisual.new()
	player.add_child(recording)
	player.visual = recording
	source.move = Vector3(0, 0, -1)
	await physics_frames(30)
	check(recording.locomotion_calls >= 29, "set_locomotion every tick (%d)" % recording.locomotion_calls)
	check_near(recording.last_speed, player.get_horizontal_speed(), 0.01, "with the horizontal speed")
	source.move = Vector3.ZERO
	source.press_punch()
	await physics_frames(40)
	source.press_roll()
	await physics_frames(50)
	var expected: Array[String] = ["play punch 0.45 0.10", "stop", "play roll 0.60 -1.00", "stop"]
	check(recording.calls == expected, "states drive the visual only through its interface (%s)" % [recording.calls])


func test_placeholder_visual_animates_and_resets() -> void:
	await _setup()
	var pivot: Node3D = player.get_node("Visual/Pivot")
	var fist: Node3D = player.get_node("Visual/Pivot/Fist")
	var rest := fist.position
	source.press_punch()
	await physics_frames(8)
	check(fist.visible and fist.position.z < rest.z - 0.3, "fist thrust forward during the punch (z %.2f)" % fist.position.z)
	await physics_frames(30)
	check(not fist.visible and fist.position.is_equal_approx(rest), "fist back at rest after the punch")
	source.press_roll()
	await physics_frames(18)
	check(absf(pivot.rotation.x) > 1.0 and pivot.scale.y < 0.9, "tucked and turning mid-roll (rotation %.2f)" % pivot.rotation.x)
	await physics_frames(30)
	check(absf(pivot.rotation.x) < 0.2 and pivot.scale.is_equal_approx(Vector3.ONE), "upright after the roll")


func test_roll_follows_camera_and_camera_follows_roll() -> void:
	add_static_box()
	var hud: UIController = instantiate("res://game/ui/hud.tscn")
	var rig: ThirdPersonCamera = instantiate("res://game/camera/third_person_camera.tscn")
	player = instantiate("res://game/player/player.tscn")
	var touch_input := TouchPlayerInput.new()
	add_node(touch_input)
	touch_input.input = hud.input
	touch_input.camera = rig
	player.input_source = touch_input
	rig.input = hud.input
	hud.bind_player(player)
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	rig.set_target(player)
	await physics_frames(10)
	# Camera turned 90° left: "stick up" now means world -X.
	rig.yaw = PI * 0.5
	rig.add_look(Vector2.ZERO)
	var stick_rect := hud.input.joystick.get_global_rect()
	var stick := stick_rect.position + stick_rect.size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -200))
	var start := player.global_position
	var roll_point := hud.input.roll_button.get_global_rect().get_center()
	touch(1, roll_point, true)
	touch(1, roll_point, false)
	await _ticks_until(func() -> bool: return _state() == &"Roll")
	var probe := FrameProbe.new()
	probe.rig = rig
	probe.target = player
	add_node(probe)
	await _ticks_until(func() -> bool: return _state() != &"Roll")
	probe.queue_free()
	touch(0, stick + Vector2(0, -200), false)
	var moved := player.global_position - start
	check(Vector2(moved.x, moved.z).normalized().dot(Vector2(-1, 0)) > 0.99, "rolled toward the camera's forward (moved %s)" % moved)
	var backwards := 0
	var off_target := 0
	var max_speed := 0.0
	for i in probe.samples.size():
		var camera: Vector3 = probe.samples[i][0]
		var target: Vector3 = probe.samples[i][1]
		if Vector2(camera.x - target.x, camera.z - target.z).length() > 0.001:
			off_target += 1
		if i > 0:
			var step: Vector3 = camera - probe.samples[i - 1][0]
			if step.dot(Vector3.LEFT) < -0.0001:
				backwards += 1
			max_speed = maxf(max_speed, step.length() / maxf(probe.samples[i][2], 0.0001))
	var travelled: float = (probe.samples.back()[0] - probe.samples.front()[0]).length()
	check(probe.samples.size() > 10, "sampled the roll (%d frames)" % probe.samples.size())
	check(off_target == 0, "camera pivot on the interpolated player in every frame (%d off)" % off_target)
	check(backwards == 0, "camera never stepped backwards during the roll (%d frames)" % backwards)
	check(travelled > _roll().distance - 0.8, "camera travelled with the roll (%.2f m)" % travelled)
	print("     camera frames during roll=%d travelled=%.2f m max frame speed=%.1f m/s" % [probe.samples.size(), travelled, max_speed])
	check(hud.input.roll_button.dimmed, "roll button faded during the cooldown")
	await physics_frames(roundi(_roll().cooldown / TICK) + 2)
	await process_frames(1)
	check(not hud.input.roll_button.dimmed, "roll button back after the cooldown")


func test_target_reentering_during_active_phase_is_hit_once() -> void:
	await _setup()
	var hurtbox := _add_hurtbox(Vector3(0, 0.9, -1.0))
	var hits := [0]
	hurtbox.hit_received.connect(func(_attacker: Node3D) -> void: hits[0] += 1)
	source.press_punch()
	await _ticks_until(func() -> bool: return hits[0] == 1)
	check(_hitbox().is_active(), "first hit lands early in the active phase")
	hurtbox.position = Vector3(0, 0.9, 5.0)
	await physics_frames(2)
	hurtbox.position = Vector3(0, 0.9, -1.0)
	await physics_frames(2)
	check(_hitbox().is_active(), "target left and came back while the hitbox was still open")
	await physics_frames(30)
	check(hits[0] == 1, "one hit per punch even when the target re-enters (got %d)" % hits[0])
