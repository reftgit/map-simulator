extends PlayerState
## Running at full speed in the stick direction, regardless of tilt.


func physics_update(delta: float) -> void:
	if start_buffered_action():
		return
	if not player.intent.has_move():
		machine.transition_to(&"Idle")
	elif not player.intent.run:
		machine.transition_to(&"Walk")
	else:
		player.apply_locomotion(player.run_speed, delta, false)
