class_name PerfExperiments
extends RefCounted
## Applies a PerfConfig to the running game without touching map files:
## hides or range-limits map node categories, changes camera, fog, shadow,
## viewport scaling, LOD, and frame-rate settings, and builds occluders from
## the map's collision geometry. Debug builds only.

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


## Applies `config`; returns a report (e.g. occluder build time) for logging.
static func apply(config: PerfConfig, map_root: Node, camera: Camera3D, viewport: Viewport) -> Dictionary:
	var report := {}
	var groups := meshes_by_category(map_root)
	for category in config.hide:
		for mesh: MeshInstance3D in groups[category]:
			mesh.visible = false
	for category in config.visibility_end:
		for mesh: MeshInstance3D in groups[category]:
			mesh.visibility_range_end = config.visibility_end[category]
	if config.camera_far > 0.0:
		camera.far = config.camera_far
		if config.fog:
			_add_depth_fog(map_root, config.camera_far)
	var sun := map_root.find_child("Sun", false, false) as DirectionalLight3D
	if sun:
		match config.shadows:
			"off":
				sun.shadow_enabled = false
			"single":
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	viewport.scaling_3d_scale = config.render_scale
	match config.scaling_mode:
		"fsr":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"metalfx":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		_:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if config.lod_threshold > 0.0:
		viewport.mesh_lod_threshold = config.lod_threshold
	if config.max_fps >= 0:
		Engine.max_fps = config.max_fps
	if config.occlusion:
		var started := Time.get_ticks_msec()
		var stats := build_occluders(map_root, groups)
		report["occluders"] = stats.instances
		report["occluder_triangles"] = stats.triangles
		report["occluder_build_ms"] = Time.get_ticks_msec() - started
		viewport.use_occlusion_culling = true
	return report


## One OccluderInstance3D per collision shape of the occluder categories.
static func build_occluders(map_root: Node, groups: Dictionary) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "PerfOccluders"
	map_root.add_child(holder)
	var instances := 0
	var triangles := 0
	for category in OCCLUDER_CATEGORIES:
		for mesh: MeshInstance3D in groups[category]:
			for shape_node in mesh.find_children("*", "CollisionShape3D", true, false):
				var shape := (shape_node as CollisionShape3D).shape as ConcavePolygonShape3D
				if shape == null:
					continue
				var faces := shape.get_faces()
				var indices := PackedInt32Array()
				indices.resize(faces.size())
				for i in faces.size():
					indices[i] = i
				var occluder := ArrayOccluder3D.new()
				occluder.set_arrays(faces, indices)
				var instance := OccluderInstance3D.new()
				instance.occluder = occluder
				holder.add_child(instance)
				instance.global_transform = (shape_node as Node3D).global_transform
				instances += 1
				triangles += faces.size() / 3
	return {"instances": instances, "triangles": triangles}


static func _add_depth_fog(map_root: Node, far: float) -> void:
	var world := map_root.find_child("WorldEnvironment", false, false) as WorldEnvironment
	if world == null:
		return
	var environment := world.environment
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.843137, 0.866667, 0.815686)
	environment.fog_depth_begin = far * 0.5
	environment.fog_depth_end = far
	environment.fog_sky_affect = 0.0
