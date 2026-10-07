extends Node
## Run in an isolated copy through prepare_visual_test.py seasonal_water.
var checks := 0
var failures: Array[String] = []
var game: Node
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func fixture(difficulty: int, season_index: int, level: int) -> void:
	GameState.difficulty = difficulty
	GameState.turn = season_index + 1
	GameState.game_over = false
	GameState.is_failure = false
	GameState.failure_metric = ""
	GameState.metrics = {"water_level": level, "water_quality": 80, "vegetation": 80, "fish": 80, "birds": 80, "community": 80}
	GameState.used_action_ids = ["water_monitor", "patrol"]
	GameState.pending_crisis = {}
	GameState.effects_queue = []
	GameState.score_ledger = []
	GameState.log_messages = []
	GameState._sync_species()
	GameState._sync_plants()

func settle(seconds: float = 0.15) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func _ready() -> void:
	Talents.reset_all()
	GameState.run_seed = 20261007
	GameState.reset_game()
	# Every difficulty: extremes are environmental pressure, never a direct defeat.
	for difficulty in 4:
		for index in 4:
			fixture(difficulty, index, 50)
			var rule: Dictionary = GameState.water_reference()
			var base: Dictionary = GameState.WATER_SEASON_RULES[GameState.SEASONS[index]]
			var inset: int = [0, 0, 1, 2][difficulty]
			check(int(rule["low"]) == int(base["low"]) + inset and int(rule["high"]) == int(base["high"]) - inset, "Difficulty must narrow both seasonal boundaries")
			rule["low"] = -99
			check(int(GameState.WATER_SEASON_RULES[GameState.SEASONS[index]]["low"]) == int(base["low"]), "Reference callers must not mutate shared seasonal rules")
			rule = GameState.water_reference()
			for edge in [rule["low"], rule["high"]]:
				check(GameState.water_pressure(edge)["effects"].is_empty(), "Reference endpoints must be safe")
			for extreme in [0, 100]:
				GameState.metrics.water_level = extreme
				check(not GameState.check_failure_now(), "Water alone must never defeat the player")
				check(GameState.metrics_below_threshold().is_empty(), "Failure report must exclude water")
				check(GameState.failure_threshold_for("water_level") == -1, "Water has no death line")
			var previous_loss := 0
			for distance in range(1, 41):
				var pressure: Dictionary = GameState.water_pressure(int(rule["high"]) + distance)
				var loss: int = -int(pressure["effects"]["vegetation"])
				check(loss >= previous_loss, "Flood damage must increase monotonically")
				check(float(pressure["multiplier"]) <= 3.0, "Pressure must be capped")
				previous_loss = loss
			for low in [int(rule["low"]) - 1, int(rule["low"]) - 10]:
				check(GameState.water_pressure(low)["effects"].get("vegetation", 0) < 0, "Drought must damage vegetation")
			GameState.metrics.water_level = int(rule["low"])
			check(not GameState._eval_condition_simple(GameState.crisis_by_id("drought")["cond"]), "Normal seasonal low water is not extreme drought")
			GameState.metrics.water_level -= 1
			check(GameState._eval_condition_simple(GameState.crisis_by_id("drought")["cond"]), "Drought condition must follow seasonal lower bound")
			GameState.metrics.water_level = int(rule["high"])
			check(not GameState._eval_condition_simple(GameState.crisis_by_id("flood")["cond"]), "Normal high water is not a flood crisis")
			GameState.metrics.water_level += 1
			check(GameState._eval_condition_simple(GameState.crisis_by_id("flood")["cond"]), "Flood condition must follow seasonal upper bound")
			# Compare actual settlement against previews across both boundary sides,
			# including cases crossing the downstream water-quality/vegetation gates.
			for level in [0, 1, 29, 30, 40, 44, 45, 48, 54, 55, 60, 65, 66, 79, 80, 81, 90, 99, 100]:
				for quality in [44, 48, 73]:
					fixture(difficulty, index, level)
					GameState.metrics.water_quality = quality
					GameState.metrics.vegetation = 44
					GameState.used_action_ids = []
					var before: Dictionary = GameState.metrics.duplicate()
					var drift: Array = GameState.water_drift_range()
					var previews: Dictionary = {}
					var weather_seed: int = 9917 + level * 103 + quality * 31 + index * 7 + difficulty
					seed(weather_seed)
					var expected_next_random := randi()
					seed(weather_seed)
					for metric in GameState.metrics:
						previews[metric] = GameState.metric_hover_preview(metric)
					check(randi() == expected_next_random, "Read-only preview must preserve RNG")
					check(GameState.metrics == before and GameState.score_ledger.is_empty(), "Preview must preserve gameplay state")
					GameState.natural_evolution()
					for metric in GameState.metrics:
						var preview: Dictionary = previews[metric]
						var value: int = int(GameState.metrics[metric])
						check(value >= int(preview["end_min"]) and value <= int(preview["end_max"]), "Actual settlement outside hover range: " + metric)
					var water_change: int = int(GameState.metrics.water_level) - level
					check(water_change >= mini(int(drift[0]), 0) and water_change <= maxi(int(drift[1]), 0), "Seasonal retreat must not be multiplied by difficulty")
		# A real ecological collapse still loses.
		fixture(difficulty, 3, 0)
		GameState.metrics.vegetation = 0
		check(GameState.check_failure_now() and GameState.failure_metric == "vegetation", "Ecological damage must still cause defeat")
	# Action, weighting and save compatibility.
	fixture(2, 1, 90)
	GameState.funds = 500
	check(GameState.execute_action("flood_release", "effective"), "Retreat card must be playable")
	check(GameState.metrics.water_level == 78, "Water retreat must be exactly -12, including hard mode")
	check(GameState.metrics.community == 76, "Community tradeoff must retain difficulty scaling")
	check(GameState.counter_ids_for(GameState.crisis_by_id("flood")).has("flood_release"), "Flood counter pool needs retreat card")
	check(GameState._card_helps_any(GameState._find_card("flood_release"), {"water_level": "high"}), "Flood rescue must favor lowering water")
	check(not GameState._card_helps_any(GameState._find_card("water_schedule"), {"water_level": "high"}), "Flood rescue must not favor adding water")
	check(GameState._card_helps_any(GameState._find_card("water_schedule"), {"water_level": "low"}), "Drought rescue must favor adding water")
	for index in 4:
		GameState.turn = index + 1
		check(GameState.season_pool().any(func(c): return c["id"] == "flood_release"), "Retreat must be available every season")
	GameState.metrics.water_level = 0
	var saved: Dictionary = GameState.serialize()
	GameState.metrics.water_level = 99
	GameState.load_state(saved)
	check(GameState.metrics.water_level == 0 and not GameState.game_over, "Live save must retain zero water without direct defeat")
	# Balance acceptance: the unassisted natural cycle must encounter meaningful
	# seasonal pressure across multiple seeds, without forcing every turn to hurt.
	var cycle_affected := 0
	for i in 32:
		GameState.difficulty = 0
		GameState.run_seed = 70000 + i
		GameState.reset_game()
		for index in 16:
			GameState.turn = index + 1
			for metric in GameState.metrics:
				if metric != "water_level": GameState.metrics[metric] = 100
			GameState.used_action_ids = ["water_monitor", "patrol"]
			GameState.clear_score_ledger()
			GameState.natural_evolution()
			if GameState.score_ledger.any(func(e): return "干旱压力" in e["label"] or "淹水压力" in e["label"]):
				cycle_affected += 1
	check(cycle_affected >= 180 and cycle_affected <= 384, "Seasonal exposure should affect 35–75% of 512 unassisted turns, got " + str(cycle_affected))
	fixture(1, 1, 48)
	var summer_pressure: Dictionary = GameState.water_pressure(48)
	check(summer_pressure["effects"].get("vegetation") == -5, "Normal summer drought 10 points out must cost 5 vegetation")
	check(summer_pressure["effects"].get("water_quality") == -3, "Normal summer drought 10 points out must cost 3 quality")
	check(summer_pressure["effects"].get("fish") == -5, "Normal summer drought 10 points out must cost 5 fish")
	fixture(0, 3, 60)
	check(GameState.water_pressure(60)["effects"].get("birds") == -3, "Easy winter flood 10 points out must cost 3 birds")
	# Natural recovery cannot erase exposure; actual intervention before nature can.
	fixture(0, 1, 52)
	var recovered: Dictionary = GameState.water_turn_pressure(52, 60)
	check(recovered["effects"].get("vegetation") == -1, "Summer recovery must retain earlier vegetation damage")
	check(recovered["effects"].get("water_quality") == -1, "Summer recovery must retain earlier quality damage")
	check(recovered["effects"].get("fish") == -1, "Summer recovery must retain earlier fish damage")
	check(GameState.water_turn_pressure(60, 66)["effects"].is_empty(), "Entirely safe exposure must cause no damage")
	fixture(0, 3, 56)
	check(GameState.water_turn_pressure(56, 49)["effects"].get("birds") == -1, "Natural retreat must not erase prior flooded bird habitat")
	check(GameState.water_turn_pressure(60, 60)["effects"] == GameState.water_pressure(60)["effects"], "Unchanged out-of-range water must retain full pressure")
	fixture(0, 1, 52)
	GameState.funds = 500
	check(GameState.execute_action("water_schedule", "effective"), "Player replenishment must be executable")
	check(not GameState.natural_evolution_plan(false).any(func(e): return e.get("hydrology", false)), "Timely player replenishment must avoid exposure loss")
	var weather_types: Dictionary = {}
	var weather_saved := GameState.serialize()
	var saved_weather: Dictionary = GameState.year_hydrology()
	GameState.load_state(weather_saved)
	check(GameState.year_hydrology() == saved_weather, "Save/load must not reroll annual weather")
	for weather_seed in range(70000, 70100):
		GameState.run_seed = weather_seed
		var annual: Dictionary = GameState.year_hydrology(1)
		weather_types[annual["name"]] = true
		for t in range(2, 5):
			check(GameState.year_hydrology(t) == annual, "Annual water regime must persist for four seasons")
		for index in 4:
			var season: String = GameState.SEASONS[index]
			var base: Array = GameState.water_reference(season)["drift"]
			var shifted: Array = GameState.water_drift_range(season, index + 1)
			check(shifted == [int(base[0]) + int(annual["shift"]), int(base[1]) + int(annual["shift"])], "Annual forecast must shift actual seasonal drift")
	check(weather_types.size() == 3, "Seeds must produce dry, normal and wet regimes")
	# UI: seasonal geometry and tooltip text from the same live rules.
	fixture(0, 0, 50)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.4)
	if game._intro_playing: game._finish_intro()
	await settle(0.3)
	game._playing = true
	game._hide_menu()
	game.popup_root.hide()
	game.crisis_root.hide()
	game._current_phase = "allocate"
	game._enter_allocate()
	game.left_panel.show()
	game.right_panel.show()
	game.left_panel.modulate.a = 1.0
	game.right_panel.modulate.a = 1.0
	for index in 4:
		fixture(0, index, 50)
		game._update_hud()
		game._update_3d()
		var refs: Dictionary = game.metric_bars["water_level"]
		var rule: Dictionary = GameState.water_reference()
		check(is_equal_approx(refs["line"].anchor_left, float(rule["low"]) / 100.0), "Lower reference must track season")
		check(is_equal_approx(refs["high_line"].anchor_left, float(rule["high"]) / 100.0), "Upper reference must track season")
		check(refs["line"].color.g > refs["line"].color.r, "Water references must differ from lethal red lines")
		game._fill_metric_tip("water_level")
		check(not "生态红线" in game.metric_tip_body.text, "Water tooltip must not show a death line")
		await settle(0.5)
		await capture("season-" + GameState.current_season())
	for difficulty in [2, 3]:
		for index in 4:
			fixture(difficulty, index, 50)
			game._update_hud()
			var refs: Dictionary = game.metric_bars["water_level"]
			var rule: Dictionary = GameState.water_reference()
			check(is_equal_approx(refs["line"].anchor_left, float(rule["low"]) / 100.0), "HUD lower boundary must track difficulty")
			check(is_equal_approx(refs["high_line"].anchor_left, float(rule["high"]) / 100.0), "HUD upper boundary must track difficulty")
	fixture(0, 3, 85)
	game.set_process(false) # Keep the explicit tooltip visible while capturing.
	game._update_hud()
	game._update_3d()
	game._fill_metric_tip("water_level")
	check("候鸟种群" in game.metric_tip_body.text, "Winter flooding must preview bird losses")
	game.metric_tip.show()
	game._place_metric_tip(Vector2(1050, 150))
	await settle(0.3)
	await capture("winter-high-water-tip")
	fixture(1, 1, 30)
	game._update_hud()
	game._update_3d()
	game._fill_metric_tip("water_level")
	check("水质" in game.metric_tip_body.text and "鱼类资源" in game.metric_tip_body.text, "Summer drought must preview quality and fish losses")
	game.metric_tip.show()
	game._place_metric_tip(Vector2(1050, 150))
	await settle(0.3)
	await capture("summer-drought-tip")
	get_window().size = Vector2i(960, 540)
	await settle(0.4)
	game._place_metric_tip(Vector2(780, 130))
	await settle(0.3)
	check(game.metric_tip.size.y <= get_viewport().get_visible_rect().size.y, "Water tooltip must fit minimum viewport")
	await capture("water-tip-small")
	var glyphs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/card-font-glyphs.json"))
	for character in "分洪退水调度":
		check(glyphs.has(character), "New retreat title needs a baked glyph: " + character)
	print("SEASONAL_WATER: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
