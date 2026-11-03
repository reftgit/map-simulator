extends "res://tests/integration/imported_map_case.gd"
## NASA's Apollo 11 landing site relief of the Phase 6b blind test as the
## import tool made it: maps/apollo11_site/, from the converted GLB in
## maps/apollo11_site/source/ (an STL for 3D printing: Z-up, millimetres,
## inside out) with no configuration but its display name: the tool turned it
## to +Y up and its faces outward by itself.

const MapGeometry := preload("res://tools/map_import/map_geometry.gd")


func definition_path() -> String:
	return "res://maps/apollo11_site/apollo11_site.tres"


func regenerate_hint() -> String:
	return "run tools/import_map.gd as in docs/maps/imported/apollo11_site.md"


func expected_categories() -> Dictionary:
	return {"ground": 1}


func test_registered_and_selectable() -> void:
	var registry := MapRegistry.load_default()
	check(registry.find("apollo11_site") != null and registry.find("apollo11_site").is_available(), "apollo11_site in the registry and available")


func test_relief_lies_flat_and_faces_up() -> void:
	await _setup()
	var relief := game.world.map_root.get_node("Model").get_child(0) as MeshInstance3D
	var box: AABB = relief.global_transform * relief.mesh.get_aabb()
	check(box.size.y < 20.0 and box.size.x > 250.0 and box.size.z > 250.0, "lying flat: %s" % box.size)
	# The faces of the top (above its base) point up in Godot's winding: the
	# outside is drawn, not the inside of the base.
	var arrays := relief.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var up := 0
	var down := 0
	var basis := relief.global_basis
	for t in range(0, indices.size() if not indices.is_empty() else positions.size(), 3):
		var a := basis * positions[indices[t] if not indices.is_empty() else t]
		var b := basis * positions[indices[t + 1] if not indices.is_empty() else t + 1]
		var c := basis * positions[indices[t + 2] if not indices.is_empty() else t + 2]
		if (a.y + b.y + c.y) / 3.0 < box.position.y + 3.0:
			continue
		var normal := (c - a).cross(b - a)
		if normal.y > 0.0:
			up += 1
		elif normal.y < 0.0:
			down += 1
	check(up > 20 * down, "the top's faces point up (%d up, %d down)" % [up, down])
	check(player.global_position.y > box.position.y + 3.0, "the player stands on the relief, not on its base (%.1f m)" % player.global_position.y)
