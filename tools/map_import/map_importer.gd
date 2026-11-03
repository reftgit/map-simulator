extends RefCounted
## The import tool's pipeline (tools/import_map.gd; rules: docs/MAP_CONTRACT.md):
## loads a GLB, flattens it into one "Model" node with rigid transforms
## (scale and axis fixes baked into the meshes), fixes normals and vertex
## colours, checks the contract, puts every mesh into a render category,
## builds colliders and occluders, and records every check for the report.
## Works on a scene in memory too (process()), so tests can feed it small
## synthetic scenes.

const MapGeometry := preload("res://tools/map_import/map_geometry.gd")
const MapClassifier := preload("res://tools/map_import/map_classifier.gd")
const MapColliders := preload("res://tools/map_import/map_colliders.gd")
const MapUnits := preload("res://tools/map_import/map_units.gd")

## Configuration keys and their JSON types (docs/MAP_CONTRACT.md, "Configuration").
const CONFIG_KEYS := {
	"id": TYPE_STRING, "display_name": TYPE_STRING, "scale": TYPE_FLOAT, "up_axis": TYPE_STRING,
	"single_sided": TYPE_BOOL, "category_rules": TYPE_ARRAY, "category_rules_resource": TYPE_STRING,
	"use_default_name_rules": TYPE_BOOL, "default_category": TYPE_STRING, "colliders": -1,
	"spawn": TYPE_DICTIONARY, "vehicle_spawn": TYPE_DICTIONARY, "npc_route": TYPE_ARRAY,
}
## C2: horizontal extent of a map in metres, and the 90th-percentile mesh
## height outside which the scale is doubted.
const MIN_EXTENT := MapUnits.MIN_EXTENT
const MAX_EXTENT := MapUnits.MAX_EXTENT
const MIN_P90_HEIGHT := 1.5
const MAX_P90_HEIGHT := 300.0
## A mesh of at most this many triangles whose connected parts number at
## least MULTI_PARTS, spread over at least MULTI_SPREAD times the largest
## part's footprint, and mostly (MULTI_GROUNDED) stand on its lowest level
## holds several objects (one mesh for many buildings).
const PART_TRIANGLES := 50000
const MULTI_PARTS := 8
const MULTI_SPREAD := 4.0
const MULTI_GROUNDED := 0.75
## Only a mesh at least this wide both ways (m) is split for classification:
## an area of separate objects, not an object of several pieces.
const MULTI_AREA := 10.0
## C5: coordinates and vertical extent.
const MAX_DISTANCE := 20000.0
const MAX_HEIGHT := 2000.0
## C6: triangle budget.
const MAX_TRIANGLES := 10000000
const MOBILE_TRIANGLES := 2000000
## C7: building meshes checked for closed shells up to this many triangles;
## open when more than this share of edges is boundary; flipped normals warn above this share.
const SHELL_MAX_TRIANGLES := 50000
const OPEN_EDGES := 0.05
const FLIPPED_SHARE := 0.01
## C7: a mesh is closed when its area-weighted normals sum to at most this
## share of its area, and inside out when its volume is negative by more
## than what its remaining openness can explain plus INSIDE_OUT times its
## area to the power 1.5 (a doubled plane encloses nothing).
const CLOSED_SUM := 0.01
const INSIDE_OUT := 0.001
## R3: non-ground meshes wider than this.
const MAX_OBJECT := 150.0

var config := {}
## Contract checks in order: {"id", "result" (PASS, FIXED, WARN, FAIL, INFO), "message"}.
var checks: Array[Dictionary] = []
## Per mesh node of the model, by name: {"category", "by" (rule, vocabulary,
## shape, default, none), "triangles", "box" (AABB in the map)}.
var meshes := {}
## The processed model (a "Model" Node3D: meshes, colliders), not in the tree.
var model: Node3D
var rules: CategoryRules
var summary := {}
## Milliseconds per stage.
var timings := {}

var _stage_started := 0
var _collision_types := {}  # node name -> collider type from a collision suffix
var _missing_normals := 0
## Fixes the tool found by itself (C2, C3): a unit's scale and the file's up direction.
var _auto_scale := 1.0
var _auto_up := "+y"
var _up := {}  # MapUnits.detect_up() result, or the configuration's axis
var _unit := {}  # what the unit check found (C2)
var _stats_cache := {}  # [mesh id, basis] -> MapGeometry.stats()
var _inside_out := 0  # closed meshes turned outward (C7)


## Validates and keeps `data` (a parsed configuration JSON); "" or an error.
func parse_config(data: Dictionary) -> String:
	for key in data:
		if not CONFIG_KEYS.has(key):
			return "unknown configuration key '%s' (known: %s)" % [key, ", ".join(PackedStringArray(CONFIG_KEYS.keys()))]
		var expected: int = CONFIG_KEYS[key]
		var actual := typeof(data[key])
		if expected == TYPE_FLOAT and actual == TYPE_INT:
			continue
		if expected >= 0 and actual != expected:
			return "configuration key '%s' must be a %s" % [key, type_string(expected)]
	if data.has("up_axis") and not MapUnits.UP_AXES.has(data.up_axis):
		return "up_axis must be one of %s" % ", ".join(PackedStringArray(MapUnits.UP_AXES.keys()))
	if data.has("scale") and float(data.scale) <= 0.0:
		return "scale must be positive"
	if data.has("id") and not RegEx.create_from_string("^[a-z0-9_]+$").search(data.id):
		return "id must use only a-z, 0-9, and _"
	if data.has("colliders"):
		var colliders = data.colliders
		if colliders is String:
			if colliders != "auto":
				return "colliders must be \"auto\" or {category: type}"
		elif colliders is Dictionary:
			for category in colliders:
				if category not in CategoryRules.CATEGORIES or colliders[category] not in MapColliders.TYPES:
					return "colliders: '%s': '%s' (categories %s, types %s)" % [category, colliders[category], CategoryRules.CATEGORIES, MapColliders.TYPES]
		else:
			return "colliders must be \"auto\" or {category: type}"
	if data.has("default_category") and not str(data.default_category).is_empty() and data.default_category not in CategoryRules.CATEGORIES:
		return "unknown default_category '%s'" % data.default_category
	if data.has("category_rules"):
		var parsed := MapClassifier.rules_from_config(data.category_rules)
		if parsed.has("error"):
			return parsed.error
	if data.has("category_rules_resource") and not (load(data.category_rules_resource) is CategoryRules):
		return "category_rules_resource '%s' is not a CategoryRules resource" % data.category_rules_resource
	config = data
	return ""


