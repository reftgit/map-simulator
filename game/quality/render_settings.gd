class_name RenderSettings
extends RefCounted
## Applies render settings to the running map without touching map files:
## map-category visibility and visibility ranges, camera far plane and depth
## fog, sun shadows, 3D render scale, mesh LOD threshold, frame cap, and
## occlusion culling. Shared by quality profiles (all builds) and performance
## experiments (debug builds).
##
## Settings are a Dictionary holding only the keys a layer sets. Layers merge
## as experiment > profile > defaults; apply() resets every key a layer does
## not set to the value captured from the scene when this object was created,
## so profiles can be switched at runtime.

const KEYS := ["hide", "visibility_end", "camera_far", "fog", "shadows", "render_scale", "scaling_mode",
		"max_fps", "occlusion", "lod_threshold"]
## Depth fog colour for a sky without a horizon colour (a light grey).
const DEFAULT_FOG_COLOR := Color(0.65, 0.66, 0.67)

## Values the scene had before any layer was applied.
var defaults := {}
## How occluders were provided: {"source": "baked"|"runtime", "ms", "occluders", "triangles"}.
var occluder_report := {}

var _map_root: Node
var _camera: Camera3D
var _viewport: Viewport
var _occluders_path := ""
var _occluder_categories: Array[String] = []
var _groups := {}
var _sun: DirectionalLight3D
var _sun_defaults := {}
var _environment: Environment
var _fog_defaults := {}
var _occluders: Node


## `occluders_path` points to a scene of baked OccluderInstance3D nodes
## (tools/bake_occluders.gd); when it is empty or missing, occluders are built
## from the map's collision on first use and a warning is logged. `rules` (the
## map's MapDefinition.category_rules) puts the map's meshes into the render
## categories; without rules no mesh has a category.
func _init(map_root: Node, camera: Camera3D, viewport: Viewport, occluders_path := "", rules: CategoryRules = null) -> void:
	_map_root = map_root
	_camera = camera
	_viewport = viewport
	_occluders_path = occluders_path
	if rules == null:
		rules = CategoryRules.new()
	_groups = rules.meshes_by_category(map_root)
	_occluder_categories = rules.occluder_categories
	_sun = map_root.find_child("Sun", false, false) as DirectionalLight3D
	if _sun:
		_sun_defaults = {"enabled": _sun.shadow_enabled, "mode": _sun.directional_shadow_mode}
	var world := map_root.find_child("WorldEnvironment", false, false) as WorldEnvironment
	if world and world.environment:
		_environment = world.environment
		_fog_defaults = {"enabled": _environment.fog_enabled, "mode": _environment.fog_mode,
				"color": _environment.fog_light_color, "begin": _environment.fog_depth_begin,
				"end": _environment.fog_depth_end, "sky": _environment.fog_sky_affect}
	defaults = {
		"hide": [], "visibility_end": {}, "camera_far": camera.far, "fog": false, "shadows": "default",
		"render_scale": viewport.scaling_3d_scale, "scaling_mode": "bilinear", "max_fps": Engine.max_fps,
		"occlusion": false, "lod_threshold": viewport.mesh_lod_threshold,
	}


## Merges layers in order; later layers win per key (dictionary values such as
## visibility_end are replaced, not combined).
static func merge(layers: Array[Dictionary]) -> Dictionary:
	var merged := {}
	for layer in layers:
		merged.merge(layer, true)
	return merged


## Applies `settings` on top of the captured defaults and returns the
## effective values.
func apply(settings: Dictionary) -> Dictionary:
	var effective := defaults.duplicate(true)
	effective.merge(settings, true)
	for category in CategoryRules.CATEGORIES:
		var range_end: float = effective.visibility_end.get(category, 0.0)
		for mesh: MeshInstance3D in _groups[category]:
			mesh.visible = category not in effective.hide
			mesh.visibility_range_end = range_end
	_camera.far = effective.camera_far
	_apply_fog(effective.fog and settings.has("camera_far"), effective.camera_far)
	_apply_shadows(effective.shadows)
	_viewport.scaling_3d_scale = effective.render_scale
	match effective.scaling_mode:
		"fsr":
			_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"metalfx":
			_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		_:
			_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.mesh_lod_threshold = effective.lod_threshold
	Engine.max_fps = effective.max_fps
	if effective.occlusion:
		_ensure_occluders()
	_viewport.use_occlusion_culling = effective.occlusion
	return effective


func _apply_fog(enabled: bool, far: float) -> void:
	if _environment == null:
		return
	if enabled:
		_environment.fog_enabled = true
		_environment.fog_mode = Environment.FOG_MODE_DEPTH
		_environment.fog_light_color = _horizon_color()
		_environment.fog_depth_begin = far * 0.5
		_environment.fog_depth_end = far
		_environment.fog_sky_affect = 0.0
	else:
		_environment.fog_enabled = _fog_defaults.enabled
		_environment.fog_mode = _fog_defaults.mode
		_environment.fog_light_color = _fog_defaults.color
		_environment.fog_depth_begin = _fog_defaults.begin
		_environment.fog_depth_end = _fog_defaults.end
		_environment.fog_sky_affect = _fog_defaults.sky


