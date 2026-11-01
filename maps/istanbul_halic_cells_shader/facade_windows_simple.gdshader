shader_type spatial;
// Measurement only (the "facade_material": "simple" runtime key): facade_windows.gdshader
// without what costs most per pixel, to compare on the devices. Hard edges (no box filter,
// no fwidth), no mullion, no fade to the average colour in the distance, one glass tint.
// Same inputs and layout constants as facade_windows.gdshader.

uniform vec3 frame_color : source_color = vec3(0.878431, 0.839216, 0.729412);
uniform vec3 glass_color : source_color = vec3(0.227451, 0.313726, 0.341176);
uniform float roughness_value = 0.88;

varying vec2 wall;
varying vec2 layout_data;

void vertex() {
	wall = UV;
	layout_data = UV2;
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	float column_width = layout_data.x;
	if (column_width > 0.0) {
		float wall_height = layout_data.y;
		float window_width = min(1.2, column_width * 0.43);
		float frame_half = window_width * 0.5 + 0.12;
		float floors = max(1.0, floor((wall_height - 1.0) / 3.3));
		float column = floor(wall.x / column_width);
		float x = abs(wall.x - (column + 0.5) * column_width);
		float storey = floor((wall.y - 1.18) / 3.3);
		float y = wall.y - (1.3 + storey * 3.3);
		float on_floor = step(0.0, storey) * step(storey, floors - 1.0);
		float frame = step(x, frame_half) * step(-0.12, y) * step(y, 1.78) * on_floor;
		float glass = step(x, window_width * 0.5) * step(0.0, y) * step(y, 1.65) * on_floor;
		float cornice = step(wall_height - 0.45, wall.y) * step(wall.y, wall_height - 0.13);
		float course_index = floor((wall.y - 3.1) / 6.6);
		float course_base = 3.1 + course_index * 6.6;
		float course = step(course_base, wall.y) * step(wall.y, course_base + 0.13)
				* step(0.0, course_index) * step(course_base, wall_height - 1.0 - 1e-3);
		albedo = mix(albedo, frame_color, max(frame, max(cornice, course)));
		albedo = mix(albedo, glass_color, glass);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
