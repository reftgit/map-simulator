class_name VehicleDefinition
extends Resource
## Tunables of one vehicle type. A new vehicle type is a scene (VehicleBody3D
## with VehicleController, wheels, seat, exit points, interaction area, and a
## VehicleVisual) plus one of these; no code changes.

@export var display_name := ""
@export var mass := 1200.0
## Low centre of mass keeps the body from rolling over in turns.
@export var center_of_mass := Vector3(0.0, 0.25, 0.0)
## Replaces the project's default linear damping (0.1, which would cap the
## speed well below max_speed); 0 leaves max_speed to the engine curve.
@export var linear_damp := 0.0

@export_group("Engine")
## Force per traction wheel (N) from standstill; it fades to 0 at max_speed.
@export var engine_force := 3000.0
## Top forward speed in m/s.
@export var max_speed := 22.0
## Force per traction wheel when reversing; it fades to 0 at max_reverse_speed.
@export var reverse_force := 2000.0
@export var max_reverse_speed := 6.0
## Holding the brake below this forward speed (m/s) reverses instead.
@export var reverse_threshold := 1.0

@export_group("Brakes")
@export var brake_force := 30.0
## Applied to the non-steering (rear) wheels.
@export var handbrake_force := 60.0
## Braking when no pedal is pressed (rolling resistance).
@export var coast_brake := 1.0
## Below this speed (m/s) with no pedal pressed, the brakes hold the vehicle
## (it does not roll away on slopes).
@export var hold_speed := 0.5

@export_group("Steering")
@export var max_steer_degrees := 30.0
## Wheel angle at max_speed; steering narrows linearly with speed. Large
## angles at speed roll the body over (8° did at 21 m/s on GodotPhysics3D).
@export var steer_at_max_speed_degrees := 5.0
## Steering input change per second toward the pressed side, and back to
## centre when released.
@export var steer_rate := 3.0
@export var steer_return_rate := 4.0

@export_group("Exit and reset")
## The driver can get out at or below this speed (m/s).
@export var safe_exit_speed := 1.5
## Tilt beyond this angle from upright counts as flipped.
@export var flip_angle_degrees := 70.0
## Seconds flipped (and nearly still) before the vehicle resets to its spawn.
@export var flip_reset_seconds := 2.0
@export var flip_reset_max_speed := 2.0

@export_group("Camera")
## Framing while driving.
@export var camera_profile: CameraProfile
