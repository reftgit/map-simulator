extends "res://tests/integration/imported_map_case.gd"
## The CC0 Kenney town (Phase 6a) as the import tool made it: maps/kenney_town/,
## from maps/kenney_town/source/kenney_town.glb with scale 10.


func definition_path() -> String:
	return "res://maps/kenney_town/kenney_town.tres"


func regenerate_hint() -> String:
	return "run tools/import_map.gd as in docs/maps/imported/kenney_town.md"


func expected_categories() -> Dictionary:
	return {"buildings": 32, "decor": 32, "ground": 144, "lamps": 20, "trees": 41}


func test_registered_and_selectable() -> void:
	var registry := MapRegistry.load_default()
	check(registry.find("kenney_town") != null and registry.find("kenney_town").is_available(), "kenney_town in the registry and available")
	check(registry.definitions[0].id == "istanbul_halic_cells_shader", "the default is unchanged")


func test_device_scenario_extensibility_switching_directly() -> void:
	# The generalized extensibility scenario from an imported map: straight to
	# the test district (scenario maps) and back, then the vehicle_sleep steps
	# on the town.
	await _setup()
	var config := PerfConfig.from_dict({"experiment": "scenario_test", "scenario": {"name": "extensibility", "maps": ["test_district"], "quit_when_done": false}})
	var scenario: DeviceScenario = game.start_scenario(config)
	var results: Array = await scenario.finished
	var steps: Array[String] = []
	for result: Dictionary in results:
		steps.append(result.step)
		check(result.result != "FAIL", "%s: %s (%s)" % [result.step, result.result, result.detail])
	for step in ["map_switch", "van_get_in", "van_throttle", "npc_hit_reaction", "npc_patrol_resumes", "map_back", "parked_car_asleep", "get_out", "slope_skipped", "done"]:
		check(step in steps, "step %s ran" % step)
	check(game.map_definition.id == "kenney_town", "back on the town at the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))
