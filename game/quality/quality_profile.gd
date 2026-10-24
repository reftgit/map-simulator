class_name QualityProfile
extends Resource
## A named set of render settings for a class of devices. Values that keep
## the scene default: max_fps -1, camera_far 0, lod_threshold 0, visibility
## range 0 (unlimited). Applied through RenderSettings; in debug builds a
## performance experiment can override single keys.

@export var profile_name := ""
## Engine.max_fps; -1 keeps the engine default (unlimited).
@export var max_fps := -1
@export var occlusion := false

@export_group("Visibility range end (m, 0 = unlimited)")
@export var trees_visibility_end := 0.0
@export var lamps_visibility_end := 0.0
@export var decor_visibility_end := 0.0
@export var facade_detail_visibility_end := 0.0

@export_group("Camera")
## Camera far plane in metres; 0 keeps the scene value.
@export var camera_far := 0.0
## Depth fog that ends at the far plane (needs camera_far).
@export var fog := false

@export_group("Rendering")
@export_enum("default", "off", "single") var shadows := "default"
@export_range(0.25, 1.0, 0.05) var render_scale := 1.0
## Viewport.mesh_lod_threshold; 0 keeps the default (1.0).
@export var lod_threshold := 0.0


## Settings Dictionary for RenderSettings, holding only the keys this profile sets.
func to_settings() -> Dictionary:
	var settings := {}
	if max_fps >= 0:
		settings.max_fps = max_fps
	if occlusion:
		settings.occlusion = true
	var ranges := {}
	for category in ["trees", "lamps", "decor", "facade_detail"]:
		var range_end: float = get("%s_visibility_end" % category)
		if range_end > 0.0:
			ranges[category] = range_end
	if not ranges.is_empty():
		settings.visibility_end = ranges
	if camera_far > 0.0:
		settings.camera_far = camera_far
		if fog:
			settings.fog = true
	if shadows != "default":
		settings.shadows = shadows
	if not is_equal_approx(render_scale, 1.0):
		settings.render_scale = render_scale
	if lod_threshold > 0.0:
		settings.lod_threshold = lod_threshold
	return settings
