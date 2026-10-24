class_name PerfConfig
extends RefCounted
## One performance experiment: temporary render settings plus optional
## benchmark parameters. Debug builds only; the default instance changes
## nothing. Loaded from JSON (see docs/ARCHITECTURE.md, "Performance
## experiments"); unknown keys are rejected so typos do not silently measure
## the baseline.

const USER_PATH := "user://perf_bench.json"

var experiment := "baseline"
## Map categories to hide (PerfExperiments.CATEGORIES keys).
var hide: Array[String] = []
## Category -> visibility range end in metres.
var visibility_end := {}
## Camera far plane in metres; 0 keeps the scene value.
var camera_far := 0.0
## Depth fog that ends at the far plane (only with camera_far).
var fog := false
## "default", "off", or "single" (one orthogonal split).
var shadows := "default"
var render_scale := 1.0
## "bilinear", "fsr", or "metalfx" (Apple only).
var scaling_mode := "bilinear"
## Engine.max_fps; -1 keeps the current value, 0 is unlimited.
var max_fps := -1
## Viewport occlusion culling with occluders built from map collision.
var occlusion := false
## Viewport.mesh_lod_threshold; 0 keeps the default (1.0).
var lod_threshold := 0.0

var bench := false
var warmup_s := 30.0
var measure_s := 60.0
## Viewpoint names to measure; empty means all.
var views: Array[String] = []
## When > 0: one long run at session_view, logging each minute.
var session_minutes := 0
var session_view := ""
var screenshots := true
var quit_when_done := true

const _KEYS := ["experiment", "hide", "visibility_end", "camera_far", "fog", "shadows", "render_scale",
		"scaling_mode", "max_fps", "occlusion", "lod_threshold", "bench"]
const _BENCH_KEYS := ["warmup_s", "measure_s", "views", "session_minutes", "session_view", "screenshots", "quit_when_done"]


## Why the last from_dict() call returned null.
static var last_error := ""


## Builds a config from parsed JSON. Returns null on bad input and sets
## last_error (no error is logged here; load_file() logs it).
static func from_dict(data: Dictionary) -> PerfConfig:
	last_error = ""
	var config := PerfConfig.new()
	for key in data:
		if key not in _KEYS:
			last_error = "unknown key '%s'" % key
			return null
	config.experiment = str(data.get("experiment", config.experiment))
	for category in data.get("hide", []):
		config.hide.append(str(category))
	for category in data.get("visibility_end", {}):
		config.visibility_end[str(category)] = float(data.visibility_end[category])
	for category in config.hide + config.visibility_end.keys():
		if category not in PerfExperiments.CATEGORIES:
			last_error = "unknown category '%s'" % category
			return null
	config.camera_far = float(data.get("camera_far", 0.0))
	config.fog = bool(data.get("fog", false))
	config.shadows = str(data.get("shadows", "default"))
	config.render_scale = float(data.get("render_scale", 1.0))
	config.scaling_mode = str(data.get("scaling_mode", "bilinear"))
	config.max_fps = int(data.get("max_fps", -1))
	config.occlusion = bool(data.get("occlusion", false))
	config.lod_threshold = float(data.get("lod_threshold", 0.0))
	if config.shadows not in ["default", "off", "single"] or config.scaling_mode not in ["bilinear", "fsr", "metalfx"]:
		last_error = "bad shadows or scaling_mode"
		return null
	var bench_data = data.get("bench")
	if bench_data is Dictionary:
		for key in bench_data:
			if key not in _BENCH_KEYS:
				last_error = "unknown bench key '%s'" % key
				return null
		config.bench = true
		config.warmup_s = float(bench_data.get("warmup_s", config.warmup_s))
		config.measure_s = float(bench_data.get("measure_s", config.measure_s))
		for view in bench_data.get("views", []):
			config.views.append(str(view))
		config.session_minutes = int(bench_data.get("session_minutes", 0))
		config.session_view = str(bench_data.get("session_view", ""))
		config.screenshots = bool(bench_data.get("screenshots", true))
		config.quit_when_done = bool(bench_data.get("quit_when_done", true))
	return config


## Reads a config file. With `consume`, the file is deleted after reading so
## the next normal launch runs without the experiment.
static func load_file(path: String, consume := false) -> PerfConfig:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if consume:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not parsed is Dictionary:
		push_error("PerfConfig: %s is not a JSON object" % path)
		return null
	var config := from_dict(parsed)
	if config == null:
		push_error("PerfConfig: %s: %s" % [path, last_error])
	return config


## True when applying this config would change nothing.
func is_default() -> bool:
	return hide.is_empty() and visibility_end.is_empty() and camera_far <= 0.0 and shadows == "default" \
			and is_equal_approx(render_scale, 1.0) and max_fps < 0 and not occlusion and lod_threshold <= 0.0


func to_dict() -> Dictionary:
	return {
		"experiment": experiment, "hide": hide, "visibility_end": visibility_end, "camera_far": camera_far,
		"fog": fog, "shadows": shadows, "render_scale": render_scale, "scaling_mode": scaling_mode,
		"max_fps": max_fps, "occlusion": occlusion, "lod_threshold": lod_threshold,
	}
