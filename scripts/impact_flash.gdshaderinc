// Adapted from GODOT-VFX-LIBRARY flash_white.gdshader (MIT).
// Kept in the shared card shader to avoid an additional render pass.
uniform float impact_flash : hint_range(0.0, 1.0) = 0.0;
vec4 card_impact(vec4 color) {
	if (impact_flash <= 0.0) { return color; }
	return vec4(mix(color.rgb, vec3(1.0, 0.97, 0.85), impact_flash * color.a), color.a);
}
