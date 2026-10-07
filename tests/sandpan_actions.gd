extends Node
## Run through prepare_visual_test.py sandpan_actions to isolate player saves.
var game: Node
var failures: Array[String] = []
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.2) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))
	game.wetland.terrain_viewport.get_texture().get_image().save_png(output_dir.path_join(label + "-terrain.png"))

func rendered_water() -> int:
	if DisplayServer.get_name() == "headless": return -1
	await RenderingServer.frame_post_draw
	var image: Image = game.wetland.terrain_viewport.get_texture().get_image()
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var pixel := image.get_pixel(x, y)
			if pixel.b > pixel.g and pixel.g > pixel.r: count += 1
	return count

func reset_fixture() -> void:
	GameState.difficulty = GameState.Difficulty.EASY
	GameState.run_seed = 20261002
	GameState.reset_game()
	for key in GameState.metrics: GameState.metrics[key] = 70
	GameState.metrics.water_level = 35
	GameState.funds = 500
	GameState._sync_species()
	GameState._sync_plants()
	game.wetland.sync_state({}, false)
	game._score_animating = true
	game.popup_root.hide()
	game._current_phase = "playing"

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.3)
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261002"
	game._on_start_pressed()
	for i in 12:
		if not game.popup_root.visible: break
		game._on_popup_button()
		await settle(0.1)
	await settle(1.0)
	reset_fixture()
	# Map counts follow the two HUD metrics, independent of hidden drivers.
	var previous_birds := -1
	var previous_houses := -1
	for value in [0, 10, 25, 50, 75, 90, 100]:
		GameState.metrics.birds = value
		GameState.metrics.community = value
		game.wetland.sync_state({}, false)
		var birds := 0
		for sid in GameState.SPECIES: birds += game.wetland._bird_count(sid)
		check(birds == roundi(value * 0.5), "Bird total must follow birds metric exactly")
		check(birds >= previous_birds, "Bird count must increase with birds metric")
		check(game.wetland.house_target_count == roundi(value / 100.0 * game.wetland.house_sites.size()), "House total must follow community metric")
		check(game.wetland.house_target_count >= previous_houses, "House count must increase with community metric")
		var visible_houses := 0
		for phase in game.wetland.house_progress:
			if phase > 0.99: visible_houses += 1
		check(visible_houses == game.wetland.house_target_count, "Immediate sync must snap house visibility")
		previous_birds = birds
		previous_houses = game.wetland.house_target_count
		if value in [0, 50, 100]:
			game._update_hud()
			await capture("population-" + str(value))
	GameState.metrics.birds = 100
	GameState.metrics.community = 100
	game.wetland.sync_state({}, false)
	GameState.metrics.birds = 0
	GameState.metrics.community = 0
	var frozen_state: Dictionary = game.wetland.capture_state()
	game.wetland.play_action("bird_reserve", frozen_state, 0.6)
	await settle(0.25)
	check(game.wetland._bird_visibility("baihe", 0) > 0.0 and game.wetland._bird_visibility("baihe", 0) < 1.0, "Bird loss must fade during card reveal")
	check(game.wetland.house_progress[0] > 0.0 and game.wetland.house_progress[0] < 1.0, "House loss must animate during card reveal")
	await settle(0.5)
	check(game.wetland._bird_count("baihe") == 0 and is_zero_approx(game.wetland.house_progress[0]), "Animations must converge to zero counts")
	GameState.settlement = 100
	for sid in GameState.species_pop: GameState.species_pop[sid] = 100
	game.wetland.sync_state({}, false)
	check(game.wetland.house_target_count == 0, "Settlement must not override zero community")
	for sid in GameState.SPECIES: check(game.wetland._bird_count(sid) == 0, "Species population must not override zero birds")
	reset_fixture()
	await capture("01-before-water")
	var low_area: int = await rendered_water()
	check(GameState.execute_action("water_replenish", "deep", true), "Deep water replenishment failed")
	var after_card: Dictionary = game.wetland.capture_state()
	check(GameState.metrics.water_level == 59, "Water card's gameplay values changed")
	check(game.wetland.metrics.water_level == 35, "Signal must stay frozen until card reveal")
	var real_metrics := GameState.metrics.duplicate()
	seed(12345)
	var expected_random := randi()
	seed(12345)
	game.wetland.play_action("water_replenish", after_card, 1.0)
	check(randi() == expected_random, "Card presentation must not consume gameplay RNG")
	await settle(0.4)
	check(game.wetland.displayed_metrics.water_level > 35 and game.wetland.displayed_metrics.water_level < 59, "Waterline must interpolate during replenishment")
	await capture("02-water-rising")
	game._pause_game()
	var paused_level: float = game.wetland.displayed_metrics.water_level
	await settle(0.2)
	check(is_equal_approx(paused_level, game.wetland.displayed_metrics.water_level), "Pause must freeze waterline animation")
	game._resume_game()
	await settle(0.8)
	await capture("03-after-water")
	var high_area: int = await rendered_water()
	print("Rendered water samples: ", low_area, " -> ", high_area)
	if low_area >= 0: check(high_area > low_area + 100, "Replenishment must increase rendered lake area")
	check(GameState.metrics == real_metrics, "Presentation mutated ecology values")
	GameState.metrics.water_level = 20
	game.wetland.sync_state({}, true, 0.6)
	await settle(0.7)
	var dry_area: int = await rendered_water()
	if high_area >= 0: check(dry_area < low_area, "Falling water must expose lakebed and shrink area")
	await capture("04-water-retreat")
	reset_fixture()
	check(GameState.execute_action("floating_island", "deep", true), "Floating island card failed")
	check(GameState.floating_islands == 4, "Legacy floating island count changed")
	game.wetland.play_action("floating_island", game.wetland.capture_state(), 1.0)
	await settle(0.4)
	check(game.wetland.displayed_islands > 0 and game.wetland.displayed_islands < 4, "Floating islands must animate construction")
	await capture("05-floating-islands-building")
	await settle(0.7)
	await capture("06-floating-islands-built")
	check(GameState.execute_action("dredge", "effective", true), "Dredging card failed")
	game.wetland.play_action("dredge", game.wetland.capture_state(), 1.0)
	await settle(0.3)
	check(game.wetland.displayed_islands > 0 and game.wetland.displayed_islands < 4, "Dredging must animate island removal")
	await settle(0.8)
	check(is_zero_approx(game.wetland.displayed_islands), "Dredging must finish removing floating islands")
	reset_fixture()
	var old_kucao: int = GameState.plant_pop.kucao
	check(GameState.execute_action("veg_restore", "deep", true), "Vegetation card failed")
	game.wetland.play_action("veg_restore", game.wetland.capture_state(), 1.0)
	await settle(0.4)
	check(game.wetland.displayed_plants.kucao > old_kucao and game.wetland.displayed_plants.kucao < GameState.plant_pop.kucao, "Wetland plants must animate growth")
	await capture("07-vegetation-growth")
	reset_fixture()
	check(GameState.execute_action("water_storage", "basic", true), "Delayed storage card failed")
	game.wetland.play_action("water_storage", game.wetland.capture_state(), 0.3)
	await settle(0.4)
	check(game.wetland.displayed_metrics.water_level == 35, "Delayed card must not enlarge the lake before its effect arrives")
	GameState.advance_effects()
	game.wetland.sync_state({}, true, 0.4)
	await settle(0.5)
	check(game.wetland.displayed_metrics.water_level == 40, "Arriving delayed water effect must update the lake")
	# Exercise the real selected-hand + emergency-dispatch score choreography.
	reset_fixture()
	game._score_animating = false
	game.current_hand = [GameState.card_by_id("water_replenish"), GameState.card_by_id("floating_island")]
	game._build_hand_panel()
	await settle(0.2)
	game._set_play_tier("effective", false)
	for info in game.card_infos: game._toggle_card(info.panel)
	GameState.dispatched_cards = [{"card_id": "fish_restock", "tier": "effective"}]
	game.score_speed = 1.0
	game._finish_turn()
	await settle(0.55)
	check(game._score_animating, "Actual turn must run score animation")
	check(not game.wetland.action_effects.is_empty(), "Card reveal must play a corresponding sandpan effect")
	for info in game.card_infos:
		check(info.has("sandpan_state"), "Successful selected/dispatched card needs its own visual snapshot")
	await capture("08-real-card-reveal")
	for i in 40:
		if not game._score_animating: break
		await settle(0.2)
	await settle(1.0)
	check(not game._score_animating, "Score choreography must finish")
	check(game.wetland.metrics == GameState.metrics, "Final sandpan must match settled ecology")
	check(is_equal_approx(game.wetland.displayed_metrics.water_level, GameState.metrics.water_level), "Animated water must converge to actual settlement")
	check(game.wetland.islands == GameState.floating_islands, "Replayed construction must converge to saved island state")
	await capture("09-real-settlement")
	var sites_before: Dictionary = game.wetland.plant_sites.duplicate(true)
	game.wetland.reduced_motion = true
	GameState.metrics.water_level = 80
	game.wetland.sync_state()
	check(game.wetland.displayed_metrics.water_level == 80, "Reduced motion must show final ecology immediately")
	game.wetland._reset_scenery()
	check(game.wetland.plant_sites == sites_before, "Seeded scenery placement must not depend on animated water level")
	print("SANDPAN_ACTIONS: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
