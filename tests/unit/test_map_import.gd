extends "res://tests/test_case.gd"
## The import tool's checks, fixes, classification, colliders, and occluders
## (tools/map_import/, docs/MAP_CONTRACT.md) on small synthetic scenes.

const MapImporter := preload("res://tools/map_import/map_importer.gd")
const MapGeometry := preload("res://tools/map_import/map_geometry.gd")
const MapClassifier := preload("res://tools/map_import/map_classifier.gd")
const MapColliders := preload("res://tools/map_import/map_colliders.gd")
const MapUnits := preload("res://tools/map_import/map_units.gd")


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
	check(importer.parse_config({"up_axis": "-z"}).is_empty() and importer.parse_config({"up_axis": "x"}).is_empty(), "every axis direction is valid")
	check(not importer.parse_config({"up_axis": "w"}).is_empty(), "an unknown axis is rejected")
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
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(1.5, 9, 10)), walls) == "buildings", "a tall thin wall is a building")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(1, 1, 1)), walls) == "decor", "small: decor")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(3, 1, 30)), up) == "ground", "a long flat strip (a road): ground")
	check(MapClassifier.category_by_shape(AABB(Vector3.ZERO, Vector3(0.3, 12, 0.3)), walls) == "", "a tall pole: no category")


## Category by shape of a mesh as the importer measures it (no names).
func _shape_of(mesh: Mesh, repeats := 1) -> String:
	var stats := MapGeometry.stats(mesh)
	return MapClassifier.category_by_shape(mesh.get_aabb(), stats, MapGeometry.profile(mesh, Transform3D.IDENTITY), repeats)


func test_shape_rules_on_measured_meshes() -> void:
	var tree := _boxes([[Vector3(0, 1.5, 0), Vector3(0.3, 3, 0.3)], [Vector3(0, 4.5, 0), Vector3(3, 3, 3)]])
	check(_shape_of(tree) == "trees", "a trunk under a crown: trees (%s)" % _shape_of(tree))
	var lamp := _boxes([[Vector3(0, 3, 0), Vector3(0.2, 6, 0.2)], [Vector3(0.8, 5.9, 0), Vector3(1.6, 0.15, 0.2)]])
	check(_shape_of(lamp) == "decor", "a pole with an arm: decor, not a tree (%s)" % _shape_of(lamp))
	check(_shape_of(_boxes([[Vector3(0, 0.75, 0), Vector3(4, 1.5, 0.1)]])) == "decor", "a fence segment: decor")
	var ring := _boxes([[Vector3(0, 1, -5), Vector3(10, 2, 0.1)], [Vector3(0, 1, 5), Vector3(10, 2, 0.1)], [Vector3(-5, 1, 0), Vector3(0.1, 2, 10)], [Vector3(5, 1, 0), Vector3(0.1, 2, 10)]])
	check(_shape_of(ring) == "decor", "a fence round a yard, open from above: decor, not a building (%s)" % _shape_of(ring))
	check(_shape_of(_boxes([[Vector3(0, 0.6, 0), Vector3(4.5, 1.2, 2)]])) == "decor", "a low object (a car, a bench): decor")
	check(_shape_of(_boxes([[Vector3(0, 10, 0), Vector3(1.5, 20, 1.5)]])) == "buildings", "a tall slender tower: buildings")
	check(_shape_of(_boxes([[Vector3(0, 0.1, 0), Vector3(10, 0.2, 10)]])) == "ground", "a flat 10 m tile: ground")
	check(_shape_of(_boxes([[Vector3(0, 9, 0), Vector3(255, 18, 255)]])) == "ground", "a closed 255 m slab (a printed relief): ground, its underside not counted")
	check(_shape_of(_boxes([[Vector3(0, 4, 0), Vector3(10, 8, 12)]])) == "buildings", "a closed house box: buildings")
	check(_shape_of(_boxes([[Vector3(0, 2.4, 0), Vector3(2.5, 4.8, 1.5)]]), 3) == "decor" and _shape_of(_boxes([[Vector3(0, 2.4, 0), Vector3(2.5, 4.8, 1.5)]])) == "", "a 4.8 m object: decor when repeated, else no category")


