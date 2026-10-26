extends Node
## Composition root: loads the map, places the player, applies the quality
## profile, and connects input, camera, and HUD. Systems do not look each
## other up; they are wired here.

@export var map_definition: MapDefinition
## Parked at each of the map's vehicle spawns.
@export var vehicle_scene: PackedScene

## Debug builds: training dummy position relative to the spawn (m, forward is
## -Z). Close enough that a punch from the spawn reaches it, and a little to
## the right so the camera behind the player sees it.
const DUMMY_OFFSET := Vector3(0.35, 0.0, -1.3)

var render_settings: RenderSettings
## Active quality profile name ("none", "high", "low").
var quality_profile := QualityProfiles.NONE
## Engine-start-to-map-ready and first-frame times plus build and runtime
## settings, filled when performance features are enabled (BuildFeatures).
var startup := {}
## Debug builds: punching target near the spawn, toggled from the overlay.
var training_dummy: TrainingDummy

var _view_index := 0
var _experiment: PerfConfig
## Experiments: map colliders farther than this from the player are off
## (negative: the feature is not in use).
var _collider_radius := -1.0
var _static_bodies := []  # [StaticBody3D, AABB] pairs, built on first use

@onready var world: WorldManager = $WorldManager
@onready var player: PlayerController = $Player
@onready var camera_rig: ThirdPersonCamera = $ThirdPersonCamera
@onready var player_input: TouchPlayerInput = $TouchPlayerInput
@onready var vehicle_input: TouchVehicleInput = $TouchVehicleInput
@onready var vehicle_interaction: VehicleInteraction = $VehicleInteraction
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

	vehicle_input.input = hud.input
	vehicle_interaction.setup(player, camera_rig, hud.input, vehicle_input)
	vehicle_interaction.entered.connect(_on_vehicle_entered)
	vehicle_interaction.exited.connect(_on_vehicle_exited)
	if vehicle_scene:
		for vehicle in world.spawn_vehicles(vehicle_scene):
			vehicle_interaction.register_vehicle(vehicle)

	render_settings = RenderSettings.new(world.map_root, camera_rig.camera, get_viewport(), map_definition.occluders_path)
	if BuildFeatures.perf_enabled():
		_experiment = _load_perf_experiment()
		if _experiment:
			apply_runtime_settings(_experiment.runtime)
	set_quality_profile(_initial_profile())

	if BuildFeatures.is_debug():
		hud.view_name = get_view_names()[0]
		hud.debug_view_requested.connect(cycle_debug_view)
		hud.debug_quality_requested.connect(cycle_quality_profile)
		hud.debug_dummy_requested.connect(toggle_training_dummy)
		hud.debug_car_requested.connect(walk_up_to_vehicle)
	if BuildFeatures.perf_enabled():
		_log_startup()
		if _experiment and _experiment.bench:
			_start_benchmark(_experiment)


## While driving, the vehicle (not the hidden player) is the body that falls
## or flips; it resets itself, so the world stops tracking the player.
func _on_vehicle_entered(vehicle: VehicleController) -> void:
	world.untrack(player)
	hud.bind_vehicle(vehicle)


func _on_vehicle_exited(_vehicle: VehicleController) -> void:
	world.track(player)
	hud.bind_vehicle(null)


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


## Debug builds: shows the training dummy in front of the spawn, or removes it.
func toggle_training_dummy() -> void:
	if training_dummy:
		training_dummy.queue_free()
		training_dummy = null
		print("DUMMY off")
		return
	training_dummy = (load("res://game/debug/training_dummy.tscn") as PackedScene).instantiate()
	world.add_child(training_dummy)
	training_dummy.place_above_floor(world.get_spawn_transform() * DUMMY_OFFSET)
	print("DUMMY on")


## Debug builds: puts the player next to the driver's door of the first
## vehicle (which is far from the player spawn), facing the same way.
func walk_up_to_vehicle() -> void:
	if vehicle_interaction.is_driving() or world.vehicles.is_empty():
		return
	var vehicle := world.vehicles[0]
	player.teleport(Transform3D(Basis(Vector3.UP, vehicle.get_follow_yaw()), vehicle.to_global(Vector3(2.4, 0.5, 0.0))))
	camera_rig.snap_behind_target()
	print("CAR walk-up")


## Moves the player (or, while driving, the vehicle) to measurement viewpoint
## `index` (0 is the spawn).
func show_debug_view(index: int) -> void:
	var views: Array[Transform3D] = [world.get_spawn_transform()]
	views.append_array(map_definition.debug_viewpoints)
	_view_index = index
	if vehicle_interaction.is_driving():
		vehicle_interaction.vehicle.place_at(views[index])
	else:
		player.teleport(views[index])
	camera_rig.snap_behind_target()
	hud.view_name = get_view_names()[index]
	print("VIEW ", hud.view_name)


## Applies a performance experiment on top of its profile and starts its
## benchmark if it has one.
func apply_perf_experiment(config: PerfConfig) -> PerfBenchmark:
	_experiment = config
	apply_runtime_settings(config.runtime)
	set_quality_profile(config.profile if not config.profile.is_empty() else quality_profile)
	return _start_benchmark(config) if config.bench else null


