extends RefCounted
## Bitmap card fronts preserve category artwork and the existing glyph font.
const PAPER := preload("res://assets/art/artist-test-card-blank.png")
const SUITS := {
	"ecology": preload("res://assets/art/card-suits/ecology.png"),
	"social": preload("res://assets/art/card-suits/social.png"),
	"manage": preload("res://assets/art/card-suits/manage.png"),
}
const DIXINHU := preload("res://assets/art/card-suits/dixinhu.png")
const GLYPHS := preload("res://assets/art/card-font-glyphs.png")
const SHADOW := Color8(150, 150, 150)
const INK := Color.BLACK
static var mapping: Dictionary = {}
static var glyph_image: Image
static var paper_image: Image
static var textures: Dictionary = {}
static var suit_images: Dictionary = {}

static func _load_pixels() -> void:
	if paper_image != null:
		return
	mapping = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/card-font-glyphs.json"))
	glyph_image = GLYPHS.get_image()
	paper_image = PAPER.get_image()
	paper_image.convert(Image.FORMAT_RGBA8)
	# Knowledge cards have no action suit. Restore the baked social icon's area
	# from the opposite blank corner, including the paper edge and outer frame.
	var knowledge_paper := paper_image.duplicate() as Image
	for y in range(6, 34):
		for x in range(64, 94):
			knowledge_paper.set_pixel(x, y, paper_image.get_pixel(95 - x, y))
	suit_images["knowledge"] = knowledge_paper
	for category in SUITS:
		var image: Image = SUITS[category].get_image()
		image.convert(Image.FORMAT_RGBA8)
		suit_images[category] = image

static func category_for(title: String) -> String:
	for card in GameState.ACTION_CARDS:
		if str(card["name"]) == title: return str(card["category"])
	return ""

static func base_image(category: String) -> Image:
	_load_pixels()
	return suit_images.get(category, paper_image)

static func _width(text: String) -> int:
	var width := 0
	for character in text:
		width += int(mapping.get(character, mapping["？"])[2])
	return width

static func _lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for character in text:
		if not line.is_empty() and _width(line + character) > 64:
			lines.append(line)
			line = ""
		line += character
	if not line.is_empty():
		lines.append(line)
	return lines

static func _write(image: Image, text: String, top: int, ink: Color = INK, left_override: int = -1, glyph_scale: int = 1) -> void:
	var left := int((image.get_width() - _width(text) * glyph_scale) / 2.0) if left_override < 0 else left_override
	# All shadows first, then all foregrounds: neighboring glyphs never overwrite ink.
	for pass_index in 2:
		var x := left
		var offset := glyph_scale if pass_index == 0 else 0
		var color := SHADOW if pass_index == 0 else ink
		for character in text:
			var glyph: Array = mapping.get(character, mapping["？"])
			for y in 16:
				for gx in int(glyph[2]):
					if glyph_image.get_pixel(int(glyph[0]) + gx, int(glyph[1]) + y).a > 0.5:
						for sy in glyph_scale:
							for sx in glyph_scale:
								image.set_pixel(x + gx * glyph_scale + offset + sx, top + y * glyph_scale + offset + sy, color)
			x += int(glyph[2]) * glyph_scale

static func texture(title: String, footer: String = "", category: String = "") -> Texture2D:
	_load_pixels()
	if category.is_empty():
		category = "knowledge" if footer in ["知识卡", "未收集"] else category_for(title)
	var key := title + "\n" + footer + "\n" + category
	if textures.has(key):
		return textures[key]
	var image := base_image(category).duplicate() as Image
	var lines := _lines(title)
	var top := 32 if lines.size() >= 4 else 40
	var spacing := 17 if lines.size() >= 4 else 18
	var glyph_scale := 4 if SUITS.has(category) else 1
	if SUITS.has(category):
		top = 133 if lines.size() >= 4 else 167
		spacing = 71 if lines.size() >= 4 else 75
	for i in lines.size():
		_write(image, lines[i], top + i * spacing, INK, -1, glyph_scale)
	if not footer.is_empty():
		# Costs are already in ten-thousands; the supplied banknote prints 萬.
		if SUITS.has(category):
			_write(image, footer, 417, Color("35482d"), 179 - _width(footer) * 2, glyph_scale)
		else: _write(image, footer, 100)
	var result := ImageTexture.create_from_image(image)
	textures[key] = result
	return result

static func add_face(panel: PanelContainer, title: String, footer: String = "", locked: bool = false, category: String = "", dixinhu: bool = false) -> TextureRect:
	var face := TextureRect.new()
	face.name = "PixelCardFace"
	face.texture = DIXINHU if dixinhu else texture(title, footer, category)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		face.modulate = Color(0.68, 0.68, 0.68)
	panel.add_child(face)
	panel.set_meta("pixel_face", face)
	var outline := Node2D.new()
	outline.set_script(preload("res://scripts/card_outline.gd"))
	outline.name = "CardArtOutline"
	outline.use_parent_material = true
	panel.add_child(outline)
	return face
