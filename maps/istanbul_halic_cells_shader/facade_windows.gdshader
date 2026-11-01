shader_type spatial;
// Facade detail of the shader facade (tools/maps/istanbul_halic/build_map.py --facade shader):
// each wall has one panel 3 cm in front of it, and this shader draws on it what the full
// facade builds from quads: the cornice, the string courses, and per floor and column a
// light surround, the glass (88 % dark, 12 % light), and a mullion in every other column.
//   UV:    metres along the wall from its first corner, metres above its ground line (zg)
//   UV2:   column width (wall length / column count) and wall height (zt - zg); 0 on faces
//          that are not panels (roofs, doors, balconies), which keep their vertex colour
//   COLOR: the wall colour (linear, as the palette material reads it); alpha a per-wall seed
// The layout constants repeat build_map.py. Each element is box-filtered over the pixel's
// footprint on the wall (the exact share of the pixel it covers, from the integral of its
// periodic pattern), so a window keeps its full contrast while it is at least a pixel wide
// and blends into the wall only as it gets smaller, without shimmering in motion.

uniform vec3 frame_color : source_color = vec3(0.878431, 0.839216, 0.729412); // LIGHT E0D6BA
uniform vec3 glass_color : source_color = vec3(0.227451, 0.313726, 0.341176); // DARK 3A5057
uniform vec3 glass_light_color : source_color = vec3(0.501961, 0.568627, 0.556863); // 80918E
uniform float roughness_value = 0.88;
// Filter width in pixels: 1 is the pixel's own footprint; wider is softer and steadier.
uniform float filter_pixels = 1.0;

varying vec2 wall;
varying vec2 layout_data;

void vertex() {
	wall = UV;
	layout_data = UV2;
}

// Integral from 0 to x of a pattern of period 1 that is 1 on [lo, hi] (0 <= lo < hi <= 1).
float pulse_integral(float x, float lo, float hi) {
	return floor(x) * (hi - lo) + clamp(fract(x), lo, hi) - lo;
}

// Share of [x - w/2, x + w/2] (in periods) covered by that pattern, for x in [0, count).
float pulse(float x, float w, float lo, float hi, float count) {
	float a = clamp(x - 0.5 * w, 0.0, count);
	float b = clamp(x + 0.5 * w, 0.0, count);
	return (pulse_integral(b, lo, hi) - pulse_integral(a, lo, hi)) / w;
}

// Share of [x - w/2, x + w/2] covered by the single band [lo, hi].
float band(float x, float w, float lo, float hi) {
	return (clamp(x + 0.5 * w, lo, hi) - clamp(x - 0.5 * w, lo, hi)) / w;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 albedo = COLOR.rgb;
	float column_width = layout_data.x;
	if (column_width > 0.0) {
		float wall_height = layout_data.y;
		vec2 footprint = max(fwidth(wall) * filter_pixels, vec2(1e-4));
		float window_width = min(1.2, column_width * 0.43);
		float frame_half = window_width * 0.5 + 0.12;
		float floors = max(1.0, floor((wall_height - 1.0) / 3.3));
		float courses = max(0.0, ceil((wall_height - 4.1) / 6.6));

		// Along the wall in columns (windows centred at 0.5), in pairs of columns for the
		// mullion (in the even column, centred at 0.25); up the wall in storeys from the
		// bottom of the first surround (1.18 m), and in string-course periods from 3.1 m.
		float u = wall.x / column_width;
		float wu = footprint.x / column_width;
		float v = (wall.y - 1.18) / 3.3;
		float wv = footprint.y / 3.3;
		float frame_x = pulse(u, wu, 0.5 - frame_half / column_width, 0.5 + frame_half / column_width, 1e6);
		float glass_x = pulse(u, wu, 0.5 - 0.5 * window_width / column_width, 0.5 + 0.5 * window_width / column_width, 1e6);
		float mullion_x = pulse(0.5 * u, 0.5 * wu, 0.25 - 0.0175 / column_width, 0.25 + 0.0175 / column_width, 1e6);
		float frame_y = pulse(v, wv, 0.0, 1.9 / 3.3, floors);
		float glass_y = pulse(v, wv, 0.12 / 3.3, 1.77 / 3.3, floors);
		float frame = frame_x * frame_y;
		float glass = glass_x * glass_y;
		float mullion = mullion_x * glass_y;
		float bands = band(wall.y, footprint.y, wall_height - 0.45, wall_height - 0.13)
				+ pulse((wall.y - 3.1) / 6.6, footprint.y / 6.6, 0.0, 0.13 / 6.6, courses);

		// One tint per window; where a pixel spans several windows, their average.
		float column = floor(u);
		float storey = floor(v);
		vec3 tint = hash(vec3(column, storey, COLOR.a * 255.0)) < 0.88 ? glass_color : glass_light_color;
		tint = mix(tint, mix(glass_color, glass_light_color, 0.12), smoothstep(0.25, 1.0, max(wu, wv)));

		// Nested shares: glass inside the surround, the mullion on the glass; bands apart.
		albedo = albedo * max(1.0 - frame - bands, 0.0) + frame_color * (frame - glass + bands + mullion) + tint * (glass - mullion);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
