extends SceneTree
## Bakes a map's occluders once into the scene named by its MapDefinition's
## occluders_path. The geometry is what RenderSettings would otherwise build
## at load: one ArrayOccluder3D per collision shape of the map's occluder
## categories (CategoryRules.occluder_categories: buildings and ground), with
## shared vertices merged. Run after the map changes.
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/bake_occluders.gd [-- --map=res://maps/<name>/<name>.tres] [--out=<path>]
## --out writes elsewhere instead (e.g. to compare a map's bake with a shared file).

const DEFAULT_MAP := "res://maps/istanbul_halic/istanbul_halic.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map_path := DEFAULT_MAP
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_path = arg.trim_prefix("--map=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var definition := load(map_path) as MapDefinition
	if definition == null or definition.occluders_path.is_empty():
		printerr("No MapDefinition with occluders_path at ", map_path)
		quit(1)
		return
	if out.is_empty():
		out = definition.occluders_path
	var map := (load(definition.scene_path) as PackedScene).instantiate()
	root.add_child(map)
	await physics_frame
	var started := Time.get_ticks_msec()
	var rules := definition.category_rules if definition.category_rules else CategoryRules.new()
	var holder := RenderSettings.build_occluders(map, rules.meshes_by_category(map), true, rules.occluder_categories)
	for child in holder.get_children():
		child.owner = holder
	var packed := PackedScene.new()
	var error := packed.pack(holder)
	if error == OK:
		error = ResourceSaver.save(packed, out, ResourceSaver.FLAG_COMPRESS)
	var stats := RenderSettings.occluder_stats(holder)
	var vertices := 0
	for instance: OccluderInstance3D in holder.get_children():
		vertices += (instance.occluder as ArrayOccluder3D).vertices.size()
	print("BAKE map=%s occluders=%d triangles=%d vertices=%d file=%s bytes=%d ms=%d error=%d" % [map_path,
			stats.instances, stats.triangles, vertices, out,
			FileAccess.get_file_as_bytes(out).size(), Time.get_ticks_msec() - started, error])
	holder.free()
	quit(0 if error == OK else 1)
