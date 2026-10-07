extends RefCounted
static var image: Image

static func face_of(card: Control) -> TextureRect:
	var panel: Control = card.get_meta("panel", card)
	return panel.get_meta("pixel_face", null)

static func face_rect(face: TextureRect) -> Rect2:
	var source := face.texture.get_size()
	var extent := source * minf(face.size.x / source.x, face.size.y / source.y)
	return Rect2((face.size - extent) * 0.5, extent)

static func contains(card: Control, point: Vector2, stable_transform: Transform2D = Transform2D.IDENTITY, stable: bool = false) -> bool:
	var face := face_of(card)
	if face == null or face.size.x <= 0 or face.size.y <= 0: return false
	var transform := stable_transform if stable else card.get_global_transform()
	var center := transform * (card.size * 0.5)
	var p := point - center
	var x := 0.0 if stable else float(card.get_meta("gyro_x", 0.0))
	var y := 0.0 if stable else float(card.get_meta("gyro_y", 0.0))
	var normal := Vector3(sin(y), -cos(y) * sin(x), cos(y) * cos(x))
	var depth := 520.0 * normal.z / (normal.x * p.x + normal.y * p.y + 520.0 * normal.z)
	var r := Vector3(p.x * depth, p.y * depth, 520.0 * (depth - 1.0))
	var q := Vector3(r.x, r.y * cos(x) + r.z * sin(x), -r.y * sin(x) + r.z * cos(x))
	var unrotated := Vector2(q.x * cos(y) - q.z * sin(y), q.y) / (1.0 if stable else float(card.get_meta("poke_scale", 1.0))) + center
	var face_transform := transform * card.get_global_transform().affine_inverse() * face.get_global_transform()
	var local := face_transform.affine_inverse() * unrotated
	var rect := face_rect(face)
	if not rect.has_point(local): return false
	if image == null: image = preload("res://assets/art/artist-test-card-blank.png").get_image()
	var uv := (local - rect.position) / rect.size
	return image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1), clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)).a > 0.5

static func project(card: Control, point: Vector2) -> Vector2:
	var center := card.get_global_transform() * (card.size * 0.5)
	var c := (point - center) * float(card.get_meta("poke_scale", 1.0))
	var x := float(card.get_meta("gyro_x", 0.0))
	var y := float(card.get_meta("gyro_y", 0.0))
	var q := Vector3(c.x * cos(y), c.y, -c.x * sin(y))
	var r := Vector3(q.x, q.y * cos(x) - q.z * sin(x), q.y * sin(x) + q.z * cos(x))
	return Vector2(r.x, r.y) * (520.0 / (520.0 + r.z)) + center
