class_name PlayerController
extends CharacterBody3D
## On-foot character body. Each physics tick it reads a PlayerIntent from its
## input source, lets the PlayerStateMachine pick speeds and transitions, then
## moves. Forward is -Z.

@export var walk_speed := 4.5
@export var run_speed := 8.0
@export var acceleration := 22.0
@export var deceleration := 28.0
## How quickly the body turns toward the movement direction.
@export var turn_sharpness := 12.0
@export var gravity_scale := 2.0

var input_source: PlayerInputSource
var intent := PlayerIntent.new()

@onready var state_machine: PlayerStateMachine = $StateMachine


func _ready() -> void:
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	intent.clear()
	if input_source:
		input_source.fill_intent(intent, self)
	state_machine.physics_update(delta)
	move_and_slide()


## Steers horizontal velocity toward the intent direction at `max_speed`.
## With `analog`, a half-tilted stick gives half speed.
func apply_locomotion(max_speed: float, delta: float, analog := true) -> void:
	var direction := intent.move if analog else intent.move.normalized()
	var target := direction * max_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if target.length_squared() >= horizontal.length_squared() else deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
	if intent.has_move():
		var goal_yaw := atan2(-intent.move.x, -intent.move.z)
		rotation.y = lerp_angle(rotation.y, goal_yaw, 1.0 - exp(-turn_sharpness * delta))


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Moves the player instantly, e.g. to a spawn point. Stops all motion.
func teleport(target: Transform3D) -> void:
	global_position = target.origin
	rotation.y = target.basis.get_euler().y
	velocity = Vector3.ZERO
	state_machine.transition_to(&"Idle")
	reset_physics_interpolation()
