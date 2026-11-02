extends "res://tests/test_case.gd"
## The cells map (istanbul_halic_cells): İstanbul • Haliç regenerated with
## facade detail, tree crowns, and shrubs in cells inside each 150 m chunk
## (build_map.py --detail-cell). Needs assets/istanbul_halic_cells.glb, which
## is generated on each machine and not in Git (docs/maps/istanbul_halic/README.md,
## "The cells map").

const MAP_MODEL := "res://assets/istanbul_halic_cells.glb"
## The GLB the documented command builds with the pinned environment.
const MODEL_SHA256 := "7973071a3ee900b0af4023fad310c250707d21ebbeea8161b334be4134053c9d"
const SPAWN := Vector3(-109.0365, 6.5477, 204.2572)
const SPAWN_FLOOR_Y := 4.5476
## Mesh name prefixes split into cells; their -col meshes (none) and every
## other category keep one mesh per 150 m chunk or per landmark.
const CELL_PREFIXES := ["Detail_", "Trees_", "Shrubs_"]

var game: Node
var player: PlayerController


func skip_reason() -> String:
	if FileAccess.file_exists(MAP_MODEL):
		return ""
	return "%s missing; generate it as in docs/maps/istanbul_halic/README.md" % MAP_MODEL.trim_prefix("res://")


func _setup() -> void:
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.requested_map = "istanbul_halic_cells"
	add_node(game)
	player = game.player
	await physics_frames(60)


func _model() -> Node:
	return game.world.map_root.get_node("Model")


func _on_bridge_deck() -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 2.0, player.global_position - Vector3.UP * 5.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return player.is_on_floor() and not hit.is_empty() and str(hit.collider.get_path()).contains("Galata_Bridge")


func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func test_model_is_the_documented_build() -> void:
	var sha := FileAccess.get_sha256(MAP_MODEL)
	check(sha == MODEL_SHA256, "assets/istanbul_halic_cells.glb is the documented build (%s)" % sha)


func test_same_map_data_as_istanbul() -> void:
	var registry := MapRegistry.load_default()
	var cells := registry.find("istanbul_halic_cells")
	var istanbul := registry.find("istanbul_halic")
	check(cells != null and istanbul != null and registry.definitions[0].id == "istanbul_halic_cells_shader", "in the registry beside İstanbul • Haliç; the shader facade map is first, the default")
	check(registry.ids().find("istanbul_halic_cells") > registry.ids().find("test_district"), "after the test district, so MAP still goes to the test district first (%s)" % [registry.ids()])
	check(cells.is_available() and cells.required_files == (["res://assets/istanbul_halic_cells.glb"] as Array[String]), "available, needing its generated GLB")
	check(cells.player_spawn_position == istanbul.player_spawn_position and cells.player_spawn_yaw_degrees == istanbul.player_spawn_yaw_degrees, "same spawn")
	check(cells.bounds == istanbul.bounds and cells.kill_height == istanbul.kill_height, "same bounds and kill height")
	check(cells.vehicle_spawns == istanbul.vehicle_spawns and cells.vehicle_scenes == istanbul.vehicle_scenes, "same vehicle spawn")
	check(cells.debug_viewpoints == istanbul.debug_viewpoints and cells.debug_viewpoint_names == istanbul.debug_viewpoint_names, "same viewpoints")
	check(cells.npc_routes.size() == istanbul.npc_routes.size(), "same number of NPC routes")
	for i in mini(cells.npc_routes.size(), istanbul.npc_routes.size()):
		check(cells.npc_routes[i].points == istanbul.npc_routes[i].points and cells.npc_routes[i].wait_seconds == istanbul.npc_routes[i].wait_seconds, "NPC route %d the same" % i)
	# Its own bake: the regenerated colliders differ from the shipped GLB's in
	# the Atatürk bridge piers (2.7-3.5 m), so İstanbul's bake is not shared.
	check(cells.occluders_path == "res://maps/istanbul_halic_cells/istanbul_halic_cells_occluders.scn" and ResourceLoader.exists(cells.occluders_path), "its own baked occluders")


func test_loads_and_spawns_on_galata_bridge() -> void:
	await _setup()
	check(game.map_definition.id == "istanbul_halic_cells" and game.world.map_root.name == &"IstanbulHalicCells", "cells map loaded (%s)" % game.map_definition.id)
	check(game.hud.map_name == "istanbul_halic_cells", "the overlay names the map")
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "at the walk spawn (%s)" % player.global_position)
	check_near(player.global_position.y, SPAWN_FLOOR_Y, 0.2, "standing on the bridge deck")
	check(_on_bridge_deck(), "floor is Galata Bridge collision")
	check(game.world.vehicles.size() == 1 and game.world.npcs.size() == 2, "the car parked and the two NPCs placed (%d, %d)" % [game.world.vehicles.size(), game.world.npcs.size()])


func test_scene_setup_and_collision() -> void:
	await _setup()
	var map: Node = game.world.map_root
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.background_mode == Environment.BG_SKY and environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "İstanbul's sky and tonemap")
	var sun: DirectionalLight3D = map.get_node("Sun")
	check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "İstanbul's sun")
	var water := map.find_child("Water", true, false) as MeshInstance3D
	check(water != null and water.material_override is ShaderMaterial, "water uses the shader material")
	var bodies := map.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() == 827, "827 static bodies, as on İstanbul (%d)" % bodies.size())
	var materials := {}
	for node: MeshInstance3D in _model().find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				materials[material] = material.vertex_color_use_as_albedo
	check(materials.size() == 6 and not materials.values().has(false), "the 6 shared materials use vertex colors (%d)" % materials.size())


