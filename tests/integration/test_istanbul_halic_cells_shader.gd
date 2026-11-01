extends "res://tests/integration/facade_map_case.gd"
## The shader facade map (istanbul_halic_cells_shader, build_map.py --facade
## shader --detail-cell 40): one panel per wall drawn by facade_windows.gdshader;
## the shared tests are in facade_map_case.gd.

const FACADE_SHADER := "res://maps/istanbul_halic_cells_shader/facade_windows.gdshader"


func map_id() -> String:
	return "istanbul_halic_cells_shader"


func root_name() -> StringName:
	return &"IstanbulHalicCellsShader"


func model_sha256() -> String:
	return "60b9f7295be0ca536822126cbcf182de8f6db96de772314c5a80a39b31755303"


func max_detail_share() -> float:
	return 0.15


func check_materials(model: Node) -> void:
	var shaded := 0
	var wrong: Array[String] = []
	var palette := {}
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface)
			var override := node.get_surface_override_material(surface)
			if material and material.resource_name == "Istanbul_FacadeWindows":
				var shader_ok := override is ShaderMaterial and (override as ShaderMaterial).shader.resource_path == FACADE_SHADER
				shaded += int(shader_ok)
				if not shader_ok or not str(node.name).begins_with("Detail_"):
					wrong.append(str(node.name))
			else:
				if override != null:
					wrong.append(str(node.name))
				if material is BaseMaterial3D:
					palette[material] = (material as BaseMaterial3D).vertex_color_use_as_albedo
	# A cell whose buildings have no wall of 2.8 m or more has no panel and keeps the palette material.
	check(shaded > 2400 and wrong.is_empty(), "the facade cells with panels (and nothing else) drawn with the window shader (%d of 2,465 cells; wrong: %s)" % [shaded, wrong.slice(0, 5)])
	check(palette.size() == 6 and not palette.values().has(false), "the other surfaces keep the 6 shared materials with vertex colors (%d)" % palette.size())


func test_panels_carry_the_window_layout() -> void:
	# The panels' UV2 holds the column width and the wall height (0 elsewhere);
	# every facade cell with panels has them in whole quads.
	await _setup()
	var cells_with_panels := 0
	var panels := 0
	var bad: Array[String] = []
	for cell: MeshInstance3D in _model().find_children("Detail_*", "MeshInstance3D", true, false).slice(0, 200):
		var raw: Variant = cell.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		if raw == null:
			continue
		var uv2: PackedVector2Array = raw
		var count := 0
		for value in uv2:
			if value.x > 0.0:
				count += 1
				if value.x > 6.6 + 1e-3 or value.y < 4.0 - 1e-3:
					bad.append("%s %s" % [cell.name, value])
		cells_with_panels += int(count > 0)
		panels += count
	check(cells_with_panels > 150 and panels % 4 == 0, "panels in %d of 200 facade cells (%d vertices)" % [cells_with_panels, panels])
	check(bad.is_empty(), "column widths up to 6.6 m and walls at least 4 m high; not: %s" % [bad.slice(0, 5)])


func test_facade_experiment_keys() -> void:
	# Measurement only: the facade material on the panels (flat, simple,
	# shader), its render priority, and the warm-up draw after loading.
	await _setup()
	var surfaces := _facade_surfaces()
	check(surfaces.size() > 2400, "facade surfaces found (%d)" % surfaces.size())
	game.apply_runtime_settings({"facade_material": "flat"})
	check(surfaces.all(func(entry: Array) -> bool: return (entry[0] as MeshInstance3D).get_surface_override_material(entry[1]) == null), "flat: the GLB material (the wall colour) on every panel")
	game.apply_runtime_settings({"facade_material": "simple", "facade_priority": -1})
	var simple: Variant = (surfaces[0][0] as MeshInstance3D).get_surface_override_material(surfaces[0][1])
	check(simple is ShaderMaterial and (simple as ShaderMaterial).shader.resource_path.ends_with("facade_windows_simple.gdshader"), "simple: the simplified shader")
	check(game.world.map_root.facade_material.render_priority == -1, "render priority set on the window shader")
	game.apply_runtime_settings({"facade_material": "shader", "facade_warmup": true})
	check(surfaces.all(func(entry: Array) -> bool: return (entry[0] as MeshInstance3D).get_surface_override_material(entry[1]) == game.world.map_root.facade_material), "shader: the window shader again")
	var camera: Camera3D = game.camera_rig.camera
	await process_frames(1)
	check(camera.get_child_count() == 1 and camera.get_child(0) is MeshInstance3D, "warm-up probe in front of the camera")
	await process_frames(5)
	check(camera.get_child_count() == 0, "warm-up probe gone after a few frames")


func test_traced_benchmark() -> void:
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "trace_test", "profile": "low",
			"bench": {"trace": true, "warmup_s": 0.3, "measure_s": 0.5, "screenshots": false, "quit_when_done": false, "views": ["Galata street, facing south"]}})
	var bench: PerfBenchmark = game.apply_perf_experiment(config)
	var results: Array = await bench.finished
	var result: Dictionary = results[0]
	var frames := (result.trace.measure.frame_ms as String).split(",")
	check(frames.size() == result.frames and (result.trace.warmup.frame_ms as String).split(",").size() > 0, "every frame of the warm-up and the measurement kept (%d)" % frames.size())
	check((result.trace.measure.gpu_ms as String).split(",").size() == frames.size() and result.has("gpu_ms") and result.has("render_cpu_p99_ms"), "GPU and render CPU times per frame")
	check(result.pipelines.size() == 5 and result.warmup_pipelines.size() == 5 and result.has("warmup_long_frames"), "pipeline compilations by source")
	game.set_quality_profile("none")


func _facade_surfaces() -> Array:
	var found := []
	for node: MeshInstance3D in _model().find_children("Detail_*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface)
			if material and material.resource_name == "Istanbul_FacadeWindows":
				found.append([node, surface])
	return found
