extends RefCounted
## Colliders of the import tool (docs/MAP_CONTRACT.md, R2): Godot's collision
## node names (-col, -colonly, -convcol, -convcolonly) or, without them, a
## collider type per category. Every collider is a StaticBody3D on physics
## layer 1 (world) under its mesh, as Godot's GLB import makes them, so
## RenderSettings.build_occluders() finds the shapes of the occluder categories.

const MapGeometry := preload("res://tools/map_import/map_geometry.gd")

## Collision node suffixes and the collider each makes (longest first).
const SUFFIXES := {"-convcolonly": "convex", "-colonly": "trimesh", "-convcol": "convex", "-col": "trimesh"}
## Collider per category without collision nodes or a configuration.
const DEFAULT_TYPES := {"ground": "trimesh", "buildings": "convex"}
const TYPES := ["trimesh", "convex", "box", "none"]
## Parts smaller than this (m, largest side) get no convex or box collider;
## parts thinner than FLAT (m, smallest side) neither (a flat hull is no volume).
const MIN_PART := 0.5
const FLAT := 0.02


## The collision suffix of a node name ("" when it has none).
static func suffix_of(node_name: String) -> String:
	for suffix: String in SUFFIXES:
		if node_name.ends_with(suffix):
			return suffix
	return ""


## Adds a collider of `type` under `mesh_instance`; returns
## {"shapes", "triangles" (trimesh), "skipped" (parts too small or flat)}.
## `owner` is the node the saved scene is packed from.
static func add_collider(mesh_instance: MeshInstance3D, type: String, owner: Node) -> Dictionary:
	var result := {"shapes": 0, "triangles": 0, "skipped": 0}
	if type == "none" or mesh_instance.mesh == null:
		return result
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	mesh_instance.add_child(body)
	body.owner = owner
	match type:
		"trimesh":
			var shape := mesh_instance.mesh.create_trimesh_shape()
			if shape:
				_add_shape(body, shape, Transform3D.IDENTITY, owner)
				result.shapes += 1
				result.triangles += shape.get_faces().size() / 3
		"convex", "box":
			for points in MapGeometry.parts(mesh_instance.mesh):
				var box := _bounds(points)
				if box.get_longest_axis_size() < MIN_PART or box.get_shortest_axis_size() < FLAT:
					result.skipped += 1
					continue
				if type == "box":
					var shape := BoxShape3D.new()
					shape.size = box.size
					_add_shape(body, shape, Transform3D(Basis.IDENTITY, box.get_center()), owner)
				else:
					_add_shape(body, hull(points), Transform3D.IDENTITY, owner)
				result.shapes += 1
	if result.shapes == 0:
		mesh_instance.remove_child(body)
		body.free()
	return result


## A convex shape holding only the hull's vertices of `points`.
static func hull(points: PackedVector3Array) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var faces := shape.get_debug_mesh()
	for surface in faces.get_surface_count():
		if faces.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			shape.points = faces.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	return shape


static func _add_shape(body: StaticBody3D, shape: Shape3D, transform: Transform3D, owner: Node) -> void:
	var node := CollisionShape3D.new()
	node.name = "CollisionShape3D" if body.get_child_count() == 0 else "CollisionShape3D%d" % (body.get_child_count() + 1)
	node.shape = shape
	node.transform = transform
	body.add_child(node)
	node.owner = owner


static func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box
