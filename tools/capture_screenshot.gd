extends SceneTree
## Renders the game in a real window and saves a screenshot plus render stats.
## Development aid for checking HUD layout and visuals without a device.
##   godot --path . --resolution 1266x585 --script res://tools/capture_screenshot.gd -- --out=/abs/path/shot.png [--walk] [--run] [--yaw=DEG]
## --walk holds the joystick forward (with --run, after tapping the run button)
## so the screenshot shows the controls in use.

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var out: String = _options.get("out", "")
	if out.is_empty():
		printerr("Missing --out=/absolute/path.png")
		quit(1)
		return
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for i in 30:
		await physics_frame
	if _options.has("yaw"):
		game.camera_rig.yaw = deg_to_rad(float(_options["yaw"]))
		game.camera_rig.add_look(Vector2.ZERO)
	var input: MobileInputController = game.hud.input
	if _options.has("run"):
		_touch(1, input.run_button.get_global_rect().get_center(), true)
		_touch(1, input.run_button.get_global_rect().get_center(), false)
	if _options.has("walk"):
		var rect := input.joystick.get_global_rect()
		var start := rect.position + rect.size * Vector2(0.4, 0.6)
		var offset := Vector2(0, -input.joystick.joystick_size * 0.4)
		_touch(0, start, true)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = root.get_final_transform() * (start + offset)
		drag.relative = root.get_final_transform().basis_xform(offset)
		Input.parse_input_event(drag)
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out)
	print("SCREENSHOT ", out, " ", image.get_size())
	print("WINDOW ", DisplayServer.window_get_size(), " CANVAS ", root.get_visible_rect().size)
	print("RENDERER ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_current_rendering_driver_name(), " / ", RenderingServer.get_video_adapter_name())
	print("FPS %d | draw calls %d | objects %d | primitives %d" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	])
	print("STATE ", game.player.state_machine.get_state_name(), " speed %.2f" % game.player.get_horizontal_speed())
	quit()


## `position` is in HUD canvas units; input events carry window pixels.
func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)
