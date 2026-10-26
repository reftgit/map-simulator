extends "res://tests/test_case.gd"
## The real game scene on the İstanbul • Haliç map: spawn, touch movement, and
## camera collision. Needs assets/istanbul_halic.glb, which is not in Git
## (docs/maps/istanbul_halic/README.md).

const MAP_MODEL := "res://assets/istanbul_halic.glb"
const SPAWN := Vector3(-109.0365, 6.5477, 204.2572)
const SPAWN_FLOOR_Y := 4.5476
## Galata Bridge deck axis toward Karaköy, measured from deck-edge raycasts:
## the 46.5 m deck shifts about 25.5 m east per 50 m north.
const BRIDGE_FORWARD := Vector3(0.454, 0.0, -0.891)

var game: Node
var player: PlayerController
var rig: ThirdPersonCamera
var input: MobileInputController


func skip_reason() -> String:
	if FileAccess.file_exists(MAP_MODEL):
		return ""
	return "%s missing; restore it as in docs/maps/istanbul_halic/README.md" % MAP_MODEL.trim_prefix("res://")


func _setup() -> void:
	game = instantiate("res://game/main.tscn")
	player = game.player
	rig = game.camera_rig
	input = game.hud.input
	await physics_frames(60)


func _stick_start() -> Vector2:
	var rect := input.joystick.get_global_rect()
	return rect.position + rect.size * Vector2(0.4, 0.6)


## Holds the stick in `direction` (screen axes) for `frames` physics frames.
## Returns [state name, horizontal speed] sampled just before release.
func _hold_stick(direction: Vector2, frames: int) -> Array:
	var start := _stick_start()
	var end := start + direction * input.joystick.joystick_size
	touch(0, start, true)
	drag(0, start, end)
	await physics_frames(frames)
	var sample := [player.state_machine.get_state_name(), player.get_horizontal_speed()]
	touch(0, end, false)
	return sample


func _floor_hit(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position - Vector3.UP * 5.0, 1)
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _on_bridge_deck() -> bool:
	var hit := _floor_hit(player.global_position)
	return player.is_on_floor() and not hit.is_empty() and str(hit.collider.get_path()).contains("Galata_Bridge")


func test_map_scene_setup() -> void:
	await _setup()
	var map: Node = game.world.map_root
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.background_mode == Environment.BG_SKY, "sky background")
	check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "color ambient light")
	check(environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "filmic tonemap")
	var sun: DirectionalLight3D = map.get_node("Sun")
	check(sun.shadow_enabled, "sun casts shadows")
	check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "2-split shadows (original demo: 4 splits)")
	check_near(sun.directional_shadow_max_distance, 60.0, 0.01, "shadow distance (original demo: 450 m)")
	check(sun.rotation_degrees.distance_to(Vector3(-43, -32, 0)) < 0.01, "sun angle kept from the original demo")
	var water := map.find_child("Water", true, false) as MeshInstance3D
	check(water != null and water.material_override is ShaderMaterial, "water uses the shader material")
	var colliders := map.find_children("*", "StaticBody3D", true, false)
	check(colliders.size() == 827, "map collision imported (%d static bodies)" % colliders.size())
	var materials := {}
	for node in map.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				materials[material] = material.vertex_color_use_as_albedo
	check(materials.size() == 6, "the GLB's 6 materials are shared (%d unique)" % materials.size())
	check(not materials.values().has(false), "every map material uses vertex colors as albedo")


func test_spawns_on_galata_bridge() -> void:
	await _setup()
	check(player.is_on_floor(), "player settles on a floor")
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "at the walk spawn (%s)" % player.global_position)
	check_near(player.global_position.y, SPAWN_FLOOR_Y, 0.2, "standing on the bridge deck")
	check(_on_bridge_deck(), "floor is Galata Bridge collision")
	check(player.state_machine.get_state_name() == &"Idle", "idle at spawn")
	var forward := -player.global_basis.z
	check(forward.dot(BRIDGE_FORWARD) > 0.995, "spawn faces along the bridge toward Karaköy (forward %s)" % forward)
	check((-rig.global_basis.z).dot(BRIDGE_FORWARD) > 0.99, "camera starts behind the player, looking along the bridge")


