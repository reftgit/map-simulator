class_name SafeAreaSource
extends RefCounted
## Where the HUD gets the window size and the display safe area, both in
## window pixels. The default asks DisplayServer (the platform reports a safe
## area on mobile; elsewhere there is none and the whole window is safe).
## Tests and the screenshot tool use fixed() to stand in for any screen.

var _fixed := false
var _window := Vector2i.ZERO
var _safe := Rect2i()


## A source that always reports `window` and `safe`.
static func fixed(window: Vector2i, safe: Rect2i) -> SafeAreaSource:
	var source := SafeAreaSource.new()
	source._fixed = true
	source._window = window
	source._safe = safe
	return source


func window_size() -> Vector2i:
	return _window if _fixed else DisplayServer.window_get_size()


## Empty when the platform reports no safe area (desktop).
func safe_area() -> Rect2i:
	if _fixed:
		return _safe
	return DisplayServer.get_display_safe_area() if OS.has_feature("mobile") else Rect2i()
