class_name TouchButton
extends TouchControl
## Round on-screen button. HOLD mode is down while a finger is on it; TOGGLE
## mode flips `toggled_on` on each press.

signal pressed
signal released
signal toggled(on: bool)

enum Mode { HOLD, TOGGLE }

@export var mode := Mode.HOLD
@export var label := ""
## Hit area as a multiple of the drawn radius, so near misses still count.
@export var hit_scale := 1.15

var is_down := false
var toggled_on := false

var _touch_index := -1


func accepts_touch(touch_position: Vector2) -> bool:
	if _touch_index != -1 or not is_visible_in_tree():
		return false
	var center := get_global_rect().get_center()
	return touch_position.distance_to(center) <= _radius() * hit_scale


func touch_pressed(index: int, _touch_position: Vector2) -> void:
	_touch_index = index
	is_down = true
	pressed.emit()
	if mode == Mode.TOGGLE:
		set_toggled(not toggled_on)
	queue_redraw()


func touch_released(index: int, _touch_position: Vector2) -> void:
	if index == _touch_index:
		reset_touch()
		released.emit()


func reset_touch() -> void:
	_touch_index = -1
	is_down = false
	queue_redraw()


func set_toggled(on: bool) -> void:
	if on == toggled_on:
		return
	toggled_on = on
	toggled.emit(on)
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _draw() -> void:
	var center := size * 0.5
	var lit := is_down or toggled_on
	var fill := Color(0.95, 0.75, 0.3, 0.55) if lit else Color(0.05, 0.08, 0.1, 0.35)
	draw_circle(center, _radius(), fill)
	draw_arc(center, _radius(), 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := int(_radius() * 0.6)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))
