extends "res://tests/test_case.gd"
## The render categories moved from RenderSettings into each map's
## CategoryRules (2026-11-02). On every map of the registry before Phase 6a,
## each mesh keeps the category the old prefix table gave it, the occluder
## categories are the same, and the low profile's fog takes the same colour.
## A map whose GLB is missing is skipped.

const Legacy := preload("res://tests/fixtures/legacy_categories.gd")


func test_istanbul_halic() -> void:
	await _check_map("istanbul_halic", 3055)


func test_istanbul_halic_cells() -> void:
	await _check_map("istanbul_halic_cells", 6129)


func test_istanbul_halic_cells_light() -> void:
	await _check_map("istanbul_halic_cells_light", 6129)


func test_istanbul_halic_cells_shader() -> void:
	await _check_map("istanbul_halic_cells_shader", 6129)


func test_test_district() -> void:
	await _check_map("test_district", 16)


func _check_map(id: String, meshes: int) -> void:
	var definition := MapRegistry.load_default().find(id)
	check(definition != null and definition.category_rules != null, "%s has category rules" % id)
	if definition == null or definition.category_rules == null:
		return
	if not definition.is_available():
		skip("%s: map files missing" % id)
		return
	var rules := definition.category_rules
	check(rules.validate().is_empty(), "rules valid: %s" % [rules.validate()])
	check(str(rules.occluder_categories) == str(Legacy.OCCLUDER_CATEGORIES), "occluder categories %s" % [rules.occluder_categories])
	var map: Node3D = add_node((load(definition.scene_path) as PackedScene).instantiate())
	var changed: Array[String] = []
	var counts := {}
	var nodes := map.find_children("*", "MeshInstance3D", true, false)
	for node in nodes:
		var category := rules.category_of(node)
		if category != Legacy.category_of(node.name):
			changed.append("%s: %s -> %s" % [node.name, Legacy.category_of(node.name), category])
		counts[category] = counts.get(category, 0) + 1
	check(nodes.size() == meshes, "%d meshes (%d)" % [meshes, nodes.size()])
	check(changed.is_empty(), "every mesh keeps its category; changed: %s" % [changed.slice(0, 10)])
	print("     %s categories: %s" % [id, counts])

	var saved_fps := Engine.max_fps
	var viewport := SubViewport.new()
	add_node(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var settings := RenderSettings.new(map, camera, viewport, definition.occluders_path, rules)
	settings.apply(QualityProfiles.settings_for("low"))
	var environment := (map.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(environment.fog_enabled and environment.fog_light_color.is_equal_approx(Legacy.FOG_COLOR),
			"low profile fog colour as before: %s" % environment.fog_light_color)
	settings.apply({})
	Engine.max_fps = saved_fps