func test_touch_walk_on_bridge() -> void:
	await _setup()
	var start := player.global_position
	var sample := await _hold_stick(Vector2.UP, 120)
	var moved := player.global_position - start
	check(sample[0] == &"Walk", "joystick walks (state %s)" % sample[0])
	check_near(sample[1], player.walk_speed, 0.2, "walk speed on the map")
	check(moved.dot(BRIDGE_FORWARD) > 8.0, "walked along the bridge toward Karaköy (moved %s)" % moved)
	await physics_frames(30)
	check(_on_bridge_deck(), "still on the bridge deck after walking (%s)" % player.global_position)
	check(player.state_machine.get_state_name() == &"Idle", "idle after release")


func test_touch_run_on_bridge() -> void:
	await _setup()
	var button := input.run_button.get_global_rect().get_center()
	touch(1, button, true)
	touch(1, button, false)
	var start := player.global_position
	var sample := await _hold_stick(Vector2.UP, 120)
	var moved := player.global_position - start
	check(sample[0] == &"Run", "run button + joystick runs (state %s)" % sample[0])
	check_near(sample[1], player.run_speed, 0.3, "run speed on the map")
	check(moved.dot(BRIDGE_FORWARD) > 14.0, "ran along the bridge toward Karaköy (moved %s)" % moved)
	check(not input.is_run_active(), "run toggle resets when the stick is released")
	await physics_frames(30)
	check(_on_bridge_deck(), "still on the bridge deck after running (%s)" % player.global_position)


func test_debug_viewpoints_stand_on_ground() -> void:
	await _setup()
	var names: Array[String] = game.get_view_names()
	check(names.size() == 3, "spawn + 2 map viewpoints (%s)" % [names])
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	for i in range(1, names.size()):
		game.cycle_debug_view()
		await physics_frames(60)
		var target: Transform3D = game.map_definition.debug_viewpoints[i - 1]
		check(player.is_on_floor(), "%s: standing on a floor" % names[i])
		check(player.global_position.distance_to(target.origin) < 0.5, "%s: at the viewpoint (%s)" % [names[i], player.global_position])
		check(game.hud.view_name == names[i], "overlay shows %s" % names[i])
	check(respawns[0] == 0, "no viewpoint drops the player out of the world")
	game.cycle_debug_view()
	check(game.hud.view_name == "Spawn", "cycling wraps back to the spawn")


func test_perf_categories_cover_every_map_mesh() -> void:
	await _setup()
	var uncategorized: Array[String] = []
	var counts := {}
	for node in game.world.map_root.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var category := RenderSettings.category_of(node.name)
		if category.is_empty():
			uncategorized.append(str(node.name))
		counts[category] = counts.get(category, 0) + 1
	check(uncategorized.is_empty(), "every map mesh has a perf category; missing: %s" % [uncategorized.slice(0, 10)])
	print("     perf categories: %s" % [counts])


func test_no_perf_experiment_by_default() -> void:
	await _setup()
	check(game.find_children("*", "PerfBenchmark", false, false).is_empty(), "no benchmark node without a config")
	var viewport := game.get_viewport()
	check(not viewport.use_occlusion_culling and is_equal_approx(viewport.scaling_3d_scale, 1.0) and is_equal_approx(viewport.mesh_lod_threshold, 1.0), "viewport at defaults")
	check(is_equal_approx(rig.camera.far, 1500.0), "camera far plane at default")
	var sun: DirectionalLight3D = game.world.map_root.get_node("Sun")
	check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "sun shadows at default")
	for node in game.world.map_root.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if not node.visible or node.visibility_range_end > 0.0:
			check(false, "map mesh changed without a config: %s" % node.name)
			break


