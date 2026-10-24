class_name RollState
extends PlayerState
## Dodge roll at a constant speed (distance / duration) in a fixed direction:
## where the stick points, relative to the camera, or where the body faces
## when there is no stick input. The body turns to that direction at once.
## Gravity and collisions keep working, so a roll can carry the body off a
## ledge. Roll presses during the roll and its cooldown are ignored; a punch
## pressed near its end runs right after. No damage immunity.

## Tolerance when comparing summed tick times with the duration.
const EPSILON := 0.0001

@export var duration := 0.6
@export var distance := 6.0
## Seconds after a roll before the next one can start.
@export var cooldown := 0.8
## Horizontal speed kept when the roll ends, so the body does not slide on.
@export var exit_speed := 4.5

var direction := Vector3.FORWARD

var _time := 0.0


func enter(_previous: StringName) -> void:
	_time = 0.0
	direction = roll_direction(player.intent, player.rotation.y)
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.actions.block(&"roll", INF)
	player.visual.play_action(&"roll", duration)


func exit() -> void:
	player.actions.block(&"roll", cooldown)
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).limit_length(exit_speed)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.visual.stop_action()


func physics_update(delta: float) -> void:
	if _time >= duration - EPSILON:
		if not start_buffered_action():
			machine.transition_to(locomotion_state())
		return
	_time += delta
	var speed := distance / duration
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.apply_gravity(delta)


## Unit roll direction on the XZ plane: the intent's movement if there is
## any (already camera-relative), otherwise the facing at `facing_yaw`.
static func roll_direction(intent: PlayerIntent, facing_yaw: float) -> Vector3:
	if intent.has_move():
		return Vector3(intent.move.x, 0.0, intent.move.z).normalized()
	return Vector3.FORWARD.rotated(Vector3.UP, facing_yaw)
