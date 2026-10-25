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
##
## Punch, roll, and interact (get in / get out) are one-shot presses: a tap on
## their button (on touch-down) or a press of their key is kept until gameplay
## consumes it once. Holding does not repeat.
##
## The on-foot and vehicle controls are two groups; set_vehicle_mode() shows
## one and hides the other. Hidden controls never take a finger.

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_forward", &"move_back", &"run", &"punch", &"roll",
		&"interact", &"vehicle_throttle", &"vehicle_brake", &"vehicle_left", &"vehicle_right", &"vehicle_handbrake"]
## Actions delivered as one-shot presses (consume_action_press()).
const ACTION_PRESSES: Array[StringName] = [&"punch", &"roll", &"interact"]
## One-shot actions that exist only on foot; ignored while driving.
const ON_FOOT_PRESSES: Array[StringName] = [&"punch", &"roll"]
## Touch indices released on the joystick when input is reset.
const MAX_TOUCHES := 10

@export var joystick: VirtualJoystick
@export var look_area: TouchLookArea
@export var run_button: TouchButton
@export var punch_button: TouchButton
@export var roll_button: TouchButton
## Shown only while a vehicle is in reach (set_interact_available()).
@export var interact_button: TouchButton
@export_group("Vehicle controls")
@export var steer_left_button: TouchButton
@export var steer_right_button: TouchButton
@export var throttle_button: TouchButton
@export var brake_button: TouchButton
@export var handbrake_button: TouchButton
@export var exit_button: TouchButton
@export_group("Control groups")
## Containers shown one at a time.
@export var on_foot_controls: Control
@export var vehicle_controls: Control
@export_group("")
## Further controls (e.g. debug buttons), routed after the action buttons and
## before the look area.
@export var extra_controls: Array[TouchControl] = []
## Turn running off when the joystick finger lifts.
@export var run_resets_on_release := true
## Camera rotation in radians for a drag across the full viewport height.
@export var look_sensitivity := 2.6

## True while the vehicle controls are shown.
var vehicle_mode := false

var _owners := {}  # touch index -> TouchControl
var _priority: Array[TouchControl] = []
var _presses := {}  # action StringName -> true, until consumed


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var ordered: Array[TouchControl] = [run_button, punch_button, roll_button, interact_button,
			steer_left_button, steer_right_button, throttle_button, brake_button, handbrake_button, exit_button]
	ordered.append_array(extra_controls)
	ordered.append(look_area)
	for control in ordered:
		if control:
			_priority.append(control)
	if punch_button:
		punch_button.pressed.connect(press_action.bind(&"punch"))
	if roll_button:
		roll_button.pressed.connect(press_action.bind(&"roll"))
	if interact_button:
		interact_button.pressed.connect(press_action.bind(&"interact"))
		interact_button.visible = false
	if exit_button:
		exit_button.pressed.connect(press_action.bind(&"interact"))
	_show_group(false)
	if joystick:
		joystick.released.connect(_on_joystick_released)


func _input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_VISIBILITY_CHANGED:
			release_all_touches()


## Routes a touch event or records an action key press; returns true when
## the event was consumed.
func handle_input_event(event: InputEvent) -> bool:
	for action in ACTION_PRESSES:
		if event.is_action_pressed(action):
			press_action(action)
			return true
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


## Drops every finger, pending action presses, and all movement, e.g. when
## the app loses focus or pauses with a finger down. Nothing keeps moving or
## fires after resume.
func release_all_touches() -> void:
	for control in _priority:
		control.reset_touch()
	_owners.clear()
	_presses.clear()
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


## Records a one-shot press of `action` (one of ACTION_PRESSES). On-foot
## actions are ignored while driving.
func press_action(action: StringName) -> void:
	if vehicle_mode and action in ON_FOOT_PRESSES:
		return
	_presses[action] = true


## Shows the vehicle controls (or the on-foot controls) and drops every
## finger and pending press, so nothing carries over between the groups.
func set_vehicle_mode(on: bool) -> void:
	vehicle_mode = on
	_show_group(on)
	release_all_touches()


func set_interact_available(available: bool) -> void:
	if interact_button:
		interact_button.visible = available


## Vehicle steering from the buttons or keys: -1 left, 1 right.
func get_vehicle_steer() -> float:
	return float(_held(steer_right_button, &"vehicle_right")) - float(_held(steer_left_button, &"vehicle_left"))


func get_vehicle_throttle() -> float:
	return 1.0 if _held(throttle_button, &"vehicle_throttle") else 0.0


func get_vehicle_brake() -> float:
	return 1.0 if _held(brake_button, &"vehicle_brake") else 0.0


func is_vehicle_handbrake_held() -> bool:
	return _held(handbrake_button, &"vehicle_handbrake")


## True once per press of `action` since the last call.
func consume_action_press(action: StringName) -> bool:
	return _presses.erase(action)


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


func _held(button: TouchButton, action: StringName) -> bool:
	return (button != null and button.is_down) or Input.is_action_pressed(action)


func _show_group(vehicle: bool) -> void:
	if on_foot_controls:
		on_foot_controls.visible = not vehicle
	if vehicle_controls:
		vehicle_controls.visible = vehicle


func _on_joystick_released(_input_vector: Vector2) -> void:
	if run_resets_on_release and run_button:
		run_button.set_toggled(false)
