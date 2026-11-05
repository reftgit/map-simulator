extends "res://tests/test_case.gd"
## Loading on threads behind the loading screen (Phase 6e): the game's start
## and a map switch with Main.threaded_loading on, as with a RenderingDevice.
## Headless runs load at once by default; these tests turn the threaded path
## on with fixture maps that have no meshes (the dummy renderer of headless
## runs makes meshes only on the main thread; docs/STREAMING.md).

const MAX_FRAMES := 900

var game: Node
var registry: MapRegistry


func _fixture(id: String, spawn: Vector3) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.id = id
	definition.scene_path = "res://tests/fixtures/flat_map.tscn"
	definition.player_spawn_position = spawn
	definition.bounds = Rect2(-20, -20, 40, 40)
	return definition


## The game on fixture maps, loading on threads; not yet in the tree.
func _game() -> Node:
	registry = MapRegistry.new()
	registry.definitions.assign([_fixture("fixture_a", Vector3(2, 0.1, 3)), _fixture("fixture_b", Vector3(-4, 0.1, -5))])
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.maps = registry
	game.threaded_loading = true
	return game


## Waits until the game is not switching (its load is done); the frames it
## took, counting how many of them showed the loading screen.
func _until_loaded() -> Dictionary:
	var frames := 0
	var shown := 0
	while game.switching and frames < MAX_FRAMES:
		await process_frames(1)
		frames += 1
		shown += int(game.hud.is_loading())
	return {"frames": frames, "shown": shown}


func test_the_start_loads_behind_a_moving_loading_screen() -> void:
	_game()
	var changed: Array[String] = []
	game.map_changed.connect(func(definition: MapDefinition) -> void: changed.append(definition.id))
	add_node(game)
	check(game.switching and game.hud.is_loading() and not game.hud.input.visible, "the loading screen is up from the first frame, no controls")
	check(game.world.loading != null and game.world.map_root == null, "the map is read on threads, not there yet")
	check(game.player.process_mode == Node.PROCESS_MODE_DISABLED, "the player waits (it would fall without a map)")
	var frames := 0
	while game.switching and frames < MAX_FRAMES:
		await process_frames(1)
		frames += 1
	check(not game.switching and game.map_definition.id == "fixture_a", "loaded (%d frames)" % frames)
	await process_frames(2)
	check(not game.hud.is_loading() and game.hud.input.visible, "the loading screen gone, the controls back")
	check(game.player.process_mode == Node.PROCESS_MODE_INHERIT and game.player.global_position.distance_to(Vector3(2, 0.1, 3)) < 0.5, "the player at the spawn (%s)" % game.player.global_position)
	check(game.world.map_root.name == &"FlatMap" and game.render_settings != null, "the map and its render settings")
	check(changed == (["fixture_a"] as Array[String]), "map_changed once (%s)" % [changed])
	var report: Dictionary = game.loading_frames.report
	check(report.kind == "start" and report.threaded and report.loaded and report.frames >= 1, "LOADING record (%s)" % [report])
	check(report.steps_ms.has("read") and report.steps_ms.has("add") and report.steps_ms.has("profile") and report.steps_ms.has("show_map"), "the steps ran (%s)" % [report.steps_ms])
	check(game.startup.get("loading", {}).get("kind", "") == "start", "STARTUP carries the record")


func test_a_switch_loads_behind_the_screen_with_one_map_at_a_time() -> void:
	_game()
	add_node(game)
	await _until_loaded()
	var old_root: int = game.world.map_root.get_instance_id()
	var old_alive_when_new_entered := []
	game.world.child_entered_tree.connect(func(node: Node) -> void:
		if node.name == &"FlatMap" and node.get_instance_id() != old_root:
			old_alive_when_new_entered.append(is_instance_id_valid(old_root)))
	var switched: Array = []
	var switch := func() -> void: switched.append(await game.switch_map(registry.find("fixture_b")))
	switch.call()
	check(game.switching and game.hud.is_loading() and not game.hud.input.visible, "the loading screen up, no controls")
	check(not (await game.switch_map(registry.find("fixture_a"))), "a second switch while one runs is refused")
	var waited: Dictionary = await _until_loaded()
	check(switched == [true] and game.map_definition.id == "fixture_b", "switched (%s)" % [waited])
	check(old_alive_when_new_entered == [false], "the old map was freed before the new one entered the tree (%s)" % [old_alive_when_new_entered])
	await process_frames(2)
	check(not game.hud.is_loading() and game.hud.input.visible, "the loading screen gone")
	check(game.player.global_position.distance_to(Vector3(-4, 0.1, -5)) < 0.5, "the player at the new spawn (%s)" % game.player.global_position)
	var report: Dictionary = game.loading_frames.report
	check(report.kind == "switch" and report.map == "fixture_b", "LOADING record of the switch (%s)" % [report])


func test_the_start_is_refused_a_switch_and_finishes_when_paused() -> void:
	_game()
	add_node(game)
	check(not (await game.switch_map(registry.find("fixture_b"))), "no switch while the first map loads")
	tree.paused = true
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var waited: Dictionary = await _until_loaded()
	check(not game.switching and game.map_definition.id == "fixture_a", "the load finished with the game paused and out of focus (%s)" % [waited])
	tree.paused = false
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frames(2)
	check(not game.hud.is_loading() and game.hud.input.visible and game.player.process_mode == Node.PROCESS_MODE_INHERIT, "playable after")
