shader_type spatial;
render_mode cull_back;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float wave = sin(world_position.x * 0.18 + TIME * 0.45) * sin(world_position.z * 0.14 - TIME * 0.35);
	float ripple = sin(world_position.x * 1.3 + world_position.z * 0.7 + TIME * 1.1);
	ALBEDO = mix(vec3(0.035, 0.19, 0.22), vec3(0.06, 0.28, 0.30), wave * 0.5 + 0.5);
	ROUGHNESS = 0.3 + ripple * 0.04;
	METALLIC = 0.12;
	NORMAL_MAP = vec3(0.5 + wave * 0.055, 0.5 + ripple * 0.03, 1.0);
}
