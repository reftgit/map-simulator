extends "res://tests/test_case.gd"
## The import tool's checks, fixes, classification, colliders, and occluders
## (tools/map_import/, docs/MAP_CONTRACT.md) on small synthetic scenes.

const MapImporter := preload("res://tools/map_import/map_importer.gd")
const MapGeometry := preload("res://tools/map_import/map_geometry.gd")
const MapClassifier := preload("res://tools/map_import/map_classifier.gd")
const MapColliders := preload("res://tools/map_import/map_colliders.gd")


## An ArrayMesh of axis-aligned boxes (centre, size), without normals unless asked.
static func _boxes(boxes: Array, normals := false) -> ArrayMesh:
	var positions := PackedVector3Array()
	for entry: Array in boxes:
		var box := BoxMesh.new()
		box.size = entry[1]
		var arrays := box.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			positions.append(vertices[index] + (entry[0] as Vector3))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return MapGeometry.with_flat_normals(mesh) if normals else mesh


## A flat quad (two triangles) of `size` facing `up` (+Y or +Z), centred at `center`.
static func _plane(size: float, center := Vector3.ZERO, facing_z := false) -> ArrayMesh:
	var h := size * 0.5
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	if facing_z:
		corners = [Vector3(-h, h, 0), Vector3(h, h, 0), Vector3(h, -h, 0), Vector3(-h, -h, 0)]
	var positions := PackedVector3Array()
	for i in [0, 1, 2, 0, 2, 3]:
		positions.append((corners[i] as Vector3) + center)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A scene root holding `parts`: [name, mesh, position].
static func _scene(parts: Array) -> Node3D:
	var root := Node3D.new()
	for part: Array in parts:
		var node := MeshInstance3D.new()
		node.name = part[0]
		node.mesh = part[1]
		node.position = part[2] if part.size() > 2 else Vector3.ZERO
		root.add_child(node)
	return root


## A small town: 60 m ground, two houses (one mesh each), a lamp, an unnamed block.
static func _town() -> Node3D:
	return _scene([
		["ground_main", _plane(60.0)],
		["house_1", _boxes([[Vector3(0, 4, 0), Vector3(8, 8, 10)]]), Vector3(10, 0, 0)],
		["house_2", _boxes([[Vector3(0, 3, 0), Vector3(6, 6, 6)], [Vector3(10, 3, 0), Vector3(6, 6, 6)]]), Vector3(-20, 0, 10)],
		["StreetLamp_1", _boxes([[Vector3(0, 3, 0), Vector3(0.2, 6, 0.2)]]), Vector3(0, 0, -10)],
		["Object_77", _boxes([[Vector3(0, 5, 0), Vector3(5, 10, 5)]]), Vector3(20, 0, -20)],
		["Object_78", _boxes([[Vector3(0, 0.5, 0), Vector3(1, 1, 1)]]), Vector3(-5, 0, -5)],
	])


func _checks(importer: RefCounted, id: String) -> Array:
	return importer.checks.filter(func(c: Dictionary) -> bool: return c.id == id)


func _result(importer: RefCounted, id: String) -> String:
	var found := _checks(importer, id)
	return found[-1].result if not found.is_empty() else ""


func test_configuration_is_validated() -> void:
	var importer := MapImporter.new()
	check(importer.parse_config({}).is_empty(), "an empty configuration is valid")
	check(importer.parse_config({"scale": 10, "up_axis": "z", "single_sided": true, "colliders": {"buildings": "box"},
			"category_rules": [{"category": "ground", "prefix": "Floor"}]}).is_empty(), "a full configuration is valid")
	check(not importer.parse_config({"scael": 10}).is_empty(), "a typo is rejected")
	check(not importer.parse_config({"scale": "10"}).is_empty(), "a wrong type is rejected")
	check(not importer.parse_config({"scale": -1}).is_empty(), "a negative scale is rejected")
	check(not importer.parse_config({"up_axis": "x"}).is_empty(), "an unknown axis is rejected")
	check(not importer.parse_config({"colliders": {"buildings": "sphere"}}).is_empty(), "an unknown collider type is rejected")
	check(not importer.parse_config({"category_rules": [{"category": "roofs", "prefix": "R"}]}).is_empty(), "an unknown category is rejected")
	check(not importer.parse_config({"category_rules": [{"category": "ground", "prefix": "A", "regex": "B"}]}).is_empty(), "two match kinds in one rule are rejected")
	check(not importer.parse_config({"id": "Bad Id"}).is_empty(), "an id with capitals or spaces is rejected")


