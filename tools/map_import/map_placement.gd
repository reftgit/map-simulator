extends RefCounted
## Placement of the import tool (docs/MAP_CONTRACT.md, C4 and C8): finds the
## walkable ground, a player spawn with room to walk, a vehicle place with
## room to drive, an NPC route, debug viewpoints, a sloped viewpoint, the
## bounds, and the kill height, with rays and shape queries against the
## model's colliders (physics layer 1). The model must be in the tree, its
## colliders in the physics space.

## C4: grid spacing (extent / 100 between these, m), walkable slope, share.
const MIN_STEP := 2.0
const MAX_STEP := 10.0
const WALKABLE_SLOPE := 35.0
const MIN_WALKABLE_SHARE := 0.05
## Player spawn: slope, clear circle (between 0.5 and 2.0 m above the
## ground), walk ahead (1 m steps, at most 0.5 m up or down each), its cap.
const SPAWN_SLOPE := 20.0
const CLEAR_RADIUS := 2.0
const MIN_WALK := 20.0
const WALK_CAP := 40.0
const STEP_HEIGHT := 0.5
## The player's capsule (PlayerController's collision shape).
const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.8
## Vehicle: clear area (x × z), clear from 0.3 to 2.5 m above the ground,
## heights within 0.3 m and slopes at most 8° under its corners and centre,
## a drive ahead of at least 25 m (2 m steps, a 3 m wide box, at most 0.6 m
## up or down per step), away from the spawn and its walk.
const CAR_AREA := Vector2(5.0, 7.0)
const CAR_SLOPE := 8.0
const CAR_HEIGHT_SPREAD := 0.3
const MIN_DRIVE := 25.0
const DRIVE_CAP := 40.0
const DRIVE_STEP := 2.0
const DRIVE_HEIGHT := 0.6
const CAR_FROM_SPAWN := 8.0
const CAR_FROM_WALK := 6.0
const CAR_LIFT := 0.3
## NPC route: two points 8–16 m apart (12 m tried first), at least 10 m
## from the spawn and 6 m from its walk, 4 m from the car's drive.
const ROUTE_LENGTHS: Array[float] = [12.0, 8.0, 16.0]
const ROUTE_FROM_SPAWN := 10.0
const ROUTE_FROM_WALK := 6.0
const ROUTE_FROM_DRIVE := 4.0
## Viewpoints: three, at least 30 m apart and from the spawn.
const VIEWPOINTS := 3
const VIEWPOINT_SPACING := 30.0
## Sloped viewpoint: ground slope range (degrees).
const SLOPE_RANGE := Vector2(2.0, 10.0)
## Candidates evaluated at most per item (nearest first); the spawn and the
## vehicle are scored over the first SCORED of them that qualify, at least
## SPREAD apart (so they reach about 40 m around).
const MAX_CANDIDATES := 400
const SCORED := 150
const SPREAD := 6.0
const DIRECTIONS := 8
## Scoring of the spawn and the vehicle place: trees, lamps, and decor within
## CLUTTER_RADIUS (vehicle) or SPAWN_CLUTTER (spawn) count against it, a
## building within STREET_REACH to a side makes it a street, room to the
## sides counts up to SIDE_ROOM, and a vehicle place further than
## FAR_FROM_SPAWN from the spawn loses a point per that distance.
const CLUTTER_RADIUS := 6.0
const SPAWN_CLUTTER := 4.0
const STREET_REACH := 12.0
const SIDE_ROOM := 6.0
const FAR_FROM_SPAWN := 40.0
const CLUTTER := ["trees", "lamps", "decor"]

## Results; empty when not found.
var spawn := {}  # {"position": Vector3, "yaw": degrees, "walk": metres}
var vehicle := {}  # {"transform": Transform3D, "drive": metres}
var route: Array[Vector3] = []
var viewpoints: Array[Transform3D] = []
var viewpoint_names: Array[String] = []
var sloped_viewpoint := -1
var bounds := Rect2()
var kill_height := -10.0
var walkable_share := 0.0
## Contract results like the importer's: {"id", "result", "message"}.
var checks: Array[Dictionary] = []
## Report lines.
var lines: Array[String] = []

