extends Node
const PixelArt = preload("res://scripts/pixel_card_art.gd")
var game: Node
var checks := 0
var failures: Array[String] = []
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.2) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func verify_face(panel: PanelContainer, title: String, footer: String, dixinhu: bool = false, knowledge_category: String = "") -> void:
	check(panel.has_meta("pixel_face"), title + " uses the shared bitmap face")
	var face: TextureRect = panel.get_meta("pixel_face")
	check(face.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "No smoothing")
	for child in panel.get_children():
		check(not child is Label or not child.visible, "Card text never draws with a Label")
	if dixinhu:
		check(face.texture == PixelArt.KNOWLEDGE_FACE_EGG, "Dixinhu uses the complete supplied easter-egg face")
		return
	# 未解锁：统一用画好的「未知」卡面，代码一个字都不写（图上自带「未知 / ？ / UNKNOW」）
	if footer == "未收集":
		check(face.texture == PixelArt.KNOWLEDGE_FACE_LOCKED, "Locked cards use the supplied unknown face")
		return
	# 有画好卡面的知识卡类别：整张卡面 + 只把卡名写在中间空白带里
	if PixelArt.knowledge_face(knowledge_category) != null:
		check(face.texture == PixelArt.knowledge_texture(title, knowledge_category),
			"Knowledge face carries only the name")
		var base_image: Image = PixelArt.knowledge_face(knowledge_category).get_image()
		var out_image := face.texture.get_image()
		var band := PixelArt.knowledge_text_band(title).grow(PixelArt.FACE_SCALE)
		var outside := 0
		var shadows := 0
		for y in out_image.get_height():
			for x in out_image.get_width():
				var pixel := out_image.get_pixel(x, y)
				if pixel == base_image.get_pixel(x, y):
					continue
				if not band.has_point(Vector2i(x, y)):
					outside += 1
				if pixel == Color8(150, 150, 150):
					shadows += 1
		check(outside == 0, "Knowledge face only writes inside the text band: %d stray pixels" % outside)
		check(shadows > 0, "Knowledge face name keeps the shared drop shadow")
		check(PixelArt._lines(title).size() <= 4, "Full name fits without truncation")
		return
	check(face.texture == PixelArt.texture(title, footer), "Correct name and fee/state")
	var category: String = "knowledge" if footer in ["知识卡", "未收集"] else PixelArt.category_for(title)
	var base: Image = PixelArt.base_image(category)
	var glyph_scale := 4 if PixelArt.SUITS.has(category) else 1
	var image := face.texture.get_image()
	var unchanged := true
	var shadows := 0
	var shadow_offset_correct := true
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel != base.get_pixel(x, y):
				var title_region := Rect2i(68, 133, 268, 253) if glyph_scale == 4 else Rect2i(16, 32, 65, 65)
				var cost_region := Rect2i(120, 417, 112, 68) if glyph_scale == 4 else Rect2i(16, 100, 65, 17)
				unchanged = unchanged and (title_region.has_point(Vector2i(x, y)) or cost_region.has_point(Vector2i(x, y)))
				if pixel == Color8(150, 150, 150):
					shadows += 1
					shadow_offset_correct = shadow_offset_correct and image.get_pixel(x - glyph_scale, y - glyph_scale) in [Color.BLACK, PixelArt.COST_INK]
	check(unchanged, "Every pixel outside text and shadow remains original")
	check(shadows > 0, "Shadow is exactly RGB 150,150,150")
	check(shadow_offset_correct, "Every shadow pixel is one source pixel below/right of ink")
	for character in title + footer:
		check(PixelArt.mapping.has(character), "Font contains " + character)
	check(PixelArt._lines(title).size() <= 4, "Full name fits without truncation")

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Run in an isolated test project")
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	if game._intro_playing:
		game._finish_intro()
	await settle(0.4)
	for card in GameState.ACTION_CARDS:
		for tier in card["tiers"]:
			var made: Dictionary = game._make_card(card, tier)
			verify_face(made.panel, card.name, str(GameState.tier_cost(card.id, tier)))
			made.panel.free()
	for kid in Knowledge.all_ids():
		for collected in [false, true]:
			var panel: PanelContainer = game._make_knowledge_card(kid, collected)
			var kcat: String = str(GameState.KNOWLEDGE_CARDS[kid].get("category", "")) if collected else ""
			verify_face(panel, GameState.KNOWLEDGE_CARDS[kid].name if collected else "？",
				"知识卡" if collected else "未收集", collected and kid == "egg_dixinhu", kcat)
			panel.free()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261005"
	game._on_start_pressed()
	for i in 16:
		if game.popup_root.visible:
			game._on_popup_button()
		await settle(0.15)
	check(game.card_infos.size() > 0, "Real hand was dealt")
	var info: Dictionary = game.card_infos[0]
	var card: Dictionary = game._card_dict(info.card_id)
	game._set_play_tier("basic", false)
	preload("res://tests/card_input.gd").drop_on_board(game, info)
	check(info.selected and info.tier == "basic", "Selection and tier locking work")
	await settle(2.1)
	game._set_play_tier("deep", false)
	check(info.tier == "basic", "Changing lever preserves selected card price")
	check(info.panel.get_meta("pixel_face").texture == PixelArt.texture(card.name,
		str(GameState.tier_cost(card.id, "basic"))), "Locked bitmap price stays correct")
	preload("res://tests/card_input.gd").retract(game, info)
	check(info.panel.get_meta("pixel_face").texture == PixelArt.texture(card.name,
		str(GameState.tier_cost(card.id, "deep"))), "Deselection refreshes bitmap price")
	await capture("pixel-cards-hand")
	game._open_deck_viewer()
	await settle(1.8)
	await capture("pixel-cards-deck")
	var view: Control = game.deck_viewer_grid.get_child(0)
	game._show_card_detail(view, view.get_meta("card"))
	await settle(0.6)
	await capture("pixel-cards-detail")
	game._close_card_detail()
	game._close_deck_viewer()
	await settle(0.5)
	game._open_dispatch_panel()
	await settle(1.8)
	check(game.dispatch_grid.get_child_count() > 0, "Dispatch uses real card faces")
	await capture("pixel-cards-dispatch")
	game._close_dispatch_panel()
	Knowledge.unlock("geo_poyang")
	game._open_knowledge_viewer()
	await settle(1.8)
	await capture("pixel-cards-knowledge")
	game._close_knowledge_viewer()
	get_window().size = Vector2i(960, 540)
	await settle(0.5)
	await capture("pixel-cards-small")
	Knowledge.unlock("egg_dixinhu")
	game._open_knowledge_viewer()
	await settle(1.8)
	game._show_knowledge_detail(game.knowledge_grid.get_child(0), "egg_dixinhu")
	await settle(0.6)
	var foil_card: Control = game._knowledge_big_card
	var mouse: Vector2 = game._card_gyro_center(foil_card) + Vector2(40, -30)
	for i in 24:
		game._process_detail_gyro(0.05, mouse)
	var overlays: Array = foil_card.get_meta("gyro_overlays")
	check(overlays.size() == 1, "Foil remains independent and follows the rigid card")
	if overlays.size() == 1:
		check(overlays[0].get_shader_parameter("card_mask") == PixelArt.KNOWLEDGE_FACE_EGG, "Foil mask follows the supplied easter-egg face")
		check(overlays[0].get_shader_parameter("card_center") == game._card_gyro_center(foil_card), "Foil uses the same card center")
	await capture("pixel-cards-foil")
	game._close_knowledge_viewer()
	get_window().size = Vector2i(1280, 720)
	game._set_play_tier("effective", false)
	await settle(0.5)
	await capture("pixel-cards-playable")
	print("PIXEL_CARDS: %d checks, %d failures" % [checks, failures.size()])
	if not "--keep-preview" in OS.get_cmdline_user_args():
		get_tree().quit(0 if failures.is_empty() else 1)
