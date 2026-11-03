extends "res://tests/test_case.gd"
## MapStreamer (docs/STREAMING.md) on the synthetic map of
## tests/fixtures/streaming_map.gd: the cells within a category's visibility
## range plus the margin are loaded, those beyond range + margin + hysteresis
## freed; a jump loads the needed cells before the frame; hidden and
## unranged categories; the per-frame budget; profile changes; cells ahead of
## a moving camera; loads in flight finished or dropped; the map script's hook.

const MapCells := preload("res://tools/map_import/map_cells.gd")
const StreamingMap := preload("res://tests/fixtures/streaming_map.gd")

const DIR := "user://test_map_streamer"
## Visibility range of every streamed category in these tests (m).
const RANGE := 25.0
const RANGES := {"visibility_end": {"facade_detail": RANGE, "trees": RANGE, "lamps": RANGE, "decor": RANGE}}

var streamer: MapStreamer
var focus: Node3D
var resident: Node3D


## The synthetic map split into cells, its resident scene in the tree, and a
## streamer with margin 10 m and hysteresis 10 m that the test drives itself
## (step()), unless `processing`.
func _stream(streamer_script: GDScript = null, processing := false) -> void:
	var definition := StreamingMap.write(DIR)
	var cells := MapCells.new()
	check(cells.run(definition, DIR.path_join("streaming"), StreamingMap.CELL).is_empty(), "split")
	resident = add_node((load(cells.index.resident_scene) as PackedScene).instantiate())
	focus = add_node(Node3D.new())
	streamer = (streamer_script.new() if streamer_script else MapStreamer.new()) as MapStreamer
	streamer.margin = 10.0
	streamer.hysteresis = 10.0
	add_node(streamer)
	streamer.set_process(processing)
	streamer.setup(resident, cells.index)
	streamer.focus = focus
	streamer.set_ranges(RANGES)


## One frame of the streamer with the camera at `position`, `delta` seconds after the last.
func step(position: Vector3, delta := 1.0 / 60.0) -> void:
	focus.global_position = position
	streamer._process(delta)


func _cell(path: String) -> int:
	return streamer.index.cell_paths.find(DIR.path_join("streaming/cells/%s.res" % path))


func _has_mesh(node_name: String) -> bool:
	return (resident.get_node("Model/" + node_name) as MeshInstance3D).mesh != null


func test_cells_within_range_and_margin_are_loaded() -> void:
	_stream()
	check(streamer.missing_cells(Vector3(-90, 1.5, 0)) > 0, "before any frame, cells in range are missing")
	step(Vector3(-90, 1.5, 0))
	check(streamer.totals.primes == 1, "the first frame loads at once")
	check(_has_mesh("Tree_-90") and _has_mesh("Tree_-70"), "trees 1.5 and 20 m away have their meshes")
	check(_has_mesh("Lamp_-75"), "the lamp 25 m away (its range) too")
	check(not _has_mesh("Tree_-50") and not _has_mesh("Detail_-60") and not _has_mesh("Lamp_-45"), "40, 36, and 49 m away: beyond range + margin (35 m)")
	check(_has_mesh("Ground_0") and _has_mesh("Building_A"), "resident meshes are always there")
	check(streamer.missing_cells() == 0, "nothing in range is missing")
	var stats := streamer.stats()
	check(stats.loaded == 3 and stats.meshes == 3 and stats.pending == 0, "three cells loaded (%s)" % stats)


func test_cells_beyond_range_margin_and_hysteresis_are_freed() -> void:
	_stream()
	step(Vector3(-90, 1.5, 0))
	for x in range(-90, -51):
		step(Vector3(x, 1.5, 0))
	check(_has_mesh("Tree_-90"), "38 m away, beyond range + margin (35 m), the tree is kept by the hysteresis (45 m)")
	check(_has_mesh("Tree_-50"), "and the tree now 2 m away is loaded on the way")
	for x in range(-52, -39):
		step(Vector3(x, 1.5, 0))
	check(not _has_mesh("Tree_-90"), "50 m away it is freed")
	check(streamer.totals.unloads >= 1 and streamer.totals.primes == 1, "freed while walking, no second prime")
	check(streamer.missing_cells() == 0, "nothing in range is missing on the way")


