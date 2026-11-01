extends "res://tests/integration/facade_map_case.gd"
## The light facade map (istanbul_halic_cells_light, build_map.py --facade
## light --detail-cell 40): surrounds and glass only, no windows behind
## neighbours, flat railings; the shared tests are in facade_map_case.gd.


func map_id() -> String:
	return "istanbul_halic_cells_light"


func root_name() -> StringName:
	return &"IstanbulHalicCellsLight"


func model_sha256() -> String:
	return "6531ca28b0ba8be0648615af23b3b625f3c9e9beec39693f163a65e42375355b"


func max_detail_share() -> float:
	return 0.5


func check_materials(model: Node) -> void:
	var materials := {}
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				materials[material] = material.vertex_color_use_as_albedo
	check(materials.size() == 6 and not materials.values().has(false), "the cells map's 6 shared materials, with vertex colors (%d)" % materials.size())
