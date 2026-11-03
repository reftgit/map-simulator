extends RefCounted
## Colliders of the import tool (docs/MAP_CONTRACT.md, R2): Godot's collision
## node names (-col, -colonly, -convcol, -convcolonly) or, without them, a
## collider type per category. Every collider is a StaticBody3D on physics
## layer 1 (world) under its mesh, as Godot's GLB import makes them, so
## RenderSettings.build_occluders() finds the shapes of the occluder categories.

const MapGeometry := preload("res://tools/map_import/map_geometry.gd")

## Collision node suffixes and the collider each makes (longest first).
const SUFFIXES := {"-convcolonly": "convex", "-colonly": "trimesh", "-convcol": "convex", "-col": "trimesh"}
## Collider per category without collision nodes or a configuration: the
## ground as it is, buildings, trees, lamps, and decor by their shape
## ("auto"); facade detail and water none.
const DEFAULT_TYPES := {"ground": "trimesh", "buildings": "auto", "trees": "auto", "lamps": "auto", "decor": "auto"}
const TYPES := ["auto", "trimesh", "convex", "box", "capsule", "none"]
## Parts smaller than this (m, largest side) get no convex or box collider;
## parts thinner than FLAT (m, smallest side) neither (a flat hull is no volume).
const MIN_PART := 0.5
const FLAT := 0.02
## auto: objects lower than this (m) get none either (the player steps over them).
const MIN_HEIGHT := 0.3
## auto, buildings: a part is concave (a courtyard, an L or U plan, walls
## without a roof) when its hull holds more than HULL_RATIO times its volume
## (a closed part) or its upward faces cover less than COVER_RATIO of its
## hull's footprint; it then collides as a trimesh of its own triangles, up
## to TRIMESH_PART of them (beyond, its hull, counted as too big).
const HULL_RATIO := 1.3
const COVER_RATIO := 0.8
const TRIMESH_PART := 20000
## auto, trees, lamps, poles: a vertical capsule round the trunk (the
## lowest tenth of the object), its radius between MIN_RADIUS and
## MAX_RADIUS, as high as the object up to CAPSULE_HEIGHT.
const MIN_RADIUS := 0.15
const MAX_RADIUS := 1.0
const CAPSULE_HEIGHT := 4.0
## auto, decor: a part at most POLE_WIDTH across both ways and at least
## POLE_HEIGHT high is a pole (capsule); a part whose upward faces cover at
## least BOX_COVER of its footprint, or at most POLE_WIDTH thick, a box;
## anything else (a frame, an enclosure) a trimesh.
const POLE_WIDTH := 0.6
const POLE_HEIGHT := 1.5
const BOX_COVER := 0.5


## The collision suffix of a node name ("" when it has none).
static func suffix_of(node_name: String) -> String:
	for suffix: String in SUFFIXES:
		if node_name.ends_with(suffix):
			return suffix
	return ""


## Adds a collider of `type` under `mesh_instance` (of `category` for
## "auto"); returns {"shapes", "triangles" (trimesh), "skipped" (parts too
## small, flat, or low), "types": {shape type: count}, "concave" (building
## parts as trimesh), "too_big" (concave parts kept as hulls)}. `owner` is
## the node the saved scene is packed from.
static func add_collider(mesh_instance: MeshInstance3D, type: String, owner: Node, category := "") -> Dictionary:
	var result := {"shapes": 0, "triangles": 0, "skipped": 0, "types": {}, "concave": 0, "too_big": 0}
	if type == "none" or mesh_instance.mesh == null:
		return result
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	mesh_instance.add_child(body)
	body.owner = owner
	if type == "auto":
		type = {"buildings": "auto_buildings", "trees": "capsule", "lamps": "capsule", "decor": "auto_decor"}.get(category, "convex")
	match type:
		"trimesh":
			_add_trimesh(body, mesh_instance.mesh, owner, result)
		"convex", "box":
			for points in MapGeometry.parts(mesh_instance.mesh):
				var box := _bounds(points)
				if box.get_longest_axis_size() < MIN_PART or box.get_shortest_axis_size() < FLAT:
					result.skipped += 1
				elif type == "box":
					_add_box(body, box, owner, result)
				else:
					_add_shape(body, hull(points), Transform3D.IDENTITY, owner, result, "convex")
		"capsule":
			if not _add_trunk(body, mesh_instance, owner, result):
				result.skipped += 1
		"auto_buildings":
			for part in MapGeometry.part_meshes(mesh_instance.mesh):
				_add_building_part(body, mesh_instance, part, owner, result)
		"auto_decor":
			for part in MapGeometry.part_meshes(mesh_instance.mesh):
				_add_decor_part(body, mesh_instance, part, owner, result)
	if result.shapes == 0:
		mesh_instance.remove_child(body)
		body.free()
	return result


## A building part: its hull when it is about convex, else its own triangles.
static func _add_building_part(body: StaticBody3D, mesh_instance: MeshInstance3D, part: ArrayMesh, owner: Node, result: Dictionary) -> void:
	var points := _points(part)
	var box := _bounds(points)
	if box.get_longest_axis_size() < MIN_PART or box.get_shortest_axis_size() < FLAT:
		result.skipped += 1
		return
	var shape := hull(points)
	if not is_concave(part, shape, mesh_instance.transform.basis):
		_add_shape(body, shape, Transform3D.IDENTITY, owner, result, "convex")
	elif MapGeometry.triangle_count(part) <= TRIMESH_PART:
		_add_trimesh(body, part, owner, result)
		result.concave += 1
	else:
		_add_shape(body, shape, Transform3D.IDENTITY, owner, result, "convex")
		result.too_big += 1