func test_short_benchmark_on_map() -> void:
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "integration", "occlusion": true,
			"bench": {"warmup_s": 0.2, "measure_s": 0.3, "screenshots": false, "quit_when_done": false}})
	var bench: PerfBenchmark = game.apply_perf_experiment(config)
	var results: Array = await bench.finished
	check(results.size() == 3, "one result per viewpoint (%d)" % results.size())
	for result: Dictionary in results:
		for key in ["view", "avg_fps", "low1_fps", "min_fps", "frames", "draw_calls", "primitives", "objects", "video_mem_mb", "static_mem_mb", "experiment", "renderer", "physics_ms", "physics_p99_ms", "in_vehicle", "vehicles_asleep"]:
			check(result.has(key), "result has %s" % key)
		check(result.vehicles_asleep >= 0.0 and result.vehicles_asleep <= 1.0, "share of frames with the parked car asleep (%s)" % result.get("vehicles_asleep"))
		check(result.physics_ms > 0.0 and result.physics_p99_ms >= result.physics_ms, "physics tick time recorded (%s / %s ms)" % [result.get("physics_ms"), result.get("physics_p99_ms")])
		check(result.in_vehicle == false, "on foot")
	var report: Dictionary = game.render_settings.occluder_report
	check(report.get("occluders", 0) > 600, "occluders available for the map (%s)" % [report])
	check(results[0].get("profile") == "none", "results record the profile")
	check(FileAccess.file_exists(PerfBenchmark.RESULTS_PATH), "results file written")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))


func test_profiles_switch_on_the_real_map() -> void:
	await _setup()
	check(game.quality_profile == "none", "desktop starts without a profile")
	var saved_fps := Engine.max_fps
	var effective: Dictionary = game.set_quality_profile("low")
	var viewport := game.get_viewport()
	check(effective.max_fps == 30 and Engine.max_fps == 30, "low: 30 FPS cap")
	check(viewport.use_occlusion_culling and is_equal_approx(viewport.scaling_3d_scale, 0.6), "low: occlusion and 0.6 scale")
	check(is_equal_approx(rig.camera.far, 400.0), "low: 400 m far plane")
	var detail: Array[Node] = game.world.map_root.get_node("Model").find_children("Detail_*", "MeshInstance3D", true, false)
	check(not detail.is_empty() and is_equal_approx(detail[0].visibility_range_end, 100.0), "low: 100 m facade detail range")
	game.set_quality_profile("high")
	check(Engine.max_fps == 60 and is_equal_approx(viewport.scaling_3d_scale, 1.0) and is_equal_approx(rig.camera.far, 1500.0), "high: 60 FPS cap, full scale, default far plane")
	check(is_equal_approx(detail[0].visibility_range_end, 200.0), "high: 200 m facade detail range")
	game.set_quality_profile("none")
	check(Engine.max_fps == saved_fps and not viewport.use_occlusion_culling and is_equal_approx(detail[0].visibility_range_end, 0.0), "none: defaults restored")
	Engine.max_fps = saved_fps


