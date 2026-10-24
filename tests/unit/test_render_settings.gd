extends "res://tests/test_case.gd"
## Quality profiles and RenderSettings on a fixture map: platform selection,
## profile values, precedence (experiment > profile > defaults), applying and
## resetting settings, occluder fallback.

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
	concave.set_faces(PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]))
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


## Fixture map, camera in a SubViewport, and RenderSettings over them.
func _setup(occluders_path := "") -> Dictionary:
	_saved_max_fps = Engine.max_fps
	var map := _fixture_map()
	add_node(map)
	var viewport := SubViewport.new()
	add_node(viewport)
	var camera := Camera3D.new()
	camera.far = 1500.0
	viewport.add_child(camera)
	return {"map": map, "viewport": viewport, "camera": camera,
			"settings": RenderSettings.new(map, camera, viewport, occluders_path)}


func _restore() -> void:
	Engine.max_fps = _saved_max_fps


func test_platform_rule() -> void:
	var ios := func(feature: String) -> bool: return feature in ["ios", "mobile"]
	var android := func(feature: String) -> bool: return feature in ["android", "mobile"]
	var desktop := func(feature: String) -> bool: return feature in ["macos", "pc"]
	check(QualityProfiles.default_name(ios) == "high", "iOS -> high")
	check(QualityProfiles.default_name(android) == "low", "Android -> low")
	check(QualityProfiles.default_name(desktop) == "none", "desktop -> none")
	check(QualityProfiles.default_name() == "none", "this test host (desktop) -> none")


func test_quality_argument() -> void:
	check(QualityProfiles.name_from_args(PackedStringArray(["unit", "--quality=low"])) == "low", "--quality=low")
	check(QualityProfiles.name_from_args(PackedStringArray(["unit"])) == "", "no argument")


func test_profile_values_match_measured_packages() -> void:
	# PROJECT_STATE.md: iPhone package cap60_combo_occ_vis200, tablet package combo_e_aggressive_cap30.
	check(QualityProfiles.settings_for("high") == {"max_fps": 60, "occlusion": true,
			"visibility_end": {"trees": 200.0, "lamps": 200.0, "decor": 200.0, "facade_detail": 200.0}},
			"high = 60 FPS cap + occlusion + 200 m (%s)" % [QualityProfiles.settings_for("high")])
	check(QualityProfiles.settings_for("low") == {"max_fps": 30, "occlusion": true,
			"visibility_end": {"trees": 100.0, "lamps": 100.0, "decor": 100.0, "facade_detail": 100.0},
			"camera_far": 400.0, "fog": true, "shadows": "off", "render_scale": 0.6, "lod_threshold": 4.0},
			"low = combo_e (%s)" % [QualityProfiles.settings_for("low")])
	check(QualityProfiles.settings_for("none").is_empty(), "none sets nothing")


func test_experiment_overrides_profile_keys() -> void:
	var experiment := PerfConfig.from_dict({"max_fps": 0, "shadows": "single"})
	var merged := RenderSettings.merge([QualityProfiles.settings_for("low"), experiment.settings])
	check(merged.max_fps == 0 and merged.shadows == "single", "experiment keys win")
	check(merged.occlusion and is_equal_approx(merged.render_scale, 0.6) and is_equal_approx(merged.camera_far, 400.0), "unset keys come from the profile")


func test_apply_low_profile() -> void:
	var s := _setup()
	var map: Node3D = s.map
	s.settings.apply(QualityProfiles.settings_for("low"))
	check(is_equal_approx(map.get_node("Trees_1_1").visibility_range_end, 100.0) and is_equal_approx(map.get_node("Detail_1_1").visibility_range_end, 100.0), "100 m ranges on trees and facade detail")
	check(is_equal_approx(map.get_node("Buildings_1_1").visibility_range_end, 0.0), "building shells unlimited")
	check(is_equal_approx(s.camera.far, 400.0), "far plane")
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH and is_equal_approx(environment.fog_depth_end, 400.0), "depth fog to the far plane")
	check(not map.get_node("Sun").shadow_enabled, "shadows off")
	check(is_equal_approx(s.viewport.scaling_3d_scale, 0.6) and is_equal_approx(s.viewport.mesh_lod_threshold, 4.0), "render scale and LOD")
	check(Engine.max_fps == 30 and s.viewport.use_occlusion_culling, "frame cap and occlusion")
	_restore()


func test_switching_to_none_restores_defaults() -> void:
	var s := _setup()
	var map: Node3D = s.map
	s.settings.apply(QualityProfiles.settings_for("low"))
	s.settings.apply(RenderSettings.merge([{}, PerfConfig.from_dict({"hide": ["trees"]}).settings]))
	check(not map.get_node("Trees_1_1").visible and map.get_node("Detail_1_1").visible, "only the experiment's hidden category is hidden")
	s.settings.apply({})
	check(map.get_node("Trees_1_1").visible, "hidden category visible again")
	check(is_equal_approx(map.get_node("Trees_1_1").visibility_range_end, 0.0), "ranges cleared")
	check(is_equal_approx(s.camera.far, 1500.0), "far plane restored")
	check(not map.get_node("WorldEnvironment").environment.fog_enabled, "fog restored")
	var sun: DirectionalLight3D = map.get_node("Sun")
	check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "shadows restored")
	check(is_equal_approx(s.viewport.scaling_3d_scale, 1.0) and is_equal_approx(s.viewport.mesh_lod_threshold, 1.0), "viewport restored")
	check(Engine.max_fps == _saved_max_fps and not s.viewport.use_occlusion_culling, "frame cap and occlusion restored")
	_restore()


func test_occluder_fallback_builds_from_collision() -> void:
	var s := _setup("res://does/not/exist_occluders.scn")
	s.settings.apply({"occlusion": true})
	var report: Dictionary = s.settings.occluder_report
	check(report.get("source") == "runtime", "missing baked file falls back to runtime building (%s)" % [report])
	check(report.get("occluders") == 1 and report.get("triangles") == 2, "one occluder with the collision's two triangles")
	_restore()


func test_shared_vertices_keep_triangles() -> void:
	var map := _fixture_map()
	add_node(map)
	var groups := RenderSettings.meshes_by_category(map)
	var plain := RenderSettings.build_occluders(map, groups)
	var shared := RenderSettings.build_occluders(map, groups, true)
	check(RenderSettings.occluder_stats(plain) == RenderSettings.occluder_stats(shared), "same occluders and triangles")
	var plain_vertices: int = (plain.get_child(0) as OccluderInstance3D).occluder.vertices.size()
	var shared_vertices: int = (shared.get_child(0) as OccluderInstance3D).occluder.vertices.size()
	check(plain_vertices == 6 and shared_vertices == 4, "shared vertices: 6 -> 4")
	plain.free()
	shared.free()


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
		check(RenderSettings.category_of(node_name) == expected[node_name], "%s -> %s (got '%s')" % [node_name, expected[node_name], RenderSettings.category_of(node_name)])
