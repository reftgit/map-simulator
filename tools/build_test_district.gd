extends SceneTree
## Builds the test district (Phase 5), a small second map made only of Godot
## primitives and StandardMaterial3D colours: a 124 m ground slab, two
## crossing streets, box buildings, a ramp up to a raised plaza, perimeter
## walls, and the same sky and sun as İstanbul • Haliç. Writes
## maps/test_district/test_district.tscn and test_district_occluders.tscn (one
## box occluder per building, in the ArrayOccluder3D form RenderSettings and
## tools/bake_occluders.gd use). The MapDefinition (test_district.tres) is
## written by hand, like İstanbul's; its spawn, vehicle spawns, routes, and
## viewpoints refer to the layout below. Edit the layout here and re-run:
##   godot --headless --path . --script res://tools/build_test_district.gd
## Node names follow RenderSettings.CATEGORIES ("Ground_", "Road_",
## "Buildings_"); every solid part is a mesh with a StaticBody3D child on the
## world layer, as the GLB import makes them, but with box (and one convex)
## shapes instead of trimesh.

const OUT_DIR := "res://maps/test_district"

## Buildings: name -> [centre x, centre z, size x, height, size z] (m).
const BUILDINGS := {
	"Buildings_NW1": [-20.0, -20.0, 20.0, 14.0, 20.0],
	"Buildings_NW2": [-45.0, -42.0, 18.0, 22.0, 20.0],
	"Buildings_NE1": [20.0, -22.0, 20.0, 10.0, 24.0],
	"Buildings_NE2": [45.0, -45.0, 16.0, 26.0, 16.0],
	"Buildings_SW1": [-22.0, 22.0, 24.0, 8.0, 20.0],
	"Buildings_SW2": [-45.0, 45.0, 14.0, 12.0, 14.0],
	"Buildings_SE1": [52.0, 52.0, 12.0, 10.0, 12.0],
}
const BUILDING_COLORS: Array[Color] = [Color(0.82, 0.72, 0.58), Color(0.7, 0.75, 0.8), Color(0.85, 0.8, 0.7), Color(0.66, 0.6, 0.62)]
## Ground slab: top at y = 0, 124 m square (the walls stand on its edge).
const GROUND_SIZE := 124.0
## Streets (visual only; the slab is the walkable surface): 10 m wide, along Z
## (north-south) and along X (east-west), crossing at the origin.
const ROAD_WIDTH := 10.0
const ROAD_LENGTH := 120.0
## Raised plaza (SE block): x 20..44, z 20..44, top at y = 2.
const PLAZA_CENTER := Vector3(32.0, 1.0, 32.0)
const PLAZA_SIZE := Vector3(24.0, 2.0, 24.0)
## Ramp from the east-west street up to the plaza's north edge: 12 m wide
## (x 26..38), 12 m long (z 8..20), 2 m rise (9.5°).
const RAMP_CENTER := Vector3(32.0, 1.0, 14.0)
const RAMP_RUN := 12.0
const RAMP_WIDTH := 12.0
const RAMP_RISE := 2.0
## Perimeter walls, 2 m thick and 3 m high; inner faces at ±60 m.
const WALL_HEIGHT := 3.0
const WALL_CENTER := 61.0


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "TestDistrict"
	_add_environment(root)
	_add_box(root, "Ground_Base", Vector3(0.0, -0.5, 0.0), Vector3(GROUND_SIZE, 1.0, GROUND_SIZE), Color(0.55, 0.58, 0.52), true)
	_add_box(root, "Road_NorthSouth", Vector3(0.0, 0.01, 0.0), Vector3(ROAD_WIDTH, 0.02, ROAD_LENGTH), Color(0.22, 0.23, 0.25), false)
	_add_box(root, "Road_EastWest", Vector3(0.0, 0.012, 0.0), Vector3(ROAD_LENGTH, 0.02, ROAD_WIDTH), Color(0.22, 0.23, 0.25), false)
	_add_box(root, "Ground_Plaza", PLAZA_CENTER, PLAZA_SIZE, Color(0.7, 0.66, 0.58), true)
	_add_ramp(root)
	var index := 0
	for building: String in BUILDINGS:
		var b: Array = BUILDINGS[building]
		_add_box(root, building, Vector3(b[0], b[3] * 0.5, b[1]), Vector3(b[2], b[3], b[4]), BUILDING_COLORS[index % BUILDING_COLORS.size()], true)
		index += 1
	var walls := {
		"Buildings_Wall_North": [Vector3(0.0, WALL_HEIGHT * 0.5, -WALL_CENTER), Vector3(GROUND_SIZE, WALL_HEIGHT, 2.0)],
		"Buildings_Wall_South": [Vector3(0.0, WALL_HEIGHT * 0.5, WALL_CENTER), Vector3(GROUND_SIZE, WALL_HEIGHT, 2.0)],
		"Buildings_Wall_West": [Vector3(-WALL_CENTER, WALL_HEIGHT * 0.5, 0.0), Vector3(2.0, WALL_HEIGHT, GROUND_SIZE - 4.0)],
		"Buildings_Wall_East": [Vector3(WALL_CENTER, WALL_HEIGHT * 0.5, 0.0), Vector3(2.0, WALL_HEIGHT, GROUND_SIZE - 4.0)],
	}
	for wall: String in walls:
		_add_box(root, wall, walls[wall][0], walls[wall][1], Color(0.5, 0.5, 0.5), true)
	_save(root, OUT_DIR.path_join("test_district.tscn"))
	var occluders := _occluders()
	_save(occluders, OUT_DIR.path_join("test_district_occluders.tscn"))
	print("test district: %d nodes, %d occluders" % [root.get_child_count(), occluders.get_child_count()])
	root.free()
	occluders.free()
	quit(0)


