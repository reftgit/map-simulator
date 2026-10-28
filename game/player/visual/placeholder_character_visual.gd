class_name PlaceholderCharacterVisual
extends CharacterVisual
## Capsule stand-in until a character model exists: leans with speed, thrusts
## a fist forward for a punch, tucks and tumbles forward for a roll, flinches
## back when hit. Tweens
## run on physics ticks, so physics interpolation smooths them like the
## body's own movement.

## Forward lean at `full_lean_speed` m/s and above.
@export var max_lean_degrees := 8.0
@export var full_lean_speed := 8.0
## How far the fist travels forward from its rest position.
@export var punch_reach := 0.55

var _tween: Tween

@onready var _pivot: Node3D = $Pivot
@onready var _fist: Node3D = $Pivot/Fist
@onready var _pivot_rest := _pivot.position
@onready var _fist_rest := _fist.position


func set_locomotion(speed: float, on_floor: bool) -> void:
	if is_playing():
		return
	var lean := deg_to_rad(max_lean_degrees) * clampf(speed / full_lean_speed, 0.0, 1.0) if on_floor else 0.0
	_pivot.rotation.x = lerpf(_pivot.rotation.x, -lean, 0.2)


func play_action(action: StringName, duration: float, impact := -1.0) -> void:
	stop_action()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	match action:
		&"punch":
			var reach := impact if impact > 0.0 else duration * 0.25
			var back := (duration - reach) * 0.7
			_fist.visible = true
			_tween.tween_property(_fist, "position", _fist_rest + Vector3(-0.05, 0.1, -punch_reach), reach).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_pivot, "rotation:x", -0.15, reach)
			_tween.tween_interval(duration - reach - back)
			_tween.tween_property(_fist, "position", _fist_rest, back)
			_tween.parallel().tween_property(_pivot, "rotation:x", 0.0, back)
		&"roll":
			# Tuck into a ball near the ground and turn forward once.
			_tween.set_parallel(true)
			_tween.tween_property(_pivot, "rotation:x", -TAU, duration).from(0.0)
			_tween.tween_property(_pivot, "scale:y", 0.6, duration * 0.2)
			_tween.tween_property(_pivot, "position:y", 0.55, duration * 0.2)
			_tween.tween_property(_pivot, "scale:y", 1.0, duration * 0.2).set_delay(duration * 0.8)
			_tween.tween_property(_pivot, "position:y", _pivot_rest.y, duration * 0.2).set_delay(duration * 0.8)
		&"hit":
			# Flinch: rock back and squash a little, then straighten up.
			_tween.tween_property(_pivot, "rotation:x", 0.35, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_pivot, "scale", Vector3(1.08, 0.9, 1.08), duration * 0.25)
			_tween.tween_property(_pivot, "rotation:x", 0.0, duration * 0.75)
			_tween.parallel().tween_property(_pivot, "scale", Vector3.ONE, duration * 0.75)
	_tween.chain().tween_callback(stop_action)


func stop_action() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_pivot.position = _pivot_rest
	_pivot.rotation = Vector3.ZERO
	_pivot.scale = Vector3.ONE
	_fist.position = _fist_rest
	_fist.visible = false


func is_playing() -> bool:
	return _tween != null and _tween.is_running()
