extends "res://tests/test_case.gd"
## The cell step (docs/STREAMING.md; tools/map_import/map_cells.gd): the
## visibility-range meshes of a map go into cells by category and the grid
## square of their centre, everything else stays in a resident scene that
## keeps every node, collider, name, and group; materials and meshes used in
## more than one place are shared; the index says when it cannot be used.

const MapCells := preload("res://tools/map_import/map_cells.gd")
const StreamingMap := preload("res://tests/fixtures/streaming_map.gd")

const DIR := "user://test_map_cells"


func _split(definition: MapDefinition) -> MapCells:
	var cells := MapCells.new()
	var error := cells.run(definition, DIR.path_join("streaming"), StreamingMap.CELL)
	check(error.is_empty(), "the split succeeds (%s)" % error)
	return cells


func test_meshes_go_to_the_cell_of_their_centre_by_category() -> void:
	var definition := StreamingMap.write(DIR)
	var index := _split(definition).index
	check(index.cell_size == StreamingMap.CELL, "the cell size is recorded")
	var expected := StreamingMap.TREE_X.size() + StreamingMap.LAMP_X.size() + StreamingMap.DETAIL_X.size() + 3
	check(index.streamed_meshes == expected, "trees, lamps, facade detail, two benches, and the grouped prop are streamed (%d, expected %d)" % [index.streamed_meshes, expected])
	check(index.resident_meshes == 4, "ground, building, the kiosk sharing the building's mesh, and the mesh in no category stay (%d)" % index.resident_meshes)
	var trees := 0
	for i in index.cell_count():
		var rect := index.cell_rects[i]
		var centers := index.cell_centers[i]
		check(rect.has_point(Vector2(centers.position.x, centers.position.z)) and rect.grow(0.001).has_point(Vector2(centers.end.x, centers.end.z)),
				"%s: its meshes' centres lie in its square" % index.cell_paths[i])
		if index.cell_categories[i] == "trees":
			trees += 1
			check(index.cell_meshes[i] == 1 and index.cell_triangles[i] == 12, "one tree (a 12-triangle box) per tree cell")
	check(trees == StreamingMap.TREE_X.size(), "one cell per tree, 20 m apart (%d)" % trees)
	var tree_cell := index.cell_paths.find(DIR.path_join("streaming/cells/trees_-5_0.res"))
	check(tree_cell >= 0 and index.cell_rects[tree_cell] == Rect2(-100, 0, 20, 20), "the tree at x = -90, z = 0 is in square (-5, 0), x -100…-80, z 0…20")
	var cell := load(index.cell_paths[tree_cell]) as MapCell
	check(cell.nodes == [NodePath("Model/Tree_-90")] and cell.meshes[0] is BoxMesh, "the cell holds the node path and its mesh")
	check(index.cell_categories.count("decor") == 3, "the benches (two squares) and the grouped prop are decor cells")


func test_resident_scene_keeps_every_node_without_the_streamed_meshes() -> void:
	var definition := StreamingMap.write(DIR)
	var index := _split(definition).index
	var whole := (load(definition.scene_path) as PackedScene).instantiate()
	var resident := (load(index.resident_scene) as PackedScene).instantiate()
	var paths := func(root: Node) -> Array:
		return root.find_children("*", "", true, false).map(func(node: Node) -> String: return "%s %s" % [root.get_path_to(node), node.get_class()])
	check(paths.call(whole) == paths.call(resident), "same nodes, names, and types")
	check(resident.get_node("Model").scene_file_path.is_empty(), "the model is part of the resident scene")
	check(not Array(ResourceLoader.get_dependencies(index.resident_scene)).any(func(dependency: String) -> bool: return dependency.contains("model.scn")),
			"the resident scene needs no other scene file: %s" % [ResourceLoader.get_dependencies(index.resident_scene)])
	check((resident.get_node("Model/Tree_-90") as MeshInstance3D).mesh == null, "a streamed node has no mesh")
	check(resident.get_node("Model/Tree_-90/StaticBody3D/CollisionShape3D") != null, "its collider stays resident")
	for name in ["Ground_0", "Building_A", "Decor_kiosk", "Thing"]:
		check((resident.get_node("Model/" + name) as MeshInstance3D).mesh != null, "%s keeps its mesh" % name)
	check(resident.get_node("Model/Prop_7").is_in_group("map_category_decor"), "groups stay")
	check(definition.category_rules.category_of(resident.get_node("Model/Prop_7")) == "decor", "so a group rule still finds the category")
	whole.free()
	resident.free()


