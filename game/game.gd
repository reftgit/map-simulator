extends Node
## Composition root: loads the map, places the player, and connects input,
## camera, and HUD. Systems do not look each other up; they are wired here.

@export var map_definition: MapDefinition

var _view_index := 0

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

	if OS.is_debug_build():
		hud.view_name = get_view_names()[0]
		hud.debug_view_requested.connect(cycle_debug_view)
		_log_startup()
		_load_perf_experiment()


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


## Applies a performance experiment and starts its benchmark if it has one.
func apply_perf_experiment(config: PerfConfig) -> PerfBenchmark:
	var report := PerfExperiments.apply(config, world.map_root, camera_rig.camera, get_viewport())
	print("PERF_EXPERIMENT ", JSON.stringify({"config": config.to_dict(), "apply": report}))
	if not config.bench:
		return null
	var bench := PerfBenchmark.new()
	bench.config = config
	bench.game = self
	bench.apply_report = report
	add_child(bench)
	return bench


## Debug builds: an experiment from `--perf-config=<path>` on the command line,
## or a one-shot user://perf_bench.json pushed to the device (deleted on read).
func _load_perf_experiment() -> void:
	var config: PerfConfig = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-config="):
			config = PerfConfig.load_file(arg.trim_prefix("--perf-config="))
	if config == null:
		config = PerfConfig.load_file(PerfConfig.USER_PATH, true)
	if config:
		apply_perf_experiment(config)


## Logs engine-start-to-map-ready and first-frame times (debug builds).
func _log_startup() -> void:
	var map_ready_ms := Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	print("STARTUP map_ready_ms=%d first_frame_ms=%d user_dir=%s" % [map_ready_ms, Time.get_ticks_msec(), OS.get_user_data_dir()])
