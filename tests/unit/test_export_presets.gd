extends "res://tests/test_case.gd"
## The reviewed export configuration (Phase 4d), pinned: arm64 only, tests /
## tools / docs left out, no permissions or privacy-sensitive capabilities,
## no keystore values, the identifiers of D8, and one version: the name comes
## from application/config/version, the build number is the same everywhere.
## perf_bench and personal paths: test_build_features.gd.

const PACKAGE := "com.mirongi.mapsimulator"
## Temporary iOS bundle ID; the final one (PACKAGE) must not be used on iOS
## until the new Apple account exists (D8).
const IOS_BUNDLE := "com.mirongi.mapsimulator.dev"
const IOS_TEAM := "8N7RYA42S6"
const BUILD_NUMBER := 1
const EXCLUDED := ["tests/*", "tools/*", "docs/*"]

var presets := ConfigFile.new()


func _sections() -> Array[String]:
	var found: Array[String] = []
	for section in presets.get_sections():
		if not section.ends_with(".options") and presets.has_section_key(section, "name"):
			found.append(section)
	return found


func _option(section: String, key: String, default: Variant = null) -> Variant:
	return presets.get_value(section + ".options", key, default)


func test_presets_load() -> void:
	check(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg readable")
	var platforms := {}
	for section in _sections():
		platforms[presets.get_value(section, "platform")] = true
	check(_sections().size() == 6 and platforms.has("Android") and platforms.has("iOS"), "six presets for Android and iOS (%d)" % _sections().size())


func test_every_preset_leaves_out_tests_tools_and_docs() -> void:
	presets.load("res://export_presets.cfg")
	for section in _sections():
		var name: String = presets.get_value(section, "name")
		var patterns: Array[String] = []
		for pattern in str(presets.get_value(section, "exclude_filter", "")).split(",", false):
			patterns.append(pattern.strip_edges())
		for pattern in EXCLUDED:
			check(pattern in patterns, "%s excludes %s" % [name, pattern])
		check(presets.get_value(section, "export_filter") == "all_resources", "%s exports all resources" % name)


func test_android_presets() -> void:
	presets.load("res://export_presets.cfg")
	for section in _sections():
		if presets.get_value(section, "platform") != "Android":
			continue
		var name: String = presets.get_value(section, "name")
		check(_option(section, "architectures/arm64-v8a") == true, "%s: arm64-v8a" % name)
		for arch in ["armeabi-v7a", "x86", "x86_64"]:
			check(_option(section, "architectures/" + arch, false) == false, "%s: no %s" % [name, arch])
		check(_option(section, "package/unique_name") == PACKAGE, "%s: package %s" % [name, PACKAGE])
		check(_option(section, "gradle_build/use_gradle_build", false) == false, "%s: template build (SDK levels from the template)" % name)
		check(_option(section, "screen/immersive_mode", false) == true, "%s: immersive" % name)
		check(_option(section, "version/name", "") == "", "%s: version name from the project" % name)
		check(_option(section, "version/code") == BUILD_NUMBER, "%s: build number %d" % [name, BUILD_NUMBER])
		for key in presets.get_section_keys(section + ".options"):
			var value: Variant = _option(section, key)
			if key.begins_with("permissions/"):
				check(value == false or (value is Array and value.is_empty()) or str(value).is_empty(), "%s: no permission (%s = %s)" % [name, key, value])
			if key.begins_with("keystore/"):
				check(str(value).is_empty(), "%s: %s empty" % [name, key])


func test_ios_presets() -> void:
	presets.load("res://export_presets.cfg")
	for section in _sections():
		if presets.get_value(section, "platform") != "iOS":
			continue
		var name: String = presets.get_value(section, "name")
		check(_option(section, "architectures/arm64") == true, "%s: arm64" % name)
		check(_option(section, "application/bundle_identifier") == IOS_BUNDLE, "%s: temporary bundle ID (D8)" % name)
		check(_option(section, "application/app_store_team_id") == IOS_TEAM, "%s: team %s (D8)" % [name, IOS_TEAM])
		check(_option(section, "application/export_project_only") == true, "%s: Xcode project only (D9)" % name)
		check(_option(section, "application/short_version", "") == "", "%s: version name from the project" % name)
		check(_option(section, "application/version") == str(BUILD_NUMBER), "%s: build number %d" % [name, BUILD_NUMBER])
		for key in presets.get_section_keys(section + ".options"):
			var value: Variant = _option(section, key)
			if key.begins_with("capabilities/") or key == "privacy/tracking_enabled":
				check(value == false or (value is Array and value.is_empty()), "%s: %s off" % [name, key])
			if key.ends_with("_usage_description"):
				check(str(value).is_empty(), "%s: no %s" % [name, key])


func test_project_values_the_presets_rely_on() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	check(version.split(".").size() == 3 and Array(version.split(".")).all(func(part: String) -> bool: return part.is_valid_int()), "project version is numeric x.y.z (%s)" % version)
	check(not str(ProjectSettings.get_setting("application/config/name")).is_empty(), "app name set")
	check(ResourceLoader.exists(ProjectSettings.get_setting("application/config/icon")), "app icon exists")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "sensor landscape")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc") == true, "ETC2/ASTC textures for Android")
