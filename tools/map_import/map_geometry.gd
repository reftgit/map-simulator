extends RefCounted
## Geometry measurements and fixes of the import tool (tools/import_map.gd):
## triangle statistics, flat normals, baked transforms, connected parts, and
## closed-shell checks. Godot's front faces wind clockwise, so a triangle's
## front normal is (c - a) x (b - a), and a closed outward shell has a
## negative sum of a . (b x c) (both measured on BoxMesh and on the shipped
## İstanbul GLB, 2026-11-02).

## Triangles smaller than this (m²) count as zero-area (C7).
const ZERO_AREA := 1e-6
## Normal within 30° of an axis.
const COS_30 := 0.8660254
## Positions closer than this (m) are one vertex for parts and shells.
const WELD := 0.001


## The triangle surfaces of `mesh` as [positions, normals or null, indices or
## null] per surface; other primitive types are left out.
static func triangle_surfaces(mesh: Mesh) -> Array:
	var surfaces := []
	if mesh == null:
		return surfaces
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var normals = arrays[Mesh.ARRAY_NORMAL]
		if normals != null and (normals as PackedVector3Array).is_empty():
			normals = null
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and (indices as PackedInt32Array).is_empty():
			indices = null
		surfaces.append([arrays[Mesh.ARRAY_VERTEX], normals, indices])
	return surfaces


