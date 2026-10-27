extends SceneTree
## Renders the game in a real window and saves a screenshot plus render stats.
## Development aid for checking HUD layout and visuals without a device.
##   godot --path . --resolution 1266x585 --script res://tools/capture_screenshot.gd -- --out=/abs/path/shot.png [--walk] [--run] [--yaw=DEG] [--punch] [--roll] [--frames=N] [--dummy] [--vehicle-hud] [--safe-area=X,Y,W,H] [--release-hud]
## --walk holds the joystick forward (with --run, after tapping the run button)
## so the screenshot shows the controls in use. --punch / --roll tap that
## button; --frames sets how many frames later the shot is taken (default 90),
## e.g. a few frames for a mid-action pose. --dummy shows the debug training
## dummy in front of the spawn. --vehicle-hud shows the vehicle control group.
## --safe-area gives the HUD a safe area in window pixels, as a phone with a
## notch, cutout, or navigation bar would report it, and shades the area
## outside it; --release-hud hides the debug overlay and buttons. The layout
## depends only on the aspect ratio and the safe area's share of the window,
## so a phone screen can be shot at a smaller resolution with the same ratio.

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
	if _options.has("release-hud"):
		BuildFeatures.debug_override = 0
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	if _options.has("safe-area"):
		var v := str(_options["safe-area"]).split(",")
		var safe := Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))
		game.hud.safe_area_source = SafeAreaSource.fixed(DisplayServer.window_get_size(), safe)
		game.hud.apply_safe_area()
		_shade_outside(game.hud.safe_rect)
	for i in 30:
		await physics_frame
	if _options.has("yaw"):
		game.camera_rig.yaw = deg_to_rad(float(_options["yaw"]))
		game.camera_rig.add_look(Vector2.ZERO)
	var input: MobileInputController = game.hud.input
	if _options.has("vehicle-hud"):
		input.set_vehicle_mode(true)
	if _options.has("dummy"):
		game.toggle_training_dummy()
		for i in 5:
			await physics_frame
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
	for action in ["punch", "roll"]:
		if _options.has(action):
			var button: TouchButton = input.punch_button if action == "punch" else input.roll_button
			_touch(2, button.get_global_rect().get_center(), true)
			_touch(2, button.get_global_rect().get_center(), false)
	for i in int(_options.get("frames", "90")):
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


## Darkens the canvas outside `safe` (canvas units), where a notch, cutout,
## or system bar would be.
func _shade_outside(safe: Rect2) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var full := root.get_visible_rect()
	var bands: Array[Rect2] = [
		Rect2(full.position, Vector2(safe.position.x, full.size.y)),
		Rect2(Vector2(safe.end.x, 0.0), Vector2(full.end.x - safe.end.x, full.size.y)),
		Rect2(Vector2(safe.position.x, 0.0), Vector2(safe.size.x, safe.position.y)),
		Rect2(Vector2(safe.position.x, safe.end.y), Vector2(safe.size.x, full.end.y - safe.end.y)),
	]
	for band in bands:
		if band.has_area():
			var shade := ColorRect.new()
			shade.color = Color(0.0, 0.0, 0.0, 0.55)
			shade.position = band.position
			shade.size = band.size
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(shade)


## `position` is in HUD canvas units; input events carry window pixels.
func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)
