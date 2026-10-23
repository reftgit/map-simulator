class_name TouchLookArea
extends TouchControl
## Drag area that accumulates finger movement for camera look. Follows one
## finger at a time; extra fingers landing here are left unclaimed.

var _touch_index := -1
var _pending := Vector2.ZERO


func is_active() -> bool:
	return _touch_index != -1


func accepts_touch(touch_position: Vector2) -> bool:
	return not is_active() and super(touch_position)


func touch_pressed(index: int, _touch_position: Vector2) -> void:
	_touch_index = index


func touch_dragged(index: int, _touch_position: Vector2, relative: Vector2) -> void:
	if index == _touch_index:
		_pending += relative


func touch_released(index: int, _touch_position: Vector2) -> void:
	if index == _touch_index:
		_touch_index = -1


func reset_touch() -> void:
	_touch_index = -1
	_pending = Vector2.ZERO


## Returns the finger movement since the last call, in canvas units.
func consume_delta() -> Vector2:
	var delta := _pending
	_pending = Vector2.ZERO
	return delta
