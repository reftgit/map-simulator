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

## Map node categories, matched by node-name prefix in this order (the GLB has
## no hierarchy; every mesh node is a 150 m chunk or a single landmark).
const CATEGORIES := {
	"facade_detail": ["Detail_", "MosqueDetail_", "LandmarkDetail_"],
	"decor": ["Galata_Bridge_Detail", "Halic_Metro_Bridge_Detail", "BridgeDetail_", "BridgeGlass_",
			"RoadPaint_", "TrafficSignals_", "SignalGlow_", "Ferry_"],
	"lamps": ["StreetLamps_", "LampGlow_"],
	"trees": ["Trees_", "TreeTrunks_", "Shrubs_"],
	"buildings": ["Buildings_", "Mosque_", "Landmark_"],
	"ground": ["Ground_", "Road_", "Pavement_", "Quays_", "Gardens_", "Galata_Bridge", "Halic_Metro_Bridge",
			"Ataturk_Bridge"],
	"water": ["Water"],
}
## Collision of these categories becomes occluders.
const OCCLUDER_CATEGORIES := ["buildings", "ground"]
const FOG_COLOR := Color(0.843137, 0.866667, 0.815686)

## Values the scene had before any layer was applied.
var defaults := {}
## How occluders were provided: {"source": "baked"|"runtime", "ms", "occluders", "triangles"}.
var occluder_report := {}

var _map_root: Node
var _camera: Camera3D
var _viewport: Viewport
var _occluders_path := ""
var _groups := {}
var _sun: DirectionalLight3D
var _sun_defaults := {}
var _environment: Environment
var _fog_defaults := {}
var _occluders: Node


## `occluders_path` points to a scene of baked OccluderInstance3D nodes
## (tools/bake_occluders.gd); when it is empty or missing, occluders are built
## from the map's collision on first use and a warning is logged.
func _init(map_root: Node, camera: Camera3D, viewport: Viewport, occluders_path := "") -> void:
	_map_root = map_root
	_camera = camera
	_viewport = viewport
	_occluders_path = occluders_path
	_groups = meshes_by_category(map_root)
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


## Category of a map mesh node, or "" when no prefix matches.
static func category_of(node_name: String) -> String:
	for category in CATEGORIES:
		for prefix: String in CATEGORIES[category]:
			if node_name.begins_with(prefix):
				return category
	return ""


## Map mesh nodes grouped by category.
static func meshes_by_category(map_root: Node) -> Dictionary:
	var groups := {}
	for category in CATEGORIES:
		groups[category] = []
	for node in map_root.find_children("*", "MeshInstance3D", true, false):
		var category := category_of(node.name)
		if not category.is_empty():
			groups[category].append(node)
	return groups


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
	for category in CATEGORIES:
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
		_environment.fog_light_color = FOG_COLOR
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
		_occluders = build_occluders(_map_root, _groups)
		_map_root.add_child(_occluders)
		occluder_report.source = "runtime"
	occluder_report.ms = Time.get_ticks_msec() - started
	var stats := occluder_stats(_occluders)
	occluder_report.occluders = stats.instances
	occluder_report.triangles = stats.triangles


## Builds one OccluderInstance3D per collision shape of the occluder
## categories under a new (not yet added) node. Transforms are relative to
## `map_root`. With `share_vertices`, identical vertices are merged (smaller
## files for baking; same triangles).
static func build_occluders(map_root: Node, groups: Dictionary, share_vertices := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Occluders"
	var root_inverse := (map_root as Node3D).global_transform.affine_inverse() if map_root is Node3D else Transform3D.IDENTITY
	for category in OCCLUDER_CATEGORIES:
		for mesh: MeshInstance3D in groups[category]:
			for shape_node in mesh.find_children("*", "CollisionShape3D", true, false):
				var shape := (shape_node as CollisionShape3D).shape as ConcavePolygonShape3D
				if shape == null:
					continue
				var faces := shape.get_faces()
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