func test_every_mesh_has_a_category_and_cells_are_named() -> void:
	await _setup()
	var uncategorized: Array[String] = []
	var misnamed: Array[String] = []
	var counts := {}
	var cells := 0
	for node in _model().find_children("*", "MeshInstance3D", true, false):
		var category: String = game.map_definition.category_rules.category_of(node)
		if category.is_empty():
			uncategorized.append(str(node.name))
		counts[category] = counts.get(category, 0) + 1
		for prefix: String in CELL_PREFIXES:
			if str(node.name).begins_with(prefix):
				cells += 1
				if str(node.name).split("_").size() != 5:
					misnamed.append(str(node.name))
	check(uncategorized.is_empty(), "every mesh has a render category; missing: %s" % [uncategorized.slice(0, 10)])
	check(misnamed.is_empty(), "cell meshes are named <Category>_<cx>_<cy>_<i>_<j>; not: %s" % [misnamed.slice(0, 10)])
	check(cells > 3000 and counts.get("facade_detail", 0) > 371, "facade detail and vegetation in cells (%d cell meshes)" % cells)
	print("     categories: %s, cell meshes %d" % [counts, cells])


func test_quality_profiles_apply_to_the_cells() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var viewport := game.get_viewport()
	var cells: Array[Node] = []
	for prefix: String in CELL_PREFIXES:
		cells.append_array(_model().find_children(prefix + "*", "MeshInstance3D", true, false))
	var ranges := func(expected: float) -> bool:
		return cells.all(func(node: Node) -> bool: return is_equal_approx((node as MeshInstance3D).visibility_range_end, expected))
	game.set_quality_profile("low")
	check(Engine.max_fps == 30 and viewport.use_occlusion_culling and is_equal_approx(game.camera_rig.camera.far, 400.0), "low: 30 FPS cap, occlusion, 400 m far plane")
	check(not cells.is_empty() and ranges.call(100.0), "low: every cell mesh ends at 100 m")
	game.set_quality_profile("high")
	check(Engine.max_fps == 60 and ranges.call(200.0), "high: 60 FPS cap, every cell mesh ends at 200 m")
	game.set_quality_profile("none")
	check(not viewport.use_occlusion_culling and ranges.call(0.0), "none: defaults restored")
	Engine.max_fps = saved_fps


func test_baked_occluders_match_this_maps_collision() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var path: String = game.map_definition.occluders_path
	var baked: Node = (load(path) as PackedScene).instantiate()
	var map_root: Node = game.world.map_root
	var rules: CategoryRules = game.map_definition.category_rules
	var runtime := RenderSettings.build_occluders(map_root, rules.meshes_by_category(map_root), false, rules.occluder_categories)
	var baked_stats := RenderSettings.occluder_stats(baked)
	check(baked_stats == RenderSettings.occluder_stats(runtime) and baked_stats.instances == 643 and baked_stats.triangles == 317518,
			"same occluders and triangles: baked %s, from this map's collision %s" % [baked_stats, RenderSettings.occluder_stats(runtime)])
	var a := _occluder_bounds(baked)
	var b := _occluder_bounds(runtime)
	check(a.position.distance_to(b.position) < 0.01 and a.end.distance_to(b.end) < 0.01, "same extent: %s vs %s" % [a, b])
	baked.free()
	runtime.free()
	game.set_quality_profile("high")
	var report: Dictionary = game.render_settings.occluder_report
	check(report.get("source") == "baked" and report.get("occluders") == 643, "the profile loads the baked occluders (%s)" % [report])
	game.set_quality_profile("none")
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


func test_viewpoints_stand_on_ground() -> void:
	await _setup()
	var names: Array[String] = game.get_view_names()
	check(names.size() == 3, "spawn + 2 viewpoints (%s)" % [names])
	for i in range(1, names.size()):
		game.cycle_debug_view()
		await physics_frames(60)
		var target: Transform3D = game.map_definition.debug_viewpoints[i - 1]
		check(player.is_on_floor() and player.global_position.distance_to(target.origin) < 0.5, "%s: standing at the viewpoint (%s)" % [names[i], player.global_position])


func test_map_switch_frees_the_cells_map() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	game.set_quality_profile("low")
	await physics_frames(10)
	var before := _node_count()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var old_map: Node = game.world.map_root
	var fixture := MapDefinition.new()
	fixture.id = "fixture"
	fixture.scene_path = "res://tests/fixtures/flat_map.tscn"
	fixture.player_spawn_position = Vector3(2, 0.1, 3)
	fixture.bounds = Rect2(-20, -20, 40, 40)
	check(await game.switch_map(fixture), "switched to the fixture map")
	await physics_frames(30)
	check(not is_instance_valid(old_map) and game.world.npcs.is_empty() and game.world.vehicles.is_empty(), "the cells map, its car, and its NPCs are freed")
	check(await game.switch_map(game.maps.find("istanbul_halic_cells")), "switched back")
	await physics_frames(60)
	check(_on_bridge_deck() and game.world.vehicles.size() == 1 and game.world.npcs.size() == 2, "back on the bridge spawn with the car and the NPCs")
	check(game.render_settings.occluder_report.get("source") == "baked", "baked occluders loaded again")
	check(_node_count() == before, "node count back to the start (%d, before %d)" % [_node_count(), before])
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	check(orphans_after <= orphans, "no orphan nodes left behind (%d, before %d)" % [orphans_after, orphans])
	game.set_quality_profile("none")
	Engine.max_fps = saved_fps
