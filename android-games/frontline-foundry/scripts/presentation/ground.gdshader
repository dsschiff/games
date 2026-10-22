shader_type spatial;
// Warm continuous terrain: a light central clearing, gentle low-frequency value
// drift, a worn gate-to-HQ track and a cooler perimeter. Color only; no height.
render_mode diffuse_lambert, specular_disabled;

uniform vec3 sand;
uniform vec3 clearing;
uniform vec3 rim;
uniform vec3 track;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float drift(vec2 p) {
	return sin(p.x * 0.9 + sin(p.y * 0.7)) * 0.5 + sin(p.y * 1.3 - p.x * 0.4) * 0.3 + sin((p.x + p.y) * 2.1) * 0.2;
}

void fragment() {
	vec2 p = world.xz;
	float d = length(vec2(p.x / 6.4, (p.y + 0.4) / 8.8));
	vec3 color = mix(sand, rim, smoothstep(0.95, 1.7, d));
	color = mix(color, clearing, (1.0 - smoothstep(0.35, 0.95, d)) * 0.75);
	float lane = (1.0 - smoothstep(0.55, 1.0, abs(p.x))) * smoothstep(-1.6, -0.6, p.y) * (1.0 - smoothstep(7.4, 8.4, p.y));
	color = mix(color, track, lane * 0.6);
	color *= 1.0 + 0.045 * drift(p * 0.45) + 0.02 * drift(p * 1.9 + 3.0);
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
