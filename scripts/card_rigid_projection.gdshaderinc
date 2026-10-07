// One planar rotation/projection for the card face, frame and foil.
uniform float tilt_x = 0.0;
uniform float tilt_y = 0.0;
uniform vec2 card_center = vec2(0.0);
uniform float poke_scale = 1.0;
varying vec3 rigid_uv;
varying vec4 rigid_tint;

void vertex() {
	mat4 m = MODEL_MATRIX;
	vec2 c = ((m * vec4(VERTEX, 0.0, 1.0)).xy - card_center) * poke_scale;
	float cy = cos(tilt_y);
	float sy = sin(tilt_y);
	float cx = cos(tilt_x);
	float sx = sin(tilt_x);
	vec3 q = vec3(c.x * cy, c.y, -c.x * sy);
	vec3 r = vec3(q.x, q.y * cx - q.z * sx, q.y * sx + q.z * cx);
	float perspective = 520.0 / (520.0 + r.z);
	vec2 projected = r.xy * perspective + card_center;
	VERTEX = (inverse(m) * vec4(projected, 0.0, 1.0)).xy;
	// Canvas triangles interpolate UV affinely. Divide interpolated UV/depth
	// by interpolated 1/depth so the texture stays on a rigid plane.
	rigid_uv = vec3(UV * perspective, perspective);
	rigid_tint = COLOR;
}
