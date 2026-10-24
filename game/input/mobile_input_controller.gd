class_name MobileInputController
extends Control
## Single source of player input; gameplay code reads intents from here and
## never handles raw input events.
##
## Movement comes from the move_* input actions, which Godot's native
## VirtualJoystick (touch) and the keyboard (desktop development) both drive.
## Every other touch is routed here to one TouchControl in priority order
## (buttons, then camera look); a routed finger stays with its control until
## release, so camera drags and buttons never interfere. Touches no control
## claims fall through to the GUI, where the joystick picks them up.

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back", &"run"]
## Touch indices released on the joystick when input is reset.
const MAX_TOUCHES := 10

@export var joystick: VirtualJoystick
@export var look_area: TouchLookArea
@export var run_button: TouchButton
## Further controls (e.g. debug buttons), routed after the run button and
## before the look area.
@export var extra_controls: Array[TouchControl] = []
## Turn running off when the joystick finger lifts.
@export var run_resets_on_release := true
## Camera rotation in radians for a drag across the full viewport height.
@export var look_sensitivity := 2.6

var _owners := {}  # touch index -> TouchControl
var _priority: Array[TouchControl] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var ordered: Array[TouchControl] = [run_button]
	ordered.append_array(extra_controls)
	ordered.append(look_area)
	for control in ordered:
		if control:
			_priority.append(control)
	if joystick:
		joystick.released.connect(_on_joystick_released)


func _input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_VISIBILITY_CHANGED:
			release_all_touches()


## Routes a touch event; returns true when a control consumed it.
func handle_input_event(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			return _begin_touch(touch.index, touch.position)
		return _end_touch(touch.index, touch.position)
	var drag := event as InputEventScreenDrag
	if drag and _owners.has(drag.index):
		_owners[drag.index].touch_dragged(drag.index, drag.position, drag.relative)
		return true
	return false


## Drops every finger and stops all movement, e.g. when the app loses focus
## or pauses with a finger down. Nothing keeps moving after resume.
func release_all_touches() -> void:
	for control in _priority:
		control.reset_touch()
	_owners.clear()
	if run_button:
		run_button.set_toggled(false)
	if joystick and is_inside_tree():
		# The native joystick has no reset method. A release for each touch
		# index makes it forget its finger (the GUI routes a release to the
		# control holding that index and ignores the others).
		for index in MAX_TOUCHES:
			var release := InputEventScreenTouch.new()
			release.index = index
			release.position = joystick.get_global_rect().get_center()
			get_viewport().push_input(release, true)
	for action in ACTIONS:
		Input.action_release(action)


## Movement in screen axes: x right, y down (forward is negative y), length 0..1.
func get_move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func is_run_active() -> bool:
	return (run_button != null and run_button.toggled_on) or Input.is_action_pressed(&"run")


## Look input since the last call, in radians: x is yaw, y is pitch.
func consume_look_delta() -> Vector2:
	if look_area == null:
		return Vector2.ZERO
	var height := maxf(get_viewport_rect().size.y, 1.0)
	return look_area.consume_delta() / height * look_sensitivity


func _begin_touch(index: int, touch_position: Vector2) -> bool:
	if _owners.has(index):
		_end_touch(index, touch_position)
	for control in _priority:
		if control.accepts_touch(touch_position):
			_owners[index] = control
			control.touch_pressed(index, touch_position)
			return true
	return false


func _end_touch(index: int, touch_position: Vector2) -> bool:
	var control: TouchControl = _owners.get(index)
	if control == null:
		return false
	_owners.erase(index)
	control.touch_released(index, touch_position)
	return true


func _on_joystick_released(_input_vector: Vector2) -> void:
	if run_resets_on_release and run_button:
		run_button.set_toggled(false)
