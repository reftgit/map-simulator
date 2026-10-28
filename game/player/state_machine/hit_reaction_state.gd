class_name HitReactionState
extends PlayerState
## Short stagger after a hit: the body is pushed away from the attacker at
## `push_speed`, slows to a stop over the stagger, keeps its facing, and
## ignores movement for `duration`; then a buffered action or the locomotion
## state that matches the intent takes over. Another hit during the stagger
## starts it again. No damage. Entered through react(), called by whoever
## owns the Hurtbox (Npc).

## Tolerance when comparing summed tick times with the duration.
const EPSILON := 0.0001

@export var duration := 0.5
## Speed away from the attacker when the stagger starts (m/s).
@export var push_speed := 2.0

var _time := 0.0
var _away := Vector3.BACK


## Starts the stagger away from `attacker`, or starts it again.
func react(attacker: Node3D) -> void:
	var offset := player.global_position - attacker.global_position if attacker else Vector3.ZERO
	offset.y = 0.0
	_away = offset.normalized() if offset.length() > 0.01 else player.global_basis.z
	if machine.current == self:
		_start()
	else:
		machine.transition_to(name)


func enter(_previous: StringName) -> void:
	_start()


func exit() -> void:
	player.visual.stop_action()


func physics_update(delta: float) -> void:
	if _time >= duration - EPSILON:
		if not start_buffered_action():
			machine.transition_to(locomotion_state())
		return
	_time += delta
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(Vector3.ZERO, push_speed / duration * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.apply_gravity(delta)


func _start() -> void:
	_time = 0.0
	player.velocity.x = _away.x * push_speed
	player.velocity.z = _away.z * push_speed
	player.visual.play_action(&"hit", duration)
