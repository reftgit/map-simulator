extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run_checks")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)
func run_checks() -> void:
	var packed := load("res://main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var bodies := scene.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() > 100, "imported static colliders exist")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map_metadata.json"))
	var mosques := scene.get_node("Map").find_children("Mosque_*", "MeshInstance3D", true, false)
	check(mosques.size() == data["mosques"].size(), "every inventoried mosque has geometry")
	check(mosques.size() >= 60, "expanded mosque inventory is present")
	check(scene.find_children("Vehicles*", "MeshInstance3D", true, false).is_empty(), "no car or tram geometry")
	check(data["stats"]["elevation_max_m"] > 60, "DEM relief has hills above 60 metres")
	check(not scene.get_node("Map").find_children("Trees_*", "MeshInstance3D", true, false).is_empty(), "tree crowns import")
	check(not scene.get_node("Map").find_children("Shrubs_*", "MeshInstance3D", true, false).is_empty(), "shrubs import")
	var trunk_colliders := 0
	for trunk in scene.get_node("Map").find_children("TreeTrunks_*", "MeshInstance3D", true, false):
		trunk_colliders += trunk.find_children("*", "StaticBody3D", true, false).size()
	check(trunk_colliders > 0, "tree trunks have collision")
	print("VEGETATION trees=", data["stats"]["trees"], " shrubs=", data["stats"]["vegetation"]["shrubs"])
	print("MOSQUES ", mosques.size(), " | MOTOR_VEHICLES 0")
	check(data["stats"]["dimensions_m"][0] > 2600, "map expanded west/east")
	check(data["stats"]["dimensions_m"][1] > 2600, "map expanded north")
	for prefix in ["StreetLamps_*", "TrafficSignals_*", "RoadPaint_*"]:
		check(not scene.get_node("Map").find_children(prefix, "MeshInstance3D", true, false).is_empty(), "street detail imports: " + prefix)
	print("STREETS ", data["stats"]["street_details"])
	var explorer = scene.get_node("Explorer")
	var target := Vector3(-175, 12, 370)
	explorer.set_view(Vector3(140, 140, 180), target)
	var expected: Vector3 = (target - explorer.camera.global_position).normalized()
	check((-explorer.camera.global_basis.z).dot(expected) > 0.999, "preset camera points at its target")
	explorer.set_view(Vector3(-210, 150, -445), Vector3(-70, 70, -285))
	target = Vector3(-70, 70, -285)
	expected = (target - explorer.camera.global_position).normalized()
	check((-explorer.camera.global_basis.z).dot(expected) > 0.999, "consecutive camera presets work")
	var spawn: Vector3 = explorer.walk_spawn
	var query := PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * 20, spawn - Vector3.UP * 40)
	query.exclude = [explorer.get_rid()]
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "walk spawn has a floor")
	if not hit.is_empty():
		check(str(hit.collider.get_path()).contains("Galata_Bridge"), "walk spawn is on bridge collision")
		print("SPAWN_FLOOR ", hit.position)
	explorer.flying = false
	explorer.global_position = spawn
	for i in range(120):
		await physics_frame
	check(explorer.is_on_floor(), "player settles on bridge floor")
	check(explorer.global_position.y > 2.0, "player stays above water")
	var bp: Array = data["metro_bridge"]["walkway_test_position"]
	var metro_spawn := Vector3(bp[0], bp[1], bp[2])
	var metro_query := PhysicsRayQueryParameters3D.create(metro_spawn+Vector3.UP*4, metro_spawn-Vector3.UP*8)
	metro_query.exclude = [explorer.get_rid()]
	var metro_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(metro_query)
	check(not metro_hit.is_empty(), "Metro bridge walkway has collision")
	if not metro_hit.is_empty():
		check(str(metro_hit.collider.get_path()).contains("Halic_Metro_Bridge"), "Metro walkway hits bridge geometry")
		print("METRO_WALKWAY ", metro_hit.position)
	explorer.global_position = metro_spawn
	explorer.velocity = Vector3.ZERO
	for i in range(120):
		await physics_frame
	check(explorer.is_on_floor() and explorer.global_position.y > 10, "player stands on metro bridge promenade")
	print("STATIC_COLLIDERS ", bodies.size())
	print("VALIDATION ", "PASS" if failures.is_empty() else "FAIL", " | failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