func test_default_vocabulary() -> void:
	var rules := CategoryRules.new()
	rules.rules = MapClassifier.vocabulary_rules()
	var expected := {"osm_12_walls": "buildings", "ms_0406_inferred_roof": "buildings", "ms_0405_inferred_windows": "facade_detail",
			"ms_0405_inferred_timber": "facade_detail", "road_osm_32484703": "ground", "terrain_DEM_resampled_2p5m": "ground",
			"road-sign-stop_3_4": "decor", "traffic-light_1": "decor", "light-square_3_4": "lamps", "StreetLamps_01_16": "lamps",
			"tree-large_2_2": "trees", "fence-1x2_5_5": "decor", "Water": "water", "building-type-a_1_1": "buildings",
			"tile-low_0_0": "ground", "Object_77": ""}
	for node_name: String in expected:
		var node := MeshInstance3D.new()
		node.name = node_name
		check(rules.category_of(node) == expected[node_name], "%s -> %s (got %s)" % [node_name, expected[node_name], rules.category_of(node)])
		node.free()


func test_shape_classification() -> void:
	var up := {"area": 100.0, "up": 90.0, "down": 0.0, "vertical": 10.0}
	var walls := {"area": 100.0, "up": 20.0, "down": 20.0, "vertical": 60.0}
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(40, 3, 30)), up) == "ground", "wide, low, facing up: ground")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(40, 20, 30)), up) != "ground", "too high for ground")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(8, 9, 10)), walls) == "buildings", "high box with walls: buildings")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(1.5, 9, 10)), walls) == "", "too thin for a building")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(1, 1, 1)), walls) == "decor", "small: decor")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(3, 1, 30)), up) == "ground", "a long flat strip (a road): ground")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(0.3, 12, 0.3)), walls) == "", "a tall pole: no category")


func test_flat_normals_face_out() -> void:
	var mesh := _boxes([[Vector3(0, 0, 0), Vector3(2, 2, 2)]])
	check(not MapGeometry.has_normals(mesh), "the test box has no normals")
	var flat := MapGeometry.with_flat_normals(mesh)
	check(MapGeometry.has_normals(flat), "normals added")
	var arrays := flat.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(positions.size() == 36, "one vertex per triangle corner (%d)" % positions.size())
	var outward := 0
	for t in range(0, positions.size(), 3):
		var center := (positions[t] + positions[t + 1] + positions[t + 2]) / 3.0
		if normals[t].dot(center) > 0.0 and is_equal_approx(normals[t].length(), 1.0):
			outward += 1
	check(outward == 12, "all 12 face normals point out of the box (%d)" % outward)
	var stats := MapGeometry.stats(flat)
	check(stats.flipped == 0 and stats.zero_area == 0 and stats.triangles == 12, "winding agrees with the normals: %s" % [stats])
	check(is_equal_approx(stats.up, 4.0) and is_equal_approx(stats.down, 4.0) and is_equal_approx(stats.vertical, 16.0), "face areas by orientation: %s" % [stats])


func test_shells_and_parts() -> void:
	var closed := MapGeometry.shell(_boxes([[Vector3.ZERO, Vector3(2, 2, 2)]]))
	check(closed.boundary == 0 and is_equal_approx(closed.volume, 8.0), "closed box: no boundary edges, volume 8 (%s)" % [closed])
	var open := MapGeometry.shell(_plane(4.0))
	check(open.boundary == 4, "a quad has 4 boundary edges (%s)" % [open])
	var inverted := MapGeometry.shell(MapGeometry.transformed(_boxes([[Vector3.ZERO, Vector3(2, 2, 2)]]), Basis.IDENTITY.scaled(Vector3(1, 1, -1))))
	check(inverted.volume > 0.0, "a mirrored box keeps facing out (winding reversed): %s" % [inverted])
	var parts := MapGeometry.parts(_boxes([[Vector3.ZERO, Vector3(1, 1, 1)], [Vector3(5, 0, 0), Vector3(1, 1, 1)]]))
	check(parts.size() == 2 and parts[0].size() == 8 and parts[1].size() == 8, "two separate boxes are two parts of 8 points")


