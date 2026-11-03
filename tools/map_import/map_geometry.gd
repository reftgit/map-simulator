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


## Triangles in the triangle surfaces of `mesh`.
static func triangle_count(mesh: Mesh) -> int:
	var count := 0
	for surface: Array in triangle_surfaces(mesh):
		count += ((surface[2] as PackedInt32Array).size() if surface[2] != null else (surface[0] as PackedVector3Array).size()) / 3
	return count


## Whether every triangle surface of `mesh` has normals.
static func has_normals(mesh: Mesh) -> bool:
	for surface: Array in triangle_surfaces(mesh):
		if surface[1] == null:
			return false
	return true


## Statistics of `mesh` placed with rotation `basis`: triangles, zero-area
## triangles, total area, the area facing within 30° of +Y ("up"), −Y
## ("down"), and each axis direction ("+x" … "-z"), the area-weighted
## coordinate along its axis of the faces toward each direction ("at_+x" …,
## after `basis`, for the up-axis detection), the vertical area (normals
## within 30° of horizontal; "side_x", "side_z" for X or Z as the up axis),
## the area its upward faces cover seen from above ("cover": a roof covers
## its building's footprint, a fence ring almost nothing), the triangles
## whose winding disagrees with their given normals, the sum
## of the area-weighted face normals (zero for a closed surface), and the
## enclosed volume measured from the centre of the mesh's box (positive when
## the faces point out; for a surface that is not closed it depends on that
## centre by up to |normal_sum| times the box's half diagonal over 3).
static func stats(mesh: Mesh, basis := Basis.IDENTITY) -> Dictionary:
	var result := {"triangles": 0, "zero_area": 0, "area": 0.0, "vertical": 0.0, "side_x": 0.0, "side_z": 0.0, "flipped": 0,
			"normal_sum": Vector3.ZERO, "volume": 0.0, "cover": 0.0}
	# Per axis direction (+x, -x, +y, -y, +z, -z): facing area, area times coordinate.
	var facing := PackedFloat64Array([0, 0, 0, 0, 0, 0])
	var at := PackedFloat64Array([0, 0, 0, 0, 0, 0])
	var center := mesh.get_aabb().get_center() if mesh else Vector3.ZERO
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
			result.normal_sum += n * area
			if n.y > 0.0:
				result.cover += n.y * area
			result.volume -= (a - center).dot((positions[i1] - center).cross(positions[i2] - center)) / 6.0
			for axis in 3:
				var component: float = n[axis]
				if absf(component) >= COS_30:
					var slot := axis * 2 + (0 if component > 0.0 else 1)
					facing[slot] += area
					at[slot] += area * (basis * ((a + positions[i1] + positions[i2]) / 3.0))[axis]
			if absf(n.y) <= 0.5:
				result.vertical += area
			if absf(n.x) <= 0.5:
				result.side_x += area
			if absf(n.z) <= 0.5:
				result.side_z += area
	for slot in 6:
		var direction: String = ["+x", "-x", "+y", "-y", "+z", "-z"][slot]
		result[direction] = facing[slot]
		result["at_" + direction] = at[slot]
	result.up = facing[2]
	result.down = facing[3]
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


## A copy of `mesh` turned inside out: every triangle's winding reversed,
## and its normals negated when `normals_too` (tangents dropped).
static func turned_out(mesh: Mesh, normals_too: bool) -> ArrayMesh:
	var out_mesh := ArrayMesh.new()
	out_mesh.resource_name = mesh.resource_name
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var primitive: Mesh.PrimitiveType = mesh.surface_get_primitive_type(surface)
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			var order := _triangle_order(arrays)
			for t in range(0, order.size(), 3):
				var swap := order[t + 1]
				order[t + 1] = order[t + 2]
				order[t + 2] = swap
			arrays[Mesh.ARRAY_INDEX] = order
			if normals_too and arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normals.size():
					normals[i] = -normals[i]
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
		out_mesh.add_surface_from_arrays(primitive, arrays)
		out_mesh.surface_set_material(surface, mesh.surface_get_material(surface))
		out_mesh.surface_set_name(surface, mesh.surface_get_name(surface))
	return out_mesh


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