## Union of all occluder vertices in map space.
func _occluder_bounds(holder: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for instance: OccluderInstance3D in holder.find_children("*", "OccluderInstance3D", true, false):
		for vertex in (instance.occluder as ArrayOccluder3D).vertices:
			var point := instance.transform * vertex
			if first:
				bounds = AABB(point, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	return bounds


func test_baked_occluders_match_runtime_build() -> void:
	await _setup()
	var path: String = game.map_definition.occluders_path
	check(ResourceLoader.exists(path), "baked occluders exist at %s" % path)
	var baked: Node = (load(path) as PackedScene).instantiate()
	var map_root: Node = game.world.map_root
	var runtime := RenderSettings.build_occluders(map_root, RenderSettings.meshes_by_category(map_root))
	var baked_stats := RenderSettings.occluder_stats(baked)
	check(baked_stats == RenderSettings.occluder_stats(runtime), "same occluders and triangles: baked %s, runtime %s" % [baked_stats, RenderSettings.occluder_stats(runtime)])
	var a := _occluder_bounds(baked)
	var b := _occluder_bounds(runtime)
	check(a.position.distance_to(b.position) < 0.01 and a.end.distance_to(b.end) < 0.01, "same extent: %s vs %s" % [a, b])
	baked.free()
	runtime.free()


func test_profile_uses_baked_occluders() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	game.set_quality_profile("high")
	var report: Dictionary = game.render_settings.occluder_report
	check(report.get("source") == "baked" and report.get("occluders") == 643 and report.get("triangles") == 317518, "occluders loaded from the baked file (%s)" % [report])
	game.set_quality_profile("none")
	Engine.max_fps = saved_fps


func test_falling_into_water_respawns() -> void:
	await _setup()
	# The deck ends about 6 m west of the spawn; railings have no collision and
	# the water (y = 0) has none either, so a fall drops below the kill height.
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	player.teleport(Transform3D(Basis.IDENTITY, SPAWN + Vector3(-15, -2, 0)))
	await physics_frames(120)
	check(respawns[0] == 1, "one respawn after falling into the water (got %d)" % respawns[0])
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.5, "back at the walk spawn (%s)" % player.global_position)
	check(player.is_on_floor(), "standing on the bridge again")


func test_movement_follows_camera_direction() -> void:
	await _setup()
	# Turn the camera about 90 degrees to the left with a look drag.
	var rect := input.look_area.get_global_rect()
	var look := rect.position + rect.size * Vector2(0.5, 0.4)
	var pixels := (PI * 0.5) / input.look_sensitivity * input.get_viewport_rect().size.y
	touch(1, look, true)
	drag(1, look, look - Vector2(pixels, 0))
	var yaw_before := rig.yaw
	touch(1, look - Vector2(pixels, 0), false)
	await process_frames(2)
	check_near(angle_difference(yaw_before, rig.yaw), PI * 0.5, 0.01, "camera turned left")
	var start := player.global_position
	await _hold_stick(Vector2.UP, 40)
	var moved := player.global_position - start
	var camera_forward := -rig.global_basis.z
	var flat := Vector2(moved.x, moved.z).normalized().dot(Vector2(camera_forward.x, camera_forward.z).normalized())
	check(flat > 0.9, "stick up moves where the camera looks (alignment %.2f, moved %s)" % [flat, moved])


func test_camera_stays_out_of_geometry_on_streets() -> void:
	await _setup()
	var space := player.get_world_3d().direct_space_state
	var points: Array[Vector3] = []
	# Ground-level points (streets, squares) between the buildings of Karaköy
	# and Galata, north of the bridge. Roads have no collider of their own; the
	# walkable surface is the Ground_* terrain.
	for x in range(-150, 151, 25):
		for z in range(-250, 51, 25):
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -10, z), 1)
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and str(hit.collider.get_path()).contains("Ground_"):
				points.append(hit.position)
	check(points.size() >= 10, "found street sample points (%d)" % points.size())
	var samples := 0
	var shortened := 0
	var obstructed: Array[String] = []
	for point in points.slice(0, 24):
		player.teleport(Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.05))
		rig.snap_behind_target()
		await physics_frames(4)
		for step in 8:
			rig.yaw = TAU * step / 8.0
			rig.add_look(Vector2.ZERO)
			await physics_frames(3)
			await process_frames(1)
			samples += 1
			if rig.get_arm_length() < rig.profile.distance - 0.3:
				shortened += 1
			var segment := PhysicsRayQueryParameters3D.create(rig.global_position, rig.camera.global_position, 1)
			segment.exclude = [player.get_rid()]
			if not space.intersect_ray(segment).is_empty():
				obstructed.append("%s yaw %d" % [point, step])
	print("     camera samples=%d shortened_by_walls=%d obstructed=%d" % [samples, shortened, obstructed.size()])
	check(obstructed.is_empty(), "no camera position hidden behind or inside geometry: %s" % [obstructed])
	check(shortened > 0, "spring arm engaged near buildings at least once")


func _tap(button: TouchButton, index: int) -> void:
	var point := button.get_global_rect().get_center()
	touch(index, point, true)
	touch(index, point, false)


func _state_sequence(ticks: int) -> Array[StringName]:
	var seen: Array[StringName] = []
	for i in ticks:
		await tree.physics_frame
		var state := player.state_machine.get_state_name()
		if seen.is_empty() or seen.back() != state:
			seen.append(state)
	return seen


