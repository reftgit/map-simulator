class_name DeviceScenario
extends Node
## Plays a scripted session on the device with synthetic touches
## (Input.parse_input_event, the path real touches take) and logs one
## "SCENARIO step=<name> result=<PASS|FAIL|INFO> <details>" line per step, so
## an on-device check needs no hands and leaves log evidence. Debug builds
## only: it presses the debug CAR and VIEW buttons. Started by an experiment
## with a "scenario" section (PerfConfig.SCENARIOS); writes its results where
## the benchmark writes (PerfBenchmark.RESULTS_PATH, and the external folder
## on Android) so the host scripts collect them the same way, then quits
## (iOS: hides the map, as the benchmark does).
##
## "vehicle_sleep": the parked car's sleep and wake rules (Phase 4b) on the
## real map, including standing against the car on a sloped street (Phase
## 4c fix), then, with rotate_hold_s > 0, the "orientation" steps.
## "orientation": holds the joystick for rotate_hold_s while the device is
## turned (by adb on Android, by hand on iOS), logging the gravity vector,
## the safe area, and the stick once a second, then releases it.
## "extensibility" (Phase 5): the debug MAP button to the test district,
## the van there, punching an NPC, MAP back, then the "vehicle_sleep" steps.

signal finished(results: Array)

## Touch indices of the synthetic fingers (above what tests and hands use).
const STICK_FINGER := 7
const BUTTON_FINGER := 8

var config: PerfConfig
var game: Node
var results: Array = []

var _started_ms := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))
	if not PerfConfig.external_dir().is_empty():
		DirAccess.remove_absolute(PerfConfig.external_dir().path_join("bench_results.json"))
	_run.call_deferred()


func _run() -> void:
	_started_ms = Time.get_ticks_msec()
	_log("start", "INFO", "scenario=%s rotate_hold_s=%.0f" % [config.scenario, config.scenario_rotate_hold_s])
	match config.scenario:
		"vehicle_sleep":
			await _vehicle_sleep()
			if config.scenario_rotate_hold_s > 0.0:
				await _orientation()
		"orientation":
			await _orientation()
		"extensibility":
			await _extensibility()
	var failed := results.filter(func(r: Dictionary) -> bool: return r.result == "FAIL").size()
	var passed := results.filter(func(r: Dictionary) -> bool: return r.result == "PASS").size()
	_log("done", "FAIL" if failed > 0 else "PASS", "passed=%d failed=%d" % [passed, failed])
	_write_results()
	finished.emit(results)
	if config.quit_when_done:
		game.world.map_root.visible = false
		Engine.max_fps = 5
		print("BENCH_DONE")
		get_tree().quit()


func _vehicle_sleep() -> void:
	var car: VehicleController = game.world.vehicles[0]
	var player: PlayerController = game.player
	var hud: UIController = game.hud
	var input: MobileInputController = hud.input
	_check("parked_car_asleep", await _until(car.is_asleep, 15.0), "car %s" % _state(car))

	_tap(hud.get_node("SafeArea/Controls/DebugCarButton"))
	await _seconds(1.0)
	var distance := player.global_position.distance_to(car.global_position)
	_check("car_button", distance < 4.0 and car.is_asleep() and input.interact_button.visible,
			"distance %.1f m, car %s, interact button %s" % [distance, _state(car), input.interact_button.visible])

	await _walk_into(car, "walk_into_car_wakes_it")
	_release_stick()
	await _sleeps_again(car, "")

	_tap(input.interact_button)
	await _seconds(0.5)
	_check("get_in_wakes_it", game.vehicle_interaction.is_driving() and not car.is_asleep(), "driving %s, car %s" % [game.vehicle_interaction.is_driving(), _state(car)])
	_press(input.throttle_button, true)
	var fast := await _until(func() -> bool: return car.get_forward_speed() > 5.0, 8.0)
	_check("throttle", fast, "forward speed %.1f m/s" % car.get_forward_speed())
	_press(input.throttle_button, false)
	_press(input.handbrake_button, true)
	await _until(func() -> bool: return car.linear_velocity.length() < 0.3, 10.0)
	_press(input.handbrake_button, false)
	_tap(input.exit_button)
	await _seconds(0.5)
	_check("get_out", not game.vehicle_interaction.is_driving(), "speed when stopped %.2f m/s" % car.linear_velocity.length())
	var slept := await _until(car.is_asleep, 4.0)
	_check("asleep_after_getting_out", slept, "car %s" % _state(car))

	# The Phase 4c defect: standing still against the car on a sloped street.
	_tap(input.interact_button)
	await _seconds(0.5)
	var view_button: TouchButton = hud.get_node("SafeArea/Controls/DebugViewButton")
	while game.vehicle_interaction.is_driving() and not hud.view_name.begins_with("Galata"):
		_tap(view_button)
		await _seconds(0.5)
	await _seconds(2.0)
	_tap(input.exit_button)
	await _seconds(0.5)
	var slope := _slope_degrees(car)
	_check("slope_setup", not game.vehicle_interaction.is_driving() and hud.view_name.begins_with("Galata") and slope >= 2.0,
			"view %s, ground slope under the car %.1f°" % [hud.view_name, slope])
	await _until(car.is_asleep, 4.0)
	await _walk_into(car, "slope_walk_into_car_wakes_it")
	_release_stick()
	await _sleeps_again(car, "slope_")