func test_materials_and_meshes_used_in_several_places_are_shared() -> void:
	var definition := StreamingMap.write(DIR)
	var index := _split(definition).index
	check(index.material_paths.size() == 2, "the streamed meshes' two materials are listed (%s)" % [index.material_paths])
	check(index.shared_mesh_paths.size() == 1, "the bench mesh used in two cells is a file of its own (%s)" % [index.shared_mesh_paths])
	var resident := (load(index.resident_scene) as PackedScene).instantiate()
	var tree_cell := load(index.cell_paths[index.cell_paths.find(DIR.path_join("streaming/cells/trees_-5_0.res"))]) as MapCell
	var building_material := (resident.get_node("Model/Building_A") as MeshInstance3D).mesh.surface_get_material(0)
	check(tree_cell.meshes[0].surface_get_material(0) == building_material, "a cell and the resident scene use the same material object")
	var benches := []
	for i in index.cell_count():
		var cell := load(index.cell_paths[i]) as MapCell
		for k in cell.nodes.size():
			if str(cell.nodes[k]).contains("bench"):
				benches.append(cell.meshes[k])
	check(benches.size() == 2 and benches[0] == benches[1], "both benches get the same mesh object")
	resident.free()


func test_warm_cells_are_the_smallest_cell_of_each_material() -> void:
	var definition := StreamingMap.write(DIR)
	var index := _split(definition).index
	check(index.warm_cells.size() == 2, "one per material of the streamed meshes, two here (%s)" % [index.warm_cells])
	for material_name in ["Shared", "Lamp"]:
		var using := []
		for cell in index.cell_count():
			var resource := load(index.cell_paths[cell]) as MapCell
			if resource.meshes.any(func(mesh: Mesh) -> bool: return mesh.surface_get_material(0).resource_name == material_name):
				using.append(cell)
		var smallest: int = using.reduce(func(a: int, b: int) -> int: return a if index.cell_bytes[a] <= index.cell_bytes[b] else b)
		check(smallest in index.warm_cells, "%s: its smallest cell (%s) is warm" % [material_name, index.cell_paths[smallest].get_file()])


func test_a_map_with_nothing_to_stream_gets_no_index() -> void:
	var definition := StreamingMap.write(DIR)
	var rules := CategoryRules.new()
	var ground := CategoryRule.new()
	ground.category = "ground"
	ground.kind = "regex"
	ground.pattern = "."
	rules.rules.append(ground)
	definition.category_rules = rules
	var cells := MapCells.new()
	var error := cells.run(definition, DIR.path_join("streaming"), StreamingMap.CELL)
	check(error.is_empty() and cells.index == null, "no index")
	check(cells.lines.size() == 1 and cells.lines[0].contains("nothing to stream"), "the summary says so: %s" % [cells.lines])
	check(not FileAccess.file_exists(DIR.path_join("streaming/stream_test_index.tres")), "no index file")


