extends "res://tests/test_case.gd"
## The import tool's placement (C4, C8) and the files it writes, on a small
## synthetic town in the physics space (tools/map_import/, docs/MAP_CONTRACT.md).

const MapImporter := preload("res://tools/map_import/map_importer.gd")
const MapPlacement := preload("res://tools/map_import/map_placement.gd")
const MapWriter := preload("res://tools/map_import/map_writer.gd")
const ImportCase := preload("res://tests/unit/test_map_import.gd")


## The synthetic town of test_map_import.gd, imported and in the tree.
func _imported(scene: Node3D, config := {}) -> RefCounted:
	var importer := MapImporter.new()
	importer.parse_config(config)
	importer.process(scene)
	add_node(importer.model)
	await physics_frames(2)
	return importer


func _placement(importer: RefCounted, overrides := {}) -> RefCounted:
	var categories := {}
	for body in importer.model.find_children("*", "StaticBody3D", true, false):
		categories[body.get_instance_id()] = importer.meshes[str(body.get_parent().name)].category
	var placement := MapPlacement.new()
	placement.run(importer.model.get_world_3d().direct_space_state, categories, importer.summary.bounds, overrides)
	return placement


func _result(placement: RefCounted, id: String) -> Array:
	return placement.checks.filter(func(c: Dictionary) -> bool: return c.id == id).map(func(c: Dictionary) -> String: return c.result)


func _space() -> PhysicsDirectSpaceState3D:
	return tree.root.get_world_3d().direct_space_state


func test_places_everything_in_the_town() -> void:
	var importer: RefCounted = await _imported(ImportCase._town())
	var placement := _placement(importer)
	check(_result(placement, "C4") == ["PASS"], "walkable ground: %s" % [placement.checks])
	check(not _result(placement, "C8").has("FAIL"), "spawn, vehicle, route found: %s" % [placement.checks])
	var spawn: Vector3 = placement.spawn.position
	check(placement.category_at(placement.ground_hit(spawn.x, spawn.z)) == "ground", "the spawn is on ground")
	check(placement.spawn.walk >= MapPlacement.MIN_WALK, "at least 20 m of walk ahead (%.0f m)" % placement.spawn.walk)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, spawn + Vector3(0, 1.2, 0))
	check(_space().intersect_shape(query).is_empty(), "the player fits at the spawn")
	var car: Transform3D = placement.vehicle.transform
	check(car.origin.distance_to(spawn) >= MapPlacement.CAR_FROM_SPAWN and placement.vehicle.drive >= MapPlacement.MIN_DRIVE,
			"the car 8 m or more from the spawn with 25 m of road (%.1f m away, %.0f m)" % [car.origin.distance_to(spawn), placement.vehicle.drive])
	var area := BoxShape3D.new()
	area.size = Vector3(5, 2.2, 7)
	query.shape = area
	query.transform = Transform3D(car.basis, car.origin + Vector3(0, 1.1, 0))
	check(_space().intersect_shape(query).is_empty(), "the 7 m × 5 m car area is clear")
	check(placement.route.size() == 2 and placement.route[0].distance_to(placement.route[1]) >= 8.0 and placement.route[0].distance_to(spawn) >= MapPlacement.ROUTE_FROM_SPAWN,
			"an NPC route of two points away from the spawn (%s)" % [placement.route])
	check(not placement.viewpoints.is_empty() and placement.viewpoints.size() == placement.viewpoint_names.size(), "viewpoints with names (%d)" % placement.viewpoints.size())
	check(placement.bounds.has_point(Vector2(spawn.x, spawn.z)) and placement.bounds.size.x > 40.0, "bounds around the walkable area (%s)" % placement.bounds)
	check(placement.kill_height <= -10.0, "kill height below the lowest geometry (%.0f)" % placement.kill_height)
	check(placement.sloped_viewpoint == -1 and _result(placement, "C8").has("INFO"), "a flat town has no sloped viewpoint")


func test_spawn_avoids_points_inside_buildings() -> void:
	# A road mesh running through a building (the Safranbolu case): no spawn,
	# viewpoint, or route point lies inside the building's collider.
	var scene := ImportCase._scene([
		["ground_main", ImportCase._plane(60.0)],
		["road_1", ImportCase._plane(30.0, Vector3(0, 0.05, 0))],
		["house_1", ImportCase._boxes([[Vector3(0, 5, 0), Vector3(20, 10, 20)]])],
	])
	var importer: RefCounted = await _imported(scene)
	var placement := _placement(importer)
	var points: Array[Vector3] = [placement.spawn.position]
	points.append_array(placement.route)
	for view: Transform3D in placement.viewpoints:
		points.append(view.origin)
	for point in points:
		check(absf(point.x) > 10.0 or absf(point.z) > 10.0, "%s is outside the building" % point)