## Loads a glTF file as a scene (C1); null when Godot cannot load it.
func load_glb(path: String) -> Node3D:
	_start()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		_check("C1", "FAIL", "%s is not a glTF 2.0 file Godot can load (error %d: %s)" % [path.get_file(), error, error_string(error)])
		return null
	var scene := document.generate_scene(state) as Node3D
	_stop("load")
	if scene == null:
		_check("C1", "FAIL", "%s is not a glTF 2.0 file Godot can load (no scene)" % path.get_file())
	return scene


## Runs the pipeline on `scene` (freed afterwards). Returns false when a
## mandatory check failed (the report says why); `force` goes on regardless.
func process(scene: Node3D, force := false) -> bool:
	_start()
	var instances := _collect(scene)
	_stop("collect")
	if instances.is_empty():
		_check("C1", "FAIL", "no triangle mesh in the file")
		scene.free()
		return false
	_check("C1", "PASS", "%d mesh nodes" % instances.size())
	_start()
	_flatten(instances)
	_fix_inside_out()
	_stop("fix")
	_start()
	_detect_up()
	if _detect_unit():
		_flatten(instances)
		_fix_inside_out()
	_stop("audit")
	scene.free()
	_start()
	if _missing_normals > 0:
		_check("R4", "FIXED", "%d meshes had no normals; flat normals computed from the triangles" % _missing_normals)
	else:
		_check("R4", "PASS", "every mesh has normals")
	_fix_materials()
	_stop("fix")
	_start()
	var ok := _audit_scale_and_axes()
	_stop("audit")
	if not ok and not force:
		return false
	_start()
	_classify()
	_stop("classify")
	_start()
	_check_shells()
	_stop("shells")
	_start()
	_build_colliders()
	_stop("colliders")
	return ok or force


## Bakes the occluders from the model's colliders (RenderSettings.build_occluders,
## shared vertices); the model must be in the tree.
func build_occluders() -> Node3D:
	_start()
	var holder := RenderSettings.build_occluders(model, rules.meshes_by_category(model), true, rules.occluder_categories)
	for child in holder.get_children():
		child.owner = holder
	var stats := RenderSettings.occluder_stats(holder)
	summary.occluders = stats.instances
	summary.occluder_triangles = stats.triangles
	_stop("occluders")
	return holder


## Whether any mandatory check failed.
func failed() -> bool:
	return checks.any(func(c: Dictionary) -> bool: return c.result == "FAIL")


func _collect(scene: Node3D) -> Array:
	var instances := []
	var removed := {"lights": 0, "cameras": 0, "animation players": 0, "skeletons": 0}
	var other_primitives := 0
	for node in scene.find_children("*", "", true, false):
		if node is Light3D:
			removed.lights += 1
		elif node is Camera3D:
			removed.cameras += 1
		elif node is AnimationPlayer:
			removed["animation players"] += 1
		elif node is Skeleton3D:
			removed.skeletons += 1
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mesh := (node as MeshInstance3D).mesh
			other_primitives += MapGeometry.other_primitives(mesh)
			if MapGeometry.triangle_surfaces(mesh).is_empty():
				continue
			instances.append([node, _relative_transform(node as Node3D, scene)])
	if other_primitives > 0:
		_check("C1", "WARN", "%d line or point surfaces skipped (only triangles are drawn and collide)" % other_primitives)
	var removed_text := PackedStringArray()
	for kind in removed:
		if removed[kind] > 0:
			removed_text.append("%d %s" % [removed[kind], kind])
	_check("R8", "INFO" if removed_text.is_empty() else "FIXED", "the model holds only meshes" if removed_text.is_empty() else "removed %s" % ", ".join(removed_text))
	return instances


static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent and parent != root:
		if parent is Node3D:
			transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform


## The scale and up-axis fix as a basis: the configuration's, else what the
## tool detected (C2, C3).
func fix_basis() -> Basis:
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * float(config.get("scale", _auto_scale)))
	var up: String = MapUnits.UP_AXES[config.up_axis] if config.has("up_axis") else _auto_up
	return MapUnits.TO_Y_UP[up] * basis


