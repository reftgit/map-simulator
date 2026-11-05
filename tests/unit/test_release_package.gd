extends "res://tests/test_case.gd"
## The release presets "Android Release" and "iOS Release" (Phase 6d): the game
## and only the maps of the release registry, a streamed map as its cells
## without its GLB; no perf_bench; the identifiers of D8 and no keystore
## values (test_export_presets.gd and test_build_features.gd check those for
## every preset too). tools/release_package.gd simulates the export;
## tools/release_contents.py lists a built package.

const ReleasePackage := preload("res://tools/release_package.gd")
const ANDROID_PACKAGE := "com.mirongi.mapsimulator"
## The temporary iOS bundle ID and team (D8): the final ID is not registered yet.
const IOS_BUNDLE := "com.mirongi.mapsimulator.dev"
const IOS_TEAM := "8N7RYA42S6"


func cleanup() -> void:
	BuildFeatures.reset_overrides()
	await super()


func test_a_normal_release_build_loads_the_release_registry() -> void:
	BuildFeatures.debug_override = 0
	BuildFeatures.perf_feature_override = 0
	check(MapRegistry.for_build().resource_path == MapRegistry.RELEASE_PATH, "normal release build: the release registry")
	BuildFeatures.perf_feature_override = 1
	check(MapRegistry.for_build().resource_path == MapRegistry.PATH, "Release Perf build: every map")
	BuildFeatures.debug_override = 1
	BuildFeatures.perf_feature_override = 0
	check(MapRegistry.for_build().resource_path == MapRegistry.PATH, "debug build: every map")
	var main := (load("res://game/main.tscn") as PackedScene).instantiate()
	check(main.maps == null, "main.tscn names no registry, so the build chooses and a release package need not carry every map's definition")
	main.free()


func test_the_release_registry_starts_on_the_default_map() -> void:
	var release := MapRegistry.load_release()
	var every := MapRegistry.load_default()
	check(not release.definitions.is_empty() and release.definitions[0] == every.definitions[0], "the release's first map is the default map (%s)" % release.ids())
	for definition in release.definitions:
		check(every.find(definition.id) == definition, "%s is a map of the full registry" % definition.id)


func test_release_presets_pack_exactly_what_the_release_maps_need() -> void:
	for name in ReleasePackage.RELEASE_PRESETS:
		var problems := ReleasePackage.problems(name, false)
		check(problems.is_empty(), "%s: %s" % [name, "as expected" if problems.is_empty() else "\n".join(problems)])


func test_release_presets_leave_out_the_other_maps_and_the_models() -> void:
	var release := MapRegistry.load_release()
	for name in ReleasePackage.RELEASE_PRESETS:
		var exclude: Array[String] = ReleasePackage.preset(name).exclude
		for definition in MapRegistry.load_default().definitions:
			var shipped := release.find(definition.id) != null
			var verb := "packed" if shipped else "left out"
			check(ReleasePackage.excluded(definition.resource_path, exclude) != shipped, "%s: %s's definition %s" % [name, definition.id, verb])
			if not definition.streaming_index_path.is_empty():
				var cell := definition.streaming_index_path.get_base_dir().path_join("cells/trees_0_0.res")
				check(ReleasePackage.excluded(cell, exclude) != shipped, "%s: %s's cells %s" % [name, definition.id, verb])
			for path in definition.required_files:
				var whole := shipped and definition.streaming_index_path.is_empty()
				check(ReleasePackage.excluded(path, exclude) != whole, "%s: %s %s (%s)" % [name, path, "packed" if whole else "left out", definition.id])
		for path in [MapRegistry.PATH, "res://maps/istanbul_halic_cells_shader/streaming_100/cells/trees_0_0.res", "res://main.tscn",
				"res://tests/unit/test_release_package.gd", "res://tools/cell_map.gd", "res://docs/STREAMING.md"]:
			check(ReleasePackage.excluded(path, exclude), "%s leaves out %s" % [name, path])
		for path in [MapRegistry.RELEASE_PATH, "res://game/main.tscn", "res://game/debug/build_features.gd", "res://icon.svg"]:
			check(not ReleasePackage.excluded(path, exclude), "%s packs %s" % [name, path])


func test_release_presets_are_plain_release_builds_with_the_d8_identifiers() -> void:
	var presets := ConfigFile.new()
	check(presets.load(ReleasePackage.PRESETS) == OK, "export_presets.cfg readable")
	for name in ReleasePackage.RELEASE_PRESETS:
		var settings := ReleasePackage.preset(name)
		check(not settings.is_empty(), "%s exists" % name)
		if settings.is_empty():
			continue
		var section: String = settings.section
		check(settings.features.is_empty(), "%s: no custom features, so no perf_bench (%s)" % [name, settings.features])
		for key in presets.get_section_keys(section + ".options"):
			var value := str(presets.get_value(section + ".options", key))
			if key.begins_with("keystore/"):
				check(value.is_empty(), "%s: %s empty (no keystore in the repository, D10)" % [name, key])
		if presets.get_value(section, "platform") == "Android":
			check(presets.get_value(section + ".options", "package/unique_name") == ANDROID_PACKAGE, "%s: package %s (D8)" % [name, ANDROID_PACKAGE])
			check(presets.get_value(section, "export_path") == "build/android/map-simulator-release.apk", "%s: its own APK" % name)
		else:
			check(presets.get_value(section + ".options", "application/bundle_identifier") == IOS_BUNDLE, "%s: the temporary bundle ID (D8)" % name)
			check(presets.get_value(section + ".options", "application/app_store_team_id") == IOS_TEAM, "%s: team %s (D8)" % [name, IOS_TEAM])
			check(presets.get_value(section + ".options", "application/export_method_release") == 1, "%s: development export, local testing only (D9)" % name)
			check(presets.get_value(section + ".options", "application/export_project_only") == true, "%s: the Xcode project only, built without portal access (D9)" % name)
			check(presets.get_value(section, "export_path") == "build/ios_release/map_simulator.ipa", "%s: its own folder" % name)
