extends SceneTree
## Captures the same camera positions on a map for side-by-side comparisons of
## map variants (docs/perf/facade/, docs/perf/facade_v2/): the spawn, the two
## measurement viewpoints, two near streets, a raised view, and two street-level
## views of buildings 100-250 m away, without the HUD, with a quality profile.
##   godot --path . --resolution 960x540 --script res://tools/capture_views.gd -- --map=<id> --quality=<none|high|low> --out=/abs/dir
## Writes <out>/<map>_<quality>_<view>.png and prints one VIEW line per shot.
## --views=a,b,... takes only those views. --facade-shader=<path> draws the
## shader facade map's panels with another shader file (an older version, for
## a before/after comparison). --pan=N also turns each free camera (the raised
## and far views) by --pan-step degrees (default 0.02) per frame for N frames
## and writes <map>_<quality>_<view>_pan_<i>.png, for checking shimmering in
## motion (tools/perf/pan_flicker.py).

## Near streets (dense buildings within 30 m, found from the generator's road
## and building records) and the raised view; positions in map space.
const STREETS := {
	"street_eminonu": [Vector3(-333.8, 6.9, 48.2), 75.0],
	"street_beyoglu": [Vector3(238.8, 68.0, -1006.0), 255.0],
}
const RAISED_FROM := Vector3(-80, 70, 200)
const RAISED_AT := Vector3(30, 15, 60)
## Free cameras (from, at), eye height: the Karaköy waterfront from the Galata
## Bridge, and the quay avenue toward the Galata hillside.
const FAR := {
	"far_bridge": [Vector3(-109, 8.3, 204), Vector3(0, 15, -50)],
	"far_avenue": [Vector3(-50, 6.0, 120), Vector3(150, 40, -200)],
}

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var map_id: String = _options.get("map", "istanbul_halic")
	var quality: String = _options.get("quality", "none")
	var out: String = _options.get("out", "")
	if out.is_empty():
		printerr("Missing --out=/absolute/dir")
		quit(1)
		return
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.requested_map = map_id
	# Loaded at once, as the shots expect it right after this (Main.threaded_loading).
	game.threaded_loading = false
	root.add_child(game)
	for i in 30:
		await physics_frame
	if game.map_definition.id != map_id:
		printerr("Map %s not available (loaded %s)" % [map_id, game.map_definition.id])
		quit(1)
		return
	game.set_quality_profile(quality)
	game.hud.visible = false
	if _options.has("facade-shader"):
		var shader := load(_options["facade-shader"]) as Shader
		if shader == null or not game.world.map_root.get("facade_material"):
			printerr("--facade-shader needs a shader file and the shader facade map")
			quit(1)
			return
		game.world.map_root.facade_material.shader = shader
	var wanted: Array = _options["views"].split(",") if _options.has("views") else []
	var shots: Array[String] = ["spawn", "karakoy", "galata"]
	for index in shots.size():
		if wanted.is_empty() or shots[index] in wanted:
			game.show_debug_view(index)
			await _shoot(game, "%s/%s_%s_%s.png" % [out, map_id, quality, shots[index]], shots[index])
	for street: String in STREETS:
		if not wanted.is_empty() and street not in wanted:
			continue
		var place: Array = STREETS[street]
		game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(place[1])), place[0]))
		game.camera_rig.snap_behind_target()
		await _shoot(game, "%s/%s_%s_%s.png" % [out, map_id, quality, street], street)
	var free := Camera3D.new()
	free.far = game.camera_rig.camera.far
	game.add_child(free)
	var cameras := {"raised": [RAISED_FROM, RAISED_AT]}
	cameras.merge(FAR)
	for view: String in cameras:
		if not wanted.is_empty() and view not in wanted:
			continue
		free.look_at_from_position(cameras[view][0], cameras[view][1])
		free.make_current()
		await _shoot(game, "%s/%s_%s_%s.png" % [out, map_id, quality, view], view)
		for i in int(_options.get("pan", "0")):
			free.rotate_y(deg_to_rad(float(_options.get("pan-step", "0.02"))))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s_%s_pan_%02d.png" % [out, map_id, quality, view, i])
	quit(0)


func _shoot(game: Node, path: String, view: String) -> void:
	for i in 60:
		await physics_frame
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("VIEW %s map=%s draw_calls=%d primitives=%d player=%s" % [view, game.map_definition.id,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), game.player.global_position])