## The colour the depth fog fades to: the map's sky horizon (a procedural
## sky), so distant geometry blends into it; else its background colour.
func _horizon_color() -> Color:
	var sky_material := _environment.sky.sky_material if _environment.sky else null
	if _environment.background_mode == Environment.BG_SKY and sky_material is ProceduralSkyMaterial:
		return (sky_material as ProceduralSkyMaterial).sky_horizon_color
	if _environment.background_mode == Environment.BG_COLOR:
		return _environment.background_color
	return DEFAULT_FOG_COLOR


func _apply_shadows(mode: String) -> void:
	if _sun == null:
		return
	_sun.shadow_enabled = _sun_defaults.enabled and mode != "off"
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if mode == "single" else _sun_defaults.mode


func _ensure_occluders() -> void:
	if _occluders:
		return
	var started := Time.get_ticks_msec()
	var packed: PackedScene = null
	if not _occluders_path.is_empty() and ResourceLoader.exists(_occluders_path):
		packed = load(_occluders_path) as PackedScene
	if packed:
		_occluders = packed.instantiate()
		_map_root.add_child(_occluders)
		occluder_report.source = "baked"
	else:
		push_warning("RenderSettings: baked occluders missing (%s); building them from collision at runtime" % _occluders_path)
		_occluders = build_occluders(_map_root, _groups, false, _occluder_categories)
		_map_root.add_child(_occluders)
		occluder_report.source = "runtime"
	occluder_report.ms = Time.get_ticks_msec() - started
	var stats := occluder_stats(_occluders)
	occluder_report.occluders = stats.instances
	occluder_report.triangles = stats.triangles


## Builds one OccluderInstance3D per collision shape (trimesh, convex, or box;
## shape_faces()) of the meshes of `categories` (the map's CategoryRules.occluder_categories) under a new (not
## yet added) node. Transforms are relative to `map_root`. With
## `share_vertices`, identical vertices are merged (smaller files for baking;
## same triangles).
static func build_occluders(map_root: Node, groups: Dictionary, share_vertices := false,
		categories: Array[String] = CategoryRules.DEFAULT_OCCLUDER_CATEGORIES) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Occluders"
	var root_inverse := (map_root as Node3D).global_transform.affine_inverse() if map_root is Node3D else Transform3D.IDENTITY
	for category in categories:
		for mesh: MeshInstance3D in groups.get(category, []):
			for shape_node in mesh.find_children("*", "CollisionShape3D", true, false):
				var faces := shape_faces((shape_node as CollisionShape3D).shape)
				if faces.is_empty():
					continue
				var vertices := PackedVector3Array()
				var indices := PackedInt32Array()
				indices.resize(faces.size())
				if share_vertices:
					var index_of := {}
					for i in faces.size():
						var vertex := faces[i]
						if not index_of.has(vertex):
							index_of[vertex] = vertices.size()
							vertices.append(vertex)
						indices[i] = index_of[vertex]
				else:
					vertices = faces
					for i in faces.size():
						indices[i] = i
				var occluder := ArrayOccluder3D.new()
				occluder.set_arrays(vertices, indices)
				var instance := OccluderInstance3D.new()
				instance.name = "%s_%d" % [mesh.name, holder.get_child_count()]
				instance.occluder = occluder
				instance.transform = root_inverse * (shape_node as Node3D).global_transform
				holder.add_child(instance)
	return holder


## The triangles of a collision shape, three points each: a trimesh's faces,
## or the faces of a convex or box shape's hull (its debug mesh's triangle
## surface); empty for other shapes.
static func shape_faces(shape: Shape3D) -> PackedVector3Array:
	if shape is ConcavePolygonShape3D:
		return (shape as ConcavePolygonShape3D).get_faces()
	var faces := PackedVector3Array()
	if not (shape is ConvexPolygonShape3D or shape is BoxShape3D):
		return faces
	var mesh := shape.get_debug_mesh()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or (indices as PackedInt32Array).is_empty():
			faces.append_array(vertices)
		else:
			for index: int in indices:
				faces.append(vertices[index])
	return faces


## Occluder count and triangle count under `holder`.
static func occluder_stats(holder: Node) -> Dictionary:
	var instances := 0
	var triangles := 0
	for instance in holder.find_children("*", "OccluderInstance3D", true, false):
		var occluder := (instance as OccluderInstance3D).occluder as ArrayOccluder3D
		if occluder:
			instances += 1
			triangles += occluder.indices.size() / 3
	return {"instances": instances, "triangles": triangles}
