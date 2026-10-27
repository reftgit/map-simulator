extends "res://tests/test_case.gd"
## The platform module: the only code that asks the OS which platform this is
## or reads its services, and the iOS, Android, and desktop paths of the
## systems that depend on it, run on this machine with a fake platform.

const FakePlatform := preload("res://tests/fixtures/fake_platform.gd")
## Calls only game/platform/ may make.
const PLATFORM_CALLS := ["OS.has_feature(", "OS.is_debug_build(", "OS.get_name(", "Callable(OS",
		"get_display_safe_area(", "screen_get_refresh_rate(", "SYSTEM_DIR_DOCUMENTS"]


func cleanup() -> void:
	Platform.use(null)
	BuildFeatures.reset_overrides()
	tree.root.size = Vector2i(1440, 900)
	await super()


func _fake(features: Array[String]) -> FakePlatform:
	var fake := FakePlatform.new()
	fake.features = features
	Platform.use(fake)
	return fake


func test_only_the_platform_module_asks_the_os() -> void:
	var scripts := _scripts_under("res://game")
	check(scripts.size() > 40, "game scripts found (%d)" % scripts.size())
	for path in scripts:
		if path.begins_with("res://game/platform/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for call in PLATFORM_CALLS:
			check(not text.contains(call), "%s calls %s outside the platform module" % [path, call])


func test_ios_paths() -> void:
	var fake := _fake(["ios", "mobile"])
	fake.window = Vector2i(2532, 1170)
	fake.safe = Rect2i(141, 0, 2250, 1107)
	fake.screen_rate = 120.0
	fake.documents = "/not/used/on/ios"
	check(QualityProfiles.default_name() == "high", "quality rule: high")
	var source := SafeAreaSource.new()
	check(source.safe_area() == fake.safe and source.window_size() == fake.window, "safe area source reports the platform's safe area")
	check(Platform.current().display_refresh_rate() == 60.0, "120 Hz panel paced at 60 Hz with the setting off")
	fake.high_refresh = true
	check(Platform.current().display_refresh_rate() == 120.0, "120 Hz with the setting on")
	check(PerfConfig.external_dir() == "", "no external folder on iOS")
	tree.root.size = fake.window
	var hud: UIController = instantiate("res://game/ui/hud.tscn")
	await process_frames(2)
	var expected := UIController.safe_rect_in_viewport(fake.safe, fake.window, tree.root.get_visible_rect().size)
	check(hud.safe_rect.is_equal_approx(expected), "HUD laid out in the iOS safe area (%s, expected %s)" % [hud.safe_rect, expected])


func test_android_paths() -> void:
	var fake := _fake(["android", "mobile"])
	fake.window = Vector2i(2400, 1080)
	fake.safe = Rect2i(110, 0, 2164, 1080)
	fake.screen_rate = 90.0
	fake.documents = "/storage/emulated/0/Android/data/com.mirongi.mapsimulator/files/Documents"
	check(QualityProfiles.default_name() == "low", "quality rule: low")
	check(SafeAreaSource.new().safe_area() == fake.safe, "safe area source reports the platform's safe area")
	check(Platform.current().display_refresh_rate() == 90.0, "the iOS setting does not cap Android (90 Hz)")
	check(PerfConfig.external_dir() == fake.documents, "external folder is the app's Documents folder")


func test_desktop_paths() -> void:
	var fake := _fake(["macos", "pc"])
	fake.safe = Rect2i(10, 10, 100, 100)
	fake.screen_rate = 144.0
	fake.documents = "/not/used/on/desktop"
	check(QualityProfiles.default_name() == "none", "quality rule: none")
	check(SafeAreaSource.new().safe_area() == Rect2i(), "no safe area on desktop, whatever the display server says")
	check(Platform.current().display_refresh_rate() == 144.0, "screen rate")
	check(PerfConfig.external_dir() == "", "no external folder")


func test_build_features_read_the_platform() -> void:
	var fake := _fake([])
	fake.debug = false
	check(not BuildFeatures.is_debug() and not BuildFeatures.perf_enabled(), "normal release")
	fake.features = ["perf_bench"]
	check(not BuildFeatures.is_debug() and BuildFeatures.perf_enabled(), "release with perf_bench")
	fake.debug = true
	check(BuildFeatures.is_debug(), "debug build")


func test_real_platform_on_this_machine() -> void:
	Platform.use(null)
	var platform := Platform.current()
	check(platform.get_script() == Platform, "the real platform is in use")
	check(not platform.is_mobile() and not platform.is_ios() and not platform.is_android(), "a desktop test host")
	check(platform.display_safe_area() == Rect2i() and platform.external_data_dir() == "", "no safe area or external folder")
	check(QualityProfiles.default_name() == "none", "quality rule on the desktop: none")
	check(platform.is_debug_build() == OS.is_debug_build(), "build kind from the engine")


func _scripts_under(directory: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			found.append(directory.path_join(file))
	for sub in DirAccess.get_directories_at(directory):
		found.append_array(_scripts_under(directory.path_join(sub)))
	return found
