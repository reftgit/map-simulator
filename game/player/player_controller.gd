class_name PlayerController
extends CharacterBody3D
## On-foot character body. Each physics tick it reads a PlayerIntent from its
## input source, buffers punch and roll presses, lets the PlayerStateMachine
## pick speeds and transitions, then moves. Visual feedback goes through a
## CharacterVisual. Forward is -Z.

@export var walk_speed := 4.5
@export var run_speed := 8.0
@export var acceleration := 22.0
@export var deceleration := 28.0
## How quickly the body turns toward the movement direction.
@export var turn_sharpness := 12.0
@export var gravity_scale := 2.0
## Seconds a punch or roll press is kept while it cannot start yet.
@export var input_buffer_time := 0.18:
	set(value):
		input_buffer_time = value
		actions.window = value
## Placeholder capsule now; an animated model later (CharacterVisual).
@export var visual: CharacterVisual

var input_source: PlayerInputSource
var intent := PlayerIntent.new()
## Pending punch and roll presses, and the roll cooldown.
var actions := ActionBuffer.new()

@onready var state_machine: PlayerStateMachine = $StateMachine


func _ready() -> void:
	actions.window = input_buffer_time
	if visual == null:
		visual = CharacterVisual.new()
		add_child(visual)
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	intent.clear()
	if input_source:
		input_source.fill_intent(intent, self)
	if intent.punch:
		actions.press(&"punch")
	if intent.roll:
		actions.press(&"roll")
	state_machine.physics_update(delta)
	actions.tick(delta)
	move_and_slide()
	visual.set_locomotion(get_horizontal_speed(), is_on_floor())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if is_node_ready():
				interrupt_actions()


## Steers horizontal velocity toward the intent direction at `max_speed`.
## With `analog`, a half-tilted stick gives half speed; with `turn`, the body
## turns toward the movement direction.
func apply_locomotion(max_speed: float, delta: float, analog := true, turn := true) -> void:
	var direction := intent.move if analog else intent.move.normalized()
	var target := direction * max_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if target.length_squared() >= horizontal.length_squared() else deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	apply_gravity(delta)
	if turn and intent.has_move():
		var goal_yaw := atan2(-intent.move.x, -intent.move.z)
		rotation.y = lerp_angle(rotation.y, goal_yaw, 1.0 - exp(-turn_sharpness * delta))


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Ends a running punch or roll at once and forgets pending presses, e.g.
## when the app loses focus or pauses. The body returns to Idle.
func interrupt_actions() -> void:
	actions.clear_presses()
	state_machine.transition_to(&"Idle")


## Moves the player instantly, e.g. to a spawn point. Stops all motion and
## any action.
func teleport(target: Transform3D) -> void:
	global_position = target.origin
	rotation.y = target.basis.get_euler().y
	velocity = Vector3.ZERO
	actions.clear_presses()
	state_machine.transition_to(&"Idle")
	reset_physics_interpolation()
