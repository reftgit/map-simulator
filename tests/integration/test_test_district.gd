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
	check(not is_instance_valid(old_map) and game.world.vehicles.is_empty() and game.world.npcs.is_empty(), "test district, its vehicles, and its NPCs freed")
	check(game.switch_map(game.maps.find("test_district")), "switched back")
	await physics_frames(30)
	check(game.world.map_root.name == &"TestDistrict" and game.world.vehicles.size() == game.map_definition.vehicle_spawns.size() and game.world.npcs.size() == 3, "test district, its vehicles, and its NPCs again")
	check(_node_count() == before, "node count back to the start (%d, before %d)" % [_node_count(), before])
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2 and player.is_on_floor(), "player at the spawn")


func _tap(button: TouchButton, index: int) -> void:
	var point := button.get_global_rect().get_center()
	touch(index, point, true)
	touch(index, point, false)


func _van() -> VehicleController:
	for vehicle in game.world.vehicles:
		if vehicle.definition.resource_path == "res://game/vehicle/definitions/van.tres":
			return vehicle
	return null


func _ticks_until(predicate: Callable, max_ticks: int) -> int:
	for i in max_ticks:
		if predicate.call():
			return i
		await tree.physics_frame
	return max_ticks if predicate.call() else -1


func test_both_vehicle_types_parked() -> void:
	await _setup()
	var vehicles: Array[VehicleController] = game.world.vehicles
	check(vehicles.size() == 2, "two vehicles from the definition (%d)" % vehicles.size())
	check(vehicles[0].definition.resource_path.ends_with("compact_car.tres") and _van() == vehicles[1], "the compact car and the van, in spawn order")
	check(_van().mass == 2200.0 and _van().definition.max_speed == 14.0, "the van's own definition")
	for i in vehicles.size():
		var spawn: Transform3D = game.map_definition.vehicle_spawns[i]
		check(Vector2(vehicles[i].global_position.x - spawn.origin.x, vehicles[i].global_position.z - spawn.origin.z).length() < 0.3, "%s at its spawn" % vehicles[i].name)
		check((-spawn.basis.z).dot(vehicles[i].global_basis.z) > 0.999, "%s faces north" % vehicles[i].name)
		var slept := await _ticks_until(vehicles[i].is_asleep, 300)
		check(slept >= 0 and vehicles[i].wheels.all(func(w: VehicleWheel3D) -> bool: return w.is_in_contact() or vehicles[i].is_asleep()), "%s asleep on its wheels" % vehicles[i].name)


func test_car_button_cycles_through_the_vehicles() -> void:
	await _setup()
	var button: TouchButton = game.hud.get_node("SafeArea/Controls/DebugCarButton")
	for vehicle: VehicleController in [game.world.vehicles[0], game.world.vehicles[1], game.world.vehicles[0]]:
		_tap(button, 1)
		await physics_frames(20)
		check(game.vehicle_interaction.nearby_vehicle() == vehicle and input.interact_button.visible, "CAR walks up to %s" % vehicle.name)


func test_van_drive_get_out_sleep_and_reset() -> void:
	await _setup()
	var van := _van()
	check(await _ticks_until(van.is_asleep, 300) >= 0, "van asleep before anyone gets in")
	var car_button: TouchButton = game.hud.get_node("SafeArea/Controls/DebugCarButton")
	_tap(car_button, 1)
	_tap(car_button, 1)
	await physics_frames(20)
	check(game.vehicle_interaction.nearby_vehicle() == van, "beside the van")
	_tap(input.interact_button, 1)
	await physics_frames(3)
	check(game.vehicle_interaction.vehicle == van and not van.is_asleep(), "in the van, awake")
	check(game.camera_rig.target == van and game.camera_rig.profile == van.definition.camera_profile, "camera follows the van")
	var start := van.global_position
	touch(2, input.throttle_button.get_global_rect().get_center(), true)
	await physics_frames(180)
	touch(2, input.throttle_button.get_global_rect().get_center(), false)
	var travelled := Vector2(van.global_position.x - start.x, van.global_position.z - start.z).length()
	check(travelled > 8.0 and van.get_forward_speed() > 5.0, "3 s of throttle: %.1f m, %.1f m/s" % [travelled, van.get_forward_speed()])
	check(van.global_position.z < start.z - 8.0 and absf(van.global_position.x - start.x) < 1.0, "straight north along its lane (%s)" % van.global_position)
	touch(2, input.handbrake_button.get_global_rect().get_center(), true)
	await _ticks_until(func() -> bool: return van.linear_velocity.length() < 0.3, 600)
	touch(2, input.handbrake_button.get_global_rect().get_center(), false)
	_tap(input.exit_button, 1)
	await physics_frames(3)
	check(not game.vehicle_interaction.is_driving() and player.visible and game.camera_rig.target == player, "got out")
	check(await _ticks_until(van.is_asleep, 240) >= 0, "van asleep again within 4 s after getting out")
	_tap(input.interact_button, 1)
	await physics_frames(3)
	check(game.vehicle_interaction.vehicle == van, "back in the van")
	van.global_position = Vector3(van.global_position.x, game.map_definition.kill_height - 2.0, van.global_position.z)
	await physics_frames(3)
	var spawn: Transform3D = game.map_definition.vehicle_spawns[1]
	check(Vector2(van.global_position.x - spawn.origin.x, van.global_position.z - spawn.origin.z).length() < 0.5, "below the kill height: van back at its spawn")
	check(game.vehicle_interaction.is_driving() and player.global_position.distance_to(van.seat.global_position) < 0.05, "with the driver")


