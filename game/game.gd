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


## Measurement viewpoints: the spawn, then the map's debug viewpoints. A
## viewpoint without a name gets a numbered one.
func get_view_names() -> Array[String]:
	var names: Array[String] = ["Spawn"]
	for i in map_definition.debug_viewpoints.size():
		var named := i < map_definition.debug_viewpoint_names.size()
		names.append(map_definition.debug_viewpoint_names[i] if named else "View %d" % (i + 1))
	return names


func cycle_debug_view() -> void:
	var views: Array[Transform3D] = [world.get_spawn_transform()]
	views.append_array(map_definition.debug_viewpoints)
	_view_index = (_view_index + 1) % views.size()
	player.teleport(views[_view_index])
	camera_rig.snap_behind_target()
	hud.view_name = get_view_names()[_view_index]
	print("VIEW ", hud.view_name)


## Logs engine-start-to-map-ready and first-frame times (debug builds).
func _log_startup() -> void:
	var map_ready_ms := Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	print("STARTUP map_ready_ms=%d first_frame_ms=%d" % [map_ready_ms, Time.get_ticks_msec()])
