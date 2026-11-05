extends "res://tests/test_case.gd"
## Streaming in the game (docs/STREAMING.md): a map with a streaming index
## loads its resident scene and streams its cells; walking and driving keep
## every cell the camera needs loaded; what Godot draws is the same with and
## without streaming; a map without an index loads whole; a map switch frees
## the cells; a jump loads the needed cells before the frame. On the
## synthetic map of tests/fixtures/streaming_map.gd (no GLB needed), and on
## the default map where its GLB and its cells exist (SKIP otherwise).

const MapCells := preload("res://tools/map_import/map_cells.gd")
const StreamingMap := preload("res://tests/fixtures/streaming_map.gd")

const DIR := "user://test_map_streaming"
const RANGE := 25.0
const RANGES := {"facade_detail": RANGE, "trees": RANGE, "lamps": RANGE, "decor": RANGE}
const DEFAULT_MAP := "res://maps/istanbul_halic_cells_shader/istanbul_halic_cells_shader.tres"

var game: Node
var definition: MapDefinition


## The synthetic map, split and linked.
func _map() -> MapDefinition:
	var written := StreamingMap.write(DIR)
	var cells := MapCells.new()
	check(cells.run(written, DIR.path_join("streaming"), StreamingMap.CELL).is_empty(), "split")
	MapCells.link(written, cells.index_path)
	return written


## Starts the game on `map` (with the test district as a second map) with
## the visibility ranges `ranges` (none: the "none" profile, every cell);
## `streaming` false loads it whole.
func _start(map: MapDefinition, ranges := {}, streaming := true) -> void:
	if game:
		game.queue_free()
		await process_frames(2)
	var registry := MapRegistry.new()
	registry.definitions.assign([map, load("res://maps/test_district/test_district.tres")])
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.maps = registry
	game.requested_map = map.id
	game.get_node("WorldManager").streaming = streaming
	add_node(game)
	await process_frames(2)
	if not ranges.is_empty():
		game.apply_perf_experiment(PerfConfig.from_dict({"experiment": "streaming_test", "visibility_end": ranges}))
		await process_frames(2)


## Map nodes Godot would draw with the camera where it is: a mesh, visible,
## and its centre within its category's visibility range (if it has one).
func _drawn(ranges: Dictionary) -> Array:
	var camera: Vector3 = game.camera_rig.camera.global_position
	var rules: CategoryRules = game.map_definition.category_rules
	var drawn := []
	for node: MeshInstance3D in game.world.map_root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree():
			continue
		var range_end: float = ranges.get(rules.category_of(node), 0.0)
		var center := (node.global_transform * node.mesh.get_aabb()).get_center()
		if range_end <= 0.0 or camera.distance_to(center) <= range_end:
			drawn.append(str(game.world.map_root.get_path_to(node)))
	drawn.sort()
	return drawn


## Moves the player along x from `from` to `to` at `speed` m/s of game time
## (on the ground at z = 30), frame by frame; returns the most frames in a row
## with a needed cell missing.
func _travel(from: float, to: float, speed: float) -> int:
	var worst := 0
	var row := 0
	var x := from
	var direction := signf(to - from)
	game.player.teleport(Transform3D(Basis.IDENTITY, Vector3(from, 0.5, 30)))
	game.camera_rig.snap_behind_target()
	await process_frames(1)
	while (to - x) * direction > 0.0:
		await tree.process_frame
		x += direction * speed * game.get_process_delta_time()
		game.player.global_position = Vector3(x, 0.5, 30)
		row = row + 1 if game.world.streamer.missing_cells() > 0 else 0
		worst = maxi(worst, row)
	return worst


func test_a_streamed_map_loads_its_resident_scene_and_streams() -> void:
	definition = _map()
	await _start(definition)
	var streamer: MapStreamer = game.world.streamer
	check(streamer != null, "a streamer for the map")
	check(game.world.map_root.scene_file_path == streamer.index.resident_scene, "the resident scene was loaded, not the map scene")
	check(streamer.stats().loaded == streamer.index.cell_count() and streamer.missing_cells() == 0, "no visibility range (profile none): every cell")
	game.apply_perf_experiment(PerfConfig.from_dict({"experiment": "streaming_test", "visibility_end": RANGES}))
	await process_frames(3)
	check(streamer.stats().loaded < streamer.index.cell_count(), "25 m ranges: the far cells are freed (%d of %d loaded)" % [streamer.stats().loaded, streamer.index.cell_count()])
	check(streamer.missing_cells() == 0, "nothing in range missing")
	check(game.hud.streaming_text().begins_with("cells %d/%d" % [streamer.stats().loaded, streamer.index.cell_count()]), "the overlay shows it: %s" % game.hud.streaming_text())


