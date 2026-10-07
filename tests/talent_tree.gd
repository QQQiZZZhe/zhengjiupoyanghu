extends Node
## Run only in prepare_visual_test.py talent_tree's isolated project/user directory.
var game: Node
var failures: Array[String] = []
var checks := 0
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")
var emitted_reports: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.25) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func fresh(wallet: int = 100) -> void:
	Talents.load_profile({"inspiration": wallet})
	Talents.granted = []
	Talents.set_run_tree({})

func buy(ids: Array) -> void:
	for id in ids: check(Talents.unlock(id), "Could not purchase " + id)

func receipt(id: String, mode: int, won: bool = true, turns: int = 16, failed: bool = false) -> Dictionary:
	return {"run_id": id, "difficulty": mode, "victory": won, "turns_survived": turns, "is_failure": failed}

func test_allocations() -> void:
	Talents.load_profile({"points": 25, "unlocked": ["fund_boost", "all_boost2"]})
	Talents.roll_for_run(999, 0)
	Talents.granted = []
	check(Talents.inspiration == 0 and Talents.tree_ranks.is_empty(), "Legacy score points must not become victory currency")
	check(Talents.points == 25 and Talents.unlocked.size() == 2, "Legacy progress backup lost")
	check(Talents.get_bonus("funding") == 0 and Talents.get_bonus("start_all") == 0, "Legacy linear bonuses leaked")
	check(not Talents.unlock("hydro"), "Zero inspiration allowed a purchase")
	fresh()
	check(Talents.tree_rank("origin") == 1, "Free root must be active")
	check(not Talents.unlock("origin") and not Talents.unlock("unknown"), "Invalid/root purchase accepted")
	check(not Talents.unlock("hydro_water") and Talents.inspiration == 100, "Missing prerequisite must not spend currency")
	buy(["hydro", "eco"])
	check(not Talents.unlock("civic") and Talents.inspiration == 98, "Three-of-three foundations allowed")
	buy(["hydro_water", "hydro_water", "hydro_quality"])
	check(not Talents.unlock("hydro_quality") and Talents.group_used("hydrology", Talents.tree_ranks) == 3, "Sibling budget must count ranks")
	check(not Talents.unlock("early_warning"), "ALL prerequisites allowed only one parent")
	buy(["careful_buy"])
	check(Talents.tree_rank("careful_buy") == 1, "ANY prerequisite rejected a single parent")
	buy(["eco_veg", "eco_fish", "eco_fish", "habitat_link", "routine_monitor"])
	check(not Talents.unlock("routine_monitor") and Talents.group_used("cross", Talents.tree_ranks) == 3, "Cross-layer budget bypassed")
	buy(["lake_resilience"])
	check(not Talents.unlock("habitat_expert") and not Talents.unlock("steady_management"), "Terminal choice must be exclusive")
	var spent := Talents.allocated_cost()
	check(spent == 17 and Talents.inspiration == 83, "Fully allocated tree must cost 17 inspiration")
	Talents.roll_for_run(12345, 0)
	Talents.granted = []
	var captured := Talents.run_tree_ranks.duplicate()
	check(Talents.respec() and Talents.inspiration == 100 and Talents.tree_ranks.is_empty(), "Respec must refund every rank")
	check(Talents.run_tree_ranks == captured, "Menu respec altered current run")
	Talents._load()
	check(Talents.inspiration == 100 and Talents.tree_ranks.is_empty(), "Profile restart lost refund")
	Talents.load_profile({"inspiration": 5, "tree_ranks": {"hydro": 9, "eco": 9, "civic": 9, "hydro_water": 9, "hydro_quality": 9, "eco_fish": -2, "unknown": 10}})
	check(Talents.group_used("directions", Talents.tree_ranks) == 2 and Talents.group_used("hydrology", Talents.tree_ranks) == 3, "Loaded invalid allocation escaped caps")
	check(not Talents.tree_ranks.has("unknown") and not Talents.tree_ranks.has("eco_fish"), "Invalid loaded ranks retained")
	fresh()
	buy(["hydro", "civic", "hydro_water", "civic_carry", "early_warning"])
	check(Talents.tree_rank("early_warning") == 1, "Both ALL parents did not unlock crossing")

