shader_type canvas_item;
render_mode unshaded;

void fragment() {
 // Lift ink-dark sprite shadows and warm highlights while keeping hue variety.
 vec3 color = COLOR.rgb;
 float value = dot(color, vec3(0.25, 0.60, 0.15));
 color = mix(vec3(value), color, 1.06);
 color = color * 0.91 + vec3(0.065, 0.068, 0.075);
 color = mix(color, color * vec3(1.025, 1.015, 0.965), smoothstep(0.45, 0.90, value) * 0.45);
 COLOR.rgb = clamp(color, vec3(0.0), vec3(1.0));
}