## Phase 5: MAP to the test district (its spawn, both vehicle types, its
## NPCs), the van (get in, throttle, get out, asleep again), an NPC (punch,
## hit reaction, back on its patrol), MAP back to the first map (the node
## count as before the switches), then the vehicle_sleep steps there.
func _extensibility() -> void:
	var hud: UIController = game.hud
	var input: MobileInputController = hud.input
	var player: PlayerController = game.player
	var first_map: String = game.map_definition.id
	await _seconds(1.0)
	var nodes_before := _node_count()
	await _switch_map("test_district")
	await _seconds(1.0)
	var spawn: Vector3 = game.map_definition.player_spawn_position
	var from_spawn := Vector2(player.global_position.x - spawn.x, player.global_position.z - spawn.z).length()
	_check("map_switch", game.map_definition.id == "test_district" and from_spawn < 0.5 and player.is_on_floor()
			and game.world.vehicles.size() == 2 and game.world.npcs.size() == 3,
			"map %s, player %.2f m from its spawn, vehicles %d, NPCs %d, nodes %d (on %s: %d)" % [game.map_definition.id, from_spawn,
			game.world.vehicles.size(), game.world.npcs.size(), _node_count(), first_map, nodes_before])

	var van: VehicleController = null
	for vehicle in game.world.vehicles:
		if vehicle.scene_file_path != game.vehicle_scene.resource_path:
			van = vehicle
	if van == null:
		_check("van_parked", false, "no second vehicle type on the map")
		return
	_check("van_parked", await _until(van.is_asleep, 10.0), "%s (%s), %s" % [van.name, van.definition.display_name, _state(van)])
	var car_button: TouchButton = hud.get_node("SafeArea/Controls/DebugCarButton")
	for i in game.world.vehicles.size():
		if game.vehicle_interaction.nearby_vehicle() == van:
			break
		_tap(car_button)
		await _seconds(0.5)
	_check("van_walk_up", game.vehicle_interaction.nearby_vehicle() == van and input.interact_button.visible,
			"beside %s, interact button %s" % [van.name, input.interact_button.visible])
	_tap(input.interact_button)
	await _seconds(0.5)
	_check("van_get_in", game.vehicle_interaction.vehicle == van and not van.is_asleep() and game.camera_rig.target == van,
			"driving %s, %s, camera on it %s" % [van.name, _state(van), game.camera_rig.target == van])
	_press(input.throttle_button, true)
	var fast := await _until(func() -> bool: return van.get_forward_speed() > 5.0, 8.0)
	_check("van_throttle", fast, "forward speed %.1f m/s (max %.0f)" % [van.get_forward_speed(), van.definition.max_speed])
	_press(input.throttle_button, false)
	_press(input.handbrake_button, true)
	await _until(func() -> bool: return van.linear_velocity.length() < 0.3, 10.0)
	_press(input.handbrake_button, false)
	_tap(input.exit_button)
	await _seconds(0.5)
	_check("van_get_out", not game.vehicle_interaction.is_driving() and player.visible, "speed when stopped %.2f m/s" % van.linear_velocity.length())
	_check("van_asleep_after_getting_out", await _until(van.is_asleep, 4.0), "%s %s" % [van.name, _state(van)])

	var npc := _nearest_npc()
	if npc == null:
		_check("npc_patrols", false, "no NPC on the player's level")
		return
	var seen_at := npc.global_position
	var arrivals := [0]
	npc.patrol_input.arrived.connect(func(_index: int) -> void: arrivals[0] += 1)
	await _seconds(3.0)
	_check("npc_patrols", npc.global_position.distance_to(seen_at) > 1.0 or arrivals[0] > 0,
			"%s moved %.1f m in 3 s, %d arrivals, state %s" % [npc.name, npc.global_position.distance_to(seen_at), arrivals[0], npc.state_machine.get_state_name()])
	var punches := 0
	var reacted := false
	while punches < 3 and npc.hits == 0:
		await _walk_up_to(npc)
		punches += 1
		_tap(input.punch_button)
		reacted = await _until(func() -> bool: return npc.state_machine.get_state_name() == &"HitReaction", 0.6)
	_check("npc_hit_reaction", npc.hits > 0 and reacted, "%s hit after %d punch(es), state %s" % [npc.name, punches, npc.state_machine.get_state_name()])
	await _seconds(1.0)
	_check("npc_one_hit_per_punch", npc.hits == 1, "%d hit(s) for the punch that landed" % npc.hits)
	var target: int = npc.patrol_input.target_index
	var resumed_at := npc.global_position
	var resumed := await _until(func() -> bool: return npc.patrol_input.target_index != target or npc.global_position.distance_to(resumed_at) > 1.0, 8.0)
	_check("npc_patrol_resumes", resumed and npc.state_machine.get_state_name() != &"HitReaction",
			"%s state %s, moved %.1f m, heading for point %d (was %d)" % [npc.name, npc.state_machine.get_state_name(),
			npc.global_position.distance_to(resumed_at), npc.patrol_input.target_index, target])

	await _switch_map(first_map)
	await _seconds(1.0)
	spawn = game.map_definition.player_spawn_position
	from_spawn = Vector2(player.global_position.x - spawn.x, player.global_position.z - spawn.z).length()
	var nodes_after := _node_count()
	_check("map_back", game.map_definition.id == first_map and from_spawn < 0.5 and player.is_on_floor()
			and game.world.vehicles.size() == game.map_definition.vehicle_spawns.size() and game.world.npcs.size() == game.map_definition.npc_routes.size()
			and nodes_after == nodes_before,
			"map %s, player %.2f m from its spawn, vehicles %d, NPCs %d, nodes %d (before the switches %d)" % [game.map_definition.id, from_spawn,
			game.world.vehicles.size(), game.world.npcs.size(), nodes_after, nodes_before])
	await _vehicle_sleep()


