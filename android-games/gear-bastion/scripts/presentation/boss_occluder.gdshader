shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 body_color = vec4(1.0);
uniform float body_roughness = 0.75;
uniform float body_metallic = 0.0;
uniform float body_specular = 0.5;
uniform vec2 boss_center = vec2(-10.0);
uniform vec2 boss_radius = vec2(0.1);

void fragment() {
	// The pinned 4.7 renderer exposes upper-left fragment coordinates.
	vec2 screen = FRAGCOORD.xy / VIEWPORT_SIZE;
	float radius = length((screen - boss_center) / max(boss_radius, vec2(0.0001)));
	float cutaway = 1.0 - smoothstep(0.82, 1.0, radius);
	ALBEDO = body_color.rgb;
	ROUGHNESS = body_roughness;
	METALLIC = body_metallic;
	SPECULAR = body_specular;
	ALPHA = mix(body_color.a, 0.015, cutaway);
}
