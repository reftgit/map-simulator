class_name TouchPlayerInput
extends PlayerInputSource
## Turns MobileInputController's screen-space stick into a world direction
## relative to the camera, so "stick up" always moves away from the camera.

var input: MobileInputController
var camera: ThirdPersonCamera


func fill_intent(intent: PlayerIntent, _player: PlayerController) -> void:
	if input == null:
		return
	var yaw := camera.yaw if camera else 0.0
	intent.move = camera_relative(input.get_move_vector(), yaw)
	intent.run = input.is_run_active()


## Rotates a screen-space stick (y down = backward) by the camera yaw.
static func camera_relative(stick: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_yaw).limit_length(1.0)