func test_roll_on_bridge_then_walk() -> void:
	await _setup()
	var roll: RollState = player.state_machine.get_node("Roll")
	var start := player.global_position
	var stick := _stick_start()
	var up := stick + Vector2.UP * input.joystick.joystick_size
	touch(0, stick, true)
	drag(0, stick, up)
	_tap(input.roll_button, 1)
	var ticks := 0
	while player.state_machine.get_state_name() != &"Roll" and ticks < 5:
		await tree.physics_frame
		ticks += 1
	check(player.state_machine.get_state_name() == &"Roll", "roll button + stick rolls on the bridge")
	while player.state_machine.get_state_name() == &"Roll" and ticks < 120:
		await tree.physics_frame
		ticks += 1
	var rolled := player.global_position - start
	check(rolled.dot(BRIDGE_FORWARD) > roll.distance - 0.5, "rolled along the bridge toward Karaköy (moved %s)" % rolled)
	check(_on_bridge_deck(), "still on the deck after the roll (%s)" % player.global_position)
	check(player.state_machine.get_state_name() == &"Walk", "walking after the roll with the stick held (%s)" % player.state_machine.get_state_name())
	await physics_frames(60)
	check_near(player.get_horizontal_speed(), player.walk_speed, 0.2, "walk speed after the roll")
	var walked := player.global_position - start - rolled
	check(walked.dot(BRIDGE_FORWARD) > 3.0, "kept walking along the bridge (moved %s)" % walked)
	touch(0, up, false)
	await physics_frames(30)
	check(player.state_machine.get_state_name() == &"Idle" and _on_bridge_deck(), "idle on the deck after release")


func test_punch_on_bridge_then_walk() -> void:
	await _setup()
	_tap(input.punch_button, 1)
	var seen := await _state_sequence(40)
	check(seen == ([&"Punch", &"Idle"] as Array[StringName]) or seen == ([&"Idle", &"Punch", &"Idle"] as Array[StringName]), "punch then Idle (%s)" % [seen])
	var sample := await _hold_stick(Vector2.UP, 90)
	check(sample[0] == &"Walk" and absf(sample[1] - player.walk_speed) < 0.2, "walks normally after the punch (%s)" % [sample])


func test_roll_off_the_deck_edge_respawns() -> void:
	await _setup()
	# Toward the western deck edge, across the deck axis; railings have no collision.
	var across := Vector3(-BRIDGE_FORWARD.z, 0.0, BRIDGE_FORWARD.x) * -1.0
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	player.teleport(Transform3D(Basis(Vector3.UP, atan2(-across.x, -across.z)), SPAWN + across * 2.0))
	await physics_frames(30)
	check(_on_bridge_deck(), "starts on the deck near its edge")
	_tap(input.roll_button, 1)
	var left_floor := false
	for i in 240:
		await tree.physics_frame
		if not player.is_on_floor() and respawns[0] == 0:
			left_floor = true
		if respawns[0] > 0:
			break
	check(left_floor, "the roll carried the body off the deck")
	check(respawns[0] == 1, "fell into the water and respawned (%d)" % respawns[0])
	await physics_frames(30)
	check(player.state_machine.get_state_name() == &"Idle" and _on_bridge_deck(), "idle on the deck at the spawn after the respawn")


func test_training_dummy_is_hit_once_per_punch() -> void:
	await _setup()
	check(game.training_dummy == null, "no dummy until requested")
	game.toggle_training_dummy()
	await physics_frames(5)
	var dummy: TrainingDummy = game.training_dummy
	check(dummy != null and dummy.is_inside_tree(), "dummy created")
	var spawn: Transform3D = game.world.get_spawn_transform()
	var offset := dummy.global_position - player.global_position
	check(Vector2(offset.x, offset.z).length() < game.DUMMY_OFFSET.length() + 0.1, "dummy next to the spawn (%s)" % offset)
	check((-player.global_basis.z).dot(Vector3(offset.x, 0, offset.z).normalized()) > 0.95, "dummy ahead of the spawn facing")
	check_near(dummy.global_position.y, SPAWN_FLOOR_Y, 0.2, "dummy stands on the deck")
	var counted := [0]
	dummy.hit.connect(func(_count: int) -> void: counted[0] += 1)
	_tap(input.punch_button, 1)
	await physics_frames(40)
	check(dummy.hits == 1 and counted[0] == 1, "one punch, one hit (%d)" % dummy.hits)
	_tap(input.punch_button, 1)
	await physics_frames(40)
	check(dummy.hits == 2, "second punch, second hit (%d)" % dummy.hits)
	check(player.global_position.distance_to(spawn.origin - Vector3(0, spawn.origin.y - player.global_position.y, 0)) < 0.3, "punching does not move the player or push it back")
	game.toggle_training_dummy()
	await physics_frames(2)
	check(game.training_dummy == null and not is_instance_valid(dummy), "second toggle removes the dummy")


