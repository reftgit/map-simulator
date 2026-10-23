class_name PlayerInputSource
extends Node
## Base for anything that drives a PlayerController: touch controls today,
## AI or replays later. Called once per physics tick by the controller.


func fill_intent(_intent: PlayerIntent, _player: PlayerController) -> void:
	pass
