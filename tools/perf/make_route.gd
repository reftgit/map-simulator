extends SceneTree
## A fixed route over a map's walkable ground for the route benchmark
## ("bench": {"route": …}, docs/ARCHITECTURE.md, "Performance experiments"):
## the shortest path through the given points over ground colliders (the
## map's `ground` category, at most 35° steep, the player's capsule fits,
## at most 0.8 m up or down per 2 m), straightened where a straight line is
## walkable, printed as JSON points (x, ground height, z) and its length.
##   godot --headless --path . --script res://tools/perf/make_route.gd -- --map=<id> --via=x,z;x,z;…
## Exit code 0 with a route, 1 when no path joins two points, 2 for bad arguments.

const STEP := 2.0
const MAX_SLOPE := 35.0
const MAX_RISE := 0.8
## Metres around the points the search may use.
const AREA_MARGIN := 80.0
const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.8

var _space: PhysicsDirectSpaceState3D
var _rules: CategoryRules
var _heights := {}  # Vector2i -> ground height, or NAN where not walkable
var _origin := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	var definition := MapRegistry.load_default().find(str(args.get("map", "")))
	var points: Array[Vector2] = []
	for pair in str(args.get("via", "")).split(";", false):
		points.append(Vector2(float(pair.get_slice(",", 0)), float(pair.get_slice(",", 1))))
	if definition == null or points.size() < 2:
		printerr("usage: --map=<id> --via=x,z;x,z[;…]")
		quit(2)
		return
	_rules = definition.category_rules
	var map := (load(definition.scene_path) as PackedScene).instantiate()
	root.add_child(map)
	await physics_frame
	await physics_frame
	_space = map.get_world_3d().direct_space_state
	var route: Array[Vector3] = []
	for i in points.size() - 1:
		var leg := _path(points[i], points[i + 1])
		if leg.is_empty():
			printerr("ROUTE no walkable path from %s to %s" % [points[i], points[i + 1]])
			quit(1)
			return
		if not route.is_empty():
			leg.remove_at(0)
		route.append_array(leg)
	route = _straighten(route)
	var length := 0.0
	var rounded := []
	for i in route.size():
		if i > 0:
			length += route[i].distance_to(route[i - 1])
		rounded.append([snappedf(route[i].x, 0.01), snappedf(route[i].y, 0.01), snappedf(route[i].z, 0.01)])
	print("ROUTE %s: %d points, %.0f m" % [definition.id, route.size(), length])
	print(JSON.stringify(rounded))
	quit(0)


## The cell of `point` on the search grid.
func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi((point.x - _origin.x) / STEP), roundi((point.y - _origin.y) / STEP))


func _point(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * STEP


## Ground height at a grid cell (NAN where not walkable), cached.
func _height(cell: Vector2i) -> float:
	if not _heights.has(cell):
		var point := _point(cell)
		_heights[cell] = _ground(point.x, point.y)
	return _heights[cell]


## Height of walkable ground under (x, z): the first collider below is a
## ground mesh's, no steeper than MAX_SLOPE, and the capsule fits on it.
func _ground(x: float, z: float) -> float:
	var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 500, z), Vector3(x, -100, z), 1))
	if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) < cos(deg_to_rad(MAX_SLOPE)):
		return NAN
	var owner_node: Node = (hit.collider as Node).get_parent()
	if owner_node == null or _rules.category_of(owner_node) != "ground":
		return NAN
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, (hit.position as Vector3) + Vector3.UP * (CAPSULE_HEIGHT * 0.5 + 0.1))
	query.collision_mask = 1
	return (hit.position as Vector3).y if _space.intersect_shape(query, 1).is_empty() else NAN


## A* over the grid from `from` to `to` within the area around them.
func _path(from: Vector2, to: Vector2) -> Array[Vector3]:
	_origin = Vector2(floorf(minf(from.x, to.x) / STEP) * STEP, floorf(minf(from.y, to.y) / STEP) * STEP)
	_heights.clear()
	var low := _cell(Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * AREA_MARGIN)
	var high := _cell(Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * AREA_MARGIN)
	var start_found: Variant = _nearest_walkable(_cell(from))
	var goal_found: Variant = _nearest_walkable(_cell(to))
	if start_found == null or goal_found == null:
		return []
	var start: Vector2i = start_found
	var goal: Vector2i = goal_found
	var heap := [[Vector2(start).distance_to(Vector2(goal)), start]]
	var came := {}
	var cost := {start: 0.0}
	var closed := {}
	while not heap.is_empty():
		var current: Vector2i = _pop(heap)[1]
		if closed.has(current):
			continue
		closed[current] = true
		if current == goal:
			var path: Array[Vector3] = []
			var cell: Variant = current
			while cell != null:
				var point := _point(cell)
				path.push_front(Vector3(point.x, _height(cell), point.y))
				cell = came.get(cell)
			return path
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var next: Vector2i = current + offset
			if next.x < low.x or next.y < low.y or next.x > high.x or next.y > high.y:
				continue
			var height := _height(next)
			if is_nan(height) or absf(height - _height(current)) > MAX_RISE * Vector2(offset).length():
				continue
			var step_cost: float = cost[current] + Vector2(offset).length()
			if step_cost < cost.get(next, INF):
				cost[next] = step_cost
				came[next] = current
				_push(heap, [step_cost + Vector2(next).distance_to(Vector2(goal)), next])
	return []


## Binary min-heap of [priority, cell] entries.
static func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var swap: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = swap
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		while true:
			var smallest := i
			for child in [2 * i + 1, 2 * i + 2]:
				if child < heap.size() and heap[child][0] < heap[smallest][0]:
					smallest = child
			if smallest == i:
				break
			var swap: Array = heap[smallest]
			heap[smallest] = heap[i]
			heap[i] = swap
			i = smallest
	return top


func _nearest_walkable(cell: Vector2i) -> Variant:
	for radius in 6:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if not is_nan(_height(cell + Vector2i(dx, dy))):
					return cell + Vector2i(dx, dy)
	return null


## Drops points where the straight line between their neighbours is walkable
## (every metre, heights within MAX_RISE per 2 m of the previous sample).
func _straighten(route: Array[Vector3]) -> Array[Vector3]:
	var kept: Array[Vector3] = [route[0]]
	var i := 0
	while i < route.size() - 1:
		var j := route.size() - 1
		while j > i + 1 and not _walkable_line(route[i], route[j]):
			j -= 1
		kept.append(route[j])
		i = j
	return kept


func _walkable_line(a: Vector3, b: Vector3) -> bool:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var last := a.y
	for k in range(1, ceili(length) + 1):
		var t := minf(k / length, 1.0)
		var height := _ground(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t))
		if is_nan(height) or absf(height - last) > MAX_RISE * 0.5:
			return false
		last = height
	return true
