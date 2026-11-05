extends SceneTree
## Shots of a map made by the import tool, for its report
## (docs/maps/imported/): the player at the spawn, the parked vehicle, the
## map from above with the spawn (green), the vehicle (blue), and the NPC
## route (red) marked by posts, and the NPC on its route; without the HUD.
##   godot --path . --resolution 960x540 --script res://tools/capture_map_shots.gd -- --definition=res://maps/<id>/<id>.tres --out=/abs/dir [--quality=high]
## Writes <out>/<id>_spawn.png, <id>_vehicle.png, <id>_above.png, <id>_npc.png
## and prints a SHOT line per shot. The map does not need to be in the
## registry. With --glb=<file> instead of --definition: one view of the whole
## model as the file holds it (<out>/<name>_raw.png), for a model the tool
## did not write.

const MARKERS := {"spawn": Color(0.1, 0.85, 0.2), "vehicle": Color(0.15, 0.4, 1.0), "route": Color(0.95, 0.15, 0.1)}

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var out: String = _options.get("out", "")
	if out.is_empty() or not (_options.has("definition") or _options.has("glb")):
		printerr("usage: --definition=res://maps/<id>/<id>.tres --out=/abs/dir [--quality=high] | --glb=<file> --out=/abs/dir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	if _options.has("glb"):
		await _raw_view(_options.glb, out)
		quit(0)
		return
	var definition := load(_options.definition) as MapDefinition
	if definition == null or not definition.is_available():
		printerr("SHOT map not available: ", _options.definition)
		quit(1)
		return
	var registry := MapRegistry.new()
	registry.definitions.assign([definition])
	var game: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	game.maps = registry
	game.requested_map = definition.id
	# Loaded at once, as the shots expect it right after this (Main.threaded_loading).
	game.threaded_loading = false
	root.add_child(game)
	for i in 30:
		await physics_frame
	game.set_quality_profile(_options.get("quality", "high"))
	game.hud.visible = false
	var prefix := out.path_join(definition.id)
	game.camera_rig.snap_behind_target()
	await _shoot(prefix + "_spawn.png")
	var camera := Camera3D.new()
	camera.far = 4000.0
	game.add_child(camera)
	camera.make_current()
	if not game.world.vehicles.is_empty():
		var car: Node3D = game.world.vehicles[0]
		var at := car.global_position
		camera.look_at_from_position(at + car.global_basis * Vector3(5.0, 3.0, 9.0), at + Vector3.UP * 0.6)
		await _shoot(prefix + "_vehicle.png")
	var bounds: Rect2 = definition.bounds
	var center := Vector3(bounds.get_center().x, definition.player_spawn_position.y, bounds.get_center().y)
	var size := maxf(maxf(bounds.size.x, bounds.size.y), 40.0)
	var markers := Node3D.new()
	game.add_child(markers)
	var post := maxf(1.0, size / 140.0)  # posts grow with the map so they show from above
	_add_marker(markers, definition.player_spawn_position, MARKERS.spawn, post)
	for spawn: Transform3D in definition.vehicle_spawns:
		_add_marker(markers, spawn.origin, MARKERS.vehicle, post)
	for route: PatrolRoute in definition.npc_routes:
		for point in route.points:
			_add_marker(markers, point, MARKERS.route, post)
	camera.look_at_from_position(center + Vector3(0.0, size * 0.8, size * 0.6), center)
	await _shoot(prefix + "_above.png")
	markers.queue_free()
	if not definition.npc_routes.is_empty() and definition.npc_routes[0].points.size() >= 2:
		var points: Array[Vector3] = definition.npc_routes[0].points
		var middle := (points[0] + points[1]) * 0.5
		var along := Vector3(points[1].x - points[0].x, 0.0, points[1].z - points[0].z)
		var side := along.cross(Vector3.UP).normalized() if along.length() > 0.1 else Vector3.BACK
		camera.look_at_from_position(middle + side * maxf(along.length(), 8.0) + Vector3.UP * 4.0, middle + Vector3.UP)
		await _shoot(prefix + "_npc.png")
	quit(0)


func _add_marker(parent: Node3D, at: Vector3, color: Color, size := 1.0) -> void:
	var post := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.6 * size
	mesh.bottom_radius = 0.6 * size
	mesh.height = 14.0 * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	post.mesh = mesh
	post.position = at + Vector3.UP * 7.0 * size
	parent.add_child(post)


## One view of a model file as loaded (no import, no fixes), framing its
## bounds from above at an angle, under a plain sky and sun.
func _raw_view(path: String, out: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if error != OK:
		printerr("SHOT cannot load ", path, ": ", error_string(error))
		return
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -32, 0)
	world.add_child(sun)
	var scene := document.generate_scene(state) as Node3D
	world.add_child(scene)
	var box := AABB()
	var first := true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var placed: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).mesh.get_aabb()
		box = placed if first else box.merge(placed)
		first = false
	var reach := maxf(box.size.length(), 0.01)
	var camera := Camera3D.new()
	camera.near = reach * 0.001
	camera.far = reach * 10.0
	world.add_child(camera)
	camera.look_at_from_position(box.get_center() + Vector3(0.45, 0.5, 0.75) * reach, box.get_center())
	camera.make_current()
	await _shoot(out.path_join(path.get_file().get_basename() + "_raw.png"))
	print("SHOT bounds of %s: position %s size %s" % [path.get_file(), box.position, box.size])


func _shoot(path: String) -> void:
	for i in 60:
		await physics_frame
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SHOT %s draw_calls=%d primitives=%d" % [path.get_file(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