func test_npcs_patrol_the_test_district() -> void:
	await _setup()
	var npcs: Array[Npc] = game.world.npcs
	var routes: Array[PatrolRoute] = game.map_definition.npc_routes
	check(npcs.size() == 3 and routes.size() == 3, "three NPCs, one per route (%d)" % npcs.size())
	var arrivals := {}
	for i in npcs.size():
		arrivals[i] = 0
		npcs[i].patrol_input.arrived.connect(func(_index: int) -> void: arrivals[i] += 1)
	var ramp_top := 0.0
	for tick in 900:
		await tree.physics_frame
		ramp_top = maxf(ramp_top, npcs[1].global_position.y)
	for i in npcs.size():
		check(arrivals[i] >= 1, "%s reached at least one point in 15 s (%d)" % [npcs[i].name, arrivals[i]])
		check(npcs[i].is_on_floor() and npcs[i].global_position.y > -0.1, "%s on a floor (%s)" % [npcs[i].name, npcs[i].global_position])
		var p := npcs[i].global_position
		check(game.map_definition.bounds.has_point(Vector2(p.x, p.z)), "%s inside the bounds" % npcs[i].name)
	check(ramp_top > 1.9, "the ramp NPC walked up onto the plaza (highest %.2f m)" % ramp_top)
	check(npcs[0].global_position.y > 1.9, "the plaza NPC stays on the plaza (%s)" % npcs[0].global_position)


func test_punching_an_npc_on_the_test_district() -> void:
	await _setup()
	var npc: Npc = game.world.npcs[2]
	# Wait until the street NPC walks north, then stand in its way, facing it.
	await _ticks_until(func() -> bool: return npc.state_machine.get_state_name() == &"Walk" and npc.patrol_input.target_index == 1, 600)
	await physics_frames(30)
	var ahead := npc.global_position + Vector3(0, 0, -1.6)
	player.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(ahead.x, 0.1, ahead.z)))
	var close := await _ticks_until(func() -> bool: return player.global_position.distance_to(npc.global_position) < 1.2, 60)
	check(close >= 0, "the NPC walked up to the player")
	_tap(input.punch_button, 1)
	var hit := await _ticks_until(func() -> bool: return npc.hits > 0, 30)
	check(hit >= 0 and npc.state_machine.get_state_name() == &"HitReaction", "the punch button's punch starts the NPC's reaction")
	await physics_frames(40)
	check(npc.hits == 1, "one hit for the one punch (%d)" % npc.hits)
	check(npc.state_machine.get_state_name() != &"HitReaction", "the reaction is over")
	# The player stands in the way, so the NPC gives the point up and walks on.
	var moved_on := await _ticks_until(func() -> bool: return npc.patrol_input.target_index != 1, 300)
	check(moved_on >= 0, "the NPC walks on (blocked by the player: it gives the point up)")


func test_npc_respawns_at_its_start_below_the_kill_height() -> void:
	await _setup()
	var npc: Npc = game.world.npcs[2]
	var start: Vector3 = game.map_definition.npc_routes[2].points[0]
	await physics_frames(60)
	npc.teleport(Transform3D(Basis.IDENTITY, Vector3(npc.global_position.x, -12.0, npc.global_position.z)))
	await physics_frames(3)
	check(Vector2(npc.global_position.x - start.x, npc.global_position.z - start.z).length() < 0.3, "back at its own start (%s)" % npc.global_position)
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "the player was not moved")
