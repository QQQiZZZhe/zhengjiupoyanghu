extends Node
var game: Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(name + ".png"))

func regular_info() -> Dictionary:
	for info in game.card_infos:
		if info.card_id == "patrol" and not info.get("dispatched", false): return info
	return {}

func refresh_budget_case() -> void:
	var snapshot: Dictionary = GameState.serialize()
	var original_hand: Array = game.current_hand.duplicate()
	var original_refresh: int = game._refresh_used_turn
	GameState.funds = 113
	GameState.turn_budget = 113
	GameState.turn_card_spent = 0
	GameState.turn_other_spent = 0
	GameState.total_spent = 50
	game._refresh_used_turn = -1
	game.play_tier = "effective"
	game.current_hand = [GameState.card_by_id("wetland_restore"), GameState.card_by_id("research"), GameState.card_by_id("migration_corridor")]
	game.play_deal_anim = false
	game._build_hand_panel()
	for info in game.card_infos:
		if info.card_id == "migration_corridor": continue
		info.selected = true
		info.staged_by_drag = true
		info.stage_order = 0 if info.card_id == "wetland_restore" else 1
		info.tier = "effective"
	game._layout_fan()
	game._update_selected_label()
	await settle(0.7)
	var candidate := {"card_id": "migration_corridor"}
	check(game._committed_funds() == 70 and game.funds_label.text == "70 / 113 万", "Reported hand reserves 70 of 113 before refresh")
	check(game._card_selection_error(candidate).is_empty(), "Actual 43 remaining permits the 40-cost card")
	GameState.funds = 110
	check(game._card_selection_error(candidate).is_empty(), "Exactly 40 remaining permits the 40-cost card")
	GameState.funds = 109
	check(game._card_selection_error(candidate) == "资金不足（还需 40 万，可用 39 万）", "39 remaining correctly rejects the 40-cost card")
	GameState.funds = 113
	game._on_refresh_hand()
	await settle(1.8)
	check(GameState.funds == 108 and GameState.total_spent == 55, "Real refresh charges 5 exactly once")
	check(game._committed_funds() == 70, "Refresh keeps the 70-cost staged cards")
	check(game.funds_label.text == "75 / 113 万", "Refresh fee is included in used budget")
	check(GameState.turn_other_spent == 5 and game.funds_label.tooltip_text.contains("刷新手牌：5 万") and game.funds_label.tooltip_text.contains("剩余预算：38 万"), "Budget breakdown explains the actual remaining funds")
	check(game._card_selection_error(candidate) == "资金不足（还需 40 万，可用 38 万）", "Post-refresh validation uses the actual 38 remaining")
	game.save_game()
	game._refresh_used_turn = -1
	check(game.load_game(), "Refresh budget saves and reloads")
	check(game.funds_label.text == "75 / 113 万", "Reload keeps the full used budget")
	check(game._refresh_used_turn == GameState.turn and game.refresh_btn.disabled, "Reload preserves the once-per-turn refresh limit")
	var funds_before: int = GameState.funds
	game._on_refresh_hand()
	check(GameState.funds == funds_before and GameState.turn_other_spent == 5, "Repeated refresh after reload cannot charge again")
	check(not GameState.spend(109) and GameState.turn_other_spent == 5, "Rejected payment does not change the expense ledger")
	var legacy_file := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
	var legacy: Dictionary = JSON.parse_string(legacy_file.get_as_text())
	legacy_file.close()
	legacy.state.erase("turn_other_spent")
	legacy.erase("refresh_used_turn")
	legacy_file = FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	check(game.load_game(), "Previous-version allocation save loads")
	check(GameState.turn_other_spent == 5 and game.funds_label.text == "75 / 113 万" and game._refresh_used_turn == GameState.turn, "Older saves recover missing refresh cost and usage")
	await capture("00-refresh-budget")
	GameState.load_state(snapshot)
	game._refresh_used_turn = original_refresh
	game.current_hand = original_hand
	game.play_deal_anim = false
	game._build_hand_panel()

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle(0.5)
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261010"
	game._on_start_pressed()
	for i in 24:
		if game.popup_root.visible: game._on_popup_button()
		await settle(0.1)
	check(GameState.turn_budget == GameState.funds, "New turn snapshots its available budget")
	check(GameState.turn_card_spent == 0, "New turn clears card expenses")
	check(GameState.turn_other_spent == 0, "New turn clears non-card expenses")
	await refresh_budget_case()
	GameState.funds = 85
	GameState.turn_budget = 85
	GameState.turn_card_spent = 0
	for metric in GameState.metrics: GameState.metrics[metric] = 70
	game.current_hand = [GameState.card_by_id("patrol"), GameState.card_by_id("community_comp")]
	game.play_deal_anim = false
	game._build_hand_panel()
	game._update_hud()
	check(game.funds_label.text == "0 / 85 万", "Empty table shows zero over total budget")
	check(not game.selected_label.visible and game.selected_label.text.is_empty(), "Old table and budget text stays removed")
	check(not game.action_hint.visible and game.action_hint.text.is_empty(), "Old action-limit text stays removed")
	var info := regular_info()
	info.selected = true
	info.staged_by_drag = true
	info.stage_order = 0
	info.tier = "effective"
	game._update_selected_label()
	check(game.funds_label.text == "20 / 85 万", "Staged regular card adds its cost")
	info.tier = "deep"
	game._update_selected_label()
	check(game.funds_label.text == "%d / 85 万" % GameState.tier_cost("patrol", "deep"), "Locked tier cost updates the numerator")
	info.tier = "effective"
	check(GameState.dispatch_card("rescue"), "Actual dispatch payment succeeds")
	game._sync_dispatched_stage_cards()
	game._update_selected_label()
	check(GameState.funds == 45 and GameState.turn_card_spent == 40, "Dispatch charge is recorded exactly once")
	check(game.funds_label.text == "60 / 85 万", "Dispatch plus regular cost uses the original total budget")
	info.selected = false
	game._update_selected_label()
	check(game.funds_label.text == "40 / 85 万", "Returning a regular card reduces the numerator")
	info.selected = true
	game._layout_fan()
	game._update_selected_label()
	await settle(0.6)
	await capture("01-budget-staged")
	game.save_game()
	check(game.load_game(), "Staged budget survives actual game save/load")
	check(game.funds_label.text == "60 / 85 万", "Save/load retains total and paid dispatch without duplicates")
	var legacy: Dictionary = GameState.serialize()
	legacy.erase("turn_budget")
	legacy.erase("turn_card_spent")
	GameState.load_state(legacy)
	check(GameState.turn_budget == 85 and GameState.turn_card_spent == 40, "Older saves recover the known dispatch charge")
	check(GameState.spend(5), "Non-card expense succeeds")
	game._update_selected_label()
	check(GameState.turn_card_spent == 40 and GameState.turn_other_spent == 5, "Refresh expense is tracked separately from card cost")
	check(game.funds_label.text == "65 / 85 万", "Refresh-type expense counts in used budget while keeping the original total")
	var observed: Array[String] = []
	GameState.funds_changed.connect(func() -> void: observed.append(game.funds_label.text))
	game.score_speed = 3.0
	game._process_staged_cards(2.2)
	await settle(0.8)
	game._finish_turn()
	for i in 200:
		if not game._score_animating: break
		await settle(0.1)
	check(not game._score_animating, "Settlement completes")
	check(GameState.turn_card_spent == 60, "Execution records regular cost but does not recharge dispatch")
	check(game.funds_label.text == "65 / 85 万", "Settlement keeps all expenses even after funds are carried forward")
	for text in observed: check(text == "65 / 85 万", "Each payment signal avoids double-counting staged cards: " + text)
	await capture("02-budget-settlement")
	game.save_game()
	check(game.load_game(), "Settlement budget saves and reloads")
	check(GameState.turn_other_spent == 5 and game.funds_label.text == "65 / 85 万", "Settlement reload keeps refresh cost without counting carried funds as an expense")
	game.popup_root.visible = false
	GameState.pending_knowledge.clear()
	GameState.start_new_turn()
	game.popup_root.visible = false
	game._enter_allocate()
	check(GameState.turn_card_spent == 0, "Next turn resets card expenses")
	check(GameState.turn_other_spent == 0, "Next turn resets refresh expenses")
	check(game.funds_label.text == "0 / %d 万" % GameState.turn_budget, "Next turn starts at zero with its new budget")
	get_window().size = Vector2i(960, 540)
	GameState.turn_budget = 155
	GameState.turn_card_spent = 134
	game._update_hud()
	await settle(0.8)
	check(get_viewport().get_visible_rect().encloses(game.funds_label.get_global_rect()), "Three-digit ratio fits a small window")
	check(get_viewport().get_visible_rect().encloses(game.end_turn_btn.get_global_rect()), "Removing labels keeps operation buttons inside the window")
	await capture("03-budget-small-window")
	print("TURN_BUDGET: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
