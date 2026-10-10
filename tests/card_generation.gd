extends SceneTree
var Art: GDScript
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func reference_write(image: Image, text: String, top: int, ink: Color, left: int, scale: int) -> void:
	if left < 0: left = int((image.get_width() - Art._width(text) * scale) / 2.0)
	for pass_index in 2:
		var x := left
		var offset := scale if pass_index == 0 else 0
		var color: Color = Art.SHADOW if pass_index == 0 else ink
		for character in text:
			var glyph: Array = Art.mapping.get(character, Art.mapping["？"])
			for y in 16:
				for gx in int(glyph[2]):
					if Art.glyph_image.get_pixel(int(glyph[0]) + gx, int(glyph[1]) + y).a > 0.5:
						for sy in scale:
							for sx in scale:
								var px := x + gx * scale + offset + sx
								var py := top + y * scale + offset + sy
								if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
									image.set_pixel(px, py, color)
			x += int(glyph[2]) * scale
func run() -> void:
	Art = load("res://scripts/pixel_card_art.gd")
	Art._load_pixels()
	Art.textures.clear()
	var cards: Array = root.get_node("GameState").ACTION_CARDS
	var start := Time.get_ticks_usec()
	var worst := 0
	for card in cards.slice(0, 7):
		var stamp_start := Time.get_ticks_usec()
		Art.texture(card.name, str(card.cost), card.category)
		worst = maxi(worst, Time.get_ticks_usec() - stamp_start)
	print("CARD_GENERATION cold7_us=", Time.get_ticks_usec() - start, " max_single_card_us=", worst)
	Art.textures.clear()
	start = Time.get_ticks_usec()
	for card in cards: Art.texture(card.name, str(card.cost), card.category)
	print("CARD_GENERATION all52_us=", Time.get_ticks_usec() - start)
	if "--benchmark-only" in OS.get_cmdline_user_args():
		quit()
		return
	var checks := 0
	for card in cards:
		for scale in [1, 4]:
			var expected := Image.create(400, 600, false, Image.FORMAT_RGBA8)
			expected.fill(Color("e2d8bf"))
			var actual := expected.duplicate() as Image
			reference_write(expected, card.name, 100, Art.INK, -1, scale)
			Art._write(actual, card.name, 100, Art.INK, -1, scale)
			reference_write(expected, str(card.cost), 417, Art.COST_INK, 160, scale)
			Art._write(actual, str(card.cost), 417, Art.COST_INK, 160, scale)
			checks += 1
			if expected.get_data() != actual.get_data():
				failures += 1
				push_error("Glyph pixels changed: " + card.id)
	print("CARD_GENERATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
