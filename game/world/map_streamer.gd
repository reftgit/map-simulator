class_name MapStreamer
extends Node
## Streams a map's visibility-range meshes (docs/STREAMING.md). The resident
## map has every node; the meshes of the facade detail, trees, lamps, and
## decor are in cell files (MapStreamingIndex, written by tools/cell_map.gd).
## Godot draws such a mesh only while the camera is within its category's
## visibility range of the mesh's centre, so every cell whose centres lie
## within that range plus `margin` of the camera is loaded (threaded, nearest
## first, given its meshes within a per-frame budget), also ahead of a moving
## camera, and freed beyond `margin` + `hysteresis`. Where the camera jumps
## farther than `margin` in one frame (a teleport, respawn, viewpoint, or the
## map's first frame) the cells it needs are loaded at once (prime()). Knows
## nothing about the player, the camera rig, or the profiles: Main sets the
## focus and the ranges.

## A cell got its meshes (`seconds`: main-thread time for it).
signal cell_attached(cell: int, seconds: float)
signal cell_detached(cell: int)

## Process after the camera, so a camera that jumped this frame is seen
## before the frame is drawn.
const PROCESS_PRIORITY := 100
## Metres the camera moves before the wanted cells are worked out again.
const REEVALUATE_DISTANCE := 2.0

## Metres beyond a category's visibility range within which cells are kept
## loaded ahead of the camera; also the farthest the camera may move in one
## frame before the cells around it are loaded at once.
@export var margin := 30.0
## Further metres beyond range + margin before a loaded cell is freed.
@export var hysteresis := 30.0
## Seconds of the camera's velocity looked ahead (cells are also wanted around
## the point it will reach).
@export var lookahead := 1.5
## Threaded requests in flight at once. One: cells are small (26 KB on
## average on the default map) and one at a time keeps up with a driving
## camera (no needed cell missing on the routes), while more at once added
## frames of 51–57 ms on the Galaxy Tab A7 (loading threads competing with
## the game's).
@export var max_requests := 1
## Main-thread milliseconds per frame for giving loaded cells their meshes;
## at least one cell per frame.
@export var attach_budget_ms := 2.0

## Whether cells load on worker threads. That needs a renderer that creates
## meshes off the main thread, one with a RenderingDevice (Forward+, Mobile);
## the dummy renderer of headless runs does not (its mesh RIDs race: errors
## seen when 2,612 cells loaded at once), so there cells load on the main
## thread, within the same budget.
var threaded := RenderingServer.get_rendering_device() != null
var index: MapStreamingIndex
var map_root: Node
## Its global position is where visibility ranges are measured from: the camera.
var focus: Node3D
## Totals since setup(): loads, unloads, primes, the last prime's cells and time,
## the longest main-thread time of one frame's attaching.
var totals := {"loads": 0, "unloads": 0, "primes": 0, "prime_cells": 0, "prime_ms": 0.0, "attach_max_ms": 0.0, "failed": 0}
## Cells given their meshes in the last processed frame, and the main-thread time it took.
var frame_attached := 0
var frame_attach_ms := 0.0

var _radius := {}  # category -> visibility range (m): INF without one, -1.0 hidden
var _grid := {}  # "category:i:j" -> cell
var _categories: Array[String] = []
var _cells_of := {}  # category -> Array of its cells
var _failed := {}  # cell -> true: not requested again
var _pinned := {}  # cell -> true: a warm cell, never freed
var _loaded_now := {}  # cell -> MapCell loaded on the main thread (not threaded)
var _loaded := {}  # cell -> MapCell
var _nodes := {}  # cell -> Array of MeshInstance3D
var _requested := {}  # cell -> true while a threaded request is in flight
var _fetched := {}  # cell -> MapCell loaded, waiting for the budget
var _queue: Array[int] = []
var _wanted := {}  # cell -> distance from the camera at the last evaluation
var _materials: Array[Resource] = []
var _last_position := Vector3.INF
var _evaluated_at := Vector3.INF
var _velocity := Vector3.ZERO
var _dirty := true


