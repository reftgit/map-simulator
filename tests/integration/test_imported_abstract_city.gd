extends "res://tests/integration/imported_map_case.gd"
## The abstract city of the Phase 6b blind test (Keenan Crane, public
## domain) as the import tool made it: maps/abstract_city/, from the
## converted GLB in maps/abstract_city/source/ with "scale": 100 (the tool's
## own suggestion). The whole city came as one mesh; the tool split it into
## its 219 objects and classified them by shape.


func definition_path() -> String:
	return "res://maps/abstract_city/abstract_city.tres"


func regenerate_hint() -> String:
	return "run tools/import_map.gd as in docs/maps/imported/abstract_city.md"


func expected_categories() -> Dictionary:
	return {"": 3, "buildings": 203, "decor": 13, "ground": 1}


func test_registered_and_selectable() -> void:
	var registry := MapRegistry.load_default()
	check(registry.find("abstract_city") != null and registry.find("abstract_city").is_available(), "abstract_city in the registry and available")
	check(registry.definitions[0].id == "istanbul_halic_cells_shader", "the default is unchanged")


func test_city_was_split_into_its_objects() -> void:
	await _setup()
	var model: Node = game.world.map_root.get_node("Model")
	check(not model.has_node("city") and model.has_node("city_000") and model.has_node("city_218"), "one mesh per object (city_000 … city_218)")
	var block := model.get_node("city_100") as MeshInstance3D
	check(block.has_node("StaticBody3D"), "each building object has its own collider")


func test_device_scenario_extensibility_switching_directly() -> void:
	# The generalized extensibility scenario on a blind-test map: straight to
	# the test district and back, then the vehicle_sleep steps on the city.
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
	check(game.map_definition.id == "abstract_city", "back on the city at the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfBenchmark.RESULTS_PATH))