func test_walking_and_driving_keep_every_needed_cell_loaded() -> void:
	definition = _map()
	await _start(definition, RANGES)
	# Five times as fast as real time (game time and speeds unchanged).
	Engine.time_scale = 5.0
	var walking_out: int = await _travel(-95, 95, 4.5)
	var walking_back: int = await _travel(95, -95, 4.5)
	var driving_out: int = await _travel(-95, 95, 20.0)
	var driving_back: int = await _travel(95, -95, 20.0)
	Engine.time_scale = 1.0
	check(walking_out == 0 and walking_back == 0, "walking both ways: never a needed cell missing (%d, %d frames)" % [walking_out, walking_back])
	check(driving_out == 0 and driving_back == 0, "driving at 20 m/s both ways: never a needed cell missing (%d, %d frames)" % [driving_out, driving_back])
	check(game.world.streamer.totals.loads > game.world.streamer.index.cell_count(), "cells were loaded and freed on the way (%d loads)" % game.world.streamer.totals.loads)


func test_what_is_drawn_is_the_same_with_and_without_streaming() -> void:
	definition = _map()
	var points := [Vector3(-90, 0.5, 30), Vector3(0, 0.5, 30), Vector3(80, 0.5, 45), Vector3(-5, 0.5, 40), Vector3(60, 0.5, -10)]
	var seen := {}
	for streaming in [true, false]:
		await _start(definition, RANGES, streaming)
		check((game.world.streamer != null) == streaming, "streaming %s" % streaming)
		var views := []
		for point: Vector3 in points:
			game.player.teleport(Transform3D(Basis.IDENTITY, point))
			game.camera_rig.snap_behind_target()
			await process_frames(2)
			views.append(_drawn(RANGES))
		seen[streaming] = views
	for i in points.size():
		check(seen[true][i] == seen[false][i], "at %s the same meshes are drawn (%d streamed, %d whole)" % [points[i], seen[true][i].size(), seen[false][i].size()])
	check(seen[false].any(func(view: Array) -> bool: return view.any(func(path: String) -> bool: return path.contains("Tree_"))), "the views include streamed meshes")


func test_route_benchmark_records_streaming() -> void:
	definition = _map()
	await _start(definition, RANGES)
	var config := PerfConfig.from_dict({"experiment": "route_test", "visibility_end": RANGES, "bench": {"warmup_s": 0.2,
			"screenshots": false, "quit_when_done": false, "trace": true, "route_speed": 60.0, "route": [[-95, 0.5, 30], [95, 0.5, 30]]}})
	var bench: PerfBenchmark = game.apply_perf_experiment(config)
	var results: Array = await bench.finished
	check(results.size() == 2 and results[0].view == "Route out" and results[1].view == "Route back", "one result per direction")
	for result: Dictionary in results:
		var streaming: Dictionary = result.get("streaming", {})
		check(is_equal_approx(result.route_m, 190.0), "route length recorded")
		check(streaming.get("loads", 0) > 0 and streaming.get("unloads", 0) > 0, "%s: cells loaded and freed on the way (%s)" % [result.view, streaming])
		check(streaming.get("missing_frames", -1) == 0, "%s: no frame with a needed cell missing" % result.view)
		check(not (result.trace.cells as Array).is_empty(), "%s: the trace lists the frames with attached cells" % result.view)
	check(game.player.global_position.distance_to(Vector3(-95, 0.5, 30)) < 2.0, "the player ends where the route began")
	check(game.player.is_physics_processing(), "the player's physics is back on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))


func test_a_map_without_an_index_loads_whole() -> void:
	definition = _map()
	await _start(load("res://maps/test_district/test_district.tres"))
	check(game.world.streamer == null and game.world.map_root.scene_file_path == "res://maps/test_district/test_district.tscn", "the test district has no index: whole, as before")
	var unlinked := definition.duplicate() as MapDefinition
	unlinked.streaming_index_path = ""
	await _start(unlinked)
	check(game.world.streamer == null and game.world.map_root.scene_file_path == definition.scene_path, "no streaming_index_path: whole")
	check((game.world.map_root.get_node("Model/Tree_-90") as MeshInstance3D).mesh != null, "with every mesh")
	await _start(definition, {}, false)
	check(game.world.streamer == null and game.world.map_root.scene_file_path == definition.scene_path, "streaming off (measurement): whole")


## As in a release package: the map's cells are there, its model (the GLB) is not.
func test_a_map_without_its_model_starts_from_its_cells() -> void:
	definition = _map()
	var model := DIR.path_join("model.scn")
	definition.required_files.assign([model])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model))
	check(definition.is_available() and not definition.has_required_files(), "available through its index alone")
	var registry := MapRegistry.new()
	registry.definitions.assign([definition, load("res://maps/test_district/test_district.tres")])
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.maps = registry
	add_node(game)
	await process_frames(2)
	check(game.map_definition == definition and game.world.streamer != null, "no map requested: the default, streamed (%s)" % game.map_definition.id)
	check(game.world.map_root.scene_file_path == game.world.streamer.index.resident_scene and game.world.streamer.missing_cells() == 0, "its resident scene and every needed cell")
	await _start(definition, {}, false)
	check(game.world.streamer != null, "streaming off cannot load it whole, so it streams")


