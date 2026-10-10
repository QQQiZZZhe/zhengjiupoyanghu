extends SceneTree
## Legacy car preparation. Card templates now rebuild with tools/import_card_art.py.
func _init() -> void:
	print("Card templates: run python tools/import_card_art.py, then tools/bake_dispatch_deck.tscn")
	var car := Image.load_from_file("res://tools/art_sources/community-car-generated.png")
	car.convert(Image.FORMAT_RGBA8)
	# Cut transparent padding so its visual scale is explicit relative to 76px houses.
	var left := car.get_width()
	var top := car.get_height()
	var right := 0
	var bottom := 0
	for y in car.get_height():
		for x in car.get_width():
			if car.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x + 1)
				bottom = maxi(bottom, y + 1)
	var bounds := Rect2i(left, top, right - left, bottom - top)
	car = car.get_region(bounds)
	car.save_png("res://assets/houses/community-car.png")
	quit()
