class_name MapStreamingIndex
extends Resource
## What tools/cell_map.gd split a map into (docs/STREAMING.md): the resident
## scene (the map with the meshes of the visibility-range categories taken out
## of their nodes) and one MapCell file per category and square of a grid on
## the ground plane. MapDefinition.streaming_index_path points here; while this
## index is missing, incomplete, or older than the map's model, the map loads
## whole (load_for()).

## The map scene without the streamed meshes; loaded instead of scene_path.
@export_file("*.scn") var resident_scene := ""
## Side of a grid square (m).
@export var cell_size := 50.0
## Per cell, in the same order: the file, its render category, its grid square
## (x, z in the map root's space), the bounds of its meshes' centres (what
## Godot measures a visibility range to), and its mesh, triangle, and byte counts.
@export var cell_paths: Array[String] = []
@export var cell_categories: Array[String] = []
@export var cell_rects: Array[Rect2] = []
@export var cell_centers: Array[AABB] = []
@export var cell_meshes: Array[int] = []
@export var cell_triangles: Array[int] = []
@export var cell_bytes: Array[int] = []
## The streamed meshes' materials (files of their own, shared with the
## resident scene): MapStreamer holds them while the map is loaded, so a
## material set up at runtime (a map script's vertex-colour fix) stays the
## same object when a cell loads again.
@export var material_paths: Array[String] = []
## Meshes used in more than one cell (files of their own: loaded once, freed
## with the last cell using them).
@export var shared_mesh_paths: Array[String] = []
## The map's binary model files when the index was written, with their sizes:
## a regenerated model makes the index stale.
@export var source_files: Array[String] = []
@export var source_sizes: Array[int] = []
## Totals when written (the tool's summary).
@export var streamed_meshes := 0
@export var resident_meshes := 0


## The index of `definition` if it can be used: its file exists and is_current().
## Null (the map loads whole) otherwise, with the reason printed or warned.
static func load_for(definition: MapDefinition) -> MapStreamingIndex:
	var path := definition.streaming_index_path
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		print("STREAMING %s: no index (%s); loading the map whole" % [definition.id, path])
		return null
	var index := load(path) as MapStreamingIndex
	var problem := index.problem() if index else "not a MapStreamingIndex"
	if not problem.is_empty():
		push_warning("STREAMING %s: index %s cannot be used (%s); loading the map whole. Run tools/cell_map.gd again." % [definition.id, path, problem])
		return null
	return index


## Why the index cannot be used ("" when it can): a missing file, or a
## model whose size changed since the cells were written.
func problem() -> String:
	if not ResourceLoader.exists(resident_scene):
		return "missing %s" % resident_scene
	for path in cell_paths + material_paths + shared_mesh_paths:
		if not ResourceLoader.exists(path):
			return "missing %s" % path
	for i in source_files.size():
		var file := FileAccess.open(source_files[i], FileAccess.READ)
		var size := file.get_length() if file else -1
		if size != source_sizes[i]:
			return "%s changed (%d bytes, %d when the cells were written)" % [source_files[i], size, source_sizes[i]]
	return ""


func cell_count() -> int:
	return cell_paths.size()
