extends Platform
## A platform for tests: the feature tags and what the raw sources report are
## plain fields; Platform's rules run on them unchanged.

var features: Array[String] = []
var debug := true
var window := Vector2i(1440, 900)
var safe := Rect2i()
var screen_rate := 60.0
var high_refresh := false
var documents := ""


func has_feature(tag: String) -> bool:
	return tag in features


func is_debug_build() -> bool:
	return debug


func window_size() -> Vector2i:
	return window


func system_safe_area() -> Rect2i:
	return safe


func screen_refresh_rate() -> float:
	return screen_rate


func allow_high_refresh_rate() -> bool:
	return high_refresh


func documents_dir() -> String:
	return documents