func test_a_jump_loads_the_cells_before_the_frame_is_drawn() -> void:
	_stream()
	step(Vector3(-90, 1.5, 0))
	step(Vector3(90, 1.5, 0))
	check(_has_mesh("Tree_90") and _has_mesh("Tree_70"), "180 m away in one frame: the cells there are loaded in that frame")
	check(not _has_mesh("Tree_-90"), "and the old ones freed")
	check(streamer.totals.primes == 2 and streamer.missing_cells() == 0, "a second prime, nothing missing")


func test_hidden_and_unranged_categories() -> void:
	_stream()
	streamer.set_ranges({"visibility_end": {"lamps": RANGE, "facade_detail": RANGE, "decor": RANGE}, "hide": ["decor"]})
	step(Vector3(-85, 1.5, 44))
	check(not _has_mesh("Decor_bench_west"), "a hidden category is not loaded, even 1 m away")
	for x: int in StreamingMap.TREE_X:
		check(_has_mesh("Tree_%d" % x), "trees without a range: every one is loaded (%d)" % x)
	check(streamer.radius_of("trees") == INF and streamer.radius_of("decor") == -1.0, "radius INF without a range, -1 hidden")


func test_profile_change_updates_the_ranges() -> void:
	_stream()
	step(Vector3(0, 1.5, 0))
	check(not _has_mesh("Tree_-50") and not _has_mesh("Tree_50"), "50 m away with a 25 m range: not loaded")
	streamer.set_ranges({"visibility_end": {"facade_detail": 100.0, "trees": 100.0, "lamps": 100.0, "decor": 100.0}})
	for i in 30:
		step(Vector3(0, 1.5, 0))
	check(_has_mesh("Tree_-90") and _has_mesh("Tree_90") and _has_mesh("Decor_bench_east"), "a 100 m range loads the rest over the next frames")
	check(streamer.missing_cells() == 0, "nothing missing")
	streamer.set_ranges(RANGES)
	step(Vector3(0, 1.5, 0))
	check(not _has_mesh("Tree_-90") and _has_mesh("Tree_10"), "back to 25 m: far cells freed, near ones kept")


func test_budget_gives_one_cell_per_frame_at_zero_budget() -> void:
	_stream()
	streamer.attach_budget_ms = 0.0
	step(Vector3(0, 1.5, 0))
	streamer.set_ranges({"visibility_end": {"facade_detail": 500.0, "trees": 500.0, "lamps": 500.0, "decor": 500.0}})
	var frames := 0
	var most := 0
	while streamer.missing_cells() > 0 and frames < 100:
		step(Vector3(0, 1.5, 0))
		most = maxi(most, streamer.frame_attached)
		frames += 1
	check(streamer.missing_cells() == 0, "every cell loaded in the end (%d frames)" % frames)
	check(most == 1, "at most one cell given its meshes per frame (%d)" % most)
	check(frames >= streamer.index.cell_count() - streamer.totals.prime_cells, "so one frame per cell")


func test_cells_ahead_of_a_moving_camera_are_wanted() -> void:
	_stream()
	step(Vector3(-90, 1.5, 0))
	for i in 60:
		step(Vector3(-90 + i * 20.0 / 60.0, 1.5, 0))
	# At 20 m/s the point 1.5 s ahead is 30 m on: the tree 46 m ahead is within its range + margin.
	check(streamer._velocity.length() > 15.0, "the camera's velocity is known (%.1f m/s)" % streamer._velocity.length())
	check(_has_mesh("Tree_-30"), "the tree 40 m ahead is loaded before the camera is within 35 m of it")


