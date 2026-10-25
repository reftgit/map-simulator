class_name UIController
extends CanvasLayer
## HUD root. Keeps the controls inside the device safe area (notch, rounded
## corners, home indicator), fades the roll button while the bound player's
## roll is on cooldown and the exit button while the bound vehicle is too fast
## to get out, and, in debug builds only, shows a performance
## overlay, logs the same numbers as "PERF" lines (readable from adb logcat or
## the Xcode console), and offers VIEW (measurement viewpoints), Q (quality
## profile), and DUMMY (training dummy) buttons.

## Emitted when the debug VIEW button is tapped.
signal debug_view_requested
## Emitted when the debug quality button is tapped.
signal debug_quality_requested
## Emitted when the debug DUMMY toggle is tapped.
signal debug_dummy_requested

## Extra space between the safe area and the controls, in canvas units.
@export var edge_margin := 16.0
## Overlay refreshes between PERF log lines.
@export var perf_log_every := 4

## Name of the current measurement viewpoint, shown in the overlay and logs.
var view_name := ""
## Active quality profile, shown in the overlay.
var profile_name := ""

var _player: PlayerController
var _vehicle: VehicleController
var _ticks := 0

@onready var input: MobileInputController = $SafeArea/Controls
@onready var _safe_area: Control = $SafeArea
@onready var _debug_label: Label = $SafeArea/DebugLabel
@onready var _debug_view_button: TouchButton = $SafeArea/Controls/DebugViewButton
@onready var _debug_quality_button: TouchButton = $SafeArea/Controls/DebugQualityButton
@onready var _debug_dummy_button: TouchButton = $SafeArea/Controls/DebugDummyButton
@onready var _debug_timer: Timer = $DebugTimer


func _ready() -> void:
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	var debug := OS.is_debug_build()
	_debug_label.visible = debug
	_debug_view_button.visible = debug
	_debug_quality_button.visible = debug
	_debug_dummy_button.visible = debug
	if debug:
		_debug_view_button.pressed.connect(debug_view_requested.emit)
		_debug_quality_button.pressed.connect(debug_quality_requested.emit)
		_debug_dummy_button.pressed.connect(debug_dummy_requested.emit)
		_debug_timer.timeout.connect(_update_debug)
		_debug_timer.start()


func bind_player(player: PlayerController) -> void:
	_player = player


## The vehicle being driven, or null on foot.
func bind_vehicle(vehicle: VehicleController) -> void:
	_vehicle = vehicle


func _process(_delta: float) -> void:
	if _player and input.roll_button:
		input.roll_button.dimmed = _player.actions.is_blocked(&"roll")
	if _vehicle and input.exit_button:
		input.exit_button.dimmed = not _vehicle.can_exit_at_current_speed()


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


## Current frame statistics. Static memory is what the engine allocated
## itself (tracked in debug builds); it excludes GPU driver memory.
static func perf_stats() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"video_mem_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"static_mem_mb": OS.get_static_memory_usage() / 1048576.0,
		"static_peak_mb": OS.get_static_memory_peak_usage() / 1048576.0,
	}


func _update_debug() -> void:
	var stats := perf_stats()
	var state := ""
	if _player:
		state = "%s %.1f m/s" % [_player.state_machine.get_state_name(), _player.get_horizontal_speed()]
	_debug_label.text = "FPS %d | %d draw calls | %.2f M prims | %d objects\n%s | vram %.0f MB | mem %.0f MB (peak %.0f)\n%s" % [
		stats.fps, stats.draw_calls, stats.primitives / 1e6, stats.objects,
		state, stats.video_mem_mb, stats.static_mem_mb, stats.static_peak_mb, "%s  |  quality %s" % [view_name, profile_name],
	]
	_ticks += 1
	if _ticks % perf_log_every == 0:
		print("PERF profile=%s view=\"%s\" fps=%d draw_calls=%d primitives=%d objects=%d video_mem_mb=%.0f static_mem_mb=%.0f static_peak_mb=%.0f" % [
			profile_name, view_name, stats.fps, stats.draw_calls, stats.primitives, stats.objects,
			stats.video_mem_mb, stats.static_mem_mb, stats.static_peak_mb,
		])