var _space: PhysicsDirectSpaceState3D
var _categories := {}  # collider instance id -> category
var _box := AABB()
var _samples := []  # walkable samples: [position, normal, slope]
var _center := Vector3.ZERO
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _drive_from := Vector3.ZERO
var _drive_to := Vector3.ZERO


## Runs every search. `model` holds the colliders, `categories` maps each
## StaticBody3D's instance id to its category, `box` is the model's bounds,
## `overrides` the configuration's "spawn", "vehicle_spawn", "npc_route".
func run(space: PhysicsDirectSpaceState3D, categories: Dictionary, box: AABB, overrides := {}) -> bool:
	_space = space
	_categories = categories
	_box = box
	kill_height = floorf(box.position.y - 10.0)
	_sample_ground()
	if walkable_share < MIN_WALKABLE_SHARE:
		_check("C4", "FAIL", "only %.1f %% of the map has walkable ground (a ground collider no steeper than %.0f°). Name the ground meshes (R1) or add collision nodes (R2)." % [100.0 * walkable_share, WALKABLE_SLOPE])
		return false
	_check("C4", "PASS", "%.1f %% of the map has walkable ground (%d samples)" % [100.0 * walkable_share, _samples.size()])
	var ok := _place_spawn(overrides.get("spawn", {}))
	ok = _place_vehicle(overrides.get("vehicle_spawn", {})) and ok
	ok = _place_route(overrides.get("npc_route", [])) and ok
	_place_viewpoints()
	_place_sloped_viewpoint()
	return ok


## Category of the collider a query hit ("" for none).
func category_at(hit: Dictionary) -> String:
	if hit.is_empty() or hit.collider == null:
		return ""
	return _categories.get((hit.collider as Object).get_instance_id(), "")


## The first hit of a ray straight down at (x, z) from above the model.
func ground_hit(x: float, z: float, from_y := INF, to_y := -INF) -> Dictionary:
	var top := _box.end.y + 10.0 if from_y == INF else from_y
	var bottom := _box.position.y - 10.0 if to_y == -INF else to_y
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, bottom, z), 1))


func _sample_ground() -> void:
	var extent := maxf(_box.size.x, _box.size.z)
	var step := clampf(extent / 100.0, MIN_STEP, MAX_STEP)
	var total := 0
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var sum := Vector3.ZERO
	var x := _box.position.x + step * 0.5
	while x < _box.end.x:
		var z := _box.position.z + step * 0.5
		while z < _box.end.z:
			total += 1
			var hit := ground_hit(x, z)
			if category_at(hit) == "ground":
				var slope := rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP))
				if slope <= WALKABLE_SLOPE:
					_samples.append([hit.position, hit.normal, slope])
					low = Vector2(minf(low.x, x), minf(low.y, z))
					high = Vector2(maxf(high.x, x), maxf(high.y, z))
					sum += hit.position
			z += step
		x += step
	walkable_share = float(_samples.size()) / maxi(total, 1)
	if _samples.is_empty():
		return
	_center = sum / _samples.size()
	bounds = Rect2(low + Vector2.ONE, high - low - Vector2.ONE * 2.0)
	lines.append("Walkable ground: %d of %d samples (%.1f %%) on a %.1f m grid; bounds x %.1f … %.1f, z %.1f … %.1f m; kill height %.0f m" % [_samples.size(),
			total, 100.0 * walkable_share, step, bounds.position.x, bounds.end.x, bounds.position.y, bounds.end.y, kill_height])


## Walkable samples no steeper than `slope`, nearest to `origin` first.
func _candidates(slope: float, origin: Vector3) -> Array:
	var list := _samples.filter(func(s: Array) -> bool: return s[2] <= slope)
	list.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_squared_to(origin) < (b[0] as Vector3).distance_squared_to(origin))
	return list


