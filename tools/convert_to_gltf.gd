extends SceneTree
## Converts model files that Godot does not load at runtime into one glTF 2.0
## scene for the import tool (docs/MAP_CONTRACT.md, "Supported formats"):
## Wavefront OBJ (with its MTL colours and textures), STL (binary or ASCII),
## and FBX (Godot's FBXDocument). The geometry is written as it is, with no
## unit or axis change, so a Z-up or centimetre source stays Z-up or in
## centimetres and the import tool's checks see it (C2, C3).
##   godot --headless --path . --script res://tools/convert_to_gltf.gd -- --out=<file.glb|file.gltf> <input> [<input> …]
## Every input becomes one node named after its file (an OBJ with objects or
## groups: one node per object or group). An OBJ without a material library
## takes a PNG or JPG of its own name beside it as its texture, when there is
## one. A .gltf output keeps its buffer and textures as files beside it.
## The inputs are only read. Exit code 0 when written, 1 when an input could
## not be read, 2 for bad arguments.

const FORMATS := ["obj", "stl", "fbx"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ""
	var inputs: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = ProjectSettings.globalize_path(arg.trim_prefix("--out="))
		else:
			inputs.append(ProjectSettings.globalize_path(arg))
	if out.get_extension().to_lower() not in ["glb", "gltf"] or inputs.is_empty() \
			or inputs.any(func(path: String) -> bool: return path.get_extension().to_lower() not in FORMATS):
		printerr("usage: --out=<file.glb|file.gltf> <input.obj|.stl|.fbx> …")
		quit(2)
		return
	var root := Node3D.new()
	root.name = out.get_file().get_basename()
	for path in inputs:
		var nodes := load_model(path)
		if nodes.is_empty():
			printerr("CONVERT could not read ", path)
			root.free()
			quit(1)
			return
		for node in nodes:
			root.add_child(node)
	_set_owner(root, root)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		error = document.write_to_filesystem(state, out)
	var triangles := 0
	var meshes := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			triangles += ((indices as PackedInt32Array).size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	root.free()
	if error != OK:
		printerr("CONVERT could not write ", out, ": ", error_string(error))
		quit(1)
		return
	print("CONVERT %s: %d inputs, %d meshes, %d triangles, %d bytes, SHA-256 %s" % [out.get_file(), inputs.size(), meshes, triangles,
			FileAccess.get_file_as_bytes(out).size(), FileAccess.get_sha256(out)])
	quit(0)


## The nodes of one model file (empty when it cannot be read).
static func load_model(path: String) -> Array[Node3D]:
	match path.get_extension().to_lower():
		"obj":
			return load_obj(path)
		"stl":
			return load_stl(path)
		"fbx":
			var document := FBXDocument.new()
			var state := FBXState.new()
			if document.append_from_file(path, state) != OK:
				return []
			var scene := document.generate_scene(state) as Node3D
			scene.name = _node_name(path.get_file().get_basename())
			return [scene]
	return []


## OBJ: a MeshInstance3D per object or group, one surface per material.
## OBJ faces wind counter-clockwise and its texture origin is at the bottom;
## Godot's front faces wind clockwise and its texture origin is at the top.
static func load_obj(path: String) -> Array[Node3D]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var materials := {}
	var groups: Array = []  # [name, {material name: [polygons]}]
	var group_name := path.get_file().get_basename()
	var material := ""
	var polygons := {}
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"v":
				positions.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vt":
				uvs.append(Vector2(float(parts[1]), 1.0 - float(parts[2]) if parts.size() > 2 else 1.0))
			"vn":
				normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"o", "g":
				if not polygons.is_empty():
					groups.append([group_name, polygons])
					polygons = {}
				group_name = line.substr(parts[0].length()).strip_edges()
			"usemtl":
				material = line.substr(6).strip_edges()
			"mtllib":
				materials.merge(_load_mtl(path.get_base_dir().path_join(line.substr(6).strip_edges())))
			"f":
				var corners := []
				for k in range(1, parts.size()):
					var ids := parts[k].split("/")
					corners.append([_obj_index(ids[0], positions.size()),
							_obj_index(ids[1], uvs.size()) if ids.size() > 1 and not ids[1].is_empty() else -1,
							_obj_index(ids[2], normals.size()) if ids.size() > 2 and not ids[2].is_empty() else -1])
				if not polygons.has(material):
					polygons[material] = []
				polygons[material].append(corners)
	if not polygons.is_empty():
		groups.append([group_name, polygons])
	if materials.is_empty():
		var texture := _texture_beside(path)
		if texture:
			var plain := StandardMaterial3D.new()
			plain.resource_name = path.get_file().get_basename()
			plain.albedo_texture = texture
			for group: Array in groups:
				for name in group[1]:
					materials[name] = plain
	var nodes: Array[Node3D] = []
	var names := {}
	for group: Array in groups:
		var mesh := ArrayMesh.new()
		for name: String in group[1]:
			var arrays := _obj_surface(group[1][name], positions, uvs, normals)
			if arrays.is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			if materials.has(name):
				mesh.surface_set_material(mesh.get_surface_count() - 1, materials[name])
		if mesh.get_surface_count() == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = _unique(_node_name(group[0]), names)
		node.mesh = mesh
		nodes.append(node)
	return nodes


## The arrays of one surface: corners welded by their (position, uv, normal)
## indices; polygons triangulated in their plane.
static func _obj_surface(polygons: Array, positions: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array) -> Array:
	var out_positions := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var index_of := {}
	var with_uv := true
	var with_normal := true
	for corners: Array in polygons:
		for corner: Array in corners:
			with_uv = with_uv and corner[1] >= 0
			with_normal = with_normal and corner[2] >= 0
	for corners: Array in polygons:
		var points := PackedVector3Array()
		for corner: Array in corners:
			points.append(positions[corner[0]])
		for triangle in _triangulate(points):
			for k in [0, 2, 1]:
				var corner: Array = corners[triangle[k]]
				var key := Vector3i(corner[0], corner[1] if with_uv else -1, corner[2] if with_normal else -1)
				if not index_of.has(key):
					index_of[key] = out_positions.size()
					out_positions.append(positions[corner[0]])
					if with_uv:
						out_uvs.append(uvs[corner[1]])
					if with_normal:
						out_normals.append(normals[corner[2]])
				indices.append(index_of[key])
	if indices.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_positions
	arrays[Mesh.ARRAY_INDEX] = indices
	if with_uv:
		arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	if with_normal:
		arrays[Mesh.ARRAY_NORMAL] = out_normals
	return arrays


## Triangles of a planar polygon as corner index triples, wound like the
## polygon (counter-clockwise around its normal): ear clipping in the
## polygon's plane, a fan when that fails (degenerate polygons).
static func _triangulate(points: PackedVector3Array) -> Array:
	var count := points.size()
	if count < 3:
		return []
	if count == 3:
		return [[0, 1, 2]]
	var normal := Vector3.ZERO
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		normal += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	var triangles := []
	if normal.length_squared() > 0.0:
		normal = normal.normalized()
		var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := normal.cross(u)
		var flat := PackedVector2Array()
		for point in points:
			flat.append(Vector2(point.dot(u), point.dot(v)))
		var ids := Geometry2D.triangulate_polygon(flat)
		for t in range(0, ids.size(), 3):
			var triangle := [ids[t], ids[t + 1], ids[t + 2]]
			var face := (points[triangle[1]] - points[triangle[0]]).cross(points[triangle[2]] - points[triangle[0]])
			if face.dot(normal) < 0.0:
				triangle = [triangle[0], triangle[2], triangle[1]]
			triangles.append(triangle)
	if triangles.is_empty():
		for i in range(1, count - 1):
			triangles.append([0, i, i + 1])
	return triangles


## OBJ index (1-based, negative from the end) as a 0-based index.
static func _obj_index(text: String, count: int) -> int:
	var index := int(text)
	return index - 1 if index > 0 else count + index


## Materials of an MTL file: diffuse colour (Kd), its texture (map_Kd), and
## opacity (d, Tr).
static func _load_mtl(path: String) -> Dictionary:
	var materials := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return materials
	var current: StandardMaterial3D
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"newmtl":
				current = StandardMaterial3D.new()
				current.resource_name = line.substr(6).strip_edges()
				materials[current.resource_name] = current
			"Kd":
				if current:
					current.albedo_color = Color(float(parts[1]), float(parts[2]), float(parts[3]), current.albedo_color.a)
			"d", "Tr":
				if current:
					current.albedo_color.a = float(parts[1]) if parts[0] == "d" else 1.0 - float(parts[1])
					if current.albedo_color.a < 1.0:
						current.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"map_Kd":
				if current:
					current.albedo_texture = _texture(path.get_base_dir().path_join(parts[parts.size() - 1]))
	return materials


static func _texture_beside(path: String) -> Texture2D:
	for extension: String in ["png", "jpg", "jpeg"]:
		var candidate := path.get_basename() + "." + extension
		if FileAccess.file_exists(candidate):
			return _texture(candidate)
	return null


static func _texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = path.get_file().get_basename()
	return texture


## STL: one MeshInstance3D, corners welded where their positions are equal.
## STL triangles wind counter-clockwise around their normal.
static func load_stl(path: String) -> Array[Node3D]:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 84:
		return []
	var corners := PackedVector3Array()
	var count := bytes.decode_u32(80)
	if 84 + 50 * count == bytes.size():
		for t in count:
			var offset := 84 + 50 * t + 12
			for k in 3:
				corners.append(Vector3(bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8)))
				offset += 12
	else:
		for line in bytes.get_string_from_utf8().split("\n"):
			var parts := line.strip_edges().split(" ", false)
			if parts.size() == 4 and parts[0] == "vertex":
				corners.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
	if corners.size() < 3:
		return []
	var positions := PackedVector3Array()
	var indices := PackedInt32Array()
	var index_of := {}
	for t in range(0, corners.size() - 2, 3):
		for k in [0, 2, 1]:
			var corner := corners[t + k]
			if not index_of.has(corner):
				index_of[corner] = positions.size()
				positions.append(corner)
			indices.append(index_of[corner])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = _node_name(path.get_file().get_basename())
	node.mesh = mesh
	return [node]


## A node name without the characters Godot does not allow in one.
static func _node_name(text: String) -> String:
	var name := text.validate_node_name().strip_edges()
	return name if not name.is_empty() else "Mesh"


static func _unique(name: String, names: Dictionary) -> String:
	var unique := name
	var n := 2
	while names.has(unique):
		unique = "%s_%d" % [name, n]
		n += 1
	names[unique] = true
	return unique


static func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner(child, owner)
