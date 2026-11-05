class_name LoadingFrames
extends RefCounted
## The frames of a loading screen (Main): from the screen's first frame to the
## first frame without it, the time of each and the loading steps that ran in
## it, the longest, how often the screen's indicator moved, and the main-thread
## time of each step. Printed as a LOADING line in every kind of build; perf
## builds also keep each frame's render times, pipeline compilations, and when
## its physics and drawing started (to tell what a long frame spent its time on).
##
## At the start, the first two frames are the boot splash's: the loading
## screen is on screen only once the first frame is presented, so those two
## are reported as "boot" and left out of the longest frame.

## The record of the last finish(): map, kind ("start", "switch"), whether it
## loaded on threads, frames, longest_ms and its steps, over_100_ms, total_ms,
## boot_ms, indicator, steps_ms, load (WorldManager.load_report), frame_ms.
var report := {}
## What a frame in which no step ran was waiting for ("unload", "read", ...).
var phase := ""

var _tree: SceneTree
var _viewport: Viewport
var _detail := false
var _frames: Array[Dictionary] = []
var _tick := 0
var _frame_steps: Array[String] = []
var _steps := {}
var _pipelines := 0
var _marks := {}


## Starts recording: every frame from now on, until finish().
func begin(kind: String, map_id: String, tree: SceneTree, viewport: Viewport, detail: bool) -> void:
	stop()
	report = {"map": map_id, "kind": kind, "threaded": true}
	_tree = tree
	_viewport = viewport
	_detail = detail
	_frames.clear()
	_frame_steps.clear()
	_steps.clear()
	phase = ""
	_tick = Time.get_ticks_usec()
	_tree.process_frame.connect(_record)
	if _detail:
		_pipelines = pipeline_compilations()
		RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
		_tree.physics_frame.connect(_mark.bind("physics"))
		RenderingServer.frame_pre_draw.connect(_mark.bind("pre_draw"))
		RenderingServer.frame_post_draw.connect(_mark.bind("post_draw"))


## Runs one loading step, adds its main-thread time to the step's total, and
## returns what it returned.
func run(step: String, work: Callable) -> Variant:
	var started := Time.get_ticks_usec()
	var result: Variant = work.call()
	_steps[step] = snappedf(_steps.get(step, 0.0) + (Time.get_ticks_usec() - started) / 1000.0, 0.1)
	if step not in _frame_steps:
		_frame_steps.append(step)
	return result


## Milliseconds since the frame being recorded started.
func frame_ms() -> float:
	return (Time.get_ticks_usec() - _tick) / 1000.0


## The last recorded frame's milliseconds (0 before the first).
func last_frame_ms() -> float:
	return _frames[-1].ms if not _frames.is_empty() else 0.0


## Stops recording and completes `report` (`indicator`: the loading screen's
## indicator counts, `load`: the load's report); prints it as a LOADING line.
func finish(loaded: bool, indicator: Dictionary, load: Dictionary) -> Dictionary:
	stop()
	var shown := _frames.slice(2) if report.kind == "start" else _frames
	var longest := {"ms": 0.0, "steps": ""}
	for frame in shown:
		if frame.ms > longest.ms:
			longest = frame
	report.merge({"loaded": loaded, "frames": shown.size(), "longest_ms": longest.ms, "longest_steps": longest.steps,
			"over_100_ms": shown.filter(func(frame: Dictionary) -> bool: return frame.ms > 100.0).size(),
			"total_ms": _sum(shown), "boot_ms": _sum(_frames.slice(0, 2)) if report.kind == "start" else 0.0,
			"indicator": indicator, "steps_ms": _steps.duplicate(), "load": load.duplicate(),
			"frame_ms": _frames.map(func(frame: Dictionary) -> float: return frame.ms)}, true)
	if _detail:
		report.frame_detail = _frames.duplicate()
	_print()
	return report


