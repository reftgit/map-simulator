class_name PerfBenchmark
extends Node
## Runs a PerfConfig benchmark: for each viewpoint, warm up, then measure
## frame times, physics tick time, and render counters; or one long session at
## a single viewpoint with per-minute results. With in_vehicle, the player
## sits in the map's first vehicle, which is moved to each viewpoint. Writes user://bench_results.json, logs one
## "BENCH {json}" line per result, saves screenshots under user://bench/, and
## quits the app when done (unless quit_when_done is false). Debug builds only.

signal finished(results: Array)

const RESULTS_PATH := "user://bench_results.json"
const SCREENSHOT_DIR := "user://bench"
const SCREENSHOT_WIDTH := 640

var config: PerfConfig
var game: Node
var results: Array = []


func _ready() -> void:
	# A results file signals completion to the host scripts, so drop stale ones.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULTS_PATH))
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = game.get_view_names()
	if config.session_minutes > 0:
		var view := config.session_view if not config.session_view.is_empty() else names[0]
		await _session(view)
	else:
		var selected: Array[String] = config.views if not config.views.is_empty() else names
		for view in selected:
			await _measure_view(view)
	_write_results()
	finished.emit(results)
	if config.quit_when_done:
		# iOS ignores quit(); stop rendering the map so the device does not heat
		# up until the host script terminates the app.
		game.world.map_root.visible = false
		Engine.max_fps = 5
		print("BENCH_DONE")
		get_tree().quit()


func _go_to(view: String) -> void:
	var index: int = game.get_view_names().find(view)
	assert(index >= 0, "Unknown viewpoint: %s" % view)
	if config.in_vehicle and not game.vehicle_interaction.is_driving():
		game.vehicle_interaction.enter(game.world.vehicles[0])
	game.show_debug_view(index)
	game.hud.view_name = "%s  [BENCH %s]" % [view, config.experiment]


func _measure_view(view: String) -> void:
	_go_to(view)
	await _wait_seconds(config.warmup_s)
	var result := await _sample(config.measure_s)
	result["view"] = view
	_record(result)
	if config.screenshots:
		await _screenshot(view)


func _session(view: String) -> void:
	_go_to(view)
	for minute in config.session_minutes:
		var result := await _sample(60.0)
		result["view"] = view
		result["minute"] = minute + 1
		_record(result)
	if config.screenshots:
		await _screenshot(view)


## Samples frames for `seconds`; returns FPS statistics and counter averages.
func _sample(seconds: float) -> Dictionary:
	var frame_us: PackedInt64Array = []
	var counters := {"draw_calls": 0.0, "primitives": 0.0, "objects": 0.0}
	var counter_samples := 0
	var physics_us: PackedInt64Array = []
	var video_mem_max := 0
	var start := Time.get_ticks_usec()
	var last := start
	var next_counter := start
	while Time.get_ticks_usec() - start < int(seconds * 1e6):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_us.append(now - last)
		last = now
		physics_us.append(roundi(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1e6))
		if now >= next_counter:
			next_counter = now + 1000000
			counters.draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			counters.primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			counters.objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			video_mem_max = maxi(video_mem_max, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
			counter_samples += 1
	var elapsed := (last - start) / 1e6
	var stats := frame_stats(frame_us, elapsed)
	for key in counters:
		stats[key] = roundi(counters[key] / maxi(counter_samples, 1))
	stats.merge(physics_stats(physics_us))
	stats["video_mem_mb"] = roundi(video_mem_max / 1048576.0)
	stats["static_mem_mb"] = roundi(OS.get_static_memory_usage() / 1048576.0)
	stats["static_peak_mb"] = roundi(OS.get_static_memory_peak_usage() / 1048576.0)
	return stats


## Average FPS over the window, "1% low" (FPS at the 99th-percentile frame
## time), and minimum FPS (longest frame).
static func frame_stats(frame_us: PackedInt64Array, elapsed_s: float) -> Dictionary:
	if frame_us.is_empty() or elapsed_s <= 0.0:
		return {"frames": 0, "avg_fps": 0.0, "low1_fps": 0.0, "min_fps": 0.0}
	var sorted := frame_us.duplicate()
	sorted.sort()
	var p99: int = sorted[clampi(ceili(sorted.size() * 0.99) - 1, 0, sorted.size() - 1)]
	return {
		"frames": frame_us.size(),
		"avg_fps": snappedf(frame_us.size() / elapsed_s, 0.01),
		"low1_fps": snappedf(1e6 / maxf(p99, 1.0), 0.01),
		"min_fps": snappedf(1e6 / maxf(sorted[-1], 1.0), 0.01),
	}


## Physics tick time (Performance.TIME_PHYSICS_PROCESS: scene physics
## callbacks plus the physics server step), sampled once per frame: mean and
## 99th percentile in milliseconds.
static func physics_stats(physics_us: PackedInt64Array) -> Dictionary:
	if physics_us.is_empty():
		return {"physics_ms": 0.0, "physics_p99_ms": 0.0}
	var sorted := physics_us.duplicate()
	sorted.sort()
	var total := 0
	for value in sorted:
		total += value
	return {
		"physics_ms": snappedf(total / 1000.0 / sorted.size(), 0.001),
		"physics_p99_ms": snappedf(sorted[clampi(ceili(sorted.size() * 0.99) - 1, 0, sorted.size() - 1)] / 1000.0, 0.001),
	}


func _record(result: Dictionary) -> void:
	result["experiment"] = config.experiment
	result["in_vehicle"] = config.in_vehicle
	result["profile"] = game.quality_profile
	result["renderer"] = RenderingServer.get_current_rendering_method()
	result["window"] = str(DisplayServer.window_get_size())
	results.append(result)
	print("BENCH ", JSON.stringify(result))


func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _screenshot(view: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var size := image.get_size()
	image.resize(SCREENSHOT_WIDTH, roundi(SCREENSHOT_WIDTH * float(size.y) / size.x), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	image.save_jpg("%s/%s_%s.jpg" % [SCREENSHOT_DIR, config.experiment, view_slug(view)], 0.7)


## ASCII file-name slug from a viewpoint's first word ("Karaköy street…" -> "karakoy").
static func view_slug(view: String) -> String:
	var ascii := {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u"}
	var slug := ""
	for character in view.get_slice(" ", 0).to_lower():
		if ascii.has(character):
			slug += ascii[character]
		elif (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			slug += character
	return slug


func _write_results() -> void:
	var file := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"config": config.to_dict(), "profile": game.quality_profile,
				"occluders": game.render_settings.occluder_report, "startup": game.startup, "results": results}, "  "))
