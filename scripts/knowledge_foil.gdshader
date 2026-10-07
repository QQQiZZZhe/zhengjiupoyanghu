shader_type canvas_item;
#include "res://scripts/card_rigid_projection.gdshaderinc"
uniform sampler2D card_mask : filter_nearest;
// Continuous translucent foil over the complete card, preserving readable ink.
vec3 spectrum(float phase) {
	return 0.58 + 0.42 * cos(6.283185 * (phase + vec3(0.0, 0.33, 0.67)));
}
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec4 tint = rigid_tint;
	vec2 card_uv = rigid_uv.xy / rigid_uv.z;
	vec2 p = card_uv * vec2(1.0, 1.35);
	float drift = TIME * 0.10;
	float rings = sin(length((p - vec2(0.50, 0.62)) * vec2(0.9, 1.0)) * 145.0 - TIME * 1.1);
	// Triangular facets reflect different hues, alongside fine foil grain.
	vec2 cell = p * 6.0;
	vec2 local = fract(cell);
	float facet = grain(floor(cell) + step(local.x, local.y) * vec2(13.0, 7.0));
	float phase = p.x * 1.7 + p.y * 0.9 + drift + facet * 0.35;
	vec3 rainbow = spectrum(phase);
	float diagonal = pow(max(0.0, cos((p.x - p.y) * 9.0 - TIME * 0.85)), 22.0);
	float sparkle = pow(grain(floor(card_uv * vec2(180.0, 245.0))), 28.0);
	float glint = sparkle * (0.5 + 0.5 * sin(TIME * 1.5 + facet * 6.28));
	vec3 foil = mix(rainbow, vec3(0.85, 0.98, 1.0), diagonal * 0.65);
	foil += rings * 0.06 + glint * 0.20;
	float edge = min(min(card_uv.x, 1.0 - card_uv.x), min(card_uv.y, 1.0 - card_uv.y));
	float border = 1.0 - smoothstep(0.009, 0.024, edge);
	vec2 q = abs(card_uv - 0.5) - vec2(0.47, 0.48);
	float rounded = 1.0 - smoothstep(0.017, 0.025, length(max(q, vec2(0.0))));
	COLOR = vec4(clamp(foil, vec3(0.0), vec3(1.0)) * tint.rgb, (0.30 + diagonal * 0.14 + border * 0.40) * rounded * tint.a * texture(card_mask, card_uv).a);
}