func test_terminal_effects() -> void:
	var finals := ["lake_resilience", "habitat_expert", "steady_management"]
	var starting_deltas := {
		"lake_resilience": {"water_level": 5, "water_quality": 5},
		"habitat_expert": {"vegetation": 5, "birds": 5},
		"steady_management": {},
	}
	for final_id in finals:
		fresh()
		buy(["hydro", "eco", "hydro_quality", "eco_veg", "habitat_link", "careful_buy"])
		GameState.difficulty = GameState.Difficulty.EASY
		GameState.run_seed = 20261004
		GameState.reset_game()
		var starting_baseline: Dictionary = GameState.metrics.duplicate()
		buy([final_id])
		GameState.reset_game()
		for metric in starting_baseline:
			check(int(GameState.metrics[metric]) - int(starting_baseline[metric]) == int(starting_deltas[final_id].get(metric, 0)), "Terminal starting bonus wrong: %s / %s" % [final_id, metric])
		for other_id in finals:
			if other_id != final_id:
				check(not Talents.unlock(other_id), "Terminal choice must remain exclusive: " + final_id)
		Talents.granted = []
		Talents.set_run_tree({})
		GameState.carry = 0
		GameState.start_new_turn()
		var baseline: int = GameState.funds
		Talents.set_run_tree(Talents.tree_ranks)
		for round_index in 2:
			GameState.carry = 0
			GameState.start_new_turn()
			check(GameState.funds == baseline + (5 if final_id == "steady_management" else 0), "Terminal recurring funding wrong: " + final_id)
		check(Talents.get_bonus("carry") == (10 if final_id == "steady_management" else 0), "Terminal carry bonus wrong: " + final_id)
		if final_id == "steady_management":
			GameState.funds = 1000
			GameState.end_turn()
			check(GameState.carry == GameState.MAX_CARRY + 10, "Terminal carry cap must apply during turn settlement")

func test_rewards() -> void:
	fresh(0)
	for mode in 3:
		var reward := Talents.claim_victory_report(receipt("regular-%d" % mode, mode))
		check(reward.amount == mode + 1, "Regular victory reward wrong for mode %d" % mode)
		var early := Talents.claim_victory_report(receipt("early-%d" % mode, mode, true, 7))
		check(early.amount == mode + 1, "Early victory reward wrong for mode %d" % mode)
	check(Talents.inspiration == 12, "Victory currency total wrong")
	check(Talents.claim_victory_report(receipt("regular-2", 2)).duplicate, "Reopened report paid twice")
	Talents._load()
	check(Talents.claim_victory_report(receipt("early-1", 1, true, 7)).duplicate and Talents.inspiration == 12, "Restart lost reward receipts")
	for invalid in [receipt("failed", 2, false, 16, true), receipt("unfinished", 1, false, 8), receipt("conflicting", 3, true, 7, true), receipt("invalid-mode", 4), receipt("", 0)]:
		var reward := Talents.claim_victory_report(invalid)
		check(reward.amount == 0 and not reward.mastery and Talents.inspiration == 12, "Non-victory or invalid receipt paid")
	check(not Talents.nightmare_mastery, "Failed nightmare granted mastery")
	var full := Talents.claim_victory_report(receipt("early-nightmare", 3, true, 5))
	check(full.mastery and Talents.nightmare_mastery and Talents.tree_ranks.size() == 18, "Early nightmare must max the entire tree")
	for node in Talents.TREE: check(Talents.tree_rank(node.id) == int(node.max_rank), "Nightmare rank not maxed: " + node.id)
	check(Talents.group_used("directions", Talents.tree_ranks) == 3 and Talents.group_used("final", Talents.tree_ranks) == 3, "Nightmare must bypass choice caps")
	check(not Talents.respec() and Talents.inspiration == 12, "Mastery generated free inspiration via respec")
	Talents._load()
	check(Talents.nightmare_mastery and Talents.tree_ranks.size() == 18, "Restart lost nightmare mastery")
	Talents.roll_for_run(7, 3)
	Talents.granted = []
	var expected := {"start_water": 8, "start_quality": 7, "start_veg": 8, "start_fish": 3, "start_birds": 8, "start_community": 3, "carry": 14, "funding": 7, "operation": -2, "card_cost": -0.02, "crisis_chance": -0.02, "cards": 0, "first_turn_actions": 0, "interest": 0, "start_all": 0}
	for key in expected: check(is_equal_approx(Talents.get_bonus(key), float(expected[key])), "Permanent maximum too large/wrong: " + key)
	check(Talents.run_tree_effect_summary().split("\n").size() <= 3, "Mastery summary must fit starting popup")