func _init() -> void:
	process_priority = PROCESS_PRIORITY


## Streams `new_index`'s cells into `new_map_root` (the resident scene, in the
## tree). Every streamed category starts without a visibility range (all of it
## wanted) until set_ranges().
func setup(new_map_root: Node, new_index: MapStreamingIndex) -> void:
	map_root = new_map_root
	index = new_index
	_grid.clear()
	_categories.clear()
	for cell in index.cell_count():
		var rect := index.cell_rects[cell]
		var category := index.cell_categories[cell]
		_grid[_key(category, roundi(rect.position.x / index.cell_size), roundi(rect.position.y / index.cell_size))] = cell
		if category not in _categories:
			_categories.append(category)
			_radius[category] = INF
		_cells_of.get_or_add(category, []).append(cell)
	for path in index.material_paths:
		_materials.append(load(path))
	# Let the map script change these materials now, at load, as it changes the
	# whole map's in _ready(): a material changed when its first cell arrives
	# makes the renderer build its shader then (stalls of 100–200 ms on the
	# Galaxy Tab A7 when the İstanbul maps' vertex-colour fix ran at first use).
	if map_root.has_method(&"prepare_streamed_materials"):
		map_root.prepare_streamed_materials(_materials)
	# Warm cells: the smallest cell using each material, loaded now and kept,
	# so every material is in the scene from the start as with the whole map
	# (on the Galaxy Tab A7 the first cell bringing a material into the scene
	# stalled a frame for about 100 ms, the whole map never did).
	for cell in index.warm_cells:
		var resource := load(index.cell_paths[cell]) as MapCell
		if resource:
			_attach(cell, resource)
			_pinned[cell] = true


## Takes the visibility ranges from RenderSettings' effective settings: a
## category with no range is wanted whole, a hidden one not at all.
func set_ranges(effective: Dictionary) -> void:
	for category in _categories:
		var range_end: float = effective.get("visibility_end", {}).get(category, 0.0)
		_radius[category] = -1.0 if category in effective.get("hide", []) else (range_end if range_end > 0.0 else INF)
	_dirty = true


## The visibility range used for `category` (INF without one, -1 hidden).
func radius_of(category: String) -> float:
	return _radius.get(category, INF)


## Where the camera is, in the map root's space.
func focus_position() -> Vector3:
	var position := focus.global_position if focus else Vector3.ZERO
	return (map_root as Node3D).global_transform.affine_inverse() * position if map_root is Node3D else position


func _process(delta: float) -> void:
	frame_attached = 0
	frame_attach_ms = 0.0
	if index == null or focus == null:
		return
	var position := focus_position()
	if _last_position == Vector3.INF or position.distance_to(_last_position) > margin:
		prime(position)
		return
	if delta > 0.0:
		_velocity = _velocity.lerp((position - _last_position) / delta, minf(1.0, delta * 4.0))
	_last_position = position
	if _dirty or position.distance_to(_evaluated_at) > REEVALUATE_DISTANCE:
		_evaluate(position)
	_poll()
	_attach_fetched(position)
	_request()


## Loads every cell wanted at `position` before returning, on the main thread
## (requests already in flight are waited for), and frees those beyond reach:
## for the map's first frame and after the camera jumps. Returns the cells it
## loaded. Not threaded: threaded requests made from Main._ready() at the
## app's start crashed a worker thread in 7 of 20 launches on the Mac (Metal),
## and none when made later from the frame loop (docs/STREAMING.md).
func prime(position := Vector3.INF) -> int:
	if index == null:
		return 0
	if position == Vector3.INF:
		position = focus_position()
	var started := Time.get_ticks_usec()
	_velocity = Vector3.ZERO
	_last_position = position
	_evaluate(position)
	var missing: Array[int] = []
	for cell in _queue:
		missing.append(cell)
	var loaded := 0
	for cell in _requested.keys():
		var resource := _take_load(cell)
		_requested.erase(cell)
		if resource == null:
			_fail(cell)
		elif _wanted.has(cell):
			_attach(cell, resource)
			loaded += 1
	for cell in missing:
		var resource := load(index.cell_paths[cell]) as MapCell
		if resource == null:
			_fail(cell)
		else:
			_attach(cell, resource)
			loaded += 1
	for cell in _fetched.keys():
		if _wanted.has(cell):
			_attach(cell, _fetched[cell])
			loaded += 1
	_fetched.clear()
	_queue.clear()
	totals.primes += 1
	totals.prime_cells = loaded
	totals.prime_ms = snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.1)
	return loaded