func test_scale_check_and_fix() -> void:
	var tiny := func() -> Node3D:
		return _scene([["ground", _plane(1.2)], ["house", _boxes([[Vector3(0, 0.4, 0), Vector3(1, 0.8, 1)]]), Vector3(0.2, 0, 0)]])
	var importer := MapImporter.new()
	check(not importer.process(tiny.call()), "a 1.2-unit model fails")
	check(_result(importer, "C2") == "FAIL" and _checks(importer, "C2")[0].message.contains("suggested: 10"), "C2 suggests a scale of 10: %s" % [_checks(importer, "C2")])
	importer.model.free()
	var scaled := MapImporter.new()
	scaled.parse_config({"scale": 25})
	check(scaled.process(tiny.call()), "scaled by 25 it passes")
	check(_result(scaled, "C2") == "FIXED", "C2 fixed by the configuration")
	var house := scaled.model.get_node("house") as MeshInstance3D
	check(house.transform.basis.is_equal_approx(Basis.IDENTITY) and house.position.is_equal_approx(Vector3(5, 0, 0)), "the node keeps a rigid transform, its position scaled (%s)" % house.transform)
	check(house.mesh.get_aabb().size.is_equal_approx(Vector3(25, 20, 25)), "the scale is baked into the mesh (%s)" % house.mesh.get_aabb().size)
	scaled.model.free()


func test_z_up_check_and_fix() -> void:
	var lying := func() -> Node3D:
		return _scene([["ground", _plane(60.0, Vector3.ZERO, true)], ["block", _boxes([[Vector3(0, 0, 4), Vector3(8, 8, 8)]])]])
	var importer := MapImporter.new()
	check(not importer.process(lying.call()), "a Z-up model fails")
	check(_result(importer, "C3") == "FAIL" and _checks(importer, "C3")[0].message.contains("\"up_axis\": \"z\""), "C3 names the fix: %s" % [_checks(importer, "C3")])
	importer.model.free()
	var turned := MapImporter.new()
	turned.parse_config({"up_axis": "z"})
	check(turned.process(lying.call()), "with up_axis z it passes")
	check(_result(turned, "C3") == "FIXED", "C3 fixed")
	var ground := turned.model.get_node("ground") as MeshInstance3D
	check(MapGeometry.stats(ground.mesh, ground.transform.basis).up > 3000.0, "the ground faces up now")
	turned.model.free()


func test_classification_colliders_and_groups() -> void:
	var importer := MapImporter.new()
	check(importer.process(_town()), "the synthetic town passes: %s" % [importer.checks.filter(func(c: Dictionary) -> bool: return c.result == "FAIL")])
	var categories := {}
	for node_name: String in importer.meshes:
		categories[node_name] = [importer.meshes[node_name].category, importer.meshes[node_name].by]
	check(categories.ground_main == ["ground", "vocabulary"] and categories.house_1 == ["buildings", "vocabulary"], "named meshes by the vocabulary: %s" % [categories])
	check(categories.StreetLamp_1 == ["lamps", "vocabulary"], "the lamp by its camel-case name")
	check(categories.Object_77 == ["buildings", "shape"] and categories.Object_78 == ["decor", "shape"], "unnamed meshes by shape: %s" % [categories])
	check(importer.model.get_node("Object_77").is_in_group("map_category_buildings"), "a shape result is stored as a group")
	for node_name: String in importer.meshes:
		var node := importer.model.get_node(node_name)
		check(importer.rules.category_of(node) == importer.meshes[node_name].category, "%s: the saved rules give the same category" % node_name)
	check(_result(importer, "R1") == "WARN", "R1 reports the shape-classified meshes")
	var ground_body := importer.model.get_node("ground_main/StaticBody3D") as StaticBody3D
	check(ground_body and ground_body.get_child(0).shape is ConcavePolygonShape3D and ground_body.collision_layer == 1, "ground: a trimesh on the world layer")
	var house_2 := importer.model.get_node("house_2/StaticBody3D") as StaticBody3D
	check(house_2 and house_2.get_child_count() == 2 and house_2.get_child(0).shape is ConvexPolygonShape3D, "a building mesh of two parts: two convex hulls")
	check((house_2.get_child(0).shape as ConvexPolygonShape3D).points.size() == 8, "a hull keeps only its 8 corners")
	check(not importer.model.get_node("StreetLamp_1").has_node("StaticBody3D") and not importer.model.get_node("Object_78").has_node("StaticBody3D"), "lamps and decor have no collider")
	check(_result(importer, "R2") == "INFO" and importer.summary.colliders.shapes == 5, "R2: generated colliders (%s)" % [importer.summary.colliders])
	importer.model.free()


