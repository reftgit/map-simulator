class_name ThirdPersonCamera
extends Node3D
## Orbit camera that follows a target. Look input turns yaw and pitch; a
## SpringArm3D pulls the camera in front of walls. Target and profile can be
## swapped at runtime (on foot, vehicle). "Behind" the target is its yaw, or
## its get_follow_yaw() if it has one (vehicles face +Z). A profile with
## follow_yaw_sharpness swings the camera back behind the target after a
## pause in look input (vehicle follow mode).

@export var profile: CameraProfile

var target: Node3D
var input: MobileInputController
var yaw := 0.0
var pitch := 0.0

var _since_look := 0.0

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _arm: SpringArm3D = $PitchPivot/SpringArm3D
@onready var camera: Camera3D = $PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	# Moved in _process from the target's interpolated transform.
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	apply_profile(profile)


func set_target(new_target: Node3D, new_profile: CameraProfile = null) -> void:
	target = new_target
	if new_profile:
		apply_profile(new_profile)
	_arm.clear_excluded_objects()
	var body := target as CollisionObject3D
	if body:
		_arm.add_excluded_object(body.get_rid())
	snap_behind_target()


func apply_profile(new_profile: CameraProfile) -> void:
	profile = new_profile
	_arm.spring_length = profile.distance
	pitch = deg_to_rad(profile.default_pitch_degrees)
	_apply_rotation()


## Places the camera directly behind the target with no smoothing.
func snap_behind_target() -> void:
	if target == null:
		return
	yaw = _target_yaw()
	_since_look = 0.0
	global_position = _pivot_goal()
	_apply_rotation()


## Adds look input in radians: x turns left/right, y tilts up/down.
func add_look(delta: Vector2) -> void:
	yaw = wrapf(yaw - delta.x, -PI, PI)
	pitch = clampf(pitch - delta.y, deg_to_rad(profile.min_pitch_degrees), deg_to_rad(profile.max_pitch_degrees))
	_apply_rotation()


func get_arm_length() -> float:
	return _arm.get_hit_length()


func _process(delta: float) -> void:
	_since_look += delta
	if input:
		var look := input.consume_look_delta()
		if look != Vector2.ZERO:
			_since_look = 0.0
		add_look(look)
	if target == null:
		return
	if profile.follow_yaw_sharpness > 0.0 and _since_look >= profile.follow_delay:
		yaw = lerp_angle(yaw, _target_yaw(), 1.0 - exp(-profile.follow_yaw_sharpness * delta))
		_apply_rotation()
	var goal := _pivot_goal()
	var y := lerpf(global_position.y, goal.y, 1.0 - exp(-profile.vertical_sharpness * delta))
	global_position = Vector3(goal.x, y, goal.z)


func _target_yaw() -> float:
	return target.get_follow_yaw() if target.has_method(&"get_follow_yaw") else target.global_rotation.y


func _pivot_goal() -> Vector3:
	return target.get_global_transform_interpolated().origin + Vector3.UP * profile.pivot_height


func _apply_rotation() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)
