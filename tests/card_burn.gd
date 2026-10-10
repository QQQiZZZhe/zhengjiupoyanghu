extends Node
const Burn := preload("res://scripts/card_burn.gd")
var checks := 0
var failures := 0
func color_gap(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("POYANG_SCREENSHOT_DIR").path_join(name + ".png"))
	return img
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	var game: Node = load("res://tests/fixtures/bgm_probe.gd").new()
	add_child(game)
	var background := ColorRect.new()
	background.color = Color("192728")
	background.size = Vector2(1280, 720)
	add_child(background)
	var panels: Array[Control] = []
	for i in 2:
		var made: Dictionary = game._make_card(GameState.card_by_id("veg_restore"), "effective", i == 1)
		var card: Control = made.panel
		add_child(card)
		card.position = Vector2(230 + i * 360, 190)
		card.size = Vector2(244, 330)
		game._bind_card_gyro(card)
		panels.append(card)
	await get_tree().create_timer(0.3).timeout
	var before := await shot("01-intact")
	for card in panels:
		Burn.play(card, 1.0)
		# Stop the tween at a reproducible middle frame, avoiding capture timing drift.
		preload("res://scripts/motion.gd").cancel(card, "card_burn")
		card.material.set_shader_parameter("dissolve_value", 0.5)
	var middle := await shot("02-burn")
	for card in panels:
		card.material.set_shader_parameter("dissolve_value", 0.0)
		card.get_meta("projected_shadow").modulate.a = 0.0
	var gone := await shot("03-gone")
	for card in panels:
		var rect := Rect2i(card.position, card.size)
		var initial := 0
		var remaining := 0
		var final_pixels := 0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if color_gap(before.get_pixel(x, y), gone.get_pixel(20, 20)) > 0.05: initial += 1
				if color_gap(middle.get_pixel(x, y), gone.get_pixel(x, y)) > 0.05: remaining += 1
				if color_gap(gone.get_pixel(x, y), gone.get_pixel(20, 20)) > 0.05: final_pixels += 1
		check(initial > 10000, "Card is visible at intact endpoint")
		check(remaining > 500 and remaining < initial * 0.9, "Partial dissolve actually removes pixels")
		check(final_pixels == 0, "Zero endpoint has no card pixels or glowing dots")
		Burn.reset(card)
		check(not card.get_meta("burning") and card.material.get_shader_parameter("dissolve_value") == 1.0, "Cancellation restores the material")
		Burn.play(card, 0.1)
	await get_tree().create_timer(0.2).timeout
	for card in panels: check(card.material.get_shader_parameter("dissolve_value") == 0.0, "Tween reaches fully dissolved state")
	background.queue_free()
	for card in panels: card.queue_free()
	game.queue_free()
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(scene)
	var actual: Node = scene.get_node("Game")
	await get_tree().create_timer(0.5).timeout
	if actual._intro_playing: actual._finish_intro()
	actual._on_title_start()
	actual._on_difficulty_pick(GameState.Difficulty.EASY)
	actual.seed_input.text = "20261010"
	actual._on_start_pressed()
	for i in 24:
		if actual.popup_root.visible: actual._on_popup_button()
		await get_tree().create_timer(0.1).timeout
	GameState.funds = 1000
	for metric in GameState.metrics: GameState.metrics[metric] = 70
	actual.current_hand = [GameState.card_by_id("patrol")]
	actual.play_deal_anim = false
	actual._build_hand_panel()
	await get_tree().process_frame
	var info: Dictionary = actual.card_infos[0]
	info.selected = true
	info.staged_by_drag = true
	info.stage_order = 0
	info.tier = "effective"
	check(GameState.dispatch_card("rescue"), "Dispatch payment succeeds")
	actual._sync_dispatched_stage_cards()
	actual._layout_fan()
	await get_tree().create_timer(0.6).timeout
	actual._finish_turn()
	var burn_seen := false
	var captured := false
	for frame in 200:
		await get_tree().create_timer(0.03).timeout
		for entry in actual.card_infos:
			if entry.panel.get_meta("burning", false):
				burn_seen = true
				var value: float = entry.panel.material.get_shader_parameter("dissolve_value")
				if not captured and value > 0.3 and value < 0.7:
					await shot("04-settlement-burn")
					captured = true
		if not actual._score_animating: break
	check(burn_seen and captured, "Real settlement burns cards after counting")
	check(actual._current_phase == "popup_settlement", "Burn completes without blocking settlement")
	for entry in actual.card_infos:
		check(not entry.panel.get_meta("burning", false), "Cleanup clears burning state")
		check(entry.panel.material.get_shader_parameter("dissolve_value") == 1.0, "Settlement cleanup restores reused materials")
	check(GameState.ever_played.get("patrol", 0) == 1 and GameState.ever_played.get("rescue", 0) == 1, "Burn does not execute cards twice")
	print("CARD BURN CHECKS: %d, failures: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
