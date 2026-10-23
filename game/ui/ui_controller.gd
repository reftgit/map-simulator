class_name UIController
extends CanvasLayer
## HUD root. Keeps the controls inside the device safe area (notch, rounded
## corners, home indicator) and shows a debug overlay in debug builds.

## Extra space between the safe area and the controls, in canvas units.
@export var edge_margin := 16.0

var _player: PlayerController

@onready var input: MobileInputController = $SafeArea/Controls
@onready var _safe_area: Control = $SafeArea
@onready var _debug_label: Label = $SafeArea/DebugLabel
@onready var _debug_timer: Timer = $DebugTimer


func _ready() -> void:
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	_debug_label.visible = OS.is_debug_build()
	if _debug_label.visible:
		_debug_timer.timeout.connect(_update_debug)
		_debug_timer.start()


func bind_player(player: PlayerController) -> void:
	_player = player


func apply_safe_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO, viewport_size)
	if OS.has_feature("mobile"):
		safe = safe_rect_in_viewport(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), viewport_size)
	_safe_area.offset_left = safe.position.x + edge_margin
	_safe_area.offset_top = safe.position.y + edge_margin
	_safe_area.offset_right = safe.end.x - viewport_size.x - edge_margin
	_safe_area.offset_bottom = safe.end.y - viewport_size.y - edge_margin


## Converts the display safe area (window pixels) to HUD canvas units.
static func safe_rect_in_viewport(safe_area: Rect2i, window_size: Vector2i, viewport_size: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if not safe_area.has_area() or window_size.x <= 0 or window_size.y <= 0:
		return full
	var scale := viewport_size / Vector2(window_size)
	var rect := Rect2(Vector2(safe_area.position) * scale, Vector2(safe_area.size) * scale)
	return rect.intersection(full)


func _update_debug() -> void:
	var text := "FPS %d" % Engine.get_frames_per_second()
	if _player:
		text += "  |  %s  |  %.1f m/s" % [_player.state_machine.get_state_name(), _player.get_horizontal_speed()]
	_debug_label.text = text
