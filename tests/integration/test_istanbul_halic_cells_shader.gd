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
