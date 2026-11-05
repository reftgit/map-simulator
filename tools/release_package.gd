extends SceneTree
## What a release package carries (the export presets "Android Release" and
## "iOS Release"; docs/ARCHITECTURE.md, "Release builds"): the game and the
## maps of the release registry (MapRegistry.RELEASE_PATH) in the form they
## load. A streamed map goes as its streaming folder (resident scene, cells,
## materials) with its definition, scripts, and occluders, without its model
## (the GLB); a map without a streaming index goes whole, with its required
## files. Used by tools/check_release.gd before an export and by the preset
## test. Godot's "all resources" export is simulated: every file of the
## project that ResourceLoader recognises, outside hidden and .gdignore
## folders, minus the preset's exclude filter, matched as Godot matches it
## (the path with and without "res://", String.matchn()).
##
## The release presets' exclude filter is written from the release registry
## (exclude_patterns(), Phase 6e), so no map is named by hand: a map that is
## not in the release registry is left out whole once the filter is written
## again, which tools/build_release.sh does before every export.
##   godot --headless --path . --script res://tools/release_package.gd -- --write   # writes it into export_presets.cfg
##   godot --headless --path . --script res://tools/release_package.gd -- --check   # exit 1 when it is not current

const PRESETS := "res://export_presets.cfg"
const RELEASE_PRESETS: Array[String] = ["Android Release", "iOS Release"]
## Where maps, their models, and the original demo live: a file here that the
## package carries must be needed by a release map.
const MAP_FOLDERS: Array[String] = ["res://maps/", "res://assets/", "res://scripts/"]
## A file name no exclude pattern spells out: a pattern that matches
## <folder>/PROBE leaves out every file under the folder.
const PROBE := "\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008"
## What a release leaves out besides the maps: the development folders, every
## comparison split (streaming_<size>/), and the registry naming every map.
const BASE_EXCLUDE: Array[String] = ["tests/*", "tools/*", "docs/*", "maps/*/streaming_*"]
const WRITE_COMMAND := "godot --headless --path . --script res://tools/release_package.gd -- --write"


func _initialize() -> void:
	_run.call_deferred()


## The command: --write writes the generated exclude filter into the release
## presets, --check exits 1 when it differs from theirs.
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args != PackedStringArray(["--write"]) and args != PackedStringArray(["--check"]):
		printerr("usage: -- --write | --check")
		quit(2)
		return
	var patterns := exclude_patterns(MapRegistry.load_release(), MapRegistry.load_default())
	var stale: Array[String] = []
	for name in RELEASE_PRESETS:
		if preset(name).get("exclude", []) != patterns:
			stale.append(name)
	if args[0] == "--check":
		for name in stale:
			printerr("RELEASE %s: its exclude filter is not the one generated from %s. Write it: %s" % [name, MapRegistry.RELEASE_PATH, WRITE_COMMAND])
		print("RELEASE exclude filter %s: %s" % ["stale" if not stale.is_empty() else "current", ", ".join(patterns)])
		quit(1 if not stale.is_empty() else 0)
		return
	if not stale.is_empty():
		var error := write_exclude_filter(patterns)
		if error != OK:
			printerr("RELEASE cannot write %s (%s)" % [PRESETS, error_string(error)])
			quit(1)
			return
	print("RELEASE exclude filter %s (%s): %s" % ["written" if not stale.is_empty() else "already current", ", ".join(RELEASE_PRESETS), ", ".join(patterns)])
	quit(0)


## The exclude filter of a release package carrying the maps of `release`:
## BASE_EXCLUDE and the full registry, then everything under the map folders
## (MAP_FOLDERS) and every scene at the top of the project that those maps do
## not need (needed()), a whole folder where none of it is needed; and the
## streaming folder of every map of `every` that `release` leaves out, which
## is generated on each machine and may not be on this one. Reading the
## folders, a model's ".import" file stands for the model, which may be
## missing too; folders with a .gdignore file are not exported anyway. The
## same tracked files give the same filter on every machine.
static func exclude_patterns(release: MapRegistry, every: MapRegistry) -> Array[String]:
	var wanted := needed(release)
	var patterns: Array[String] = BASE_EXCLUDE.duplicate()
	patterns.append(MapRegistry.PATH.trim_prefix("res://"))
	var found: Array[String] = []
	for definition in every.definitions:
		var folder := definition.streaming_index_path.get_base_dir()
		if release.find(definition.id) == null and not folder.is_empty() and not wanted.folders.has(folder + "/"):
			found.append(folder.trim_prefix("res://") + "/*")
	for dir in MAP_FOLDERS:
		_unneeded(dir.trim_suffix("/"), wanted, found)
	for file in DirAccess.get_files_at("res://"):
		if file.get_extension() in ["tscn", "scn"] and not wanted.files.has("res://" + file):
			found.append(file)
	found.sort()
	for pattern in found:
		if pattern not in patterns and not excluded("res://" + pattern.trim_suffix("/*").path_join(PROBE) if pattern.ends_with("/*") else "res://" + pattern, patterns):
			patterns.append(pattern)
	return patterns