func test_one_mesh_holding_a_town_is_split() -> void:
	var blocks := []
	for i in 12:
		blocks.append([Vector3((i % 4) * 10.0, 6.0, (i / 4) * 10.0), Vector3(6, 12, 6)])
	blocks.append([Vector3(5, 0.5, 25), Vector3(4, 1, 2)])
	var timber := []
	for i in 8:
		timber.append([Vector3(0, 1.0 + i * 1.2, 4.05), Vector3(6, 0.15, 0.1)])
	var importer := MapImporter.new()
	check(importer.process(_scene([["ground_main", _plane(80.0)], ["Object_1", _boxes(blocks), Vector3(-15, 0, -15)],
			["Object_2", _boxes([[Vector3(0, 4, 0), Vector3(8, 8, 8)]] + timber), Vector3(20, 0, 20)]])), "passes")
	check(not importer.model.has_node("Object_1") and importer.model.has_node("Object_1_000") and importer.model.has_node("Object_1_012"), "the 13 objects became 13 meshes")
	var block := importer.model.get_node("Object_1_005") as MeshInstance3D
	check(importer.meshes[str(block.name)].category == "buildings" and block.transform.origin.is_equal_approx(Vector3(-15, 0, -15)), "each keeps the node's transform and gets its own category")
	check(importer.meshes["Object_1_012"].category == "decor", "the small low one: decor")
	check(block.mesh.get_aabb().size.is_equal_approx(Vector3(6, 12, 6)), "a part's mesh holds only its own triangles (%s)" % block.mesh.get_aabb().size)
	check(importer.model.has_node("Object_2"), "a building with pieces at many heights stays one mesh")
	check(_result(importer, "R3") == "PASS" and _checks(importer, "R3")[0].result == "FIXED", "R3 reports the split: %s" % [_checks(importer, "R3")])
	importer.model.free()


func test_detail_and_roof_on_a_building() -> void:
	var walls := _boxes([[Vector3(0, 3, 0), Vector3(10, 6, 8)]])
	var windows := []
	for i in 6:
		windows.append([Vector3(-4 + i * 1.6, 2 + (i % 2) * 2.5, 4.05), Vector3(1, 1.2, 0.1)])
	var roof := _boxes([[Vector3(0, 7, 0), Vector3(10.6, 2, 8.6)]])
	var importer := MapImporter.new()
	importer.parse_config({"use_default_name_rules": false})
	check(importer.process(_scene([["Floor", _plane(60.0)], ["A", walls], ["B", _boxes(windows)], ["C", roof]])), "passes without the vocabulary")
	check(importer.meshes.A.category == "buildings", "the walls: buildings")
	check(importer.meshes.B.category == "facade_detail", "thin pieces on its walls: facade detail (%s)" % importer.meshes.B.category)
	check(importer.meshes.C.category == "buildings", "a cover above it: its roof, buildings (%s)" % importer.meshes.C.category)
	check(importer.summary.attached == {"facade_detail": 1, "roof": 1}, "counted: %s" % [importer.summary.attached])
	importer.model.free()


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


func test_z_up_is_detected_and_turned() -> void:
	var lying := func() -> Node3D:
		return _scene([["ground", _plane(60.0, Vector3.ZERO, true)], ["block", _boxes([[Vector3(0, 0, 4), Vector3(8, 8, 8)]])]])
	var importer := MapImporter.new()
	check(importer.process(lying.call()), "a Z-up model passes: the tool turns it")
	check(_result(importer, "C3") == "FIXED" and _checks(importer, "C3")[0].message.contains("+Z up"), "C3 says what it did: %s" % [_checks(importer, "C3")])
	var ground := importer.model.get_node("ground") as MeshInstance3D
	check(MapGeometry.stats(ground.mesh, ground.transform.basis).up > 3000.0, "the ground faces up now")
	check(ground.transform.basis.is_equal_approx(MapUnits.TO_Y_UP["+z"]) and ground.mesh.get_aabb().size.z < 0.01, "turned rigidly by the node, the mesh not rebaked")
	var block := importer.model.get_node("block") as MeshInstance3D
	check((block.transform * block.mesh.get_aabb()).position.y > -0.01, "the block stands on the ground (%s)" % (block.transform * block.mesh.get_aabb()))
	importer.model.free()
	var kept := MapImporter.new()
	kept.parse_config({"up_axis": "y"})
	kept.process(lying.call())
	check(_result(kept, "C3") == "WARN" and (kept.model.get_node("ground") as Node3D).transform.basis.is_equal_approx(Basis.IDENTITY), "up_axis y keeps the file's axes, with a warning")
	kept.model.free()
	var configured := MapImporter.new()
	configured.parse_config({"up_axis": "z"})
	check(configured.process(lying.call()) and _result(configured, "C3") == "FIXED", "up_axis z turns it too")
	configured.model.free()


