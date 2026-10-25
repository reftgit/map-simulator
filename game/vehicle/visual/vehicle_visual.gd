class_name VehicleVisual
extends Node3D
## What a vehicle looks like. VehicleController calls these every physics tick
## and never touches meshes itself, so a modelled vehicle can replace the
## placeholder without changing the controller. This base does nothing.


## Forward speed in m/s (negative when reversing), smoothed steering -1..1,
## and whether brakes or reverse are engaged (for lights).
func set_drive_state(_speed: float, _steer: float, _braking: bool, _reversing: bool) -> void:
	pass


## Wheel poses (spin, steering, suspension) relative to the vehicle, in the
## order of VehicleController.wheels.
func set_wheel_transforms(_transforms: Array[Transform3D]) -> void:
	pass