func _flatten(instances: Array) -> void:
	if model:
		model.free()
	model = Node3D.new()
	model.name = "Model"
	_collision_types.clear()
	_stats_cache.clear()
	var fix := Transform3D(fix_basis(), Vector3.ZERO)
	var baked := {}  # [mesh id, basis] -> mesh with that basis applied
	var flattened := {}  # mesh id -> mesh with flat normals
	_missing_normals = 0
	var fixed_meshes := {}
	var names := {}
	for entry: Array in instances:
		var source: MeshInstance3D = entry[0]
		var placed: Transform3D = fix * (entry[1] as Transform3D)
		var mesh := source.mesh
		var basis := placed.basis
		var rotation := basis.orthonormalized()
		if basis.determinant() < 0.0:
			rotation = Basis.IDENTITY
		var rest := _snapped(rotation.inverse() * basis)
		if not rest.is_equal_approx(Basis.IDENTITY):
			var key := [mesh.get_instance_id(), rest]
			if not baked.has(key):
				baked[key] = MapGeometry.transformed(mesh, rest)
			mesh = baked[key]
		else:
			rotation = basis
		if not MapGeometry.has_normals(mesh):
			if not flattened.has(mesh.get_instance_id()):
				flattened[mesh.get_instance_id()] = MapGeometry.with_flat_normals(mesh)
				_missing_normals += 1
			mesh = flattened[mesh.get_instance_id()]
		fixed_meshes[mesh] = true
		var node := MeshInstance3D.new()
		var node_name := str(source.name)
		var suffix := MapColliders.suffix_of(node_name)
		node_name = node_name.trim_suffix(suffix)
		node.name = _unique(node_name, names)
		if not suffix.is_empty():
			_collision_types[str(node.name)] = MapColliders.SUFFIXES[suffix] if not suffix.ends_with("only") else "only_" + MapColliders.SUFFIXES[suffix]
		node.mesh = mesh
		node.transform = Transform3D(rotation, placed.origin)
		for surface in source.get_surface_override_material_count():
			if source.get_surface_override_material(surface) and surface < mesh.get_surface_count():
				node.set_surface_override_material(surface, source.get_surface_override_material(surface))
		model.add_child(node)
		node.owner = model
	summary.mesh_nodes = model.get_child_count()
	summary.meshes = fixed_meshes.size()
	summary.baked_meshes = baked.size()


## `basis` with its components rounded to 10⁻⁵, so the same scale under
## different rotations bakes one mesh.
static func _snapped(basis: Basis) -> Basis:
	return Basis(basis.x.snapped(Vector3.ONE * 1e-5), basis.y.snapped(Vector3.ONE * 1e-5), basis.z.snapped(Vector3.ONE * 1e-5))


static func _unique(node_name: String, names: Dictionary) -> String:
	if node_name.is_empty():
		node_name = "Mesh"
	var unique := node_name
	var n := 2
	while names.has(unique):
		unique = "%s_%d" % [node_name, n]
		n += 1
	names[unique] = true
	return unique


## R5 (vertex colours on white untextured materials) and R6 (double-sided).
func _fix_materials() -> void:
	var materials := {}  # material -> whether a surface using it has colours
	for node: MeshInstance3D in model.get_children():
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface)
			if material == null:
				continue
			var arrays := node.mesh.surface_get_arrays(surface)
			var colored: bool = arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0
			materials[material] = materials.get(material, false) or colored
	summary.materials = materials.size()
	var shown := 0
	var white := 0
	var double_sided := 0
	var single_sided: bool = config.get("single_sided", false)
	for material: Material in materials:
		var base := material as BaseMaterial3D
		if base == null:
			continue
		var plain_white := base.albedo_texture == null and base.albedo_color.is_equal_approx(Color.WHITE) and not base.vertex_color_use_as_albedo
		if plain_white and materials[material]:
			base.vertex_color_use_as_albedo = true
			shown += 1
		elif plain_white:
			white += 1
		if base.cull_mode == BaseMaterial3D.CULL_DISABLED:
			double_sided += 1
			if single_sided:
				base.cull_mode = BaseMaterial3D.CULL_BACK
	if shown > 0:
		_check("R5", "FIXED", "%d materials show their vertex colours now" % shown)
	if white > 0:
		_check("R5", "WARN", "%d white untextured materials without vertex colours render white" % white)
	if shown == 0 and white == 0:
		_check("R5", "PASS", "colour from textures, material colours, or vertex colours")
	if double_sided == 0:
		_check("R6", "PASS", "every material is single-sided")
	elif single_sided:
		_check("R6", "FIXED", "%d double-sided materials made single-sided (\"single_sided\": true)" % double_sided)
	else:
		_check("R6", "WARN", "%d double-sided materials: back faces are drawn too (fill-rate cost on mobile). Set \"single_sided\": true if the shells are closed (C7)." % double_sided)


## Face statistics of a mesh node as placed (cached per mesh and rotation).
func _node_stats(node: MeshInstance3D) -> Dictionary:
	var key := [node.mesh.get_instance_id(), node.transform.basis]
	if not _stats_cache.has(key):
		_stats_cache[key] = MapGeometry.stats(node.mesh, node.transform.basis)
	return _stats_cache[key]


## The box of all meshes as placed.
func _model_box() -> AABB:
	var total := AABB()
	var first := true
	for node: MeshInstance3D in model.get_children():
		var box: AABB = node.transform * node.mesh.get_aabb()
		total = box if first else total.merge(box)
		first = false
	return total


## The area facing each axis direction over the whole model, with the
## area-weighted coordinates in the model's space (MapUnits.detect_up()).
func _face_totals() -> Dictionary:
	var totals := {}
	for node: MeshInstance3D in model.get_children():
		var stats := _node_stats(node)
		for direction: String in ["+x", "-x", "+y", "-y", "+z", "-z"]:
			var axis := "xyz".find(direction[1])
			totals[direction] = totals.get(direction, 0.0) + stats[direction]
			totals["at_" + direction] = totals.get("at_" + direction, 0.0) + stats["at_" + direction] + stats[direction] * node.position[axis]
	return totals


