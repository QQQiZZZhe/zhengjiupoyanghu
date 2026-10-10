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
func monitored_sort(mode: bool, completion: Array) -> void:
	await game._sort_hand_cards(mode)
	completion[0] = true
	game._sort_animating = false
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(name + ".png"))
func new_hand() -> void:
	game.current_hand = []
	for id in ["patrol", "research", "education", "guard_team", "water_control", "veg_restore", "community_comp"]:
		game.current_hand.append(GameState.card_by_id(id))
	game.play_deal_anim = true
	game._build_hand_panel()
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	game = scene.get_node("Game")
	await wait_for(0.5)
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261010"
	game._on_start_pressed()
	for i in 24:
		if game.popup_root.visible: game._on_popup_button()
		await wait_for(0.1)
	game.set_process(false) # Keep the user's current pointer from raising a test card.
	var art: GDScript = load("res://scripts/pixel_card_art.gd")
	art.textures.clear()
	var warm_hand: Array = []
	for id in ["patrol", "research", "education", "guard_team", "water_control", "veg_restore", "community_comp"]:
		warm_hand.append(GameState.card_by_id(id))
	var texture_counts: Array = []
	var monitor := func() -> void: texture_counts.append(art.textures.size())
	get_tree().process_frame.connect(monitor)
	await game._prepare_hand_art(warm_hand)
	get_tree().process_frame.disconnect(monitor)
	check(texture_counts.size() >= 6, "Cold hand generation is spread across frames")
	for i in range(1, texture_counts.size()):
		check(int(texture_counts[i]) - int(texture_counts[i - 1]) <= 1, "At most one new face upload per frame")
	new_hand()
	await get_tree().process_frame
	for i in game.card_infos.size():
		var info: Dictionary = game.card_infos[i]
		check(info.get("dealing", false) and info.get("flying", false), "Deal owns card pose")
		check(info.panel.get_meta("deal_index", -1) == i, "Cards leave in fan order")
		var center: Vector2 = info.panel.get_global_transform() * (info.panel.size * 0.5)
		check(center.distance_to(info.panel.get_meta("deal_source")) < 20.0, "Every card starts at the visible stack")
	var last: Dictionary = game.card_infos.back()
	var start: Vector2 = last.panel.position
	game._layout_fan()
	check(last.panel.position.is_equal_approx(start), "Repeated layout does not snap delayed cards into hand")
	await wait_for(0.20)
	await shot("01-dealing")
	check(game.card_infos[0].panel.modulate.a > 0.99 and last.panel.modulate.a < 0.01, "Takeoff is staggered instead of simultaneous")
	await wait_for(0.7)
	for info in game.card_infos:
		check(not info.get("dealing", false) and not info.get("flying", false), "Arrival releases input ownership")
		check(info.panel.position.distance_to(info.base_pos) < 0.1 and absf(info.panel.rotation - info.theta) < 0.01, "Cards arrive at the fan pose")
	await shot("02-fan")
	var staged: Dictionary = game.card_infos[0]
	staged.selected = true
	staged.staged_by_drag = true
	staged.stage_order = 0
	staged.tier = "effective"
	game._layout_fan()
	await wait_for(0.4)
	var staged_pose: Vector2 = staged.panel.position
	var old_hand: Array = []
	for info in game.card_infos:
		if not info.get("staged_by_drag", false): old_hand.append(info.panel)
	var old_center: Vector2 = old_hand[0].get_global_transform() * (old_hand[0].size * 0.5)
	GameState.funds = 1000
	game._on_refresh_hand()
	game._on_refresh_hand()
	await get_tree().process_frame
	check(GameState.funds == 995, "Repeated refresh during collection pays only once")
	check(game._sort_animating and is_instance_valid(old_hand[0]), "Old cards remain visible during collection")
	check(game.card_infos.has(staged), "Refresh keeps the existing table card")
	check(not staged.get("dealing", false), "Refresh deals only the new hand")
	check(staged.panel.position.distance_to(staged_pose) < 0.1, "Table card stays in place while new cards fly")
	await wait_for(0.12)
	var deck_center: Vector2 = game.deck_backs.back().get_global_transform() * (game.deck_backs.back().size * 0.5)
	var moving_center: Vector2 = old_hand[0].get_global_transform() * (old_hand[0].size * 0.5)
	check(moving_center.distance_to(deck_center) < old_center.distance_to(deck_center), "Old hand flies back toward the deck before replacements exist")
	await shot("03-refresh-return")
	await wait_for(0.45)
	check(not is_instance_valid(old_hand[0]), "Old cards are removed only after reaching the deck")
	check(not game._sort_animating, "Collection releases the refresh lock")
	var new_deal := false
	for info in game.card_infos:
		if not info.get("staged_by_drag", false) and info.get("dealing", false): new_deal = true
	check(new_deal, "Replacements are dealt after collection completes")
	await wait_for(0.9)
	get_window().size = Vector2i(960, 540)
	new_hand()
	await get_tree().process_frame
	await wait_for(0.85)
	for info in game.card_infos: check(info.panel.position.distance_to(info.base_pos) < 0.1, "Small-window arrival matches current layout")
	game.wetland.reduced_motion = true
	new_hand()
	await get_tree().process_frame
	for info in game.card_infos:
		check(not info.get("dealing", false) and info.panel.modulate.a == 1.0, "Reduced motion shows complete cards immediately")
	game.wetland.reduced_motion = false
	new_hand()
	await wait_for(0.9)
	for mode in [true, false]:
		var saw_redeal := false
		var correct_layers := true
		var correct_rest := true
		var start_order: Array = []
		for info in game.card_infos: start_order.append(info.panel)
		# A stale hover must not become the front card again after sorting.
		game.card_infos[0].hovered = true
		game._update_card_stack()
		game._sort_animating = true
		var completion := [false]
		monitored_sort(mode, completion)
		var deadline := Time.get_ticks_msec() + 4000
		while not completion[0] and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			var changed := false
			for i in game.card_infos.size():
				if game.card_infos[i].panel != start_order[i]: changed = true
			if changed and game.card_infos[0].get("flying", false): saw_redeal = true
			for i in range(1, game.card_infos.size()):
				var left: Control = game.card_infos[i - 1].panel
				var right: Control = game.card_infos[i].panel
				if left.z_index > right.z_index: correct_layers = false
				if not game.card_infos[0].get("flying", false) and left.get_index() > right.get_index(): correct_rest = false
		check(completion[0], "Sort finishes before rebuilding another hand")
		check(saw_redeal, "Sort changes order while cards are dealt back")
		check(correct_layers, "Right cards stay above left cards throughout both sort modes")
		check(correct_rest, "Resting draw order is restored before the next hover update")
	new_hand()
	await get_tree().process_frame
	for metric in GameState.metrics: GameState.metrics[metric] = 70
	game._finish_turn()
	await wait_for(5.0)
	check(not game._score_animating and game._current_phase == "popup_settlement", "Immediate end turn safely interrupts dealing")
	for info in game.card_infos: check(not info.get("dealing", false), "Settlement clears deal flags")
	print("CARD DEAL CHECKS: %d, failures: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
