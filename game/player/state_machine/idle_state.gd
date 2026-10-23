extends PlayerState
## Standing still; slows to a stop and waits for movement input.


func physics_update(delta: float) -> void:
	player.apply_locomotion(0.0, delta)
	if player.intent.has_move():
		machine.transition_to(&"Run" if player.intent.run else &"Walk")
