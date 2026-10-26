extends SceneTree
## Counts a map's colliders: static bodies, shapes by type, triangles in
## concave (trimesh) shapes, per map category, and how many bodies and
## triangles lie within 25 / 50 / 100 / 200 m (ground plane) of each
## measurement viewpoint. Measurement aid for the physics cost diagnosis.
##   godot --headless --path . --script res://tools/perf/collider_census.gd [-- --map=res://maps/<name>/<name>.tres]

const DEFAULT_MAP := "res://maps/istanbul_halic/istanbul_halic.tres"
const RADII: Array[float] = [25.0, 50.0, 100.0, 200.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map_path := DEFAULT_MAP
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_path = arg.trim_prefix("--map=")
	var definition := load(map_path) as MapDefinition
	var map := (load(definition.scene_path) as PackedScene).instantiate()
	root.add_child(map)
	await physics_frame
	var by_type := {}
	var by_category := {}
	var entries := []  # [AABB, triangles]
	var total_triangles := 0
	var bodies := map.find_children("*", "StaticBody3D", true, false)
	for body: StaticBody3D in bodies:
		var triangles := 0
		var bounds := AABB()
		var first := true
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var type := shape.shape.get_class()
			by_type[type] = by_type.get(type, 0) + 1
			if shape.shape is ConcavePolygonShape3D:
				triangles += (shape.shape as ConcavePolygonShape3D).get_faces().size() / 3
			var box: AABB = shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var category := RenderSettings.category_of(body.get_parent().name if body.get_parent() else body.name)
		if category.is_empty():
			category = str(body.name).get_slice("_", 0)
		var stats: Dictionary = by_category.get(category, {"bodies": 0, "triangles": 0})
		stats.bodies += 1
		stats.triangles += triangles
		by_category[category] = stats
		entries.append([bounds, triangles])
		total_triangles += triangles
	print("CENSUS bodies=%d shapes=%s concave_triangles=%d" % [bodies.size(), JSON.stringify(by_type), total_triangles])
	print("CENSUS by_category=%s" % JSON.stringify(by_category))
	var views: Array[Transform3D] = [Transform3D(Basis.IDENTITY, definition.player_spawn_position)]
	views.append_array(definition.debug_viewpoints)
	var names: Array[String] = ["Spawn"]
	names.append_array(definition.debug_viewpoint_names)
	for i in views.size():
		var center := views[i].origin
		var near := []
		for radius in RADII:
			var count := 0
			var triangles := 0
			for entry in entries:
				var bounds: AABB = entry[0]
				var nearest := Vector2(clampf(center.x, bounds.position.x, bounds.end.x), clampf(center.z, bounds.position.z, bounds.end.z))
				if nearest.distance_to(Vector2(center.x, center.z)) <= radius:
					count += 1
					triangles += entry[1]
			near.append("%dm: %d bodies, %d triangles" % [radius, count, triangles])
		print("CENSUS near \"%s\": %s" % [names[i] if i < names.size() else str(i), ", ".join(near)])
	map.free()
	quit()