func _vehicle() -> VehicleController:
	return game.world.vehicles[0]


## Teleports the player next to the vehicle's driver door and gets in.
func _get_in() -> void:
	var vehicle := _vehicle()
	player.teleport(Transform3D(Basis.IDENTITY, vehicle.to_global(Vector3(2.2, 0.2, 0))))
	await physics_frames(20)
	_tap(input.interact_button, 1)
	await physics_frames(3)


func test_vehicle_parked_on_a_flat_karakoy_street() -> void:
	await _setup()
	check(game.map_definition.vehicle_spawns.size() == 1 and game.world.vehicles.size() == 1, "one vehicle spawned from the map definition")
	var vehicle := _vehicle()
	await physics_frames(60)
	var spawn: Transform3D = game.map_definition.vehicle_spawns[0]
	check(Vector2(vehicle.global_position.x - spawn.origin.x, vehicle.global_position.z - spawn.origin.z).length() < 0.3, "at its spawn (%s)" % vehicle.global_position)
	check(vehicle.global_basis.y.dot(Vector3.UP) > 0.99, "upright")
	check(vehicle.linear_velocity.length() < 0.1, "at rest")
	check(vehicle.wheels.all(func(wheel: VehicleWheel3D) -> bool: return wheel.is_in_contact()), "all four wheels on the ground")
	var ground := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(vehicle.global_position + Vector3.UP * 3, vehicle.global_position + Vector3.DOWN * 3, 1))
	check(not ground.is_empty() and str(ground.collider.get_path()).contains("Ground_"), "on the Ground_ terrain (%s)" % [ground.get("collider")])
	var slept := 0
	while not vehicle.is_asleep() and slept < 300:
		await tree.physics_frame
		slept += 1
	check(vehicle.is_asleep(), "asleep at its spawn (P2), %d ticks after the checks" % slept)
	var parked := vehicle.global_position
	await physics_frames(120)
	check(vehicle.is_asleep() and vehicle.global_position.distance_to(parked) < 0.001, "stays asleep and in place on the street")
	check((-spawn.basis.z).dot(vehicle.global_basis.z) > 0.999, "faces along the street (the spawn's -Z)")
	var to_bridge := Vector2(vehicle.global_position.x - SPAWN.x, vehicle.global_position.z - SPAWN.z).length()
	check(to_bridge > 150.0, "well away from the bridge spawn (%.0f m)" % to_bridge)


func test_vehicle_drives_five_seconds_along_the_street() -> void:
	await _setup()
	var vehicle := _vehicle()
	for i in 300:
		if vehicle.is_asleep():
			break
		await tree.physics_frame
	check(vehicle.is_asleep(), "starts from a sleeping car")
	await _get_in()
	check(game.vehicle_interaction.is_driving() and not vehicle.is_asleep(), "in the vehicle, awake")
	var start := vehicle.global_position
	_tap(input.throttle_button, 2)
	touch(2, input.throttle_button.get_global_rect().get_center(), true)
	var lowest := 1.0
	for i in 300:
		await tree.physics_frame
		lowest = minf(lowest, vehicle.global_basis.y.dot(Vector3.UP))
	var travelled := Vector2(vehicle.global_position.x - start.x, vehicle.global_position.z - start.z).length()
	var speed := vehicle.get_forward_speed()
	touch(2, input.throttle_button.get_global_rect().get_center(), false)
	print("     vehicle 5 s full throttle: %.1f m, end speed %.1f m/s, lowest up %.3f" % [travelled, speed, lowest])
	check(travelled >= 35.0, "at least 35 m in 5 s of throttle (%.1f m)" % travelled)
	check(speed > 10.0, "still accelerating at the end, not stuck on a kerb or wall (%.1f m/s)" % speed)
	check(lowest > 0.95, "stays upright (%.3f)" % lowest)
	var heading := Vector2(vehicle.global_basis.z.x, vehicle.global_basis.z.z).normalized()
	var spawn_forward := -(game.map_definition.vehicle_spawns[0] as Transform3D).basis.z
	check(heading.dot(Vector2(spawn_forward.x, spawn_forward.z)) > 0.98, "kept straight along the street")


