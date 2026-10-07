shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ground_texture : filter_nearest, repeat_disable;

void fragment() {
 // The map fills this viewport. Sample the actual 3D ground rendering, before
 // ecology tinting and scenery, so river joins and moving lake shores agree.
 vec3 ground = texture(ground_texture, SCREEN_UV).rgb;
 if (ground.b > ground.g && ground.g > ground.r) discard;
}