func _place_spawn(override: Dictionary) -> bool:
	if not override.is_empty():
		var position := _vector(override.position)
		spawn = {"position": position, "yaw": float(override.get("yaw", 0.0)), "walk": _walk(position, _direction(float(override.get("yaw", 0.0))))}
		_set_walk()
		_check("C8", "PASS", "player spawn from the configuration at %s, facing %.0f°" % [_text(position), spawn.yaw])
		return true
	var best := {}
	var evaluated := 0
	var tried: Array[Vector3] = []
	var half := maxf(_box.size.x, _box.size.z) * 0.5
	for sample: Array in _candidates(SPAWN_SLOPE, _center):
		if evaluated >= MAX_CANDIDATES or evaluated >= SCORED and not best.is_empty():
			break
		var at: Vector3 = sample[0]
		if tried.any(func(p: Vector3) -> bool: return p.distance_to(at) < SPREAD):
			continue
		if not _capsule_fits(at) or not _circle_clear(at, CLEAR_RADIUS):
			continue
		evaluated += 1
		tried.append(at)
		var clutter := _clutter(at, SPAWN_CLUTTER)
		for d in DIRECTIONS:
			var yaw := 360.0 * d / DIRECTIONS
			var walk := _walk(at, _direction(yaw))
			if walk < MIN_WALK:
				continue
			var street := _street(at, Basis(Vector3.UP, deg_to_rad(yaw)))
			var score: float = 2.0 * minf(walk, WALK_CAP) / WALK_CAP + street.score - 0.5 * clutter - 0.5 * at.distance_to(_center) / maxf(half, 1.0)
			if best.is_empty() or score > best.score + 1e-6:
				best = {"position": at + Vector3(0, 0.1, 0), "yaw": yaw, "walk": walk, "score": score, "clutter": clutter, "street": street.sides}
	if best.is_empty():
		_check("C8", "FAIL", "no player spawn: needs a walkable point (ground, at most %.0f°) with a %.0f m clear circle and %.0f m of clear walk ahead." % [SPAWN_SLOPE, CLEAR_RADIUS, MIN_WALK])
		return false
	spawn = best
	_set_walk()
	_check("C8", "PASS", "player spawn at %s facing %.0f°, %.0f m of clear walk ahead, %.0f m from the centre of the walkable area; score %.2f (%d trees, lamps, or decor within %.0f m, buildings on %d sides)" % [_text(spawn.position), spawn.yaw,
			minf(spawn.walk, WALK_CAP), (spawn.position as Vector3).distance_to(_center), spawn.score, spawn.clutter, SPAWN_CLUTTER, spawn.street])
	return true


func _set_walk() -> void:
	_walk_from = spawn.position
	_walk_to = (spawn.position as Vector3) + _direction(spawn.yaw) * minf(spawn.walk, WALK_CAP)