## Whether a part (placed with `basis`) is concave: its hull `shape` holds
## more than HULL_RATIO times its volume (when it is closed), or its upward
## faces cover less than COVER_RATIO of the hull's footprint.
static func is_concave(part: Mesh, shape: ConvexPolygonShape3D, basis := Basis.IDENTITY) -> bool:
	var stats := MapGeometry.stats(part, basis)
	var flat := PackedVector2Array()
	for point in shape.points:
		var placed := basis * point
		flat.append(Vector2(placed.x, placed.z))
	var footprint := absf(_area(Geometry2D.convex_hull(flat)))
	if footprint > 0.0 and stats.cover < COVER_RATIO * footprint:
		return true
	var shell := MapGeometry.shell(part)
	if shell.edges == 0 or shell.boundary > 0.01 * shell.edges or shell.volume <= 0.0:
		return false
	return absf(MapGeometry.stats(_hull_mesh(shape)).volume) > HULL_RATIO * shell.volume


## A decor part: a pole as a capsule, a block or a thin barrier as a box, a
## frame or an enclosure as its own triangles; nothing when small or low.
static func _add_decor_part(body: StaticBody3D, mesh_instance: MeshInstance3D, part: ArrayMesh, owner: Node, result: Dictionary) -> void:
	var points := _points(part)
	var local := _bounds(points)
	var placed := _bounds(_placed(points, mesh_instance.transform.basis))
	var size := placed.size
	if maxf(maxf(size.x, size.z), size.y) < MIN_PART or size.y < MIN_HEIGHT:
		result.skipped += 1
		return
	if maxf(size.x, size.z) <= POLE_WIDTH and size.y >= POLE_HEIGHT:
		_add_capsule(body, mesh_instance, placed, maxf(size.x, size.z) * 0.5, owner, result)
		return
	var cover: float = MapGeometry.stats(part, mesh_instance.transform.basis).cover
	if cover >= BOX_COVER * size.x * size.z or minf(size.x, size.z) <= POLE_WIDTH:
		_add_box(body, local, owner, result)
	else:
		_add_trimesh(body, part, owner, result)


## A vertical capsule round the trunk of a tree, lamp, or pole (the
## horizontal extent of its lowest tenth); false when it is too low.
static func _add_trunk(body: StaticBody3D, mesh_instance: MeshInstance3D, owner: Node, result: Dictionary) -> bool:
	var profile := MapGeometry.profile(mesh_instance.mesh, mesh_instance.transform)
	if profile.is_empty() or profile.height < MIN_HEIGHT * 2.0:
		return false
	var radius: float = maxf(profile.low.x, profile.low.y) * 0.5
	var bottom: Vector3 = profile.low_center - mesh_instance.position
	_add_capsule(body, mesh_instance, AABB(bottom - Vector3(radius, 0, radius), Vector3(radius * 2.0, profile.height, radius * 2.0)), radius, owner, result)
	return true


## A capsule standing upright in the map at the bottom centre of `placed`
## (a box in map orientation, relative to the node's position).
static func _add_capsule(body: StaticBody3D, mesh_instance: MeshInstance3D, placed: AABB, radius: float, owner: Node, result: Dictionary) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = clampf(radius, MIN_RADIUS, MAX_RADIUS)
	shape.height = maxf(minf(placed.size.y, CAPSULE_HEIGHT), shape.radius * 2.0)
	var center := placed.get_center()
	center.y = placed.position.y + shape.height * 0.5
	# The body is under the node: undo its rotation so the capsule stands upright in the map.
	var basis := mesh_instance.transform.basis.inverse()
	_add_shape(body, shape, Transform3D(basis, basis * center), owner, result, "capsule")


static func _add_box(body: StaticBody3D, box: AABB, owner: Node, result: Dictionary) -> void:
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * FLAT)
	_add_shape(body, shape, Transform3D(Basis.IDENTITY, box.get_center()), owner, result, "box")


static func _add_trimesh(body: StaticBody3D, mesh: Mesh, owner: Node, result: Dictionary) -> void:
	var shape := mesh.create_trimesh_shape()
	if shape:
		_add_shape(body, shape, Transform3D.IDENTITY, owner, result, "trimesh")
		result.triangles += shape.get_faces().size() / 3


## A convex shape holding only the hull's vertices of `points`.
static func hull(points: PackedVector3Array) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var faces := shape.get_debug_mesh()
	for surface in faces.get_surface_count():
		if faces.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			shape.points = faces.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	return shape


## The triangles of a convex shape's hull as a mesh (for its volume).
static func _hull_mesh(shape: ConvexPolygonShape3D) -> Mesh:
	var faces := shape.get_debug_mesh()
	var out := ArrayMesh.new()
	for surface in faces.get_surface_count():
		if faces.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, faces.surface_get_arrays(surface))
	return out


static func _add_shape(body: StaticBody3D, shape: Shape3D, transform: Transform3D, owner: Node, result: Dictionary, kind: String) -> void:
	var node := CollisionShape3D.new()
	node.name = "CollisionShape3D" if body.get_child_count() == 0 else "CollisionShape3D%d" % (body.get_child_count() + 1)
	node.shape = shape
	node.transform = transform
	body.add_child(node)
	node.owner = owner
	result.shapes += 1
	result.types[kind] = result.types.get(kind, 0) + 1


static func _points(mesh: Mesh) -> PackedVector3Array:
	var points := PackedVector3Array()
	for surface: Array in MapGeometry.triangle_surfaces(mesh):
		points.append_array(surface[0])
	return points


static func _placed(points: PackedVector3Array, basis: Basis) -> PackedVector3Array:
	var placed := PackedVector3Array()
	placed.resize(points.size())
	for i in points.size():
		placed[i] = basis * points[i]
	return placed


static func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box


## Signed area of a polygon.
static func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return area * 0.5
