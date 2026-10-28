class_name CharacterVisual
extends Node3D
## What the character looks like. PlayerController and the states ask for
## feedback only through these methods and never touch meshes, tweens, or
## animation nodes, so a model with an AnimationTree can replace the
## placeholder without changing the controller or the states. This base does
## nothing; subclasses override what they show. Called from physics ticks.


## Every physics tick: horizontal speed in m/s and whether the body stands on a floor.
func set_locomotion(_speed: float, _on_floor: bool) -> void:
	pass


## Starts the one-shot action `action` (&"punch", &"roll", &"hit") lasting `duration`
## seconds. `impact` is when it should look like it connects (a punch's
## active phase), or a negative value when there is no such moment.
func play_action(_action: StringName, _duration: float, _impact := -1.0) -> void:
	pass


## Ends the current action at once and returns to the locomotion pose: the
## action finished or was cut short (cancelled, interrupted, respawned).
func stop_action() -> void:
	pass
