extends Node
const PixelArt := preload("res://scripts/pixel_card_art.gd")
func _ready() -> void:
	bake()
func bake() -> void:
	var cards: Array = GameState.ACTION_CARDS.duplicate(true)
	var manifest: Array = []
	for card in cards:
		var path := "res://assets/art/dispatch/cards/%s.png" % card["id"]
		PixelArt.dispatch_texture(card, false).get_image().save_png(path)
		manifest.append({"id": card["id"], "name": card["name"], "category": card["category"], "texture": path})
	var file := FileAccess.open("res://assets/art/dispatch/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("DISPATCH_DECK: baked %d independent faces without cost or note" % cards.size())
	get_tree().quit()
