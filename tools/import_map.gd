extends SceneTree
## Imports a map GLB into the game (rules: docs/MAP_CONTRACT.md): checks the
## map contract, fixes what it can (normals, vertex colours, scale and axes
## when configured), puts every mesh into a render category, builds
## colliders and occluders, places the player spawn, a vehicle, an NPC route,
## and viewpoints, and writes the processed model, the category rules, the
## occluders, the map scene, its MapDefinition, the registry entry, and a report.
##   godot --headless --path . --script res://tools/import_map.gd -- --glb=<file.glb> [--config=<file.json>] [--id=<id>]
##       [--out=res://maps/<id>] [--report=res://docs/maps/imported/<id>.md] [--no-register] [--force]
##       [--compare=<earlier report.md>[,<earlier report.md>…]] [--no-cells]
## --compare puts earlier reports of the same map (a blind run, say) beside
## this one in the report. After writing, the map is split into a resident
## scene and streaming cells (<out>/streaming/, the cell step of
## tools/cell_map.gd; docs/STREAMING.md) unless --no-cells is given.
## The GLB is only read. Exit code 0 when the map was written, 1 when a
## mandatory rule failed (the report says what to fix), 2 for bad arguments.

const MapImporter := preload("res://tools/map_import/map_importer.gd")
const MapPlacement := preload("res://tools/map_import/map_placement.gd")
const MapWriter := preload("res://tools/map_import/map_writer.gd")
const ImportReport := preload("res://tools/map_import/import_report.gd")
const MapCells := preload("res://tools/map_import/map_cells.gd")

## Models larger than this stay out of Git (a .gitignore in the map folder).
const GIT_LIMIT := 10 * 1024 * 1024


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--"):
			args[arg.trim_prefix("--")] = true
	if not args.has("glb"):
		printerr("usage: --glb=<file.glb> [--config=<file.json>] [--id=<id>] [--out=res://maps/<id>] [--report=<path.md>] [--no-register] [--force] [--compare=<report.md>,…] [--no-cells]")
		quit(2)
		return
	var glb := ProjectSettings.globalize_path(str(args.glb))
	var importer := MapImporter.new()
	var config := {}
	if args.has("config"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(str(args.config))))
		if not parsed is Dictionary:
			printerr("IMPORT the configuration is not a JSON object: ", args.config)
			quit(2)
			return
		config = parsed
	var error := importer.parse_config(config)
	if not error.is_empty():
		printerr("IMPORT configuration: ", error)
		quit(2)
		return
	var id := str(args.get("id", config.get("id", _id_from_file(glb))))
	var out := str(args.get("out", "res://maps/%s" % id))
	var report_path := str(args.get("report", "res://docs/maps/imported/%s.md" % id))
	var file := FileAccess.open(glb, FileAccess.READ)
	var info := {"id": id, "source": glb.get_file(), "bytes": file.get_length() if file else 0,
			"sha256": FileAccess.get_sha256(glb), "config": config, "written": false, "outputs": [],
			"command": "godot --headless --path . --script res://tools/import_map.gd -- " + " ".join(_shown_args()),
			"compare": Array(str(args.get("compare", "")).split(",", false))}
	print("IMPORT %s from %s" % [id, glb])
	var scene := importer.load_glb(glb)
	var ok := scene != null and importer.process(scene, args.has("force"))
	if ok:
		root.add_child(importer.model)
		await physics_frame
		await physics_frame
		var placement := _place(importer)
		info.placement = {"lines": placement.lines}
		if not importer.failed() or args.has("force"):
			info.written = _write(importer, placement, id, out, info)
			if info.written and not args.has("no-cells"):
				info.streaming = _cells(out.path_join("%s.tres" % id))
			if info.written and not args.has("no-register"):
				var registered := MapWriter.register(ProjectSettings.globalize_path(MapRegistry.PATH), out.path_join("%s.tres" % id))
				info.registered = registered in ["added", "present"]
				print("IMPORT registry: ", registered)
	info.seconds = (Time.get_ticks_msec() - started) / 1000.0
	_save_text(report_path, ImportReport.markdown(importer, info))
	for check: Dictionary in importer.checks:
		print("CHECK %s %s %s" % [check.id, check.result, check.message])
	print("IMPORT %s %s in %.1f s; report %s" % [id, "written" if info.written else "NOT written", info.seconds, report_path])
	if importer.model and importer.model.is_inside_tree():
		root.remove_child(importer.model)
	if importer.model:
		importer.model.free()
	quit(0 if info.written else 1)


## C4 and C8: the placement against the model's colliders; its checks join
## the importer's.
func _place(importer: RefCounted) -> RefCounted:
	var started := Time.get_ticks_msec()
	var categories := {}
	for body in importer.model.find_children("*", "StaticBody3D", true, false):
		var owner_node: Node = body.get_parent()
		var record: Dictionary = importer.meshes.get(str(owner_node.name), {})
		categories[body.get_instance_id()] = record.category if record.has("category") else importer.rules.category_of(owner_node)
	var placement := MapPlacement.new()
	placement.run(importer.model.get_world_3d().direct_space_state, categories, importer.summary.bounds, importer.config)
	importer.checks.append_array(placement.checks)
	importer.timings.placement = Time.get_ticks_msec() - started
	print("IMPORT stage placement %d ms" % importer.timings.placement)
	return placement


