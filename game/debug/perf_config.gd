class_name PerfConfig
extends RefCounted
## One performance experiment: render settings layered on top of a quality
## profile, runtime (physics and frame) settings, plus optional benchmark
## parameters or a device scenario (DeviceScenario, debug builds only). Debug
## builds and perf_bench release builds only (BuildFeatures). Loaded from
## JSON (see docs/ARCHITECTURE.md, "Performance experiments"); unknown keys
## and values are rejected so typos do not silently measure something else.
##
## `settings` holds only the RenderSettings keys the experiment sets; they
## override the profile (experiment > profile > defaults). `profile` picks the
## base profile ("none", "high", "low"); empty means the platform default.
## `runtime` holds only the RUNTIME_KEYS the experiment sets (applied by
## Main.apply_runtime_settings()); every other runtime value stays default.
## `map` starts the game on another map of the MapRegistry (by id).

const USER_PATH := "user://perf_bench.json"
## Runtime experiment keys and their types: physics tick rate, physics
## interpolation, the player's physics processing, the parked vehicles,
## the radius (m) around the player beyond which map colliders are switched
## off (0 = all), the V-Sync mode, whether parked vehicles may sleep, and the
## NPCs.
const RUNTIME_KEYS := {
	"physics_ticks": TYPE_INT,
	"physics_interpolation": TYPE_BOOL,
	"player_physics": TYPE_BOOL,
	"vehicles": TYPE_BOOL,
	"vehicle_sleep": TYPE_BOOL,
	"npcs": TYPE_BOOL,
	"collider_radius": TYPE_FLOAT,
	"vsync_mode": TYPE_STRING,
}
## Device scenarios (DeviceScenario) and the keys of a "scenario" section.
const SCENARIOS := ["vehicle_sleep", "orientation"]
const _SCENARIO_KEYS := ["name", "rotate_hold_s", "quit_when_done"]
const VSYNC_MODES := {"disabled": DisplayServer.VSYNC_DISABLED, "enabled": DisplayServer.VSYNC_ENABLED,
		"adaptive": DisplayServer.VSYNC_ADAPTIVE, "mailbox": DisplayServer.VSYNC_MAILBOX}

var experiment := "baseline"
var profile := ""
## MapDefinition.id to start on; empty means the registry's default.
var map := ""
var settings := {}
var runtime := {}

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

## Device scenario to play (SCENARIOS), or "" for none.
var scenario := ""
## Seconds the scenario holds the joystick while the device is turned; 0
## leaves the orientation steps out of "vehicle_sleep".
var scenario_rotate_hold_s := 0.0

const _BENCH_KEYS := ["warmup_s", "measure_s", "views", "session_minutes", "session_view", "screenshots", "quit_when_done", "in_vehicle"]


## Why the last from_dict() call returned null.
static var last_error := ""


## Builds a config from parsed JSON. Returns null on bad input and sets
## last_error (no error is logged here; load_file() logs it).
static func from_dict(data: Dictionary) -> PerfConfig:
	last_error = ""
	var config := PerfConfig.new()
	for key in data:
		if key not in RenderSettings.KEYS and key not in ["experiment", "profile", "map", "bench", "runtime", "scenario"]:
			last_error = "unknown key '%s'" % key
			return null
	config.experiment = str(data.get("experiment", config.experiment))
	config.profile = str(data.get("profile", ""))
	if not config.profile.is_empty() and config.profile not in QualityProfiles.names():
		last_error = "unknown profile '%s'" % config.profile
		return null
	config.map = str(data.get("map", ""))
	if not config.map.is_empty() and MapRegistry.load_default().find(config.map) == null:
		last_error = "unknown map '%s'" % config.map
		return null
	var error := _parse_settings(data, config.settings)
	if error.is_empty():
		error = _parse_runtime(data.get("runtime", {}), config.runtime)
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
	if data.has("scenario"):
		error = _parse_scenario(data.scenario, config)
		if not error.is_empty():
			last_error = error
			return null
	return config


## Reads a "scenario" section into `config`; returns an error message or "".
static func _parse_scenario(data: Variant, config: PerfConfig) -> String:
	if not data is Dictionary:
		return "scenario must be an object"
	for key in data:
		if key not in _SCENARIO_KEYS:
			return "unknown scenario key '%s'" % key
	config.scenario = str(data.get("name", ""))
	if config.scenario not in SCENARIOS:
		return "unknown scenario '%s'" % config.scenario
	config.scenario_rotate_hold_s = float(data.get("rotate_hold_s", 0.0))
	if config.scenario == "orientation" and config.scenario_rotate_hold_s <= 0.0:
		return "the orientation scenario needs rotate_hold_s > 0"
	config.quit_when_done = bool(data.get("quit_when_done", true))
	return ""


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


## The app-specific external Documents folder on Android (created when first
## asked for), or "" elsewhere (Platform.external_data_dir()). Experiment and
## result files also go through it, because adb reaches it without `run-as`,
## which release builds lack.
static func external_dir() -> String:
	return Platform.current().external_data_dir()


## Copies and type-checks runtime keys; returns an error message or "".
static func _parse_runtime(data: Variant, out: Dictionary) -> String:
	if not data is Dictionary:
		return "runtime must be an object"
	for key in data:
		if key not in RUNTIME_KEYS:
			return "unknown runtime key '%s'" % key
		match RUNTIME_KEYS[key]:
			TYPE_INT:
				out[key] = int(data[key])
			TYPE_BOOL:
				out[key] = bool(data[key])
			TYPE_FLOAT:
				out[key] = float(data[key])
			TYPE_STRING:
				out[key] = str(data[key])
	if out.has("vsync_mode") and out.vsync_mode not in VSYNC_MODES:
		return "bad vsync_mode '%s'" % out.vsync_mode
	if out.has("physics_ticks") and out.physics_ticks < 1:
		return "bad physics_ticks %d" % out.physics_ticks
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
	var out := {"experiment": experiment, "profile": profile, "settings": settings, "runtime": runtime}
	if not map.is_empty():
		out.map = map
	if not scenario.is_empty():
		out.scenario = {"name": scenario, "rotate_hold_s": scenario_rotate_hold_s}
	return out