## Writes `patterns` as the exclude filter of both release presets (the line
## in each preset's section of export_presets.cfg; nothing else changes).
static func write_exclude_filter(patterns: Array[String]) -> Error:
	var file := FileAccess.open(PRESETS, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var lines := file.get_as_text().split("\n")
	file.close()
	var section := ""
	var release := false
	for i in lines.size():
		var line := lines[i]
		if line.begins_with("["):
			section = line
			release = false
		elif line.begins_with("name=") and not section.ends_with(".options]"):
			release = line.trim_prefix("name=").trim_prefix("\"").trim_suffix("\"") in RELEASE_PRESETS
		elif release and line.begins_with("exclude_filter="):
			lines[i] = "exclude_filter=\"%s\"" % ", ".join(patterns)
	file = FileAccess.open(PRESETS, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	return OK


## The preset called `name`: its section, custom features, export filter, and
## exclude patterns; {} when export_presets.cfg has none.
static func preset(name: String) -> Dictionary:
	var presets := ConfigFile.new()
	if presets.load(PRESETS) != OK:
		return {}
	for section in presets.get_sections():
		if section.ends_with(".options") or presets.get_value(section, "name", "") != name:
			continue
		var exclude: Array[String] = []
		for pattern in str(presets.get_value(section, "exclude_filter", "")).split(",", false):
			exclude.append(pattern.strip_edges())
		return {"section": section, "features": str(presets.get_value(section, "custom_features", "")).split(",", false),
				"filter": presets.get_value(section, "export_filter", ""), "exclude": exclude}
	return {}


## Whether an export with the exclude filter `patterns` leaves `path` out.
static func excluded(path: String, patterns: Array[String]) -> bool:
	var short := path.trim_prefix("res://")
	for pattern in patterns:
		if path.matchn(pattern) or short.matchn(pattern):
			return true
	return false


## The project's resource files under `dir` that an export with the exclude
## filter `patterns` packs, sorted. A folder the filter leaves out whole is
## not listed.
static func packed_files(patterns: Array[String], dir := "res://") -> Array[String]:
	var found: Array[String] = []
	if dir != "res://" and (FileAccess.file_exists(dir.path_join(".gdignore")) or excluded(dir.path_join(PROBE), patterns)):
		return found
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if file.get_extension() in ["import", "uid"] or excluded(path, patterns) or not ResourceLoader.exists(path):
			continue
		found.append(path)
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			found.append_array(packed_files(patterns, dir.path_join(sub)))
	found.sort()
	return found


## What the maps of `registry` need in a release package: "files" (path -> map
## id) and "folders" (folder -> map id; every file under it, such as the cells
## generated on each machine).
static func needed(registry: MapRegistry) -> Dictionary:
	var files := {}
	var folders := {}
	for definition in registry.definitions:
		var roots: Array[String] = [definition.resource_path, definition.occluders_path]
		if definition.streaming_index_path.is_empty():
			roots.append(definition.scene_path)
			roots.append_array(definition.required_files)
		else:
			folders[definition.streaming_index_path.get_base_dir() + "/"] = definition.id
			# The resident scene is the map scene without its model: what the
			# scene uses besides the model (its script, the script's own files).
			for dependency in _dependencies(definition.scene_path):
				if dependency not in definition.required_files:
					roots.append(dependency)
		for root in roots:
			if not root.is_empty():
				_add_closure(root, definition.id, files, definition.required_files)
	return {"files": files, "folders": folders}


## Why the preset `name` would not pack exactly what the release maps need
## (empty when it would), its exclude filter first: the one exclude_patterns()
## writes. With `cells`, also every release map's cells: written, complete,
## and current against its model on this machine.
static func problems(name: String, cells: bool) -> Array[String]:
	var found: Array[String] = []
	var settings := preset(name)
	if settings.is_empty():
		return ["no export preset '%s' in %s" % [name, PRESETS]]
	var exclude: Array[String] = settings.exclude
	if "perf_bench" in settings.features:
		found.append("%s carries perf_bench (debug tools and experiments)" % name)
	if settings.filter != "all_resources":
		found.append("%s exports %s, not all resources" % [name, settings.filter])
	if exclude != exclude_patterns(MapRegistry.load_release(), MapRegistry.load_default()):
		found.append("%s: its exclude filter is not the one generated from %s. Write it: %s" % [name, MapRegistry.RELEASE_PATH, WRITE_COMMAND])
	if excluded(MapRegistry.RELEASE_PATH, exclude):
		found.append("%s leaves out the release registry %s" % [name, MapRegistry.RELEASE_PATH])
	if not excluded(MapRegistry.PATH, exclude):
		found.append("%s packs %s, which names every map" % [name, MapRegistry.PATH])
	var registry := load(MapRegistry.RELEASE_PATH) as MapRegistry
	var wanted := needed(registry)
	for path: String in wanted.files:
		if excluded(path, exclude):
			found.append("%s needs %s, which %s leaves out" % [wanted.files[path], path, name])
	for folder: String in wanted.folders:
		if excluded(folder.path_join(PROBE), exclude):
			found.append("%s needs %s, which %s leaves out" % [wanted.folders[folder], folder, name])
	for path in packed_files(exclude):
		if MAP_FOLDERS.any(func(folder: String) -> bool: return path.begins_with(folder)) or (path.get_base_dir() == "res://" and path.get_extension() in ["tscn", "scn"]):
			if not wanted.files.has(path) and not wanted.folders.keys().any(func(folder: String) -> bool: return path.begins_with(folder)):
				found.append("%s packs %s, which no release map needs" % [name, path])
	if cells:
		for definition in registry.definitions:
			var problem := cells_problem(definition)
			if not problem.is_empty():
				found.append(problem)
	return found


## Why `definition` cannot go into a release package as it is on this machine
## ("" when it can): a map with a streaming index needs its cells written and
## current against its model; one without, its required files.
static func cells_problem(definition: MapDefinition) -> String:
	if definition.streaming_index_path.is_empty():
		return "" if definition.has_required_files() else "%s: %s" % [definition.id, definition.unavailable_reason()]
	var fix := "Write them: godot --headless --path . --script res://tools/cell_map.gd -- --map=%s, then godot --headless --path . --import" % definition.id
	if not ResourceLoader.exists(definition.streaming_index_path):
		return "%s: no cells written (%s missing). %s" % [definition.id, definition.streaming_index_path, fix]
	var index := load(definition.streaming_index_path) as MapStreamingIndex
	var problem := index.problem(true) if index else "not a MapStreamingIndex"
	return "" if problem.is_empty() else "%s: its cells cannot be packed (%s). %s" % [definition.id, problem, fix]


## `path`, what it depends on, and the scripts and shaders its scripts extend
## or preload, into `files`; not `skip` (a map's model) or what it uses.
static func _add_closure(path: String, id: String, files: Dictionary, skip: Array[String]) -> void:
	if files.has(path) or path in skip:
		return
	files[path] = id
	var next := _dependencies(path)
	if path.get_extension() == "gd" and FileAccess.file_exists(path):
		var pattern := RegEx.create_from_string("(?:extends|preload\\()\\s*\"(res://[^\"]+)\"")
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			next.append(found.get_string(1))
	for dependency in next:
		_add_closure(dependency, id, files, skip)


## Adds to `found` the patterns for what under `dir` (a res:// folder, no
## trailing slash) the release maps do not need: the folder, when nothing in
## it is needed, else each unneeded file and, folder by folder, the rest.
static func _unneeded(dir: String, wanted: Dictionary, found: Array[String]) -> void:
	if FileAccess.file_exists(dir.path_join(".gdignore")) or wanted.folders.has(dir + "/"):
		return
	var inside := dir + "/"
	var any_needed: bool = wanted.files.keys().any(func(path: String) -> bool: return path.begins_with(inside)) \
			or wanted.folders.keys().any(func(folder: String) -> bool: return folder.begins_with(inside))
	if not any_needed:
		found.append(inside.trim_prefix("res://") + "*")
		return
	var files := {}
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "import":
			files[file.trim_suffix(".import")] = true
		elif file.get_extension() != "uid":
			files[file] = true
	for file: String in files:
		var path := dir.path_join(file)
		if not wanted.files.has(path) and ResourceLoader.exists(path):
			found.append(path.trim_prefix("res://"))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_unneeded(dir.path_join(sub), wanted, found)


static func _dependencies(path: String) -> Array[String]:
	var found: Array[String] = []
	if not ResourceLoader.exists(path):
		return found
	for dependency in ResourceLoader.get_dependencies(path):
		found.append(dependency.get_slice("::", dependency.get_slice_count("::") - 1))
	return found
