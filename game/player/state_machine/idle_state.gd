extends PlayerState
## Standing still; slows to a stop and waits for movement or an action.


func physics_update(delta: float) -> void:
	if start_buffered_action():
		return
	player.apply_locomotion(0.0, delta)
	if player.intent.has_move():
		machine.transition_to(&"Run" if player.intent.run else &"Walk")