## C3: which way is up: the configuration's axis, else detected from the
## model as the file's nodes place it. A detected direction other than +Y
## turns every node rigidly so that it points up (nothing is rebaked).
func _detect_up() -> void:
	if config.has("up_axis"):
		_up = {"up": MapUnits.UP_AXES[config.up_axis], "decided": true, "configured": true}
		if config.up_axis == "y":
			_up.measured = MapUnits.detect_up(_model_box().size, _face_totals())
		return
	var box := _model_box()
	var faces := _face_totals()
	_up = MapUnits.detect_up(box.size, faces)
	if _up.axis != "" and (_up.up != "+y" or _up.winding != "+"):
		# Before turning the model, or when the faces alone cannot tell: where its base is.
		_up = MapUnits.detect_up(box.size, faces, _flat_area_at_ends("xyz".find(_up.axis)))
	if _up.decided and _up.up != "+y":
		_auto_up = _up.up
		var turn := Transform3D(MapUnits.TO_Y_UP[_auto_up], Vector3.ZERO)
		for node: Node3D in model.get_children():
			node.transform = turn * node.transform


## Flat face area (within 30° of the axis, either side) in the lowest and the
## highest MapUnits.END_BAND of the model along `axis` (0 x, 1 y, 2 z): a
## map's ground or a printed relief's underside gathers at its low end.
func _flat_area_at_ends(axis: int) -> Vector2:
	var box := _model_box()
	var band: float = box.size[axis] * MapUnits.END_BAND
	var low_limit: float = box.position[axis] + band
	var high_limit: float = box.end[axis] - band
	var ends := Vector2.ZERO
	for node: MeshInstance3D in model.get_children():
		var placed: AABB = node.transform * node.mesh.get_aabb()
		if placed.position[axis] > low_limit and placed.end[axis] < high_limit:
			continue
		for surface: Array in MapGeometry.triangle_surfaces(node.mesh):
			var positions: PackedVector3Array = surface[0]
			var indices = surface[2]
			var count: int = (indices as PackedInt32Array).size() if indices != null else positions.size()
			for t in range(0, count - 2, 3):
				var a := node.transform * positions[indices[t] if indices != null else t]
				var b := node.transform * positions[indices[t + 1] if indices != null else t + 1]
				var c := node.transform * positions[indices[t + 2] if indices != null else t + 2]
				var face := (c - a).cross(b - a)
				var double_area := face.length()
				if double_area <= 0.0 or absf(face[axis]) < MapGeometry.COS_30 * double_area:
					continue
				var at := (a[axis] + b[axis] + c[axis]) / 3.0
				if at <= low_limit:
					ends.x += double_area * 0.5
				elif at >= high_limit:
					ends.y += double_area * 0.5
	return ends


## C7: a closed mesh whose faces point inward (negative volume) is turned
## outward: its winding reversed, and its normals as well, unless the file's
## normals already pointed out (then only the winding was wrong).
func _fix_inside_out() -> void:
	var turned := {}  # mesh id -> the mesh turned outward
	for node: MeshInstance3D in model.get_children():
		var stats := _node_stats(node)
		var id := node.mesh.get_instance_id()
		if not turned.has(id) and not inside_out(stats, node.mesh):
			continue
		if not turned.has(id):
			turned[id] = MapGeometry.turned_out(node.mesh, stats.flipped <= stats.triangles / 2)
		node.mesh = turned[id]
	_inside_out = turned.size()


## Whether `mesh` (with these statistics, MapGeometry.stats()) is closed
## and inside out (C7): its normals cancel out, its volume is clearly
## negative, and, welded, it has (almost) no boundary edges; the last test
## runs only on the few meshes that pass the first two (two discs facing
## away from each other also cancel out and enclose a "volume").
static func inside_out(stats: Dictionary, mesh: Mesh) -> bool:
	var area: float = stats.area
	var open_sum := (stats.normal_sum as Vector3).length()
	if area <= 0.0 or open_sum > CLOSED_SUM * area:
		return false
	if stats.volume >= -(open_sum * mesh.get_aabb().size.length() / 6.0 + INSIDE_OUT * pow(area, 1.5)):
		return false
	var shell := MapGeometry.shell(mesh)
	return shell.edges > 0 and shell.boundary <= CLOSED_SUM * shell.edges and shell.volume < 0.0


## C2: when the model does not look like metres (a map-sized extent, its
## 90th-percentile mesh between 1.5 and 300 m high), measures its separate
## objects and tries the common units; a unit that clearly fits becomes the
## scale. True when it did (the model must be flattened again).
func _detect_unit() -> bool:
	_unit = {}
	var box := _model_box()
	var extent := maxf(box.size.x, box.size.z)
	var p90 := _p90_height()
	var out_of_range := extent < MIN_EXTENT or extent > MAX_EXTENT
	if not out_of_range and p90 >= MIN_P90_HEIGHT and p90 <= MAX_P90_HEIGHT:
		return false
	var typical := _typical_sizes(extent)
	_unit = {"extent": extent, "typical": typical, "suggestion": MapUnits.suggest_scale(typical.height, typical.width)}
	if config.has("scale"):
		return false
	var unit := MapUnits.unit_of(extent, typical.height)
	if unit.has("factor"):
		_unit.unit = unit
		_auto_scale = unit.factor
		return true
	if unit.has("choices"):
		_unit.choices = unit.choices
	return false


func _p90_height() -> float:
	var heights := PackedFloat32Array()
	for node: MeshInstance3D in model.get_children():
		heights.append((node.transform * node.mesh.get_aabb()).size.y)
	heights.sort()
	return heights[ceili(0.9 * heights.size()) - 1] if not heights.is_empty() else 0.0