func test_up_direction_from_box_faces_and_base() -> void:
	# Faces: flat area toward each direction, with area-weighted coordinates.
	var town := MapUnits.detect_up(Vector3(300, 40, 260), {"+y": 60000.0, "-y": 3000.0, "+x": 4000.0, "-x": 4000.0, "+z": 4000.0, "-z": 4000.0})
	check(town.decided and town.up == "+y", "a town: flat across Y, ground facing up (%s)" % town.reason)
	# A printed relief (Z-up slab): both sides alike, so the base decides.
	var slab_faces := {"+z": 65000.0, "-z": 65000.0, "at_+z": 65000.0 * 1.1, "at_-z": 65000.0 * 11.0, "+x": 2000.0, "-x": 2000.0}
	var slab := MapUnits.detect_up(Vector3(255, 255, 19), slab_faces)
	check(slab.axis == "z", "the slab's axis is Z (%s)" % slab.reason)
	var based := MapUnits.detect_up(Vector3(255, 255, 19), slab_faces, Vector2(65000.0, 100.0))
	check(based.decided and based.up == "+z", "its base is at the low end: +Z up, whatever the winding (%s)" % based.reason)
	# Upside down: the ground faces −Y and lies at the top.
	var upside := MapUnits.detect_up(Vector3(200, 30, 200), {"+y": 500.0, "-y": 40000.0}, Vector2(0.0, 40000.0))
	check(upside.decided and upside.up == "-y", "upside down: -Y up (%s)" % upside.reason)
	# Inside out: the ground at the bottom but facing −Y: the cues disagree.
	var inverted := MapUnits.detect_up(Vector3(200, 30, 200), {"+y": 500.0, "-y": 40000.0}, Vector2(40000.0, 0.0))
	check(not inverted.decided and inverted.up == "+y", "base and faces disagree: undecided, the file's +Y kept (%s)" % inverted.reason)
	var sideways := MapUnits.detect_up(Vector3(20, 300, 300), {"+x": 50000.0, "-x": 1000.0, "+y": 3000.0, "-y": 3000.0})
	check(sideways.decided and sideways.up == "+x", "X-up (%s)" % sideways.reason)
	var cube := MapUnits.detect_up(Vector3(10, 10, 10), {"+x": 100.0, "-x": 100.0, "+y": 100.0, "-y": 100.0, "+z": 100.0, "-z": 100.0})
	check(not cube.decided, "a cube shows no up axis")
	# A cluster of towers without ground: walls outweigh roofs, the box decides.
	var towers := MapUnits.detect_up(Vector3(140, 24, 125), {"+y": 400.0, "-y": 400.0, "+x": 2900.0, "-x": 2900.0, "+z": 2900.0, "-z": 2900.0,
			"at_+y": 400.0 * 20.0, "at_-y": 0.0})
	check(towers.decided and towers.up == "+y", "towers on a very flat box: +Y (%s)" % towers.reason)


