extends "res://tests/test_case.gd"
## Gameplay on a map made by the import tool (Phase 6a, docs/MAP_CONTRACT.md),
## with the tool's placement only: the spawn on the ground, a 10 s walk
## without falling or getting stuck, punch and roll, the vehicle parked flat
## and driving, the NPC patrolling, the quality profiles, a map switch
## without leaks, the device scenario. Each imported map's test file extends
## this; it is skipped while the map's generated model is missing.

var game: Node
var player: PlayerController
var input: MobileInputController
var definition: MapDefinition


## The MapDefinition the import tool wrote.
func definition_path() -> String:
	return ""


## How to regenerate the map (for the skip message).
func regenerate_hint() -> String:
	return ""


## Mesh count per category the import gave.
func expected_categories() -> Dictionary:
	return {}


func skip_reason() -> String:
	if not ResourceLoader.exists(definition_path()):
		return "%s missing; %s" % [definition_path(), regenerate_hint()]
	if not (load(definition_path()) as MapDefinition).is_available():
		return "the generated model of %s is missing; %s" % [definition_path().get_file(), regenerate_hint()]
	return ""


## The game on this map, with a registry of this map and the test district
## (the registry's own entries are not needed and might be missing).
func _setup() -> void:
	definition = load(definition_path()) as MapDefinition
	var registry := MapRegistry.new()
	registry.definitions.assign([definition, MapRegistry.load_default().find("test_district")])
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.maps = registry
	game.requested_map = definition.id
	add_node(game)
	player = game.player
	input = game.hud.input
	await physics_frames(60)


func _floor_hit(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position - Vector3.UP * 5.0, 1)
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _category_under(position: Vector3) -> String:
	var hit := _floor_hit(position)
	if hit.is_empty() or not (hit.collider as Node).get_parent():
		return ""
	return definition.category_rules.category_of((hit.collider as Node).get_parent())


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tap(button: TouchButton, index: int) -> void:
	var point := button.get_global_rect().get_center()
	touch(index, point, true)
	touch(index, point, false)


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func test_loads_and_spawns_on_the_ground() -> void:
	await _setup()
	check(game.map_definition.id == definition.id, "%s loaded (%s)" % [definition.id, game.map_definition.id])
	check(_flat_distance(player.global_position, definition.player_spawn_position) < 0.3, "the player at the spawn (%s)" % player.global_position)
	check(player.is_on_floor() and _category_under(player.global_position) == "ground", "standing on ground (%s)" % _category_under(player.global_position))
	var map: Node = game.world.map_root
	check(map.get_node("WorldEnvironment").environment.background_mode == Environment.BG_SKY and (map.get_node("Sun") as DirectionalLight3D).shadow_enabled, "sky and sun")
	var counts := {}
	for node in map.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var category: String = definition.category_rules.category_of(node)
		counts[category] = counts.get(category, 0) + 1
	check(counts == expected_categories(), "categories as imported: %s (expected %s)" % [counts, expected_categories()])
	for i in definition.debug_viewpoints.size():
		var view: Transform3D = definition.debug_viewpoints[i]
		check(_category_under(view.origin) == "ground", "%s on ground" % definition.debug_viewpoint_names[i])


func test_walks_ten_seconds_without_falling_or_sticking() -> void:
	await _setup()
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	var start := player.global_position
	var stick := input.joystick.get_global_rect().position + input.joystick.get_global_rect().size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -1) * input.joystick.joystick_size)
	var on_floor := 0
	var lowest := start.y
	for tick in 600:
		await tree.physics_frame
		on_floor += int(player.is_on_floor())
		lowest = minf(lowest, player.global_position.y)
	touch(0, stick + Vector2(0, -1) * input.joystick.joystick_size, false)
	var walked := _flat_distance(player.global_position, start)
	print("     %s: walked %.1f m in 10 s, on a floor %d of 600 ticks, lowest %.1f m below the spawn" % [definition.id, walked, on_floor, start.y - lowest])
	check(respawns[0] == 0, "no fall out of the map (%d respawns)" % respawns[0])
	check(on_floor >= 540, "on a floor at least 90 %% of the time (%d of 600 ticks)" % on_floor)
	check(walked >= 18.0, "not stuck: at least 18 m along the spawn's clear walk (%.1f m)" % walked)


func test_punch_and_roll() -> void:
	await _setup()
	var states: Array[StringName] = []
	_tap(input.punch_button, 1)
	for tick in 40:
		await tree.physics_frame
		if states.is_empty() or states.back() != player.state_machine.get_state_name():
			states.append(player.state_machine.get_state_name())
	check(&"Punch" in states and states.back() == &"Idle", "punch, then idle: %s" % [states])
	var start := player.global_position
	_tap(input.roll_button, 1)
	await physics_frames(3)
	check(player.state_machine.get_state_name() == &"Roll", "rolling (%s)" % player.state_machine.get_state_name())
	await physics_frames(50)
	check(_flat_distance(player.global_position, start) > 4.0 and player.is_on_floor(), "rolled %.1f m and landed on a floor" % _flat_distance(player.global_position, start))


