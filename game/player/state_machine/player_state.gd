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
