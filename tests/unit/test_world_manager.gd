extends "res://tests/test_case.gd"
## WorldManager map loading, spawn, kill height, and bounds, using a tiny fixture map.

var world: WorldManager
var definition: MapDefinition


func _setup() -> void:
	definition = MapDefinition.new()
	definition.display_name = "Fixture"
	definition.scene_path = "res://tests/fixtures/flat_map.tscn"
	definition.player_spawn_position = Vector3(2, 0.1, 3)
	definition.player_spawn_yaw_degrees = 90.0
	definition.bounds = Rect2(-20, -20, 40, 40)
	definition.kill_height = -5.0
	world = WorldManager.new()
	add_node(world)
	world.load_map(definition)
	await physics_frames(2)


func test_loads_map_scene() -> void:
	await _setup()
	check(world.map_root != null and world.map_root.get_parent() == world, "map scene instanced under WorldManager")
	check(world.map_root.name == &"FlatMap", "fixture map loaded")


func test_spawn_transform() -> void:
	await _setup()
	var spawn := world.get_spawn_transform()
	check(spawn.origin == Vector3(2, 0.1, 3), "spawn position")
	check((-spawn.basis.z).distance_to(Vector3.LEFT) < 0.0001, "90 degrees faces west (-X)")


func test_respawns_bodies_below_kill_height() -> void:
	await _setup()
	var player: PlayerController = instantiate("res://game/player/player.tscn")
	world.track(player)
	var respawned: Array[Node3D] = []
	world.body_respawned.connect(func(body: Node3D) -> void: respawned.append(body))
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(0, -6, 0)))
	await physics_frames(2)
	check(respawned == ([player] as Array[Node3D]), "respawn signal for the player")
	check(player.global_position.distance_to(Vector3(2, 0.1, 3)) < 0.5, "player back at spawn (%s)" % player.global_position)


func test_holds_bodies_inside_bounds() -> void:
	await _setup()
	var body := Node3D.new()
	add_node(body)
	world.track(body)
	body.global_position = Vector3(35, 1, -50)
	await physics_frames(2)
	check(body.global_position == Vector3(20, 1, -20), "clamped to bounds (%s)" % body.global_position)


func test_freed_tracked_body_is_skipped() -> void:
	await _setup()
	var body := Node3D.new()
	tree.root.add_child(body)
	world.track(body)
	body.free()
	await physics_frames(2)
	check(world.definition != null, "world keeps running after a tracked body is freed")


func test_untracked_bodies_are_left_alone() -> void:
	await _setup()
	var body := Node3D.new()
	add_node(body)
	world.track(body)
	world.untrack(body)
	body.global_position = Vector3(0, -50, 0)
	await physics_frames(2)
	check(body.global_position == Vector3(0, -50, 0), "untracked body not respawned")


func test_spawns_vehicles_from_the_definition() -> void:
	definition = MapDefinition.new()
	definition.scene_path = "res://tests/fixtures/flat_map.tscn"
	definition.kill_height = -7.0
	definition.vehicle_spawns = [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4, 0.3, -2))] as Array[Transform3D]
	world = WorldManager.new()
	add_node(world)
	world.load_map(definition)
	var vehicles := world.spawn_vehicles(load("res://game/vehicle/placeholder_car.tscn"))
	check(vehicles.size() == 1 and vehicles[0].get_parent() == world, "one vehicle under WorldManager")
	var vehicle := vehicles[0]
	check(vehicle.global_position.distance_to(Vector3(4, 0.3, -2)) < 0.001, "at the spawn position")
	check(vehicle.global_basis.z.distance_to(Vector3.LEFT) < 0.0001, "the spawn faces west (-X), so the vehicle's +Z forward points west")
	check(vehicle.spawn_transform == vehicle.global_transform and vehicle.kill_height == -7.0, "reset target and kill height from the map")
	world.unload_map()
	await process_frames(1)
	check(world.vehicles.is_empty() and not is_instance_valid(vehicle), "vehicles go with the map")


func test_spawns_the_vehicle_type_of_each_spawn() -> void:
	definition = MapDefinition.new()
	definition.scene_path = "res://tests/fixtures/flat_map.tscn"
	definition.vehicle_spawns = [Transform3D(Basis.IDENTITY, Vector3(-4, 0.3, 0)), Transform3D(Basis.IDENTITY, Vector3(4, 0.3, 0)), Transform3D(Basis.IDENTITY, Vector3(12, 0.3, 0))] as Array[Transform3D]
	definition.vehicle_scenes = [null, load("res://game/vehicle/placeholder_van.tscn")] as Array[PackedScene]
	world = WorldManager.new()
	add_node(world)
	world.load_map(definition)
	var vehicles := world.spawn_vehicles(load("res://game/vehicle/placeholder_car.tscn"))
	var types: Array[String] = []
	for vehicle in vehicles:
		types.append(vehicle.definition.resource_path.get_file())
	check(types == (["compact_car.tres", "van.tres", "compact_car.tres"] as Array[String]), "empty and missing entries park the default type (%s)" % [types])
