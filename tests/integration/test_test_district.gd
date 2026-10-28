extends "res://tests/test_case.gd"
## The game on the test district (Phase 5), the second map: built from Godot
## primitives only, so these tests run without the İstanbul GLB.

const SPAWN := Vector3(0, 0, 50)

var game: Node
var player: PlayerController
var input: MobileInputController


func _setup() -> void:
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.requested_map = "test_district"
	add_node(game)
	player = game.player
	input = game.hud.input
	await physics_frames(60)


func _floor_hit(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 3.0, position + Vector3.DOWN * 5.0, 1)
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func test_loads_from_the_registry() -> void:
	await _setup()
	check(game.map_definition.id == "test_district" and game.world.map_root.name == &"TestDistrict", "test district loaded (%s)" % game.map_definition.id)
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "player at the spawn (%s)" % player.global_position)
	check(player.is_on_floor() and absf(player.global_position.y) < 0.05, "standing on the ground slab")
	check((-player.global_basis.z).dot(Vector3.FORWARD) > 0.999, "facing north along the street")
	check((-game.camera_rig.global_basis.z).dot(Vector3.FORWARD) > 0.99, "camera behind the player")
	check(game.hud.map_name == "test_district", "the overlay names the map")
	check(game.get_view_names() == (["Spawn", "Plaza, facing north", "Crossing, facing west"] as Array[String]), "viewpoints from the definition (%s)" % [game.get_view_names()])


func test_built_from_primitives() -> void:
	await _setup()
	var map: Node = game.world.map_root
	check(map.get_node("WorldEnvironment").environment.background_mode == Environment.BG_SKY, "sky")
	check((map.get_node("Sun") as DirectionalLight3D).shadow_enabled, "sun with shadows")
	for mesh: MeshInstance3D in map.find_children("*", "MeshInstance3D", true, false):
		check(mesh.mesh is PrimitiveMesh, "%s is a primitive mesh" % mesh.name)
		check(not RenderSettings.category_of(mesh.name).is_empty(), "%s belongs to a render category" % mesh.name)
	var bodies := map.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() == 14, "ground, plaza, ramp, 7 buildings, 4 walls have colliders (%d)" % bodies.size())
	for body: StaticBody3D in bodies:
		var shape: Shape3D = (body.get_child(0) as CollisionShape3D).shape
		check(shape is BoxShape3D or shape is ConvexPolygonShape3D, "%s: simple collision shape (%s)" % [body.name, shape.get_class()])
		check(body.collision_layer == 1, "%s on the world layer" % body.name)


func test_ramp_and_plaza() -> void:
	await _setup()
	var middle := _floor_hit(Vector3(32, 1, 14))
	check(not middle.is_empty() and str(middle.collider.name).begins_with("Ground_Ramp"), "ramp under its middle")
	var slope := rad_to_deg((middle.normal as Vector3).angle_to(Vector3.UP))
	check_near(slope, 9.46, 0.1, "ramp slope (degrees)")
	check_near(middle.position.y, 1.0, 0.05, "ramp halfway up at its middle")
	check_near(_floor_hit(Vector3(32, 3, 32)).position.y, 2.0, 0.01, "plaza 2 m up")
	# Walk up the ramp onto the plaza with the stick.
	player.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(28, 0.1, 4)))
	game.camera_rig.snap_behind_target()
	await physics_frames(5)
	var stick := input.joystick.get_global_rect().position + input.joystick.get_global_rect().size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2.UP * input.joystick.joystick_size)
	await physics_frames(300)
	touch(0, stick + Vector2.UP * input.joystick.joystick_size, false)
	check(player.global_position.z > 22.0 and absf(player.global_position.y - 2.0) < 0.1, "walked up the ramp onto the plaza (%s)" % player.global_position)


func test_bounds_and_kill_height() -> void:
	await _setup()
	var respawns := [0]
	game.world.body_respawned.connect(func(_body: Node3D) -> void: respawns[0] += 1)
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, -12, 0)))
	await physics_frames(3)
	check(respawns[0] == 1, "respawned below the kill height (-10 m)")
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "back at the spawn")
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(80, 0.1, -90)))
	await physics_frames(3)
	check(player.global_position.x <= 59.5 + 0.01 and player.global_position.z >= -59.5 - 0.01, "held inside the bounds (%s)" % player.global_position)
	# The walls stand just outside the bounds and keep vehicles in.
	var wall := _floor_hit(Vector3(0, 2, -61))
	check(not wall.is_empty() and str(wall.collider.name).begins_with("Buildings_Wall_North") and wall.position.y > 2.9, "north wall 3 m high")


func test_debug_viewpoints_stand_on_ground() -> void:
	await _setup()
	for view: Transform3D in game.map_definition.debug_viewpoints:
		var hit := _floor_hit(view.origin)
		check(not hit.is_empty() and view.origin.y - hit.position.y < 0.3 and view.origin.y >= hit.position.y, "viewpoint %s just above a floor (%s)" % [view.origin, hit.get("position")])
	game.cycle_debug_view()
	await physics_frames(30)
	check(player.is_on_floor() and absf(player.global_position.y - 2.0) < 0.05, "VIEW puts the player on the plaza")


func test_quality_profiles_on_the_test_district() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var viewport := game.get_viewport()
	game.set_quality_profile("low")
	check(Engine.max_fps == 30 and viewport.use_occlusion_culling and is_equal_approx(game.camera_rig.camera.far, 400.0), "low: 30 FPS, occlusion, 400 m far plane")
	var sun: DirectionalLight3D = game.world.map_root.get_node("Sun")
	var environment: Environment = game.world.map_root.get_node("WorldEnvironment").environment
	check(not sun.shadow_enabled and environment.fog_enabled, "low: no shadows, depth fog")
	var report: Dictionary = game.render_settings.occluder_report
	check(report.get("source") == "baked" and report.get("occluders") == 7 and report.get("triangles") == 84, "baked box occluders, one per building (%s)" % [report])
	game.set_quality_profile("high")
	check(Engine.max_fps == 60 and sun.shadow_enabled and not environment.fog_enabled and is_equal_approx(game.camera_rig.camera.far, 1500.0), "high: 60 FPS, shadows, no fog")
	game.set_quality_profile("none")
	check(Engine.max_fps == saved_fps and not viewport.use_occlusion_culling, "none: defaults restored")
	Engine.max_fps = saved_fps


func test_map_switch_frees_the_test_district() -> void:
	# The same check as on İstanbul, here without the GLB: to a fixture map
	# and back.
	await _setup()
	var before := _node_count()
	var old_map: Node = game.world.map_root
	var fixture := MapDefinition.new()
	fixture.id = "fixture"
	fixture.scene_path = "res://tests/fixtures/flat_map.tscn"
	fixture.player_spawn_position = Vector3(2, 0.1, 3)
	check(game.switch_map(fixture), "switched to the fixture map")
	await physics_frames(10)
	check(not is_instance_valid(old_map) and game.world.vehicles.is_empty(), "test district and its vehicles freed")
	check(game.switch_map(game.maps.find("test_district")), "switched back")
	await physics_frames(30)
	check(game.world.map_root.name == &"TestDistrict" and game.world.vehicles.size() == game.map_definition.vehicle_spawns.size(), "test district and its vehicles again")
	check(_node_count() == before, "node count back to the start (%d, before %d)" % [_node_count(), before])
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2 and player.is_on_floor(), "player at the spawn")
