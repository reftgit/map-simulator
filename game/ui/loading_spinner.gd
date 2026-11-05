class_name LoadingSpinner
extends Control
## The loading screen's turning arc (UIController): it turns on in every frame
## it is shown, by the time the frame took, so a frame that blocks the main
## thread shows as a stop. Counts the frames it was drawn in for the LOADING
## line and the tests.

## Turns per second.
@export var speed := 0.75
@export var color := Color(0.92, 0.94, 0.96, 0.9)
@export var thickness := 6.0

## Where the arc starts (radians).
var angle := 0.0
## Frames it turned in since reset().
var frames := 0


func reset() -> void:
	frames = 0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	angle = fmod(angle + delta * TAU * speed, TAU)
	frames += 1
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - thickness
	draw_arc(size * 0.5, radius, angle, angle + TAU * 0.7, 48, color, thickness, true)
