extends SceneTree
## Contact sheet for hand-labelling the categories of an imported map
## (Phase 6b, the classification accuracy): `count` meshes drawn at random
## (fixed seed) from the map's model, each shown in green among its grey
## surroundings from above at 60°, framed, without its category. Writes
## <out>/<id>_sample_<page>.png (numbered left to right, top to bottom,
## three to a row, fifteen to a page) and <id>_sample.tsv (number, node name, size in metres, category the
## tool gave), the latter to be compared with the labels afterwards.
##   godot --path . --resolution 640x480 --script res://tools/map_import/sample_sheet.gd -- --definition=res://maps/<id>/<id>.tres --out=/abs/dir [--count=60] [--seed=6] [--match=<regex on node names>] [--isolate]
## --isolate hides every other mesh smaller than 50 m (for a mesh its
## neighbours hide; the pages are then named <id>_isolated_<page>.png).

const THUMB := Vector2i(320, 240)
const COLUMNS := 3
const PER_PAGE := 15

var _options := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var definition := load(_options.get("definition", "")) as MapDefinition
	var out: String = _options.get("out", "")
	if definition == null or out.is_empty():
		printerr("usage: --definition=<map .tres> --out=/abs/dir [--count=60] [--seed=6] [--match=<regex>]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var model := (load(definition.required_files[0]) as PackedScene).instantiate() as Node3D
	world.add_child(model)
	var pattern := RegEx.create_from_string(_options.get("match", "."))
	var candidates: Array[MeshInstance3D] = []
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if pattern.search(str(node.name)):
			candidates.append(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_options.get("seed", "6"))
	var picked: Array[MeshInstance3D] = []
	while picked.size() < mini(int(_options.get("count", "60")), candidates.size()):
		var node := candidates[rng.randi_range(0, candidates.size() - 1)]
		if node not in picked:
			picked.append(node)
	var camera := Camera3D.new()
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = Vector2(8, 4)
	root.add_child(label)
	var marked := StandardMaterial3D.new()
	marked.albedo_color = Color(0.1, 0.9, 0.2)
	marked.emission_enabled = true
	marked.emission = Color(0.0, 0.35, 0.05)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.78, 0.78, 0.8)
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		node.material_override = grey
	var sheet: Image
	var lines := PackedStringArray(["number\tnode\tsize_x\tsize_y\tsize_z\ttool_category"])
	for i in picked.size():
		var node := picked[i]
		node.material_override = marked
		if _options.has("isolate"):
			for other: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				var other_box: AABB = other.global_transform * other.mesh.get_aabb()
				other.visible = other == node or maxf(other_box.size.x, other_box.size.z) >= 50.0
		var box: AABB = node.global_transform * node.mesh.get_aabb()
		var reach := maxf(box.size.length() * 1.8, 10.0)
		camera.look_at_from_position(box.get_center() + Vector3(0.35, 1.0, 0.45).normalized() * reach, box.get_center())
		label.text = str(i + 1)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		image.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		var slot := i % PER_PAGE
		if slot == 0:
			sheet = Image.create(THUMB.x * COLUMNS, THUMB.y * (PER_PAGE / COLUMNS), false, Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, THUMB), Vector2i((slot % COLUMNS) * THUMB.x, (slot / COLUMNS) * THUMB.y))
		if slot == PER_PAGE - 1 or i == picked.size() - 1:
			sheet.save_png(out.path_join("%s_%s_%d.png" % [definition.id, "isolated" if _options.has("isolate") else "sample", i / PER_PAGE + 1]))
		node.material_override = grey
		lines.append("%d\t%s\t%.1f\t%.1f\t%.1f\t%s" % [i + 1, node.name, box.size.x, box.size.y, box.size.z, definition.category_rules.category_of(node)])
	var file := FileAccess.open(out.path_join("%s_%s.tsv" % [definition.id, "isolated" if _options.has("isolate") else "sample"]), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("SAMPLE %d meshes of %d: %s" % [picked.size(), candidates.size(), out.path_join("%s_sample_*.png" % definition.id)])
	quit(0)
