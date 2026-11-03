extends "res://tests/test_case.gd"
## The converter for model formats Godot does not load at runtime (Phase 6b,
## tools/convert_to_gltf.gd): OBJ and STL geometry kept as it is (no unit or
## axis change), turned to Godot's clockwise front faces, OBJ's texture
## origin flipped, polygons triangulated in their plane, a GLB that keeps the
## source's axes.

const Converter := preload("res://tools/convert_to_gltf.gd")
const DIR := "user://convert_to_gltf_test"


func _write(file_name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := ProjectSettings.globalize_path(DIR.path_join(file_name))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _cleanup() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(name))
	DirAccess.remove_absolute(DIR)


## Godot front-face normals (clockwise winding: (c - a) x (b - a)) and the
## total area of a mesh's triangles.
func _faces(mesh: Mesh) -> Dictionary:
	var normal_sum := Vector3.ZERO
	var area := 0.0
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := positions[indices[t]]
			var face := (positions[indices[t + 2]] - a).cross(positions[indices[t + 1]] - a)
			normal_sum += face.normalized()
			area += face.length() * 0.5
			triangles += 1
	return {"normal": normal_sum / maxi(triangles, 1), "area": area, "triangles": triangles}


func test_obj_concave_polygon_and_quad_keep_their_facing() -> void:
	# An L-shaped hexagon (concave, area 3) and a quad (area 1), both facing +Y
	# (counter-clockwise seen from above, as OBJ winds front faces).
	var path := _write("shapes.obj", "\n".join([
		"v 0 0 0", "v 2 0 0", "v 2 0 -1", "v 1 0 -1", "v 1 0 -2", "v 0 0 -2",
		"v 5 0 0", "v 6 0 0", "v 6 0 -1", "v 5 0 -1",
		"vt 0 0", "vt 1 0", "vt 1 1", "vt 0 1",
		"f 1/1 2/2 3/3 4/4 5/1 6/2", "f 7/1 8/2 9/3 10/4"]))
	var nodes := Converter.load_obj(path)
	check(nodes.size() == 1 and nodes[0].name == &"shapes", "one node named after the file: %s" % [nodes])
	var faces := _faces((nodes[0] as MeshInstance3D).mesh)
	check(faces.triangles == 6, "4 + 2 triangles (%d)" % faces.triangles)
	check_near(faces.area, 4.0, 1e-4, "the triangles cover the concave polygon and the quad exactly")
	check(faces.normal.is_equal_approx(Vector3.UP), "every triangle faces +Y in Godot's winding (%s)" % faces.normal)
	var uvs: PackedVector2Array = (nodes[0] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(uvs.has(Vector2(0, 1)) and uvs.has(Vector2(1, 0)), "texture v flipped to Godot's top-left origin (%s)" % [uvs])
	for node in nodes:
		node.free()
	_cleanup()


func test_obj_objects_become_nodes_and_take_the_texture_beside_them() -> void:
	var path := _write("town.obj", "\n".join([
		"o Block A", "v 0 0 0", "v 1 0 0", "v 1 1 0", "f 1 2 3",
		"g street", "v 0 0 1", "v 1 0 1", "v 1 0 2", "f -3 -2 -1"]))
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png(path.get_basename() + ".png")
	var nodes := Converter.load_obj(path)
	var names: Array = nodes.map(func(node: Node3D) -> String: return str(node.name))
	check(names == ["Block A", "street"], "one node per object or group (%s)" % [names])
	var material := (nodes[0] as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	check(material != null and material.albedo_texture != null, "no material library: the PNG of the same name is the texture")
	check((nodes[1] as MeshInstance3D).mesh.get_aabb().position.z == 1.0, "negative indices count from the end")
	for node in nodes:
		node.free()
	_cleanup()


func test_stl_binary_and_ascii_keep_their_axes() -> void:
	# A Z-up square (two triangles, counter-clockwise around +Z) in binary STL.
	var corners := [Vector3(0, 0, 5), Vector3(10, 0, 5), Vector3(10, 10, 5), Vector3(0, 0, 5), Vector3(10, 10, 5), Vector3(0, 10, 5)]
	var bytes := PackedByteArray()
	bytes.resize(84 + 50 * 2)
	bytes.encode_u32(80, 2)
	for t in 2:
		for k in 3:
			var corner: Vector3 = corners[t * 3 + k]
			for axis in 3:
				bytes.encode_float(84 + 50 * t + 12 + 12 * k + 4 * axis, corner[axis])
	DirAccess.make_dir_recursive_absolute(DIR)
	var binary := ProjectSettings.globalize_path(DIR.path_join("Site 1.stl"))
	var file := FileAccess.open(binary, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var nodes := Converter.load_stl(binary)
	var mesh := (nodes[0] as MeshInstance3D).mesh
	var faces := _faces(mesh)
	check(nodes[0].name == &"Site 1" and faces.triangles == 2, "one node named after the file, 2 triangles")
	check((mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 4, "shared corners welded")
	check(faces.normal.is_equal_approx(Vector3.BACK), "still facing +Z: no axis change (%s)" % faces.normal)
	var ascii := _write("tri.stl", "solid t\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\nvertex 1 0 0\nvertex 0 1 0\nendloop\nendfacet\nendsolid t\n")
	var ascii_nodes := Converter.load_stl(ascii)
	check(_faces((ascii_nodes[0] as MeshInstance3D).mesh).triangles == 1, "ASCII STL read")
	# Written to a GLB and read back, the square is still Z-up.
	var root := Node3D.new()
	root.name = "site"
	root.add_child(nodes[0])
	nodes[0].owner = root
	var glb := ProjectSettings.globalize_path(DIR.path_join("site.glb"))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	check(document.append_from_scene(root, state) == OK and document.write_to_filesystem(state, glb) == OK, "GLB written")
	root.free()
	var read_state := GLTFState.new()
	var reader := GLTFDocument.new()
	check(reader.append_from_file(glb, read_state) == OK, "GLB read back")
	var scene := reader.generate_scene(read_state)
	var found: Array[Node] = [scene] if scene is MeshInstance3D else scene.find_children("*", "MeshInstance3D", true, false)
	var read_mesh := (found[0] as MeshInstance3D).mesh
	var bounds := read_mesh.get_aabb()
	check(bounds.position.is_equal_approx(Vector3(0, 0, 5)) and bounds.size.distance_to(Vector3(10, 10, 0)) < 0.001, "same bounds after the GLB round trip (%s)" % bounds)
	check(_faces(read_mesh).normal.is_equal_approx(Vector3.BACK), "same facing after the GLB round trip")
	scene.free()
	for node in ascii_nodes:
		node.free()
	_cleanup()
