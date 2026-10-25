class_name PerfConfig
extends RefCounted
## One performance experiment: render settings layered on top of a quality
## profile, plus optional benchmark parameters. Debug builds only. Loaded
## from JSON (see docs/ARCHITECTURE.md, "Performance experiments"); unknown
## keys and values are rejected so typos do not silently measure something else.
##
## `settings` holds only the RenderSettings keys the experiment sets; they
## override the profile (experiment > profile > defaults). `profile` picks the
## base profile ("none", "high", "low"); empty means the platform default.

const USER_PATH := "user://perf_bench.json"

var experiment := "baseline"
var profile := ""
var settings := {}

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
## Measure from the driver's seat of the map's first vehicle (moved to each
## viewpoint, no pedal pressed, so it holds still).
var in_vehicle := false

const _BENCH_KEYS := ["warmup_s", "measure_s", "views", "session_minutes", "session_view", "screenshots", "quit_when_done", "in_vehicle"]


## Why the last from_dict() call returned null.
static var last_error := ""


## Builds a config from parsed JSON. Returns null on bad input and sets
## last_error (no error is logged here; load_file() logs it).
static func from_dict(data: Dictionary) -> PerfConfig:
	last_error = ""
	var config := PerfConfig.new()
	for key in data:
		if key not in RenderSettings.KEYS and key not in ["experiment", "profile", "bench"]:
			last_error = "unknown key '%s'" % key
			return null
	config.experiment = str(data.get("experiment", config.experiment))
	config.profile = str(data.get("profile", ""))
	if not config.profile.is_empty() and config.profile not in QualityProfiles.names():
		last_error = "unknown profile '%s'" % config.profile
		return null
	var error := _parse_settings(data, config.settings)
	if not error.is_empty():
		last_error = error
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
		config.in_vehicle = bool(bench_data.get("in_vehicle", false))
	return config


## Copies and type-checks RenderSettings keys from `data`; returns an error message or "".
static func _parse_settings(data: Dictionary, out: Dictionary) -> String:
	if data.has("hide"):
		var hidden: Array[String] = []
		for category in data.hide:
			hidden.append(str(category))
		out.hide = hidden
	if data.has("visibility_end"):
		var ranges := {}
		for category in data.visibility_end:
			ranges[str(category)] = float(data.visibility_end[category])
		out.visibility_end = ranges
	for category in out.get("hide", []) + out.get("visibility_end", {}).keys():
		if category not in RenderSettings.CATEGORIES:
			return "unknown category '%s'" % category
	for key in ["camera_far", "render_scale", "lod_threshold"]:
		if data.has(key):
			out[key] = float(data[key])
	for key in ["fog", "occlusion"]:
		if data.has(key):
			out[key] = bool(data[key])
	if data.has("max_fps"):
		out.max_fps = int(data.max_fps)
	if data.has("shadows"):
		out.shadows = str(data.shadows)
		if out.shadows not in ["default", "off", "single"]:
			return "bad shadows '%s'" % out.shadows
	if data.has("scaling_mode"):
		out.scaling_mode = str(data.scaling_mode)
		if out.scaling_mode not in ["bilinear", "fsr", "metalfx"]:
			return "bad scaling_mode '%s'" % out.scaling_mode
	return ""


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


func to_dict() -> Dictionary:
	return {"experiment": experiment, "profile": profile, "settings": settings}