func test_vehicle_reset_takes_the_driver_along() -> void:
	await _setup()
	await _get_in()
	var vehicle := _vehicle()
	vehicle.global_position = Vector3(vehicle.global_position.x, game.map_definition.kill_height - 5.0, vehicle.global_position.z)
	await physics_frames(3)
	var spawn: Transform3D = game.map_definition.vehicle_spawns[0]
	check(Vector2(vehicle.global_position.x - spawn.origin.x, vehicle.global_position.z - spawn.origin.z).length() < 0.5, "vehicle back at its spawn")
	check(game.vehicle_interaction.is_driving(), "still driving after the reset")
	check(player.global_position.distance_to(vehicle.seat.global_position) < 0.05, "the driver went along")
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	await physics_frames(30)
	check(respawns[0] == 0, "the hidden player is not respawned by the world while driving")


func test_view_cycle_moves_the_vehicle_while_driving() -> void:
	await _setup()
	await _get_in()
	game.cycle_debug_view()
	await physics_frames(60)
	var vehicle := _vehicle()
	var target: Transform3D = game.map_definition.debug_viewpoints[0]
	check(Vector2(vehicle.global_position.x - target.origin.x, vehicle.global_position.z - target.origin.z).length() < 0.5, "vehicle moved to the viewpoint and stays there on the slope (%s)" % vehicle.global_position)
	var heading := Vector2(vehicle.global_basis.z.x, vehicle.global_basis.z.z).normalized()
	check(heading.dot(Vector2(-target.basis.z.x, -target.basis.z.z).normalized()) > 0.99, "facing the viewpoint direction")
	check(game.vehicle_interaction.is_driving() and rig.target == vehicle, "still driving, camera on the vehicle")


func test_short_benchmark_in_the_vehicle() -> void:
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "integration_vehicle",
			"bench": {"warmup_s": 0.5, "measure_s": 0.5, "screenshots": false, "quit_when_done": false, "in_vehicle": true}})
	var bench: PerfBenchmark = game.apply_perf_experiment(config)
	var results: Array = await bench.finished
	check(results.size() == 3 and results.all(func(result: Dictionary) -> bool: return result.in_vehicle), "three in-vehicle results")
	check(game.vehicle_interaction.is_driving() and rig.target == _vehicle(), "measured from the driver's seat, camera on the vehicle")
	var last_view: Transform3D = game.map_definition.debug_viewpoints[-1]
	check(Vector2(_vehicle().global_position.x - last_view.origin.x, _vehicle().global_position.z - last_view.origin.z).length() < 1.0, "vehicle moved to the last viewpoint (%s)" % _vehicle().global_position)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))


func test_debug_car_button_walks_up_to_the_vehicle() -> void:
	await _setup()
	var button: TouchButton = game.hud.get_node("SafeArea/Controls/DebugCarButton")
	check(button.visible == OS.is_debug_build(), "CAR button only in debug builds")
	_tap(button, 1)
	await physics_frames(30)
	check(player.is_on_floor(), "standing after the walk-up")
	check(input.interact_button.visible, "vehicle in reach: interact button shown")
	_tap(input.interact_button, 1)
	await physics_frames(3)
	check(game.vehicle_interaction.is_driving(), "can get in right away")


func _write_perf_bench_file() -> void:
	var file := FileAccess.open(PerfConfig.USER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"experiment": "gating", "profile": "none",
			"bench": {"warmup_s": 0.2, "measure_s": 0.3, "screenshots": false, "quit_when_done": false}}))
	file.close()


