extends RefCounted
## A small synthetic map for the streaming tests (docs/STREAMING.md), written
## to a user:// folder the way the import tool writes a map: a model scene
## (model.scn) instanced in the map scene (map.tscn), category rules, and a
## MapDefinition (map.tres). 200 m of ground and a building (resident), a row
## of trees with trunk colliders, lamps, facade detail, and decor (streamed),
## two decor meshes sharing one mesh in different cells, a decor that shares
## the building's mesh (stays resident), a mesh in no category (resident), and
## a decor found by its group. Grid squares of CELL m put each streamed object
## in a known cell.

const CELL := 20.0
## Trees every 20 m along x at z = 0, x from -90 to 90 (10 trees, 10 cells).
const TREE_X := [-90, -70, -50, -30, -10, 10, 30, 50, 70, 90]
const LAMP_X := [-75, -45, -15, 15, 45, 75]
const DETAIL_X := [-60, 0, 60]


## Writes the map to `dir` (a user:// folder, cleared first) and returns its
## definition, loaded from map.tres.
static func write(dir: String) -> MapDefinition:
	_clear(ProjectSettings.globalize_path(dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var shared := StandardMaterial3D.new()
	shared.resource_name = "Shared"
	shared.albedo_color = Color(0.6, 0.5, 0.4)
	var lamp_material := StandardMaterial3D.new()
	lamp_material.resource_name = "Lamp"
	var model := Node3D.new()
	model.name = "Model"
	_add(model, "Ground_0", _box(Vector3(200, 1, 200), shared), Vector3(0, -0.5, 0), true)
	var building_mesh := _box(Vector3(10, 10, 10), shared)
	_add(model, "Building_A", building_mesh, Vector3(-30, 5, -40), true)
	for x: int in TREE_X:
		_add(model, "Tree_%d" % x, _box(Vector3(2, 6, 2), shared), Vector3(x, 3, 0), true)
	for x: int in LAMP_X:
		_add(model, "Lamp_%d" % x, _box(Vector3(0.3, 4, 0.3), lamp_material), Vector3(x, 2, 20), false)
	for x: int in DETAIL_X:
		_add(model, "Detail_%d" % x, _box(Vector3(8, 3, 0.2), shared), Vector3(x, 5, -20), false)
	var bench := _box(Vector3(2, 0.5, 0.6), shared)
	_add(model, "Decor_bench_west", bench, Vector3(-85, 0.25, 45), false)
	_add(model, "Decor_bench_east", bench, Vector3(85, 0.25, 45), false)
	_add(model, "Decor_kiosk", building_mesh, Vector3(60, 5, 60), false)
	_add(model, "Thing", _box(Vector3(1, 1, 1), shared), Vector3(0, 0.5, 70), false)
	var prop := _add(model, "Prop_7", _box(Vector3(1, 1, 1), shared), Vector3(-5, 0.5, 45), false)
	prop.add_to_group("map_category_decor", true)
	var model_path := dir.path_join("model.scn")
	_save_scene(model, model_path)
	model.free()
	var root := Node3D.new()
	root.name = "StreamTest"
	var instance := (load(model_path) as PackedScene).instantiate()
	root.add_child(instance)
	instance.owner = root
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	root.add_child(sun)
	sun.owner = root
	var scene_path := dir.path_join("map.tscn")
	_save_scene(root, scene_path)
	root.free()
	var rules := CategoryRules.new()
	for rule in [["ground", "prefix", "Ground_"], ["buildings", "prefix", "Building_"], ["trees", "prefix", "Tree_"],
			["lamps", "prefix", "Lamp_"], ["facade_detail", "prefix", "Detail_"], ["decor", "prefix", "Decor_"],
			["decor", "group", "map_category_decor"]]:
		var entry := CategoryRule.new()
		entry.category = rule[0]
		entry.kind = rule[1]
		entry.pattern = rule[2]
		rules.rules.append(entry)
	var definition := MapDefinition.new()
	definition.id = "stream_test"
	definition.scene_path = scene_path
	definition.player_spawn_position = Vector3(0, 0.5, 30)
	definition.bounds = Rect2(-100, -100, 200, 200)
	definition.category_rules = rules
	var definition_path := dir.path_join("map.tres")
	ResourceSaver.save(definition, definition_path)
	return ResourceLoader.load(definition_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MapDefinition


static func _box(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


## A mesh node under `model` at `position`; with `collider`, a StaticBody3D
## with a box under it, as the import tool makes colliders.
static func _add(model: Node3D, node_name: String, mesh: Mesh, position: Vector3, collider: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	model.add_child(instance)
	instance.owner = model
	if collider:
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = mesh.get_aabb().size
		shape.shape = box
		instance.add_child(body)
		body.add_child(shape)
		body.owner = model
		shape.owner = model
	return instance


static func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, path)


static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