func test_collider_types_from_configuration() -> void:
	var importer := MapImporter.new()
	importer.parse_config({"colliders": {"buildings": "box", "lamps": "convex"}})
	importer.process(_town())
	var house := importer.model.get_node("house_1/StaticBody3D/CollisionShape3D") as CollisionShape3D
	check(house.shape is BoxShape3D and (house.shape as BoxShape3D).size.is_equal_approx(Vector3(8, 8, 10)) and house.position.is_equal_approx(Vector3(0, 4, 0)), "box collider around the part")
	check(importer.model.get_node("StreetLamp_1").has_node("StaticBody3D"), "lamps get the configured convex collider")
	importer.model.free()


func test_collision_nodes_replace_category_colliders() -> void:
	var scene := _scene([["Floor-col", _plane(60.0)], ["house_1", _boxes([[Vector3(0, 4, 0), Vector3(8, 8, 10)]]), Vector3(10, 0, 0)],
			["Wall-convcolonly", _boxes([[Vector3(0, 2, 0), Vector3(20, 4, 1)]]), Vector3(0, 0, 25)]])
	var importer := MapImporter.new()
	importer.parse_config({"category_rules": [{"category": "ground", "prefix": "Floor"}]})
	check(importer.process(scene), "passes")
	check(importer.model.has_node("Floor") and not importer.model.has_node("Floor-col"), "the -col suffix is dropped from the name")
	check(importer.model.get_node("Floor/StaticBody3D/CollisionShape3D").shape is ConcavePolygonShape3D, "-col: trimesh")
	var wall := importer.model.get_node("Wall")
	check(not wall is MeshInstance3D and wall.get_node("StaticBody3D/CollisionShape3D").shape is ConvexPolygonShape3D, "-convcolonly: a convex collider without a mesh")
	check(not importer.model.get_node("house_1").has_node("StaticBody3D"), "with collision nodes, no category colliders")
	check(_result(importer, "R2") == "INFO" and _checks(importer, "R2")[0].result == "PASS", "R2 uses the collision nodes: %s" % [_checks(importer, "R2")])
	importer.model.free()


func test_vertex_colours_and_double_sided_materials() -> void:
	var arrays := _plane(60.0).surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(Color(0.4, 0.5, 0.3))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var importer := MapImporter.new()
	importer.parse_config({"single_sided": true})
	importer.process(_scene([["ground", mesh], ["house", _boxes([[Vector3(0, 4, 0), Vector3(8, 8, 10)]])]]))
	var fixed := (importer.model.get_node("ground") as MeshInstance3D).get_active_material(0) as StandardMaterial3D
	check(fixed.vertex_color_use_as_albedo and fixed.cull_mode == BaseMaterial3D.CULL_BACK, "vertex colours shown, back faces culled")
	check(_result(importer, "R5") == "FIXED" and _result(importer, "R6") == "FIXED", "R5 and R6 fixed")
	check(importer.model.get_node("ground").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null, "flat normals keep the colours")
	importer.model.free()


func test_occluders_from_trimesh_convex_and_box_colliders() -> void:
	var importer := MapImporter.new()
	importer.parse_config({"colliders": {"buildings": "box"}})
	importer.process(_town())
	add_node(importer.model)
	var occluders: Node3D = importer.build_occluders()
	var stats := RenderSettings.occluder_stats(occluders)
	# ground: 2 triangles; house_1: 1 box; house_2: 2 boxes; Object_77: 1 box (12 triangles each).
	check(stats.instances == 5 and stats.triangles == 2 + 4 * 12, "occluders from the ground trimesh and the building boxes: %s" % [stats])
	occluders.free()
	var box := BoxShape3D.new()
	check(RenderSettings.shape_faces(box).size() == 36 and RenderSettings.shape_faces(MapColliders.hull(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]))).size() == 12,
			"a box has 12 triangles, a tetrahedron hull 4")
	check(RenderSettings.shape_faces(SphereShape3D.new()).is_empty(), "other shapes give none")


func test_budget_and_bounds_checks() -> void:
	var far := MapImporter.new()
	check(not far.process(_scene([["ground", _plane(60.0, Vector3(30000, 0, 0))], ["house", _boxes([[Vector3(30000, 4, 0), Vector3(8, 8, 10)]])]])), "a model 30 km from the origin fails")
	check(_result(far, "C5") == "FAIL", "C5 names the distance")
	far.model.free()
	var fine := MapImporter.new()
	fine.process(_town())
	check(_result(fine, "C5") == "PASS" and _result(fine, "C6") == "PASS" and _result(fine, "C1") == "PASS", "the town passes C1, C5, C6")
	fine.model.free()
