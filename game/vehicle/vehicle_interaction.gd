class_name VehicleInteraction
extends Node
## Gets the player into and out of vehicles. Shows the interact button while
## a vehicle is in reach and the player stands on a floor; entering seats the
## player and switches the HUD control group, the vehicle's input source, and
## the camera profile. Exiting is allowed at or below the vehicle's safe exit
## speed and needs a free place beside it (driver's side first). Driving
## itself is VehicleController's job.

signal entered(vehicle: VehicleController)
signal exited(vehicle: VehicleController)
## An exit request was turned down: "speed" (too fast) or "blocked".
signal exit_refused(reason: String)

var player: PlayerController
var camera: ThirdPersonCamera
var input: MobileInputController
## Drives whichever vehicle the player is in.
var vehicle_input: VehicleInputSource
## Restored on exit.
var on_foot_profile: CameraProfile
## The vehicle being driven, or null on foot.
var vehicle: VehicleController

var _in_reach: Array[VehicleController] = []


func setup(new_player: PlayerController, new_camera: ThirdPersonCamera, new_input: MobileInputController, new_vehicle_input: VehicleInputSource) -> void:
	player = new_player
	camera = new_camera
	input = new_input
	vehicle_input = new_vehicle_input
	on_foot_profile = camera.profile
	player.interact_requested.connect(_on_interact_requested)


func register_vehicle(candidate: VehicleController) -> void:
	candidate.interaction_area.body_entered.connect(_on_reach_entered.bind(candidate))
	candidate.interaction_area.body_exited.connect(_on_reach_exited.bind(candidate))
	candidate.exit_requested.connect(request_exit)


## Closest vehicle in reach, or null.
func nearby_vehicle() -> VehicleController:
	var best: VehicleController = null
	for candidate in _in_reach:
		if best == null or candidate.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = candidate
	return best


func can_enter() -> bool:
	return vehicle == null and nearby_vehicle() != null and player.is_on_floor()


func is_driving() -> bool:
	return vehicle != null


func enter(target: VehicleController) -> void:
	vehicle = target
	player.set_seated(true)
	player.global_transform = target.seat.global_transform
	input.set_vehicle_mode(true)
	target.input_source = vehicle_input
	camera.set_target(target, target.definition.camera_profile)
	entered.emit(target)


## Gets out if the vehicle is slow enough and a side is free; returns whether
## the player got out.
func request_exit() -> bool:
	if vehicle == null:
		return false
	if not vehicle.can_exit_at_current_speed():
		exit_refused.emit("speed")
		return false
	var place: Variant = vehicle.find_exit_transform(player.body_shape.shape, player.body_shape.position.y, [player.get_rid()])
	if place == null:
		exit_refused.emit("blocked")
		return false
	var left := vehicle
	vehicle = null
	left.input_source = null
	left.release_controls()
	player.set_seated(false)
	player.teleport(place)
	input.set_vehicle_mode(false)
	camera.set_target(player, on_foot_profile)
	exited.emit(left)
	return true


func _physics_process(_delta: float) -> void:
	if vehicle:
		player.global_transform = vehicle.seat.global_transform
	elif input and player:
		input.set_interact_available(can_enter())


func _on_interact_requested() -> void:
	if can_enter():
		enter(nearby_vehicle())


func _on_reach_entered(body: Node3D, candidate: VehicleController) -> void:
	if body == player and candidate not in _in_reach:
		_in_reach.append(candidate)


func _on_reach_exited(body: Node3D, candidate: VehicleController) -> void:
	if body == player:
		_in_reach.erase(candidate)
