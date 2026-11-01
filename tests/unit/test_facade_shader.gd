extends "res://tests/test_case.gd"
## The shader facade map's window shaders compile (a shader error is logged
## and fails the test) and expose their uniforms; runs without the GLB.

const SHADERS := {
	"res://maps/istanbul_halic_cells_shader/facade_windows.gdshader": ["frame_color", "glass_color", "glass_light_color", "roughness_value", "filter_pixels"],
	"res://maps/istanbul_halic_cells_shader/facade_windows_simple.gdshader": ["frame_color", "glass_color", "roughness_value"],
}


func test_window_shaders_compile() -> void:
	for path: String in SHADERS:
		var shader := load(path) as Shader
		check(shader != null and shader.get_mode() == Shader.MODE_SPATIAL, "%s loads as a spatial shader" % path.get_file())
		var names: Array[String] = []
		for uniform in shader.get_shader_uniform_list():
			names.append(uniform.name)
		var expected: Array[String] = []
		expected.assign(SHADERS[path])
		check(names == expected, "%s: uniforms %s" % [path.get_file(), names])


func test_window_shader_filters_by_the_pixel_footprint() -> void:
	# The distant fade of the first version (a smoothstep to the average colour
	# over 0.35-0.9 m of wall per pixel) gave way to box filtering over the
	# pixel's footprint (2026-11-01).
	var shader := load("res://maps/istanbul_halic_cells_shader/facade_windows.gdshader") as Shader
	check(shader.code.contains("fwidth(wall)") and shader.code.contains("pulse_integral") and not shader.code.contains("smoothstep(0.35, 0.9"), "footprint filter, no fixed distance fade")
	check(shader.code.contains("uniform float filter_pixels = 1.0;"), "one pixel's footprint by default")
