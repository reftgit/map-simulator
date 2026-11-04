extends SceneTree
## Streaming on and off side by side (docs/STREAMING.md): for a map and a
## quality profile, the same camera at the spawn and at each debug viewpoint
## (eye height, looking along the viewpoint), once with the map streamed and
## once loaded whole, with the player, the vehicles, and the NPCs hidden
## (and the NPCs out of the simulation), the game clock stopped, and the water hidden (its shader moves with the engine's own
## clock, which time_scale does not stop; water is resident, never streamed),
## then the pixel difference. Windowed run (a renderer is needed):
##   godot --path . --resolution 960x540 --script res://tools/capture_streaming.gd -- --map=<id> --quality=<low|high> --out=/abs/dir
## Writes <out>/<map>_<quality>_<n>_<view>.jpg (streamed | whole | difference
## ×8) and prints one LOOK line per view: pixels that differ by more than
## 2 of 255 in any channel, the largest difference, and the streamer's cells.

const EYE := 1.7
const PITCH := -8.0

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var map_id: String = _options.get("map", "")
	var quality: String = _options.get("quality", "low")
	var out: String = _options.get("out", "")
	if map_id.is_empty() or out.is_empty():
		printerr("usage: --map=<id> --quality=<low|high> --out=/abs/dir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var shots := {}
	var cells := {}
	for streaming in [true, false]:
		var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
		game.requested_map = map_id
		game.get_node("WorldManager").streaming = streaming
		root.add_child(game)
		for i in 10:
			await physics_frame
		if game.map_definition.id != map_id:
			printerr("Map %s not available (loaded %s)" % [map_id, game.map_definition.id])
			quit(1)
			return
		if streaming and game.world.streamer == null:
			printerr("Map %s has no usable streaming index" % map_id)
			quit(1)
			return
		game.apply_runtime_settings({"npcs": false})
		var settings := QualityProfiles.settings_for(quality)
		settings["hide"] = ["water"]
		var effective: Dictionary = game.render_settings.apply(settings)
		if streaming:
			game.world.streamer.set_ranges(effective)
		game.hud.visible = false
		# The camera stands where the player spawns; only the map is compared
		# (a parked car may still be settling on its wheels, an NPC on its feet).
		game.player.visible = false
		for body in game.world.vehicles + game.world.npcs:
			body.visible = false
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.far = game.camera_rig.camera.far
		camera.current = true
		if streaming:
			game.world.streamer.focus = camera
		var views: Array[Transform3D] = [game.world.get_spawn_transform()]
		views.append_array(game.map_definition.debug_viewpoints)
		var names: Array[String] = game.get_view_names()
		Engine.time_scale = 0.0
		for i in views.size():
			var yaw := views[i].basis.get_euler().y
			camera.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(PITCH), yaw, 0)), views[i].origin + Vector3.UP * EYE)
			if streaming:
				game.world.streamer.prime(game.world.streamer.focus_position())
				cells[i] = game.world.streamer.stats()
			for frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			shots[[streaming, i]] = root.get_texture().get_image()
		Engine.time_scale = 1.0
		for i in views.size():
			if not streaming:
				_compare(shots[[true, i]], shots[[false, i]], out.path_join("%s_%s_%d_%s.jpg" % [map_id, quality, i, PerfBenchmark.view_slug(names[i])]), "%s %s %s" % [map_id, quality, names[i]], cells[i])
		game.queue_free()
		for i in 3:
			await process_frame
	quit(0)


## Saves streamed | whole | difference side by side; prints the LOOK line.
func _compare(streamed: Image, whole: Image, path: String, label: String, cells: Dictionary) -> void:
	var size := streamed.get_size()
	var sheet := Image.create(size.x * 3, size.y, false, Image.FORMAT_RGB8)
	sheet.blit_rect(streamed, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	sheet.blit_rect(whole, Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
	var differing := 0
	var largest := 0.0
	var where := Rect2i()
	for y in size.y:
		for x in size.x:
			var a := streamed.get_pixel(x, y)
			var b := whole.get_pixel(x, y)
			var d := maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			largest = maxf(largest, d)
			if d > 2.0 / 255.0:
				differing += 1
				where = Rect2i(x, y, 1, 1) if differing == 1 else where.expand(Vector2i(x, y))
			sheet.set_pixel(size.x * 2 + x, y, Color(minf(d * 8.0, 1.0), minf(d * 8.0, 1.0), minf(d * 8.0, 1.0)))
	sheet.save_jpg(path, 0.85)
	print("LOOK %s: %d of %d pixels differ (%.3f %%)%s, largest %d/255; cells %d/%d loaded, %d meshes" % [label, differing, size.x * size.y,
			100.0 * differing / (size.x * size.y), " within x %d-%d, y %d-%d" % [where.position.x, where.end.x, where.position.y, where.end.y] if differing > 0 else "",
			roundi(largest * 255.0), cells.loaded, cells.cells, cells.meshes])