## Sky, ambient light, and sun as in maps/istanbul_halic/istanbul_halic.tscn.
func _add_environment(root: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.45098, 0.623529, 0.666667)
	sky_material.sky_horizon_color = Color(0.843137, 0.866667, 0.815686)
	sky_material.ground_bottom_color = Color(0.392157, 0.490196, 0.501961)
	sky_material.ground_horizon_color = Color(0.843137, 0.866667, 0.815686)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.705882, 0.772549, 0.792157)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_attach(root, world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-43.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.901961, 0.741176)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	_attach(root, sun)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


## A box mesh named `node_name`; with `solid`, a StaticBody3D child with the
## same box as its collision shape.
func _add_box(root: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	_attach(root, instance)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_body(root, instance, shape)


## The ramp: a right-angled prism rising toward +Z (south), with a convex
## collision shape through its six corners.
func _add_ramp(root: Node3D) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(RAMP_RUN, RAMP_RISE, RAMP_WIDTH)
	mesh.left_to_right = 1.0
	mesh.material = _material(Color(0.64, 0.6, 0.53))
	var instance := MeshInstance3D.new()
	instance.name = "Ground_Ramp"
	instance.mesh = mesh
	instance.position = RAMP_CENTER
	# The prism rises toward its local +X; turned so that +X points south (+Z).
	instance.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	_attach(root, instance)
	var half := mesh.size * 0.5
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, half.y, half.z),
	])
	_add_body(root, instance, shape)


func _add_body(root: Node3D, instance: MeshInstance3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = instance.name + "_col"
	body.collision_layer = 1
	body.collision_mask = 0
	instance.add_child(body)
	body.owner = root
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root


## One box occluder per building block (the walls are too low to hide much).
func _occluders() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Occluders"
	for building: String in BUILDINGS:
		var b: Array = BUILDINGS[building]
		var half := Vector3(b[2], b[3], b[4]) * 0.5
		var vertices := PackedVector3Array()
		for corner in 8:
			vertices.append(Vector3(half.x if corner & 1 else -half.x, half.y if corner & 2 else -half.y, half.z if corner & 4 else -half.z))
		# Two triangles per face, corners indexed by the bits above.
		var indices := PackedInt32Array([0, 2, 3, 0, 3, 1, 4, 5, 7, 4, 7, 6, 0, 1, 5, 0, 5, 4, 2, 6, 7, 2, 7, 3, 0, 4, 6, 0, 6, 2, 1, 3, 7, 1, 7, 5])
		var occluder := ArrayOccluder3D.new()
		occluder.set_arrays(vertices, indices)
		var instance := OccluderInstance3D.new()
		instance.name = building
		instance.occluder = occluder
		instance.position = Vector3(b[0], b[3] * 0.5, b[1])
		holder.add_child(instance)
		instance.owner = holder
	return holder


func _attach(root: Node3D, node: Node) -> void:
	root.add_child(node)
	node.owner = root


func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("could not save %s (%s)" % [path, error_string(error)])
		quit(1)
