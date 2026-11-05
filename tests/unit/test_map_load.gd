extends "res://tests/test_case.gd"
## MapLoad (Phase 6e): a map scene read and instantiated at once, or on
## worker threads while the frames go on; polled, finished, cancelled, waited
## for. Headless, the threaded path runs on a scene without meshes (the dummy
## renderer makes meshes only on the main thread; docs/STREAMING.md).

const SCENE := "res://tests/fixtures/flat_map.tscn"
## Frames a load of the fixture may take before a test gives up.
const MAX_FRAMES := 600


## Polls `job` once per frame until it is finished; the steps it went through.
func _poll_until_finished(job: MapLoad) -> Array[int]:
	var steps: Array[int] = [job.step]
	var progress := job.progress
	for i in MAX_FRAMES:
		if job.is_finished():
			break
		await process_frames(1)
		job.poll(2.0)
		check(job.progress >= progress, "progress never goes back (%.2f after %.2f)" % [job.progress, progress])
		progress = job.progress
		if job.step != steps[-1]:
			steps.append(job.step)
	return steps


func test_at_once_reads_and_instantiates_at_once() -> void:
	var job := MapLoad.new(SCENE, false)
	check(job.step == MapLoad.Step.DONE and job.is_finished(), "done before returning")
	check(job.root != null and job.root.name == &"FlatMap" and not job.root.is_inside_tree(), "the scene's instance, not in the tree")
	check(job.progress == 1.0 and job.report.read_ms >= 0.0 and job.report.instantiate_ms >= 0.0, "progress and times (%s)" % [job.report])
	job.root.free()


func test_on_threads_reads_then_instantiates_while_frames_go_on() -> void:
	var job := MapLoad.new(SCENE, true)
	check(job.step == MapLoad.Step.LOADING and job.root == null, "reading after the request")
	var steps: Array[int] = await _poll_until_finished(job)
	check(steps[-1] == MapLoad.Step.DONE, "done (steps %s, %s)" % [steps, job.report])
	check(MapLoad.Step.INSTANTIATING in steps or steps == ([MapLoad.Step.LOADING, MapLoad.Step.DONE] as Array[int]), "instantiated after reading (steps %s)" % [steps])
	check(job.root != null and job.root.name == &"FlatMap" and not job.root.is_inside_tree(), "the scene's instance, not in the tree")
	check(job.progress == 1.0 and job.report.polls >= 1, "progress 1, polled (%s)" % [job.report])
	check(ResourceLoader.load_threaded_get_status(SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "the threaded load was collected")
	job.root.free()


func test_cancel_while_reading_drops_the_scene() -> void:
	var job := MapLoad.new(SCENE, true)
	job.cancel()
	var steps: Array[int] = await _poll_until_finished(job)
	check(job.step == MapLoad.Step.CANCELLED and job.root == null, "cancelled, nothing made (steps %s)" % [steps])
	check(ResourceLoader.load_threaded_get_status(SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "the threaded load was still collected")


func test_cancel_after_done_frees_the_instance() -> void:
	var job := MapLoad.new(SCENE, false)
	var root := job.root
	job.cancel()
	check(job.step == MapLoad.Step.CANCELLED and job.root == null and not is_instance_valid(root), "instance freed")


func test_wait_finishes_a_load_in_flight() -> void:
	var job := MapLoad.new(SCENE, true)
	check(job.wait() == MapLoad.Step.DONE and job.root != null, "done without a frame (%s)" % [job.report])
	job.root.free()
	job = MapLoad.new(SCENE, true)
	job.cancel()
	check(job.wait() == MapLoad.Step.CANCELLED and job.root == null, "cancelled and waited for: dropped")


func test_a_missing_scene_fails_with_a_reason() -> void:
	for threaded in [false, true]:
		var job := MapLoad.new("res://tests/fixtures/none.tscn", threaded)
		check(job.step == MapLoad.Step.FAILED and job.is_finished() and job.root == null, "failed (threaded %s)" % threaded)
		check(str(job.report.get("error", "")).contains("none.tscn"), "says which file (%s)" % [job.report])
