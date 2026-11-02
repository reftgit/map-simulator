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

## Configuration keys and their JSON types (docs/MAP_CONTRACT.md, "Configuration").
const CONFIG_KEYS := {
	"id": TYPE_STRING, "display_name": TYPE_STRING, "scale": TYPE_FLOAT, "up_axis": TYPE_STRING,
	"single_sided": TYPE_BOOL, "category_rules": TYPE_ARRAY, "category_rules_resource": TYPE_STRING,
	"use_default_name_rules": TYPE_BOOL, "default_category": TYPE_STRING, "colliders": -1,
	"spawn": TYPE_DICTIONARY, "vehicle_spawn": TYPE_DICTIONARY, "npc_route": TYPE_ARRAY,
}
## C2: horizontal extent of a map in metres, and the 90th-percentile mesh
## height outside which the scale is doubted.
const MIN_EXTENT := 20.0
const MAX_EXTENT := 10000.0
const TYPICAL_HEIGHT := 8.0
const MIN_P90_HEIGHT := 1.5
const MAX_P90_HEIGHT := 300.0
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
	if data.has("up_axis") and data.up_axis not in ["y", "z"]:
		return "up_axis must be \"y\" or \"z\""
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
	scene.free()
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


## The configuration's scale and up-axis fix as a basis.
func fix_basis() -> Basis:
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * float(config.get("scale", 1.0)))
	if config.get("up_axis", "y") == "z":
		basis = Basis(Vector3.RIGHT, -PI / 2.0) * basis
	return basis


func _flatten(instances: Array) -> void:
	model = Node3D.new()
	model.name = "Model"
	var fix := Transform3D(fix_basis(), Vector3.ZERO)
	var baked := {}  # [mesh id, basis] -> mesh with that basis applied
	var flattened := {}  # mesh id -> mesh with flat normals
	var missing_normals := 0
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
				missing_normals += 1
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
	if missing_normals > 0:
		_check("R4", "FIXED", "%d meshes had no normals; flat normals computed from the triangles" % missing_normals)
	else:
		_check("R4", "PASS", "every mesh has normals")
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


