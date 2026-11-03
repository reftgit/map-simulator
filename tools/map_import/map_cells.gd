extends RefCounted
## The cell step (docs/STREAMING.md): splits any map the game can load (one
## made by the import tool, by the İstanbul generator, or by hand) into a
## resident scene and streaming cells, from its MapDefinition alone. The
## meshes of the visibility-range categories (STREAMED_CATEGORIES, by the
## map's own CategoryRules) go into cells: one MapCell file per category and
## square of a grid on the ground plane, each mesh in the square of its
## centre (the point Godot measures a visibility range to); no mesh is cut. The
## resident scene is the whole map scene with those meshes taken out of their
## nodes: every node, collider, group, and name stays, so collision, the
## occluders, the categories, and the map's scripts see the same map.
## Materials go to files of their own, so the resident scene and the cells
## share them; a mesh used in more than one cell too. The map's own files are
## only read. Used by tools/cell_map.gd and tools/import_map.gd.

## The render categories the quality profiles give a visibility range; their
## meshes are streamed, everything else is resident.
const STREAMED_CATEGORIES: Array[String] = ["facade_detail", "trees", "lamps", "decor"]
## Side of a grid square (m), chosen by measurement (docs/STREAMING.md).
const DEFAULT_CELL_SIZE := 50.0

## The written index (null until run() succeeds).
var index: MapStreamingIndex
## Where it was written.
var index_path := ""
## Summary lines for the log and reports.
var lines: Array[String] = []
var seconds := 0.0


