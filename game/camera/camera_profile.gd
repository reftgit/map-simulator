class_name CameraProfile
extends Resource
## Framing for ThirdPersonCamera. Each controllable thing (on foot, a vehicle)
## gets its own profile, so switching targets also switches framing.

@export var distance := 4.5
## Height of the orbit pivot above the target's origin.
@export var pivot_height := 1.5
@export_range(-89.0, 0.0) var min_pitch_degrees := -65.0
@export_range(0.0, 89.0) var max_pitch_degrees := 35.0
@export_range(-89.0, 89.0) var default_pitch_degrees := -15.0
## Smoothing of the pivot's vertical follow (steps, curbs). Higher is tighter.
@export var vertical_sharpness := 12.0
