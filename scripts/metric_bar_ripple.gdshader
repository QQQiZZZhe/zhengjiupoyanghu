shader_type canvas_item;
uniform float flow_clock = 0.0;
uniform float fill_ratio = 0.0;
uniform vec2 extent = vec2(160.0, 7.0);
uniform bool enabled = true;
void fragment() {
	// 波峰沿屏幕向右移动；仅覆盖真实填充部分，参考线绘制在其上。
	vec2 p = UV * extent;
	float width = extent.x * fill_ratio;
	vec2 half_size = vec2(width, extent.y) * 0.5;
	float radius = min(3.0, min(half_size.x, half_size.y));
	vec2 q = abs(p - half_size) - half_size + radius;
	float mask = 1.0 - smoothstep(-0.4, 0.6, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius);
	float phase = p.x / 30.0 - flow_clock * 0.65 + sin(UV.y * 6.28318) * 0.055;
	float wave = pow(0.5 + 0.5 * cos(phase * 6.28318), 9.0);
	COLOR = vec4(0.86, 0.98, 1.0, wave * 0.22 * mask * float(enabled) * step(0.001, fill_ratio));
}
