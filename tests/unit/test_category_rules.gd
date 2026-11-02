extends "res://tests/test_case.gd"
## CategoryRules (a map's render categories, 2026-11-02): rule kinds, order,
## the default category, validation, word splitting, and that RenderSettings
## holds no map-specific names any more.

const Legacy := preload("res://tests/fixtures/legacy_categories.gd")


func _mesh(node_name: String, material_name := "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = BoxMesh.new()
	if not material_name.is_empty():
		var material := StandardMaterial3D.new()
		material.resource_name = material_name
		node.mesh.surface_set_material(0, material)
	add_node(node)
	return node


func _rules(lines: Array) -> CategoryRules:
	var rules := CategoryRules.new()
	for line: Array in lines:
		rules.rules.append(CategoryRule.create(line[0], line[1], line[2]))
	return rules


func test_rule_kinds() -> void:
	var rules := _rules([
		["water", "group", "map_category_water"],
		["facade_detail", "material", "(?i)^window$"],
		["lamps", "regex", "^Light\\d+$"],
		["buildings", "prefix", "House_"],
		["ground", "words", "road terrain"],
	])
	var pond := _mesh("Thing_1")
	pond.add_to_group("map_category_water", true)
	check(rules.category_of(pond) == "water", "group rule")
	check(rules.category_of(_mesh("Panel_3", "Window")) == "facade_detail", "material rule")
	check(rules.category_of(_mesh("Light12")) == "lamps", "regex rule")
	check(rules.category_of(_mesh("Light12b")) == "", "regex is anchored as written")
	check(rules.category_of(_mesh("House_4")) == "buildings", "prefix rule")
	check(rules.category_of(_mesh("osm_road_17")) == "ground", "word rule")
	check(rules.category_of(_mesh("TerrainBase")) == "ground", "word rule on a camel-case name")
	check(rules.category_of(_mesh("Railroad_2")) == "", "a word must start with the listed word")
	check(rules.category_of(_mesh("Unknown")) == "", "no match and no default: no category")
	rules.default_category = "decor"
	check(rules.category_of(_mesh("Unknown2")) == "decor", "default category")


func test_first_rule_wins() -> void:
	var rules := _rules([["decor", "prefix", "Galata_Bridge_Detail"], ["ground", "prefix", "Galata_Bridge"]])
	check(rules.category_of(_mesh("Galata_Bridge_Detail")) == "decor", "earlier rule first")
	check(rules.category_of(_mesh("Galata_Bridge")) == "ground", "later rule for the rest")


func test_meshes_by_category_has_every_category() -> void:
	var root := Node3D.new()
	add_node(root)
	for node_name in ["House_1", "House_2", "Other"]:
		var mesh := MeshInstance3D.new()
		mesh.name = node_name
		root.add_child(mesh)
	var groups := _rules([["buildings", "prefix", "House_"]]).meshes_by_category(root)
	check(groups.keys().size() == CategoryRules.CATEGORIES.size(), "a key per category")
	check(groups.buildings.size() == 2 and groups.ground.is_empty(), "two buildings, the rest in no category")


func test_validate() -> void:
	var rules := _rules([["buildings", "prefix", "A"], ["roofs", "prefix", "B"]])
	rules.default_category = "props"
	rules.occluder_categories = ["buildings", "walls"]
	var problems := rules.validate()
	check(problems.size() == 3, "unknown rule category, default, occluder category: %s" % [problems])
	check(_rules([["water", "words", "sea"]]).validate().is_empty(), "valid rules")


func test_words_of() -> void:
	check(CategoryRules.words_of("osm_12_walls") == PackedStringArray(["osm", "walls"]), "underscores and digits split")
	check(CategoryRules.words_of("StreetLamps_03") == PackedStringArray(["street", "lamps"]), "case change splits")
	check(CategoryRules.words_of("road-sign-stop") == PackedStringArray(["road", "sign", "stop"]), "hyphens split")
	check(CategoryRules.words_of("HTMLPage") == PackedStringArray(["htmlpage"]), "only lower-to-upper splits")
	check(CategoryRules.words_of("_42_") == PackedStringArray(), "no letters, no words")


func test_istanbul_rules_match_the_legacy_table() -> void:
	var rules := load("res://maps/istanbul_halic/istanbul_halic_categories.tres") as CategoryRules
	var names := ["Detail_13_07_1_2", "MosqueDetail_1564032", "LandmarkDetail_23236783", "Galata_Bridge_Detail", "Halic_Metro_Bridge_Detail",
			"BridgeDetail_3", "BridgeGlass_1", "RoadPaint_3_4", "TrafficSignals_1_1", "SignalGlow_red", "Ferry_28_9784_41_0201",
			"StreetLamps_1_2", "LampGlow_Bridge", "Trees_1_2_3_4", "TreeTrunks_1_2", "Shrubs_1_2", "Buildings_1_2", "Mosque_1564032",
			"Landmark_23236783", "Ground_1_2", "Road_1_2", "Pavement_1_2", "Quays_1_2", "Gardens_1_2", "Galata_Bridge",
			"Halic_Metro_Bridge", "Ataturk_Bridge_Deck", "Water", "Sun", "Model"]
	for node_name: String in names:
		var category := rules.category_of(_mesh(node_name))
		check(category == Legacy.category_of(node_name), "%s -> %s (got %s)" % [node_name, Legacy.category_of(node_name), category])
	var test_district := load("res://maps/test_district/test_district_categories.tres") as CategoryRules
	for node_name: String in ["Ground_Base", "Road_NorthSouth", "Ground_Ramp", "Buildings_NW1", "Buildings_Wall_East"]:
		check(test_district.category_of(_mesh(node_name)) == Legacy.category_of(node_name), "test district %s" % node_name)


## Acceptance check of Phase 6a: no map's names are built into RenderSettings.
func test_render_settings_has_no_map_specific_names() -> void:
	var source := FileAccess.get_file_as_string("res://game/quality/render_settings.gd")
	var found: Array[String] = []
	for category in Legacy.CATEGORIES:
		for prefix: String in Legacy.CATEGORIES[category]:
			if source.contains('"%s' % prefix):
				found.append(prefix)
	for word in ["Galata", "Halic", "Ataturk", "Istanbul", "İstanbul", "0.843137"]:
		if source.contains(word):
			found.append(word)
	check(found.is_empty(), "RenderSettings names no map's meshes or colours: %s" % [found])
	check(not source.contains("const CATEGORIES") and not source.contains("const OCCLUDER_CATEGORIES") and not source.contains("const FOG_COLOR"),
			"the category table, occluder categories, and fog colour constant are gone")
