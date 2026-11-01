shader_type spatial;
// Facade detail of the shader facade (tools/maps/istanbul_halic/build_map.py --facade shader):
// each wall has one panel 3 cm in front of it, and this shader draws on it what the full
// facade builds from quads: the cornice, the string courses, and per floor and column a
// light surround, the glass (88 % dark, 12 % light), and a mullion in every other column.
//   UV:    metres along the wall from its first corner, metres above its ground line (zg)
//   UV2:   column width (wall length / column count) and wall height (zt - zg); 0 on faces
//          that are not panels (roofs, doors, balconies), which keep their vertex colour
//   COLOR: the wall colour (linear, as the palette material reads it); alpha a per-wall seed
// The layout constants repeat build_map.py. Edges are box-filtered over one pixel, and where
// a window gets smaller than about two pixels (more than 0.35-0.9 m of wall per pixel) the
// pattern fades to its average colour, so it does not shimmer in the distance.

uniform vec3 frame_color : source_color = vec3(0.878431, 0.839216, 0.729412); // LIGHT E0D6BA
uniform vec3 glass_color : source_color = vec3(0.227451, 0.313726, 0.341176); // DARK 3A5057
uniform vec3 glass_light_color : source_color = vec3(0.501961, 0.568627, 0.556863); // 80918E
uniform float roughness_value = 0.88;

varying vec2 wall;
varying vec2 layout_data;

void vertex() {
	wall = UV;
	layout_data = UV2;
}

// 1 inside [lo, hi] (per axis), with a linear ramp one pixel wide at the edges.
float box(vec2 p, vec2 lo, vec2 hi, vec2 pixel) {
	vec2 inside = clamp((p - lo) / pixel + 0.5, 0.0, 1.0) * clamp((hi - p) / pixel + 0.5, 0.0, 1.0);
	return inside.x * inside.y;
}

float band(float v, float lo, float hi, float pixel) {
	return clamp((v - lo) / pixel + 0.5, 0.0, 1.0) * clamp((hi - v) / pixel + 0.5, 0.0, 1.0);
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	float column_width = layout_data.x;
	if (column_width > 0.0) {
		float wall_height = layout_data.y;
		vec2 pixel = max(fwidth(wall), vec2(1e-4));
		float window_width = min(1.2, column_width * 0.43);
		float frame_half = window_width * 0.5 + 0.12;
		float floors = max(1.0, floor((wall_height - 1.0) / 3.3));

		float column = floor(wall.x / column_width);
		float x = wall.x - (column + 0.5) * column_width;
		float storey = floor((wall.y - 1.18) / 3.3);
		float y = wall.y - (1.3 + storey * 3.3);
		float on_floor = step(0.0, storey) * step(storey, floors - 1.0);

		float frame = box(vec2(x, y), vec2(-frame_half, -0.12), vec2(frame_half, 1.78), pixel) * on_floor;
		float glass = box(vec2(x, y), vec2(-window_width * 0.5, 0.0), vec2(window_width * 0.5, 1.65), pixel) * on_floor;
		float mullion = box(vec2(x, y), vec2(-0.035, 0.0), vec2(0.035, 1.65), pixel) * on_floor * step(mod(column, 2.0), 0.5);

		float cornice = band(wall.y, wall_height - 0.45, wall_height - 0.13, pixel.y);
		float course_index = floor((wall.y - 3.1) / 6.6);
		float course_base = 3.1 + course_index * 6.6;
		float course = band(wall.y, course_base, course_base + 0.13, pixel.y)
				* step(0.0, course_index) * step(course_base, wall_height - 1.0 - 1e-3);

		vec3 tint = hash(vec3(column, storey, COLOR.a * 255.0)) < 0.88 ? glass_color : glass_light_color;
		vec3 pattern = mix(albedo, frame_color, max(frame, max(cornice, course)));
		pattern = mix(pattern, tint, glass);
		pattern = mix(pattern, frame_color, mullion);

		// The average of one floor and column, for windows only a few pixels wide.
		float cell = column_width * 3.3;
		float frame_share = (2.0 * frame_half * 1.9) / cell;
		float glass_share = (window_width * 1.65) / cell;
		vec3 average = albedo * (1.0 - frame_share) + frame_color * (frame_share - glass_share) + glass_color * glass_share;
		float in_window_rows = step(1.18, wall.y) * step(wall.y, 1.18 + floors * 3.3);
		average = mix(albedo, average, in_window_rows);
		float distant = smoothstep(0.35, 0.9, max(pixel.x, pixel.y));
		albedo = mix(pattern, average, distant);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