func test_run_snapshot() -> void:
	fresh()
	GameState.difficulty = GameState.Difficulty.EASY
	GameState.run_seed = 20261003
	GameState.reset_game()
	var baseline := GameState.metrics.duplicate()
	var first_id := GameState.run_id
	var random_ids := Talents.granted.duplicate()
	var next_random := randi()
	buy(["hydro"])
	check(Talents.run_tree_count() == 0, "Allocation changed an ongoing run")
	GameState.reset_game()
	check(first_id != GameState.run_id and GameState.run_id.length() == 32, "Same seed must still produce different reward receipts")
	check(Talents.granted == random_ids and randi() == next_random, "New tree/receipt consumed seeded game RNG")
	for key in baseline:
		check(int(GameState.metrics[key]) - int(baseline[key]) == (1 if key == "water_level" else 0), "Starting permanent bonus not applied correctly: " + key)
	var saved := GameState.serialize()
	var saved_id := GameState.run_id
	check(Talents.respec(), "Respec failed during saved run")
	GameState.reset_game()
	check(Talents.run_tree_count() == 0, "New run kept removed permanent bonuses")
	GameState.load_state(saved)
	check(GameState.run_id == saved_id and Talents.run_tree_ranks == {"hydro": 1} and Talents.granted == random_ids, "Continue must restore both talent layers and receipt")
	GameState.game_over = false
	GameState.is_failure = false
	GameState.turn = 7
	check(not GameState.generate_report().victory, "An unfinished run counted as victory")
	GameState.game_over = true
	var early := GameState.generate_report()
	check(early.victory and early.inspiration_reward == 1 and early.turns_survived == 7, "Reported early victory still gated on 16 turns")
	GameState.is_failure = true
	check(not GameState.generate_report().victory and GameState.generate_report().inspiration_reward == 0, "Early failure counted as victory")
	fresh(0)
	GameState.reset_game()
	GameState.game_ended.connect(func(report: Dictionary): emitted_reports.append(report))
	GameState.turn = 16
	for key in GameState.metrics: GameState.metrics[key] = 85
	GameState.pending_crisis = {}
	GameState.forecast_crisis = {}
	GameState.end_turn()
	check(GameState.game_over and not GameState.is_failure and emitted_reports.size() == 1, "Actual final-turn flow did not emit one victorious report")
	if not emitted_reports.is_empty():
		check(Talents.claim_victory_report(emitted_reports[0]).amount == 1, "Actual game victory did not award inspiration")
	var legacy := saved.duplicate(true)
	legacy.erase("run_id")
	legacy.erase("tree_talents")
	legacy.erase("tree_mastery")
	GameState.load_state(legacy)
	var legacy_id := GameState.run_id
	check(Talents.run_tree_count() == 0 and legacy_id.begins_with("legacy:"), "Older run must continue without retroactive permanent bonuses")
	GameState.load_state(legacy)
	check(GameState.run_id == legacy_id, "Legacy save receipts must be stable on reopen")

