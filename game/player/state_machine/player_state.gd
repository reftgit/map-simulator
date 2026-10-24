class_name PlayerState
extends Node
## One player state. Subclasses override the hooks and switch states through
## `machine.transition_to()`.

var player: PlayerController
var machine: PlayerStateMachine


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## The locomotion state that matches the current intent.
func locomotion_state() -> StringName:
	if not player.intent.has_move():
		return &"Idle"
	return &"Run" if player.intent.run else &"Walk"


## Starts a buffered action if the body stands on a floor: a roll first, then
## a punch unless `roll_only`. Returns true when the state changed. Actions
## never start in the air; their presses stay buffered until they expire.
func start_buffered_action(roll_only := false) -> bool:
	if not player.is_on_floor():
		return false
	if player.actions.take(&"roll"):
		machine.transition_to(&"Roll")
		return true
	if not roll_only and player.actions.take(&"punch"):
		machine.transition_to(&"Punch")
		return true
	return false