func test_inside_out_closed_mesh_is_turned_outward() -> void:
	var inverted := MapGeometry.turned_out(_boxes([[Vector3(0, 4, 0), Vector3(8, 8, 10)]]), true)
	check(MapGeometry.stats(inverted).volume < 0.0, "the test box is inside out")
	var importer := MapImporter.new()
	importer.process(_scene([["ground_main", _plane(60.0)], ["house_1", inverted, Vector3(10, 0, 0)]]))
	var house := importer.model.get_node("house_1") as MeshInstance3D
	var stats := MapGeometry.stats(house.mesh)
	check(_checks(importer, "C7").any(func(c: Dictionary) -> bool: return c.result == "FIXED"), "C7 FIXED: %s" % [_checks(importer, "C7")])
	check(stats.volume > 0.0 and stats.flipped == 0 and is_equal_approx(stats.up, 80.0), "turned outward: positive volume, the normals agree, the roof faces up (%s)" % [stats])
	var ground := importer.model.get_node("ground_main") as MeshInstance3D
	check(is_equal_approx(MapGeometry.stats(ground.mesh).up, 3600.0), "the open ground plane is left facing up")
	importer.model.free()


func test_units_are_recognised() -> void:
	check(MapUnits.unit_of(6000.0, 800.0).get("name", "") == "centimetres", "a 60 m town in centimetres (%s)" % [MapUnits.unit_of(6000.0, 800.0)])
	check(MapUnits.unit_of(2400.0, 315.0).get("name", "") == "inches", "a town in inches (%s)" % [MapUnits.unit_of(2400.0, 315.0)])
	check(MapUnits.unit_of(30000.0, 1000.0).get("name", "") == "centimetres", "a 300 m town in centimetres")
	check(MapUnits.unit_of(3.4, 0.27).is_empty(), "a model in arbitrary units fits no common unit")
	check(MapUnits.unit_of(5000.0, 450.0).has("choices"), "centimetres and inches fit about as well: the user decides (%s)" % [MapUnits.unit_of(5000.0, 450.0)])
	check(MapUnits.suggest_scale(0.27, 0.065) == 100.0 and MapUnits.suggest_scale(0.8, 0.6) == 10.0, "suggestions from the typical object's height and width")
	# A town modelled in centimetres: scaled by 0.01 without a configuration.
	var importer := MapImporter.new()
	check(importer.process(_scene([["ground", _plane(6000.0)], ["house_1", _boxes([[Vector3(0, 400, 0), Vector3(1000, 800, 1000)]]), Vector3(1000, 0, 0)],
			["house_2", _boxes([[Vector3(0, 300, 0), Vector3(800, 600, 900)]]), Vector3(-1500, 0, 800)]])), "the centimetre town passes")
	check(_result(importer, "C2") == "FIXED" and _checks(importer, "C2")[0].message.contains("centimetres"), "C2 names the unit: %s" % [_checks(importer, "C2")])
	check(importer.summary.bounds.size.is_equal_approx(Vector3(60, 8, 60)), "60 m wide after the scale (%s)" % importer.summary.bounds.size)
	importer.model.free()


func test_scale_suggestion_counts_the_objects_in_one_mesh() -> void:
	# The whole "city" in one mesh: 12 separate towers 0.05 units wide and
	# 0.3 high, spread over 1.2 units; the mesh's own height says little.
	var towers := []
	for i in 12:
		towers.append([Vector3((i % 4) * 0.4, 0.15, (i / 4) * 0.4), Vector3(0.05, 0.3, 0.05)])
	var importer := MapImporter.new()
	check(not importer.process(_scene([["city", _boxes(towers)]])), "fails C2")
	var message: String = _checks(importer, "C2")[0].message
	check(message.contains("suggested: 200") and message.contains("12 separate objects"), "the suggestion makes each tower 8 m wide: %s" % message)
	importer.model.free()


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
	check(importer.model.get_node("StreetLamp_1/StaticBody3D/CollisionShape3D").shape is CapsuleShape3D, "a lamp: a capsule round its post")
	check(importer.model.get_node("Object_78/StaticBody3D/CollisionShape3D").shape is BoxShape3D, "a 1 m block of decor: a box")
	check(_result(importer, "R2") == "INFO" and importer.summary.colliders.shapes == 7, "R2: generated colliders (%s)" % [importer.summary.colliders])
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