## The connected parts of `mesh` (as parts()) as meshes of their own: the
## same surfaces and materials with only the part's triangles, its vertices
## re-indexed, in the order the parts first appear.
static func part_meshes(mesh: Mesh) -> Array[ArrayMesh]:
	var index_of := {}
	var parent := []
	var surfaces := []  # [surface index, arrays, corner order, welded id per corner]
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var order := _triangle_order(arrays)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var welded := PackedInt32Array()
		welded.resize(order.size())
		for i in order.size():
			var key := Vector3i((positions[order[i]] / WELD).round())
			if not index_of.has(key):
				index_of[key] = parent.size()
				parent.append(parent.size())
			welded[i] = index_of[key]
		surfaces.append([surface, arrays, order, welded])
	for entry: Array in surfaces:
		var welded: PackedInt32Array = entry[3]
		for t in range(0, welded.size(), 3):
			var root_a := _find(parent, welded[t])
			for k in [1, 2]:
				var root_b := _find(parent, welded[t + k])
				if root_a != root_b:
					parent[root_b] = root_a
	var part_of_root := {}
	var parts := []  # per part: {slot in surfaces: PackedInt32Array of triangle starts}
	for slot in surfaces.size():
		var welded: PackedInt32Array = surfaces[slot][3]
		for t in range(0, welded.size(), 3):
			var root := _find(parent, welded[t])
			if not part_of_root.has(root):
				part_of_root[root] = parts.size()
				parts.append({})
			var triangles: Dictionary = parts[part_of_root[root]]
			if not triangles.has(slot):
				triangles[slot] = PackedInt32Array()
			triangles[slot].append(t)
	var result: Array[ArrayMesh] = []
	for triangles: Dictionary in parts:
		var out := ArrayMesh.new()
		out.resource_name = mesh.resource_name
		for slot: int in triangles:
			var entry: Array = surfaces[slot]
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _subset(entry[1], entry[2], triangles[slot]))
			out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(entry[0]))
			out.surface_set_name(out.get_surface_count() - 1, mesh.surface_get_name(entry[0]))
		result.append(out)
	return result


## Surface arrays holding only the triangles starting at `starts` (corner
## positions in `order`), with the vertex attributes they use.
static func _subset(arrays: Array, order: PackedInt32Array, starts: PackedInt32Array) -> Array:
	var remap := {}
	var used := PackedInt32Array()
	var indices := PackedInt32Array()
	for t in starts:
		for k in 3:
			var vertex := order[t + k]
			if not remap.has(vertex):
				remap[vertex] = used.size()
				used.append(vertex)
			indices.append(remap[vertex])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var source = arrays[slot]
		if source == null or source.size() != count:
			continue
		var gathered = PackedVector3Array() if slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL] else PackedVector2Array()
		gathered.resize(used.size())
		for i in used.size():
			gathered[i] = source[used[i]]
		out[slot] = gathered
	if arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == count:
		var colors := PackedColorArray()
		colors.resize(used.size())
		for i in used.size():
			colors[i] = arrays[Mesh.ARRAY_COLOR][used[i]]
		out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	return out


## How the vertices of `mesh` placed with `transform` spread over its height:
## the horizontal extent (x, z) and centre of those in its lowest tenth
## ("low", "low_center", the latter at the bottom) and of those above 30 % of
## its height ("crown"), and the height ("height"). A tree is a narrow trunk
## under a wide crown, a pole narrow at the bottom.
static func profile(mesh: Mesh, transform: Transform3D) -> Dictionary:
	var points := PackedVector3Array()
	for surface: Array in triangle_surfaces(mesh):
		for point: Vector3 in surface[0]:
			points.append(transform * point)
	if points.is_empty():
		return {}
	var bottom := INF
	var top := -INF
	for point in points:
		bottom = minf(bottom, point.y)
		top = maxf(top, point.y)
	var height := top - bottom
	var low := Rect2()
	var crown := Rect2()
	var low_seen := false
	var crown_seen := false
	for point in points:
		var flat := Vector2(point.x, point.z)
		if point.y <= bottom + 0.1 * height:
			low = low.expand(flat) if low_seen else Rect2(flat, Vector2.ZERO)
			low_seen = true
		if point.y >= bottom + 0.3 * height:
			crown = crown.expand(flat) if crown_seen else Rect2(flat, Vector2.ZERO)
			crown_seen = true
	var center := low.get_center()
	return {"height": height, "low": low.size, "low_center": Vector3(center.x, bottom, center.y), "crown": crown.size}


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
