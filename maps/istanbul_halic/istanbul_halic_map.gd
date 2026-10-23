extends Node3D
## Runtime setup the GLB import does not carry over: vertex-color albedo and
## the animated water material.

const WATER_SHADER := preload("res://scripts/water.gdshader")


func _ready() -> void:
	_use_vertex_colors($Model)
	var water := $Model.find_child("Water", true, false) as MeshInstance3D
	if water:
		var material := ShaderMaterial.new()
		material.shader = WATER_SHADER
		water.material_override = material


## The map stores all colors in COLOR_0 with white base colors; Godot imports
## the materials without vertex-color albedo, which renders the city white.
## The 6 materials are shared, so this touches each one once.
func _use_vertex_colors(model: Node) -> void:
	var seen := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material and not seen.has(material):
				seen[material] = true
				material.vertex_color_use_as_albedo = true
