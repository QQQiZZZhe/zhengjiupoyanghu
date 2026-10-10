// Adapted from mreliptik's CC0 2D dissolve with burn edge:
// https://godotshaders.com/shader/2d-dissolve-with-burn-edge/
uniform sampler2D dissolve_texture : filter_linear;
uniform float dissolve_value : hint_range(0.0, 1.0) = 1.0;
uniform float burn_size : hint_range(0.0, 1.0) = 0.04;
uniform vec4 burn_color : source_color = vec4(1.0, 0.68, 0.22, 1.0);
uniform vec2 dissolve_extent = vec2(122.0, 165.0);
varying vec2 burn_uv;
#include "res://scripts/impact_flash.gdshaderinc"

vec4 card_burn(vec4 color) {
	color = card_impact(color);
	if (dissolve_value >= 1.0) { return color; }
	if (dissolve_value <= 0.0) { return vec4(color.rgb, 0.0); }
	float noise = texture(dissolve_texture, burn_uv).r;
	float threshold = smoothstep(noise - burn_size, noise, dissolve_value);
	float border = smoothstep(noise, noise + burn_size, dissolve_value);
	return vec4(mix(burn_color.rgb, color.rgb, border), color.a * threshold);
}