func _place_vehicle(override: Dictionary) -> bool:
	if spawn.is_empty():
		return false
	if not override.is_empty():
		var position := _vector(override.position)
		var yaw := float(override.get("yaw", 0.0))
		vehicle = {"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), position), "drive": _drive(position, _direction(yaw))}
		_set_drive()
		_check("C8", "PASS", "vehicle from the configuration at %s, facing %.0f°" % [_text(position), yaw])
		return true
	var best := {}
	var evaluated := 0
	var tried: Array[Vector3] = []
	for sample: Array in _candidates(CAR_SLOPE, spawn.position):
		var at: Vector3 = sample[0]
		if at.distance_to(spawn.position) < CAR_FROM_SPAWN or _segment_distance(at, _walk_from, _walk_to) < CAR_FROM_WALK:
			continue
		if evaluated >= MAX_CANDIDATES or evaluated >= SCORED and not best.is_empty():
			break
		if tried.any(func(p: Vector3) -> bool: return p.distance_to(at) < SPREAD):
			continue
		evaluated += 1
		tried.append(at)
		for d in DIRECTIONS:
			var yaw := 360.0 * d / DIRECTIONS
			var basis := Basis(Vector3.UP, deg_to_rad(yaw))
			var center := _car_area(at, basis)
			if center == Vector3.INF:
				continue
			var drive := _drive(center, basis * Vector3.FORWARD)
			if drive < MIN_DRIVE:
				continue
			var scored := _car_score(center, basis, drive)
			if best.is_empty() or scored.score > best.score + 1e-6:
				best = {"transform": Transform3D(basis, center + Vector3(0, CAR_LIFT, 0)), "drive": drive}
				best.merge(scored)
	if best.is_empty():
		_check("C8", "FAIL", "no vehicle place: needs a clear flat area of %.0f m × %.0f m (heights within %.1f m, at most %.0f°) with %.0f m of clear road ahead." % [CAR_AREA.y, CAR_AREA.x, CAR_HEIGHT_SPREAD, CAR_SLOPE, MIN_DRIVE])
		return false
	vehicle = best
	_set_drive()
	var origin: Vector3 = (vehicle.transform as Transform3D).origin
	_check("C8", "PASS", "vehicle at %s facing %.0f°, %.0f m of clear road ahead, %.0f m from the spawn; score %.2f (%d trees, lamps, or decor within %.0f m, buildings on %d sides, %.1f m of room on its narrower side)" % [_text(origin), _yaw_of(vehicle.transform.basis),
			minf(vehicle.drive, DRIVE_CAP), origin.distance_to(spawn.position), vehicle.score, vehicle.clutter, CLUTTER_RADIUS, vehicle.street, vehicle.room])
	return true


func _set_drive() -> void:
	var t: Transform3D = vehicle.transform
	_drive_from = t.origin
	_drive_to = t.origin + t.basis * Vector3.FORWARD * minf(vehicle.drive, DRIVE_CAP)


## The ground centre of a clear, flat car area at `at` turned by `basis`, or
## Vector3.INF when it does not qualify.
func _car_area(at: Vector3, basis: Basis) -> Vector3:
	var heights := PackedFloat32Array()
	for corner in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var offset := basis * Vector3(corner.x * CAR_AREA.x * 0.5, 0.0, corner.y * CAR_AREA.y * 0.5)
		var hit := ground_hit(at.x + offset.x, at.z + offset.z, at.y + 3.0, at.y - 3.0)
		if category_at(hit) != "ground" or rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP)) > CAR_SLOPE:
			return Vector3.INF
		heights.append((hit.position as Vector3).y)
	var spread := 0.0
	for h in heights:
		spread = maxf(spread, absf(h - heights[0]))
	if spread > CAR_HEIGHT_SPREAD:
		return Vector3.INF
	var center := Vector3(at.x, heights[0], at.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(CAR_AREA.x, 2.2, CAR_AREA.y)
	if _overlaps(shape, Transform3D(basis, center + Vector3(0, CAR_LIFT + 1.1, 0))):
		return Vector3.INF
	return center


## How good a car place is (higher is better): the drive ahead (up to 40 m:
## 2 points), the room to its sides beyond 2.5 m (up to SIDE_ROOM: 1 point),
## a building within STREET_REACH to a side (a street: 1, on both sides 1.5),
## minus 0.5 for every tree, lamp, or decor collider within CLUTTER_RADIUS
## (at most 6), minus a point per FAR_FROM_SPAWN beyond that distance from
## the spawn.
func _car_score(center: Vector3, basis: Basis, drive: float) -> Dictionary:
	var street := _street(center, basis)
	var room := clampf((minf(street.room, SIDE_ROOM) - 2.5) / (SIDE_ROOM - 2.5), 0.0, 1.0)
	var clutter := mini(_clutter(center, CLUTTER_RADIUS), 6)
	var far := maxf(0.0, center.distance_to(spawn.position) - FAR_FROM_SPAWN) / FAR_FROM_SPAWN
	return {"score": 2.0 * minf(drive, DRIVE_CAP) / DRIVE_CAP + room + street.score - 0.5 * clutter - far,
			"clutter": clutter, "street": street.sides, "room": street.room}


## What lies to the left and right of `at` (facing -Z of `basis`), 1.2 m
## above the ground: {"sides": how many end at a building within
## STREET_REACH, "score": 0, 1, or 1.5 for those, "room": metres to the
## nearer collider on either side}.
func _street(at: Vector3, basis: Basis) -> Dictionary:
	var sides := 0
	var room := STREET_REACH
	for side in [basis * Vector3.RIGHT, basis * Vector3.LEFT]:
		var from := at + Vector3(0, 1.2, 0)
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + (side as Vector3) * STREET_REACH, 1))
		if hit.is_empty():
			continue
		room = minf(room, from.distance_to(hit.position))
		if category_at(hit) == "buildings":
			sides += 1
	return {"sides": sides, "score": [0.0, 1.0, 1.5][sides], "room": room}