## Height and width (75th percentiles) of the model's separate objects: a
## mesh, or each connected part of a mesh that holds several objects; flat
## pieces (less than a tenth as high as wide) and ground-sized ones (wider
## than half the map) are left out.
func _typical_sizes(extent: float) -> Dictionary:
	var heights := PackedFloat32Array()
	var widths := PackedFloat32Array()
	for node: MeshInstance3D in model.get_children():
		for box: AABB in _objects_of(node):
			var wide := maxf(box.size.x, box.size.z)
			if box.size.y < 0.1 * wide or wide > 0.5 * extent:
				continue
			heights.append(box.size.y)
			widths.append(wide)
	if heights.is_empty():
		return {"height": _p90_height(), "width": 0.0, "objects": 0}
	heights.sort()
	widths.sort()
	var at := ceili(0.75 * heights.size()) - 1
	return {"height": heights[at], "width": widths[at], "objects": heights.size()}


## The boxes in the model of the objects in a mesh node: its connected parts
## when it holds several objects (multi_parts()), else the mesh as a whole.
func _objects_of(node: MeshInstance3D) -> Array[AABB]:
	var boxes: Array[AABB] = []
	var parts := multi_parts(node.mesh, node.transform.basis)
	if parts.is_empty():
		boxes.append(node.transform * node.mesh.get_aabb())
	for points: PackedVector3Array in parts:
		var box := AABB(node.transform * points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(node.transform * point)
		boxes.append(box)
	return boxes


## The connected parts (point lists) of a mesh that holds several separate
## objects standing side by side, the whole city in one mesh for example: at
## most PART_TRIANGLES triangles, at least MULTI_PARTS parts spread over at
## least MULTI_SPREAD times the largest part's footprint, and at least
## MULTI_GROUNDED of them standing on the mesh's lowest level (placed with
## `basis`), the whole at least `min_narrow` wide both ways. [] for any
## other mesh, among them the pieces of one object: the beams of a timber
## frame sit at many heights, a fence's posts and rails along a line.
static func multi_parts(mesh: Mesh, basis := Basis.IDENTITY, min_narrow := 0.0) -> Array[PackedVector3Array]:
	var none: Array[PackedVector3Array] = []
	if MapGeometry.triangle_count(mesh) > PART_TRIANGLES:
		return none
	var parts := MapGeometry.parts(mesh)
	if parts.size() < MULTI_PARTS:
		return none
	var largest := 0.0
	var bottoms := PackedFloat32Array()
	var whole := AABB()
	for i in parts.size():
		var box := AABB(basis * parts[i][0], Vector3.ZERO)
		for point in parts[i]:
			box = box.expand(basis * point)
		largest = maxf(largest, maxf(box.size.x, 0.01) * maxf(box.size.z, 0.01))
		bottoms.append(box.position.y)
		whole = box if i == 0 else whole.merge(box)
	if whole.size.x * whole.size.z < MULTI_SPREAD * largest or minf(whole.size.x, whole.size.z) < min_narrow:
		return none
	var tolerance := maxf(0.05 * whole.size.y, 1e-4)
	var grounded := 0
	for bottom in bottoms:
		if bottom <= whole.position.y + tolerance:
			grounded += 1
	if grounded < MULTI_GROUNDED * parts.size():
		return none
	return parts


## C2, C3, C5, C6 from the meshes as placed; also fills `meshes` with each
## node's box, triangles, and face statistics. False when C2 or C5 failed or
## C6's limit is exceeded.
func _audit_scale_and_axes() -> bool:
	var total := AABB()
	var first := true
	var triangles := 0
	var zero_area := 0
	var flipped := 0
	var farthest := 0.0
	var faces := _face_totals()
	for node: MeshInstance3D in model.get_children():
		var stats := _node_stats(node)
		var box: AABB = node.transform * node.mesh.get_aabb()
		meshes[str(node.name)] = {"category": "", "by": "none", "triangles": stats.triangles, "box": box, "stats": stats}
		total = box if first else total.merge(box)
		first = false
		triangles += stats.triangles
		zero_area += stats.zero_area
		flipped += stats.flipped
		for corner in 8:
			farthest = maxf(farthest, box.get_endpoint(corner).length())
	summary.triangles = triangles
	summary.zero_area = zero_area
	summary.flipped = flipped
	summary.bounds = total
	var p90 := _p90_height()
	summary.p90_height = p90
	var extent := maxf(total.size.x, total.size.z)
	var configured_scale := float(config.get("scale", 1.0))
	var ok := true
	if extent < MIN_EXTENT or extent > MAX_EXTENT:
		var message := "the model spans %.1f × %.1f units; with 1 unit = 1 m that is not a map." % [total.size.x, total.size.z]
		var typical: Dictionary = _unit.get("typical", {"height": p90, "width": 0.0, "objects": 0})
		var suggested := float(_unit.get("suggestion", 1.0))
		if _unit.has("choices"):
			message += " It looks like %s: set \"scale\" in the configuration to the one it is in." % " or ".join(PackedStringArray(_unit.choices))
		else:
			message += " If it is in other units, set \"scale\" in the configuration (suggested: %s, which makes its typical object, the 75th percentile of %d separate objects, %.1f m tall and %.1f m wide)." % [
					_number(suggested * configured_scale), typical.objects, typical.height * suggested, typical.width * suggested]
		_check("C2", "FAIL", message)
		ok = false
	elif _unit.has("unit"):
		_check("C2", "FIXED", "the model looks like it is in %s (%.0f units wide, its typical object %.0f units tall): scaled by %s to %.0f × %.0f m (\"scale\" in the configuration overrides this)" % [
				_unit.unit.name, _unit.extent, _unit.typical.height, _number(_unit.unit.factor), total.size.x, total.size.z])
	elif config.has("scale") and not is_equal_approx(configured_scale, 1.0):
		_check("C2", "FIXED", "scaled by %s (configuration; baked into %d meshes, the nodes keep rotation and position): %.0f × %.0f m, typical object (90th percentile) %.1f m tall" % [_number(configured_scale), summary.baked_meshes, total.size.x, total.size.z, p90])
	else:
		_check("C2", "PASS", "%.0f × %.0f × %.0f m; typical object (90th-percentile height) %.1f m" % [total.size.x, total.size.z, total.size.y, p90])
	if ok and (p90 < MIN_P90_HEIGHT or p90 > MAX_P90_HEIGHT):
		var hint := " (it may be in %s)" % " or ".join(PackedStringArray(_unit.choices)) if _unit.has("choices") else ""
		_check("C2", "WARN", "the 90th-percentile mesh height is %.2f m (expected %.1f–%.0f m): check the units%s" % [p90, MIN_P90_HEIGHT, MAX_P90_HEIGHT, hint])
	summary.up = _up
	if _up.get("configured", false):
		var measured: Dictionary = _up.get("measured", {})
		if _up.up != "+y":
			_check("C3", "FIXED", "rotated from %s up to +Y up (configuration)" % _up.up.to_upper())
		elif measured.get("decided", false) and measured.up != "+y":
			_check("C3", "WARN", "the configuration keeps +Y up, but the model looks %s up: %s" % [measured.up.to_upper(), measured.reason])
		else:
			_check("C3", "PASS", "+Y up (configuration)")
	elif not _up.decided:
		_check("C3", "WARN", "%s; the file's +Y is taken as up. Set \"up_axis\" in the configuration if that is wrong." % _up.reason)
	elif _up.up != "+y":
		_check("C3", "FIXED", "the model is %s up: %s. Rotated to +Y up (\"up_axis\": \"y\" in the configuration keeps the file's axes)." % [_up.up.to_upper(), _up.reason])
	else:
		_check("C3", "PASS", "+Y up: %s" % _up.reason)
	if farthest > MAX_DISTANCE:
		_check("C5", "FAIL", "geometry reaches %.0f m from the origin (limit 20 km). Move the model's origin into the map." % farthest)
		ok = false
	elif total.size.y > MAX_HEIGHT:
		_check("C5", "FAIL", "the model spans %.0f m vertically (limit 2 km)" % total.size.y)
		ok = false
	else:
		_check("C5", "PASS", "within %.0f m of the origin, %.0f m high" % [farthest, total.size.y])
	if triangles > MAX_TRIANGLES:
		_check("C6", "FAIL", "%d triangles (limit 10,000,000)" % triangles)
		ok = false
	elif triangles > MOBILE_TRIANGLES:
		_check("C6", "WARN", "%d triangles, above the 2,000,000 mobile budget: the low profile hides only categorized meshes beyond 100 m; lighter geometry or more meshes in visibility-range categories would help." % triangles)
	else:
		_check("C6", "PASS", "%d triangles" % triangles)
	summary.faces = faces
	return ok


## Every mesh into a category: the configuration's rules (or rules resource),
## the vocabulary, then the shape rules (C4's ground depends on it; R1, R3, R7).
func _classify() -> void:
	rules = CategoryRules.new()
	var configured: Array[CategoryRule] = []
	if config.has("category_rules_resource"):
		var resource := load(config.category_rules_resource) as CategoryRules
		configured.append_array(resource.rules)
		rules.occluder_categories = resource.occluder_categories.duplicate()
	if config.has("category_rules"):
		configured.append_array(MapClassifier.rules_from_config(config.category_rules).rules)
	var vocabulary: Array[CategoryRule] = []
	if config.get("use_default_name_rules", true):
		vocabulary = MapClassifier.vocabulary_rules()
	rules.rules.append_array(configured)
	rules.rules.append_array(vocabulary)
	rules.rules.append_array(MapClassifier.group_rules())
	rules.default_category = config.get("default_category", "")
	summary.rule_counts = {"configured": configured.size(), "vocabulary": vocabulary.size()}
	var by_counts := {"rule": 0, "vocabulary": 0, "shape": 0, "default": 0, "none": 0}
	var shape_counts := {}
	var unclassified: Array[String] = []
	# Names first; a mesh no name matches that holds several separate objects
	# is split into one mesh per object before its shape is judged (R3).
	var by_name := {}
	var split: Array[String] = []
	for node: MeshInstance3D in model.get_children().duplicate():
		var category := _first_match(configured, node)
		var by := "rule"
		if category.is_empty():
			category = _first_match(vocabulary, node)
			by = "vocabulary"
		if not category.is_empty():
			by_name[str(node.name)] = [category, by]
		elif not _collision_types.has(str(node.name)) and not multi_parts(node.mesh, node.transform.basis, MULTI_AREA).is_empty():
			split.append("%s (%d)" % [node.name, _split(node)])
	var repeats := {}
	for node: MeshInstance3D in model.get_children():
		var record: Dictionary = meshes[str(node.name)]
		var key := MapClassifier.shape_key(record.triangles, record.box)
		repeats[key] = repeats.get(key, 0) + 1
	var by_shape_nodes: Array[MeshInstance3D] = []
	for node: MeshInstance3D in model.get_children():
		var record: Dictionary = meshes[str(node.name)]
		if by_name.has(str(node.name)):
			record.category = by_name[str(node.name)][0]
			record.by = by_name[str(node.name)][1]
			continue
		record.profile = MapGeometry.profile(node.mesh, node.transform)
		record.category = MapClassifier.category_by_shape(record.box, record.stats, record.profile, repeats[MapClassifier.shape_key(record.triangles, record.box)])
		record.by = "shape"
		by_shape_nodes.append(node)
	summary.attached = _attachments(by_shape_nodes)
	for node: MeshInstance3D in model.get_children():
		var record: Dictionary = meshes[str(node.name)]
		if record.by == "shape" and not record.category.is_empty():
			node.add_to_group(MapClassifier.GROUP_PREFIX + record.category, true)
			shape_counts[record.category] = shape_counts.get(record.category, 0) + 1
		if record.category.is_empty():
			record.category = rules.default_category
			record.by = "default" if not record.category.is_empty() else "none"
			if record.category.is_empty():
				unclassified.append(str(node.name))
		by_counts[record.by] += 1
	summary.split = split
	summary.classified_by = by_counts
	var by_shape: int = by_counts.shape + by_counts.default + by_counts.none
	if by_shape == 0:
		_check("R1", "PASS", "every mesh matched a name rule (%d configured, %d vocabulary)" % [by_counts.rule, by_counts.vocabulary])
	else:
		var message := "%d meshes matched no name rule and were classified by their shape (%s)" % [by_shape, _counts_text(shape_counts)]
		if not unclassified.is_empty():
			message += "; %d are in no category: %s" % [unclassified.size(), _list(unclassified)]
		_check("R1", "WARN", message)
	var categories := {}
	for record: Dictionary in meshes.values():
		categories[record.category] = categories.get(record.category, 0) + 1
	_check("R7", "INFO", "%d water meshes" % categories.get("water", 0))
	var wide: Array[String] = []
	for node_name: String in meshes:
		var record: Dictionary = meshes[node_name]
		if record.category != "ground" and maxf(record.box.size.x, record.box.size.z) > MAX_OBJECT:
			wide.append(node_name)
	if not split.is_empty():
		_check("R3", "FIXED", "%d meshes no name rule matched held several separate objects and were split into one mesh per object: %s" % [split.size(), _list(split)])
	if wide.is_empty():
		_check("R3", "PASS", "no non-ground mesh is wider than %.0f m" % MAX_OBJECT)
	else:
		_check("R3", "WARN", "%d non-ground meshes are wider than %.0f m (%s): visibility ranges and occlusion work per mesh, so they are drawn whole or not at all." % [wide.size(), MAX_OBJECT, _list(wide)])


## A second look at the meshes classified by shape that sit on a building
## (inside its box with 1 m around it): one made of many thin pieces (at
## least 4 parts, three quarters of them at most 0.4 m thick) within the
## building's height is its facade detail (windows, timber, frames); a cover
## (its upward faces covering half its footprint) above the building's lower
## half is its roof. Returns how many became which.
func _attachments(nodes: Array[MeshInstance3D]) -> Dictionary:
	var changed := {"facade_detail": 0, "roof": 0}
	var buildings: Array[Dictionary] = []
	for record: Dictionary in meshes.values():
		if record.category == "buildings":
			buildings.append(record)
	for node in nodes:
		var record: Dictionary = meshes[str(node.name)]
		if record.category in ["ground", "trees", "water"]:
			continue
		var box: AABB = record.box
		for building in buildings:
			if building == record:
				continue
			var around: AABB = (building.box as AABB).grow(1.0)
			if box.position.x < around.position.x or box.end.x > around.end.x or box.position.z < around.position.z or box.end.z > around.end.z:
				continue
			var base: AABB = building.box
			var cover: float = float(record.stats.cover) / maxf(box.size.x * box.size.z, 1e-6)
			if cover >= 0.5 and box.position.y >= base.position.y + 0.5 * base.size.y and box.end.y <= base.end.y + 10.0:
				record.category = "buildings"
				changed.roof += 1
				break
			if box.position.y >= around.position.y and box.end.y <= around.end.y and _thin_pieces(node.mesh):
				record.category = "facade_detail"
				changed.facade_detail += 1
				break
	return changed


## Whether a mesh is made of many thin pieces (at least 4 connected parts,
## three quarters of them at most 0.4 m thick).
static func _thin_pieces(mesh: Mesh) -> bool:
	var parts := MapGeometry.parts(mesh)
	if parts.size() < 4:
		return false
	var thin := 0
	for points in parts:
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		if box.get_shortest_axis_size() <= 0.4:
			thin += 1
	return thin >= 0.75 * parts.size()


## Replaces a mesh node that holds several objects by one node per connected
## part (named "<name>_000" …, same transform and materials), each with its
## own record; returns the number of parts.
func _split(node: MeshInstance3D) -> int:
	var node_name := str(node.name)
	var index := node.get_index()
	var pieces := MapGeometry.part_meshes(node.mesh)
	var names := {}
	for child in model.get_children():
		names[str(child.name)] = true
	var digits := maxi(3, str(pieces.size() - 1).length())
	for i in pieces.size():
		var part := MeshInstance3D.new()
		part.name = _unique("%s_%0*d" % [node_name, digits, i], names)
		part.mesh = pieces[i]
		part.transform = node.transform
		model.add_child(part)
		model.move_child(part, index + i)
		part.owner = model
		var stats := _node_stats(part)
		meshes[str(part.name)] = {"category": "", "by": "none", "triangles": stats.triangles, "box": part.transform * part.mesh.get_aabb(), "stats": stats, "split_from": node_name}
	meshes.erase(node_name)
	model.remove_child(node)
	node.free()
	summary.mesh_nodes = model.get_child_count()
	return pieces.size()


static func _first_match(list: Array[CategoryRule], node: Node) -> String:
	for rule in list:
		if rule.matches(node, str(node.name)):
			return rule.category
	return ""


## C7 on the building meshes (closed, outward) and the totals of flipped and
## zero-area triangles.
func _check_shells() -> void:
	var open: Array[String] = []
	var checked := 0
	var buildings := 0
	var seen := {}
	for node: MeshInstance3D in model.get_children():
		var record: Dictionary = meshes[str(node.name)]
		if record.category != "buildings":
			continue
		buildings += 1
		if record.triangles > SHELL_MAX_TRIANGLES:
			continue
		if not seen.has(node.mesh):
			seen[node.mesh] = MapGeometry.shell(node.mesh)
		var shell: Dictionary = seen[node.mesh]
		checked += 1
		if shell.edges > 0 and float(shell.boundary) / shell.edges > OPEN_EDGES:
			open.append(str(node.name))
	summary.shells = {"buildings": buildings, "checked": checked, "open": open.size(), "inside_out": _inside_out}
	var problems := 0
	if _inside_out > 0:
		_check("C7", "FIXED", "%d closed meshes were inside out (their faces pointed in, so their outside was not drawn): turned outward" % _inside_out)
		problems += 1
	if not open.is_empty():
		var colliders = config.get("colliders", {})
		var building_type: String = colliders.get("buildings", "convex") if colliders is Dictionary else "convex"
		var hull := ", and their convex colliders fill the hull" if _collision_types.is_empty() and building_type == "convex" else ""
		_check("C7", "WARN", "%d of %d building meshes are open (more than 5 %% boundary edges), e.g. %s: open walls show holes where back faces are culled%s." % [open.size(), checked, _list(open), hull])
		problems += 1
	if summary.flipped > FLIPPED_SHARE * summary.triangles:
		_check("C7", "WARN", "%d triangles disagree with their normals" % summary.flipped)
		problems += 1
	if summary.zero_area > 0:
		_check("C7", "WARN", "%d zero-area triangles" % summary.zero_area)
		problems += 1
	if problems == 0:
		_check("C7", "PASS", "%d of %d building meshes checked: closed and outward; no zero-area triangles" % [checked, buildings])


## R2: colliders from collision nodes, or per category.
func _build_colliders() -> void:
	var types: Dictionary = MapColliders.DEFAULT_TYPES.duplicate()
	var colliders = config.get("colliders", {})
	if colliders is Dictionary:
		types.merge(colliders, true)
	var use_nodes := not _collision_types.is_empty()
	var add_categories: bool = not use_nodes or colliders is String
	var totals := {"bodies": 0, "shapes": 0, "trimesh_triangles": 0, "skipped": 0}
	var by_type := {}
	var only := 0
	for node: MeshInstance3D in model.get_children().duplicate():
		var node_name := str(node.name)
		var type := ""
		if _collision_types.has(node_name):
			type = _collision_types[node_name]
		elif add_categories:
			type = types.get(meshes[node_name].category, "none")
		if type.is_empty() or type == "none":
			continue
		var collision_only := type.begins_with("only_")
		type = type.trim_prefix("only_")
		var result := MapColliders.add_collider(node, type, model)
		if result.shapes > 0:
			totals.bodies += 1
			totals.shapes += result.shapes
			totals.trimesh_triangles += result.triangles
			by_type[type] = by_type.get(type, 0) + result.shapes
		totals.skipped += result.skipped
		if collision_only:
			_replace_with_body(node)
			only += 1
	summary.colliders = totals
	summary.collider_types = by_type
	var text := "%d bodies, %d shapes (%s), %d trimesh triangles" % [totals.bodies, totals.shapes, _counts_text(by_type), totals.trimesh_triangles]
	if totals.skipped > 0:
		text += "; %d parts too small or flat for a collider" % totals.skipped
	if use_nodes:
		_check("R2", "PASS", "%d collision nodes used%s: %s" % [_collision_types.size(), " (and category colliders, \"colliders\": \"auto\")" if add_categories else "", text])
	else:
		_check("R2", "INFO", "no collision nodes; colliders generated from the categories: %s" % text)
	if only > 0:
		_check("R2", "INFO", "%d collision-only nodes keep their collider without a mesh (no occluders from them)" % only)


## A -colonly node: its body stays, its mesh goes (as Godot's GLB import does).
func _replace_with_body(node: MeshInstance3D) -> void:
	var holder := Node3D.new()
	holder.transform = node.transform
	var node_name := node.name
	var body := node.get_node("StaticBody3D")
	node.remove_child(body)
	model.remove_child(node)
	node.free()
	holder.name = node_name
	model.add_child(holder)
	holder.owner = model
	holder.add_child(body)
	_set_owner(body, model)
	meshes.erase(str(node_name))


static func _set_owner(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner(child, owner)


func _check(id: String, result: String, message: String) -> void:
	checks.append({"id": id, "result": result, "message": message})


func _start() -> void:
	_stage_started = Time.get_ticks_msec()


func _stop(stage: String) -> void:
	var ms := Time.get_ticks_msec() - _stage_started
	timings[stage] = timings.get(stage, 0) + ms
	print("IMPORT stage %s %d ms" % [stage, ms])


static func _counts_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in counts:
		parts.append("%s %d" % [key, counts[key]])
	return ", ".join(parts) if not parts.is_empty() else "none"


static func _list(names: Array[String], limit := 8) -> String:
	var shown := ", ".join(PackedStringArray(names.slice(0, limit)))
	return shown + (", …" if names.size() > limit else "")


static func _number(value: float) -> String:
	return str(snappedf(value, 0.001)).trim_suffix(".0")
