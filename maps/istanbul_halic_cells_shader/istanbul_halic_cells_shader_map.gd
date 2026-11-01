extends "res://maps/istanbul_halic/istanbul_halic_map.gd"
## The shader facade map: İstanbul's runtime setup, then every surface with the
## GLB's facade material (the Detail_* panels and the geometry kept beside them)
## drawn with facade_windows.gdshader instead.

const FACADE_SHADER := preload("res://maps/istanbul_halic_cells_shader/facade_windows.gdshader")
## Name of the GLB material build_map.py --facade shader gives those surfaces.
const FACADE_MATERIAL := "Istanbul_FacadeWindows"

## The shader material set on the facade surfaces (shared by all of them).
var facade_material: ShaderMaterial


func _ready() -> void:
	super()
	facade_material = ShaderMaterial.new()
	facade_material.shader = FACADE_SHADER
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			if material and material.resource_name == FACADE_MATERIAL:
				instance.set_surface_override_material(surface, facade_material)
