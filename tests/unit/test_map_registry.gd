extends "res://tests/test_case.gd"
## The map registry and how the game picks its map at startup (Phase 5):
## the first map by default and always in normal release builds, another by
## id in debug and Release Perf builds.

const GAME_SCRIPT := preload("res://game/game.gd")


func cleanup() -> void:
	BuildFeatures.reset_overrides()
	await super()


func _fixture_definition(id: String) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.id = id
	definition.scene_path = "res://tests/fixtures/flat_map.tscn"
	return definition


## A game node outside the tree with `registry`: only _initial_map() is used.
func _game_with(registry: MapRegistry) -> Node:
	var game: Node = GAME_SCRIPT.new()
	game.maps = registry
	return game


func test_registry_lists_the_maps() -> void:
	var registry := MapRegistry.load_default()
	check(registry != null and not registry.definitions.is_empty(), "registry loads with maps")
	check(registry.default_map().id == "istanbul_halic", "İstanbul • Haliç is the default (%s)" % registry.default_map().id)
	var seen := {}
	for definition in registry.definitions:
		check(not definition.id.is_empty() and not seen.has(definition.id), "unique, non-empty id (%s)" % definition.id)
		seen[definition.id] = true
		check(FileAccess.file_exists(definition.scene_path), "%s: scene file exists (%s)" % [definition.id, definition.scene_path])
		var spawn := definition.player_spawn_position
		check(definition.bounds.has_point(Vector2(spawn.x, spawn.z)), "%s: spawn inside the bounds" % definition.id)
		check(definition.kill_height < spawn.y, "%s: kill height below the spawn" % definition.id)
	var main := FileAccess.get_file_as_string("res://game/main.tscn")
	check(main.contains(MapRegistry.PATH), "the game scene uses the registry")


func test_find_next_and_arguments() -> void:
	var registry := MapRegistry.new()
	var first := _fixture_definition("first")
	var second := _fixture_definition("second")
	registry.definitions.assign([first, second])
	check(registry.find("second") == second and registry.find("third") == null, "find by id")
	check(registry.ids() == (["first", "second"] as Array[String]), "ids in order")
	check(registry.next_after(first) == second and registry.next_after(second) == first, "next wraps around")
	check(registry.next_after(_fixture_definition("elsewhere")) == first, "a map outside the list is followed by the first")
	check(MapRegistry.id_from_args(PackedStringArray(["--quality=low", "--map=second"])) == "second", "--map=<id> read")
	check(MapRegistry.id_from_args(PackedStringArray(["--quality=low"])) == "", "no --map")


func test_startup_map_choice() -> void:
	var registry := MapRegistry.new()
	registry.definitions.assign([_fixture_definition("first"), _fixture_definition("second")])
	var game := _game_with(registry)
	var args := PackedStringArray(["--map=second"])
	BuildFeatures.debug_override = 1
	check(game._initial_map(PackedStringArray()).id == "first", "debug, no argument: the first map")
	check(game._initial_map(args).id == "second", "debug: --map picks the map")
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 1
	check(game._initial_map(args).id == "second", "Release Perf: --map picks the map")
	game._experiment = PerfConfig.new()
	game._experiment.map = "first"
	check(game._initial_map(args).id == "first", "an experiment's map wins over --map")
	game._experiment = null
	BuildFeatures.perf_feature_override = 0
	check(game._initial_map(args).id == "first", "normal release: always the first map")
	game.requested_map = "second"
	check(game._initial_map(PackedStringArray()).id == "second", "requested_map (tests) picks the map")
	game.free()


func test_unknown_map_argument_falls_back_to_the_default() -> void:
	var registry := MapRegistry.new()
	registry.definitions.assign([_fixture_definition("first"), _fixture_definition("second")])
	var game := _game_with(registry)
	BuildFeatures.debug_override = 1
	check(game._initial_map(PackedStringArray(["--map=nowhere"])).id == "first", "unknown id: the first map")
	game.free()


func test_experiment_map_key() -> void:
	var config := PerfConfig.from_dict({"experiment": "map_key", "map": "istanbul_halic"})
	check(config != null and config.map == "istanbul_halic", "known map accepted")
	check(config.to_dict().map == "istanbul_halic", "map recorded in the result's config")
	check(PerfConfig.from_dict({"experiment": "default_map"}).map == "", "no key: default map")
	check(PerfConfig.from_dict({"map": "nowhere"}) == null and PerfConfig.last_error.contains("unknown map"), "unknown map rejected (%s)" % PerfConfig.last_error)