## Taps MAP until the map `id` is loaded (each switch loads synchronously).
func _switch_map(id: String) -> void:
	var button: TouchButton = game.hud.get_node("SafeArea/Controls/DebugMapButton")
	var started := Time.get_ticks_msec()
	for i in game.maps.definitions.size():
		if game.map_definition.id == id:
			break
		var before: MapDefinition = game.map_definition
		_tap(button)
		await _until(func() -> bool: return game.map_definition != before, 60.0)
		await _seconds(0.5)
	_log("map_" + id, "INFO", "loaded after %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))


## The NPC nearest to the player on the player's level (not one on the
## raised plaza), so that walking straight at it reaches it.
func _nearest_npc() -> Npc:
	var player: PlayerController = game.player
	var nearest: Npc = null
	for npc in game.world.npcs:
		if absf(npc.global_position.y - player.global_position.y) > 0.5:
			continue
		if nearest == null or npc.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = npc
	return nearest


## Walks the player to `npc` with the stick, steering at it every physics
## tick, and lets go once within punching reach (at most 15 s).
func _walk_up_to(npc: Npc) -> void:
	var start := _stick_start()
	var size: float = game.hud.input.joystick.joystick_size
	var last := start
	_touch(STICK_FINGER, start, true)
	var until := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until and game.player.global_position.distance_to(npc.global_position) > 0.95:
		var next := start + _stick_toward(npc.global_position) * size
		_drag(STICK_FINGER, last, next)
		last = next
		await get_tree().physics_frame
	_touch(STICK_FINGER, last, false)


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _orientation() -> void:
	var input: MobileInputController = game.hud.input
	var start := _stick_start()
	_touch(STICK_FINGER, start, true)
	_drag(STICK_FINGER, start, start + Vector2(0, -1) * input.joystick.joystick_size)
	await _seconds(0.3)
	_log("rotate_hold", "INFO", "READY hold %.0f s; %s" % [config.scenario_rotate_hold_s, _orientation_state()])
	var until := Time.get_ticks_msec() + int(config.scenario_rotate_hold_s * 1000)
	while Time.get_ticks_msec() < until:
		await _seconds(1.0)
		_log("rotate_sample", "INFO", _orientation_state())
	_touch(STICK_FINGER, start + Vector2(0, -1) * input.joystick.joystick_size, false)
	await _seconds(1.0)
	var speed: float = game.player.get_horizontal_speed()
	_check("rotate_release", input.get_move_vector() == Vector2.ZERO and speed < 0.5,
			"after release: stick %s, speed %.2f m/s; %s" % [input.get_move_vector(), speed, _orientation_state()])


## Holds the stick toward `car` until it wakes (at most 3 s); logs the step.
func _walk_into(car: VehicleController, step: String) -> void:
	_hold_stick_toward(car.global_position)
	var woke := await _until(func() -> bool: return not car.is_asleep(), 3.0)
	_check(step, woke, "player on a wall %s, car %s" % [game.player.is_on_wall(), _state(car)])


## After the player let go of the stick next to `car`: asleep within 4 s and
## still asleep 3 s later while the player stands there.
func _sleeps_again(car: VehicleController, prefix: String) -> void:
	var started := Time.get_ticks_msec()
	var slept := await _until(car.is_asleep, 4.0)
	_check(prefix + "asleep_after_stopping", slept, "after %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	var touching := false
	var stayed := true
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		stayed = stayed and car.is_asleep()
		touching = touching or game.player.is_on_wall()
	_check(prefix + "stays_asleep_beside_it", stayed, "player touched the car %s, distance %.2f m" % [touching, game.player.global_position.distance_to(car.global_position)])


func _hold_stick_toward(target: Vector3) -> void:
	var start := _stick_start()
	_touch(STICK_FINGER, start, true)
	_drag(STICK_FINGER, start, start + _stick_toward(target) * game.hud.input.joystick.joystick_size)


## The stick direction (screen axes, length 1) that walks the player toward
## `target` with the camera where it is.
func _stick_toward(target: Vector3) -> Vector2:
	var to_target: Vector3 = target - game.player.global_position
	var local := Vector3(to_target.x, 0.0, to_target.z).normalized().rotated(Vector3.UP, -game.camera_rig.yaw)
	return Vector2(local.x, local.z)


func _release_stick() -> void:
	var start := _stick_start()
	_touch(STICK_FINGER, start, false)


func _stick_start() -> Vector2:
	var zone: Rect2 = game.hud.input.joystick.get_global_rect()
	return zone.position + zone.size * Vector2(0.4, 0.6)


func _tap(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	_touch(BUTTON_FINGER, at, true)
	_touch(BUTTON_FINGER, at, false)


func _press(control: Control, down: bool) -> void:
	_touch(BUTTON_FINGER, control.get_global_rect().get_center(), down)


## `position` is in HUD canvas units; touch events carry window pixels.
func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_tree().root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var to_window := get_tree().root.get_final_transform()
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to_window * to
	event.relative = to_window.basis_xform(to - from)
	Input.parse_input_event(event)


func _slope_degrees(car: VehicleController) -> float:
	var space := car.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP * 2.0, car.global_position + Vector3.DOWN * 3.0, 1, [car.get_rid()]))
	return rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP)) if not hit.is_empty() else -1.0


