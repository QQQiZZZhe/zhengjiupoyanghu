extends Node
## Run only in the isolated project made by prepare_visual_test.py.
var checks := 0
var failures: Array[String] = []
var game: Node
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func check_foil_render(card: Control, label: String) -> void:
	var panel: Control = card.get_meta("panel", card)
	var overlay: ColorRect = panel.get_node("KnowledgeFoil")
	check(not overlay.use_parent_material, label + " retains the foil material")
	game._step_card_gyro(card, Vector2(0.15, -0.20), 0.2)
	var foil := overlay.material as ShaderMaterial
	var gyro := card.material as ShaderMaterial
	check(is_equal_approx(float(foil.get_shader_parameter("tilt_x")), float(gyro.get_shader_parameter("tilt_x"))), label + " foil follows tilt")
	check(Vector2(foil.get_shader_parameter("card_center")).is_equal_approx(game._card_gyro_center(card)), label + " foil shares perspective center")
	game._step_card_gyro(card, Vector2.ZERO, 2.0)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var bounds := card.get_global_rect().grow(-6).intersection(get_viewport().get_visible_rect())
	var ratio := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var dark_pixels := 0
	var bright_pixels := 0
	for y in range(int(bounds.position.y * ratio.y), int(bounds.end.y * ratio.y), 2):
		for x in range(int(bounds.position.x * ratio.x), int(bounds.end.x * ratio.x), 2):
			var color := img.get_pixel(x, y)
			var brightness := (color.r + color.g + color.b) / 3.0
			if brightness < 0.48:
				dark_pixels += 1
			if brightness > 0.65:
				bright_pixels += 1
	check(dark_pixels > 30 and bright_pixels > 100, label + " renders legible ink and foil paper instead of a blank cover")

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("Knowledge tests require an isolated user directory")
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	Knowledge.reset_all()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	if game._intro_playing:
		game._finish_intro()
	await settle(1.0)
	game._open_knowledge_viewer()
	await settle(1.8)
	check(game.knowledge_grid.get_child_count() == 41, "All 41 cards must appear")
	check(game.knowledge_count_label.text == "已收集 0 / 41", "New profile starts at 0 / 41")
	game._show_knowledge_detail(game.knowledge_grid.get_child(8), "geo_poyang")
	check(game.knowledge_detail_title.text == "？？？", "Locked card title stays hidden")
	check(not "source_url" in game.knowledge_detail_body.text and not "https://" in game.knowledge_detail_body.text, "Locked card sources stay hidden")
	game._close_knowledge_detail()
	game._close_knowledge_viewer()
	game._show_knowledge("geo_poyang")
	check(Knowledge.is_collected("geo_poyang"), "Gameplay popup collects the new card")
	check("资料来源" in game.popup_body.text, "Gameplay popup includes source")
	game.popup_root.visible = false
	for kid in Knowledge.all_ids():
		Knowledge.unlock(kid)
	Knowledge._load()
	check(Knowledge.collected_count() == 41, "All new cards survive save reload")
	game._open_knowledge_viewer()
	await settle(1.8)
	check(game.knowledge_count_label.text == "已收集 41 / 41", "Full collection count is correct")
	var egg_view: Control = game.knowledge_grid.get_child(Knowledge.all_ids().find("egg_dixinhu"))
	await check_foil_render(egg_view, "Gallery egg")
	await capture("knowledge-dixinhu-gallery-fixed")
	game._show_knowledge_detail(egg_view, "egg_dixinhu")
	await settle(0.8)
	await check_foil_render(game._knowledge_big_card, "Detail egg")
	await capture("knowledge-dixinhu-detail-fixed")
	game._close_knowledge_detail()
	for i in Knowledge.all_ids().size():
		var kid: String = Knowledge.all_ids()[i]
		var view: Control = game.knowledge_grid.get_child(i)
		var panel: PanelContainer = view.get_meta("panel")
		check(panel.size.x <= 122.1 and panel.size.y <= 165.1, "%s must fit its card texture: %s" % [kid, panel.size])
		check(game._knowledge_art(kid) != null, "%s needs an illustration" % kid)
		game._show_knowledge_detail(view, kid)
		check(game.knowledge_detail_title.text == GameState.KNOWLEDGE_CARDS[kid]["name"], "%s opens the correct title" % kid)
		if GameState.KNOWLEDGE_CARDS[kid].has("source_url"):
			check(GameState.KNOWLEDGE_CARDS[kid]["source_url"] in game.knowledge_detail_body.text, "%s opens its source link" % kid)
	game._close_knowledge_detail()
	await capture("knowledge-all-desktop")
	for window_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = window_size
		await settle(0.4)
		game._show_knowledge_detail(game.knowledge_grid.get_child(32), "protect_scientific_release")
		await settle(2.6)
		var bounds := get_viewport().get_visible_rect()
		check(bounds.encloses(game._knowledge_big_card.get_global_rect()), "Enlarged card must fit window")
		check(bounds.encloses(game.knowledge_detail_title.get_global_rect()), "Long title must fit window")
		check(bounds.encloses(game.knowledge_detail_body.get_global_rect()), "Body must fit window")
		check(game.knowledge_detail_body.scroll_active, "Long details need scrolling")
		await capture("knowledge-detail-%d" % window_size.x)
		game._close_knowledge_detail()
	game._show_knowledge_detail(game.knowledge_grid.get_child(26), "mech_wetland_carbon")
	check("初中拓展" in game.knowledge_detail_body.text, "Carbon card carries age-level label")
	await settle(2.6)
	await capture("knowledge-carbon-small")
	game._close_knowledge_detail()
	game._close_knowledge_viewer()
	var egg: Dictionary = GameState.KNOWLEDGE_CARDS["egg_dixinhu"].duplicate(true)
	egg["condition"] = "turn == 1"
	egg["seasons"] = ["春", "夏", "秋", "冬"]
	egg["action_ids"] = ["water_control"]
	GameState.turn = 1
	GameState.used_action_ids = ["water_control"]
	check(not GameState._knowledge_condition_met(egg), "Random-only card rejects even injected trigger conditions")
	var drops := 0
	GameState._knowledge_rng.seed = 1042026
	for sample in 2000:
		GameState.turn = 1
		GameState.knowledge_last_turn = -99
		GameState.knowledge_unlocked.clear()
		GameState.pending_knowledge.clear()
		GameState._check_knowledge_triggers()
		if "egg_dixinhu" in GameState.pending_knowledge:
			drops += 1
			GameState.turn = 2
			GameState._check_knowledge_triggers()
			check(GameState.pending_knowledge.size() == 1, "Egg respects quiet next turn")
	check(drops > 25 and drops < 100, "Random egg appears at approximately 3 percent: %d" % drops)
	game._hide_menu()
	game._show_knowledge("egg_dixinhu")
	await settle(1.0)
	check(is_instance_valid(game._knowledge_egg_reveal), "Acquisition displays foil card")
	await capture("knowledge-dixinhu-acquired")
	game._show_popup("普通弹窗", "内容", "继续", Callable())
	check(game._knowledge_egg_reveal == null, "Next popup cleans special presentation")
	print("KNOWLEDGE_UI: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
