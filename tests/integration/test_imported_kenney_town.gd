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
