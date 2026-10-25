class_name VehicleController
extends VehicleBody3D
## Drivable vehicle. Each physics tick it reads a VehicleIntent from its input
## source (without one it stands parked with the handbrake on), turns it into
## engine, brake, and steering values from its VehicleDefinition, and resets
## to its spawn after falling below the kill height or staying flipped.
## VehicleBody3D drives along +Z, so a vehicle's forward is +Z (the player's
## is -Z); cameras use get_follow_yaw() to sit behind it. Positive
## VehicleBody3D steering turns left, so intent steering is negated.

signal exit_requested
signal respawned

## Tolerance for "no input" comparisons.
const EPSILON := 0.001

@export var definition: VehicleDefinition
@export var visual: VehicleVisual
## Where a seated driver is kept.
@export var seat: Node3D
## Places to get out, tried in order (driver's side first).
@export var exit_points: Array[Node3D] = []
## Detects a player close enough to get in.
@export var interaction_area: Area3D

var input_source: VehicleInputSource
var intent := VehicleIntent.new()
## VehicleWheel3D children in scene order.
var wheels: Array[VehicleWheel3D] = []
## Smoothed steering input, -1 (left) .. 1 (right).
var steer := 0.0
var reversing := false
## Set by whoever places the vehicle; reset target.
var spawn_transform := Transform3D.IDENTITY
## Falling below this height resets the vehicle.
var kill_height := -INF

var _flipped_for := 0.0
var _hold_handbrake := false


func _ready() -> void:
	mass = definition.mass
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = definition.center_of_mass
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = definition.linear_damp
	for child in get_children():
		if child is VehicleWheel3D:
			wheels.append(child)
	spawn_transform = global_transform


func _physics_process(delta: float) -> void:
	intent.clear()
	if input_source:
		input_source.fill_intent(intent, self)
	else:
		intent.handbrake = true
	if _hold_handbrake:
		if intent.throttle > EPSILON or intent.brake > EPSILON:
			_hold_handbrake = false
		else:
			intent.handbrake = true
	if intent.exit:
		exit_requested.emit()
	var speed := get_forward_speed()
	steer = approach_steer(steer, intent.steer, delta, definition)
	steering = -steer_angle(steer, speed, definition)
	var command := drive_command(intent, speed, definition)
	engine_force = command.engine
	for wheel in wheels:
		wheel.brake = command.brake if wheel.use_as_steering else maxf(command.brake, command.handbrake)
	reversing = command.engine < 0.0
	_check_reset(delta)
	if visual:
		visual.set_drive_state(speed, steer, command.brake > definition.coast_brake or command.handbrake > 0.0, reversing)
		var poses: Array[Transform3D] = []
		for wheel in wheels:
			poses.append(wheel.transform)
		visual.set_wheel_transforms(poses)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			release_controls()


## Drops throttle and holds the handbrake until the driver presses a pedal
## again (focus loss, pause, the driver getting out).
func release_controls() -> void:
	_hold_handbrake = true
	engine_force = 0.0


## Speed along the vehicle's forward (+Z) axis; negative when reversing.
func get_forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


## Yaw that puts a camera behind the vehicle (its forward is +Z).
func get_follow_yaw() -> float:
	return global_rotation.y + PI


func can_exit_at_current_speed() -> bool:
	return linear_velocity.length() <= definition.safe_exit_speed


## A free standing place next to one of the exit points, in order, for a body
## with `shape` whose origin is `shape_height` above its feet; null when every
## exit point is blocked or has no floor below it.
func find_exit_transform(shape: Shape3D, shape_height: float, exclude: Array[RID] = []) -> Variant:
	var space := get_world_3d().direct_space_state
	var mask := collision_mask
	var ray_exclude: Array[RID] = [get_rid()]
	ray_exclude.append_array(exclude)
	for point in exit_points:
		var origin := point.global_position
		var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 2.0, origin + Vector3.DOWN * 3.0, mask, ray_exclude)
		var floor_hit := space.intersect_ray(ray)
		if floor_hit.is_empty():
			continue
		var feet: Vector3 = floor_hit.position + Vector3.UP * 0.05
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * shape_height)
		query.collision_mask = mask
		query.exclude = exclude
		if space.intersect_shape(query, 1).is_empty():
			return Transform3D(Basis(Vector3.UP, get_follow_yaw()), feet)
	return null


## Puts the vehicle at `target`, facing its -Z (the convention of map spawns
## and viewpoints), at rest. With `as_spawn`, resets come back here.
func place_at(target: Transform3D, as_spawn := false) -> void:
	global_transform = Transform3D(target.basis * Basis(Vector3.UP, PI), target.origin)
	if as_spawn:
		spawn_transform = global_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steer = 0.0
	reset_physics_interpolation()


func reset_to_spawn() -> void:
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steer = 0.0
	_flipped_for = 0.0
	reset_physics_interpolation()
	respawned.emit()


func _check_reset(delta: float) -> void:
	if global_position.y < kill_height:
		reset_to_spawn()
		return
	var flipped := global_basis.y.dot(Vector3.UP) < cos(deg_to_rad(definition.flip_angle_degrees))
	if flipped and linear_velocity.length() < definition.flip_reset_max_speed:
		_flipped_for += delta
		if _flipped_for >= definition.flip_reset_seconds:
			reset_to_spawn()
	else:
		_flipped_for = 0.0


## Steering input after one tick: toward `target` at steer_rate, back to the
## centre at steer_return_rate when released.
static func approach_steer(current: float, target: float, delta: float, def: VehicleDefinition) -> float:
	if absf(target) < EPSILON:
		return move_toward(current, 0.0, def.steer_return_rate * delta)
	return move_toward(current, target, def.steer_rate * delta)


## Wheel angle in radians for steering input `input` at forward speed `speed`.
static func steer_angle(input: float, speed: float, def: VehicleDefinition) -> float:
	var limit := lerpf(def.max_steer_degrees, def.steer_at_max_speed_degrees, clampf(absf(speed) / def.max_speed, 0.0, 1.0))
	return deg_to_rad(limit) * input


## Engine force per traction wheel, brake per wheel, and handbrake for the
## rear wheels, from the pedals at forward speed `speed`:
## throttle accelerates (and first stops a vehicle rolling backwards); brake
## slows a vehicle moving forward faster than reverse_threshold and reverses
## below it; both pedals brake; no pedal coasts, or holds below hold_speed;
## the handbrake cuts the engine.
static func drive_command(input: VehicleIntent, speed: float, def: VehicleDefinition) -> Dictionary:
	var engine := 0.0
	var brake := def.coast_brake
	var throttle := input.throttle > EPSILON
	var braking := input.brake > EPSILON
	if throttle and braking:
		brake = def.brake_force * input.brake
	elif throttle:
		if speed < -def.reverse_threshold:
			brake = def.brake_force * input.throttle
		else:
			engine = def.engine_force * input.throttle * clampf(1.0 - speed / def.max_speed, 0.0, 1.0)
			brake = 0.0
	elif braking:
		if speed > def.reverse_threshold:
			brake = def.brake_force * input.brake
		else:
			engine = -def.reverse_force * input.brake * clampf(1.0 + speed / def.max_reverse_speed, 0.0, 1.0)
			brake = 0.0
	elif absf(speed) < def.hold_speed:
		brake = def.brake_force
	var handbrake := def.handbrake_force if input.handbrake else 0.0
	if input.handbrake:
		engine = 0.0
	return {"engine": engine, "brake": brake, "handbrake": handbrake}
