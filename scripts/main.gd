extends Node3D
var status: Label
var explorer: CharacterBody3D
var show_hud := true
var hud: CanvasLayer
var map_data: Dictionary = {}
var mosque_markers: Node3D
var markers_visible := false

func _ready() -> void:
	explorer = $Explorer
	# East / up / south. Valid starting point on the east sidewalk of the bridge.
	explorer.walk_spawn = Vector3(-109.0365, 6.4047, 204.2572)
	if FileAccess.file_exists("res://assets/map_metadata.json"):
		map_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map_metadata.json"))
		var spawn: Array = map_data.get("walk_spawn", [-109.0365, 6.4047, 204.2572])
		explorer.walk_spawn = Vector3(spawn[0], spawn[1], spawn[2])
		var bounds: Array = map_data.get("bounds", [-1940, -1120, 760, 1560])
		explorer.map_bounds = Rect2(bounds[0], -bounds[3], bounds[2]-bounds[0], bounds[3]-bounds[1])
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("739faa")
	sky_material.sky_horizon_color = Color("d7ddd0")
	sky_material.ground_bottom_color = Color("647d80")
	sky_material.ground_horizon_color = Color("d7ddd0")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c5ca")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -32, 0)
	sun.light_color = Color("ffe6bd")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 450
	add_child(sun)
	var water := $Map.find_child("Water", true, false) as MeshInstance3D
	if water:
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/water.gdshader")
		water.material_override = material
	make_hud()
	make_mosque_markers()

func make_mosque_markers() -> void:
	mosque_markers = Node3D.new()
	mosque_markers.name = "MosqueNames"
	add_child(mosque_markers)
	for entry: Dictionary in map_data.get("mosques", []):
		var label := Label3D.new()
		label.text = str(entry.get("name", "Cami"))
		label.position = Vector3(entry["east"], entry["ground_m"] + 30, -entry["north"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 44
		label.pixel_size = 0.08
		label.modulate = Color("fff0c9")
		label.outline_modulate = Color("243c40")
		label.outline_size = 12
		label.no_depth_test = true
		mosque_markers.add_child(label)
	mosque_markers.visible = markers_visible

func make_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var plate := PanelContainer.new()
	plate.position = Vector2(24, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.10, 0.115, 0.90)
	style.content_margin_left = 20
	style.content_margin_right = 24
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_right = 8
	plate.add_theme_stylebox_override("panel", style)
	hud.add_child(plate)
	var column := VBoxContainer.new()
	plate.add_child(column)
	var label := Label.new()
	label.text = "İSTANBUL  /  HALİÇ"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color("ebd6aa"))
	column.add_child(label)
	var sub := Label.new()
	sub.text = "GALATA · EMİNÖNÜ · KASIMPAŞA · UNKAPANI\n2,69 × 2,67 km  /  yükselti verisiyle oluşturulmuş arazi"
	sub.add_theme_font_size_override("font_size", 14)
	column.add_child(sub)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	column.add_child(status)
	var controls := Label.new()
	controls.text = "Sağ tık: bakış  ·  WASD: hareket  ·  Shift: hızlan\nQ / E: alçal / yüksel  ·  F: yürüyüş / uçuş  ·  Space: zıpla\n1: Galata  2: Köprü  3: Eminönü  4: Genel  5: Süleymaniye\n6: Metro Köprüsü  7: Sokak ayrıntısı  8: Kasımpaşa\nM: cami adları  ·  Esc: imleç  ·  H: arayüz  ·  R: köprü\n\n© OpenStreetMap contributors · ODbL 1.0 | Arazi: Mapzen Terrain Tiles / USGS / EU-DEM"
	controls.position = Vector2(24, 746)
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color("edf0e5"))
	controls.add_theme_constant_override("outline_size", 5)
	controls.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.08, 0.9))
	hud.add_child(controls)

func _process(_delta: float) -> void:
	status.text = ("UÇUŞ" if explorer.flying else "YÜRÜYÜŞ") + "  ·  %.0f m yükseklik" % explorer.global_position.y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: explorer.set_view(Vector3(-210, 150, -445), Vector3(-70, 70, -285))
			KEY_2: explorer.set_view(Vector3(145, 135, 125), Vector3(-165, 8, 355))
			KEY_3: explorer.set_view(Vector3(180, 170, 460), Vector3(-235, 30, 650))
			KEY_4: explorer.set_view(Vector3(1950, 2250, 2200), Vector3(-585, 0, -220))
			KEY_5: explorer.set_view(Vector3(-660, 195, 560), Vector3(-920, 95, 780))
			KEY_6: explorer.set_view(Vector3(-410, 165, 350), Vector3(-690, 35, 0))
			KEY_7: explorer.set_view(Vector3(35, 70, 165), Vector3(-20, 7, 50))
			KEY_8: explorer.set_view(Vector3(-280, 340, -700), Vector3(-1080, 15, -850))
			KEY_M:
				markers_visible = not markers_visible
				mosque_markers.visible = markers_visible
			KEY_H:
				show_hud = not show_hud
				hud.visible = show_hud
