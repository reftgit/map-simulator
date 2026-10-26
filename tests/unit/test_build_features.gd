extends "res://tests/test_case.gd"
## Debug / perf_bench feature gating and the export presets that carry it.

const NORMAL_PRESETS := ["Android Debug", "iOS Debug", "Android Debug Compatibility"]


func cleanup() -> void:
	BuildFeatures.reset_overrides()
	await super()


func test_feature_logic() -> void:
	BuildFeatures.debug_override = 1
	BuildFeatures.perf_feature_override = 0
	check(BuildFeatures.is_debug() and BuildFeatures.perf_enabled(), "debug build: debug UI and perf features")
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 1
	check(not BuildFeatures.is_debug() and BuildFeatures.perf_enabled(), "release with perf_bench: perf features only")
	BuildFeatures.perf_feature_override = 0
	check(not BuildFeatures.is_debug() and not BuildFeatures.perf_enabled(), "normal release: neither")
	BuildFeatures.reset_overrides()
	check(BuildFeatures.is_debug() == OS.is_debug_build() and BuildFeatures.has_perf_feature() == OS.has_feature("perf_bench"), "no override: the engine decides")


func test_release_hud_has_no_debug_controls() -> void:
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 1
	var hud: UIController = instantiate("res://game/ui/hud.tscn")
	await process_frames(2)
	for path in ["SafeArea/DebugLabel", "SafeArea/Controls/DebugViewButton", "SafeArea/Controls/DebugQualityButton", "SafeArea/Controls/DebugDummyButton", "SafeArea/Controls/DebugCarButton"]:
		check(not hud.get_node(path).visible, "%s hidden in a release perf build" % path)
	check(hud.input.run_button.visible, "gameplay controls stay")


func test_perf_bench_only_in_release_perf_presets() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg readable")
	var names: Array[String] = []
	for section in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "name"):
			continue
		var name: String = presets.get_value(section, "name")
		names.append(name)
		var features := str(presets.get_value(section, "custom_features", "")).split(",", false)
		var perf := "perf_bench" in features
		check(perf == name.contains("Release Perf"), "%s: perf_bench only in Release Perf presets (features %s)" % [name, features])
		for key in presets.get_section_keys(section + ".options"):
			var value := str(presets.get_value(section + ".options", key))
			if key.begins_with("keystore/"):
				check(value.is_empty(), "%s: %s left empty (no keystore path or password in the repository)" % [name, key])
			check(not value.contains("/Users/"), "%s: no personal path in %s" % [name, key])
	for name in NORMAL_PRESETS:
		check(name in names, "normal preset %s still present" % name)
	check("Android Release Perf" in names and "iOS Release Perf" in names, "release perf presets present")


func test_measurement_tags_only_in_their_presets() -> void:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	for section in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "name"):
			continue
		var name: String = presets.get_value(section, "name")
		var features := str(presets.get_value(section, "custom_features", "")).split(",", false)
		check(("perf_jolt" in features) == (name == "Android Release Perf Jolt"), "%s: perf_jolt only in the Jolt measurement preset" % name)
		check(("perf_60hz" in features) == (name == "iOS Release Perf 60Hz"), "%s: perf_60hz only in the 60 Hz measurement preset" % name)