## Waits for the requests in flight and drops them, and lets go of every cell
## and material (the map is being freed). Called before the map is freed and
## when this node leaves the tree.
func shutdown() -> void:
	for cell in _requested:
		_take_load(cell)
	_requested.clear()
	_fetched.clear()
	_queue.clear()
	_loaded.clear()
	_loaded_now.clear()
	_pinned.clear()
	_nodes.clear()
	_materials.clear()
	index = null


func _exit_tree() -> void:
	if index:
		shutdown()


## Cells of a category with a visibility range (or none) whose meshes' centres
## lie within that range of `position` but that are not loaded: what the
## camera there would miss. 0 while streaming keeps up.
func missing_cells(position := Vector3.INF) -> int:
	if index == null:
		return 0
	if position == Vector3.INF:
		position = focus_position()
	var missing := 0
	for cell in _cells_within(position, 0.0):
		if not _loaded.has(cell):
			missing += 1
	return missing


## Loaded cells, waiting cells (queued, in flight, fetched), the loaded cells'
## file size (MB) and meshes, and the totals.
func stats() -> Dictionary:
	var bytes := 0
	var meshes := 0
	for cell in _loaded:
		bytes += index.cell_bytes[cell]
		meshes += index.cell_meshes[cell]
	var out := {"cells": index.cell_count() if index else 0, "loaded": _loaded.size(),
			"pending": _queue.size() + _requested.size() + _fetched.size(), "loaded_mb": snappedf(bytes / 1048576.0, 0.1), "meshes": meshes}
	out.merge(totals)
	return out


func is_loaded(cell: int) -> bool:
	return _loaded.has(cell)


## Distance from `position` to the bounds of a cell's mesh centres: no mesh of
## the cell is nearer, so beyond its category's range none is drawn.
func cell_distance(cell: int, position: Vector3) -> float:
	var box := index.cell_centers[cell]
	return position.distance_to(position.clamp(box.position, box.end))


## Works out the wanted cells around `position` and the point the camera
## will reach, frees cells beyond reach, and queues the missing ones nearest first.
func _evaluate(position: Vector3) -> void:
	_dirty = false
	_evaluated_at = position
	_wanted = _cells_within(position, margin)
	if _velocity.length() > 1.0:
		var ahead := position + _velocity * lookahead
		for cell: int in _cells_within(ahead, margin):
			if not _wanted.has(cell):
				_wanted[cell] = cell_distance(cell, position)
	for cell in _loaded.keys():
		if not _wanted.has(cell) and not _pinned.has(cell) and not _within(cell, position, margin + hysteresis):
			_detach(cell)
	for cell in _fetched.keys():
		if not _wanted.has(cell):
			_fetched.erase(cell)
	_queue.clear()
	for cell in _wanted:
		if not _loaded.has(cell) and not _requested.has(cell) and not _fetched.has(cell) and not _failed.has(cell):
			_queue.append(cell)
	_queue.sort_custom(func(a: int, b: int) -> bool: return _wanted[a] < _wanted[b])


## Cells (-> distance) of each category whose centres lie within its range
## plus `extra` metres of `position`.
func _cells_within(position: Vector3, extra: float) -> Dictionary:
	var found := {}
	var size := index.cell_size
	for category in _categories:
		var radius: float = _radius[category]
		if radius < 0.0:
			continue
		if radius == INF:
			for cell: int in _cells_of[category]:
				found[cell] = cell_distance(cell, position)
			continue
		var reach := radius + extra
		for i in range(floori((position.x - reach) / size), floori((position.x + reach) / size) + 1):
			for j in range(floori((position.z - reach) / size), floori((position.z + reach) / size) + 1):
				var cell: int = _grid.get(_key(category, i, j), -1)
				if cell >= 0:
					var distance := cell_distance(cell, position)
					if distance <= reach:
						found[cell] = distance
	return found


