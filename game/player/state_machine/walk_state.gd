extends PlayerState
## Walking; speed follows how far the stick is tilted.


func physics_update(delta: float) -> void:
	if start_buffered_action():
		return
	if not player.intent.has_move():
		machine.transition_to(&"Idle")
	elif player.intent.run:
		machine.transition_to(&"Run")
	else:
		player.apply_locomotion(player.walk_speed, delta)
