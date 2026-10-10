shader_type canvas_item;
#include "res://scripts/card_rigid_projection.gdshaderinc"

void fragment() {
	vec2 card_uv = rigid_uv.xy / rigid_uv.z;
	COLOR = card_burn(texture(TEXTURE, card_uv) * rigid_tint);
}