func test_ui() -> void:
	fresh(17)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.3)
	if game._intro_playing: game._finish_intro()
	await settle(1.0)
	check(game.menu_talent_btn.visible and game.menu_start_btn.get_index() < game.menu_talent_btn.get_index() and game.menu_talent_btn.get_index() < game.menu_settings_btn.get_index(), "Tree menu entry must be between Start and Settings")
	game.menu_talent_btn.pressed.emit()
	await settle()
	var panel: PanelContainer = game.menu_talent_panel
	check(panel.visible and panel.buttons.size() == 19, "Tree panel did not render all nodes")
	panel.buttons.hydro.pressed.emit()
	panel.upgrade_button.pressed.emit()
	check(Talents.tree_rank("hydro") == 1 and panel.wallet.text.contains("16"), "UI purchase/wallet did not update")
	panel.buttons.hydro_water.pressed.emit()
	check(not panel.upgrade_button.disabled, "UI did not enable unlocked successor")
	buy(["eco", "hydro_water", "hydro_water", "hydro_quality", "eco_veg", "eco_fish", "eco_fish", "habitat_link", "routine_monitor", "stable_funding", "habitat_expert"])
	panel.select_node("habitat_link")
	await settle()
	check(panel.detail_text.text.contains("需要全部前置") and panel.detail_text.text.contains("3 / 3"), "Cross node detail must show prerequisites and cap")
	check(Talents.inspiration == 0 and panel.wallet.text == "灵感 0", "UI full build spent incorrect inspiration")
	check(get_viewport().get_visible_rect().grow(-8).encloses(panel.get_global_rect()), "Tree panel clipped at default size")
	await capture("01-talent-tree")
	for window_size in [Vector2i(960, 540), Vector2i(960, 900), Vector2i(1600, 900)]:
		get_window().size = window_size
		await settle(0.3)
		check(get_viewport().get_visible_rect().grow(-8).encloses(panel.get_global_rect()), "Tree panel clipped at " + str(window_size))
		check(panel.upgrade_button.get_global_rect().end.y < get_viewport().get_visible_rect().size.y and panel.back_button.get_global_rect().end.y < get_viewport().get_visible_rect().size.y, "Tree actions clipped at " + str(window_size))
		await capture("02-tree-%dx%d" % [window_size.x, window_size.y])
	get_window().size = Vector2i(1280, 720)
	await settle()
	panel.respec_button.pressed.emit()
	check(Talents.inspiration == 17 and Talents.tree_ranks.is_empty() and panel.wallet.text == "灵感 17", "UI respec did not refund/update")
	panel.back_button.pressed.emit()
	check(not panel.visible and game.menu_start_btn.visible, "Tree back button did not return to menu")
	Talents.claim_victory_report(receipt("ui-nightmare", 3, true, 6))
	GameState.difficulty = GameState.Difficulty.HARD
	GameState.run_seed = 6
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.HARD)
	game.seed_input.text = "6"
	game._on_start_pressed()
	# Exercise the tallest legitimate popup: three random entries + full tree.
	Talents.set_granted(["fund_boost2", "bird_start2", "cost_discount2"])
	game._show_run_talents_popup()
	game._refresh_run_talents()
	await settle(2.8)
	game.popup_body.visible_characters = -1
	check(get_viewport().get_visible_rect().grow(-8).encloses(game.popup_panel.get_global_rect()), "Full mastery start popup exceeded viewport")
	check(Talents.run_tree_count() == 18 and game.popup_body.text.contains("18 项"), "Full mastery start popup omitted permanent tree")
	await capture("03-mastery-start")
	game.popup_root.hide()
	game._refresh_run_talents()
	check(game.talents_row.get_child(0).tooltip_text.contains("蓄水预案"), "HUD must expose permanent node details")
	check(game.talents_row.get_child(0).mouse_filter != Control.MOUSE_FILTER_IGNORE, "Permanent tooltip must receive mouse hover")
	GameState.turn = 6
	GameState.game_over = true
	GameState.is_failure = false
	game._show_report(GameState.generate_report())
	await settle(0.3)
	game.popup_body.visible_characters = -1
	check(game.popup_title.text.contains("提前胜利") and game.popup_body.text.contains("+3"), "Early victory UI failed to pay/display difficulty reward")
	var wallet_after := Talents.inspiration
	game._show_report(GameState.generate_report())
	check(Talents.inspiration == wallet_after and game.popup_body.text.contains("已领取"), "UI reopening report paid twice")
	scene.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	test_allocations()
	test_terminal_effects()
	test_rewards()
	test_run_snapshot()
	await test_ui()
	print("TALENT_TREE: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	get_tree().quit(0 if failures.is_empty() else 1)
