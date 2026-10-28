class_name AiPatrolInput
extends PlayerInputSource
## Drives a PlayerController along a PatrolRoute the way a stick would: walks
## toward the current point at `move_scale` of the walk speed, stands there
## for the route's wait_seconds, then heads for the next point (after the
## last, the first again). If walking gets the body no closer to the point by
## `min_progress` within `stuck_seconds` (a wall, a car, someone in the way),
## it gives that point up and heads for the next one. It never runs, punches,
## rolls, or follows anyone; it reads only its own body's position and state.

## Reached point `index`; the body waits there now.
signal arrived(index: int)
## Gave up on point `index` after making no progress toward it.
signal gave_up(index: int)

## States in which the body walks by itself; time in others (a hit
## reaction) does not count as being stuck.
const WALKING_STATES: Array[StringName] = [&"Walk", &"Run"]

## Stick tilt: the fraction of PlayerController.walk_speed to walk at.
@export_range(0.1, 1.0) var move_scale := 0.5
## Distance on the ground plane that counts as having reached a point (m).
@export var arrive_distance := 0.6
## Seconds of walking without getting min_progress closer to the point
## before it is given up.
@export var stuck_seconds := 2.0
@export var min_progress := 0.25

## The route to walk. Setting one heads for its second point (the body
## stands on the first).
var route: PatrolRoute:
	set(value):
		route = value
		target_index = 1 if route and route.points.size() > 1 else 0
		_wait_left = 0.0
		_forget_progress()
## The point being walked to.
var target_index := 0

var _wait_left := 0.0
var _closest := INF
var _stalled := 0.0


func fill_intent(intent: PlayerIntent, player: PlayerController) -> void:
	if route == null or route.points.size() < 2:
		return
	var delta := player.get_physics_process_delta_time()
	if _wait_left > 0.0:
		_wait_left -= delta
		return
	var target := route.points[target_index]
	var to_target := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	var distance := to_target.length()
	if distance <= arrive_distance:
		reach_point()
		return
	if player.state_machine.get_state_name() in WALKING_STATES:
		if distance < _closest - min_progress:
			_closest = distance
			_stalled = 0.0
		else:
			_stalled += delta
			if _stalled >= stuck_seconds:
				gave_up.emit(target_index)
				_next_point()
				return
	intent.move = to_target / distance * move_scale


## True while standing at a point.
func is_waiting() -> bool:
	return _wait_left > 0.0


## Seconds still to stand at the point.
func wait_left() -> float:
	return maxf(_wait_left, 0.0)


## The body is at the current point: start the wait and head for the next
## one afterwards (also called by Npc's far mode, which walks without this
## input).
func reach_point() -> void:
	arrived.emit(target_index)
	_wait_left = route.wait_seconds
	_next_point()


## Stops waiting (Npc's far mode waits by itself).
func end_wait() -> void:
	_wait_left = 0.0


func _next_point() -> void:
	target_index = (target_index + 1) % route.points.size()
	_forget_progress()


func _forget_progress() -> void:
	_closest = INF
	_stalled = 0.0