## The cell step on the written map: its resident scene and streaming cells
## in <map folder>/streaming/, the definition pointed at the index. Returns
## the summary lines.
func _cells(definition_path: String) -> Array[String]:
	var started := Time.get_ticks_msec()
	var definition := ResourceLoader.load(definition_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MapDefinition
	var cells := MapCells.new()
	var error := cells.run(definition, definition_path.get_base_dir().path_join("streaming"))
	var lines := cells.lines.duplicate()
	if not error.is_empty():
		lines.append("cell step failed: %s (the map loads whole)" % error)
	elif cells.index:
		lines.append("definition: %s" % MapCells.link(definition, cells.index_path))
	for line in lines:
		print("IMPORT cells: ", line)
	print("IMPORT stage cells %d ms" % (Time.get_ticks_msec() - started))
	return lines


## Writes the processed model, the category rules, the occluders, the map
## scene, and the MapDefinition to `out`.
func _write(importer: RefCounted, placement: RefCounted, id: String, out: String, info: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var model_path := out.path_join("%s_model.scn" % id)
	var rules_path := out.path_join("%s_categories.tres" % id)
	var occluders_path := out.path_join("%s_occluders.scn" % id)
	if not _save_scene(importer.model, model_path):
		return false
	var model_bytes := FileAccess.get_file_as_bytes(model_path).size()
	var ignore := ProjectSettings.globalize_path(out.path_join(".gitignore"))
	if model_bytes > GIT_LIMIT:
		_save_text(ignore, "# Generated by tools/import_map.gd: larger than 10 MB, regenerated on each machine\n%s_model.scn\n" % id)
	elif FileAccess.file_exists(ignore):
		DirAccess.remove_absolute(ignore)
	info.outputs.append([model_path, model_bytes, model_bytes <= GIT_LIMIT and _in_git(model_path)])
	var error := ResourceSaver.save(importer.rules, rules_path)
	if error != OK:
		printerr("IMPORT could not save ", rules_path, ": ", error_string(error))
		return false
	info.outputs.append([rules_path, FileAccess.get_file_as_bytes(rules_path).size(), _in_git(rules_path)])
	var occluders: Node3D = importer.build_occluders()
	var saved := _save_scene(occluders, occluders_path)
	occluders.free()
	if not saved:
		return false
	info.outputs.append([occluders_path, FileAccess.get_file_as_bytes(occluders_path).size(), _in_git(occluders_path)])
	var scene_path := out.path_join("%s.tscn" % id)
	_save_text(scene_path, MapWriter.scene_text(id, model_path))
	info.outputs.append([scene_path, FileAccess.get_file_as_bytes(scene_path).size(), _in_git(scene_path)])
	var paths := {"scene": scene_path, "model": model_path, "rules": rules_path, "occluders": occluders_path}
	var definition := MapWriter.definition(id, str(importer.config.get("display_name", id)), paths, placement)
	var definition_path := out.path_join("%s.tres" % id)
	error = ResourceSaver.save(definition, definition_path)
	if error != OK:
		printerr("IMPORT could not save ", definition_path, ": ", error_string(error))
		return false
	info.outputs.append([definition_path, FileAccess.get_file_as_bytes(definition_path).size(), _in_git(definition_path)])
	return true


## Whether Git keeps `path` (not ignored, e.g. by the 10 MB rule or tests/imported/);
## true when git cannot tell.
static func _in_git(path: String) -> bool:
	var file := ProjectSettings.globalize_path(path)
	return OS.execute("git", ["-C", file.get_base_dir(), "check-ignore", "-q", file]) != 0


func _save_scene(node: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var error := packed.pack(node)
	if error == OK:
		error = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		printerr("IMPORT could not save ", path, ": ", error_string(error))
	return error == OK


static func _save_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)


## A registry id from a file name: lowercase, anything but a-z and 0-9 as "_".
static func _id_from_file(path: String) -> String:
	var id := ""
	for c in path.get_file().get_basename().to_lower():
		id += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return id


## The arguments as given, with the GLB, configuration, and earlier reports
## shown by file name only (no personal paths in the report).
static func _shown_args() -> PackedStringArray:
	var shown := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb=") or arg.begins_with("--config=") or arg.begins_with("--compare="):
			var values := PackedStringArray()
			for value in arg.substr(arg.find("=") + 1).split(","):
				values.append(value if value.begins_with("res://") else "<dir>/" + value.get_file())
			shown.append("%s=%s" % [arg.get_slice("=", 0), ",".join(values)])
		else:
			shown.append(arg)
	return shown