func test_vehicle_parks_flat_and_drives() -> void:
	await _setup()
	check(game.world.vehicles.size() == 1, "one vehicle from the map definition")
	var vehicle: VehicleController = game.world.vehicles[0]
	for i in 300:
		if vehicle.is_asleep():
			break
		await tree.physics_frame
	var spawn: Transform3D = definition.vehicle_spawns[0]
	check(vehicle.is_asleep() and _flat_distance(vehicle.global_position, spawn.origin) < 0.3, "asleep at its spawn (%s)" % vehicle.global_position)
	check(vehicle.global_basis.y.dot(Vector3.UP) > cos(deg_to_rad(5.0)), "level within 5° (%.4f)" % vehicle.global_basis.y.dot(Vector3.UP))
	check(vehicle.wheels.all(func(wheel: VehicleWheel3D) -> bool: return wheel.is_in_contact()), "all wheels on the ground")
	player.teleport(Transform3D(Basis.IDENTITY, vehicle.to_global(Vector3(2.2, 0.2, 0))))
	await physics_frames(20)
	_tap(input.interact_button, 1)
	await physics_frames(3)
	check(game.vehicle_interaction.is_driving(), "got in")
	var start := vehicle.global_position
	touch(2, input.throttle_button.get_global_rect().get_center(), true)
	var lowest := 1.0
	for i in 300:
		await tree.physics_frame
		lowest = minf(lowest, vehicle.global_basis.y.dot(Vector3.UP))
	touch(2, input.throttle_button.get_global_rect().get_center(), false)
	var travelled := _flat_distance(vehicle.global_position, start)
	print("     %s: 5 s of throttle: %.1f m, end speed %.1f m/s" % [definition.id, travelled, vehicle.get_forward_speed()])
	check(travelled >= 15.0, "at least 15 m in 5 s of throttle (%.1f m)" % travelled)
	check(lowest > 0.95, "stays upright (%.3f)" % lowest)


func test_npc_patrols() -> void:
	await _setup()
	check(game.world.npcs.size() == definition.npc_routes.size() and not game.world.npcs.is_empty(), "an NPC per route (%d)" % game.world.npcs.size())
	var npc: Npc = game.world.npcs[0]
	var arrivals := [0]
	npc.patrol_input.arrived.connect(func(_index: int) -> void: arrivals[0] += 1)
	var start := npc.global_position
	var farthest := 0.0
	for tick in 600:
		await tree.physics_frame
		farthest = maxf(farthest, _flat_distance(npc.global_position, start))
	check(arrivals[0] >= 1 and farthest > 3.0, "walked its route in 10 s: %d arrivals, %.1f m from its start at most" % [arrivals[0], farthest])
	var hit := _floor_hit(npc.global_position)
	check(not hit.is_empty() and absf(npc.global_position.y - (hit.position as Vector3).y) < 0.3, "feet on the floor (%s)" % npc.global_position)


func test_quality_profiles_apply() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var groups: Dictionary = definition.category_rules.meshes_by_category(game.world.map_root)
	var ranged: Array = []
	for category in ["trees", "lamps", "decor", "facade_detail"]:
		ranged.append_array(groups[category])
	var ranges := func(expected: float) -> bool:
		return ranged.all(func(node: MeshInstance3D) -> bool: return is_equal_approx(node.visibility_range_end, expected))
	game.set_quality_profile("low")
	check(not ranged.is_empty() and ranges.call(100.0) and Engine.max_fps == 30, "low: 100 m on the %d meshes with ranges" % ranged.size())
	check(game.render_settings.occluder_report.get("source") == "baked", "the baked occluders (%s)" % [game.render_settings.occluder_report])
	game.set_quality_profile("high")
	check(ranges.call(200.0) and Engine.max_fps == 60, "high: 200 m")
	game.set_quality_profile("none")
	check(ranges.call(0.0), "none: the scene defaults")
	Engine.max_fps = saved_fps


func test_map_switch_without_leaks() -> void:
	await _setup()
	await physics_frames(10)
	var before := _node_count()
	var released := []
	game.world.map_unloaded.connect(func(_id: String) -> void:
		released.append(not ResourceLoader.has_cached(definition.scene_path) and not ResourceLoader.has_cached(definition.required_files[0])), CONNECT_ONE_SHOT)
	check(await game.switch_map(game.maps.find("test_district")), "switched to the test district")
	check(released == [true], "the map scene and model released before the next map loaded (%s)" % [released])
	check(await game.switch_map(definition), "switched back")
	await physics_frames(30)
	check(_node_count() == before, "node count back where it was (%d, before %d)" % [_node_count(), before])
	check(_flat_distance(player.global_position, definition.player_spawn_position) < 0.3 and player.is_on_floor(), "back at the spawn")


func test_device_scenario_vehicle_sleep() -> void:
	# The generalized device scenario (Phase 6a) on this map's own points.
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "scenario_test", "scenario": {"name": "vehicle_sleep", "quit_when_done": false}})
	var scenario: DeviceScenario = game.start_scenario(config)
	var results: Array = await scenario.finished
	var steps: Array[String] = []
	for result: Dictionary in results:
		steps.append(result.step)
		check(result.result != "FAIL", "%s: %s (%s)" % [result.step, result.result, result.detail])
	for step in ["parked_car_asleep", "car_button", "walk_into_car_wakes_it", "get_in_wakes_it", "throttle", "get_out", "asleep_after_getting_out", "done"]:
		check(step in steps, "step %s ran" % step)
	if definition.sloped_viewpoint >= 0:
		check("slope_setup" in steps and "slope_stays_asleep_beside_it" in steps, "the slope steps ran on the map's sloped viewpoint")
	else:
		check("slope_skipped" in steps, "no sloped viewpoint: the slope steps are skipped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))