class SlowLoads extends MapStreamer:
	## Frames a load stays in flight; started and taken loads.
	var frames := 3
	var flights := {}
	var started := 0
	var taken := 0

	func _begin_load(cell: int) -> void:
		_requested[cell] = true
		flights[cell] = frames
		started += 1

	func _load_status(cell: int) -> int:
		flights[cell] -= 1
		return ResourceLoader.THREAD_LOAD_IN_PROGRESS if flights[cell] > 0 else ResourceLoader.THREAD_LOAD_LOADED

	func _take_load(cell: int) -> MapCell:
		taken += 1
		flights.erase(cell)
		return load(index.cell_paths[cell]) as MapCell


func test_loads_in_flight_are_finished_or_dropped() -> void:
	_stream(SlowLoads)
	var slow := streamer as SlowLoads
	step(Vector3(-90, 1.5, 0))
	step(Vector3(-80, 1.5, 0))
	check(slow.started > 0 and streamer.stats().pending > 0, "loads in flight after moving (%d)" % slow.started)
	check(not _has_mesh("Tree_-50"), "not attached while in flight")
	step(Vector3(-79, 1.5, 0))
	step(Vector3(-78, 1.5, 0))
	step(Vector3(-77, 1.5, 0))
	check(_has_mesh("Tree_-50"), "attached once loaded")
	streamer.set_ranges({"visibility_end": {"facade_detail": 500.0, "trees": 500.0, "lamps": 500.0, "decor": 500.0}})
	step(Vector3(-77, 1.5, 0))
	var in_flight := slow.flights.size()
	check(in_flight > 0, "more loads in flight (%d)" % in_flight)
	var taken_before := slow.taken
	streamer.shutdown()
	check(slow.taken == taken_before + in_flight and slow.flights.is_empty(), "shutdown waits for each one and drops it")
	check(streamer.index == null and streamer.stats().loaded == 0, "nothing held afterwards")


func test_a_load_that_arrives_after_the_camera_left_is_dropped() -> void:
	_stream(SlowLoads)
	step(Vector3(-90, 1.5, 0))
	step(Vector3(-80, 1.5, 0))
	var cell := _cell("trees_-3_0")
	check(streamer._requested.has(cell), "the tree at x = -50 is in flight")
	step(Vector3(-89, 1.5, 0))
	step(Vector3(-98, 1.5, 0))
	step(Vector3(-107, 1.5, 0))
	check(not streamer._requested.has(cell) and streamer.totals.primes == 1, "it arrived (no jump in between)")
	check(not streamer.is_loaded(cell) and not _has_mesh("Tree_-50"), "when no longer wanted, and was dropped")


func test_the_map_script_prepares_streamed_meshes() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar prepared := []\nfunc prepare_streamed(instances: Array) -> void:\n\tprepared.append_array(instances)\n"
	script.reload()
	_stream()
	resident.set_script(script)
	step(Vector3(-90, 1.5, 0))
	var names: Array = (resident.get("prepared") as Array).map(func(node: Node) -> String: return str(node.name))
	names.sort()
	check(names == ["Lamp_-75", "Tree_-70", "Tree_-90"], "each attached cell's meshes go to prepare_streamed() (%s)" % [names])


func test_streaming_follows_the_streamer_s_own_frames() -> void:
	_stream(null, true)
	focus.global_position = Vector3(-90, 1.5, 0)
	await process_frames(2)
	check(_has_mesh("Tree_-90") and streamer.missing_cells() == 0, "in the tree it streams by itself")
	check(streamer.process_priority == MapStreamer.PROCESS_PRIORITY and MapStreamer.PROCESS_PRIORITY > 0, "after the camera (priority %d)" % streamer.process_priority)
	tree.paused = true
	focus.global_position = Vector3(90, 1.5, 0)
	await process_frames(2)
	check(not _has_mesh("Tree_90"), "paused (focus loss): nothing happens")
	tree.paused = false
	await process_frames(2)
	check(_has_mesh("Tree_90") and streamer.missing_cells() == 0, "and it catches up when unpaused")