## The gravity vector (device sensor; debug builds enable it), the applied
## safe area, and the stick: a 180° turn flips the gravity's x sign.
func _orientation_state() -> String:
	return "gravity %s, safe area %s, stick %s" % [Input.get_gravity().snapped(Vector3.ONE * 0.1), game.hud.safe_rect, game.hud.input.get_move_vector().snapped(Vector2.ONE * 0.01)]


func _state(car: VehicleController) -> String:
	return "asleep" if car.is_asleep() else "awake"


func _check(step: String, passed: bool, detail: String) -> void:
	_log(step, "PASS" if passed else "FAIL", detail)


func _log(step: String, result: String, detail: String) -> void:
	var t := (Time.get_ticks_msec() - _started_ms) / 1000.0
	results.append({"step": step, "result": result, "detail": detail, "t": snappedf(t, 0.1)})
	print("SCENARIO step=%s result=%s t=%.1f %s" % [step, result, t, detail])


## Waits until `predicate` holds or `seconds` pass; returns whether it held.
func _until(predicate: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return predicate.call()


func _seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _write_results() -> void:
	var text := JSON.stringify({"config": config.to_dict(), "profile": game.quality_profile, "startup": game.startup, "scenario": results}, "  ")
	var paths: Array[String] = [PerfBenchmark.RESULTS_PATH]
	if not PerfConfig.external_dir().is_empty():
		paths.append(PerfConfig.external_dir().path_join("bench_results.json"))
	for path in paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(text)