## How many tree, lamp, and decor colliders stand within `radius` of `at`.
func _clutter(at: Vector3, radius: float) -> int:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 3.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 1.6, 0))
	query.collision_mask = 1
	var count := 0
	for hit: Dictionary in _space.intersect_shape(query, 64):
		if _categories.get((hit.collider as Object).get_instance_id(), "") in CLUTTER:
			count += 1
	return count


## Metres a car can drive from `from` along `direction` (2 m steps, a 3 m
## wide box clear between 0.3 and 1.8 m above the ground, ground under it).
func _drive(from: Vector3, direction: Vector3) -> float:
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 1.5, DRIVE_STEP)
	var basis := Basis.looking_at(direction, Vector3.UP)
	var last := from
	var distance := 0.0
	while distance < DRIVE_CAP:
		var next := last + direction * DRIVE_STEP
		var hit := ground_hit(next.x, next.z, last.y + 3.0, last.y - 3.0)
		if category_at(hit) != "ground" or absf((hit.position as Vector3).y - last.y) > DRIVE_HEIGHT:
			break
		next = hit.position
		if _overlaps(shape, Transform3D(basis, next + Vector3(0, 0.3 + 0.75, 0))):
			break
		last = next
		distance += DRIVE_STEP
	return distance


## Metres the player can walk from `from` along `direction` (1 m steps).
func _walk(from: Vector3, direction: Vector3, cap := WALK_CAP) -> float:
	var last := from
	var distance := 0.0
	while distance < cap:
		var next := last + direction
		var hit := ground_hit(next.x, next.z, last.y + 2.0, last.y - 2.0)
		if category_at(hit) != "ground" or absf((hit.position as Vector3).y - last.y) > STEP_HEIGHT:
			break
		next = hit.position
		if not _capsule_fits(next):
			break
		last = next
		distance += 1.0
	return distance


func _place_route(override: Array) -> bool:
	if spawn.is_empty():
		return false
	if not override.is_empty():
		for point in override:
			route.append(_vector(point))
		_check("C8", "PASS", "NPC route from the configuration: %d points" % route.size())
		return true
	var evaluated := 0
	for sample: Array in _candidates(SPAWN_SLOPE, spawn.position):
		var at: Vector3 = sample[0]
		if not _route_point_ok(at):
			continue
		if evaluated >= MAX_CANDIDATES:
			break
		evaluated += 1
		if not _capsule_fits(at):
			continue
		for length in ROUTE_LENGTHS:
			for d in DIRECTIONS:
				var direction := _direction(360.0 * d / DIRECTIONS)
				if _walk(at, direction, length) < length:
					continue
				var end := at + direction * length
				var hit := ground_hit(end.x, end.z, at.y + 3.0, at.y - 3.0)
				if hit.is_empty() or not _route_point_ok(hit.position):
					continue
				route = [at + Vector3(0, 0.1, 0), (hit.position as Vector3) + Vector3(0, 0.1, 0)]
				_check("C8", "PASS", "NPC route %s → %s (%.0f m), %.0f m from the spawn" % [_text(route[0]), _text(route[1]), length, at.distance_to(spawn.position)])
				return true
	_check("C8", "FAIL", "no NPC route: needs two walkable points 8–16 m apart, at least %.0f m from the spawn, with a clear path between them." % ROUTE_FROM_SPAWN)
	return false


func _route_point_ok(at: Vector3) -> bool:
	return at.distance_to(spawn.position) >= ROUTE_FROM_SPAWN and _segment_distance(at, _walk_from, _walk_to) >= ROUTE_FROM_WALK \
			and (vehicle.is_empty() or _segment_distance(at, _drive_from, _drive_to) >= ROUTE_FROM_DRIVE)


