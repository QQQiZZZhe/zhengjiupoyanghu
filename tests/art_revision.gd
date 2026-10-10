extends Node
const PixelArt := preload("res://scripts/pixel_card_art.gd")
var failures: Array[String] = []
var checks := 0
var game: Node
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(label + ".png"))
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var original := GameState.ACTION_CARDS.duplicate(true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await get_tree().create_timer(1.0).timeout
	if game._intro_playing: game._finish_intro()
	await get_tree().create_timer(1.0).timeout
	await capture("01-title")
	for card in GameState.ACTION_CARDS:
		var made: Dictionary = game._make_card(card, "effective", true)
		var face: TextureRect = made.panel.get_meta("pixel_face")
		check(face.texture == PixelArt.dispatch_texture(card), "Dispatch uses independent face: " + card.id)
		check(ResourceLoader.exists("res://assets/art/dispatch/cards/%s.png" % card.id), "Dispatch material exists: " + card.id)
		check(not "万" in made.panel.tooltip_text, "Dispatch tooltip omits original price: " + card.id)
		game._update_card_face({"card_id": card.id, "tier": "effective", "dispatched": true, "panel": made.panel, "cost_label": made.cost_label})
		check(face.texture == PixelArt.dispatch_texture(card), "Refreshing a dispatched card preserves independent art")
		made.panel.free()
	check(GameState.ACTION_CARDS == original, "Card fees and effects remain unchanged")
	for used in [0, 1, 2, 5]:
		GameState.dispatch_used_count = used
		check(GameState.dispatch_cost() == 40 + used * 10, "Dispatch pricing still rises by 10")
	GameState.dispatch_used_count = 0
	for kid in Knowledge.all_ids():
		var card: Dictionary = GameState.KNOWLEDGE_CARDS[kid]
		if card.category != "彩蛋": check(PixelArt.knowledge_face(card.category) != null, "New knowledge face covers " + card.category)
		Knowledge.unlock(kid)
	game._open_knowledge_viewer()
	await get_tree().create_timer(2.0).timeout
	await capture("02-knowledge-all")
	game._show_knowledge_detail(game.knowledge_grid.get_child(Knowledge.all_ids().find("geo_poyang")), "geo_poyang")
	await get_tree().create_timer(1.0).timeout
	await capture("03-knowledge-geography")
	game._close_knowledge_detail()
	game._close_knowledge_viewer()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261009"
	game._on_start_pressed()
	for i in 16:
		if game.popup_root.visible: game._on_popup_button()
		await get_tree().create_timer(0.15).timeout
	game._open_dispatch_panel()
	await get_tree().create_timer(2.0).timeout
	await capture("04-dispatch")
	game._close_dispatch_panel()
	var wetland: Control = game.wetland
	check(wetland.car_site != Vector2.ZERO and wetland._is_land(wetland.car_site), "Car parks on land")
	check(wetland.car_site.distance_to(wetland.house_sites[wetland.CAR_HOUSE_INDEX]) >= 0.035, "Car has room beside the house")
	wetland.metrics["community"] = 55
	wetland.sync_community_targets()
	check(not wetland._community_car_visible(), "Car hidden before community grows")
	GameState.metrics["community"] = 80
	game._update_hud()
	wetland.metrics["community"] = 80
	wetland.sync_community_targets()
	check(wetland._community_car_visible(), "Car appears with grown community")
	await get_tree().create_timer(1.0).timeout
	var cars := 0
	for item in wetland._render_items:
		if item.kind == "community_car": cars += 1
	check(cars == 1, "Exactly one community car")
	await capture("05-community-car")
	print("CAR_POSITION: ", wetland.car_site, " screen=", wetland._wildlife_point(wetland.car_site))
	game._open_deck_viewer()
	await get_tree().create_timer(1.5).timeout
	await capture("06-normal-deck")
	game._close_deck_viewer()
	print("ART_REVISION: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
