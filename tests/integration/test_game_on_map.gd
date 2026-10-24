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