func _place_viewpoints() -> void:
	if spawn.is_empty():
		return
	var taken: Array[Vector3] = [spawn.position]
	var stride := maxi(1, _samples.size() / 2000)
	var scored := []
	for i in range(0, _samples.size(), stride):
		var sample: Array = _samples[i]
		if sample[2] <= SPAWN_SLOPE:
			scored.append(sample[0])
	scored.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(_center) < b.distance_squared_to(_center))
	for at: Vector3 in scored:
		if viewpoints.size() >= VIEWPOINTS:
			break
		if taken.any(func(p: Vector3) -> bool: return p.distance_to(at) < VIEWPOINT_SPACING):
			continue
		if not _capsule_fits(at) or not _circle_clear(at, CLEAR_RADIUS):
			continue
		var to_center := _center - at
		var yaw := atan2(-to_center.x, -to_center.z) if Vector2(to_center.x, to_center.z).length() > 1.0 else 0.0
		viewpoints.append(Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 0.1, 0)))
		viewpoint_names.append("View %s" % ["A", "B", "C", "D"][viewpoints.size() - 1])
		taken.append(at)
	if viewpoints.size() < VIEWPOINTS:
		_check("C8", "WARN", "only %d viewpoints %.0f m apart with a %.0f m clear circle (3 wanted)" % [viewpoints.size(), VIEWPOINT_SPACING, CLEAR_RADIUS])
	for i in viewpoints.size():
		lines.append("%s at %s facing %.0f°" % [viewpoint_names[i], _text(viewpoints[i].origin), _yaw_of(viewpoints[i].basis)])


func _place_sloped_viewpoint() -> void:
	if spawn.is_empty():
		return
	var evaluated := 0
	for sample: Array in _candidates(SLOPE_RANGE.y, spawn.position):
		if sample[2] < SLOPE_RANGE.x:
			continue
		if evaluated >= MAX_CANDIDATES:
			break
		evaluated += 1
		var at: Vector3 = sample[0]
		var normal: Vector3 = sample[1]
		var downhill := Vector3(normal.x, 0.0, normal.z).normalized()
		var basis := Basis.looking_at(downhill, Vector3.UP) if downhill.length() > 0.5 else Basis.IDENTITY
		var shape := BoxShape3D.new()
		shape.size = Vector3(CAR_AREA.x, 2.2, CAR_AREA.y)
		if _overlaps(shape, Transform3D(basis, at + Vector3(0, CAR_LIFT + 1.6, 0))):
			continue
		var ok := true
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var offset := basis * Vector3(corner.x * CAR_AREA.x * 0.5, 0.0, corner.y * CAR_AREA.y * 0.5)
			var hit := ground_hit(at.x + offset.x, at.z + offset.z, at.y + 4.0, at.y - 4.0)
			var slope := rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP)) if not hit.is_empty() else 0.0
			if category_at(hit) != "ground" or slope < SLOPE_RANGE.x or slope > SLOPE_RANGE.y:
				ok = false
				break
		if not ok:
			continue
		viewpoints.append(Transform3D(basis, at + Vector3(0, 0.1, 0)))
		viewpoint_names.append("Sloped street")
		sloped_viewpoint = viewpoints.size() - 1
		lines.append("Sloped street at %s (%.1f°), for the device scenario's parked-on-a-slope steps" % [_text(at), sample[2]])
		return
	_check("C8", "INFO", "no sloped viewpoint (ground %.0f–%.0f° with room for a car): the device scenario skips its slope steps" % [SLOPE_RANGE.x, SLOPE_RANGE.y])


## Whether the player's capsule fits standing at `at` (0.2 m above it).
func _capsule_fits(at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	return not _overlaps(shape, Transform3D(Basis.IDENTITY, at + Vector3(0, CAPSULE_HEIGHT * 0.5 + 0.2, 0)))


## Whether no collider is within `radius` of `at` between 0.5 and 2.0 m above it.
func _circle_clear(at: Vector3, radius: float) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.5
	return not _overlaps(shape, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.25, 0)))


func _overlaps(shape: Shape3D, transform: Transform3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = 1
	return not _space.intersect_shape(query, 1).is_empty()


static func _direction(yaw_degrees: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_degrees)) * Vector3.FORWARD


static func _yaw_of(basis: Basis) -> float:
	var forward := basis * Vector3.FORWARD
	return fposmod(rad_to_deg(atan2(-forward.x, -forward.z)), 360.0)


static func _segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var closest := Geometry2D.get_closest_point_to_segment(flat, Vector2(a.x, a.z), Vector2(b.x, b.z))
	return flat.distance_to(closest)


static func _vector(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _text(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _check(id: String, result: String, message: String) -> void:
	checks.append({"id": id, "result": result, "message": message})