func test_reports_a_map_without_walkable_ground() -> void:
	var scene := ImportCase._scene([["house_1", ImportCase._boxes([[Vector3(0, 5, 0), Vector3(30, 10, 30)]])]])
	var importer: RefCounted = await _imported(scene)
	var placement := _placement(importer)
	check(_result(placement, "C4") == ["FAIL"], "C4 fails without ground: %s" % [placement.checks])
	check(placement.checks[0].message.contains("Name the ground meshes"), "the message says how to fix it")


func test_reports_no_room_for_a_vehicle() -> void:
	# A 60 m × 4.6 m alley along the sample row z = 1: the player has room, the car (a 5 m wide area) does not.
	var scene := ImportCase._scene([["ground_main", ImportCase._plane(60.0)],
			["wall_1", ImportCase._boxes([[Vector3(0, 3, -3.3), Vector3(60, 6, 4)]])], ["wall_2", ImportCase._boxes([[Vector3(0, 3, 5.3), Vector3(60, 6, 4)]])],
			["wall_3", ImportCase._boxes([[Vector3(0, 3, -17), Vector3(60, 6, 24)]])], ["wall_4", ImportCase._boxes([[Vector3(0, 3, 19), Vector3(60, 6, 24)]])]])
	var importer: RefCounted = await _imported(scene)
	var placement := _placement(importer)
	var vehicle_fail: Array = placement.checks.filter(func(c: Dictionary) -> bool: return c.result == "FAIL" and c.message.contains("no vehicle place"))
	check(not vehicle_fail.is_empty(), "C8 names the missing vehicle place: %s" % [placement.checks])


func test_configured_points_replace_the_search() -> void:
	var importer: RefCounted = await _imported(ImportCase._town())
	var placement := _placement(importer, {"spawn": {"position": [-25, 0.1, -25], "yaw": 90}, "vehicle_spawn": {"position": [20, 0.3, 20], "yaw": 180},
			"npc_route": [[-20, 0.1, 20], [-10, 0.1, 20]]})
	check(placement.spawn.position == Vector3(-25, 0.1, -25) and is_equal_approx(placement.spawn.yaw, 90.0), "spawn from the configuration")
	check((placement.vehicle.transform as Transform3D).origin == Vector3(20, 0.3, 20), "vehicle from the configuration")
	check(placement.route == ([Vector3(-20, 0.1, 20), Vector3(-10, 0.1, 20)] as Array[Vector3]), "route from the configuration")


func test_writer_files() -> void:
	var importer: RefCounted = await _imported(ImportCase._town())
	var placement := _placement(importer)
	var text := MapWriter.scene_text("kenney_town", "res://maps/kenney_town/kenney_town_model.scn")
	check(text.contains('[node name="KenneyTown" type="Node3D"]') and text.contains('path="res://maps/kenney_town/kenney_town_model.scn"')
			and text.contains('[node name="Sun" type="DirectionalLight3D"') and text.contains('[node name="WorldEnvironment"'), "scene with model, sky, sun")
	var paths := {"scene": "res://maps/x/x.tscn", "model": "res://maps/x/x_model.scn", "rules": "res://maps/istanbul_halic/istanbul_halic_categories.tres", "occluders": "res://maps/x/x_occluders.scn"}
	var definition := MapWriter.definition("x", "X", paths, placement)
	check(definition.id == "x" and definition.player_spawn_position == placement.spawn.position and definition.vehicle_spawns.size() == 1
			and definition.npc_routes.size() == 1 and definition.npc_routes[0].points.size() == 2 and definition.required_files == (["res://maps/x/x_model.scn"] as Array[String])
			and definition.category_rules != null and definition.debug_viewpoints.size() == definition.debug_viewpoint_names.size(), "the MapDefinition carries the placement and the files")
	var registry_copy := OS.get_user_data_dir().path_join("maps_registry_test.tres")
	var copy := FileAccess.open(registry_copy, FileAccess.WRITE)
	copy.store_string(FileAccess.get_file_as_string(MapRegistry.PATH))
	copy.close()
	check(MapWriter.register(registry_copy, "res://maps/test_district/test_district.tres") == "present", "a registered map is not added twice")
	check(MapWriter.register(registry_copy, "res://maps/x/x.tres") == "added", "a new map is added")
	var written := FileAccess.get_file_as_string(registry_copy)
	var original := FileAccess.get_file_as_string(MapRegistry.PATH)
	var found := RegEx.create_from_string('path="res://maps/x/x.tres" id="([^"]+)"').search(written)
	check(found != null and written.contains('ExtResource("%s")])' % found.get_string(1)), "appended as the last entry")
	if found:
		var id := found.get_string(1)
		var steps := RegEx.create_from_string("load_steps=(\\d+)").search(original)
		var restored := written.replace('\n[ext_resource type="Resource" path="res://maps/x/x.tres" id="%s"]' % id, "").replace(', ExtResource("%s")])' % id, "])")
		restored = restored.replace("load_steps=%d" % (int(steps.get_string(1)) + 1), steps.get_string())
		check(restored == original, "nothing else in the registry changes")
	DirAccess.remove_absolute(registry_copy)