func test_a_map_switch_frees_the_cells() -> void:
	definition = _map()
	await _start(definition, RANGES)
	var nodes_before: int = game.get_tree().get_node_count()
	var streamer: MapStreamer = game.world.streamer
	var loaded_paths := []
	for cell in streamer.index.cell_count():
		if streamer.is_loaded(cell):
			loaded_paths.append(streamer.index.cell_paths[cell])
	check(not loaded_paths.is_empty(), "cells loaded before the switch")
	var switched: bool = await game.switch_map(load("res://maps/test_district/test_district.tres"))
	check(switched and not is_instance_valid(streamer), "switched; the streamer is freed with the map")
	check(game.hud.streamer == null and game.hud.streaming_text() == "cells off", "the overlay lets go of it")
	var gone := MapStreamer.new()
	game.hud.streamer = gone
	gone.free()
	check(game.hud.streaming_text() == "cells off", "and a streamer freed under it reads as none")
	game.hud.streamer = null
	check(not loaded_paths.any(func(path: String) -> bool: return ResourceLoader.has_cached(path)), "no cell is held any more")
	switched = await game.switch_map(definition)
	await process_frames(2)
	check(switched and game.world.streamer != null and game.world.streamer.missing_cells() == 0, "back: streaming again, nothing missing")
	check(game.get_tree().get_node_count() == nodes_before, "node count as before the switches (%d, %d)" % [game.get_tree().get_node_count(), nodes_before])


func test_a_teleport_or_respawn_loads_the_cells_before_the_frame() -> void:
	definition = _map()
	await _start(definition, RANGES)
	var streamer: MapStreamer = game.world.streamer
	var primes: int = streamer.totals.primes
	game.player.teleport(Transform3D(Basis.IDENTITY, Vector3(-90, 0.5, 30)))
	game.camera_rig.snap_behind_target()
	# The camera follows the player's interpolated transform, which moves at
	# the next physics tick; the streamer processes after the camera.
	await _until_camera_moved(Vector3(-90, 0.5, 30))
	check(streamer.totals.primes == primes + 1 and streamer.missing_cells() == 0, "a teleport: loaded in the camera's first frame there")
	game.player.global_position = Vector3(-90, -20, 30)
	await tree.physics_frame
	await _until_camera_moved(definition.player_spawn_position)
	check(game.player.global_position.distance_to(definition.player_spawn_position) < 1.0, "fell below the kill height and respawned")
	check(streamer.totals.primes == primes + 2 and streamer.missing_cells() == 0, "the respawn: loaded in the camera's first frame there")


## Waits frame by frame until the camera is within 10 m of `point`
## (horizontally), checking after each frame that the streamer kept up.
func _until_camera_moved(point: Vector3) -> void:
	for i in 10:
		await tree.process_frame
		var camera: Vector3 = game.camera_rig.camera.global_position
		check(game.world.streamer.missing_cells() == 0, "frame %d: nothing missing" % i)
		if Vector2(camera.x - point.x, camera.z - point.z).length() < 10.0:
			return
	check(false, "the camera reached %s" % point)


func test_the_default_map_streams_what_its_profiles_draw() -> void:
	var map := load(DEFAULT_MAP) as MapDefinition
	if not map.has_required_files() or MapStreamingIndex.load_for(map) == null:
		skip("needs the default map's GLB and its cells (tools/cell_map.gd)")
		return
	var seen := {}
	for streaming in [true, false]:
		await _start(map, {}, streaming)
		var views := []
		for profile in ["low", "high"]:
			var effective: Dictionary = game.set_quality_profile(profile)
			for view in game.get_view_names().size():
				game.show_debug_view(view)
				await process_frames(2)
				views.append(_drawn(effective.visibility_end))
				if streaming:
					check(game.world.streamer.missing_cells() == 0, "%s, %s: nothing missing" % [profile, game.get_view_names()[view]])
		seen[streaming] = views
	for i in seen[true].size():
		check(seen[true][i] == seen[false][i], "view %d: the same meshes are drawn (%d streamed, %d whole)" % [i, seen[true][i].size(), seen[false][i].size()])


func test_the_registry_maps_cells_are_current() -> void:
	var checked := []
	for map in MapRegistry.load_default().definitions:
		if map.streaming_index_path.is_empty() or not ResourceLoader.exists(map.streaming_index_path):
			continue
		var index := load(map.streaming_index_path) as MapStreamingIndex
		check(index.problem().is_empty(), "%s: its cells are current (%s)" % [map.id, index.problem()])
		check(map.streaming_index_path == map.resource_path.get_base_dir().path_join("streaming/%s_index.tres" % map.id), "%s: index beside the map" % map.id)
		checked.append(map.id)
	if checked.is_empty():
		skip("no map's cells are written here (tools/cell_map.gd -- --all)")
		return
	print("cells current: ", checked)