## The record of a load at once on the main thread (headless runs, the
## measurement key "threaded_load": false): the whole load in one frame,
## `ms` from its start to the first frame drawn with the map, which is all
## the loading screen (or, at the start, the boot splash) shows meanwhile.
func finish_at_once(kind: String, map_id: String, ms: float, unload_frames: int, load: Dictionary) -> Dictionary:
	stop()
	report = {"map": map_id, "kind": kind, "threaded": false, "loaded": true, "frames": 1 + unload_frames,
			"longest_ms": snappedf(ms, 0.1), "longest_steps": "all", "over_100_ms": int(ms > 100.0),
			"total_ms": snappedf(ms, 0.1), "load": load.duplicate()}
	_print()
	return report


func stop() -> void:
	if _tree == null or not _tree.process_frame.is_connected(_record):
		return
	_tree.process_frame.disconnect(_record)
	if _detail:
		_tree.physics_frame.disconnect(_mark)
		RenderingServer.frame_pre_draw.disconnect(_mark)
		RenderingServer.frame_post_draw.disconnect(_mark)


## Godot's pipeline compilations so far (PerfBenchmark.PIPELINE_INFO).
static func pipeline_compilations() -> int:
	var total := 0
	for info in PerfBenchmark.PIPELINE_INFO:
		total += RenderingServer.get_rendering_info(info)
	return total


## Each frame: the time since the last one and what ran in it (the steps, else
## the phase). Connected before the loading coroutine resumes on the same
## signal, so it closes the frame before the next steps run.
func _record() -> void:
	var now := Time.get_ticks_usec()
	var frame := {"ms": snappedf((now - _tick) / 1000.0, 0.1), "steps": ",".join(_frame_steps) if not _frame_steps.is_empty() else phase}
	if report.kind == "start" and _frames.size() < 2:
		frame.steps = "boot"
	if _detail:
		var viewport := _viewport.get_viewport_rid()
		# The render times the renderer reports now are the last drawn frame's.
		frame.render_cpu_ms = snappedf(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu(), 0.1)
		frame.gpu_ms = snappedf(RenderingServer.viewport_get_measured_render_time_gpu(viewport), 0.1)
		var pipelines := pipeline_compilations()
		frame.pipelines = pipelines - _pipelines
		_pipelines = pipelines
		frame.marks = _marks.duplicate()
	_frames.append(frame)
	_tick = now
	_frame_steps.clear()
	_marks.clear()


## Perf builds: when, within the frame being recorded, its physics steps (the
## first), drawing, and the end of drawing came (ms from the frame's start).
func _mark(mark: String) -> void:
	if not _marks.has(mark):
		_marks[mark] = snappedf((Time.get_ticks_usec() - _tick) / 1000.0, 0.1)


## The LOADING line and its companions, each short enough for Android's log
## (which splits a line after about 1,000 characters): the summary, the steps'
## times (LOADING_STEPS), the load's report (LOADING_LOAD), and the frame
## times, 80 a line (LOADING_FRAMES); the perf builds' frame detail goes into
## the results instead (Main.startup).
func _print() -> void:
	var summary := report.duplicate()
	for key in ["frame_ms", "frame_detail", "steps_ms", "load"]:
		summary.erase(key)
	print("LOADING ", JSON.stringify(summary))
	if report.has("steps_ms"):
		print("LOADING_STEPS %s %s" % [report.map, JSON.stringify(report.steps_ms)])
	print("LOADING_LOAD %s %s" % [report.map, JSON.stringify(report.load)])
	var times: Array = report.get("frame_ms", [])
	for i in range(0, times.size(), 80):
		print("LOADING_FRAMES %s %d %s" % [report.map, i, JSON.stringify(times.slice(i, i + 80))])


static func _sum(frames: Array) -> float:
	return snappedf(frames.reduce(func(sum: float, frame: Dictionary) -> float: return sum + frame.ms, 0.0), 0.1)