## C2, C3, C5, C6 from the meshes as placed; also fills `meshes` with each
## node's box, triangles, and face statistics. False when C2 or C3 failed.
func _audit_scale_and_axes() -> bool:
	var stats_cache := {}
	var total := AABB()
	var first := true
	var triangles := 0
	var zero_area := 0
	var flipped := 0
	var with_normals := 0
	var orientation := {"up": 0.0, "down": 0.0, "pos_z": 0.0, "neg_z": 0.0}
	var heights := PackedFloat32Array()
	var farthest := 0.0
	for node: MeshInstance3D in model.get_children():
		var key := [node.mesh.get_instance_id(), node.transform.basis]
		if not stats_cache.has(key):
			stats_cache[key] = MapGeometry.stats(node.mesh, node.transform.basis)
		var stats: Dictionary = stats_cache[key]
		var box: AABB = node.transform * node.mesh.get_aabb()
		meshes[str(node.name)] = {"category": "", "by": "none", "triangles": stats.triangles, "box": box, "stats": stats}
		total = box if first else total.merge(box)
		first = false
		triangles += stats.triangles
		zero_area += stats.zero_area
		flipped += stats.flipped
		for k in orientation:
			orientation[k] += stats[k]
		heights.append(box.size.y)
		for corner in 8:
			farthest = maxf(farthest, box.get_endpoint(corner).length())
	summary.triangles = triangles
	summary.zero_area = zero_area
	summary.flipped = flipped
	summary.bounds = total
	heights.sort()
	var p90 := heights[ceili(0.9 * heights.size()) - 1] if not heights.is_empty() else 0.0
	summary.p90_height = p90
	var extent := maxf(total.size.x, total.size.z)
	var ok := true
	if extent < MIN_EXTENT or extent > MAX_EXTENT:
		var suggested := _nice(TYPICAL_HEIGHT / p90) if p90 > 0.0 else 1.0
		_check("C2", "FAIL", "the model spans %.1f × %.1f units; with 1 unit = 1 m that is not a map. If it is in other units, set \"scale\" in the configuration (suggested: %s, which makes its typical object %.1f m tall)." % [total.size.x, total.size.z, _number(suggested), p90 * suggested])
		ok = false
	elif config.has("scale") and not is_equal_approx(float(config.scale), 1.0):
		_check("C2", "FIXED", "scaled by %s (configuration; baked into %d meshes, the nodes keep rotation and position): %.0f × %.0f m, typical object (90th percentile) %.1f m tall" % [_number(float(config.scale)), summary.baked_meshes, total.size.x, total.size.z, p90])
	else:
		_check("C2", "PASS", "%.0f × %.0f × %.0f m; typical object (90th-percentile height) %.1f m" % [total.size.x, total.size.z, total.size.y, p90])
	if ok and (p90 < MIN_P90_HEIGHT or p90 > MAX_P90_HEIGHT):
		_check("C2", "WARN", "the 90th-percentile mesh height is %.2f m (expected %.1f–%.0f m): check the units" % [p90, MIN_P90_HEIGHT, MAX_P90_HEIGHT])
	var up: float = orientation.up
	if orientation.pos_z > 2.0 * up or orientation.neg_z > 2.0 * up:
		_check("C3", "FAIL", "most flat area faces %s, not +Y: the model looks Z-up. Set \"up_axis\": \"z\" in the configuration (or re-export with +Y up)." % ("+Z" if orientation.pos_z >= orientation.neg_z else "−Z"))
		ok = false
	elif orientation.down > 2.0 * up:
		_check("C3", "FAIL", "most flat area faces −Y, not +Y: the model looks upside down (or its triangles wind the wrong way). Re-export it with +Y up.")
		ok = false
	elif config.get("up_axis", "y") == "z":
		_check("C3", "FIXED", "rotated from Z-up to Y-up (configuration)")
	else:
		_check("C3", "PASS", "+Y up: %.0f m² face up, %.0f m² down, %.0f / %.0f m² toward ±Z" % [up, orientation.down, orientation.pos_z, orientation.neg_z])
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
	var vocabulary: Array[CategoryRule] = MapClassifier.vocabulary_rules() if config.get("use_default_name_rules", true) else []
	rules.rules.append_array(configured)
	rules.rules.append_array(vocabulary)
	rules.rules.append_array(MapClassifier.group_rules())
	rules.default_category = config.get("default_category", "")
	summary.rule_counts = {"configured": configured.size(), "vocabulary": vocabulary.size()}
	var by_counts := {"rule": 0, "vocabulary": 0, "shape": 0, "default": 0, "none": 0}
	var shape_counts := {}
	var unclassified: Array[String] = []
	for node: MeshInstance3D in model.get_children():
		var record: Dictionary = meshes[str(node.name)]
		var category := _first_match(configured, node)
		var by := "rule"
		if category.is_empty():
			category = _first_match(vocabulary, node)
			by = "vocabulary"
		if category.is_empty():
			category = MapClassifier.category_by_shape(record.box, record.stats)
			by = "shape"
			if not category.is_empty():
				node.add_to_group(MapClassifier.GROUP_PREFIX + category, true)
				shape_counts[category] = shape_counts.get(category, 0) + 1
		if category.is_empty():
			category = rules.default_category
			by = "default" if not category.is_empty() else "none"
			if category.is_empty():
				unclassified.append(str(node.name))
		record.category = category
		record.by = by
		by_counts[by] += 1
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
	if wide.is_empty():
		_check("R3", "PASS", "no non-ground mesh is wider than %.0f m" % MAX_OBJECT)
	else:
		_check("R3", "WARN", "%d non-ground meshes are wider than %.0f m (%s): visibility ranges and occlusion work per mesh, so they are drawn whole or not at all." % [wide.size(), MAX_OBJECT, _list(wide)])


static func _first_match(list: Array[CategoryRule], node: Node) -> String:
	for rule in list:
		if rule.matches(node, str(node.name)):
			return rule.category
	return ""


## C7 on the building meshes (closed, outward) and the totals of flipped and
## zero-area triangles.
func _check_shells() -> void:
	var open: Array[String] = []
	var inside_out: Array[String] = []
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
		elif shell.volume < 0.0:
			inside_out.append(str(node.name))
	summary.shells = {"buildings": buildings, "checked": checked, "open": open.size(), "inside_out": inside_out.size()}
	var problems := 0
	if not open.is_empty():
		var colliders = config.get("colliders", {})
		var building_type: String = colliders.get("buildings", "convex") if colliders is Dictionary else "convex"
		var hull := ", and their convex colliders fill the hull" if _collision_types.is_empty() and building_type == "convex" else ""
		_check("C7", "WARN", "%d of %d building meshes are open (more than 5 %% boundary edges), e.g. %s: open walls show holes where back faces are culled%s." % [open.size(), checked, _list(open), hull])
		problems += 1
	if not inside_out.is_empty():
		_check("C7", "WARN", "%d closed building meshes are inside out (negative volume), e.g. %s" % [inside_out.size(), _list(inside_out)])
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


## 1, 2, 2.5, or 5 times a power of ten, nearest to `value`.
static func _nice(value: float) -> float:
	var power := pow(10.0, floor(log(value) / log(10.0)))
	var best := power
	for step in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if absf(step * power - value) < absf(best - value):
			best = step * power
	return best


static func _number(value: float) -> String:
	return str(snappedf(value, 0.001)).trim_suffix(".0")
