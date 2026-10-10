extends SceneTree
func _init() -> void:
	call_deferred("verify")
func verify() -> void:
	var state := root.get_node("GameState")
	var art: GDScript = load("res://scripts/pixel_card_art.gd")
	var failures := 0
	for card in state.ACTION_CARDS:
		var path := "res://assets/art/dispatch/cards/%s.png" % card["id"]
		if not ResourceLoader.exists(path):
			push_error("Missing packed dispatch material: " + path)
			failures += 1
		elif art.dispatch_texture(card).get_size() != Vector2(400, 600):
			failures += 1
	for category in art.KNOWLEDGE_CATEGORIES:
		if art.knowledge_face(category) == null: failures += 1
	if ProjectSettings.get_setting("application/config/name") != "鄱阳归翎-生态修复手记": failures += 1
	if not ResourceLoader.exists("res://assets/houses/community-car.png"): failures += 1
	if not ResourceLoader.exists("res://assets/effects/impact-atlas.png"): failures += 1
	if not FileAccess.file_exists("res://licenses/snkrx.txt"): failures += 1
	if not FileAccess.file_exists("res://licenses/godot-vfx-library.txt"): failures += 1
	print("FRAME_LIMIT: ", Engine.max_fps)
	print("ART_EXPORT: %d dispatch cards, all knowledge categories and car; %d failures" % [state.ACTION_CARDS.size(), failures])
	print("PLAYER_PROFILE: ", OS.get_user_data_dir())
	quit(0 if failures == 0 else 1)
