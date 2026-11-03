extends "res://tests/test_case.gd"
## The import tool's colliders by shape (Phase 6b, docs/MAP_CONTRACT.md, R2):
## capsules round trunks and poles, boxes for blocks and fences, nothing for
## small or low objects, and concave buildings (a courtyard, an L or U plan)
## as their own triangles instead of a hull that fills them.

const MapImporter := preload("res://tools/map_import/map_importer.gd")
const MapGeometry := preload("res://tools/map_import/map_geometry.gd")
const MapColliders := preload("res://tools/map_import/map_colliders.gd")
const Imports := preload("res://tests/unit/test_map_import.gd")


## A closed prism over `polygon` (x, z, counter-clockwise seen from above)
## from y = 0 to `height`, faces out in Godot's winding.
static func _prism(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var positions := PackedVector3Array()
	var cap := Geometry2D.triangulate_polygon(polygon)
	for t in range(0, cap.size(), 3):
		var a := polygon[cap[t]]
		var b := polygon[cap[t + 1]]
		var c := polygon[cap[t + 2]]
		var top := [Vector3(a.x, height, a.y), Vector3(b.x, height, b.y), Vector3(c.x, height, c.y)]
		var bottom := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(c.x, 0, c.y)]
		for corner: Vector3 in _facing(top, Vector3.UP):
			positions.append(corner)
		for corner: Vector3 in _facing(bottom, Vector3.DOWN):
			positions.append(corner)
	var center := Vector2.ZERO
	for point in polygon:
		center += point / polygon.size()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var out := Vector3(b.y - a.y, 0, a.x - b.x)
		var quad := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, height, b.y), Vector3(a.x, height, a.y)]
		for corner: Vector3 in _facing([quad[0], quad[1], quad[2]], out) + _facing([quad[0], quad[2], quad[3]], out):
			positions.append(corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A triangle wound so that its Godot front face points along `normal`.
static func _facing(corners: Array, normal: Vector3) -> Array:
	var face := (corners[2] - corners[0]).cross(corners[1] - corners[0]) as Vector3
	return corners if face.dot(normal) > 0.0 else [corners[0], corners[2], corners[1]]


## A U-shaped building, 20 m × 20 m, 9 m high, its yard (10 m × 12 m) open to +Z.
static func _u_building() -> ArrayMesh:
	return _prism(PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(5, 10), Vector2(5, -2), Vector2(-5, -2), Vector2(-5, 10), Vector2(-10, 10)]), 9.0)


func _shapes(node: Node) -> Array:
	if not node.has_node("StaticBody3D"):
		return []
	return node.get_node("StaticBody3D").get_children().map(func(child: CollisionShape3D) -> Shape3D: return child.shape)


func test_concave_building_collides_as_its_triangles() -> void:
	var u := _u_building()
	check(MapGeometry.shell(u).boundary == 0 and MapGeometry.stats(u).volume > 0.0, "the test building is a closed, outward shell")
	var shape := MapColliders.hull(MapGeometry.parts(u)[0])
	check(MapColliders.is_concave(u, shape), "its hull would fill the yard: concave")
	var block := Imports._boxes([[Vector3(0, 4, 0), Vector3(10, 8, 12)]])
	check(not MapColliders.is_concave(block, MapColliders.hull(MapGeometry.parts(block)[0])), "a box is not")
	var importer := MapImporter.new()
	check(importer.process(Imports._scene([["ground_main", Imports._plane(80.0)], ["house_u", u, Vector3(0, 0, -10)], ["house_box", block, Vector3(25, 0, 0)]])), "passes")
	check(_shapes(importer.model.get_node("house_u"))[0] is ConcavePolygonShape3D, "the U building: a trimesh")
	check(_shapes(importer.model.get_node("house_box"))[0] is ConvexPolygonShape3D, "the box: its hull")
	check(importer.summary.colliders.concave == 1, "counted as concave: %s" % [importer.summary.colliders])
	add_node(importer.model)
	await physics_frames(2)
	var space := importer.model.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 30, -5), Vector3(0, -5, -5), 1))
	check(not hit.is_empty() and (hit.collider as Node).get_parent().name == &"ground_main", "a ray into the yard reaches the ground (%s)" % [hit])
	# The player's capsule walks from the street into the yard.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var walk := PhysicsShapeQueryParameters3D.new()
	walk.shape = capsule
	walk.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 8))
	walk.motion = Vector3(0, 0, -12)
	walk.collision_mask = 1
	check(space.cast_motion(walk)[0] > 0.99, "the capsule walks 12 m into the yard unhindered (%s)" % [space.cast_motion(walk)])


