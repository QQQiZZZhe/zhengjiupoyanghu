shader_type canvas_item;
uniform float tilt_x = 0.0;
uniform float tilt_y = 0.0;
uniform vec2 card_center = vec2(0.0);

void vertex() {
	mat4 m = MODEL_MATRIX;
	vec2 c = (m * vec4(VERTEX, 0.0, 1.0)).xy - card_center;
	float cy = cos(tilt_y);
	float sy = sin(tilt_y);
	float cx = cos(tilt_x);
	float sx = sin(tilt_x);
	// 绕 Y 轴（偏航）
	vec3 q = vec3(c.x * cy, c.y, -c.x * sy);
	// 绕 X 轴（俯仰）
	vec3 r = vec3(q.x, q.y * cx - q.z * sx, q.y * sx + q.z * cx);
	// 透视投影：越深越小
	float f = 520.0;
	float persp = f / (f + r.z);
	vec2 w = vec2(r.x, r.y) * persp + card_center;
	// 送回该节点自己的局部空间，剩余的交给常规管线
	VERTEX = (inverse(m) * vec4(w, 0.0, 1.0)).xy;
}