## Applies an experiment's runtime keys (PerfConfig.RUNTIME_KEYS). Keys it
## leaves out keep their values. Measurement only: none of these is a game
## setting.
func apply_runtime_settings(runtime: Dictionary) -> void:
	if runtime.has("physics_ticks"):
		Engine.physics_ticks_per_second = runtime.physics_ticks
	if runtime.has("physics_interpolation"):
		get_tree().physics_interpolation = runtime.physics_interpolation
	if runtime.has("player_physics"):
		player.set_physics_process(runtime.player_physics)
	if runtime.has("vehicles"):
		for vehicle in world.vehicles:
			vehicle.process_mode = PROCESS_MODE_INHERIT if runtime.vehicles else PROCESS_MODE_DISABLED
	if runtime.has("vsync_mode"):
		DisplayServer.window_set_vsync_mode(PerfConfig.VSYNC_MODES[runtime.vsync_mode])
	_collider_radius = runtime.get("collider_radius", -1.0)
	update_far_colliders(player.global_position)
	if not runtime.is_empty():
		print("RUNTIME ", JSON.stringify(runtime))


## With a collider_radius experiment: switches the map's static bodies off
## (removed from the physics space) beyond the radius from `center`, measured
## on the ground plane to each body's bounds, and back on within it.
## Returns how many bodies are on.
func update_far_colliders(center: Vector3) -> int:
	if _collider_radius < 0.0:
		return -1
	if _static_bodies.is_empty():
		for body: StaticBody3D in world.map_root.find_children("*", "StaticBody3D", true, false):
			_static_bodies.append([body, _body_bounds(body)])
	var active := 0
	for entry in _static_bodies:
		var bounds: AABB = entry[1]
		var nearest := Vector2(clampf(center.x, bounds.position.x, bounds.end.x), clampf(center.z, bounds.position.z, bounds.end.z))
		var on := nearest.distance_to(Vector2(center.x, center.z)) <= _collider_radius
		(entry[0] as StaticBody3D).process_mode = PROCESS_MODE_INHERIT if on else PROCESS_MODE_DISABLED
		active += int(on)
	return active


static func _body_bounds(body: StaticBody3D) -> AABB:
	var bounds := AABB()
	var first := true
	for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
		var local := shape.shape.get_debug_mesh().get_aabb()
		var world_box: AABB = shape.global_transform * local
		bounds = world_box if first else bounds.merge(world_box)
		first = false
	return bounds


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


## An experiment from `--perf-config=<path>` on the command line, or a
## one-shot perf_bench.json pushed to the device (deleted on read): in user://
## (debug builds, iOS), or in the app-specific external folder on Android,
## which a release build can read without `run-as`.
func _load_perf_experiment() -> PerfConfig:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-config="):
			return PerfConfig.load_file(arg.trim_prefix("--perf-config="))
	var config := PerfConfig.load_file(PerfConfig.USER_PATH, true)
	if config == null and not PerfConfig.external_dir().is_empty():
		config = PerfConfig.load_file(PerfConfig.external_dir().path_join("perf_bench.json"), true)
	return config


## Name of the active 3D physics engine. Godot has no getter for it and the
## project setting may just say "DEFAULT", so it is read from the class of
## the world's direct space state, which each engine implements itself.
static func physics_engine_name(space_state: PhysicsDirectSpaceState3D) -> String:
	var type := space_state.get_class()
	if type.begins_with("GodotPhysics"):
		return "GodotPhysics3D"
	if type.begins_with("JoltPhysics"):
		return "Jolt Physics"
	return type


## Logs engine-start-to-map-ready and first-frame times, the physics engine,
## and what kind of build this is with its frame and physics settings, so a
## result file shows the conditions it was measured under.
func _log_startup() -> void:
	var map_ready_ms := Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		# No frame is drawn headless (tests); the first processed frame stands in.
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	var physics := physics_engine_name(world.get_world_3d().direct_space_state)
	startup = {"map_ready_ms": map_ready_ms, "first_frame_ms": Time.get_ticks_msec(), "physics_3d": physics}
	startup.merge(build_info())
	print("STARTUP map_ready_ms=%d first_frame_ms=%d profile=%s occluders=%s physics_3d=%s (setting %s) build=%s user_dir=%s" % [map_ready_ms,
			startup.first_frame_ms, quality_profile, JSON.stringify(render_settings.occluder_report), physics,
			ProjectSettings.get_setting("physics/3d/physics_engine"), JSON.stringify(build_info()), OS.get_user_data_dir()])


## Build kind and the frame and physics settings in effect. Project
## settings are read with their feature-tag overrides applied (what the
## engine uses); plain get_setting() would report the untagged value.
func build_info() -> Dictionary:
	return {
		"debug_build": OS.is_debug_build(),
		"perf_feature": OS.has_feature(BuildFeatures.PERF_FEATURE),
		"physics_ticks": Engine.physics_ticks_per_second,
		"physics_interpolation": get_tree().physics_interpolation,
		"max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"physics_engine_setting": ProjectSettings.get_setting_with_override("physics/3d/physics_engine"),
		"ios_allow_high_refresh_rate": ProjectSettings.get_setting_with_override("display/window/ios/allow_high_refresh_rate"),
		"android_frame_pacing": ProjectSettings.get_setting_with_override("display/window/frame_pacing/android/enable_frame_pacing"),
	}
