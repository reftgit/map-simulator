extends Node
## Composition root: loads the map, places the player, applies the quality
## profile, and connects input, camera, and HUD. Systems do not look each
## other up; they are wired here.

@export var map_definition: MapDefinition

var render_settings: RenderSettings
## Active quality profile name ("none", "high", "low").
var quality_profile := QualityProfiles.NONE
## Engine-start-to-map-ready and first-frame times, filled in debug builds.
var startup := {}

var _view_index := 0
var _experiment: PerfConfig

@onready var world: WorldManager = $WorldManager
@onready var player: PlayerController = $Player
@onready var camera_rig: ThirdPersonCamera = $ThirdPersonCamera
@onready var player_input: TouchPlayerInput = $TouchPlayerInput
@onready var hud: UIController = $HUD


func _ready() -> void:
	world.load_map(map_definition)
	player.teleport(world.get_spawn_transform())
	world.track(player)

	player_input.input = hud.input
	player_input.camera = camera_rig
	player.input_source = player_input

	camera_rig.input = hud.input
	camera_rig.set_target(player)
	hud.bind_player(player)

	render_settings = RenderSettings.new(world.map_root, camera_rig.camera, get_viewport(), map_definition.occluders_path)
	if OS.is_debug_build():
		_experiment = _load_perf_experiment()
	set_quality_profile(_initial_profile())

	if OS.is_debug_build():
		hud.view_name = get_view_names()[0]
		hud.debug_view_requested.connect(cycle_debug_view)
		hud.debug_quality_requested.connect(cycle_quality_profile)
		_log_startup()
		if _experiment and _experiment.bench:
			_start_benchmark(_experiment)


## Applies a quality profile, with the debug experiment (if any) on top.
func set_quality_profile(profile_name: String) -> Dictionary:
	quality_profile = profile_name
	var layers: Array[Dictionary] = [QualityProfiles.settings_for(profile_name)]
	if _experiment:
		layers.append(_experiment.settings)
	var effective := render_settings.apply(RenderSettings.merge(layers))
	hud.profile_name = profile_name
	print("QUALITY profile=%s experiment=%s occluders=%s effective=%s" % [profile_name,
			_experiment.experiment if _experiment else "none", JSON.stringify(render_settings.occluder_report),
			JSON.stringify(effective)])
	return effective


func cycle_quality_profile() -> void:
	var names := QualityProfiles.names()
	set_quality_profile(names[(names.find(quality_profile) + 1) % names.size()])


## Measurement viewpoints: the spawn, then the map's debug viewpoints. A
## viewpoint without a name gets a numbered one.
func get_view_names() -> Array[String]:
	var names: Array[String] = ["Spawn"]
	for i in map_definition.debug_viewpoints.size():
		var named := i < map_definition.debug_viewpoint_names.size()
		names.append(map_definition.debug_viewpoint_names[i] if named else "View %d" % (i + 1))
	return names


func cycle_debug_view() -> void:
	show_debug_view((_view_index + 1) % get_view_names().size())


## Moves the player to measurement viewpoint `index` (0 is the spawn).
func show_debug_view(index: int) -> void:
	var views: Array[Transform3D] = [world.get_spawn_transform()]
	views.append_array(map_definition.debug_viewpoints)
	_view_index = index
	player.teleport(views[index])
	camera_rig.snap_behind_target()
	hud.view_name = get_view_names()[index]
	print("VIEW ", hud.view_name)


## Applies a performance experiment on top of its profile and starts its
## benchmark if it has one.
func apply_perf_experiment(config: PerfConfig) -> PerfBenchmark:
	_experiment = config
	set_quality_profile(config.profile if not config.profile.is_empty() else quality_profile)
	return _start_benchmark(config) if config.bench else null


func _start_benchmark(config: PerfConfig) -> PerfBenchmark:
	print("PERF_EXPERIMENT ", JSON.stringify({"config": config.to_dict(), "profile": quality_profile}))
	var bench := PerfBenchmark.new()
	bench.config = config
	bench.game = self
	add_child(bench)
	return bench


## Profile at startup, strongest first: the experiment's "profile" key,
## `--quality=<name>`, then the platform rule (iOS high, Android low, else none).
func _initial_profile() -> String:
	if _experiment and not _experiment.profile.is_empty():
		return _experiment.profile
	var requested := QualityProfiles.name_from_args(OS.get_cmdline_user_args())
	return requested if not requested.is_empty() else QualityProfiles.default_name()


## Debug builds: an experiment from `--perf-config=<path>` on the command line,
## or a one-shot user://perf_bench.json pushed to the device (deleted on read).
func _load_perf_experiment() -> PerfConfig:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-config="):
			return PerfConfig.load_file(arg.trim_prefix("--perf-config="))
	return PerfConfig.load_file(PerfConfig.USER_PATH, true)


## Logs engine-start-to-map-ready and first-frame times (debug builds).
func _log_startup() -> void:
	var map_ready_ms := Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	startup = {"map_ready_ms": map_ready_ms, "first_frame_ms": Time.get_ticks_msec()}
	print("STARTUP map_ready_ms=%d first_frame_ms=%d profile=%s occluders=%s user_dir=%s" % [map_ready_ms,
			startup.first_frame_ms, quality_profile, JSON.stringify(render_settings.occluder_report), OS.get_user_data_dir()])
