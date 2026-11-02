extends SceneTree
## Composes the CC0 test town (Phase 6a): a 12 × 12 tile town of Kenney's
## "City Kit (Suburban)" 2.0 and "City Kit (Roads)" 2.2 pieces (CC0 1.0,
## www.kenney.nl), written as one GLB. The pieces keep Kenney's own scale (one
## road tile is 1 unit), so the import tool has to be told the map's scale,
## as it would for any model in other units; every piece keeps its Kenney
## name with its tile position. The layout is fixed (no randomness), so a run
## writes the same town every time.
##   godot --headless --path . --script res://tools/maps/kenney_town/compose_town.gd -- \
##       --suburban="<kit>/Models/GLB format" --roads="<kit>/Models/GLB format" --out=<town.glb>
## Sources, licence, and the expected output: docs/maps/imported/kenney_town_source.md.

## Roads run along these tile rows (constant z) and columns (constant x).
const ROAD_LINES := [3, 8]
const SIZE := 12
## Houses in reading order, one per lot.
const HOUSES := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u"]

var _kits := {}  # "suburban" / "roads" -> folder of its GLB models
var _pieces := {}  # piece name -> Mesh
var _materials := {}  # kit -> the one material its pieces share
var _root: Node3D
var _house := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	for key in ["suburban", "roads", "out"]:
		if not args.has(key):
			printerr("usage: --suburban=<dir> --roads=<dir> --out=<file.glb>")
			quit(2)
			return
	_kits = {"suburban": args.suburban, "roads": args.roads}
	_root = Node3D.new()
	_root.name = "kenney_town"
	for x in SIZE:
		for z in SIZE:
			_tile(x, z)
	_lots()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(_root, state)
	if error == OK:
		error = document.write_to_filesystem(state, args.out)
	print("COMPOSE %s nodes=%d error=%s" % [args.out, _root.get_child_count(), error_string(error)])
	_root.free()
	quit(0 if error == OK else 1)


func _is_road(i: int) -> bool:
	return i in ROAD_LINES


## The ground of a tile: a road piece on the road lines (a crossroad where
## they meet), a low tile elsewhere.
func _tile(x: int, z: int) -> void:
	var road_x := _is_road(x)
	var road_z := _is_road(z)
	if road_x and road_z:
		_place("roads", "road-crossroad", x, z, 0.0)
	elif road_x:
		_place("roads", "road-straight", x, z, 0.0)
	elif road_z:
		_place("roads", "road-straight", x, z, 90.0)
	else:
		_place("roads", "tile-low", x, z, 0.0)
	# A street light on every second road tile, at its edge.
	if (road_x != road_z) and (x + z) % 2 == 0:
		var side := Vector3(0.45, 0.0, 0.0) if road_x else Vector3(0.0, 0.0, 0.45)
		_place("roads", "light-square", x, z, 0.0 if road_x else 90.0, side)


## Houses on the lots beside the roads (every second tile, facing the road,
## set back from it), fences between them, trees inside the blocks.
func _lots() -> void:
	for x in SIZE:
		for z in SIZE:
			if _is_road(x) or _is_road(z):
				continue
			var toward := Vector2i.ZERO
			for line in ROAD_LINES:
				if x == line - 1:
					toward = Vector2i(1, 0)
				elif x == line + 1:
					toward = Vector2i(-1, 0)
				elif z == line - 1:
					toward = Vector2i(0, 1)
				elif z == line + 1:
					toward = Vector2i(0, -1)
			if toward != Vector2i.ZERO and (x + z) % 2 == 1:
				var yaw := rad_to_deg(atan2(float(toward.x), float(toward.y)))
				var setback := Vector3(-toward.x, 0.0, -toward.y) * 0.15
				_place("suburban", "building-type-%s" % HOUSES[_house % HOUSES.size()], x, z, yaw, setback)
				_house += 1
			elif toward != Vector2i.ZERO:
				_place("suburban", "fence-1x2", x, z, rad_to_deg(atan2(float(toward.x), float(toward.y))), Vector3(-toward.x, 0.0, -toward.y) * 0.3)
				_place("suburban", "tree-small", x, z, 0.0, Vector3(toward.x, 0.0, toward.y) * 0.2)
			elif (x * 7 + z * 3) % 4 == 0:
				_place("suburban", "tree-large", x, z, 0.0)


## A piece at tile (x, z), turned by `yaw` degrees, moved by `offset` tiles.
func _place(kit: String, piece: String, x: int, z: int, yaw: float, offset := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _mesh(kit, piece)
	node.name = "%s_%d_%d" % [piece, x, z]
	var n := 2
	while _root.has_node(NodePath(node.name)):
		node.name = "%s_%d_%d_%d" % [piece, x, z, n]
		n += 1
	node.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x + 0.5 - SIZE / 2.0, 0.0, z + 0.5 - SIZE / 2.0) + offset)
	_root.add_child(node)
	node.owner = _root


## The mesh of a Kenney piece, loaded once, with its kit's shared material.
func _mesh(kit: String, piece: String) -> Mesh:
	if _pieces.has(piece):
		return _pieces[piece]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(str(_kits[kit]).path_join(piece + ".glb"), state)
	assert(error == OK, "cannot load %s" % piece)
	var scene := document.generate_scene(state)
	var source := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	mesh.resource_name = piece
	for surface in mesh.get_surface_count():
		if not _materials.has(kit):
			_materials[kit] = mesh.surface_get_material(surface)
			(_materials[kit] as Material).resource_name = "colormap_" + kit
		mesh.surface_set_material(surface, _materials[kit])
	scene.free()
	_pieces[piece] = mesh
	return mesh
