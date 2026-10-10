extends Node
var game: Node
func sample(label: String) -> void:
	await get_tree().create_timer(0.8).timeout
	var started := Time.get_ticks_usec()
	for i in 1000: game._update_card_hover(1.0 / 120.0, Vector2(-500, -500))
	var hover_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in 1000: game._update_metric_preview()
	var preview_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for i in 300: game.wetland._process(1.0 / 120.0)
	var wetland_us := Time.get_ticks_usec() - started
	# Let Performance's one-second CPU window expire after the deliberate
	# microbenchmark loops; these stalls are not normal gameplay frame costs.
	await get_tree().create_timer(1.3).timeout
	var frames: Array[float] = []
	var calls: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 240:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort()
	calls.sort()
	print("PREVIEW_PERF %s hover1000_us=%d preview1000_us=%d wetland300_us=%d frame_p50_ms=%.3f frame_p95_ms=%.3f draw_p95=%.0f" % [label, hover_us, preview_us, wetland_us, frames[120], frames[228], calls[228]])
func _ready() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	game = scene.get_node("Game")
	add_child(scene)
	await get_tree().create_timer(0.5).timeout
	if game._intro_playing: game._finish_intro()
	game._on_title_start()
	game._on_difficulty_pick(GameState.Difficulty.EASY)
	game.seed_input.text = "20261010"
	game._on_start_pressed()
	for i in 32:
		if game.popup_root.visible: game._on_popup_button()
		await get_tree().create_timer(0.1).timeout
	GameState.funds = 1000
	await sample("hand")
	for i in 4: preload("res://tests/card_input.gd").drop_on_board(game, game.card_infos[i])
	game._update_metric_preview()
	await sample("board4")
	GameState.dispatch_card("water_control")
	game._sync_dispatched_stage_cards()
	game._process_staged_cards(1.1)
	await get_tree().create_timer(0.8).timeout
	await sample("board5")
	get_window().size = Vector2i(1600, 900)
	await sample("board5-large")
	get_window().size = Vector2i(1280, 720)
	game.sandpan_view.toggle_view()
	await sample("sandpan")
	print("PREVIEW_PERFORMANCE: ", "PASS" if Engine.max_fps == 120 else "FAIL", " cap=", Engine.max_fps)
	get_tree().quit(0 if Engine.max_fps == 120 else 1)