## Splits the map of `definition` into `out_dir` (a res:// folder that holds
## nothing else; cleared first) with grid squares of `cell_size` metres.
## Returns "" on success, or why nothing (or not everything) was written.
## A map with no mesh to stream gets no index ("nothing to stream").
func run(definition: MapDefinition, out_dir: String, cell_size := DEFAULT_CELL_SIZE) -> String:
	var started := Time.get_ticks_msec()
	lines.clear()
	index = null
	index_path = out_dir.path_join("%s_index.tres" % definition.id)
	if cell_size <= 0.0:
		return "bad cell size %s" % cell_size
	var packed := ResourceLoader.load(definition.scene_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		return "cannot load %s" % definition.scene_path
	var root := packed.instantiate()
	var rules := definition.category_rules if definition.category_rules else CategoryRules.new()
	var instances: Array[MeshInstance3D] = []
	var users := {}  # Mesh -> [MeshInstance3D]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		instances.append(instance)
		users.get_or_add(instance.mesh, []).append(instance)
	# Streamed: a mesh of a streamed category whose every user is streamed too
	# (a mesh shared with a resident node stays resident with all its users).
	var streamed := {}  # MeshInstance3D -> category
	for instance in instances:
		var category := rules.category_of(instance)
		if category in STREAMED_CATEGORIES:
			streamed[instance] = category
	for instance in streamed.keys():
		for user: MeshInstance3D in users[instance.mesh]:
			if not streamed.has(user):
				streamed.erase(instance)
				break
	_clear(out_dir)
	if streamed.is_empty():
		root.free()
		seconds = (Time.get_ticks_msec() - started) / 1000.0
		lines.append("%s: nothing to stream (no mesh in %s); the map loads whole" % [definition.id, ", ".join(STREAMED_CATEGORIES)])
		return ""
	# Cells: by category and grid square of the mesh's centre in the map root's space.
	var cells := {}  # "category:i:j" -> {category, i, j, nodes, meshes, centers}
	for instance: MeshInstance3D in streamed:
		var local := instance.custom_aabb if instance.custom_aabb.has_volume() else instance.mesh.get_aabb()
		var center := (_to_root(instance, root) * local).get_center()
		var i := floori(center.x / cell_size)
		var j := floori(center.z / cell_size)
		var category: String = streamed[instance]
		var cell: Dictionary = cells.get_or_add("%s:%d:%d" % [category, i, j], {"category": category, "i": i, "j": j,
				"nodes": [], "meshes": [], "centers": AABB(center, Vector3.ZERO)})
		cell.nodes.append(root.get_path_to(instance))
		cell.meshes.append(instance.mesh)
		cell.centers = cell.centers.expand(center)
	index = MapStreamingIndex.new()
	index.cell_size = cell_size
	var error := _save_shared(instances, cells, out_dir)
	if not error.is_empty():
		root.free()
		index = null
		return error
	var keys := cells.keys()
	keys.sort()
	for key in keys:
		var cell: Dictionary = cells[key]
		var resource := MapCell.new()
		resource.nodes.assign(cell.nodes)
		resource.meshes.assign(cell.meshes)
		var path := out_dir.path_join("cells/%s_%d_%d.res" % [cell.category, cell.i, cell.j])
		error = _save(resource, path, ResourceSaver.FLAG_COMPRESS)
		if not error.is_empty():
			root.free()
			return error
		index.cell_paths.append(path)
		index.cell_categories.append(cell.category)
		index.cell_rects.append(Rect2(cell.i * cell_size, cell.j * cell_size, cell_size, cell_size))
		index.cell_centers.append(cell.centers)
		index.cell_meshes.append(cell.nodes.size())
		var triangles := 0
		for mesh: Mesh in cell.meshes:
			triangles += triangle_count(mesh)
		index.cell_triangles.append(triangles)
		index.cell_bytes.append(_file_size(path))
	# The resident scene: every node, the streamed ones without their mesh.
	for instance: MeshInstance3D in streamed:
		instance.mesh = null
	_make_local(root)
	var resident := PackedScene.new()
	var packed_error := resident.pack(root)
	root.free()
	if packed_error != OK:
		return "cannot pack the resident scene: %s" % error_string(packed_error)
	index.resident_scene = out_dir.path_join("%s_resident.scn" % definition.id)
	error = _save(resident, index.resident_scene, ResourceSaver.FLAG_COMPRESS)
	if not error.is_empty():
		return error
	for source in model_files(definition.scene_path):
		index.source_files.append(source)
		index.source_sizes.append(_file_size(source))
	index.streamed_meshes = streamed.size()
	index.resident_meshes = instances.size() - streamed.size()
	error = _save(index, index_path, 0)
	if not error.is_empty():
		return error
	seconds = (Time.get_ticks_msec() - started) / 1000.0
	lines.append_array(summary(definition.id, index))
	return ""


## Summary lines: meshes and triangles streamed per category, cells, sizes.
static func summary(id: String, written: MapStreamingIndex) -> Array[String]:
	var per := {}
	for i in written.cell_count():
		var entry: Dictionary = per.get_or_add(written.cell_categories[i], {"cells": 0, "meshes": 0, "triangles": 0, "bytes": 0})
		entry.cells += 1
		entry.meshes += written.cell_meshes[i]
		entry.triangles += written.cell_triangles[i]
		entry.bytes += written.cell_bytes[i]
	var out: Array[String] = ["%s: %d of %d meshes streamed in %d cells of %d m; resident scene %.1f MB, cells %.1f MB" % [id,
			written.streamed_meshes, written.streamed_meshes + written.resident_meshes, written.cell_count(), roundi(written.cell_size),
			_file_size(written.resident_scene) / 1048576.0, written.cell_bytes.reduce(func(a: int, b: int) -> int: return a + b, 0) / 1048576.0]]
	for category in STREAMED_CATEGORIES:
		if per.has(category):
			var entry: Dictionary = per[category]
			out.append("  %s: %d meshes, %d triangles, %d cells (%.1f MB)" % [category, entry.meshes, entry.triangles, entry.cells, entry.bytes / 1048576.0])
	return out


## Points `definition` (its .tres file) at `path`: replaces its
## streaming_index_path line, or adds one after scene_path. Text, so the rest
## of a hand-written file stays as it is. Returns "linked", "present", or an error.
static func link(definition: MapDefinition, path: String) -> String:
	if definition.streaming_index_path == path:
		return "present"
	var file_path := definition.resource_path
	var text := FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return "cannot read %s" % file_path
	var line := 'streaming_index_path = "%s"' % path
	var existing := RegEx.create_from_string('(?m)^streaming_index_path = ".*"$').search(text)
	if existing:
		text = text.replace(existing.get_string(), line)
	else:
		var scene := RegEx.create_from_string('(?m)^scene_path = ".*"$').search(text)
		if scene == null:
			return "no scene_path line in %s" % file_path
		text = text.replace(scene.get_string(), scene.get_string() + "\n" + line)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % file_path
	file.store_string(text)
	definition.streaming_index_path = path
	return "linked"


## The binary files holding the meshes of the scene at `scene_path`: its
## imported GLBs' import results and its .scn models (a text scene is
## converted on export, so its size is no fingerprint).
static func model_files(scene_path: String) -> Array[String]:
	var files: Array[String] = []
	for dependency in ResourceLoader.get_dependencies(scene_path):
		var path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		var config := ConfigFile.new()
		if config.load(path + ".import") == OK:
			files.append(str(config.get_value("remap", "path", path)))
		elif path.get_extension() in ["scn", "res"]:
			files.append(path)
	return files


## Triangles of a mesh's surfaces (indexed or not).
static func triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var indices := (mesh as ArrayMesh).surface_get_array_index_len(surface)
			triangles += (indices if indices > 0 else (mesh as ArrayMesh).surface_get_array_len(surface)) / 3
		else:
			var arrays := mesh.surface_get_arrays(surface)
			var indexed = arrays[Mesh.ARRAY_INDEX]
			triangles += (indexed.size() if indexed != null and indexed.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return triangles


## Transform of `node` relative to `root` (the scene is not in a tree).
static func _to_root(node: Node, root: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != root and current != null:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


## Saves the materials of every mesh and node to files of their own (so the
## resident scene and the cells use the same material; the index lists the
## streamed meshes' materials, which MapStreamer holds while the map is
## loaded), and the meshes used in more than one cell.
func _save_shared(instances: Array[MeshInstance3D], cells: Dictionary, out_dir: String) -> String:
	var materials := {}  # Material -> whether a streamed mesh uses it
	var streamed_meshes := {}
	for cell: Dictionary in cells.values():
		for mesh: Mesh in cell.meshes:
			streamed_meshes[mesh] = true
	for instance in instances:
		var used := [instance.material_override, instance.material_overlay]
		for surface in instance.mesh.get_surface_count():
			used.append(instance.mesh.surface_get_material(surface))
			used.append(instance.get_surface_override_material(surface))
		for material: Material in used:
			if material:
				materials[material] = materials.get(material, false) or streamed_meshes.has(instance.mesh)
	var count := 0
	for material: Material in materials:
		if material.resource_path.is_empty() or material.resource_path.contains("::"):
			var path := out_dir.path_join("materials/%03d_%s.res" % [count, _slug(material.resource_name)])
			var error := _save(material, path, ResourceSaver.FLAG_COMPRESS)
			if not error.is_empty():
				return error
			material.take_over_path(path)
			count += 1
		if materials[material]:
			index.material_paths.append(material.resource_path)
	var cells_of := {}  # Mesh -> number of cells using it
	for cell: Dictionary in cells.values():
		var once := {}
		for mesh: Mesh in cell.meshes:
			once[mesh] = true
		for mesh: Mesh in once:
			cells_of[mesh] = cells_of.get(mesh, 0) + 1
	count = 0
	for mesh: Mesh in cells_of:
		if cells_of[mesh] > 1:
			var path := out_dir.path_join("meshes/%03d_%s.res" % [count, _slug(mesh.resource_name)])
			var error := _save(mesh, path, ResourceSaver.FLAG_COMPRESS)
			if not error.is_empty():
				return error
			mesh.take_over_path(path)
			index.shared_mesh_paths.append(path)
			count += 1
	return ""


## Makes every node part of `root`'s own scene (a model instanced from a GLB
## or a .scn becomes plain nodes), so the packed scene needs no other file.
static func _make_local(root: Node) -> void:
	for node in root.find_children("*", "", true, false):
		node.owner = root
		node.scene_file_path = ""
	root.scene_file_path = ""


static func _save(resource: Resource, path: String, flags: int) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := ResourceSaver.save(resource, path, flags)
	return "" if error == OK else "cannot save %s: %s" % [path, error_string(error)]


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file else 0


## Lowercase ASCII letters, digits, and "_" from a resource name ("material" when empty).
static func _slug(name: String) -> String:
	var slug := ""
	for c in name.to_lower():
		slug += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return slug if not slug.is_empty() else "material"


## Removes what an earlier run wrote to `out_dir` (cells, materials, meshes,
## the resident scene, the index); other files stay.
static func _clear(out_dir: String) -> void:
	var dir := ProjectSettings.globalize_path(out_dir)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in ["cells", "materials", "meshes"]:
		if not DirAccess.dir_exists_absolute(dir.path_join(sub)):
			continue
		for file in DirAccess.get_files_at(dir.path_join(sub)):
			DirAccess.remove_absolute(dir.path_join(sub).path_join(file))
		DirAccess.remove_absolute(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with("_resident.scn") or file.ends_with("_index.tres"):
			DirAccess.remove_absolute(dir.path_join(file))
