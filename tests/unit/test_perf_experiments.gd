extends "res://tests/test_case.gd"
## Performance experiment flags: parsing, category matching, applying to a
## fixture map, frame statistics. The real map is covered in integration tests.

var _saved_max_fps := 0


func _fixture_map() -> Node3D:
	var root := Node3D.new()
	for node_name in ["Trees_1_1", "TreeTrunks_1_1", "StreetLamps_1_1", "Buildings_1_1", "Detail_1_1", "RoadPaint_1_1", "Ground_1_1", "Water"]:
		var mesh := MeshInstance3D.new()
		mesh.name = node_name
		mesh.mesh = BoxMesh.new()
		root.add_child(mesh)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)]))
	shape.shape = concave
	body.add_child(shape)
	root.get_node("Buildings_1_1").add_child(body)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = Environment.new()
	root.add_child(world)
	return root


func test_default_config_changes_nothing() -> void:
	var config := PerfConfig.from_dict({})
	check(config != null and config.is_default(), "empty JSON is the default config")
	check(not config.bench, "no benchmark without a bench section")
	var bench := PerfConfig.from_dict({"bench": {}})
	check(bench.bench and is_equal_approx(bench.warmup_s, 30.0) and is_equal_approx(bench.measure_s, 60.0), "protocol defaults: 30 s warm-up, 60 s measurement")


func test_rejects_typos() -> void:
	check(PerfConfig.from_dict({"hdie": ["trees"]}) == null and PerfConfig.last_error.contains("hdie"), "unknown key rejected")
	check(PerfConfig.from_dict({"hide": ["tree"]}) == null and PerfConfig.last_error.contains("tree"), "unknown category rejected")
	check(PerfConfig.from_dict({"shadows": "none"}) == null, "unknown shadow mode rejected")
	check(PerfConfig.from_dict({"bench": {"measure": 5}}) == null, "unknown bench key rejected")


func test_experiment_files_parse() -> void:
	var directory := "res://tools/perf/experiments"
	var files := DirAccess.get_files_at(directory)
	check(files.size() >= 20, "experiment definitions present (%d)" % files.size())
	for file in files:
		if file.ends_with(".json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
			var config := PerfConfig.from_dict(parsed) if parsed is Dictionary else null
			check(config != null and config.bench, "%s parses and has a bench section (%s)" % [file, PerfConfig.last_error])
			check(config == null or config.experiment == file.get_basename(), "%s: experiment name matches the file" % file)


func test_category_matching() -> void:
	var expected := {
		"Detail_13_07": "facade_detail", "MosqueDetail_1564032": "facade_detail", "LandmarkDetail_23236783": "facade_detail",
		"Galata_Bridge_Detail": "decor", "Ferry_28_9784_41_0201": "decor", "SignalGlow_red": "decor", "RoadPaint_3_4": "decor",
		"StreetLamps_1_2": "lamps", "LampGlow_Bridge": "lamps",
		"Trees_1_2": "trees", "TreeTrunks_1_2": "trees", "Shrubs_1_2": "trees",
		"Buildings_1_2": "buildings", "Mosque_1564032": "buildings", "Landmark_23236783": "buildings",
		"Ground_1_2": "ground", "Galata_Bridge": "ground", "Halic_Metro_Bridge": "ground", "Gardens_1_2": "ground",
		"Water": "water", "Sun": "",
	}
	for node_name: String in expected:
		check(PerfExperiments.category_of(node_name) == expected[node_name], "%s -> %s (got '%s')" % [node_name, expected[node_name], PerfExperiments.category_of(node_name)])


func test_apply_changes_only_requested_settings() -> void:
	_saved_max_fps = Engine.max_fps
	var map := _fixture_map()
	add_node(map)
	var viewport := SubViewport.new()
	add_node(viewport)
	var camera := Camera3D.new()
	camera.far = 1500.0
	viewport.add_child(camera)
	var config := PerfConfig.from_dict({
		"hide": ["trees"], "visibility_end": {"lamps": 150}, "camera_far": 400, "fog": true, "shadows": "off",
		"render_scale": 0.6, "scaling_mode": "fsr", "max_fps": 30, "occlusion": true, "lod_threshold": 4.0,
	})
	var report := PerfExperiments.apply(config, map, camera, viewport)
	check(not map.get_node("Trees_1_1").visible and not map.get_node("TreeTrunks_1_1").visible, "trees hidden")
	check(map.get_node("Buildings_1_1").visible and map.get_node("Detail_1_1").visible, "other categories stay visible")
	check(is_equal_approx(map.get_node("StreetLamps_1_1").visibility_range_end, 150.0), "lamp visibility range")
	check(is_equal_approx(map.get_node("Ground_1_1").visibility_range_end, 0.0), "no range on other categories")
	check(is_equal_approx(camera.far, 400.0), "camera far plane")
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH and is_equal_approx(environment.fog_depth_end, 400.0), "depth fog ends at the far plane")
	check(not map.get_node("Sun").shadow_enabled, "shadows off")
	check(is_equal_approx(viewport.scaling_3d_scale, 0.6) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "render scale with FSR")
	check(is_equal_approx(viewport.mesh_lod_threshold, 4.0), "LOD threshold")
	check(Engine.max_fps == 30, "frame cap")
	check(viewport.use_occlusion_culling and report.get("occluders") == 1 and report.get("occluder_triangles") == 1, "one occluder from the building collision (%s)" % [report])
	Engine.max_fps = _saved_max_fps


func test_single_split_shadows() -> void:
	var map := _fixture_map()
	add_node(map)
	var viewport := SubViewport.new()
	add_node(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	PerfExperiments.apply(PerfConfig.from_dict({"shadows": "single"}), map, camera, viewport)
	var sun: DirectionalLight3D = map.get_node("Sun")
	check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "one orthogonal split")
	check(not viewport.use_occlusion_culling and is_equal_approx(viewport.scaling_3d_scale, 1.0), "defaults untouched")


func test_frame_stats() -> void:
	# 98 frames of 10 ms and two of 50 ms over 1.08 s.
	var frames := PackedInt64Array()
	for i in 98:
		frames.append(10000)
	frames.append(50000)
	frames.append(50000)
	var stats := PerfBenchmark.frame_stats(frames, 1.08)
	check_near(stats.avg_fps, 100 / 1.08, 0.01, "average FPS")
	check_near(stats.low1_fps, 20.0, 0.01, "1% low is the 99th-percentile frame")
	check_near(stats.min_fps, 20.0, 0.01, "minimum FPS from the longest frame")
	check(PerfBenchmark.frame_stats(PackedInt64Array(), 1.0).frames == 0, "empty window")


func test_view_slug() -> void:
	check(PerfBenchmark.view_slug("Karaköy street, facing north") == "karakoy", "Turkish letters to ASCII")
	check(PerfBenchmark.view_slug("Spawn") == "spawn", "plain name")
