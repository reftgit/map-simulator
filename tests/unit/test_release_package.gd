extends "res://tests/test_case.gd"
## The release presets "Android Release" and "iOS Release" (Phase 6d): the game
## and only the maps of the release registry, a streamed map as its cells
## without its GLB; no perf_bench; the identifiers of D8 and no keystore
## values (test_export_presets.gd and test_build_features.gd check those for
## every preset too). tools/release_package.gd simulates the export and writes
## the presets' exclude filter from the release registry (Phase 6e);
## tools/release_contents.py lists a built package.

const ReleasePackage := preload("res://tools/release_package.gd")
const MapCells := preload("res://tools/map_import/map_cells.gd")
const StreamingMap := preload("res://tests/fixtures/streaming_map.gd")
const DIR := "user://test_release_package"
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


## Phase 6e: the presets' exclude filter is the one written from the release
## registry, so no map is named by hand.
func test_release_presets_use_the_filter_written_from_the_release_registry() -> void:
	var patterns := ReleasePackage.exclude_patterns(MapRegistry.load_release(), MapRegistry.load_default())
	for name in ReleasePackage.RELEASE_PRESETS:
		var exclude: Array[String] = ReleasePackage.preset(name).exclude
		check(exclude == patterns, "%s: the generated filter (write it: %s)\n  preset:    %s\n  generated: %s" % [name, ReleasePackage.WRITE_COMMAND, exclude, patterns])
	for id in MapRegistry.load_default().ids():
		check(id not in str(ReleasePackage.BASE_EXCLUDE), "no map named in the fixed part (%s)" % id)


## Phase 6e: a map folder that appears (a map imported, not in the release
## registry) is left out whole by the generated filter, and the package does
## not change; its streaming folder, not written on this machine, too.
func test_a_new_map_folder_is_left_out_and_the_package_does_not_change() -> void:
	var release := MapRegistry.load_release()
	var every := MapRegistry.load_default()
	var before := ReleasePackage.exclude_patterns(release, every)
	var packed_before := ReleasePackage.packed_files(before)
	var folder := "res://maps/zz_release_filter_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var scene := PackedScene.new()
	var root := Node3D.new()
	root.name = "ZzReleaseFilterTest"
	scene.pack(root)
	root.free()
	check(ResourceSaver.save(scene, folder.path_join("zz_release_filter_test.tscn")) == OK, "fake map scene written")
	var definition := MapDefinition.new()
	definition.id = "zz_release_filter_test"
	definition.scene_path = folder.path_join("zz_release_filter_test.tscn")
	definition.streaming_index_path = folder.path_join("streaming/zz_release_filter_test_index.tres")
	check(ResourceSaver.save(definition, folder.path_join("zz_release_filter_test.tres")) == OK, "fake map definition written")
	var with_new := MapRegistry.new()
	with_new.definitions.assign(every.definitions + [definition])
	var after := ReleasePackage.exclude_patterns(release, with_new)
	var packed_after := ReleasePackage.packed_files(after)
	var packed_with_old_filter := ReleasePackage.packed_files(before)
	for file in ["zz_release_filter_test.tscn", "zz_release_filter_test.tres"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	check("maps/zz_release_filter_test/*" in after and after.size() == before.size() + 1, "the folder left out whole, nothing else changed\n  before: %s\n  after:  %s" % [before, after])
	check(packed_after == packed_before, "the package holds the same files (%d / %d)" % [packed_after.size(), packed_before.size()])
	check(packed_with_old_filter.has(definition.scene_path), "without writing the filter again the new map would be packed (the check stops the export)")


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


## What tools/check_release.gd stops an export for, and the command it names.
func test_the_export_check_wants_current_cells() -> void:
	var definition := StreamingMap.write(DIR)
	var model := DIR.path_join("model.scn")
	definition.required_files.assign([model])
	check(ReleasePackage.cells_problem(definition).is_empty(), "no index: the map goes whole with its required files")
	definition.streaming_index_path = DIR.path_join("streaming/stream_test_index.tres")
	var problem := ReleasePackage.cells_problem(definition)
	check(problem.contains("no cells written") and problem.contains("res://tools/cell_map.gd -- --map=stream_test"), "no cells yet: stops and names the command (%s)" % problem)
	var cells := MapCells.new()
	check(cells.run(definition, DIR.path_join("streaming"), StreamingMap.CELL).is_empty(), "split")
	check(ReleasePackage.cells_problem(definition).is_empty(), "cells current against the model: ready")
	var file := FileAccess.open(model, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_8(0)
	file.close()
	problem = ReleasePackage.cells_problem(definition)
	check(problem.contains("model.scn changed") and problem.contains("cell_map.gd"), "a changed model: stale, stops (%s)" % problem)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model))
	problem = ReleasePackage.cells_problem(definition)
	check(problem.contains("the model to compare the cells with"), "no model on the exporting machine: cannot tell, stops (%s)" % problem)
	check(definition.is_available(), "although the game itself could load the map from its cells")
