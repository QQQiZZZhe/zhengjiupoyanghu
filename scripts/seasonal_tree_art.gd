extends RefCounted

# Cached pixel masks: leaves grow/shed in clusters; branches never dissolve.
static func _branch(image: Image, a: Vector2, b: Vector2, width: int = 1) -> void:
	var steps := int(a.distance_to(b)) * 2 + 1
	for i in steps + 1:
		var p := Vector2i(a.lerp(b, float(i) / steps).round())
		for dx in width:
			if p.x + dx >= 0 and p.x + dx < image.get_width() and p.y >= 0 and p.y < image.get_height():
				image.set_pixel(p.x + dx, p.y, Color("73593e"))

static func build(source: Image) -> Array:
	var bare := Image.create(40, 44, false, Image.FORMAT_RGBA8)
	bare.fill(Color.TRANSPARENT)
	_branch(bare, Vector2(19, 40), Vector2(19, 8), 2)
	for pair in [[Vector2(19, 29), Vector2(7, 18)], [Vector2(19, 24), Vector2(31, 13)], [Vector2(19, 18), Vector2(12, 8)], [Vector2(19, 31), Vector2(32, 23)], [Vector2(12, 23), Vector2(6, 24)], [Vector2(26, 18), Vector2(27, 8)], [Vector2(26, 27), Vector2(34, 27)]]:
		_branch(bare, pair[0], pair[1])
	for y in 44:
		for x in 40:
			var col := source.get_pixel(x, y)
			if col.a > 0.1 and col.g <= col.r: bare.set_pixel(x, y, col)
	var snowy := bare.duplicate() as Image
	for y in range(1, 33):
		for x in 40:
			if bare.get_pixel(x, y).a > 0.1 and bare.get_pixel(x, y - 1).a < 0.1:
				snowy.set_pixel(x, y - 1, Color("edf1e9"))
	var result: Array = []
	for season in 4:
		var frames: Array[Texture2D] = []
		for stage in 17:
			var coverage := float(stage) / 16.0 if season == 0 else (1.0 - float(stage) / 16.0 if season == 3 else 1.0)
			var image := (snowy if season == 3 and stage >= 10 else bare).duplicate() as Image
			for y in 44:
				for x in 40:
					var col := source.get_pixel(x, y)
					if col.a < 0.1 or col.g <= col.r or col.g <= col.b: continue
					var cluster := float((int(x / 3) * 37 + int(y / 3) * 17 + int(x / 3) * int(y / 3) * 7) % 97 + 1) / 98.0
					if cluster > coverage: continue
					var light := clampf((col.g - 0.15) / 0.65, 0.0, 1.0)
					var tint := Color("526c55").lerp(Color("b9ca7f"), light)
					if season == 1: tint = Color("4c7156").lerp(Color("b3cc79"), light)
					if season in [2, 3]: tint = Color("a17f5e").lerp(Color("ebc997"), light)
					image.set_pixel(x, y, tint)
			frames.append(ImageTexture.create_from_image(image))
		result.append(frames)
	return result

static func build_pine(source: Image) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for season in 4:
		var image := source.duplicate() as Image
		for y in image.get_height():
			for x in image.get_width():
				var col := source.get_pixel(x, y)
				if col.a < 0.1 or col.g <= col.r: continue
				if season == 2: image.set_pixel(x, y, col.lerp(Color("b3ae74"), 0.25))
				if season == 3 and (y == 0 or source.get_pixel(x, y - 1).a < 0.1 or y in [4, 7, 10]):
					image.set_pixel(x, y, Color("edf1e9"))
		result.append(ImageTexture.create_from_image(image))
	return result
