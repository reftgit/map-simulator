extends Node3D
## Runtime setup the GLB import does not carry over: vertex-color albedo and
## the animated water material. A streamed map (docs/STREAMING.md) gets the
## same setup for the meshes of each cell as it loads (prepare_streamed()).

const WATER_SHADER := preload("res://scripts/water.gdshader")


func _ready() -> void:
	_use_vertex_colors($Model.find_children("*", "MeshInstance3D", true, false))
	var water := $Model.find_child("Water", true, false) as MeshInstance3D
	if water:
		var material := ShaderMaterial.new()
		material.shader = WATER_SHADER
		water.material_override = material


## MapStreamer gave these nodes their meshes: the setup _ready() gives the
## meshes present at load.
func prepare_streamed(instances: Array) -> void:
	_use_vertex_colors(instances)


## The materials of the streamed meshes, at load (MapStreamer.setup()): the
## same vertex-colour albedo, set before any of their cells arrives.
func prepare_streamed_materials(materials: Array) -> void:
	for material in materials:
		if material is BaseMaterial3D:
			(material as BaseMaterial3D).vertex_color_use_as_albedo = true


## The map stores all colors in COLOR_0 with white base colors; Godot imports
## the materials without vertex-color albedo, which renders the city white.
## The 6 materials are shared, so this touches each one once.
func _use_vertex_colors(instances: Array) -> void:
	var seen := {}
	for node in instances:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material and not seen.has(material):
				seen[material] = true
				material.vertex_color_use_as_albedo = true
