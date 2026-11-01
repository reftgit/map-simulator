extends "res://tests/test_case.gd"
## Shared tests of the experimental facade maps: the cells map rebuilt with
## build_map.py --facade light or shader (and --detail-cell 40). The data,
## collision, and occluders are the cells map's; only the facade detail
## (Detail_*) differs. Their GLBs are generated on each machine and not in Git
## (docs/maps/istanbul_halic/README.md, "Facade variants"); without the GLB
## every test reports SKIP. A test file per map overrides the functions below.

const SPAWN := Vector3(-109.0365, 6.5477, 204.2572)
const SPAWN_FLOOR_Y := 4.5476
## Render triangles of the cells map (full facade): facade detail and the rest.
const CELLS_DETAIL_TRIANGLES := 4187598
const CELLS_OTHER_TRIANGLES := 2884007

var game: Node
var player: PlayerController


## The map's registry id; its GLB is assets/<id>.glb.
func map_id() -> String:
	return ""


func root_name() -> StringName:
	return &""


## SHA-256 of the GLB the documented command builds.
func model_sha256() -> String:
	return ""


## Largest share of the cells map's facade detail triangles the variant keeps.
func max_detail_share() -> float:
	return 1.0


## Checks of the map's materials after loading (the variants differ here).
func check_materials(_model: Node) -> void:
	pass


func model_path() -> String:
	return "res://assets/%s.glb" % map_id()


func skip_reason() -> String:
	if FileAccess.file_exists(model_path()):
		return ""
	return "%s missing; generate it as in docs/maps/istanbul_halic/README.md" % model_path().trim_prefix("res://")


func _setup() -> void:
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.requested_map = map_id()
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


func _triangles(node: MeshInstance3D) -> int:
	var count := 0
	for surface in node.mesh.get_surface_count():
		count += node.mesh.surface_get_array_index_len(surface) / 3
	return count


func test_model_is_the_documented_build() -> void:
	var sha := FileAccess.get_sha256(model_path())
	check(sha == model_sha256(), "%s is the documented build (%s)" % [model_path().trim_prefix("res://"), sha])


func test_same_map_data_as_the_cells_map() -> void:
	var registry := MapRegistry.load_default()
	var mine := registry.find(map_id())
	var cells := registry.find("istanbul_halic_cells")
	check(mine != null and registry.definitions[0].id == "istanbul_halic_cells_shader", "in the registry; the shader facade map is first, the default (D25)")
	check(mine.is_available() and mine.required_files == ([model_path()] as Array[String]), "available, needing its generated GLB")
	check(mine.player_spawn_position == cells.player_spawn_position and mine.player_spawn_yaw_degrees == cells.player_spawn_yaw_degrees, "same spawn")
	check(mine.bounds == cells.bounds and mine.kill_height == cells.kill_height, "same bounds and kill height")
	check(mine.vehicle_spawns == cells.vehicle_spawns and mine.vehicle_scenes == cells.vehicle_scenes, "same vehicle spawn")
	check(mine.debug_viewpoints == cells.debug_viewpoints and mine.debug_viewpoint_names == cells.debug_viewpoint_names, "same viewpoints")
	check(mine.npc_routes.size() == cells.npc_routes.size(), "same number of NPC routes")
	for i in mini(mine.npc_routes.size(), cells.npc_routes.size()):
		check(mine.npc_routes[i].points == cells.npc_routes[i].points and mine.npc_routes[i].wait_seconds == cells.npc_routes[i].wait_seconds, "NPC route %d the same" % i)
	check(mine.occluders_path == cells.occluders_path, "shares the cells map's occluders (the same collision)")


func test_loads_and_spawns_on_galata_bridge() -> void:
	await _setup()
	check(game.map_definition.id == map_id() and game.world.map_root.name == root_name(), "%s loaded (%s)" % [map_id(), game.map_definition.id])
	check(game.hud.map_name == map_id(), "the overlay names the map")
	check(Vector2(player.global_position.x - SPAWN.x, player.global_position.z - SPAWN.z).length() < 0.2, "at the walk spawn (%s)" % player.global_position)
	check_near(player.global_position.y, SPAWN_FLOOR_Y, 0.2, "standing on the bridge deck")
	check(_on_bridge_deck(), "floor is Galata Bridge collision")
	check(game.world.vehicles.size() == 1 and game.world.npcs.size() == 2, "the car parked and the two NPCs placed (%d, %d)" % [game.world.vehicles.size(), game.world.npcs.size()])


func test_scene_collision_and_materials() -> void:
	await _setup()
	var map: Node = game.world.map_root
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.background_mode == Environment.BG_SKY and environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "İstanbul's sky and tonemap")
	check((map.get_node("Sun") as DirectionalLight3D).shadow_enabled, "İstanbul's sun")
	var water := map.find_child("Water", true, false) as MeshInstance3D
	check(water != null and water.material_override is ShaderMaterial, "water uses the shader material")
	var bodies := map.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() == 827, "827 static bodies, as on the cells map (%d)" % bodies.size())
	check_materials(_model())


