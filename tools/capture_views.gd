extends SceneTree
## Captures the same camera positions on a map for side-by-side comparisons of
## map variants (docs/perf/facade/): the spawn, the two measurement viewpoints,
## two near streets, and a raised view, without the HUD, with a quality profile.
##   godot --path . --resolution 960x540 --script res://tools/capture_views.gd -- --map=<id> --quality=<none|high|low> --out=/abs/dir
## Writes <out>/<map>_<quality>_<view>.png and prints one VIEW line per shot.

## Near streets (dense buildings within 30 m, found from the generator's road
## and building records) and the raised view; positions in map space.
const STREETS := {
	"street_eminonu": [Vector3(-333.8, 6.9, 48.2), 75.0],
	"street_beyoglu": [Vector3(238.8, 68.0, -1006.0), 255.0],
}
const RAISED_FROM := Vector3(-80, 70, 200)
const RAISED_AT := Vector3(30, 15, 60)

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
	root.add_child(game)
	for i in 30:
		await physics_frame
	if game.map_definition.id != map_id:
		printerr("Map %s not available (loaded %s)" % [map_id, game.map_definition.id])
		quit(1)
		return
	game.set_quality_profile(quality)
	game.hud.visible = false
	var shots: Array[String] = ["spawn", "karakoy", "galata"]
	for index in shots.size():
		game.show_debug_view(index)
		await _shoot(game, "%s/%s_%s_%s.png" % [out, map_id, quality, shots[index]], shots[index])
	for street: String in STREETS:
		var place: Array = STREETS[street]
		game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(place[1])), place[0]))
		game.camera_rig.snap_behind_target()
		await _shoot(game, "%s/%s_%s_%s.png" % [out, map_id, quality, street], street)
	var raised := Camera3D.new()
	raised.far = game.camera_rig.camera.far
	game.add_child(raised)
	raised.look_at_from_position(RAISED_FROM, RAISED_AT)
	raised.make_current()
	await _shoot(game, "%s/%s_%s_raised.png" % [out, map_id, quality], "raised")
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