## Surfaces of `mesh` that are not triangles (lines, points, strips).
static func other_primitives(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			count += 1
	return count


## Whether every triangle surface of `mesh` has normals.
static func has_normals(mesh: Mesh) -> bool:
	for surface: Array in triangle_surfaces(mesh):
		if surface[1] == null:
			return false
	return true


## Statistics of `mesh` placed with rotation `basis`: triangles, zero-area
## triangles, total area, the area facing within 30° of +Y, −Y, +Z, −Z, the
## vertical area (normals within 30° of horizontal), and the triangles whose
## winding disagrees with their given normals.
static func stats(mesh: Mesh, basis := Basis.IDENTITY) -> Dictionary:
	var result := {"triangles": 0, "zero_area": 0, "area": 0.0, "up": 0.0, "down": 0.0, "pos_z": 0.0, "neg_z": 0.0,
			"vertical": 0.0, "flipped": 0}
	for surface: Array in triangle_surfaces(mesh):
		var positions: PackedVector3Array = surface[0]
		var normals = surface[1]
		var indices = surface[2]
		var count: int = (indices as PackedInt32Array).size() if indices != null else positions.size()
		for t in range(0, count - 2, 3):
			var i0: int = indices[t] if indices != null else t
			var i1: int = indices[t + 1] if indices != null else t + 1
			var i2: int = indices[t + 2] if indices != null else t + 2
			var a := positions[i0]
			var face := (positions[i2] - a).cross(positions[i1] - a)
			var double_area := face.length()
			result.triangles += 1
			if double_area < 2.0 * ZERO_AREA:
				result.zero_area += 1
				continue
			if normals != null and face.dot(normals[i0] + normals[i1] + normals[i2]) < 0.0:
				result.flipped += 1
			var area := double_area * 0.5
			var n := basis * (face / double_area)
			result.area += area
			if n.y >= COS_30:
				result.up += area
			elif n.y <= -COS_30:
				result.down += area
			elif absf(n.y) <= 0.5:
				result.vertical += area
			if n.z >= COS_30:
				result.pos_z += area
			elif n.z <= -COS_30:
				result.neg_z += area
	return result


## A copy of `mesh` with flat (per-face) normals: every triangle gets its own
## three vertices; positions, colours, and UVs are kept, the materials too.
static func with_flat_normals(mesh: Mesh) -> ArrayMesh:
	var flat := ArrayMesh.new()
	flat.resource_name = mesh.resource_name
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var order := _triangle_order(arrays)
		var out_positions := PackedVector3Array()
		var out_normals := PackedVector3Array()
		out_positions.resize(order.size())
		out_normals.resize(order.size())
		for t in range(0, order.size(), 3):
			var a := positions[order[t]]
			var b := positions[order[t + 1]]
			var c := positions[order[t + 2]]
			var face := (c - a).cross(b - a)
			var normal := face.normalized() if face.length_squared() > 0.0 else Vector3.UP
			out_positions[t] = a
			out_positions[t + 1] = b
			out_positions[t + 2] = c
			out_normals[t] = normal
			out_normals[t + 1] = normal
			out_normals[t + 2] = normal
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = out_positions
		out[Mesh.ARRAY_NORMAL] = out_normals
		if arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == positions.size():
			out[Mesh.ARRAY_COLOR] = _gathered_colors(arrays[Mesh.ARRAY_COLOR], order)
		for slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arrays[slot] != null and (arrays[slot] as PackedVector2Array).size() == positions.size():
				out[slot] = _gathered_uvs(arrays[slot], order)
		flat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		flat.surface_set_material(flat.get_surface_count() - 1, mesh.surface_get_material(surface))
		flat.surface_set_name(flat.get_surface_count() - 1, mesh.surface_get_name(surface))
	return flat


## The vertex index of every triangle corner of a surface, three per
## triangle (its index array, or 0, 1, 2, … without one).
static func _triangle_order(arrays: Array) -> PackedInt32Array:
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and (indices as PackedInt32Array).size() > 0:
		var order: PackedInt32Array = indices
		order.resize(order.size() - order.size() % 3)
		return order
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var order := PackedInt32Array()
	order.resize(count - count % 3)
	for i in order.size():
		order[i] = i
	return order


static func _gathered_colors(source: PackedColorArray, order: PackedInt32Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(order.size())
	for i in order.size():
		out[i] = source[order[i]]
	return out


static func _gathered_uvs(source: PackedVector2Array, order: PackedInt32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(order.size())
	for i in order.size():
		out[i] = source[order[i]]
	return out


## A copy of `mesh` with `transform` (scale, shear, mirroring; no
## translation) applied to its vertices: positions by the basis, normals by
## its inverse transpose; a mirroring basis also reverses the winding so the
## faces keep facing out. Tangents are dropped.
static func transformed(mesh: Mesh, basis: Basis) -> ArrayMesh:
	var out_mesh := ArrayMesh.new()
	out_mesh.resource_name = mesh.resource_name
	var normal_basis := basis.inverse().transposed()
	var mirrored := basis.determinant() < 0.0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in positions.size():
			positions[i] = basis * positions[i]
		arrays[Mesh.ARRAY_VERTEX] = positions
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():
				normals[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		var primitive: Mesh.PrimitiveType = mesh.surface_get_primitive_type(surface)
		if mirrored and primitive == Mesh.PRIMITIVE_TRIANGLES:
			if arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for t in range(0, indices.size() - 2, 3):
					var swap := indices[t + 1]
					indices[t + 1] = indices[t + 2]
					indices[t + 2] = swap
				arrays[Mesh.ARRAY_INDEX] = indices
			else:
				var reversed_order := PackedInt32Array()
				var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				reversed_order.resize(count - count % 3)
				for v in range(0, reversed_order.size(), 3):
					reversed_order[v] = v
					reversed_order[v + 1] = v + 2
					reversed_order[v + 2] = v + 1
				arrays[Mesh.ARRAY_INDEX] = reversed_order
		out_mesh.add_surface_from_arrays(primitive, arrays)
		out_mesh.surface_set_material(surface, mesh.surface_get_material(surface))
		out_mesh.surface_set_name(surface, mesh.surface_get_name(surface))
	return out_mesh


## The connected parts of `mesh` (triangles sharing a welded vertex), each
## as its point list.
static func parts(mesh: Mesh) -> Array[PackedVector3Array]:
	var welded := _welded(mesh)
	var points: PackedVector3Array = welded.points
	var triangles: PackedInt32Array = welded.triangles
	var parent := range(points.size())
	for t in range(0, triangles.size(), 3):
		var root_a := _find(parent, triangles[t])
		for k in [1, 2]:
			var root_b := _find(parent, triangles[t + k])
			if root_a != root_b:
				parent[root_b] = root_a
	var by_root := {}
	for i in points.size():
		var root := _find(parent, i)
		if not by_root.has(root):
			by_root[root] = PackedVector3Array()
		by_root[root].append(points[i])
	var result: Array[PackedVector3Array] = []
	for root in by_root:
		result.append(by_root[root])
	return result


## Closed-shell check of `mesh`: edges, edges used by one triangle only
## (boundary), and the enclosed volume (positive when the faces point out).
static func shell(mesh: Mesh) -> Dictionary:
	var welded := _welded(mesh)
	var points: PackedVector3Array = welded.points
	var triangles: PackedInt32Array = welded.triangles
	var edges := {}
	var volume := 0.0
	var n := points.size()
	for t in range(0, triangles.size(), 3):
		var ids := [triangles[t], triangles[t + 1], triangles[t + 2]]
		volume -= points[ids[0]].dot(points[ids[1]].cross(points[ids[2]])) / 6.0
		for k in 3:
			var a: int = ids[k]
			var b: int = ids[(k + 1) % 3]
			var key := mini(a, b) * n + maxi(a, b)
			edges[key] = edges.get(key, 0) + 1
	var boundary := 0
	for key in edges:
		if edges[key] == 1:
			boundary += 1
	return {"edges": edges.size(), "boundary": boundary, "volume": volume}


## Positions of every triangle surface welded at WELD: unique points and
## the triangles as indices into them (zero-area triangles left out).
static func _welded(mesh: Mesh) -> Dictionary:
	var index_of := {}
	var points := PackedVector3Array()
	var triangles := PackedInt32Array()
	for surface: Array in triangle_surfaces(mesh):
		var positions: PackedVector3Array = surface[0]
		var indices = surface[2]
		var count: int = (indices as PackedInt32Array).size() if indices != null else positions.size()
		for t in range(0, count - 2, 3):
			var ids := PackedInt32Array()
			for k in 3:
				var vertex := positions[indices[t + k] if indices != null else t + k]
				var key := Vector3i((vertex / WELD).round())
				if not index_of.has(key):
					index_of[key] = points.size()
					points.append(vertex)
				ids.append(index_of[key])
			if ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]:
				triangles.append_array(ids)
	return {"points": points, "triangles": triangles}


## Union-find root of `i`, compressing the path (`parent` is a shared Array).
static func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i
