extends Node
var game: Node
var failures: Array[String] = []
var checks := 0
var output_dir := OS.get_environment("POYANG_SCREENSHOT_DIR")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(seconds: float = 0.4) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func hand_state() -> Array:
	var out: Array = []
	for info in game.card_infos:
		out.append([info["card_id"], info["selected"], info["tier"], info["base_pos"], info["panel"].size])
	return out

func hand_matches(expected: Array) -> bool:
	var actual := hand_state()
	if actual.size() != expected.size(): return false
	for i in actual.size():
		for field in 3:
			if actual[i][field] != expected[i][field]: return false
		# Container layout can introduce subpixel float differences after resize.
		for field in [3, 4]:
			if (actual[i][field] as Vector2).distance_to(expected[i][field]) > 0.001: return false
	return true

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await settle()
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261004"
	game._on_start_pressed()
	for i in 12:
		if not game.popup_root.visible: break
		game._on_popup_button()
		await settle(0.1)
	if game.has_method("_on_expedition_selected"):
		if game.expedition_panel.visible: game._on_expedition_selected("habitat")
	await settle(1.2)
	GameState.funds = 500
	game._update_hud()
	var view: Node = game.sandpan_view
	check(game._current_phase == "allocate" and game.card_infos.size() > 0, "Must start in a real allocation phase")
	check(view.view_button.visible, "Sandpan entry missing during card selection")
	game.wetland.set_hand_view(0, 1, false)
	await settle(0.1)
	await capture("01-before-hand-clearance")
	view.invalidate_layout()
	await settle()
	await capture("02-hand-clearance")
	for window_size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = window_size
		await settle(0.5)
		var wetland: Control = game.wetland
		check(wetland.hand_view_state.x > 0, "Hand must shift map up")
		var shifted_center: Vector2 = wetland._point(Vector2(0.5, 0.5))
		check(shifted_center.y < get_viewport().get_visible_rect().size.y * 0.5 - 20, "Camera clearance moved map in wrong direction")
		check(is_equal_approx(wetland.camera_zoom_factor, wetland.GAME_CAMERA_ZOOM), "User zoom must remain unchanged")
		check(is_equal_approx(wetland.hand_view_state.y, 1.08 if window_size.y <= 600 else 1.0), "Small-window framing incorrect")
		check(get_viewport().get_visible_rect().encloses(view.view_button.get_global_rect()), "View button outside window")
		var inverse: Transform2D = wetland.get_node("Wildlife").get_transform().affine_inverse()
		for uv in [Vector2(0.3, 0.4), Vector2(0.6, 0.7), Vector2(0.7, 0.3)]:
			var projected: Vector2 = wetland.map_camera.unproject_position(wetland._ground_position(uv) + Vector3(0, wetland._relief_at(uv), 0))
			check(wetland._shadow_point(uv).distance_to(inverse * projected) < 0.002, "Ground/overlay alignment changed during clearance")
		check(wetland.get_node("Wildlife").get_transform().is_equal_approx(wetland.get_node("GroundShadows").get_transform()), "Shadow transform differs from scenery")
		var focus: Vector2 = wetland.hand_view_state
		for info in game.card_infos:
			info["hovered"] = true
		await settle(0.1)
		check(wetland.hand_view_state.is_equal_approx(focus), "Hovering must not move camera")
		await capture("03-clearance-" + str(window_size.x))
	get_window().size = Vector2i(1280, 720)
	await settle()
	game._set_play_tier("deep", false)
	var selected: Dictionary = game.card_infos[0]
	var before_play_focus: Vector2 = game.wetland.hand_view_state
	var press: Vector2 = selected.panel.get_global_transform() * (selected.panel.size * 0.5)
	game._card_press_panel = selected.panel
	game._card_press_origin = press
	game._start_card_drag()
	game._update_card_drag_pose(press + Vector2(0, -28), Vector2.ZERO)
	game._finish_card_pointer(press + Vector2(0, -28))
	await settle(3.0)
	check(selected.selected and selected.get("stage_zone", "") == "board", "Selected card must park before testing HUD visibility")
	check(game.wetland.hand_view_state.is_equal_approx(before_play_focus), "Parking a card must not move map")
	var expected_hand := hand_state()
	var expected_metrics: Dictionary = GameState.metrics.duplicate()
	var expected_funds: int = GameState.funds
	var board_relative: Vector2 = selected.panel.global_position - game.staged_board.global_position
	view.view_button.pressed.emit()
	await settle(0.10)
	check((selected.panel.global_position - game.staged_board.global_position).distance_to(board_relative) < 0.01, "Board and cards move right as one during collapse")
	check(view.hud_layer.position.x > 0.0 and selected.panel.get_parent() == game.staged_board, "Board cards ride HUD instead of sliding down with hand")
	await settle()
	check(view.collapsed and not view.hand_layer.visible, "View mode must completely hide hand")
	check(not view.hud_layer.visible, "Full view must hide every persistent HUD control")
	check(not game.staged_board.is_visible_in_tree(), "Full view hides the wooden card board")
	check(not game.left_panel.is_visible_in_tree() and not game.right_panel.is_visible_in_tree(), "Full view must hide metrics and status panels")
	check(not game.bottom_right.is_visible_in_tree() and not game.tier_lever.is_visible_in_tree() and not game.deck_root.is_visible_in_tree(), "Full view must hide sorting, dispatch, refresh, execution, tiers and deck entry")
	check(game.hand_sort_btn.disabled, "Full view must disable hand sorting")
	var previous_sort: bool = game._deck_sort_by_category
	game._toggle_hand_sort()
	check(game._deck_sort_by_category == previous_sort and not game._sort_animating, "Hidden sort callback must not modify or animate the hand")
	check(view.view_button.text == "展开手牌" and view.view_button.visible, "Must retain restore entry")
	check(hand_matches(expected_hand), "View mode changed cards, selection, tier, fan layout or card size")
	check(GameState.metrics == expected_metrics and GameState.funds == expected_funds, "View mode changed gameplay state")
	check(game.wetland.hand_view_state.is_equal_approx(Vector2(0, 1)), "Full view must restore camera framing")
	await capture("04-full-sandpan")
	game._open_deck_viewer()
	await settle(0.5)
	check(not view.view_button.visible, "View entry must not overlay deck")
	game._close_deck_viewer()
	await settle(0.6)
	check(view.collapsed and not view.hand_layer.visible and view.view_button.visible, "Deck close must restore collapsed view")
	check(game.hand_panel.offset_top == -290 and game.hand_panel.offset_bottom == -4, "Wrapper changed deck slide origins")
	check(hand_matches(expected_hand), "Opening deck changed selected cards")
	view.toggle_view()
	await settle(0.1)
	check((selected.panel.global_position - game.staged_board.global_position).distance_to(board_relative) < 0.01, "Board and cards stay together during restore")
	game._pause_game()
	var paused_position: Vector2 = view.hand_layer.position
	await settle(0.25)
	check(view.hand_layer.position.is_equal_approx(paused_position), "Pause must freeze hand transition")
	game._resume_game()
	await settle()
	check(not view.collapsed and view.hand_layer.visible and view.hand_layer.position.is_zero_approx(), "Restore must return exact hand origin")
	check(view.hud_layer.visible and view.hud_layer.position.is_zero_approx(), "Restore must return exact HUD origin")
	check(game.left_panel.is_visible_in_tree() and game.right_panel.is_visible_in_tree() and game.bottom_right.is_visible_in_tree(), "Restoring must recover HUD visibility")
	check(hand_matches(expected_hand), "Restoring hand changed locked tier/selection")
	var normal_focus: Vector2 = game.wetland.hand_view_state
	game._open_deck_viewer()
	await settle(0.45)
	game._close_deck_viewer()
	await settle(0.6)
	check(get_viewport().get_visible_rect().encloses(view.view_button.get_global_rect()), "Deck slide left view entry outside window")
	check(game.wetland.hand_view_state.is_equal_approx(normal_focus), "Deck slide changed hand clearance")
	game._open_dispatch_panel()
	await settle(0.45)
	check(not view.view_button.visible, "Dispatch overlay must hide view entry")
	game._close_dispatch_panel()
	await settle(0.6)
	check(view.view_button.visible and get_viewport().get_visible_rect().encloses(view.view_button.get_global_rect()), "Dispatch close must restore view entry")
	check(game.wetland.hand_view_state.is_equal_approx(normal_focus), "Dispatch slide changed hand clearance")
	view.toggle_view()
	await settle(0.05)
	view.toggle_view()
	await settle(0.05)
	view.toggle_view()
	await settle()
	check(view.collapsed and not view.hand_layer.visible, "Rapid toggles left hand transition unfinished")
	get_window().size = Vector2i(960, 540)
	await settle()
	check(view.collapsed and not view.hand_layer.visible, "Resize must keep full-view hand hidden")
	view.toggle_view()
	await settle()
	check(view.hand_layer.position.is_zero_approx(), "Resize restore drifted hand origin")
	game.wetland.reduced_motion = true
	view.toggle_view()
	await settle(0.1)
	check(not view.hand_layer.visible, "Reduced-motion mode must hide hand immediately")
	view.toggle_view()
	await settle(0.1)
	check(view.hand_layer.visible and view.hand_layer.position.is_zero_approx(), "Reduced-motion restore failed")
	game.wetland.reduced_motion = false
	view.toggle_view()
	await settle()
	game._finish_turn()
	check(not view.collapsed and view.hand_layer.visible and view.hand_layer.position.is_zero_approx(), "Settlement must restore hand before flying cards")
	check(not view.view_button.visible, "Settlement must hide view entry")
	for i in 100:
		if not game._score_animating: break
		await settle(0.1)
	check(not game._score_animating, "Real settlement failed to complete")
	for i in 12:
		if not game.popup_root.visible: break
		game._on_popup_button()
		await settle(0.1)
	await settle(1.0)
	check(game._current_phase == "allocate" and view.view_button.visible, "Next turn must restore hand and clearance")
	check(not view.collapsed and view.hand_layer.position.is_zero_approx(), "Next turn retained collapsed hand")
	game._pause_game()
	game._on_pause_exit()
	await settle(0.5)
	check(not view.view_button.visible and game.wetland.hand_view_state.is_equal_approx(Vector2(0, 1)), "Menu must restore full map without view entry")
	print("SANDPAN_VIEW: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks, ", failures.size(), " failures)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