func _within(cell: int, position: Vector3, extra: float) -> bool:
	var radius: float = _radius[index.cell_categories[cell]]
	return radius >= 0.0 and cell_distance(cell, position) <= radius + extra


func _request() -> void:
	while _requested.size() < max_requests and not _queue.is_empty():
		_begin_load(_queue.pop_front())


func _poll() -> void:
	for cell in _requested.keys():
		var status := _load_status(cell)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_requested.erase(cell)
		var resource := _take_load(cell) if status == ResourceLoader.THREAD_LOAD_LOADED else null
		if resource == null:
			_fail(cell)
		elif _wanted.has(cell):
			_fetched[cell] = resource


## Starts loading a cell (a threaded request, or at once on the main thread).
func _begin_load(cell: int) -> void:
	_requested[cell] = true
	if threaded:
		ResourceLoader.load_threaded_request(index.cell_paths[cell])
	else:
		_loaded_now[cell] = load(index.cell_paths[cell])


## ResourceLoader.THREAD_LOAD_* of a started load.
func _load_status(cell: int) -> int:
	if not threaded:
		return ResourceLoader.THREAD_LOAD_LOADED if _loaded_now.get(cell) else ResourceLoader.THREAD_LOAD_FAILED
	return ResourceLoader.load_threaded_get_status(index.cell_paths[cell])


## The cell of a started load, waiting for it if it is still in flight; null if it failed.
func _take_load(cell: int) -> MapCell:
	if not threaded:
		var resource := _loaded_now.get(cell) as MapCell
		_loaded_now.erase(cell)
		return resource
	return ResourceLoader.load_threaded_get(index.cell_paths[cell]) as MapCell


func _attach_fetched(position: Vector3) -> void:
	if _fetched.is_empty():
		return
	var cells := _fetched.keys()
	cells.sort_custom(func(a: int, b: int) -> bool: return cell_distance(a, position) < cell_distance(b, position))
	var started := Time.get_ticks_usec()
	for cell: int in cells:
		_attach(cell, _fetched[cell])
		_fetched.erase(cell)
		if (Time.get_ticks_usec() - started) / 1000.0 >= attach_budget_ms:
			break
	frame_attach_ms = (Time.get_ticks_usec() - started) / 1000.0
	totals.attach_max_ms = maxf(totals.attach_max_ms, snappedf(frame_attach_ms, 0.01))


## Gives the cell's nodes their meshes, then lets the map script set them up
## as at load (prepare_streamed(), if the map's root has it).
func _attach(cell: int, resource: MapCell) -> void:
	var started := Time.get_ticks_usec()
	var instances: Array = _nodes.get(cell, [])
	if instances.is_empty():
		for path in resource.nodes:
			instances.append(map_root.get_node_or_null(path) as MeshInstance3D)
		_nodes[cell] = instances
	for k in instances.size():
		if instances[k]:
			instances[k].mesh = resource.meshes[k]
	_loaded[cell] = resource
	if map_root.has_method(&"prepare_streamed"):
		map_root.prepare_streamed(instances.filter(func(node: Variant) -> bool: return node != null))
	totals.loads += 1
	frame_attached += 1
	cell_attached.emit(cell, (Time.get_ticks_usec() - started) / 1e6)


func _detach(cell: int) -> void:
	for instance: MeshInstance3D in _nodes.get(cell, []):
		if instance:
			instance.mesh = null
	_loaded.erase(cell)
	totals.unloads += 1
	cell_detached.emit(cell)


func _fail(cell: int) -> void:
	push_error("STREAMING could not load %s" % index.cell_paths[cell])
	totals.failed += 1
	_failed[cell] = true
	_wanted.erase(cell)


static func _key(category: String, i: int, j: int) -> String:
	return "%s:%d:%d" % [category, i, j]
