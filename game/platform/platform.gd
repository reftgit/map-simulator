class_name Platform
extends RefCounted
## The one place that asks which platform the game runs on and reads the
## platform's services: OS feature tags, the build kind, the window and the
## display safe area, the display refresh rate, and the external data folder.
## Systems call Platform.current(). Tests install a fake with use(): a
## subclass that overrides the raw sources (the first group of methods); the
## rules in the second group then run unchanged, so the iOS and Android paths
## can be tested on the desktop.

static var _current: Platform


static func current() -> Platform:
	if _current == null:
		_current = Platform.new()
	return _current


## Installs `platform` as the current one (tests); null restores the real one.
static func use(platform: Platform) -> void:
	_current = platform


# Raw sources (a fake platform overrides these).

func has_feature(tag: String) -> bool:
	return OS.has_feature(tag)


func is_debug_build() -> bool:
	return OS.is_debug_build()


## Window size in pixels.
func window_size() -> Vector2i:
	return DisplayServer.window_get_size()


## What the display server reports as the safe area, in window pixels.
func system_safe_area() -> Rect2i:
	return DisplayServer.get_display_safe_area()


## The panel's maximum refresh rate (UIScreen.maximumFramesPerSecond on iOS).
func screen_refresh_rate() -> float:
	return DisplayServer.screen_get_refresh_rate()


## display/window/ios/allow_high_refresh_rate with feature-tag overrides.
func allow_high_refresh_rate() -> bool:
	return ProjectSettings.get_setting_with_override("display/window/ios/allow_high_refresh_rate")


## The app-specific external Documents folder (Android creates it on request).
func documents_dir() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS, false)


# Rules (the same for the real platform and for fakes).

func is_ios() -> bool:
	return has_feature("ios")


func is_android() -> bool:
	return has_feature("android")


func is_mobile() -> bool:
	return has_feature("mobile")


## The display safe area in window pixels; empty where the platform has none
## (desktop), meaning the whole window is safe.
func display_safe_area() -> Rect2i:
	return system_safe_area() if is_mobile() else Rect2i()


## The refresh rate frames are paced to (see paced_refresh_rate()).
func display_refresh_rate() -> float:
	return paced_refresh_rate(screen_refresh_rate(), is_ios(), allow_high_refresh_rate())


## A folder outside the app sandbox that adb reaches without `run-as` (release
## builds are not debuggable): Android's external Documents folder, "" elsewhere.
func external_data_dir() -> String:
	return documents_dir() if is_android() else ""


## On iOS the engine's display link runs at 120 Hz when
## display/window/ios/allow_high_refresh_rate is on and at 60 Hz when it is
## off (Godot 4.7.2, platform/ios/godot_view_ios.mm), while the screen reports
## the panel's maximum (120 on ProMotion iPhones). The setting is read only by
## the iOS platform code; elsewhere the screen rate applies.
static func paced_refresh_rate(screen_rate: float, ios: bool, allow_high: bool) -> float:
	return minf(screen_rate, 60.0) if ios and not allow_high else screen_rate
