class_name MapLoad
extends RefCounted
## One map scene loading behind the loading screen (WorldManager.begin_load()).
## On threads, the file is read with ResourceLoader.load_threaded_request() and
## the scene instantiated on a WorkerThreadPool task while the frames go on;
## Main polls it once per frame and WorldManager.finish_load() adds the
## instance to the tree when it is done. Without threads (headless runs, whose
## renderer cannot create meshes off the main thread, and the measurement key
## "threaded_load": false) the scene is read and instantiated at once, as
## before (docs/STREAMING.md, "Loading a map").
##
## Two rules from the Phase 6e probes on the Mac:
## - The loading thread needs the main thread to run the rendering server's
##   queued work. Polled once per frame, the default map's resident scene took
##   15 s instead of 0.2 s, so poll() keeps asking for up to `service_ms` of
##   the frame, which runs that work each time (ResourceLoader's own wait in
##   load_threaded_get() does the same every millisecond).
## - It never waits in load_threaded_get() for a load in flight: that wait,
##   while several loads created the same materials for the first time,
##   crashed a worker thread (5 of 40 launches; 0 of 40 with one load at a time,
##   and 0 of 40 without the main thread's wait).

enum Step { LOADING, INSTANTIATING, DONE, FAILED, CANCELLED }

## Share of `progress` for reading the file; instantiating is the rest.
const READ_SHARE := 0.9
## Microseconds between two status checks while poll() serves the loading thread.
const SERVICE_STEP_US := 500

## The scene file.
var path := ""
var threaded := false
var step := Step.LOADING
## 0..1, never decreasing: reading the file up to READ_SHARE, then instantiating.
var progress := 0.0
## The scene's instance, not in the tree, once DONE.
var root: Node
## Milliseconds spent reading and instantiating (on the main thread without
## threads), the frames polled, the longest single run of the loading
## thread's queued physics work on the main thread (_serve(): one collision
## shape's setup cannot be split), and why it failed.
var report := {}

var _started := 0
var _instantiate_started := 0
var _task := -1
var _instance: Node
var _cancelled := false
var _space := RID()


## `space`: a physics space whose state poll() reads while serving the
## loading thread (see _serve()).
func _init(scene_path: String, on_threads: bool, space := RID()) -> void:
	path = scene_path
	threaded = on_threads
	_space = space
	_started = Time.get_ticks_usec()
	report = {"read_ms": 0.0, "instantiate_ms": 0.0, "polls": 0, "serve_max_ms": 0.0}
	if not ResourceLoader.exists(path):
		_fail("%s does not exist" % path)
		return
	if not threaded:
		_instantiate_now(load(path) as PackedScene)
		return
	# The scene's scripts load here: the shaders a script preloads, loaded on
	# the loading thread, left three of ResourceLoader's load tokens behind
	# (leaked at exit; Phase 6e, the default map's script).
	for dependency in ResourceLoader.get_dependencies(path):
		var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if dependency_path.get_extension() == "gd":
			load(dependency_path)
	if ResourceLoader.load_threaded_request(path) != OK:
		_fail("cannot request %s" % path)


func is_finished() -> bool:
	return step in [Step.DONE, Step.FAILED, Step.CANCELLED]


## Advances the load; on the main thread, once per frame. While the file is
## read, keeps checking for up to `service_ms`, which serves the loading
## thread (above). Returns the step.
func poll(service_ms := 0.0) -> Step:
	report.polls += 1
	if step == Step.LOADING and threaded:
		_poll_read(service_ms)
	elif step == Step.INSTANTIATING and WorkerThreadPool.is_task_completed(_task):
		_collect_instance()
	return step


## Drops the load. An instance already made is freed at once; a file still
## being read or a scene still being instantiated is dropped when it is done
## (Godot cannot cancel a threaded load, and an uncollected one keeps its
## resource), so keep polling until is_finished(), or call wait().
func cancel() -> void:
	_cancelled = true
	if step == Step.DONE:
		root.free()
		root = null
		step = Step.CANCELLED


## Finishes the load on the main thread without returning in between (the
## game is closing, or a test frees it): the only place that waits for a load
## in flight, and only for this one.
func wait() -> Step:
	while step == Step.LOADING and threaded:
		_poll_read(INF)
	if step == Step.INSTANTIATING:
		_collect_instance()
	return step


func _poll_read(service_ms: float) -> void:
	var started := Time.get_ticks_usec()
	var read := []
	var status := ResourceLoader.load_threaded_get_status(path, read)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and (Time.get_ticks_usec() - started) / 1000.0 < service_ms:
		OS.delay_usec(SERVICE_STEP_US)
		_serve()
		status = ResourceLoader.load_threaded_get_status(path, read)
	if not read.is_empty():
		progress = maxf(progress, float(read[0]) * READ_SHARE)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("cannot load %s" % path)
		return
	# Loaded: returns at once, without waiting.
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	report.read_ms = _ms_since(_started)
	if _cancelled:
		step = Step.CANCELLED
	elif packed == null:
		_fail("%s is not a scene" % path)
	else:
		step = Step.INSTANTIATING
		_instantiate_started = Time.get_ticks_usec()
		_task = WorkerThreadPool.add_task(_instantiate.bind(packed), false, "MapLoad %s" % path.get_file())


## Runs the physics work the loading thread queued for the main thread (the
## collision shapes it makes are set up there: a reading on the main thread
## runs the queue first), in small pieces, instead of all of it at the next
## physics step (frames of 30-70 ms on the Mac while the default map loaded).
func _serve() -> void:
	if _space.is_valid():
		var started := Time.get_ticks_usec()
		PhysicsServer3D.space_is_active(_space)
		report.serve_max_ms = maxf(report.serve_max_ms, _ms_since(started))


## Runs on a worker thread: a scene's nodes may be made off the main thread
## as long as they are added to the tree on it.
func _instantiate(packed: PackedScene) -> void:
	_instance = packed.instantiate()


func _collect_instance() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	report.instantiate_ms = _ms_since(_instantiate_started)
	var instance := _instance
	_instance = null
	if _cancelled:
		if instance:
			instance.free()
		step = Step.CANCELLED
	else:
		_done(instance)


func _instantiate_now(packed: PackedScene) -> void:
	report.read_ms = _ms_since(_started)
	if packed == null:
		_fail("cannot load %s" % path)
		return
	_instantiate_started = Time.get_ticks_usec()
	var instance := packed.instantiate()
	report.instantiate_ms = _ms_since(_instantiate_started)
	_done(instance)


func _done(instance: Node) -> void:
	if instance == null:
		_fail("%s could not be instantiated" % path)
		return
	root = instance
	progress = 1.0
	step = Step.DONE


func _fail(reason: String) -> void:
	report.error = reason
	step = Step.FAILED


static func _ms_since(usec: int) -> float:
	return snappedf((Time.get_ticks_usec() - usec) / 1000.0, 0.1)
