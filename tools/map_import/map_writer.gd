extends RefCounted
## Writes the map files the game reads (docs/MAP_CONTRACT.md, "What the tool
## writes"): the map scene, the MapDefinition, and the registry entry.

## Sky, ambient light, and sun of the map scene: the same as İstanbul • Haliç
## and the test district, so imported maps look lit alike and the quality
## profiles find a WorldEnvironment and a Sun to change.
const SCENE_TEMPLATE := """[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" path="{model}" id="1_model"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_top_color = Color(0.45098, 0.623529, 0.666667, 1)
sky_horizon_color = Color(0.843137, 0.866667, 0.815686, 1)
ground_bottom_color = Color(0.392157, 0.490196, 0.501961, 1)
ground_horizon_color = Color(0.843137, 0.866667, 0.815686, 1)

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
ambient_light_source = 2
ambient_light_color = Color(0.705882, 0.772549, 0.792157, 1)
ambient_light_energy = 0.65
tonemap_mode = 2

[node name="{root}" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1_model")]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-43, -32, 0)
light_color = Color(1, 0.901961, 0.741176, 1)
light_energy = 1.65
shadow_enabled = true
directional_shadow_mode = 1
directional_shadow_max_distance = 60.0
"""
## Seconds an NPC waits at each point of the route the tool finds.
const ROUTE_WAIT := 1.5


## The map scene text for the model at `model_path`.
static func scene_text(id: String, model_path: String) -> String:
	return SCENE_TEMPLATE.format({"model": model_path, "root": id.to_pascal_case()})


## A MapDefinition from the placement (map_placement.gd) and the written files.
static func definition(id: String, display_name: String, paths: Dictionary, placement: RefCounted) -> MapDefinition:
	var map := MapDefinition.new()
	map.id = id
	map.display_name = display_name
	map.scene_path = paths.scene
	map.player_spawn_position = placement.spawn.position
	map.player_spawn_yaw_degrees = snappedf(placement.spawn.yaw, 0.01)
	map.bounds = placement.bounds
	map.kill_height = placement.kill_height
	map.vehicle_spawns.assign([placement.vehicle.transform])
	var route := PatrolRoute.new()
	route.points.assign(placement.route)
	route.wait_seconds = ROUTE_WAIT
	map.npc_routes.assign([route])
	map.occluders_path = paths.occluders
	map.category_rules = load(paths.rules) as CategoryRules
	map.required_files.assign([paths.model])
	map.debug_viewpoints.assign(placement.viewpoints)
	map.debug_viewpoint_names.assign(placement.viewpoint_names)
	return map


## Appends the definition at `definition_path` to the registry file (text,
## so the other entries and their ids stay as they are). Returns "added",
## "present", or an error message.
static func register(registry_path: String, definition_path: String) -> String:
	var text := FileAccess.get_file_as_string(registry_path)
	if text.is_empty():
		return "cannot read %s" % registry_path
	if text.contains('path="%s"' % definition_path):
		return "present"
	var ids := RegEx.create_from_string('id="(\\d+)_').search_all(text)
	var next := 1
	for found in ids:
		next = maxi(next, int(found.get_string(1)) + 1)
	var new_id := "%d_%s" % [next, definition_path.get_file().get_basename()]
	var lines := text.split("\n")
	var last_ext := -1
	var definitions := -1
	for i in lines.size():
		if lines[i].begins_with("[ext_resource "):
			last_ext = i
		if lines[i].begins_with("definitions = ") and lines[i].ends_with("])"):
			definitions = i
	if last_ext < 0 or definitions < 0:
		return "unexpected registry format in %s" % registry_path
	lines[definitions] = lines[definitions].trim_suffix("])") + ', ExtResource("%s")])' % new_id
	lines.insert(last_ext + 1, '[ext_resource type="Resource" path="%s" id="%s"]' % [definition_path, new_id])
	text = "\n".join(lines)
	var steps := RegEx.create_from_string("load_steps=(\\d+)").search(text)
	if steps:
		text = text.replace(steps.get_string(), "load_steps=%d" % (int(steps.get_string(1)) + 1))
	var file := FileAccess.open(registry_path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % registry_path
	file.store_string(text)
	return "added"
