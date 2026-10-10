extends Node
var checks := 0
var failures := 0
const REGULAR := ["veg_restore", "education", "guard_team", "research"]
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(difficulty: int) -> void:
	GameState.difficulty = difficulty
	GameState.run_seed = 20261009
	GameState.reset_game()
	GameState.funds = 1000
	for metric in GameState.metrics: GameState.metrics[metric] = 65
	GameState.clear_score_ledger()
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	for difficulty in [GameState.Difficulty.EASY, GameState.Difficulty.NORMAL, GameState.Difficulty.HARD, GameState.Difficulty.NIGHTMARE]:
		fresh(difficulty)
		var slots := GameState.action_slots()
		for dispatch_position in range(slots + 1):
			fresh(difficulty)
			var normal_count := 0
			for position in range(slots + 1):
				if position == dispatch_position:
					check(GameState.execute_action("water_control", "effective", true), "Dispatch executes at any queue position")
				else:
					check(GameState.execute_action(REGULAR[normal_count % REGULAR.size()], "effective"), "Normal action after dispatch must execute up to the normal slot limit")
					normal_count += 1
			check(GameState.used_action_ids.size() == slots + 1, "Every queued card enters effects and scoring")
			check(GameState.free_actions_executed == 1, "Only the free action is excluded from slots")
			check(not GameState.can_execute("research", "effective"), "Extra normal actions still respect the slot limit")
			var saved := GameState.serialize()
			GameState.load_state(saved)
			check(GameState.free_actions_executed == 1 and not GameState.can_execute("research", "effective"), "Save/reload keeps slot accounting")
	fresh(GameState.Difficulty.EASY)
	check(GameState.execute_action("water_control", "effective", true), "Dispatch before partial normal sequence")
	check(GameState.execute_action("education", "effective"), "Normal action before saving")
	var saved := GameState.serialize()
	GameState.load_state(saved)
	check(GameState.can_execute("research", "effective"), "Remaining normal slots survive load after dispatch")
	GameState.start_new_turn()
	check(GameState.free_actions_executed == 0 and GameState.used_action_ids.is_empty(), "Next turn clears both counters")
	var old_save := GameState.serialize()
	old_save.erase("free_actions_executed")
	GameState.load_state(old_save)
	check(GameState.free_actions_executed == 0, "Older saves load with an empty free-action count")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var game: Node = scene.get_node("Game")
	game.set_script(load("res://tests/fixtures/dispatch_score_probe.gd"))
	add_child(scene)
	await get_tree().create_timer(0.5).timeout
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261009"
	game._on_start_pressed()
	for i in 16:
		if game.popup_root.visible: game._on_popup_button()
		await get_tree().create_timer(0.15).timeout
	GameState.funds = 1000
	for metric in GameState.metrics: GameState.metrics[metric] = 65
	for info in game.card_infos: info.panel.queue_free()
	game.card_infos.clear()
	for i in REGULAR.size():
		var card := GameState.card_by_id(REGULAR[i])
		var made: Dictionary = game._make_card(card, "effective")
		var panel: PanelContainer = made.panel
		panel.pivot_offset = Vector2(61, 165)
		panel.set_meta("probe_card_id", card.id)
		game.card_box.add_child(panel)
		game.card_infos.append({"panel": panel, "card_id": card.id, "cost_label": made.cost_label, "selected": true, "staged_by_drag": true, "stage_order": i, "tier": "effective", "hovered": false, "shaking": false})
	check(GameState.dispatch_card("water_control"), "Real dispatch payment succeeds")
	game._sync_dispatched_stage_cards()
	var dispatched: Dictionary = game.card_infos.back()
	dispatched.panel.set_meta("probe_card_id", "water_control")
	await get_tree().create_timer(0.7).timeout
	game._card_press_panel = dispatched.panel
	game._start_card_drag()
	var drop: Vector2 = game.card_box.global_position + game.card_infos[0].base_pos + Vector2(61, 70)
	game._update_card_drag_pose(drop, Vector2(-100, 0))
	game._finish_card_pointer(drop)
	var order: Array = game._ordered_staged_indices()
	check(game.card_infos[order[0]].get("dispatched", false), "Actual drag moves dispatch from last to first")
	check(game.card_infos[order.back()].card_id == "research", "A regular hand card now occupies the final slot")
	game._process_staged_cards(2.2)
	await get_tree().create_timer(0.8).timeout
	game._finish_turn()
	for i in 160:
		await get_tree().create_timer(0.05).timeout
		if game.popped_cards.size() == 5: break
	var expected: Array[String] = ["water_control", "veg_restore", "education", "guard_team", "research"]
	check(game.replayed_cards == expected, "Settlement keeps all five cards in reordered table order")
	check(game.popped_cards == expected, "Final normal card receives its actual score-pop animation")
	check(GameState.ever_played.get("research", 0) == 1, "Final normal card effects execute once")
	if not OS.get_environment("POYANG_SCREENSHOT_DIR").is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join("09-dispatch-reordered-score.png"))
	print("DISPATCH_REORDER: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