func test_release_perf_build_runs_benchmarks_without_debug_ui() -> void:
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 1
	_write_perf_bench_file()
	await _setup()
	check(not FileAccess.file_exists(PerfConfig.USER_PATH), "experiment file read and consumed")
	var benches := game.find_children("*", "PerfBenchmark", false, false)
	check(benches.size() == 1, "benchmark started")
	if benches.size() == 1 and (benches[0] as PerfBenchmark).results.size() < 3:
		await (benches[0] as PerfBenchmark).finished
	if benches.size() == 1:
		check((benches[0] as PerfBenchmark).results.size() == 3, "benchmark produced results")
	check(game.startup.has("debug_build") and game.startup.has("physics_ticks"), "STARTUP data with build info (%s)" % [game.startup.keys()])
	check(game.startup.has("vehicles") and game.startup.has("display_refresh_rate"), "STARTUP data with vehicle state and display refresh rate (%s)" % [game.startup.keys()])
	check(not game.hud.get_node("SafeArea/DebugLabel").visible and not game.hud.get_node("SafeArea/Controls/DebugCarButton").visible, "no debug overlay or buttons")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))
	BuildFeatures.reset_overrides()


func test_normal_release_ignores_experiments() -> void:
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 0
	_write_perf_bench_file()
	await _setup()
	check(FileAccess.file_exists(PerfConfig.USER_PATH), "experiment file left alone")
	check(game.find_children("*", "PerfBenchmark", false, false).is_empty(), "no benchmark")
	check(game.startup.is_empty(), "no STARTUP measurement")
	check(not game.hud.get_node("SafeArea/DebugLabel").visible, "no debug overlay")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfConfig.USER_PATH))
	BuildFeatures.reset_overrides()


func test_runtime_experiment_keys_apply_on_the_map() -> void:
	await _setup()
	var bodies: Array[Node] = game.world.map_root.find_children("*", "StaticBody3D", true, false)
	var config := PerfConfig.from_dict({"experiment": "runtime_keys", "profile": "none",
			"runtime": {"physics_ticks": 30, "physics_interpolation": false, "player_physics": false, "vehicles": false, "collider_radius": 100},
			"bench": {"warmup_s": 0.2, "measure_s": 0.4, "screenshots": false, "quit_when_done": false, "views": ["Spawn"]}})
	var bench: PerfBenchmark = game.apply_perf_experiment(config)
	var results: Array = await bench.finished
	check(Engine.physics_ticks_per_second == 30, "30 Hz physics applied")
	check(not tree.physics_interpolation, "interpolation off")
	check(not player.is_physics_processing(), "player physics paused")
	check(game.world.vehicles.all(func(v: VehicleController) -> bool: return v.process_mode == Node.PROCESS_MODE_DISABLED), "parked vehicles out of the simulation")
	var active: int = bodies.filter(func(b: Node) -> bool: return b.process_mode != Node.PROCESS_MODE_DISABLED).size()
	check(active > 0 and active < bodies.size(), "only colliders within 100 m stay on (%d of %d)" % [active, bodies.size()])
	var result: Dictionary = results[0]
	for key in ["process_ms", "process_p99_ms", "frame_p50_ms", "frame_p99_ms", "frame_hist_ms", "long_frames"]:
		check(result.has(key), "result has %s" % key)
	Engine.physics_ticks_per_second = 60
	tree.physics_interpolation = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))


func test_vehicle_sleep_runtime_key() -> void:
	await _setup()
	var vehicle := _vehicle()
	game.apply_runtime_settings({"vehicle_sleep": false})
	await physics_frames(180)
	check(not vehicle.is_asleep() and not vehicle.definition.sleep_when_parked, "parking sleep off: the parked car stays awake")
	var shared: VehicleDefinition = load("res://game/vehicle/definitions/compact_car.tres")
	check(shared.sleep_when_parked, "the shared definition resource is unchanged")
	game.apply_runtime_settings({"vehicle_sleep": true})
	var ticks := 0
	while not vehicle.is_asleep() and ticks < 300:
		await tree.physics_frame
		ticks += 1
	check(vehicle.is_asleep(), "parking sleep on again: asleep after %d ticks" % ticks)
