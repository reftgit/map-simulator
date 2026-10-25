class_name VehicleIntent
extends RefCounted
## What the driver wants this physics tick, independent of the input device.
## Filled by a VehicleInputSource, read by VehicleController.

## -1 full left .. 1 full right.
var steer := 0.0
var throttle := 0.0
## Brake pedal; at (almost) standstill it reverses instead.
var brake := 0.0
var handbrake := false
## One-shot: true only on the tick the exit press arrives.
var exit := false


func clear() -> void:
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	handbrake = false
	exit = false
