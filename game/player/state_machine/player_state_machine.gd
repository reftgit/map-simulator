class_name PlayerStateMachine
extends Node
## Runs the player's active state. States are the PlayerState children of this
## node, addressed by node name. Later actions (punch, roll, vehicle) are added
## as new child states.

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: PlayerState

var current: PlayerState

var _states := {}  # StringName -> PlayerState


func setup(player: PlayerController) -> void:
	for child in get_children():
		var state := child as PlayerState
		if state:
			state.player = player
			state.machine = self
			_states[state.name] = state
	current = initial_state
	current.enter(&"")


func physics_update(delta: float) -> void:
	current.physics_update(delta)


func transition_to(state_name: StringName) -> void:
	if current and current.name == state_name:
		return
	var next: PlayerState = _states.get(state_name)
	assert(next != null, "Unknown player state: %s" % state_name)
	var previous := current.name
	current.exit()
	current = next
	current.enter(previous)
	state_changed.emit(previous, state_name)


func get_state_name() -> StringName:
	return current.name if current else &""
