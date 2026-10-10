extends Node
var game: Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func wait_for(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func shot(label: String) -> void:
	var folder := OS.get_environment("POYANG_SCREENSHOT_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(label + ".png"))

func begin(info: Dictionary) -> Vector2:
	var panel: Control = info.panel
	var origin: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
	game._card_press_panel = panel
	game._card_press_origin = origin
	game._start_card_drag()
	game._card_drag_grab_point = panel.size * 0.5
	return origin

func drop(info: Dictionary, point: Vector2) -> void:
	game._update_card_drag_pose(point, Vector2.ZERO)
	game._finish_card_pointer(point)

func real_drag(info: Dictionary, movement: Vector2) -> void:
	var panel: Control = info.panel
	var origin: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = origin
	motion.global_position = origin
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.position = origin
	press.global_position = origin
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(game._card_press_panel == panel, "Native GUI can press the visible card outside the hand bounds")
	motion = InputEventMouseMotion.new()
	motion.position = origin + movement
	motion.global_position = motion.position
	motion.relative = movement
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(game._card_dragging, "Real input motion starts the drag")
	var release := InputEventMouseButton.new()
	release.position = origin + movement
	release.global_position = release.position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(game._card_press_panel == null and not game._card_dragging, "Real release clears GUI capture")

func board_pose() -> void:
	var order: Array = game._ordered_staged_indices()
	var previous_center := Vector2.ZERO
	for i in order.size():
		var info: Dictionary = game.card_infos[order[i]]
		var panel: Control = info.panel
		var center: Vector2 = panel.get_global_transform() * (panel.size * 0.5)
		check(game.staged_board.get_global_rect().encloses(panel.get_global_rect()), "Every mini card fits on the wood")
		check(absf(panel.rotation) < 0.001 and absf(panel.scale.x - game.BOARD_CARD_SCALE) < 0.001, "Mini cards lie flat at the same scale")
		if i > 0:
			check(absf(center.y - previous_center.y) < 0.1, "Mini cards share a horizontal baseline")
			check(absf(center.x - previous_center.x - game.BOARD_CARD_SPACING) < 0.1, "Mini cards have equal gaps")
		previous_center = center

func flight_rates() -> void:
	var reference: Array = []
	for rate in [30, 60, 120]:
		var panel := Control.new()
		panel.size = Vector2(122, 165)
		panel.pivot_offset = Vector2(61, 165)
		panel.position = Vector2(40, 60)
		game.card_box.add_child(panel)
		var start: Vector2 = panel.get_transform() * (panel.size * 0.5)
		var flight: Node = game.CardFlight.play(panel, Vector2(470, -260), Vector2(0.44, 0.44), 0.0, 0.6, 92.0)
		flight.set_process(false)
		check((panel.get_transform() * (panel.size * 0.5)).distance_to(start) < 0.001, "Flight starts at the exact visible pose")
		for step in int(rate * 0.3): flight._process(1.0 / float(rate))
		var sample: Array = [panel.position, panel.scale, panel.rotation]
		if reference.is_empty(): reference = sample
		else:
			check(panel.position.distance_to(reference[0]) < 0.001 and panel.scale.distance_to(reference[1]) < 0.001 and absf(panel.rotation - reference[2]) < 0.001, "Flight trajectory matches at 30 / 60 / 120 fps")
		game.CardFlight.stop(panel)
		check(panel.get_node_or_null("CardFlight") == null, "Cancellation detaches the flight immediately")
		panel.queue_free()

func refund_transactions() -> void:
	var snapshot: Dictionary = GameState.serialize()
	GameState.turn = 10
	GameState.funds = 1000
	GameState.total_spent = 200
	GameState.turn_card_spent = 0
	GameState.dispatched_cards = []
	GameState.dispatch_used_count = 3
	GameState.dispatch_last_turn = 3
	var quote: int = GameState.dispatch_cost()
	check(GameState.dispatch_card("water_control"), "Later dispatch quote can be purchased")
	GameState.load_state(GameState.serialize())
	check(GameState.cancel_dispatch("water_control"), "Pending saved dispatch can be cancelled")
	check(GameState.funds == 1000 and GameState.total_spent == 200 and GameState.turn_card_spent == 0, "Later quote refunds actual payment after reload")
	check(GameState.dispatch_cost() == quote and GameState.dispatch_last_turn == 3 and GameState.dispatch_used_count == 3, "Cancellation restores prior price and cooldown history")
	check(not GameState.cancel_dispatch("water_control") and GameState.funds == 1000, "Repeated refund never creates money")
	GameState.load_state(snapshot)

func rejected_returns(info: Dictionary, destination: Vector2, label: String) -> void:
	var rest: Vector2 = info.base_pos
	var angle: float = info.theta
	var funds: int = GameState.funds
	var committed: int = game._committed_funds()
	var count: int = game._ordered_staged_indices().size()
	begin(info)
	game._update_card_drag_pose(destination, Vector2(0, -60))
	game._update_card_drag_pose(destination + Vector2(2, 0), Vector2(2, 0))
	check(info.base_pos.is_equal_approx(rest) and is_equal_approx(info.theta, angle), label + ": drag preview preserves the hand rest pose")
	drop(info, destination)
	check(not info.selected and not info.get("staged_by_drag", false), label + ": release cannot commit a rejected card")
	await wait_for(1.4)
	check(info.panel.position.distance_to(info.base_pos) < 0.5 and absf(info.panel.rotation - info.theta) < 0.01 and info.panel.scale.distance_to(Vector2.ONE) < 0.01, label + ": rejected card automatically returns to its hand pose without mouse movement")
	check(not info.get("shaking", false) and not info.get("flying", false), label + ": rejection animation releases the card")
	check(GameState.funds == funds and game._committed_funds() == committed and game._ordered_staged_indices().size() == count, label + ": rejection preserves payment and queue")

func rejection_cases() -> void:
	var info: Dictionary = game.card_infos[4]
	var funds: int = GameState.funds
	GameState.funds = 0
	await rejected_returns(info, game.card_box.global_position + Vector2(game.card_box.size.x * 0.5, -110), "Insufficient funds in preview area")
	await rejected_returns(info, game.staged_board.get_global_rect().get_center(), "Insufficient funds on wood")
	GameState.funds = funds
	for i in 4:
		var staged: Dictionary = game.card_infos[i]
		staged.selected = true
		staged.staged_by_drag = true
		staged.stage_order = i
		staged.stage_zone = "board"
	game._layout_fan(true)
	await wait_for(0.8)
	check(game._card_selection_error(info).contains("行动位"), "Four ordinary cards fill EASY action slots")
	await rejected_returns(info, game.staged_board.get_global_rect().get_center(), "Action slots full")
	for staged in game.card_infos:
		staged.selected = false
		staged.staged_by_drag = false
		staged.stage_zone = "hand"
	game._layout_fan(true)
	await wait_for(0.8)

func direct_board_preview() -> void:
	var info: Dictionary = game.card_infos[0]
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	begin(info)
	drop(info, game.staged_board.get_global_rect().get_center())
	check(info.selected and info.stage_zone == "board" and info.preview_left == 0.0 and not info.get("queue_flying", false), "Direct wood drop skips preview timer and flight")
	await wait_for(0.8)
	game._update_metric_preview()
	var queue: Array = [{"card_id": info.card_id, "tier": game._info_tier(info), "dispatched": false}]
	check(game._metric_preview_values == GameState.preview_settlement(queue), "Board HUD shows the current settlement forecast")
	var actual = load("res://scripts/game_state.gd").new()
	actual.load_state(snapshot.duplicate(true), false)
	actual.execute_action(info.card_id, game._info_tier(info))
	actual.end_turn()
	check(game._metric_preview_values == actual.metrics, "Forecast matches actual settlement with the same turn weather")
	actual.free()
	seed(451)
	var expected_random := randi()
	seed(451)
	for i in 8: GameState.preview_settlement(queue)
	check(randi() == expected_random and GameState.serialize() == snapshot, "Repeated previews preserve live state and global random stream")
	for metric in game.metric_bars:
		var overlay: Control = game.metric_bars[metric].preview
		check(overlay.tint == game.METRIC_COLORS[metric] and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Preview uses metric color and cannot intercept card input")
		check(is_equal_approx(overlay.current, float(GameState.metrics[metric])) and is_equal_approx(overlay.predicted, float(game._metric_preview_values[metric])), "Overlay covers exactly the forecast difference")
		check(overlay.segment_rect().size.y == game.metric_bars[metric].bar.size.y and overlay.segment_rect().position.y == 0.0, "Preview has the original bar's full thickness and baseline")
		var original_fill: StyleBoxFlat = game.metric_bars[metric].bar.get_theme_stylebox("fill")
		var preview_fill: StyleBoxFlat = overlay._fill.get_theme_stylebox("fill")
		check(original_fill.bg_color == game.METRIC_COLORS[metric], "Preview cannot recolor the live metric bar")
		if overlay.predicted < overlay.current:
			check(preview_fill.bg_color == overlay.LOSS_COLOR and preview_fill.corner_radius_top_right == original_fill.corner_radius_top_right, "Loss preview is red with the original shape")
		else:
			check(preview_fill == original_fill, "Increasing preview retains its original fill and border")
	var staggered := 0
	for metric in game.metric_bars:
		var overlay: Control = game.metric_bars[metric].preview
		overlay.configure(30.0, 60.0 if staggered % 2 == 0 else 20.0)
		check(overlay._fill.get_theme_stylebox("fill").bg_color == (game.METRIC_COLORS[metric] if staggered % 2 == 0 else overlay.LOSS_COLOR), "Forecast direction changes immediately select the correct color")
		game._metric_preview_clock += 0.17
		await get_tree().process_frame
		staggered += 1
	for phase in [0.1, 0.42, 0.76]:
		game._metric_preview_clock = phase
		await wait_for(0.04)
		var reference_alpha := -1.0
		for metric in game.metric_bars:
			var overlay: Control = game.metric_bars[metric].preview
			if reference_alpha < 0.0: reference_alpha = overlay._fill.modulate.a
			check(absf(overlay._fill.modulate.a - reference_alpha) < 0.0001, "Staggered increases and decreases blink in exactly the same phase")
	for metric in game.metric_bars:
		var overlay: Control = game.metric_bars[metric].preview
		if overlay.predicted > overlay.current:
			check(overlay._join_clip.visible and is_equal_approx(overlay._join_clip.position.x + overlay._join_clip.size.x, overlay.segment_rect().position.x), "Increasing preview covers the old rounded tip without a gap")
		else:
			check(not overlay._join_clip.visible, "Decreasing preview retains the original rounded endpoint")
	game._metric_preview_dirty = true
	game._update_metric_preview()
	await shot("00-direct-preview")
	await capture_decrease_demo()
	game._return_staged_to_hand(info)
	await wait_for(0.6)
	game._update_metric_preview()
	check(game._metric_preview_values == GameState.preview_settlement([]), "Empty queue retains the natural settlement forecast")
	for metric in game.metric_bars:
		check(game.metric_bars[metric].preview.predicted == game._metric_preview_values[metric], "Empty queue previews each natural metric change")
	var live: Dictionary = GameState.serialize().duplicate(true)
	for ids in [["veg_restore", "water_control"], ["dredge", "education"], ["guard_team", "research"]]:
		var source: Dictionary = live.duplicate(true)
		source.metrics.vegetation = 98
		source.effects_queue.append({"metric": "fish", "delta": 8, "remaining": 1, "source": "test", "queued_turn": GameState.turn - 1})
		source.pending_crisis = {"id": "test", "name": "test", "hit": "test", "effects": [{"metric": "community", "delta": -4}]}
		var isolated = load("res://scripts/game_state.gd").new()
		isolated.load_state(source.duplicate(true), false)
		actual = load("res://scripts/game_state.gd").new()
		actual.load_state(source.duplicate(true), false)
		queue = []
		for id in ids:
			queue.append({"card_id": id, "tier": "effective", "dispatched": false})
			actual.execute_action(id, "effective")
			if actual.game_over: break
		if not actual.game_over: actual.end_turn()
		check(isolated.preview_settlement(queue) == actual.metrics, "Preview matches settlement for delayed effects, limits, crisis and card combinations")
		isolated.free()
		actual.free()
	check(GameState.serialize() == live, "Complex forecast scenarios cannot mutate the live game")
	forecast_regression()

func forecast_regression() -> void:
	var live: Dictionary = GameState.serialize().duplicate(true)
	for difficulty in range(4):
		for turn in [2, 3, 4, 5]:
			for values in [[48, 44, 44, 60, 85, 65], [76, 72, 98, 98, 58, 80], [32, 53, 58, 56, 69, 59]]:
				var source: Dictionary = live.duplicate(true)
				source.difficulty = difficulty
				source.turn = turn
				source.funds = 1000
				source.used_action_ids = []
				source.free_actions_executed = 0
				var keys := ["water_level", "water_quality", "vegetation", "fish", "birds", "community"]
				for i in keys.size(): source.metrics[keys[i]] = values[i]
				source.effects_queue = [{"metric": "water_quality", "delta": -3, "remaining": 1, "source": "leftover", "queued_turn": turn - 2}, {"metric": "vegetation", "delta": 8, "remaining": 1, "source": "leftover", "queued_turn": turn - 1}, {"metric": "fish", "delta": 20, "remaining": 2, "source": "future", "queued_turn": turn - 1}]
				source.pending_crisis = {"id": "test", "name": "test", "hit": "test", "effects": [{"metric": "community", "delta": -4}]}
				var queue: Array = [{"card_id": "water_control", "tier": "effective", "dispatched": false}, {"card_id": "veg_restore", "tier": "effective", "dispatched": false}]
				var forecast = load("res://scripts/game_state.gd").new()
				forecast.load_state(source.duplicate(true), false)
				var predicted: Dictionary = forecast.preview_settlement(queue)
				var actual = load("res://scripts/game_state.gd").new()
				actual.load_state(source.duplicate(true), false)
				for card in queue:
					actual.execute_action(card.card_id, card.tier)
					if actual.game_over: break
				if not actual.game_over: actual.end_turn()
				check(predicted == actual.metrics, "Exact forecast covers all seasons, difficulties, thresholds, leftover effects and ecological interactions")
				check(forecast.settlement_water_delta() == actual.settlement_water_delta(), "Weather is identical across preview and actual settlement")
				forecast.free()
				actual.free()
	check(GameState.serialize() == live, "Forecast regression never changes the player's state")

func capture_decrease_demo() -> void:
	var folder := OS.get_environment("POYANG_PREVIEW_DEMO_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless": return
	var original: Dictionary = GameState.serialize().duplicate(true)
	# Isolated illustration: a queued ecological loss reaches this turn's settlement.
	GameState.effects_queue.append({"metric": "fish", "delta": -12, "remaining": 1, "source": "demo", "queued_turn": GameState.turn - 1})
	game._metric_preview_dirty = true
	game._update_metric_preview()
	print("DECREASE_DEMO: fish ", GameState.metrics.fish, " -> ", game._metric_preview_values.fish)
	for frame in 60:
		game._metric_preview_clock = float(frame) / 33.0
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image = get_viewport().get_texture().get_image()
		rendered.get_region(Rect2i(game.right_panel.get_global_rect())).save_png(folder.path_join("frame_%03d.png" % frame))
	GameState.load_state(original, false)
	game._metric_preview_dirty = true
	game._update_metric_preview()

func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	game = scene.get_node("Game")
	game.set_script(load("res://tests/fixtures/dispatch_score_probe.gd"))
	add_child(scene)
	await wait_for(0.5)
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261010"
	game._on_start_pressed()
	for i in 24:
		if game.popup_root.visible: game._on_popup_button()
		await wait_for(0.1)
	game.set_process(false)
	refund_transactions()
	GameState.funds = 1000
	for metric in GameState.metrics: GameState.metrics[metric] = 65
	game.current_hand = []
	for id in ["veg_restore", "education", "guard_team", "research", "patrol", "water_control"]:
		game.current_hand.append(GameState.card_by_id(id))
	await game._prepare_hand_art(game.current_hand)
	game.play_deal_anim = false
	game._build_hand_panel()
	await wait_for(0.3)
	game._process_staged_cards(0.0)
	flight_rates()
	check(game.staged_board.visible, "Board appears during allocation")
	check(game.staged_board.get_global_rect().end.x < game.right_panel.get_global_rect().position.x, "Board sits left of ecological monitoring")
	var first: Dictionary = game.card_infos[0]
	await rejection_cases()
	await direct_board_preview()
	var origin := begin(first)
	game._update_card_drag_pose(origin + Vector2(0, -28), Vector2(0, -28))
	check(not first.selected and game._is_play_drop_target(origin + Vector2(0, -28)), "A light upward swipe arms play without committing before release")
	check(game.drag_play_hint.visible and game.drag_play_hint.z_index > first.panel.z_index, "Play hint draws above dragged card")
	drop(first, origin + Vector2(0, -28))
	check(first.selected and first.stage_zone == "preview", "Release queues the card at full size")
	var was_collapsed: bool = game.sandpan_view.collapsed
	game.sandpan_view.toggle_view()
	check(game.sandpan_view.collapsed == was_collapsed and game.sandpan_view._blocked(), "Preview cards block sandpan toggle")
	await wait_for(0.6)
	check(absf(first.panel.scale.x - 1.0) < 0.002, "Preview stays full size")
	game._process_staged_cards(0.99)
	check(first.stage_zone == "preview", "Preview remains until 1 second")
	await shot("01-preview")
	game._process_staged_cards(0.02)
	check(first.get("queue_flying", false), "Preview expires into a flight")
	var flight_start: Vector2 = first.panel.get_global_transform() * (first.panel.size * 0.5)
	await wait_for(0.20)
	var flight_center: Vector2 = first.panel.get_global_transform() * (first.panel.size * 0.5)
	check(flight_center.distance_to(flight_start) > 20.0 and first.panel.scale.x < 0.95 and first.panel.scale.x > game.BOARD_CARD_SCALE, "Card moves and shrinks continuously in flight")
	await shot("02-flight")
	game._paused = true
	var paused_pos: Vector2 = first.panel.position
	await wait_for(0.15)
	check(first.panel.position.is_equal_approx(paused_pos), "Pause freezes the flight")
	game._paused = false
	await wait_for(0.55)
	check(not first.get("flying", false) and first.panel.get_node_or_null("CardFlight") == null, "Landing releases ownership and deletes the trail driver")
	board_pose()
	if DisplayServer.get_name() != "headless":
		await real_drag(first, Vector2(0, 95))
		check(not first.selected, "Native mini-card input retracts to hand")
		await wait_for(0.55)
		await real_drag(first, Vector2(0, -28))
		check(first.selected, "Native light upward swipe queues the hand card")
		await wait_for(0.5)
		game._process_staged_cards(2.2)
		await wait_for(0.7)
	origin = begin(first)
	game._update_card_drag_pose(origin + Vector2(1, 0), Vector2(1, 0))
	check(game.drag_play_hint.text == "松手放下", "Board dragging uses put-down hint")
	drop(first, origin + Vector2(0, 95))
	check(not first.selected and first.get("returning", false), "Downward mini-card swipe undoes immediately")
	await wait_for(0.55)
	check(first.panel.scale.is_equal_approx(Vector2.ONE) and not first.get("flying", false), "Undo grows back to the hand and releases input")
	origin = begin(first)
	drop(first, origin + Vector2(0, -28))
	await wait_for(0.4)
	game._process_staged_cards(2.2)
	await wait_for(0.2)
	var interrupted_pose: Vector2 = first.panel.position
	origin = begin(first)
	check(game._card_dragging and not first.get("flying", false) and first.panel.position.is_equal_approx(interrupted_pose), "Grabbing a moving card takes over without a jump")
	drop(first, origin + Vector2(0, 95))
	check(not first.selected, "A card can be undone during its parking flight")
	await wait_for(0.55)
	# Releasing back at the press point cancels the upward gesture.
	origin = begin(first)
	game._update_card_drag_pose(origin + Vector2(0, -30), Vector2.ZERO)
	drop(first, origin)
	check(not first.selected, "Reversing a swipe before release cancels play")
	await wait_for(0.4)
	origin = begin(first)
	drop(first, origin + Vector2(0, -28))
	await wait_for(0.4)
	origin = begin(first)
	drop(first, origin + Vector2(0, 48))
	check(not first.selected, "Full-size preview can also swipe downward to hand")
	await wait_for(0.55)
	# Four ordinary actions + one paid dispatch are the EASY capacity of five.
	for i in 4:
		var info: Dictionary = game.card_infos[i]
		origin = begin(info)
		drop(info, origin + Vector2(0, -28))
		info.panel.set_meta("probe_card_id", info.card_id)
		await wait_for(0.04)
	check(GameState.dispatch_card("water_control"), "Paid dispatch succeeds")
	game._sync_dispatched_stage_cards()
	var dispatched: Dictionary = game.card_infos.back()
	dispatched.panel.set_meta("probe_card_id", dispatched.card_id)
	await wait_for(0.4)
	check(game.end_turn_btn.disabled and game._cards_waiting_for_board(), "Preview cards block execution")
	var blocked_funds: int = GameState.funds
	game._finish_turn()
	check(not game._score_animating and GameState.funds == blocked_funds, "Direct execute callback also blocks preview cards")
	game._process_staged_cards(2.2)
	game._update_execute_button()
	check(game.end_turn_btn.disabled, "Cards in flight still block execution")
	await wait_for(0.8)
	check(not game.end_turn_btn.disabled, "Execution unlocks after all cards land")
	check(game._ordered_staged_indices().size() == 5 and game.staged_board_count.text == "待执行", "Board holds five queued cards without a quota label")
	check(not game._card_selection_error(game.card_infos[4]).is_empty(), "A sixth card is rejected")
	await rejected_returns(game.card_infos[4], game.staged_board.get_global_rect().get_center(), "Five-card board full")
	board_pose()
	await shot("03-five-cards")
	var target_info: Dictionary = game.card_infos[game._ordered_staged_indices()[0]]
	var left_center: Vector2 = target_info.panel.get_global_transform() * (target_info.panel.size * 0.5)
	origin = begin(dispatched)
	game._update_card_drag_pose(left_center, Vector2(-20, 0))
	check(game._staged_row_without_drag().size() == 4, "Reorder keeps every neighbour")
	drop(dispatched, left_center)
	await wait_for(0.7)
	check(game.card_infos[game._ordered_staged_indices()[0]].get("dispatched", false), "Dragging on wood changes queue order")
	board_pose()
	await shot("04-reordered")
	# Cancellation returns the dispatched card to its pool and reverses payment.
	var paid_funds: int = GameState.funds
	var paid_total: int = GameState.total_spent
	var paid_turn: int = GameState.turn_card_spent
	var paid_cost: int = GameState.dispatched_cards[0].paid_cost
	origin = begin(dispatched)
	drop(dispatched, origin + Vector2(0, 95))
	await wait_for(0.6)
	check(not game.card_infos.has(dispatched) and GameState.dispatched_cards.is_empty(), "Cancelled dispatch leaves queue and hand")
	check(GameState.funds == paid_funds + paid_cost and GameState.total_spent == paid_total - paid_cost and GameState.turn_card_spent == paid_turn - paid_cost, "Dispatch refunds exact payment in every ledger")
	check(GameState.can_dispatch(), "Cancelling restores dispatch availability")
	check(not GameState.cancel_dispatch("water_control"), "Duplicate cancellation cannot refund twice")
	game.save_game()
	check(game.load_game(), "Save/reload works with a retracted dispatch")
	await wait_for(0.7)
	check(GameState.dispatched_cards.is_empty() and GameState.funds == paid_funds + paid_cost, "Save keeps cancellation and refund")
	check(GameState.dispatch_card("water_control"), "Dispatch can be purchased again after cancellation")
	game._sync_dispatched_stage_cards()
	dispatched = game.card_infos.back()
	check(dispatched.get("dispatched", false) and dispatched.selected and GameState.funds == paid_funds, "Repurchase charges the restored quote once")
	for info in game.card_infos: info.panel.set_meta("probe_card_id", info.card_id)
	origin = begin(dispatched)
	drop(dispatched, origin + Vector2(0, -28))
	await wait_for(0.4)
	game.wetland.reduced_motion = true
	game._process_staged_cards(2.2)
	await get_tree().process_frame
	check(not dispatched.get("flying", false) and absf(dispatched.panel.scale.x - game.BOARD_CARD_SCALE) < 0.001, "Reduced motion parks instantly")
	game.wetland.reduced_motion = false
	get_window().size = Vector2i(960, 540)
	await wait_for(0.2)
	game._layout_fan(true)
	await wait_for(0.7)
	board_pose()
	check(get_viewport().get_visible_rect().encloses(game.staged_board.get_global_rect()), "Board fits minimum window")
	await shot("05-small-window")
	get_window().size = Vector2i(1280, 720)
	await wait_for(0.2)
	game._layout_fan(true)
	await wait_for(0.7)
	var order: Array = []
	for idx in game._ordered_staged_indices(): order.append(game.card_infos[idx].card_id)
	game.replayed_cards.clear()
	game.replayed_panels.clear()
	game.popped_cards.clear()
	game.row_y_spreads.clear()
	game.score_speed = 1.0
	game._finish_turn()
	await wait_for(0.20)
	var growing: Control = game.card_infos[game._ordered_staged_indices()[0]].panel
	check(growing.scale.x > game.BOARD_CARD_SCALE and growing.scale.x < 1.0, "Settlement enlarges continuously from wood")
	await shot("06-settlement-flight")
	for i in 160:
		await wait_for(0.05)
		if game.popped_cards.size() == 5: break
	check(game.replayed_cards == order and game.popped_cards == order, "All five effects and score beats follow the reordered queue")
	check(game.active_settlement_springs == 0 and game.unsettled_gyro_cards == 0, "Settlement has one animation owner and flat card poses")
	for spread in game.row_y_spreads: check(spread < 0.1, "Settlement cards share a baseline")
	await shot("07-scoring")
	for i in 100:
		await wait_for(0.05)
		if not game._score_animating: break
	check(not game._score_animating and game._current_phase == "popup_settlement", "Settlement completes normally")
	for info in game.card_infos: check(info.panel.get_node_or_null("CardFlight") == null, "No flight driver leaks after settlement")
	print("STAGED_BOARD: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
