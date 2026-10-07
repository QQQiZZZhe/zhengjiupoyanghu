extends Node2D
## 与卡面同一材质，沿素材 alpha 轮廓绘制，而不是沿布局容器描边。
static var contour := PackedVector2Array()
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var panel := get_parent() as PanelContainer
	var style := panel.get_theme_stylebox("panel")
	if not style.get_meta("card_outline", false): return
	var face: TextureRect = panel.get_meta("pixel_face")
	if contour.is_empty():
		var image := preload("res://assets/art/artist-test-card-blank.png").get_image()
		var right := PackedVector2Array()
		for y in image.get_height():
			var lo := -1
			var hi := -1
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					if lo < 0: lo = x
					hi = x
			if lo >= 0:
				contour.append(Vector2(lo + 0.5, y + 0.5) / Vector2(image.get_size()))
				right.append(Vector2(hi + 0.5, y + 0.5) / Vector2(image.get_size()))
		for i in range(right.size() - 1, -1, -1): contour.append(right[i])
	var rect: Rect2 = preload("res://scripts/card_geometry.gd").face_rect(face)
	var points := PackedVector2Array()
	for uv in contour: points.append(to_local(face.get_global_transform() * (rect.position + uv * rect.size)))
	points.append(points[0])
	draw_polyline(points, style.border_color, 2.0, true)
