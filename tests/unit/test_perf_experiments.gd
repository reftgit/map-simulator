extends "res://tests/test_case.gd"
## Performance experiments (debug): JSON parsing and validation, experiment
## files, frame statistics. Applying settings is covered by test_render_settings.gd.


func test_default_config_changes_nothing() -> void:
	var config := PerfConfig.from_dict({})
	check(config != null and config.settings.is_empty(), "empty JSON sets no render settings")
	check(config.profile.is_empty(), "no profile key: platform default profile")
	check(not config.bench, "no benchmark without a bench section")
	var bench := PerfConfig.from_dict({"bench": {}})
	check(bench.bench and is_equal_approx(bench.warmup_s, 30.0) and is_equal_approx(bench.measure_s, 60.0), "protocol defaults: 30 s warm-up, 60 s measurement")


func test_only_given_keys_become_settings() -> void:
	var config := PerfConfig.from_dict({"profile": "low", "max_fps": 60, "shadows": "single", "visibility_end": {"trees": 150}})
	check(config.profile == "low", "base profile")
	check(config.settings == {"max_fps": 60, "shadows": "single", "visibility_end": {"trees": 150.0}}, "settings hold only the given keys (%s)" % [config.settings])


func test_rejects_typos() -> void:
	check(PerfConfig.from_dict({"hdie": ["trees"]}) == null and PerfConfig.last_error.contains("hdie"), "unknown key rejected")
	check(PerfConfig.from_dict({"hide": ["tree"]}) == null and PerfConfig.last_error.contains("tree"), "unknown category rejected")
	check(PerfConfig.from_dict({"shadows": "none"}) == null, "unknown shadow mode rejected")
	check(PerfConfig.from_dict({"profile": "ultra"}) == null and PerfConfig.last_error.contains("ultra"), "unknown profile rejected")
	check(PerfConfig.from_dict({"bench": {"measure": 5}}) == null, "unknown bench key rejected")


func test_experiment_files_parse() -> void:
	var directory := "res://tools/perf/experiments"
	var files := DirAccess.get_files_at(directory)
	check(files.size() >= 40, "experiment definitions present (%d)" % files.size())
	for file in files:
		if file.ends_with(".json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
			var config := PerfConfig.from_dict(parsed) if parsed is Dictionary else null
			check(config != null and config.bench, "%s parses and has a bench section (%s)" % [file, PerfConfig.last_error])
			check(config == null or config.experiment == file.get_basename(), "%s: experiment name matches the file" % file)
			if config and not file.begins_with("profile_default") and not file.begins_with("session_profile"):
				check(config.profile == "none", "%s: measured before profiles existed, so it pins profile none" % file)


func test_frame_stats() -> void:
	# 98 frames of 10 ms and two of 50 ms over 1.08 s.
	var frames := PackedInt64Array()
	for i in 98:
		frames.append(10000)
	frames.append(50000)
	frames.append(50000)
	var stats := PerfBenchmark.frame_stats(frames, 1.08)
	check_near(stats.avg_fps, 100 / 1.08, 0.01, "average FPS")
	check_near(stats.low1_fps, 20.0, 0.01, "1% low is the 99th-percentile frame")
	check_near(stats.min_fps, 20.0, 0.01, "minimum FPS from the longest frame")
	check(PerfBenchmark.frame_stats(PackedInt64Array(), 1.0).frames == 0, "empty window")


func test_view_slug() -> void:
	check(PerfBenchmark.view_slug("Karaköy street, facing north") == "karakoy", "Turkish letters to ASCII")
	check(PerfBenchmark.view_slug("Spawn") == "spawn", "plain name")
