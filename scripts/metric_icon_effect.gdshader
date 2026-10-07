shader_type canvas_item;
uniform vec2 center = vec2(7.0);
uniform float effect_scale = 1.0;
uniform vec2 shake = vec2(0.0);
void vertex() {
	VERTEX = (VERTEX - center) * effect_scale + center + shake;
}
