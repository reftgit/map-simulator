class_name TouchControl
extends Control
## Base for on-screen touch controls. MobileInputController routes each finger
## to at most one control, which keeps that finger until it is released.
## Positions are in the HUD canvas coordinates.


func _init() -> void:
	# Touches are routed by MobileInputController, never by the GUI system.
	mouse_filter = MOUSE_FILTER_IGNORE


func accepts_touch(touch_position: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(touch_position)


func touch_pressed(_index: int, _touch_position: Vector2) -> void:
	pass


func touch_dragged(_index: int, _touch_position: Vector2, _relative: Vector2) -> void:
	pass


func touch_released(_index: int, _touch_position: Vector2) -> void:
	pass


## Drops all fingers without a release event (app paused, controls hidden).
func reset_touch() -> void:
	pass
