extends "res://maps/istanbul_halic/istanbul_halic_map.gd"
## The shader facade map: İstanbul's runtime setup, then every surface with the
## GLB's facade material (the Detail_* panels and the geometry kept beside them)
## drawn with facade_windows.gdshader instead.

const FACADE_SHADER := preload("res://maps/istanbul_halic_cells_shader/facade_windows.gdshader")
## Measurement only ("facade_material": "simple"): the shader without its costliest parts.
const SIMPLE_SHADER := preload("res://maps/istanbul_halic_cells_shader/facade_windows_simple.gdshader")
## Name of the GLB material build_map.py --facade shader gives those surfaces.
const FACADE_MATERIAL := "Istanbul_FacadeWindows"

## The shader material set on the facade surfaces (shared by all of them).
var facade_material: ShaderMaterial

var _facade_surfaces := []  # [MeshInstance3D, surface index]


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
				_facade_surfaces.append([instance, surface])


## Measurement only (PerfConfig runtime keys, applied by Main): with
## "facade_material" "flat" the facade surfaces keep the GLB material (the wall
## colour, nothing drawn on the panels), "simple" draws them with
## facade_windows_simple.gdshader, "shader" with facade_windows.gdshader again;
## "facade_priority" sets the shader material's render priority (opaque
## surfaces are drawn in ascending priority, so -1 draws the panels before the
## walls behind them, which then fail the depth test); "facade_warmup" draws one facade cell, shrunk to 1 cm, in front of the camera
## for a few frames once the profile is applied, so its pipelines exist before
## the first viewpoint.
func apply_runtime_settings(runtime: Dictionary, camera: Camera3D) -> void:
	if runtime.has("facade_priority"):
		facade_material.render_priority = runtime.facade_priority
		print("FACADE render_priority=%d" % facade_material.render_priority)
	if runtime.has("facade_material"):
		var material: Material = null
		if runtime.facade_material == "shader":
			material = facade_material
		elif runtime.facade_material == "simple":
			material = ShaderMaterial.new()
			material.shader = SIMPLE_SHADER
		for entry in _facade_surfaces:
			(entry[0] as MeshInstance3D).set_surface_override_material(entry[1], material)
		print("FACADE material=%s surfaces=%d" % [runtime.facade_material, _facade_surfaces.size()])
	if runtime.get("facade_warmup", false) and not _facade_surfaces.is_empty():
		_warm_up.call_deferred(camera)


func _warm_up(camera: Camera3D) -> void:
	var source: MeshInstance3D = _facade_surfaces[0][0]
	var bounds := source.mesh.get_aabb()
	var probe := MeshInstance3D.new()
	probe.mesh = source.mesh
	for surface in source.mesh.get_surface_count():
		probe.set_surface_override_material(surface, source.get_surface_override_material(surface))
	var size := 0.01 / maxf(bounds.get_longest_axis_size(), 0.001)
	probe.transform = Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3(0, 0, -1) - bounds.get_center() * size)
	camera.add_child(probe)
	for i in 3:
		await get_tree().process_frame
	probe.queue_free()
	print("FACADE warm-up drawn (%s)" % source.name)
