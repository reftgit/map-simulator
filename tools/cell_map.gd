extends SceneTree
## Splits maps into a resident scene and streaming cells (docs/STREAMING.md),
## the same way for every map: imported ones, the İstanbul generator's, and
## hand-made ones. Writes <map folder>/streaming/ and points the map's
## MapDefinition at its index (streaming_index_path). The map's own files are
## only read; the output is generated on each machine (ignored by Git) and
## exported with the game when present. Run --import afterwards.
##   godot --headless --path . --script res://tools/cell_map.gd -- --all
##   godot --headless --path . --script res://tools/cell_map.gd -- --map=<id>[,<id>…]
##   godot --headless --path . --script res://tools/cell_map.gd -- --definition=res://…/<id>.tres
##       [--cell-size=<m>] [--out=<res:// folder>] [--no-link]
## --all takes every available map of the registry. --out (one map only) and
## --no-link write a second split beside the first without changing the
## definition (cell size comparisons). Exit code 0 when every map was split
## (or had nothing to stream), 1 when one failed, 2 for bad arguments.

const MapCells := preload("res://tools/map_import/map_cells.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--"):
			args[arg.trim_prefix("--")] = true
	var definitions: Array[MapDefinition] = []
	var registry := MapRegistry.load_default()
	if args.has("all"):
		for definition in registry.definitions:
			if definition.has_required_files():
				definitions.append(definition)
			else:
				print("CELLS %s skipped: its files are missing (%s)" % [definition.id, ", ".join(PackedStringArray(definition.required_files))])
	for id in str(args.get("map", "")).split(",", false):
		var found := registry.find(id)
		if found == null:
			printerr("CELLS unknown map '%s'" % id)
			quit(2)
			return
		definitions.append(found)
	for path in str(args.get("definition", "")).split(",", false):
		var loaded := load(path) as MapDefinition
		if loaded == null:
			printerr("CELLS not a MapDefinition: %s" % path)
			quit(2)
			return
		definitions.append(loaded)
	if definitions.is_empty() or (args.has("out") and definitions.size() > 1):
		printerr("usage: --all | --map=<id>[,<id>…] | --definition=<res://…/id.tres>[,…] [--cell-size=<m>] [--out=<res:// folder> (one map)] [--no-link]")
		quit(2)
		return
	var cell_size := float(args.get("cell-size", MapCells.DEFAULT_CELL_SIZE))
	var failed := 0
	for definition in definitions:
		var out := str(args.get("out", definition.resource_path.get_base_dir().path_join("streaming")))
		var cells := MapCells.new()
		var error := cells.run(definition, out, cell_size)
		for line in cells.lines:
			print("CELLS ", line)
		if not error.is_empty():
			printerr("CELLS %s failed: %s" % [definition.id, error])
			failed += 1
			continue
		if cells.index and not args.has("no-link"):
			print("CELLS %s definition: %s" % [definition.id, MapCells.link(definition, cells.index_path)])
		print("CELLS %s done in %.1f s" % [definition.id, cells.seconds])
	quit(1 if failed > 0 else 0)
