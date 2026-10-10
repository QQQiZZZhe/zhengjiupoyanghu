extends Node2D
## 与卡面同一材质，沿素材 alpha 轮廓绘制，而不是沿布局容器描边。
static var contour := PackedVector2Array()
const Geometry = preload("res://scripts/card_geometry.gd")
var _points := PackedVector2Array()
var _geometry_key: Array = []
var _enabled := false
var _color := Color.TRANSPARENT
var geometry_builds := 0

func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var panel := get_parent() as PanelContainer
	var style := panel.get_theme_stylebox("panel")
	var enabled: bool = style.get_meta("card_outline", false)
	var color: Color = style.border_color
	if not enabled:
		if _enabled:
			_enabled = false
			queue_redraw()
		return
	var face: TextureRect = panel.get_meta("pixel_face")
	# Only transforms inside the card affect local outline coordinates.
	# The card's own movement/rotation/scale is applied by CanvasItem.
	var relative := face.get_transform()
	var ancestor := face.get_parent() as CanvasItem
	while ancestor != panel:
		relative = ancestor.get_transform() * relative
		ancestor = ancestor.get_parent() as CanvasItem
	relative = transform.affine_inverse() * relative
	var rect := Geometry.face_rect(face)
	var key: Array = [relative, rect]
	if key != _geometry_key:
		_geometry_key = key
		_build_points(relative, rect)
		queue_redraw()
	if not _enabled or _color != color:
		_enabled = true
		_color = color
		queue_redraw()

func _build_points(relative: Transform2D, rect: Rect2) -> void:
	geometry_builds += 1
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
	_points.resize(contour.size() + 1)
	for i in contour.size():
		_points[i] = relative * (rect.position + contour[i] * rect.size)
	_points[-1] = _points[0]

func _draw() -> void:
	if _enabled and not _points.is_empty():
		draw_polyline(_points, _color, 2.0, true)
