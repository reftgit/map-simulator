extends "res://tests/integration/imported_map_case.gd"
## The CC0 Kenney town (Phase 6a) as the import tool made it: maps/kenney_town/,
## from maps/kenney_town/source/kenney_town.glb with scale 10; re-imported in
## Phase 6b with colliders for trees, lamps, and fences and a scored car place.


func definition_path() -> String:
	return "res://maps/kenney_town/kenney_town.tres"


func regenerate_hint() -> String:
	return "run tools/import_map.gd as in docs/maps/imported/kenney_town.md"


func expected_categories() -> Dictionary:
	return {"buildings": 32, "decor": 32, "ground": 144, "lamps": 20, "trees": 41}


func test_registered_and_selectable() -> void:
	var registry := MapRegistry.load_default()
	check(registry.find("kenney_town") != null and registry.find("kenney_town").is_available(), "kenney_town in the registry and available")
	check(registry.definitions[0].id == "istanbul_halic_cells_shader", "the default is unchanged")


func test_device_scenario_extensibility_switching_directly() -> void:
	# The generalized extensibility scenario from an imported map: straight to
	# the test district (scenario maps) and back, then the vehicle_sleep steps
	# on the town.
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "scenario_test", "scenario": {"name": "extensibility", "maps": ["test_district"], "quit_when_done": false}})
	var scenario: DeviceScenario = game.start_scenario(config)
	var results: Array = await scenario.finished
	var steps: Array[String] = []
	for result: Dictionary in results:
		steps.append(result.step)
		check(result.result != "FAIL", "%s: %s (%s)" % [result.step, result.result, result.detail])
	for step in ["map_switch", "van_get_in", "van_throttle", "npc_hit_reaction", "npc_patrol_resumes", "map_back", "parked_car_asleep", "get_out", "slope_skipped", "done"]:
		check(step in steps, "step %s ran" % step)
	check(game.map_definition.id == "kenney_town", "back on the town at the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))


## The collision shape of the first mesh of `category` whose collider is a
## `kind` and that the player's capsule can walk straight at from 4 m away
## on the ground: [shape, start position, direction toward it].
func _approach(category: String, kind: String) -> Array:
	var space := player.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	for node in game.world.map_root.get_node("Model").get_children():
		if definition.category_rules.category_of(node) != category or not node.has_node("StaticBody3D"):
			continue
		for shape: CollisionShape3D in node.get_node("StaticBody3D").get_children():
			if shape.shape.get_class() != kind:
				continue
			var center := shape.global_position
			var directions: Array[Vector3] = []
			if kind == "BoxShape3D":
				var thin := shape.global_basis.x if (shape.shape as BoxShape3D).size.x < (shape.shape as BoxShape3D).size.z else shape.global_basis.z
				directions.assign([Vector3(thin.x, 0, thin.z).normalized(), -Vector3(thin.x, 0, thin.z).normalized()])
			else:
				for d in 8:
					directions.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * d / 8.0))
			for direction in directions:
				var start := center - direction * 4.0
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 3.0, start - Vector3.UP * 5.0, 1))
				if ground.is_empty() or definition.category_rules.category_of((ground.collider as Node).get_parent()) != "ground":
					continue
				start = ground.position
				var walk := PhysicsShapeQueryParameters3D.new()
				walk.shape = capsule
				walk.transform = Transform3D(Basis.IDENTITY, start + Vector3(0, 1.2, 0))
				walk.motion = direction * 4.0
				walk.collision_mask = 1
				if not space.intersect_shape(walk, 1).is_empty():
					continue
				var fractions := space.cast_motion(walk)
				if fractions[1] >= 1.0:
					continue
				walk.transform = walk.transform.translated(walk.motion * fractions[1])
				var rest := space.get_rest_info(walk)
				if not rest.is_empty() and rest.collider_id == shape.get_parent().get_instance_id():
					return [shape, start, direction]
	return []


## Walks the player for 3 s from `start` along `direction` (the stick held forward).
func _walk_at(start: Vector3, direction: Vector3) -> void:
	player.teleport(Transform3D(Basis.looking_at(direction, Vector3.UP), start + Vector3.UP * 0.1))
	game.camera_rig.snap_behind_target()
	await physics_frames(10)
	var stick := input.joystick.get_global_rect().position + input.joystick.get_global_rect().size * Vector2(0.4, 0.6)
	touch(0, stick, true)
	drag(0, stick, stick + Vector2(0, -1) * input.joystick.joystick_size)
	await physics_frames(180)
	touch(0, stick + Vector2(0, -1) * input.joystick.joystick_size, false)


func test_trees_and_fences_block_the_player() -> void:
	# Phase 6b: trees, lamps, fences, and decor have colliders (T52).
	await _setup()
	var tree := _approach("trees", "CapsuleShape3D")
	check(not tree.is_empty(), "a tree the player can walk straight at")
	if not tree.is_empty():
		var trunk: CollisionShape3D = tree[0]
		await _walk_at(tree[1], tree[2])
		var offset: Vector3 = player.global_position - trunk.global_position
		var flat := Vector2(offset.x, offset.z)
		check(flat.length() >= (trunk.shape as CapsuleShape3D).radius + 0.3 and Vector2(tree[2].x, tree[2].z).dot(flat) < 0.0,
				"the player stops at the trunk, %.2f m from its axis, on the side it came from" % flat.length())
	var fence := _approach("decor", "BoxShape3D")
	check(not fence.is_empty(), "a fence or block the player can walk straight at")
	if not fence.is_empty():
		var box: CollisionShape3D = fence[0]
		await _walk_at(fence[1], fence[2])
		var side: Vector3 = player.global_position - box.global_position
		check(Vector3(fence[2]).dot(Vector3(side.x, 0, side.z)) < 0.0, "the player stays on its side of the fence (%s)" % player.global_position)


func test_car_parks_on_a_road() -> void:
	# Phase 6b: scored placement (T53) puts the car on a road tile, not among trees.
	await _setup()
	var spawn: Transform3D = definition.vehicle_spawns[0]
	var hit := _floor_hit(spawn.origin)
	var under := str((hit.collider as Node).get_parent().name) if not hit.is_empty() else ""
	check(under.begins_with("road-"), "the ground under the car is a road tile (%s)" % under)
