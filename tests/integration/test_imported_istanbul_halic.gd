extends "res://tests/integration/imported_map_case.gd"
## The shipped assets/istanbul_halic.glb imported by the tool under a test id
## (Phase 6a robustness check; it does not replace İstanbul • Haliç): the
## tool must use its -col nodes, so the collision and the occluders equal the
## shipped map's. Output in tests/imported/istanbul_halic_import/ (out of Git
## and of every export); skipped without it.

const Legacy := preload("res://tests/fixtures/legacy_categories.gd")


func definition_path() -> String:
	return "res://tests/imported/istanbul_halic_import/istanbul_halic_import.tres"


func regenerate_hint() -> String:
	return "import assets/istanbul_halic.glb as in docs/maps/imported/istanbul_halic_import.md"


func expected_categories() -> Dictionary:
	return {"buildings": 371, "decor": 299, "facade_detail": 371, "ground": 1031, "lamps": 517, "trees": 465, "water": 1}


func test_collision_and_categories_equal_the_shipped_map() -> void:
	await _setup()
	var model: Node = game.world.map_root.get_node("Model")
	var bodies := model.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() == 827, "the 827 -col bodies of the shipped map (%d)" % bodies.size())
	var triangles := 0
	for body in bodies:
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			check(shape.shape is ConcavePolygonShape3D, "%s: trimesh, as Godot's importer makes it" % body.get_parent().name)
			triangles += (shape.shape as ConcavePolygonShape3D).get_faces().size() / 3
	check(triangles == 438012, "438,012 collision triangles, as the shipped map (%d)" % triangles)
	var changed: Array[String] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if definition.category_rules.category_of(node) != Legacy.category_of(node.name):
			changed.append(str(node.name))
	check(changed.is_empty(), "every mesh in the category the shipped map gives it: %s" % [changed.slice(0, 10)])
	var occluders: Node = (load(definition.occluders_path) as PackedScene).instantiate()
	var stats := RenderSettings.occluder_stats(occluders)
	check(stats.instances == 643 and stats.triangles == 317518, "the occluders of the shipped map's bake: %s" % [stats])
	occluders.free()
