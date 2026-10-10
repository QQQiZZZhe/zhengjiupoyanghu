extends Node2D
## 固定屏幕光源，旋转卡面先沿光线投到背景平面，再经过同一相机透视。
# More overhead light keeps the projection close to each card's own footprint.
const LIGHT_RAY := Vector2(0.14, 0.22)
var points := PackedVector2Array()
var softness := 4.0
var _mesh: ArrayMesh

func update_projection(card: Control, tilt: Vector2) -> void:
	var transform := card.get_global_transform()
	var center := transform * (card.size * 0.5)
	var extent := Vector2(transform.x.length() * card.size.x, transform.y.length() * card.size.y)
	# 接收平面始终位于倾斜卡片背后，不让角点穿过背景。
	var receiver := 16.0 + extent.length() * 0.30
	var perspective := 520.0 / (520.0 + receiver)
	var inverse := get_global_transform().affine_inverse()
	var cx := cos(tilt.x)
	var sx := sin(tilt.x)
	var cy := cos(tilt.y)
	var sy := sin(tilt.y)
	points.clear()
	for uv in [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]:
		var c: Vector2 = (transform * (card.size * uv) - center) * float(card.get_meta("poke_scale", 1.0))
		var q := Vector3(c.x * cy, c.y, -c.x * sy)
		var r := Vector3(q.x, q.y * cx - q.z * sx, q.y * sx + q.z * cx)
		var projected := (Vector2(r.x, r.y) + LIGHT_RAY * (receiver - r.z)) * perspective + center
		points.append(inverse * projected)
	softness = clampf(receiver * 0.035, 2.0, 8.0) / maxf(transform.x.length(), 0.01)
	queue_redraw()

func _draw() -> void:
	if points.size() != 4: return
	var center := Vector2.ZERO
	for point in points: center += point * 0.25
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# 多层半影固定在接收平面，独立于卡面着色器。
	for layer in range(8, -1, -1):
		var start := vertices.size()
		for point in points:
			vertices.append(point + (point - center).normalized() * softness * layer / 8.0)
			colors.append(Color(0.015, 0.025, 0.025, 0.055))
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	draw_mesh(_mesh, null)