func test_facade_detail_is_lighter_and_the_rest_unchanged() -> void:
	await _setup()
	var detail := 0
	var other := 0
	var detail_meshes := 0
	for node: MeshInstance3D in _model().find_children("*", "MeshInstance3D", true, false):
		if str(node.name).begins_with("Detail_"):
			detail += _triangles(node)
			detail_meshes += 1
		else:
			other += _triangles(node)
	check(detail_meshes == 2465, "the cells map's 2,465 facade detail cells (%d)" % detail_meshes)
	check(detail <= CELLS_DETAIL_TRIANGLES * max_detail_share(), "facade detail %d triangles, at most %.0f %% of the cells map's %d" % [detail, max_detail_share() * 100.0, CELLS_DETAIL_TRIANGLES])
	check(other == CELLS_OTHER_TRIANGLES, "every other mesh as on the cells map (%d triangles, expected %d)" % [other, CELLS_OTHER_TRIANGLES])
	print("     facade detail: %d triangles (%.1f %% fewer than the cells map)" % [detail, 100.0 * (1.0 - float(detail) / CELLS_DETAIL_TRIANGLES)])


func test_every_mesh_has_a_category_and_cells_are_named() -> void:
	await _setup()
	var uncategorized: Array[String] = []
	var misnamed: Array[String] = []
	for node in _model().find_children("*", "MeshInstance3D", true, false):
		var name := str(node.name)
		if RenderSettings.category_of(name).is_empty():
			uncategorized.append(name)
		for prefix in ["Detail_", "Trees_", "Shrubs_"]:
			if name.begins_with(prefix) and name.split("_").size() != 5:
				misnamed.append(name)
	check(uncategorized.is_empty(), "every mesh has a render category; missing: %s" % [uncategorized.slice(0, 10)])
	check(misnamed.is_empty(), "cell meshes are named <Category>_<cx>_<cy>_<i>_<j>; not: %s" % [misnamed.slice(0, 10)])


func test_quality_profiles_apply_to_the_facade_cells() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var cells: Array[Node] = _model().find_children("Detail_*", "MeshInstance3D", true, false)
	var ranges := func(expected: float) -> bool:
		return cells.all(func(node: Node) -> bool: return is_equal_approx((node as MeshInstance3D).visibility_range_end, expected))
	game.set_quality_profile("low")
	check(Engine.max_fps == 30 and game.get_viewport().use_occlusion_culling and not cells.is_empty() and ranges.call(100.0), "low: occlusion and 100 m on every facade cell")
	game.set_quality_profile("high")
	check(Engine.max_fps == 60 and ranges.call(200.0), "high: 200 m on every facade cell")
	game.set_quality_profile("none")
	check(ranges.call(0.0), "none: defaults restored")
	Engine.max_fps = saved_fps


func test_shared_occluders_match_this_maps_collision() -> void:
	await _setup()
	var saved_fps := Engine.max_fps
	var baked: Node = (load(game.map_definition.occluders_path) as PackedScene).instantiate()
	var map_root: Node = game.world.map_root
	var runtime := RenderSettings.build_occluders(map_root, RenderSettings.meshes_by_category(map_root))
	var baked_stats := RenderSettings.occluder_stats(baked)
	check(baked_stats == RenderSettings.occluder_stats(runtime) and baked_stats.instances == 643 and baked_stats.triangles == 317518,
			"same occluders and triangles: baked %s, from this map's collision %s" % [baked_stats, RenderSettings.occluder_stats(runtime)])
	var a := _occluder_bounds(baked)
	var b := _occluder_bounds(runtime)
	check(a.position.distance_to(b.position) < 0.01 and a.end.distance_to(b.end) < 0.01, "same extent: %s vs %s" % [a, b])
	baked.free()
	runtime.free()
	game.set_quality_profile("high")
	check(game.render_settings.occluder_report.get("source") == "baked", "the profile loads the baked occluders")
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


func test_map_switch_frees_the_map() -> void:
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
	check(not is_instance_valid(old_map) and game.world.npcs.is_empty() and game.world.vehicles.is_empty(), "the map, its car, and its NPCs are freed")
	check(await game.switch_map(game.maps.find(map_id())), "switched back")
	await physics_frames(60)
	check(_on_bridge_deck() and game.world.vehicles.size() == 1 and game.world.npcs.size() == 2, "back on the bridge spawn with the car and the NPCs")
	check(_node_count() == before, "node count back to the start (%d, before %d)" % [_node_count(), before])
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	check(orphans_after <= orphans, "no orphan nodes left behind (%d, before %d)" % [orphans_after, orphans])
	game.set_quality_profile("none")
	Engine.max_fps = saved_fps
