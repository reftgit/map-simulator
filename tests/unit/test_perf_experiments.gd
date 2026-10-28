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
			var scenario := file.begins_with("scenario_")
			check(config != null and (config.bench or (scenario and not config.scenario.is_empty())), "%s parses and has a bench (or scenario) section (%s)" % [file, PerfConfig.last_error])
			check(config == null or config.experiment == file.get_basename(), "%s: experiment name matches the file" % file)
			var platform_default := file.begins_with("profile_default") or file.begins_with("session_profile")
			var device_specific := file.begins_with("c_") or file.begins_with("pacing_") or file.begins_with("jolt_") or file.begins_with("session_pacing_")
			if config and device_specific:
				check(config.profile in ["low", "high"], "%s: Phase 4 experiments name the device profile they were measured with" % file)
			elif config and scenario:
				check(config.profile.is_empty(), "%s: scenarios run with the platform default profile" % file)
			elif config and not platform_default:
				check(config.profile == "none", "%s: measured before profiles existed, so it pins profile none" % file)


func test_scenario_section_parses_and_rejects_typos() -> void:
	var config := PerfConfig.from_dict({"experiment": "s", "scenario": {"name": "vehicle_sleep", "rotate_hold_s": 12, "quit_when_done": false}})
	check(config != null and config.scenario == "vehicle_sleep" and config.scenario_rotate_hold_s == 12.0 and not config.quit_when_done and not config.bench, "scenario section read (%s)" % PerfConfig.last_error)
	if config:
		check(config.to_dict().scenario == {"name": "vehicle_sleep", "rotate_hold_s": 12.0}, "scenario recorded in results")
	check(PerfConfig.from_dict({"experiment": "s", "scenario": {"name": "dance"}}) == null and PerfConfig.last_error.contains("dance"), "unknown scenario rejected")
	check(PerfConfig.from_dict({"experiment": "s", "scenario": {"name": "vehicle_sleep", "rotate": 3}}) == null, "unknown scenario key rejected")
	check(PerfConfig.from_dict({"experiment": "s", "scenario": {"name": "orientation"}}) == null, "orientation needs a hold time")
	check(PerfConfig.from_dict({"experiment": "s"}).scenario.is_empty(), "no scenario by default")
	check(PerfConfig.from_dict({"experiment": "s", "scenario": {"name": "extensibility"}}).scenario == "extensibility", "the Phase 5 scenario")


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


func test_physics_stats() -> void:
	var samples := PackedInt64Array([1000, 2000, 3000, 4000])
	var stats := PerfBenchmark.physics_stats(samples)
	check_near(stats.physics_ms, 2.5, 0.0001, "mean physics tick time in ms")
	check_near(stats.physics_p99_ms, 4.0, 0.0001, "99th percentile in ms")
	check(PerfBenchmark.physics_stats(PackedInt64Array()).physics_ms == 0.0, "empty window")


func test_in_vehicle_bench_key() -> void:
	var config := PerfConfig.from_dict({"experiment": "x", "bench": {"in_vehicle": true}})
	check(config != null and config.in_vehicle, "in_vehicle parsed")
	check(not PerfConfig.from_dict({"experiment": "x", "bench": {}}).in_vehicle, "off by default")


func test_runtime_keys_parse_and_reject_typos() -> void:
	var config := PerfConfig.from_dict({"experiment": "x", "runtime": {"physics_ticks": 30, "physics_interpolation": false, "player_physics": false, "vehicles": false, "vehicle_sleep": false, "npcs": false, "npc_far_mode": false, "collider_radius": 100, "vsync_mode": "mailbox"}})
	check(config != null, "all runtime keys accepted (%s)" % PerfConfig.last_error)
	if config:
		check(config.runtime.physics_ticks == 30 and config.runtime.physics_interpolation == false and is_equal_approx(config.runtime.collider_radius, 100.0) and config.runtime.npcs == false, "values typed (%s)" % [config.runtime])
		check(config.to_dict().runtime == config.runtime, "runtime keys recorded in results")
	check(PerfConfig.from_dict({"experiment": "x", "runtime": {"physics_tick": 30}}) == null and PerfConfig.last_error.contains("physics_tick"), "unknown runtime key rejected")
	check(PerfConfig.from_dict({"experiment": "x", "runtime": {"vsync_mode": "sometimes"}}) == null, "bad vsync mode rejected")
	check(PerfConfig.from_dict({"experiment": "x", "runtime": {"physics_ticks": 0}}) == null, "zero tick rate rejected")
	check(PerfConfig.from_dict({"experiment": "x"}).runtime.is_empty(), "no runtime keys by default")


func test_frame_time_distribution() -> void:
	# 98 frames of 16.7 ms and two of 25 ms (a 60 FPS cap on a 120 Hz display).
	var frames := PackedInt64Array()
	for i in 98:
		frames.append(16700)
	frames.append(25000)
	frames.append(25000)
	var stats := PerfBenchmark.frame_stats(frames, 1.687)
	check_near(stats.frame_p50_ms, 16.7, 0.001, "median frame")
	check_near(stats.frame_p99_ms, 25.0, 0.001, "99th percentile frame")
	check(stats.long_frames == 2, "frames one refresh late counted as long (%d)" % stats.long_frames)
	check(stats.frame_hist_ms.size() == PerfBenchmark.HISTOGRAM_MS + 1 and stats.frame_hist_ms[16] == 98 and stats.frame_hist_ms[25] == 2, "1 ms histogram")
	var timing := PerfBenchmark.timing_stats("process", PackedInt64Array([2000, 4000]))
	check_near(timing.process_ms, 3.0, 0.0001, "process mean")
	check_near(timing.process_p99_ms, 4.0, 0.0001, "process p99")