func test_trees_poles_fences_and_small_things() -> void:
	var tree := Imports._boxes([[Vector3(0, 1.5, 0), Vector3(0.4, 3, 0.4)], [Vector3(0, 4.5, 0), Vector3(3, 3, 3)]])
	var lamp := Imports._boxes([[Vector3(0, 3, 0), Vector3(0.2, 6, 0.2)], [Vector3(0.8, 5.9, 0), Vector3(1.6, 0.15, 0.2)]])
	var fence := Imports._boxes([[Vector3(0, 0.6, 0), Vector3(6, 1.2, 0.1)]])
	var crate := Imports._boxes([[Vector3(0, 0.5, 0), Vector3(1, 1, 1)]])
	var stone := Imports._boxes([[Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3)]])
	var importer := MapImporter.new()
	check(importer.process(Imports._scene([["ground_main", Imports._plane(80.0)], ["tree_1", tree, Vector3(10, 0, 10)], ["StreetLamp_1", lamp, Vector3(-10, 0, 0)],
			["fence_1", fence, Vector3(0, 0, 20)], ["crate_prop", crate, Vector3(5, 0, -10)], ["stone_prop", stone, Vector3(-5, 0, -10)], ["house_1", Imports._boxes([[Vector3(0, 4, 0), Vector3(8, 8, 10)]]), Vector3(-25, 0, -25)]])), "passes")
	var trunk := importer.model.get_node("tree_1/StaticBody3D/CollisionShape3D") as CollisionShape3D
	check(trunk.shape is CapsuleShape3D and is_equal_approx((trunk.shape as CapsuleShape3D).radius, 0.2), "a tree: a capsule round its 0.4 m trunk (%s)" % [trunk.shape])
	check(trunk.position.is_equal_approx(Vector3(0, (trunk.shape as CapsuleShape3D).height * 0.5, 0)) and (trunk.shape as CapsuleShape3D).height <= MapColliders.CAPSULE_HEIGHT, "standing on the ground at the trunk (%s)" % trunk.position)
	check(_shapes(importer.model.get_node("StreetLamp_1"))[0] is CapsuleShape3D, "a lamp post: a capsule")
	var fence_shape: Shape3D = _shapes(importer.model.get_node("fence_1"))[0]
	check(fence_shape is BoxShape3D and (fence_shape as BoxShape3D).size.is_equal_approx(Vector3(6, 1.2, 0.1)), "a fence: a box")
	check(_shapes(importer.model.get_node("crate_prop"))[0] is BoxShape3D, "a 1 m crate: a box")
	check(_shapes(importer.model.get_node("stone_prop")).is_empty(), "a 0.2 m stone: none (stepped over)")
	add_node(importer.model)
	await physics_frames(2)
	var space := importer.model.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var walk := PhysicsShapeQueryParameters3D.new()
	walk.shape = capsule
	walk.collision_mask = 1
	walk.transform = Transform3D(Basis.IDENTITY, Vector3(10, 1.2, 14))
	walk.motion = Vector3(0, 0, -8)
	check(space.cast_motion(walk)[0] < 0.5, "walking at the tree stops at its trunk (%s)" % [space.cast_motion(walk)])
	walk.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 24))
	check(space.cast_motion(walk)[0] < 0.6, "walking at the fence stops at it (%s)" % [space.cast_motion(walk)])
	walk.transform = Transform3D(Basis.IDENTITY, Vector3(-5, 1.2, -6))
	check(space.cast_motion(walk)[0] > 0.99, "walking over the small stone is not blocked")


func test_rotated_tree_capsule_stands_upright() -> void:
	# A tree node turned like a Z-up file's nodes after the axis fix.
	var tree := Imports._boxes([[Vector3(0, 0, 1.5), Vector3(0.4, 0.4, 3)], [Vector3(0, 0, 4.5), Vector3(3, 3, 3)]])
	var node := MeshInstance3D.new()
	node.mesh = tree
	node.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(3, 0, 3))
	var holder := Node3D.new()
	holder.add_child(node)
	var result := MapColliders.add_collider(node, "capsule", holder, "trees")
	var shape := node.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
	var placed := node.transform * shape.transform
	check(result.types == {"capsule": 1} and placed.basis.y.is_equal_approx(Vector3.UP), "the capsule's axis is the map's up (%s)" % placed.basis.y)
	check(placed.origin.is_equal_approx(Vector3(3, (shape.shape as CapsuleShape3D).height * 0.5, 3)), "at the trunk on the ground (%s)" % placed.origin)
	holder.free()
