class_name PunchState
extends PlayerState
## Punch in three phases: startup, active (the hitbox is open), recovery. The
## body slows to `move_speed` and keeps its facing. Only the recovery can be
## cancelled, and only by a roll; startup and active always play out. Presses
## during the punch wait in the action buffer: a roll is checked from the
## first recovery tick, a punch or roll when the punch ends. Then locomotion
## resumes.

enum Phase { STARTUP, ACTIVE, RECOVERY, DONE }

## Tolerance when comparing summed tick times with phase boundaries.
const EPSILON := 0.0001

@export var startup := 0.1
@export var active := 0.1
@export var recovery := 0.25
## Top speed while punching; 0 brings the body to a stop.
@export var move_speed := 0.0
@export var hitbox: Hitbox

var phase := Phase.STARTUP

var _time := 0.0  # seconds into the punch at the start of the current tick


func enter(_previous: StringName) -> void:
	_time = 0.0
	phase = Phase.STARTUP
	player.visual.play_action(&"punch", get_duration(), startup)


func exit() -> void:
	hitbox.deactivate()
	player.visual.stop_action()


func physics_update(delta: float) -> void:
	var next := phase_at(_time)
	_time += delta
	if next == Phase.DONE:
		if not start_buffered_action():
			machine.transition_to(locomotion_state())
		return
	if next != phase:
		phase = next
		if phase == Phase.ACTIVE:
			hitbox.activate()
		else:
			hitbox.deactivate()
	if phase == Phase.RECOVERY and start_buffered_action(true):
		return
	player.apply_locomotion(move_speed, delta, true, false)


func get_duration() -> float:
	return startup + active + recovery


## Phase at `time` seconds into the punch.
func phase_at(time: float) -> Phase:
	if time < startup - EPSILON:
		return Phase.STARTUP
	if time < startup + active - EPSILON:
		return Phase.ACTIVE
	if time < get_duration() - EPSILON:
		return Phase.RECOVERY
	return Phase.DONE