func test_link_points_the_definition_at_the_index() -> void:
	var definition := StreamingMap.write(DIR)
	var cells := _split(definition)
	check(MapCells.link(definition, cells.index_path) == "linked", "linked")
	var text := FileAccess.get_file_as_string(definition.resource_path)
	check(text.contains('scene_path = "%s"\nstreaming_index_path = "%s"' % [definition.scene_path, cells.index_path]), "a line after scene_path")
	var reloaded := ResourceLoader.load(definition.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MapDefinition
	check(reloaded.streaming_index_path == cells.index_path, "the definition reads it")
	check(MapCells.link(reloaded, cells.index_path) == "present", "a second run changes nothing")
	check(MapCells.link(reloaded, "user://other_index.tres") == "linked", "another path replaces the line")
	check(FileAccess.get_file_as_string(definition.resource_path).count("streaming_index_path") == 1, "one line")


func test_index_that_cannot_be_used_loads_the_map_whole() -> void:
	var definition := StreamingMap.write(DIR)
	check(MapStreamingIndex.load_for(definition) == null, "no streaming_index_path: whole")
	var cells := _split(definition)
	definition.streaming_index_path = cells.index_path
	var index := MapStreamingIndex.load_for(definition)
	check(index != null and index.problem().is_empty(), "a fresh index is used")
	check(index.source_files == [DIR.path_join("model.scn")], "the model file is its fingerprint (%s)" % [index.source_files])
	var file := FileAccess.open(DIR.path_join("model.scn"), FileAccess.READ_WRITE)
	file.seek_end()
	file.store_8(0)
	file.close()
	check(index.problem().contains("model.scn changed"), "a changed model makes it stale (%s)" % index.problem())
	_split(definition)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(load(definition.streaming_index_path).cell_paths[0]))
	check(MapStreamingIndex.load_for(definition) == null, "a missing cell: whole")
	definition.streaming_index_path = DIR.path_join("nowhere/index.tres")
	check(MapStreamingIndex.load_for(definition) == null, "a missing index: whole")


## The model stands for a map's GLB: its required file, and the file its index
## is compared with. A release package carries the cells without the model.
func test_a_usable_index_makes_a_map_available_without_its_model() -> void:
	var definition := StreamingMap.write(DIR)
	var model := DIR.path_join("model.scn")
	definition.required_files.assign([model])
	check(definition.is_available() and definition.has_required_files(), "model, no index: available (whole), as before")
	var cells := _split(definition)
	definition.streaming_index_path = cells.index_path
	check(definition.is_available() and MapStreamingIndex.load_for(definition) != null, "model and index: available, streamed")
	var cell := cells.index.cell_paths[0]
	var cell_bytes := FileAccess.get_file_as_bytes(cell)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cell))
	check(definition.is_available() and MapStreamingIndex.load_for(definition) == null, "model, a cell missing: available, whole")
	FileAccess.open(cell, FileAccess.WRITE).store_buffer(cell_bytes)
	var model_bytes := FileAccess.get_file_as_bytes(model)
	var file := FileAccess.open(model, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_8(0)
	file.close()
	check(definition.is_available() and MapStreamingIndex.load_for(definition) == null, "a changed model: available, whole (the index is stale)")
	FileAccess.open(model, FileAccess.WRITE).store_buffer(model_bytes)
	check(MapStreamingIndex.load_for(definition) != null, "the model as it was: streamed again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model))
	check(not definition.has_required_files(), "the model is gone")
	check(definition.is_available() and MapStreamingIndex.load_for(definition) != null, "no model, a usable index: available, streamed (nothing to be stale against)")
	check(cells.index.problem(true).contains("missing %s" % model), "the release check still wants the model (%s)" % cells.index.problem(true))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cell))
	check(not definition.is_available(), "no model, a cell missing: not available")
	check(definition.unavailable_reason() == "missing: %s; its streaming index cannot be used" % model, "the reason says both (%s)" % definition.unavailable_reason())
	definition.streaming_index_path = DIR.path_join("nowhere/index.tres")
	check(not definition.is_available(), "no model, no index file: not available")
	definition.streaming_index_path = ""
	check(not definition.is_available() and definition.unavailable_reason() == "missing: %s" % model, "no model, no index: not available, as before")


func test_the_import_tool_and_cell_step_agree_on_the_streamed_categories() -> void:
	check(MapCells.STREAMED_CATEGORIES == ["facade_detail", "trees", "lamps", "decor"], "the categories the profiles give a visibility range")
	for category in MapCells.STREAMED_CATEGORIES:
		check(QualityProfiles.settings_for("low").visibility_end.has(category) and QualityProfiles.settings_for("high").visibility_end.has(category),
				"%s has a range in both profiles" % category)
